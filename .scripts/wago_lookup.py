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
ATLAS_RE = re.compile(r"^majorfactions_icons_([a-z0-9]+?)512$")

# Faction icon filenames are wildly inconsistent, so matching a strict pattern
# produces false "no icon exists" verdicts. All of these are real, in 12.1:
#   ui_majorfactions_storm.blp                  plural
#   ui_majorfaction_storm.blp                   singular
#   ui_majorfactions_ nightfall.blp             stray space (CSV quotes the line)
#   ui_majorfaction_renown_zuljarrasforces.blp  'renown_', and the kit is only a prefix
#   ui_prey.blp / ui_delves.blp                 no 'majorfaction' at all
# So scan every ui_* icon for the kit name as a substring, and treat a miss as
# "nothing matched" rather than proof that no icon exists.
UI_ICON_RE = re.compile(r"^interface/icons/(ui_.*?)(?:_256)?\.blp$")
# Kit-ish token from a faction icon filename, for factions that ship an icon but
# no atlas member (radiantcore in 12.1). Tolerates singular/plural, the stray
# space, and an optional `renown_`.
ICON_KIT_RE = re.compile(r"^ui_majorfactions?_[ ]*(?:renown_)?[ ]*([a-z0-9]+)$")


def _mapped_kits() -> Dict[str, int]:
    """Texture kit -> FileDataID, as hardcoded in majorFactionTextureKitIconMap."""
    if not REP_HELPERS.exists():
        return {}
    text = REP_HELPERS.read_text(encoding="utf-8")
    block = re.search(
        r"local majorFactionTextureKitIconMap\s*=\s*\{(.*?)\n\}", text, re.S
    )
    if not block:
        return {}
    return {
        m.group(1).lower(): int(m.group(2))
        for m in re.finditer(r'\["([^"]+)"\]\s*=\s*(\d+),', block.group(1))
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
    # Every ui_* icon, so a kit can be matched as a substring of the basename.
    ui_icons: List[Tuple[int, str, str]] = []
    for fdid, name in listfile("wow", args.refresh):
        lowered = name.lower()
        # _256 files are higher-res duplicates of the base icon; keeping them
        # makes a faction look unmapped when only its base icon is in the map.
        if lowered.endswith("_256.blp"):
            continue
        m = UI_ICON_RE.match(lowered)
        if m:
            ui_icons.append((fdid, name, m.group(1)))

    # Some factions ship an icon but no atlas member, so the live set is the
    # union of both sources. Icon-derived tokens that merely extend an atlas kit
    # (`zuljarrasforces` vs `zuljarra`) are the same faction, not a new one.
    icon_kits = set()
    for _, _, base in ui_icons:
        m = ICON_KIT_RE.match(base)
        if m:
            token = m.group(1)
            if not any(k in token or token in k for k in atlases):
                icon_kits.add(token)

    known = set(mapped)
    live = set(atlases) | icon_kits
    missing = sorted(live - known)

    print(f"build {build}: {len(mapped)} kit(s) mapped, {len(live)} live\n")
    if not missing:
        print("No unmapped major faction texture kits. Nothing to do.")
        return 0

    mapped_fdids = set(mapped.values())
    rows, unmatched = [], []
    for kit in missing:
        candidates = [(f, n) for f, n, base in ui_icons if kit in base]
        # A kit whose only icon is already in the map is the same faction under
        # a different kit alias (`denizens` is Dream Wardens, already `dream`).
        if candidates and all(f in mapped_fdids for f, _ in candidates):
            continue
        rows.append((kit, candidates))

    if not rows:
        print("No unmapped major faction texture kits. Nothing to do.")
        return 0

    print("UNMAPPED texture kits:\n")
    for kit, candidates in rows:
        if candidates:
            fresh = [(f, n) for f, n in candidates if f not in mapped_fdids]
            fdid, name = (fresh or candidates)[0]
            extra = (
                f"  (+{len(fresh or candidates) - 1} more)"
                if len(fresh or candidates) > 1
                else ""
            )
            print(f"  {kit:<20} icon file   {fdid}  {name}{extra}")
        else:
            unmatched.append(kit)
            atlas = atlases.get(kit, "<none>")
            print(f"  {kit:<20} no ui_* icon matched   atlas: {atlas}")

    print(
        "\n'icon file' rows: verify with `presence <fdid>`, then add to\n"
        "majorFactionTextureKitIconMap. The filename is only a heuristic match on\n"
        "the kit name -- eyeball the art before trusting it.\n",
        file=sys.stderr,
    )
    if unmatched:
        print(
            "Rows with no match may still have an icon under an unrelated name\n"
            "(ui_prey.blp and ui_delves.blp both do). Search manually before\n"
            "concluding a faction is atlas-only:\n"
            + "".join(f"    wago_lookup.py find {k} --icons-only\n" for k in unmatched)
            + "If genuinely atlas-only, it needs the atlas render path (see\n"
            "paragonIconAtlas / G_RLF.AtlasIconCoefficients) or a substitute icon.",
            file=sys.stderr,
        )
    return 0


def _require_pillow():
    """Pillow is only needed by `extract`, so it stays an optional import."""
    try:
        from PIL import Image
    except ImportError:
        raise SystemExit(
            "extract needs Pillow, which the other subcommands do not.\n"
            "Run it as:  uv run --with pillow .scripts/wago_lookup.py extract ...\n"
            'or:         make faction_icon_preview TARGETS="..."'
        ) from None
    return Image


def _blp2_raw_bgra(data: bytes, Image):
    """Decode BLP2 encoding 3 (uncompressed BGRA).

    Pillow's BLP plugin raises "Unknown BLP encoding 3" on these, and the
    major faction atlas sheets all use it, so it has to be handled here.
    Palettised (1) and DXT (2) BLPs are left to Pillow.
    """
    import struct

    width, height = struct.unpack_from("<II", data, 12)
    offsets = struct.unpack_from("<16I", data, 20)
    sizes = struct.unpack_from("<16I", data, 84)
    mip0 = data[offsets[0] : offsets[0] + sizes[0]]
    expected = width * height * 4
    if len(mip0) != expected:
        raise ValueError(
            f"mip0 is {len(mip0)} bytes, expected {expected} for {width}x{height}"
        )
    return Image.frombytes("RGBA", (width, height), mip0, "raw", "BGRA")


def _blp_image(fdid: int, build: str, Image):
    data = _cached(f"casc-{fdid}.blp", f"{BASE}/api/casc/{fdid}?version={build}")
    if not data.startswith(b"BLP"):
        raise SystemExit(f"FileDataID {fdid} did not return a BLP (got {data[:16]!r})")
    try:
        return Image.open(io.BytesIO(data)).convert("RGBA")
    except Exception:
        return _blp2_raw_bgra(data, Image)


def cmd_extract(args: argparse.Namespace) -> int:
    """Save icons / atlas members as PNGs so the art can actually be eyeballed."""
    Image = _require_pillow()
    build = args.build or builds()["wow"]
    out_dir = Path(args.out)
    out_dir.mkdir(parents=True, exist_ok=True)

    members = sheets = None
    for target in args.targets:
        if target.isdigit():
            fdid = int(target)
            img = _blp_image(fdid, build, Image)
            label = f"fdid-{fdid}"
            detail = f"{img.width}x{img.height}"
        else:
            if members is None:
                members = {
                    r["CommittedName"].lower(): r
                    for r in db2("UiTextureAtlasMember", build, args.refresh)
                }
                sheets = {
                    r["ID"]: r for r in db2("UiTextureAtlas", build, args.refresh)
                }
            row = members.get(target.lower())
            if not row:
                print(f"no atlas member named {target!r}", file=sys.stderr)
                continue
            sheet = sheets[row["UiTextureAtlasID"]]
            img = _blp_image(int(sheet["FileDataID"]), build, Image).crop(
                (
                    int(row["CommittedLeft"]),
                    int(row["CommittedTop"]),
                    int(row["CommittedRight"]),
                    int(row["CommittedBottom"]),
                )
            )
            label = target.lower()
            detail = (
                f"{img.width}x{img.height} from atlas {row['UiTextureAtlasID']}"
                f" (fdid {sheet['FileDataID']})"
            )

        if args.scale > 1:
            img = img.resize(
                (img.width * args.scale, img.height * args.scale), Image.NEAREST
            )
        path = out_dir / f"{label}.png"
        img.save(path)
        print(f"{label}\t{detail}\t-> {path}")
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

    s = sub.add_parser(
        "extract",
        help="save icons / atlas members as PNGs (needs Pillow: uv run --with pillow)",
    )
    s.add_argument(
        "targets",
        nargs="+",
        metavar="FDID|ATLAS_MEMBER",
        help="all-digit args are FileDataIDs, anything else is an atlas member name",
    )
    s.add_argument("--out", default=str(CACHE_DIR.parent / "wago-icons"))
    s.add_argument("--scale", type=int, default=4, help="nearest-neighbour upscale")
    s.add_argument("--build", help="full build (default: latest Retail)")
    s.set_defaults(func=cmd_extract)

    s = sub.add_parser("builds", help="list the latest build per product")
    s.set_defaults(func=cmd_builds)

    args = p.parse_args(list(argv) if argv is not None else None)
    return args.func(args)


if __name__ == "__main__":
    sys.exit(main())
