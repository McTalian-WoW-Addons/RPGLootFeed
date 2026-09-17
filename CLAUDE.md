# RPGLootFeed

WoW addon (Lua, Ace3): scrolling loot feed. Flavors from `RPGLootFeed/RPGLootFeed.toc` `## Interface`. Shared workflow: `wow-dev` plugin skills.

## Commands

`make help` lists targets. Checks: `/wow-dev:run-checks`. Only via make: `make test`, `make test-file FILE=…`, `make all_checks`, `make toc_check`, `make dev`; `./trunk fmt && ./trunk check`.
In-game: alpha build runs SmokeTest on load; `/rlf i` integration tests; `/rlf test` test mode.

## Conventions

- Pipeline: `G_RLF.WoWAPI.*` adapter → `Module:BuildPayload()` → `RLF_ElementPayload` → `LootElementBase:fromPayload():Show()`.
- Modules via `FeatureBase:new(...)`; end files with `G_RLF.X = X` and `return X`.
- All `C_*`/`_G["KEY"]` calls in `utils/WoWAPIAdapters.lua`; capture as `_someAdapter`.
- Capture `G_RLF` deps as locals; never `G_RLF.db` (nil until OnInitialize).
- Strings via `G_RLF.L["Key"]` + key in `locale/enUS.lua`; no `print()`; `G_RLF:LogDebug`.
- New files: register in `*.xml` chain and `git add` before building.
- FileDataIDs: `wago-datamining` skill `presence` first; guard with `IsRetail()/IsClassic()`.
  Full list: `docs/agent/conventions.md`.

## Docs

- `.github/docs/architecture.md` — any structural change; load order; feature pattern.
- `.github/docs/testing.md` — writing specs; mocks; loadfile pattern.
- `.github/docs/multi-frame-design.md` — frames, per-frame config, `db.global.frames[id]`.
- `docs/pr-title-rules.md` — PR titles; merge labels.
- `/wow-dev:wow-api` — API/event/enum per flavor (`~/code/wow-ui-source`).
- `.claude/skills/add-feature-module` — new feature module.
