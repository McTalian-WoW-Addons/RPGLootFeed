# RPGLootFeed conventions

## Structure

- Start every file `local addonName, ns = ...` then `local G_RLF = ns`.
- Capture `G_RLF` dependencies as locals at file top; never read `G_RLF.db` at file scope.
- Build modules with `FeatureBase:new(...)`; never `G_RLF.RLF:NewModule()` directly.
- End every module file with `G_RLF.X = X` and `return X`.
- Register new files in the `*.xml` include chain; `Core.lua` must load before any feature file.
- Prefix row mixin globals `RLF_`; order a mixin file header, `---@class`, `RLF_XxxMixin = {}`, methods, export.
- Size text with `SetWidth` + `SetWordWrap(false)`, not manual width math.
- `self:fn(...)` is deprecated; call directly with a guard clause.
- `LootDisplayProperties.lua` is deprecated; use `LootElementBase:fromPayload()`.

## WoW API

- Put every `C_*` call and `_G["KEY"]` lookup in `utils/WoWAPIAdapters.lua` under `G_RLF.WoWAPI.<Feature>`.
- Capture the adapter on the module as `_someAdapter`; this is the test injection seam.
- Confirm API signatures, events, and enums per flavor with `/wow-dev:wow-api`.
- Run `presence` from the `wago-datamining` skill on a FileDataID before hardcoding it.
- Guard non-universal assets and APIs with `G_RLF:IsRetail()` / `G_RLF:IsClassic()`.

## Strings

- User-facing text goes through `G_RLF.L["Key"]`, with the key added to `RPGLootFeed/locale/enUS.lua`.
- Add new keys under the current `--#region` block in the locale file.
- Never call `print()` outside specs, `.scripts/`, or `GameTestRunner.lua`; use `G_RLF:LogDebug`/`G_RLF:LogWarn`.
- Wrap alpha-only code (game testing, debug helpers) in `--@alpha@` blocks.

## Testing

- Mirror the source path under `RPGLootFeed_spec/` for every spec file.
- Load the module with `loadfile("RPGLootFeed/<path>")("TestAddon", ns)` and capture the return value.
- Inject fakes by overriding `Module._someAdapter` after `loadfile`.
- Run tests only through `make test*` targets; `busted` is not on `$PATH`.

## Packaging

- Only `RPGLootFeed/` ships; `.scripts/`, `_spec/`, `.github/`, `docs/` are dev-only.
- `git add` new files before `make dev`/`make build` — untracked files are skipped silently.
- Type commits by whether they touch the packaged `RPGLootFeed/` dir; see `/wow-dev:git-workflow`.
