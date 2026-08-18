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

Downloads are cached under .scripts/.output/wago-cache (gitignored). Listfiles
are large (Retail is ~40MB); the first call for a product is slow, subsequent
ones are instant.

Cache filenames carry the build they were fetched for, so a stale cache cannot
silently answer a question about a newer patch -- a new build is simply a file
that has not been downloaded yet. `cache` reports cached vs live builds, and
`cache --prune` drops superseded ones. If wago is unreachable the tool falls
back to the last known build list with a warning; --strict makes that an error.
Downloaded listfiles are validated (well-formed last row, minimum row count)
before being cached and retried on failure -- a truncated wago response used
to get cached as if it were the real thing, silently poisoning every lookup
against it.

`find` and `audit` source filenames from the GitHub community listfile
(github.com/wowdev/wow-listfile) by default: a single well-formed file behind
GitHub's CDN, cached by release tag, faster and more reliably complete than
wago's per-product download. It has NO per-product/per-build dimension --
finding a name there is not proof it ships anywhere. `presence` always stays
on wago's `/api/files`, the only source that can answer that. Pass `find
--source wago --flavor X` for a targeted, version-specific search scoped to
one product's live listfile instead.

IMPORTANT: https://wago.tools/api/casc/{fdid} always returns HTTP 200 whether
a file is present in the queried `product` or not -- status code alone tells
you nothing, which is how this endpoint earned a "useless for presence
checks" reputation. But the `product` param DOES filter, and the response
BODY SIZE is a reliable signal (0 bytes = absent, real bytes = present) --
verified against the authoritative /api/files listfile across a random
16-fdid x 4-product sample (64/64 correct). `presence` uses this by default
(one small request per fdid/flavor pair, no listfile download); pass
`--source listfile` to fall back to downloading and filtering the full
per-product listfile instead.
"""

import argparse
import csv
import gzip
import io
import json
import re
import sys
import time
import urllib.error
import urllib.request
from pathlib import Path
from typing import Callable, Dict, Iterable, List, Optional, Tuple

BASE = "https://wago.tools"
# wago.tools sits behind Cloudflare, which 403s urllib's default User-Agent.
UA = "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/125.0 Safari/537.36"

# Community-maintained, cross-product FileDataID -> filename index. Unlike
# wago's /api/files, this has no per-product/per-build dimension -- a name
# here is not proof a file ships to any flavor RPGLootFeed supports. Use it
# for name discovery (`find`, `audit`'s matching pass); `presence` always
# stays on wago's per-product listfile, which is the only source that can
# answer "does this flavor's client actually carry this file".
GITHUB_LISTFILE_REPO = "wowdev/wow-listfile"
GITHUB_LISTFILE_ASSET = "community-listfile.csv"
GITHUB_API = "https://api.github.com/"
GITHUB_DOWNLOADS = "https://github.com/"

# Row-count floors below which a downloaded listfile is almost certainly a
# truncated/error response rather than the real thing (wago's /api/files has
# 504'd mid-transfer and cached the partial body before; see _validate_listfile).
# Each product has a very different asset count -- Classic Era is ~1/12th of
# Retail's -- so these are ~85% of an observed-good count per product, not a
# single guessed number. Re-measure (`cache`) if a floor starts false-positiving.
MIN_LISTFILE_ROWS: Dict[str, int] = {
    "wow": 1_650_000,  # observed ~1,908,906 (12.1.0.69382)
    "wow_classic": 360_000,  # observed ~420,065 (5.5.4.69155)
    "wow_classic_era": 135_000,  # observed ~159,633 (1.15.9.69109)
    "wow_anniversary": 160_000,  # observed ~190,291 (2.5.6.69110)
}
MIN_GITHUB_LISTFILE_ROWS = 1_000_000  # observed ~2,210,170 (202608181116)

CACHE_DIR = Path(__file__).resolve().parent / ".output" / "wago-cache"

# Products matching the flavors RPGLootFeed ships to, keyed by the `## Interface`
# prefix in RPGLootFeed.toc. Keep in sync with the toc when a flavor is added.
FLAVORS: Dict[str, str] = {
    "Classic Era": "wow_classic_era",  # 11xxx
    "TBC Anniversary": "wow_anniversary",  # 20xxx
    "MoP Classic": "wow_classic",  # 50xxx
    "Retail": "wow",  # 12xxxx
}


_DEFAULT_ALLOWED_PREFIXES = (f"{BASE}/",)


def _fetch(
    url: str,
    timeout: int = 300,
    attempts: int = 4,
    allowed_prefixes: Tuple[str, ...] = _DEFAULT_ALLOWED_PREFIXES,
) -> bytes:
    """GET with retries.

    The listfile endpoints return multi-megabyte payloads and intermittently
    502/504 under load, so a bare urlopen is not reliable enough for a tool
    people will run unattended.
    """
    if not any(url.startswith(p) for p in allowed_prefixes):
        # Guards against file:// and other schemes reaching urlopen.
        raise ValueError(f"refusing to fetch url outside allowlist: {url}")

    last: Optional[Exception] = None
    # urllib does not negotiate compression on its own (unlike curl --compressed);
    # the listfile endpoints are large and highly repetitive CSV, so asking for
    # gzip and decompressing ourselves cuts transfer size and 504 exposure a lot.
    req = urllib.request.Request(
        url, headers={"User-Agent": UA, "Accept-Encoding": "gzip"}
    )
    for attempt in range(1, attempts + 1):
        try:
            # Scheme is pinned to the allowlist above.
            with urllib.request.urlopen(
                req, timeout=timeout
            ) as resp:  # nosec B310 # noqa: S310
                body = resp.read()
                if resp.headers.get("Content-Encoding", "").lower() == "gzip":
                    body = gzip.decompress(body)
                return body
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


def _validate_listfile_csv(raw: bytes, source: str, min_rows: int = 0) -> None:
    """Raise if `raw` looks like a truncated or error response, not a listfile.

    wago's /api/files has 504'd mid-transfer and returned a short body ending
    in a JSON error object rather than raising -- a bare fetch-then-cache
    silently accepts that as a valid (but wrong, incomplete) listfile, and
    every subsequent lookup answers from missing data with no indication
    anything is wrong. Catch the shape here instead.
    """
    text = raw.decode("utf-8", "replace")
    lines = [line for line in text.splitlines() if line.strip()]
    if not lines:
        raise RuntimeError(f"{source}: empty response")
    if not re.match(r"^\d+;", lines[-1]):
        raise RuntimeError(
            f"{source}: last line is not a well-formed 'fdid;name' row "
            f"(got {lines[-1][:80]!r}) -- response looks truncated or is an error body"
        )
    if min_rows and len(lines) < min_rows:
        raise RuntimeError(
            f"{source}: only {len(lines)} rows, expected at least {min_rows} -- "
            "response looks truncated"
        )


def _cached(
    name: str,
    url: str,
    refresh: bool = False,
    *,
    fetch_kwargs: Optional[dict] = None,
    validate: Optional[Callable[[bytes], None]] = None,
    validate_attempts: int = 3,
) -> bytes:
    CACHE_DIR.mkdir(parents=True, exist_ok=True)
    path = CACHE_DIR / name
    if path.exists() and not refresh:
        return path.read_bytes()
    sys.stderr.write(f"fetching {url} ...\n")
    fetch_kwargs = fetch_kwargs or {}
    last_err: Optional[RuntimeError] = None
    for attempt in range(1, validate_attempts + 1):
        data = _fetch(url, **fetch_kwargs)
        if validate is not None:
            try:
                validate(data)
            except RuntimeError as e:
                last_err = e
                if attempt < validate_attempts:
                    sys.stderr.write(
                        f"  {e} - retry {attempt}/{validate_attempts - 1}\n"
                    )
                    continue
                raise
        path.write_bytes(data)
        return data
    raise last_err  # pragma: no cover - loop always returns or raises


# How long a cached /api/builds/latest response is trusted before re-checking.
# Short enough to notice a patch the day it drops, long enough that a batch of
# subcommands in one sitting costs a single request.
BUILDS_TTL_SECONDS = 900
STRICT = False  # set from --strict; turn stale-cache fallbacks into errors


def builds(refresh: bool = False) -> Dict[str, str]:
    """Latest build version string per product.

    The endpoint returns either a bare version string or an object carrying
    `version` plus CDN config hashes, depending on the product; normalise both
    down to the version string.

    Cached with a short TTL, and falls back to the last good response if
    wago is unreachable -- being offline should degrade to "possibly stale",
    not "cannot run at all".
    """
    CACHE_DIR.mkdir(parents=True, exist_ok=True)
    path = CACHE_DIR / "builds-latest.json"
    fresh_enough = (
        path.exists() and (time.time() - path.stat().st_mtime) < BUILDS_TTL_SECONDS
    )
    raw = None
    if fresh_enough and not refresh:
        raw = json.loads(path.read_text())
    else:
        try:
            data = _fetch(f"{BASE}/api/builds/latest", timeout=60)
            path.write_bytes(data)
            raw = json.loads(data.decode())
        except Exception as e:  # noqa: BLE001
            if not path.exists():
                raise
            msg = (
                f"could not reach wago ({e}); using build list cached at {_mtime(path)}"
            )
            if STRICT:
                raise SystemExit(f"--strict: {msg}") from None
            sys.stderr.write(f"WARNING: {msg}\n")
            raw = json.loads(path.read_text())

    out: Dict[str, str] = {}
    for product, value in raw.items():
        if isinstance(value, dict):
            version = value.get("version")
            if version:
                out[product] = version
        elif isinstance(value, str):
            out[product] = value
    return out


def _mtime(path: Path) -> str:
    return time.strftime("%Y-%m-%d %H:%M", time.localtime(path.stat().st_mtime))


def _cached_builds_for(product: str) -> List[str]:
    """Builds of `product` already on disk, newest-looking last."""
    prefix = f"files-{product}-"
    found = [
        p.name[len(prefix) : -len(".csv")] for p in CACHE_DIR.glob(f"{prefix}*.csv")
    ]
    return sorted(found, key=_version_key)


def _version_key(version: str):
    return tuple(int(part) if part.isdigit() else 0 for part in version.split("."))


def listfile(product: str, refresh: bool = False) -> List[Tuple[int, str]]:
    """Every file present in a product's current build, as (fdid, filename).

    The build is baked into the cache filename, so a patch cannot be served
    from a stale cache -- a new build is simply a different file that has not
    been downloaded yet. This is deliberate: silently answering "is this icon
    in the game" from last patch's data is the failure mode most likely to
    produce a confidently wrong result.
    """
    try:
        build = builds().get(product)
    except Exception:  # noqa: BLE001
        build = None

    if not build:
        cached = _cached_builds_for(product)
        if not cached:
            raise SystemExit(
                f"cannot determine the current build for {product} and nothing "
                f"is cached for it -- check network access to {BASE}"
            )
        build = cached[-1]
        msg = f"using cached {product} build {build}; could not confirm it is current"
        if STRICT:
            raise SystemExit(f"--strict: {msg}")
        sys.stderr.write(f"WARNING: {msg}\n")

    name = f"files-{product}-{build}.csv"
    if not (CACHE_DIR / name).exists() and not refresh:
        superseded = [b for b in _cached_builds_for(product) if b != build]
        if superseded:
            sys.stderr.write(
                f"{product}: new build {build} (cached: {', '.join(superseded)});"
                " downloading current listfile\n"
            )

    raw = _cached(
        name,
        f"{BASE}/api/files?product={product}&format=csv",
        refresh,
        validate=lambda data: _validate_listfile_csv(
            data, name, MIN_LISTFILE_ROWS.get(product, 0)
        ),
    )
    out: List[Tuple[int, str]] = []
    for line in raw.decode("utf-8", "replace").splitlines():
        fdid, _, name = line.partition(";")
        try:
            out.append((int(fdid), name.strip().strip('"')))
        except ValueError:
            continue
    return out


def _github_release_meta(refresh: bool = False) -> dict:
    """Latest wow-listfile release metadata, short-TTL cached like builds()."""
    CACHE_DIR.mkdir(parents=True, exist_ok=True)
    path = CACHE_DIR / "github-listfile-release.json"
    fresh_enough = (
        path.exists() and (time.time() - path.stat().st_mtime) < BUILDS_TTL_SECONDS
    )
    if fresh_enough and not refresh:
        return json.loads(path.read_text())
    try:
        data = _fetch(
            f"{GITHUB_API}repos/{GITHUB_LISTFILE_REPO}/releases/latest",
            timeout=60,
            allowed_prefixes=(GITHUB_API,),
        )
        path.write_bytes(data)
        return json.loads(data.decode())
    except Exception as e:  # noqa: BLE001
        if not path.exists():
            raise
        msg = f"could not reach GitHub ({e}); using release metadata cached at {_mtime(path)}"
        if STRICT:
            raise SystemExit(f"--strict: {msg}") from None
        sys.stderr.write(f"WARNING: {msg}\n")
        return json.loads(path.read_text())


def github_listfile(refresh: bool = False) -> List[Tuple[int, str]]:
    """Cross-product FileDataID -> filename index from wowdev/wow-listfile.

    This has NO per-product/per-build dimension: a name here does not mean the
    file ships to any flavor RPGLootFeed supports, only that it exists in some
    WoW build wowdev has indexed (Retail, Classic, PTR, beta, ...). It is a
    faster and more reliable name-discovery source than wago's per-product
    listfile (a single well-formed file behind GitHub's CDN, no Cloudflare
    UA-sniffing, no observed truncation), but it can never answer `presence` --
    that still requires wago's `/api/files`.

    Cached by release tag, same build-pinning approach as listfile(): a new
    wowdev release is simply a file that has not been downloaded yet.
    """
    meta = _github_release_meta(refresh)
    tag = meta.get("tag_name", "unknown")
    asset = next(
        (a for a in meta.get("assets", []) if a.get("name") == GITHUB_LISTFILE_ASSET),
        None,
    )
    if asset is None:
        raise SystemExit(
            f"wow-listfile release {tag} has no asset named {GITHUB_LISTFILE_ASSET}"
        )

    name = f"github-listfile-{tag}.csv"
    raw = _cached(
        name,
        asset["browser_download_url"],
        refresh,
        fetch_kwargs={
            "allowed_prefixes": (
                GITHUB_DOWNLOADS,
                "https://objects.githubusercontent.com/",
            )
        },
        validate=lambda data: _validate_listfile_csv(
            data, name, MIN_GITHUB_LISTFILE_ROWS
        ),
    )
    out: List[Tuple[int, str]] = []
    for line in raw.decode("utf-8", "replace").splitlines():
        fdid, _, fname = line.partition(";")
        try:
            out.append((int(fdid), fname.strip().strip('"')))
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


def _resolve_filename(fdid: int) -> str:
    """FileDataID -> filename via /api/info, or a placeholder on failure.

    A FileDataID absent from every product/build 500s persistently; `_fetch`
    retries that to exhaustion and raises RuntimeError, not HTTPError, so
    catching only HTTPError here would let a bad ID crash the whole command
    instead of just leaving its name unresolved.
    """
    try:
        data = json.loads(_fetch(f"{BASE}/api/info/{fdid}", timeout=60).decode())
        return data.get("filename") or "<unknown>"
    except (urllib.error.HTTPError, RuntimeError):
        return "<unknown>"


def cmd_info(args: argparse.Namespace) -> int:
    for fdid in args.fdids:
        print(f"{fdid}\t{_resolve_filename(fdid)}")
    return 0


def _casc_presence(fdid: int, product: str, timeout: int = 30) -> Optional[bool]:
    """True if `fdid` ships in `product`'s current build, False if confirmed
    absent, None if the query itself failed (bad FileDataID, network error).

    Uses /api/casc/{fdid}?product=X and the response BODY SIZE, not the HTTP
    status: the endpoint returns HTTP 200 both when the file is present (real
    bytes) and when it is absent from that product (0 bytes) -- status code
    alone cannot tell those apart, which is how this endpoint earned a
    "useless for presence checks" reputation. Verified against the
    authoritative /api/files listfile across a random 16-fdid x 4-product
    sample (64/64 correct) before this was trusted for real lookups. A
    completely invalid FileDataID (not present in ANY product/build) 500s
    instead of 200-with-empty-body; that case returns None here, not False,
    so a typo'd ID is not silently reported as "absent".
    """
    url = f"{BASE}/api/casc/{fdid}?product={product}"
    req = urllib.request.Request(
        url, headers={"User-Agent": UA, "Accept-Encoding": "gzip"}
    )
    try:
        with urllib.request.urlopen(req, timeout=timeout) as resp:  # nosec B310
            body = resp.read()
            if resp.headers.get("Content-Encoding", "").lower() == "gzip":
                body = gzip.decompress(body)
            return len(body) > 0
    except (urllib.error.HTTPError, urllib.error.URLError, TimeoutError):
        return None


def _presence_via_casc(args: argparse.Namespace, flavors: Dict[str, str]) -> int:
    names = {fdid: _resolve_filename(fdid) for fdid in args.fdids}

    width = max((len(lbl) for lbl in flavors), default=10)
    print(
        f"{'fdid':<10} {'file':<58} " + " ".join(f"{lbl:<{width}}" for lbl in flavors)
    )
    missing_anywhere = False
    errored = False
    for fdid in args.fdids:
        cells = []
        for _label, product in flavors.items():
            present = _casc_presence(fdid, product)
            if present is None:
                cells.append(f"{'ERR':<{width}}")
                errored = True
            else:
                cells.append(f"{'yes' if present else 'NO':<{width}}")
                if not present:
                    missing_anywhere = True
        print(f"{fdid:<10} {names.get(fdid, '<unknown>'):<58} " + " ".join(cells))
    if errored:
        print(
            "\nAt least one query errored (network issue, or a FileDataID that "
            "does not exist in any product/build). Rerun, or pass "
            "`--source listfile` to cross-check against the full downloaded "
            "listfile instead.",
            file=sys.stderr,
        )
    if missing_anywhere:
        print(
            "\nAt least one file is absent from a shipped flavor. Guard its use "
            "with G_RLF:IsRetail()/IsClassic(), or pick a different asset.",
            file=sys.stderr,
        )
    return 0


def _presence_via_listfile(args: argparse.Namespace, flavors: Dict[str, str]) -> int:
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


def cmd_presence(args: argparse.Namespace) -> int:
    flavors = _selected_flavors(args)
    if args.source == "listfile":
        return _presence_via_listfile(args, flavors)
    return _presence_via_casc(args, flavors)


def cmd_find(args: argparse.Namespace) -> int:
    pattern = re.compile(args.pattern, re.I)
    if args.source == "github":
        rows = github_listfile(args.refresh)
        scope = "GitHub community listfile (cross-product -- not a presence check)"
    else:
        rows = listfile(FLAVORS[args.flavor], args.refresh)
        scope = args.flavor
    hits = [(f, n) for f, n in rows if pattern.search(n)]
    if args.icons_only:
        hits = [(f, n) for f, n in hits if n.startswith("interface/icons/")]
    for fdid, name in hits[: args.limit]:
        print(f"{fdid}\t{name}")
    print(
        f"\n{len(hits)} match(es) in {scope}"
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
    # Sourced from the GitHub community listfile rather than wago's per-product
    # listfile: this pass is name discovery, not a presence check, and the
    # cross-product file is a faster, more reliably-complete download. Any
    # FileDataID this surfaces still needs `presence` before being hardcoded.
    ui_icons: List[Tuple[int, str, str]] = []
    for fdid, name in github_listfile(args.refresh):
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


def cmd_cache(args: argparse.Namespace) -> int:
    """Inspect, refresh, or prune the local listfile cache."""
    CACHE_DIR.mkdir(parents=True, exist_ok=True)
    flavors = _selected_flavors(args)
    latest = builds(refresh=True) if args.refresh else builds()

    if args.refresh:
        for label, product in flavors.items():
            build = latest.get(product, "?")
            sys.stderr.write(f"--- {label} ({product}) {build}\n")
            listfile(product, refresh=True)
        sys.stderr.write("--- GitHub community listfile\n")
        github_listfile(refresh=True)

    if args.prune:
        removed = 0
        for product in FLAVORS.values():
            current = latest.get(product)
            for build in _cached_builds_for(product):
                if build != current:
                    (CACHE_DIR / f"files-{product}-{build}.csv").unlink()
                    print(f"pruned {product} {build}")
                    removed += 1
            # Listfiles cached before builds were baked into the filename.
            legacy = CACHE_DIR / f"files-{product}.csv"
            if legacy.exists():
                legacy.unlink()
                print(f"pruned {product} (legacy un-pinned cache)")
                removed += 1
        try:
            current_tag = _github_release_meta().get("tag_name")
            for path in CACHE_DIR.glob("github-listfile-*.csv"):
                if path.name != f"github-listfile-{current_tag}.csv":
                    path.unlink()
                    print(f"pruned {path.name} (superseded wow-listfile release)")
                    removed += 1
        except Exception as e:  # noqa: BLE001
            sys.stderr.write(
                f"WARNING: could not check wow-listfile release, skipping its prune: {e}\n"
            )
        print(f"{removed} superseded listfile(s) removed")

    width = max(len(lbl) for lbl in FLAVORS)
    print(f"\n{'flavor':<{width}}  {'current build':<18} {'cached':<18} status")
    for label, product in FLAVORS.items():
        current = latest.get(product, "?")
        cached = _cached_builds_for(product)
        path = CACHE_DIR / f"files-{product}-{current}.csv"
        if path.exists():
            status = f"ok (fetched {_mtime(path)})"
            have = current
        elif cached:
            status = "STALE - will re-download on next use"
            have = cached[-1]
        else:
            status = "not cached - will download on first use"
            have = "-"
        print(f"{label:<{width}}  {current:<18} {have:<18} {status}")

    try:
        gh_tag = _github_release_meta().get("tag_name", "?")
    except Exception as e:  # noqa: BLE001
        gh_tag = f"? ({e})"
    gh_path = CACHE_DIR / f"github-listfile-{gh_tag}.csv"
    gh_status = (
        f"ok (fetched {_mtime(gh_path)})"
        if gh_path.exists()
        else "not cached - will download on first use"
    )
    print(f"{'GitHub listfile':<{width}}  {gh_tag:<18} {'' :<18} {gh_status}")

    db2_files = sorted(CACHE_DIR.glob("db2-*.csv"))
    if db2_files:
        print(
            f"\n{len(db2_files)} cached DB2 export(s); these are build-pinned by name:"
        )
        for p in db2_files:
            print(f"  {p.name}")
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
    p.add_argument(
        "--strict",
        action="store_true",
        help="fail instead of falling back to a cache whose build cannot be confirmed current",
    )
    sub = p.add_subparsers(dest="cmd", required=True)

    s = sub.add_parser("info", help="resolve FileDataID(s) to filenames")
    s.add_argument("fdids", nargs="+", type=int)
    s.set_defaults(func=cmd_info)

    s = sub.add_parser("presence", help="check FileDataID presence per shipped flavor")
    s.add_argument("fdids", nargs="+", type=int)
    s.add_argument("--flavor", choices=list(FLAVORS), help="limit to one flavor")
    s.add_argument(
        "--source",
        default="casc",
        choices=["casc", "listfile"],
        help=(
            "casc = one small /api/casc request per fdid/flavor pair, no "
            "listfile download (default); listfile = download and filter the "
            "full per-product listfile, for cross-checking a casc result you "
            "don't trust"
        ),
    )
    s.set_defaults(func=cmd_presence)

    s = sub.add_parser("find", help="search a filename index by regex")
    s.add_argument("pattern")
    s.add_argument(
        "--source",
        default="github",
        choices=["github", "wago"],
        help=(
            "github = cross-product community listfile, fast, NOT a presence "
            "check (default); wago = one product's live listfile, for a "
            "targeted, version-specific search (combine with --flavor)"
        ),
    )
    s.add_argument(
        "--flavor",
        default="Retail",
        choices=list(FLAVORS),
        help="only used with --source wago",
    )
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

    s = sub.add_parser(
        "cache", help="show cache status; optionally refresh or prune it"
    )
    s.add_argument("--refresh", action="store_true", help="re-download listfiles")
    s.add_argument("--prune", action="store_true", help="delete superseded builds")
    s.add_argument(
        "--flavor", choices=list(FLAVORS), help="limit --refresh to one flavor"
    )
    s.set_defaults(func=cmd_cache)

    args = p.parse_args(list(argv) if argv is not None else None)
    global STRICT
    STRICT = args.strict
    return args.func(args)


if __name__ == "__main__":
    sys.exit(main())
