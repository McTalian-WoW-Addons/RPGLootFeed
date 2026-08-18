# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

RPGLootFeed is a World of Warcraft addon (Lua) that replaces chat loot spam with a configurable scrolling loot feed. It ships for Retail and Classic flavors from a single codebase (`## Interface: 11509, 20506, 50504, 120007, 120100` in `RPGLootFeed/RPGLootFeed.toc`).

## Commands

Everything routes through `make` (`make help` lists targets). Python tooling runs via `uv`; Lua tooling lives in `~/.luarocks/bin`.

```bash
make test                                   # busted unit tests
make test-cov                               # + luacov HTML report in luacov-html/
make test-file FILE=RPGLootFeed_spec/Features/Currency_spec.lua
make test-pattern PATTERN="quantity mismatch"
make test-only                              # only tests tagged #only
make all_checks                             # hardcoded-string + missing-translation + i18n key checks
make i18n_fmt                               # sort/organize locale files
./trunk fmt && ./trunk check                # formatting + lint
make dev                                    # alpha build into ./.release
make watch                                  # rebuild on change
make lua_deps                               # install busted + rockspec deps (--local, lua 5.4)
```

- **Do not run `busted` directly** — it is not on `$PATH`. Always use the `make` targets.
- `wbt_setup` clones `wow-build-tools` to `../wow-build-tools` on demand; several targets depend on it. Build targets also need the `wow-build-tools` binary on `$PATH`.
- CONTRIBUTING.md mentions `make local`; that target no longer exists — use `make dev`.
- In-game: alpha builds run `SmokeTest` automatically on load; `/rlf i` runs the visual integration tests.

## Architecture

Read `.github/docs/architecture.md` first — it is detailed and current. Key points that shape most changes:

- **Namespace**: every file starts `local addonName, ns = ...` / `local G_RLF = ns`. `G_RLF.RLF` is the AceAddon instance created in `Core.lua`. Load order is defined by `RPGLootFeed.toc` and the nested `*.xml` include chains, and matters — `Core.lua` must run before any feature.
- **Ace3** provides addon/module structure, DB (`AceDB-3.0`, SavedVariable `RPGLootFeedDB`), options UI, events, hooks, timers, buckets.
- **Four-layer feature pipeline**: `G_RLF.WoWAPI.*` adapter → module `BuildPayload(...)` returning an `RLF_ElementPayload` → `LootElementBase:fromPayload(payload)` → `element:Show()`. Modules are created with `FeatureBase:new(name, ...)`, never `G_RLF.RLF:NewModule()` directly. `Features/TravelPoints.lua` is the reference implementation.
- **WoW API adapters**: all `C_*` calls and `_G["STRING_KEY"]` lookups live in `utils/WoWAPIAdapters.lua` under `G_RLF.WoWAPI.*`, captured on the module as `_someAdapter`. That field is the test injection seam — never call WoW APIs inline in feature code.
- **Dependency capture**: features capture `G_RLF` dependencies as locals at the top of the file. `G_RLF.db` is the deliberate exception — it is nil until `OnInitialize`, so always look it up inside function bodies.
- **Multi-frame**: config lives under `db.global.frames[id]` (up to 5 frames; frame 1 "Main" is undeletable). Features fire one `RLF_NEW_LOOT` message; each `LootDisplayFrame` is its own broker that decides whether to display it based on that frame's config. Per-frame config builders take `(frameId, order)` and close over the id.
- **Row rendering** uses the Blizzard XML mixin pattern: `LootDisplayRowTemplate.xml` composes `LootDisplayRowMixin` plus eight `RLF_Row*Mixin` sub-mixins. Row sub-mixin globals are prefixed `RLF_` to avoid `_G` collisions. Text sizing uses native engine truncation (`SetWidth` + `SetWordWrap(false)`), not manual width math.
- **`self:fn(...)`** (the xpcall wrapper on the module prototype) is deprecated — it swallows errors. Use direct calls with explicit guard clauses. `LootDisplayProperties.lua` is likewise deprecated in favor of `LootElementBase:fromPayload()`.

Other useful docs: `.github/docs/testing.md`, `glossary.md`, `multi-frame-design.md`, `module-rearchitecture.md`, `resources.md`.

## Testing

Specs live in `RPGLootFeed_spec/`, mirroring the addon tree. `.busted` preloads `RPGLootFeed_spec/_mocks/helper.lua`, which installs the Lua-compat polyfills and the `_G` WoW stubs (`Enum`, `Constants`, `C_Item`, `C_CurrencyInfo`, `C_Reputation`, …) — specs do not require them manually.

Typical pattern: load the module under test with `loadfile("RPGLootFeed/Features/X.lua")("TestAddon", ns)` using a mock `ns` from `_mocks/Internal/addonNamespace.lua`, then override `Module._someAdapter` to inject fakes. Row mixin tests build their stubbed frame from `_mocks/Internal/LootDisplayRowFrame.lua`. See `.github/docs/testing.md` for the full guide.

## Conventions

- **User-facing strings must be localized**: use `G_RLF.L["Key"]` and add the key to `RPGLootFeed/locale/enUS.lua`. `make all_checks` fails on hardcoded strings and missing locale keys.
- **No stray prints**: the custom trunk linter `no-invalid-prints` blocks them outside specs, `.scripts/`, and `GameTestRunner.lua`. Use `G_RLF:LogDebug/LogWarn/...`.
- **Alpha-only code** (game testing, debug helpers) is wrapped in `--@alpha@` preprocessor blocks.
- **Untracked files under `RPGLootFeed/` break in-game builds** — build targets run `check_untracked_files` and fail on them.
- **PR titles are commit messages and release notes.** Format `type: description`, lowercase description, one line, conventional types (`feat`, `fix`, `docs`, `refactor`, `test`, `ci`, `chore`, `style`, `perf`, `build`, `revert`, `locale`). See `docs/pr-title-rules.md`.
- Branch from `main`; CI (`.github/workflows/`) delegates to reusable `wow-build-tools` workflows.

## WoW API ground truth

Blizzard's UI source is checked out locally at `~/code/wow-ui-source` (branch per flavor: `live` = Retail, `classic` = MoP, `classic_era` = Vanilla). Use the `wow-api-researcher` subagent for questions about API signatures, events, enums, or how Blizzard's own UI does something, rather than recalling APIs from memory.

`wow-ui-source` covers API and UI _code_ only — it contains no asset listing. For **assets** (FileDataIDs, icons, texture atlases, texture kits, DB2 tables) use wago.tools via `.scripts/wago_lookup.py`; the `wago-datamining` skill has the full workflow and pitfalls.

- **Never hardcode a FileDataID without checking it ships to every flavor**: `uv run .scripts/wago_lookup.py presence <fdid>`. Each client carries a different asset subset — e.g. `236681` (the default reputation icon) is missing from TBC Anniversary, which predates achievements and ships no `Achievement_*` icons. Guard non-universal assets with `G_RLF:IsRetail()` / `G_RLF:IsClassic()`.
- **After a patch drops**, `uv run .scripts/wago_lookup.py audit` lists major faction texture kits missing from `majorFactionTextureKitIconMap`. Some factions never ship an icon file at all and are atlas-only.
- `presence` checks per-flavor shipping via `/api/casc/{fdid}?product=X` response body size (0 bytes = absent), not its HTTP status, which is always 200 regardless. Pass `--source listfile` to fall back to downloading and filtering the full per-product listfile instead. Always include a known-absent control in any presence check.
