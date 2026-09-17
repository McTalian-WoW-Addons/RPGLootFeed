---
name: add-feature-module
description: Add a new RPGLootFeed feature module end to end — WoWAPI adapter, FeatureBase module with BuildPayload, XML include registration, optional per-frame config builder, locale keys, lightweight spec — following the TravelPoints reference. Trigger on /add-feature-module <Name>, or "add a feature for X loot", "new feature module".
argument-hint: <Name>
---

# /add-feature-module — add a new RPGLootFeed feature module

## Read first

- `.github/docs/architecture.md` §Feature Module Pattern
- `.github/docs/testing.md` §Lightweight Feature Module Tests
- `docs/agent/conventions.md`
- `RPGLootFeed/Features/TravelPoints.lua` — reference implementation

## Steps

1. Confirm the API/event exists per flavor: `/wow-dev:wow-api`.
2. Add the adapter table `G_RLF.WoWAPI.<Name>` to `RPGLootFeed/utils/WoWAPIAdapters.lua`; wrap every `C_*` call and `_G["KEY"]` lookup the feature needs.
3. Add `<Name> = "<Name>",` to `G_RLF.FeatureModule` in `RPGLootFeed/utils/Enums.lua`. Create `RPGLootFeed/Features/<Name>.lua`: header (`local addonName, ns = ...` / `local G_RLF = ns`), dependency locals, `local <Name> = FeatureBase:new(FeatureModule.<Name>, "AceEvent-3.0", ...)`, capture the adapter as `<Name>._<x>Adapter`, a `BuildPayload` method returning `RLF_ElementPayload`, `LootElementBase:fromPayload(payload):Show()` on the trigger event, `G_RLF.<Name> = <Name>` and `return <Name>`.
4. Register `<Script file="<Name>.lua"/>` in `RPGLootFeed/Features/features.xml`, after the `_Internals/internals.xml` include that loads `FeatureBase`.
5. When the feature has per-frame options, add `RPGLootFeed/config/Features/<Name>Config.lua` with `G_RLF.Build<Name>Args(frameId, order)`, following `TravelPointsConfig.lua`.
6. Add any user-facing string as a key: `/wow-dev:add-locale-key`.
7. Add `RPGLootFeed_spec/Features/<Name>_spec.lua` mirroring `TravelPoints_spec.lua`.
8. `git add` every new file — untracked files are skipped silently at build.
9. Run the full check sequence: `/wow-dev:run-checks`.
10. Verify in-game: `/rlf test`; the alpha build also runs SmokeTest on load.

## Owners

Delegate steps 2-5 to `wow-dev:lua-feature-builder` and step 7 to `wow-dev:spec-author`; roles and boundaries: `${CLAUDE_PLUGIN_ROOT}/ROSTER.md`.
