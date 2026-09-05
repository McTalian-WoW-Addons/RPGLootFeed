# Agent decisions

Rationale only. Not read by skills or agents.

## Why self:fn is deprecated

`self:fn(...)` is the xpcall wrapper on the module prototype. It is deprecated because it
swallows errors — a failure inside the wrapped call is silently caught instead of
surfacing. Use direct calls with explicit guard clauses instead.

## Why G_RLF.db is not captured

Every other `G_RLF` dependency is captured as a local at the top of a feature file.
`G_RLF.db` is the deliberate exception: it is `nil` until `OnInitialize` runs, so a
top-of-file capture would just be `nil` forever. Always look it up inside function
bodies instead.

## Why FeatureBase not NewModule

Modules are created via `FeatureBase:new(name, ...)`, never `G_RLF.RLF:NewModule()`
directly. No further rationale for this specific rule is recorded anywhere in the repo
docs today — CLAUDE.md states the rule but not the reason, and
`.github/docs/module-rearchitecture.md`'s "Key Decisions" cover a different, related
choice (generic `LootElementBase:fromPayload()` over per-module `Element:new()`
constructors — chosen to enforce a uniform contract, reduce duplication, and let one
set of tests cover every module's element construction), not the `FeatureBase` vs
`NewModule` choice itself.

## wago presence check mechanics

`/api/casc/{fdid}?product=X` always returns HTTP 200, whether the file is present or
absent for that product — status code alone is useless for presence. The `product`
param does filter the response, though, and response body size is a reliable signal:
0 bytes means absent from that product, real bytes means present. This was verified
against the authoritative `/api/files` listfile across a random 16-fdid x 4-product
sample (64/64 correct). `presence` uses this casc/body-size check by default — one
small request per fdid/flavor pair, no listfile download needed. A FileDataID absent
from every product/build 500s instead of returning 200-with-empty-body; `presence`
reports that case as `ERR`, distinct from a confirmed-absent `NO`, so a network/typo
failure is never conflated with a real negative. `presence --source listfile` falls
back to the older download-and-filter approach when a casc result looks wrong.
Cloudflare 403s the default urllib/python User-Agent, so the script sets a browser
User-Agent on its requests. Separately, BLP2 encoding 3 (raw BGRA) breaks Pillow with
"Unknown BLP encoding 3", and the major faction atlas sheets all use it — `extract`
handles this encoding explicitly; anything else that decodes BLPs needs to as well.

## Listfile caching incidents

Cached listfiles are build-pinned by filename, so a patch cannot be answered from the
previous patch's cached data — a new build is simply a file that has not been
downloaded yet, and it re-downloads itself on next use.

A truncated download used to get cached as if it were the real listfile: wago has
504'd mid-transfer and returned a short body ending in a JSON error object, and a bare
fetch-then-cache accepted that silently. Every lookup afterward then answered from
incomplete data with no sign anything was wrong — this produced a false "no icon"
verdict for 12.1's `zuljarra` and `radiantcore` kits before anyone noticed. The script
now validates a downloaded listfile (last line is a well-formed `fdid;name` row, row
count above a per-product floor) before caching it, and retries a bad response
automatically. If a lookup ever looks implausibly sparse anyway, `--refresh` forces a
redownload.

## Faction icon naming irregularities

Faction icon filenames are wildly inconsistent — all of the following are real in
12.1: `ui_majorfactions_storm.blp` (plural), `ui_majorfaction_storm.blp` (singular),
`ui_majorfactions_nightfall.blp` but with a stray space after the underscore,
`ui_majorfaction_renown_zuljarrasforces.blp` (`renown_` inserted, and the kit name is
only a prefix), and `ui_prey.blp` / `ui_delves.blp` (no `majorfaction` substring at
all). No single pattern reliably matches every kit.

Alias kits compound this: `denizens`, `gold`, and `vines` are Dream Wardens, Silvermoon
Court, and Hara'ti respectively, already mapped under different keys (`dream`,
`light`, `root`) pointing at the same FileDataIDs. The audit dedupes on FileDataID, so
an alias only surfaces as new work if it genuinely ships new art.

## CONTRIBUTING drift

`CONTRIBUTING.md` documented `make local` for packaging, but that target no longer
exists in the Makefile — the correct target is `make dev`. It also told contributors
to run `busted` and `luarocks luacov` directly, which contradicts both
`RPGLootFeed/CLAUDE.md` and the actual Makefile: the `busted` binary lives under
`~/.luarocks/bin`, is not on `$PATH`, and must always be invoked through `make test` /
`make test-cov` / etc. Its "Getting Started" issue link also pointed at
`github.com/RPGLootFeed/issues`, missing the `McTalian-WoW-Addons/` org prefix used
everywhere else (e.g. the `.toc`'s `X-GitHub` field). All three have been corrected in
`CONTRIBUTING.md`.
