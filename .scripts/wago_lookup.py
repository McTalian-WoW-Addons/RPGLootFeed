"""
Query wago.tools for WoW asset ground truth: FileDataIDs, per-flavor file
presence, texture atlases, and texture kits.

Motivating use case: picking an icon for a newly added faction. Some factions
never ship a plain `interface/icons/*.blp` at all (Ritual Sites in 12.0.5 only
shipped atlas + minimap art), and an icon that exists on Retail may be absent
from Classic, so a FileDataID must be presence-checked per flavor before it is
hardcoded into a lookup table.

Usage (see `--help` on any subcommand):

    uv run .scripts/wago_lookup.py info 236681
    uv run .scripts/wago_lookup.py presence 236681 894556
    uv run .scripts/wago_lookup.py find achievement_reputation
    uv run .scripts/wago_lookup.py atlas ritual
    uv run .scripts/wago_lookup.py kits ritual
    uv run .scripts/wago_lookup.py builds

Downloads are cached under .scripts/.output/wago-cache (gitignored). Pass
--refresh to re-fetch. Listfiles are large (Retail is ~40MB); the first call
for a product is slow, subsequent ones are instant.

IMPORTANT: https://wago.tools/api/casc/{fdid} does NOT honour its `product`
parameter -- it returns HTTP 200 for Retail-only assets queried against
Classic, and even for FileDataIDs that do not exist. It is useless for
presence checks. Only the /api/files listfile is authoritative, which is what
`presence` uses.
"""

import argparse
import csv
import io
import json
import re
import sys
import time
import urllib.error
import urllib.request
from pathlib import Path
from typing import Dict, Iterable, List, Optional, Tuple

BASE = "https://wago.tools"
# wago.tools sits behind Cloudflare, which 403s urllib's default User-Agent.
UA = "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/125.0 Safari/537.36"

CACHE_DIR = Path(__file__).resolve().parent / ".output" / "wago-cache"

# Products matching the flavors RPGLootFeed ships to, keyed by the `## Interface`
# prefix in RPGLootFeed.toc. Keep in sync with the toc when a flavor is added.
FLAVORS: Dict[str, str] = {
    "Classic Era": "wow_classic_era",  # 11xxx
    "TBC Anniversary": "wow_anniversary",  # 20xxx
    "MoP Classic": "wow_classic",  # 50xxx
    "Retail": "wow",  # 12xxxx
}


def _fetch(url: str, timeout: int = 300, attempts: int = 4) -> bytes:
    """GET with retries.

    The listfile endpoints return multi-megabyte payloads and intermittently
    502/504 under load, so a bare urlopen is not reliable enough for a tool
    people will run unattended.
    """
    if not url.startswith(f"{BASE}/"):
        # Guards against file:// and other schemes reaching urlopen.
        raise ValueError(f"refusing to fetch non-wago.tools URL: {url}")

    last: Optional[Exception] = None
    req = urllib.request.Request(url, headers={"User-Agent": UA})
    for attempt in range(1, attempts + 1):
        try:
            # Scheme is pinned to the https BASE constant by the guard above.
            with urllib.request.urlopen(
                req, timeout=timeout
            ) as resp:  # nosec B310 # noqa: S310
                return resp.read()
        except (urllib.error.HTTPError, urllib.error.URLError, TimeoutError) as e:
            last = e
            code = getattr(e, "code", None)
            # 4xx other than 429 will not fix themselves; fail fast.
            if code is not None and 400 <= code < 500 and code != 429:
                raise
            if attempt < attempts:
                delay = 2**attempt
                sys.stderr.write(
                    f"  {type(e).__name__} ({code or e}) - retry {attempt}/{attempts - 1} in {delay}s\n"
                )
                time.sleep(delay)
    raise RuntimeError(f"giving up on {url} after {attempts} attempts: {last}")


def _cached(name: str, url: str, refresh: bool = False) -> bytes:
    CACHE_DIR.mkdir(parents=True, exist_ok=True)
    path = CACHE_DIR / name
    if path.exists() and not refresh:
        return path.read_bytes()
    sys.stderr.write(f"fetching {url} ...\n")
    data = _fetch(url)
    path.write_bytes(data)
    return data


def builds() -> Dict[str, str]:
    """Latest build version string per product.

    The endpoint returns either a bare version string or an object carrying
    `version` plus CDN config hashes, depending on the product; normalise both
    down to the version string.
    """
    raw = json.loads(_fetch(f"{BASE}/api/builds/latest", timeout=60).decode())
    out: Dict[str, str] = {}
    for product, value in raw.items():
        if isinstance(value, dict):
            version = value.get("version")
            if version:
                out[product] = version
        elif isinstance(value, str):
            out[product] = value
    return out


def listfile(product: str, refresh: bool = False) -> List[Tuple[int, str]]:
    """Every file present in a product's latest build, as (fdid, filename)."""
    raw = _cached(
        f"files-{product}.csv",
        f"{BASE}/api/files?product={product}&format=csv",
        refresh,
    )
    out: List[Tuple[int, str]] = []
    for line in raw.decode("utf-8", "replace").splitlines():
        fdid, _, name = line.partition(";")
        try:
            out.append((int(fdid), name.strip().strip('"')))
        except ValueError:
            continue
    return out


def db2(table: str, build: str, refresh: bool = False) -> List[dict]:
    """A DB2 table exported as CSV for a specific build."""
    raw = _cached(
        f"db2-{table}-{build}.csv",
        f"{BASE}/db2/{table}/csv?build={build}",
        refresh,
    )
    return list(csv.DictReader(io.StringIO(raw.decode("utf-8", "replace"))))


def cmd_info(args: argparse.Namespace) -> int:
    for fdid in args.fdids:
        try:
            data = json.loads(_fetch(f"{BASE}/api/info/{fdid}", timeout=60).decode())
            print(f"{fdid}\t{data.get('filename')}")
        except urllib.error.HTTPError as e:
            print(f"{fdid}\t<HTTP {e.code}>")
    return 0


def cmd_presence(args: argparse.Namespace) -> int:
    flavors = _selected_flavors(args)
    tables = {
        label: {fdid for fdid, _ in listfile(product, args.refresh)}
        for label, product in flavors.items()
    }
    names: Dict[int, str] = {}
    for product in flavors.values():
        for fdid, name in listfile(product, False):
            if fdid in args.fdids and fdid not in names:
                names[fdid] = name

    width = max((len(lbl) for lbl in flavors), default=10)
    print(
        f"{'fdid':<10} {'file':<58} " + " ".join(f"{lbl:<{width}}" for lbl in flavors)
    )
    missing_anywhere = False
    for fdid in args.fdids:
        cells = []
        for label in flavors:
            present = fdid in tables[label]
            cells.append(f"{'yes' if present else 'NO':<{width}}")
            if not present:
                missing_anywhere = True
        print(f"{fdid:<10} {names.get(fdid, '<unknown>'):<58} " + " ".join(cells))
    if missing_anywhere:
        print(
            "\nAt least one file is absent from a shipped flavor. Guard its use "
            "with G_RLF:IsRetail()/IsClassic(), or pick a different asset.",
            file=sys.stderr,
        )
    return 0


def cmd_find(args: argparse.Namespace) -> int:
    pattern = re.compile(args.pattern, re.I)
    rows = listfile(FLAVORS[args.flavor], args.refresh)
    hits = [(f, n) for f, n in rows if pattern.search(n)]
    if args.icons_only:
        hits = [(f, n) for f, n in hits if n.startswith("interface/icons/")]
    for fdid, name in hits[: args.limit]:
        print(f"{fdid}\t{name}")
    print(
        f"\n{len(hits)} match(es) in {args.flavor}"
        + (f", showing {args.limit}" if len(hits) > args.limit else ""),
        file=sys.stderr,
    )
    return 0


def cmd_atlas(args: argparse.Namespace) -> int:
    build = args.build or builds()["wow"]
    pattern = re.compile(args.pattern, re.I)
    rows = db2("UiTextureAtlasMember", build, args.refresh)
    hits = [r for r in rows if pattern.search(r.get("CommittedName", ""))]
    for r in hits[: args.limit]:
        print(
            f"{r['CommittedName']}\t(atlas {r.get('UiTextureAtlasID')}, {r.get('Width')}x{r.get('Height')})"
        )
    print(f"\n{len(hits)} atlas member(s) in build {build}", file=sys.stderr)
    return 0


def cmd_kits(args: argparse.Namespace) -> int:
    build = args.build or builds()["wow"]
    pattern = re.compile(args.pattern, re.I)
    rows = db2("UiTextureKit", build, args.refresh)
    hits = [r for r in rows if pattern.search(r.get("KitPrefix", ""))]
    for r in hits[: args.limit]:
        print(f"{r['ID']}\t{r['KitPrefix']}")
    print(f"\n{len(hits)} texture kit(s) in build {build}", file=sys.stderr)
    return 0


REP_HELPERS = (
    Path(__file__).resolve().parent.parent
    / "RPGLootFeed"
    / "utils"
    / "ReputationHelpers.lua"
)
# Blizzard ships some of these with a stray space after the underscore
# (`ui_majorfactions_ nightfall`), so the separator is `[_ ]*`.
ICON_FILE_RE = re.compile(
    r"interface/icons/ui_majorfactions_[_ ]*(?:renown_)?[_ ]*([a-z0-9]+?)(?:_256)?\.blp$"
)
ATLAS_RE = re.compile(r"^majorfactions_icons_([a-z0-9]+?)512$")


def _mapped_kits() -> Dict[str, str]:
    """Texture kits already hardcoded in majorFactionTextureKitIconMap."""
    if not REP_HELPERS.exists():
        return {}
    text = REP_HELPERS.read_text(encoding="utf-8")
    block = re.search(
        r"local majorFactionTextureKitIconMap\s*=\s*\{(.*?)\n\}", text, re.S
    )
    if not block:
        return {}
    return {
        m.group(1).lower(): (m.group(2) or "").strip()
        for m in re.finditer(
            r'\["([^"]+)"\]\s*=\s*\d+,\s*(?:--\s*(.*))?', block.group(1)
        )
    }


def cmd_audit(args: argparse.Namespace) -> int:
    """Diff the addon's major faction icon map against live game data."""
    build = args.build or builds()["wow"]
    mapped = _mapped_kits()
    if not mapped:
        print("Could not parse majorFactionTextureKitIconMap", file=sys.stderr)
        return 1

    atlases = {
        m.group(1): r["CommittedName"]
        for r in db2("UiTextureAtlasMember", build, args.refresh)
        if (m := ATLAS_RE.match(r.get("CommittedName", "").lower()))
    }
    icon_files: Dict[str, Tuple[int, str]] = {}
    for fdid, name in listfile("wow", args.refresh):
        m = ICON_FILE_RE.match(name.lower())
        if m and "_256" not in name.lower():
            icon_files.setdefault(m.group(1), (fdid, name))

    known = set(mapped)
    live = set(atlases) | set(icon_files)
    missing = sorted(live - known)

    print(
        f"build {build}: {len(mapped)} kit(s) mapped, {len(live)} seen in game data\n"
    )
    if not missing:
        print("No unmapped major faction texture kits. Nothing to do.")
        return 0

    print("UNMAPPED texture kits:\n")
    for kit in missing:
        icon = icon_files.get(kit)
        if icon:
            print(f"  {kit:<20} icon file  {icon[0]}  {icon[1]}")
        else:
            print(f"  {kit:<20} ATLAS ONLY  {atlases[kit]}  (no interface/icons file)")
    print(
        "\n'icon file' entries can be added to majorFactionTextureKitIconMap directly.\n"
        "'ATLAS ONLY' entries have no FileDataID -- they need the atlas path\n"
        "(see paragonIconAtlas / G_RLF.AtlasIconCoefficients for the existing\n"
        "atlas-rendering approach), or a substitute icon.\n"
        "Verify anything you add with: wago_lookup.py presence <fdid>",
        file=sys.stderr,
    )
    return 0


def cmd_builds(args: argparse.Namespace) -> int:
    latest = builds()
    for product, version in sorted(latest.items()):
        flavor = next((k for k, v in FLAVORS.items() if v == product), "")
        print(f"{product:<24} {version:<18} {flavor}")
    return 0


def _selected_flavors(args: argparse.Namespace) -> Dict[str, str]:
    if getattr(args, "flavor", None):
        return {args.flavor: FLAVORS[args.flavor]}
    return dict(FLAVORS)


def main(argv: Optional[Iterable[str]] = None) -> int:
    p = argparse.ArgumentParser(
        prog="wago_lookup.py",
        description=__doc__,
        formatter_class=argparse.RawDescriptionHelpFormatter,
    )
    p.add_argument("--refresh", action="store_true", help="bypass the local cache")
    sub = p.add_subparsers(dest="cmd", required=True)

    s = sub.add_parser("info", help="resolve FileDataID(s) to filenames")
    s.add_argument("fdids", nargs="+", type=int)
    s.set_defaults(func=cmd_info)

    s = sub.add_parser("presence", help="check FileDataID presence per shipped flavor")
    s.add_argument("fdids", nargs="+", type=int)
    s.add_argument("--flavor", choices=list(FLAVORS), help="limit to one flavor")
    s.set_defaults(func=cmd_presence)

    s = sub.add_parser("find", help="search a flavor's listfile by filename regex")
    s.add_argument("pattern")
    s.add_argument("--flavor", default="Retail", choices=list(FLAVORS))
    s.add_argument(
        "--icons-only", action="store_true", help="restrict to interface/icons/"
    )
    s.add_argument("--limit", type=int, default=40)
    s.set_defaults(func=cmd_find)

    s = sub.add_parser("atlas", help="search UiTextureAtlasMember names")
    s.add_argument("pattern")
    s.add_argument(
        "--build", help="full build, e.g. 12.1.0.69299 (default: latest Retail)"
    )
    s.add_argument("--limit", type=int, default=40)
    s.set_defaults(func=cmd_atlas)

    s = sub.add_parser(
        "kits", help="search UiTextureKit prefixes (major faction textureKit)"
    )
    s.add_argument("pattern")
    s.add_argument(
        "--build", help="full build, e.g. 12.1.0.69299 (default: latest Retail)"
    )
    s.add_argument("--limit", type=int, default=40)
    s.set_defaults(func=cmd_kits)

    s = sub.add_parser(
        "audit",
        help="diff majorFactionTextureKitIconMap against live game data",
    )
    s.add_argument(
        "--build", help="full build, e.g. 12.1.0.69299 (default: latest Retail)"
    )
    s.set_defaults(func=cmd_audit)

    s = sub.add_parser("builds", help="list the latest build per product")
    s.set_defaults(func=cmd_builds)

    args = p.parse_args(list(argv) if argv is not None else None)
    return args.func(args)


if __name__ == "__main__":
    sys.exit(main())
