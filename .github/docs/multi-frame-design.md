# Multi-Frame Loot Display — Architecture Reference

## Overview

RPGLootFeed uses a dynamic, user-managed collection of named **Loot Frames**.
Each frame is a fully self-contained unit: its own positioning, sizing,
styling, animation settings, and feature configurations. From the user's
perspective, configuring a frame means selecting it and seeing all of its
appearance and feature settings in one place.

The **Main frame** (ID 1) is always present and protected from deletion, but
can be renamed. All other frames are freely created, renamed, and deleted.
Up to **5 frames** total.

### Goals

- Allow users to create purpose-specific feeds (e.g. "Gear", "Currency",
  "Group", "Currencies + Money").
- Each frame is fully independent: its own appearance AND feature settings.
  The same feature (e.g. Reputation) can appear in multiple frames with
  different settings per frame.
- Simplify the options UI: top-level is Global / Frames / Blizz / About.
  All per-frame settings live under each frame's entry.
- Maintain backward compatibility: users who never touch the new feature
  should see no change.

---

## Design Decisions

| #   | Topic              | Decision                                                                                                                                                                   |
| --- | ------------------ | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Q1  | Frame identity     | Integer IDs (1, 2, 3…) with a separate `name` display string. IDs are never reused after deletion (`nextFrameId` is monotonically increasing).                             |
| Q2  | Feature routing    | Per-frame broker. Each frame owns a `features` table with full per-feature config. Feature modules fire unified `RLF_NEW_LOOT`; each frame's broker filters independently. |
| Q3  | Max frames         | 5 (initial hard cap).                                                                                                                                                      |
| Q4  | Main frame rename  | Allowed. Deletion guard is `id == 1`, not an `isProtected` flag.                                                                                                           |
| Q5  | Animations         | Per-frame (inside the frame's DB structure).                                                                                                                               |
| Q6  | Deletion safety    | Destroys widget + removes DB entry. Feature modules don't know about frames — they broadcast events; frames self-manage.                                                   |
| Q7  | WoW frame names    | Anonymous (`nil` name in `CreateFrame`). Internal refs in `lootFrames[id]`. `G_RLF.RLF_MainLootFrame` remains as a global alias for frame 1.                               |
| Q8  | AceConfig options  | Full `args` table rebuild + `NotifyChange` on frame list changes. No closure-driven state.                                                                                 |
| Q9  | Loot History       | Deferred to a future phase. Current global history unchanged.                                                                                                              |
| Q10 | Feature settings   | Per-frame, not global. Each frame can have different quality thresholds, sounds, text styles, etc.                                                                         |
| Q11 | Message channel    | Unified `RLF_NEW_LOOT` (no separate `RLF_NEW_PARTY_LOOT`). Element `type` distinguishes loot kinds.                                                                        |
| Q12 | Global override    | None. Each frame independently enables/disables features. Module active if **any** frame needs it.                                                                         |
| Q13 | New frame defaults | All features disabled. Appearance copied from Main as a starting point.                                                                                                    |

---

## Config UI Structure

```
Root (group, childGroups = "select")
├── ⚙ Global
│   ├── Quick Actions (test mode, clear rows, loot history)
│   ├── Show '1' Quantity, Hide All Icons, Minimap Icon, etc.
│   ├── Blizzard Overrides
│   └── About
├── Main (frame 1, childGroups = "tree")
│   ├── Appearance (sub-group, childGroups = "tree")
│   │   ├── Positioning
│   │   ├── Sizing
│   │   ├── Styling
│   │   └── Animations
│   └── Loot Feeds (sub-group, childGroups = "tree")
│       ├── Item Loot (enable toggle + all settings)
│       ├── Party Loot
│       ├── Currency
│       ├── Money
│       ├── Experience
│       ├── Reputation
│       ├── Professions
│       ├── Travel Points
│       └── Transmog
├── [User Frame 2] (same structure as Main)
├── + New Frame (input + execute button)
└── Manage Frames (rename/delete controls)
```

- AceConfig `select` childGroups does **not** support dividers — ordering and
  naming conventions (e.g. "⚙ Global") provide visual grouping.
- "Manage Frames" and "+ New Frame" are sorted to the end (orders 98, 99).
- Per-frame groups use `order = 10 + id` to avoid collision with `global`
  (order 1).

---

## DB Schema

```lua
db.global.frames = {
    [1] = {
        name        = "Main",
        positioning = { anchorPoint, relativePoint, xOffset, yOffset, frameStrata },
        sizing      = { feedWidth, maxRows, rowHeight, padding, iconSize },
        styling     = { textAlignment, growUp, fonts, colors, backdrop, border, … },
        animations  = { enter = {…}, exit = {…}, hover = {…}, update = {…} },
        features    = {
            itemLoot    = { enabled = true,  itemQualitySettings, sounds, textStyleOverrides, … },
            partyLoot   = { enabled = false, itemQualityFilter, hideServerNames, … },
            currency    = { enabled = true,  currencyTotalTextEnabled, colors, … },
            money       = { enabled = true,  showMoneyTotal, accountantMode, … },
            experience  = { enabled = true,  experienceTextColor, showCurrentLevel, … },
            reputation  = { enabled = true,  defaultRepColor, enableRepLevel, … },
            profession  = { enabled = true,  showSkillChange, skillColor, … },
            travelPoints = { enabled = true, textColor, … },
            transmog    = { enabled = true,  enableTransmogEffect, … },
        },
    },
    [2] = { … },  -- user-created frames
}
db.global.nextFrameId = 3   -- monotonically increasing; never reused
```

### AceDB defaults

The canonical defaults live in `defaults.global.frames["**"]` (the AceDB
wildcard). This provides inherited defaults for **all** frame IDs — including
frame 1 (explicitly written by migration v8). New config keys added to `"**"`
are automatically inherited by all existing frames without a migration.

**Why `"**"`over`"_"`**: Frame 1 is explicitly written by migration v8.
`"_"`only applies to keys not explicitly defined in the defaults table.`"\*\*"` inherits into all siblings, so even frame 1 gets defaults for new keys
added in future versions.

**Proxy depth**: AceDB proxy depth works correctly through 5+ levels of
nesting (e.g. `frames[1].features.itemLoot.sounds.mounts.enabled`) — no
nested `"**"` keys needed. Verified in-game.

**Default-change migration rule**: AceDB's `__index` means unsaved keys
automatically track code-side default changes — no migration needed.
Migrations are only required when changing defaults for data that was
**explicitly written** to SavedVariables (e.g. by migration v8).

### Migration v8

Migration v8 copies pre-multi-frame settings into `frames[1].*`:

- `db.global.positioning/sizing/styling/animations` → `frames[1].*`
- `db.global.item` → `frames[1].features.itemLoot`, etc. (all 9 features)
- If `db.global.partyLoot.separateFrame` was true, creates `frames[2]` with
  the party frame's appearance settings and party loot enabled.

The migration is **self-contained**: a local `LEGACY_DEFAULTS` table in
`v8.lua` mirrors all old AceDB defaults, using `pick(source.field,
LEGACY_DEFAULTS.key.field)` so it produces correct output even when old
default declarations have been removed (e.g. user jumping from v6 → v10).

**`"**"`guard fix**: The wildcard causes`frames[1]`to never be`nil`(AceDB proxy returns a table for any key). The migration checks`f1 == nil or f1.name == ""`instead, since`"\*\*"`defaults`name`to`""`and migration v8 writes`"Main"`.

Old top-level keys (`db.global.item`, `db.global.positioning`, etc.) are
preserved in SavedVariables by migration v8 — it does not delete the
originals. A future migration could nil them out to reduce SavedVariables
size.

---

## Event & Routing Architecture

```
Feature module → registers for WoW events (active if ANY frame needs it)
Feature module → fires RLF_NEW_LOOT (unified channel)
LootDisplayFrame broker → receives RLF_NEW_LOOT
LootDisplayFrame broker → checks frames[id].features[key].enabled
LootDisplayFrame broker → applies per-frame filters (quality, etc.)
LootDisplayFrame broker → displays row or discards
```

Each `LootDisplayFrame` is a self-contained subscriber. Adding/removing a frame
automatically adds/removes a broker. `LootDisplay` remains as the lifecycle
manager (creates/destroys frames, manages row pools) but is no longer the
central routing authority.

### Feature module lifecycle

A feature module is **enabled** when at least one frame has it enabled, and
**disabled** when no frame does. Checked at startup (`OnInitialize`), when a
feature toggle changes, and when a frame is created or deleted. Implemented
via `DbAccessor:IsFeatureNeededByAnyFrame(featureKey)`.

---

## Implementation History

All phases are complete.

| Phase | Description                          | Summary                                                                       |
| ----- | ------------------------------------ | ----------------------------------------------------------------------------- |
| 1     | DB schema + migration v8             | Copies all settings into `frames[1].*`. `DbAccessor:Feature()` added.         |
| 2     | Per-frame broker + unified message   | `RLF_NEW_PARTY_LOOT` collapsed into `RLF_NEW_LOOT`. Each frame owns a broker. |
| 3     | Feature configs → per-frame builders | All 9 `*Config.lua` export `Build*Args(frameId, order)`.                      |
| 4a    | Global group consolidation           | General, Blizzard UI, About under single `⚙ Global` group.                    |
| 4b    | Per-frame groups                     | Appearance + Loot Feeds tree structure per frame.                             |
| 4c    | Root select + frame management       | Dropdown navigation, "+ New Frame" / "Manage Frames" root groups.             |
| 5     | Feature module lifecycle             | `OnInitialize` uses `IsFeatureNeededByAnyFrame()`.                            |
| 5b    | Harden migration v8                  | `LEGACY_DEFAULTS` for self-contained migration.                               |
| 5c    | `"**"` wildcard defaults             | Runtime fallback for all frame config keys.                                   |
| 5d    | Integration test fixes               | Multi-frame routing in integration tests.                                     |
| 6a    | Migrate reads to per-frame paths     | All production code reads via `DbAccessor`.                                   |
| 6b    | Dead code removal                    | Removed `Frames.PARTY`, `RLF_PartyLootFrame`, old defaults, legacy fallbacks. |
| 6c    | Documentation updates                | Wiki, architecture.md updated. Design doc compacted.                          |

### Key files affected

| Area                | Files                                                                                                                        |
| ------------------- | ---------------------------------------------------------------------------------------------------------------------------- |
| Migration           | `config/Migrations/v8.lua`, `config/ConfigOptions.lua`, `config/DbAccessors.lua`                                             |
| Display             | `LootDisplay/LootDisplay.lua`, `LootDisplay/LootDisplayFrame/LootDisplayFrame.lua`, `LootDisplay/SampleRows.lua`             |
| Config builders     | `config/FramesConfig.lua`, all 9 `config/Features/*Config.lua`, `config/Features/Features.lua`                               |
| Config UI           | `config/ConfigOptions.lua`, `config/General.lua`, `config/BlizzardUI.lua`, `config/About.lua`                                |
| Appearance builders | `config/Positioning.lua`, `config/Sizing.lua`, `config/Styling.lua`, `config/Animations.lua`                                 |
| Feature modules     | All 9 feature modules, `Features/_Internals/LootElementBase.lua`                                                             |
| Row mixins          | `RowAnimationMixin.lua`, `RowTextMixin.lua`, `RowUnitPortraitMixin.lua`, `RowScriptedEffectsMixin.lua`, `LootDisplayRow.lua` |
| Utils               | `utils/Enums.lua`, `utils/HistoryService.lua`                                                                                |
| Testing             | `GameTesting/SmokeTest.lua`, `GameTesting/IntegrationTest.lua`                                                               |

---

## Future: Loot History Architecture

**Status**: Discussion primer — not yet designed.

### Current behavior

`LootDisplayFrameMixin:StoreRowHistory(row)` is called when a row is
**released** (exits the feed). History is per-frame in `self.rowHistory`,
capped at `db.global.lootHistory.historyLimit`.

### Tension points

1. **Aggregation lossy**: 3 currency events → 1 aggregated row → 1 history
   entry. Individual events lost.
2. **Timing-dependent**: History depends on display lifecycle. Hidden/destroyed
   frames or cleared rows may never reach history.
3. **Per-frame but not per-event**: Same event fires to all frames. Frame A
   may show it, Frame B may filter it — correct for "what this frame showed"
   but confusing for "what happened".

### Possible models

| Model                        | Records                                  | Pros                                         | Cons                                      |
| ---------------------------- | ---------------------------------------- | -------------------------------------------- | ----------------------------------------- |
| **A — On display** (current) | When row exits feed                      | Matches what user saw; aggregation reflected | Timing-coupled, lossy                     |
| **B — On event acceptance**  | When broker accepts event                | No timing dependency; every event captured   | Diverges from visual (3 entries vs 1 row) |
| **C — Hybrid**               | Global event log + per-frame display log | Both views available                         | More complexity and storage               |

### Open questions

- Is history "what I saw" or "what happened"?
- Should history survive frame deletion?
- Should aggregated events be individual entries or collapsed?
- Per-frame history vs one global history?

---

## Non-Goals / Out of Scope

- Per-frame loot history (deferred — architecture supports it).
- Global appearance defaults with per-frame override (deferred).
- Feature module TOC split / sub-addon architecture (deferred).
- Cross-frame drag-and-drop row re-ordering.
- Frame sharing between AceDB profiles or characters.
- More than 5 frames in initial release.
- Cleanup of orphaned top-level DB keys (migration v8 preserves originals).

---

## References

- [Architecture](architecture.md) — module map and coding patterns
- [Glossary](glossary.md) — WoW and addon terminology
- `loot-display.instructions.md` — frame/row pooling patterns
- `config.instructions.md` — AceConfig option table conventions
