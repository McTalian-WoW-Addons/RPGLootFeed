---
name: wago-datamining
description: Look up WoW asset ground truth on wago.tools — resolve FileDataIDs, check whether an icon ships to every flavor RPGLootFeed supports, find texture atlases and major faction texture kits, and audit the faction icon map after a patch. Use when picking or verifying an icon/FileDataID, when a new faction needs an icon, when an icon renders wrong on one flavor but not another, or whenever a hardcoded FileDataID is added or changed.
---

# /wago-datamining — look up WoW asset ground truth on wago.tools

## Commands

```bash
uv run .scripts/wago_lookup.py --help
uv run .scripts/wago_lookup.py info 236681          # FileDataID -> filename
uv run .scripts/wago_lookup.py presence 236681      # per-flavor presence  <- the important one
uv run .scripts/wago_lookup.py find ui_majorfactions --icons-only
uv run .scripts/wago_lookup.py atlas majorfactions_icons_
uv run .scripts/wago_lookup.py kits ritual
uv run .scripts/wago_lookup.py audit                # unmapped major faction texture kits

# extract needs Pillow; everything else is stdlib-only
uv run --with pillow .scripts/wago_lookup.py extract 7903180 majorfactions_icons_ritualsites512
```

All-digit arguments are FileDataIDs; anything else is an atlas member name. Look at the extracted art before trusting a filename match to a faction.

## Rule

Never hardcode a FileDataID without running `presence` on it first — Classic Era, TBC Anniversary, MoP Classic and Retail ship from one codebase but carry different asset subsets.
`236681` (default reputation icon): present on Retail, Classic Era, MoP Classic; absent from TBC Anniversary.
When an asset is not universal, pick a different one or guard with `G_RLF:IsRetail()` / `G_RLF:IsClassic()`.

## Pitfalls

- Include a known-present and a known-absent control on every presence check.
- Treat `ERR` and `NO` as different: `ERR` is a network/typo failure, `NO` is confirmed absent.
- `find`/`audit` default to the community listfile — a hit there proves nothing about which flavor ships the asset; scope a check to one product with `find PATTERN --source wago --flavor <Flavor>`.
- Search several spellings before concluding an icon is atlas-only — faction icon filenames are inconsistent (`majorfactions`/`majorfaction`, stray spaces, `renown_` prefixes, non-`majorfaction` names like `ui_prey.blp`/`ui_delves.blp`).
- Use `.scripts/wago_lookup.py`, not ad-hoc greps — it unquotes CSV filenames with spaces and decodes BLP2 encoding 3.
- Pass `--refresh` when a result looks implausibly sparse.
- Pass `--strict` in unattended or scripted runs.

## Adding an icon for a new faction

1. `make faction_icon_audit` — lists texture kits missing from `majorFactionTextureKitIconMap` in `RPGLootFeed/utils/ReputationHelpers.lua`.
2. `make faction_icon_preview TARGETS="<fdid>"` — confirm the art is that faction's; the audit only matches on filename.
3. `make asset_presence FDIDS="<fdid>"`; add `["<kit>"] = <fdid>,` to the map with a trailing comment naming the faction.
4. When a kit has no `ui_*` match, run the suggested `find` searches before concluding there is none; if genuinely atlas-only, use the atlas render path or a substitute icon.
5. Key the map by `mfd.textureKit:lower()` from `C_MajorFactions.GetMajorFactionData`.

Check for an alias before adding a duplicate FileDataID: `denizens`, `gold`, `vines` already map to `dream`, `light`, `root`. `factionIdIconMap` in the same file keys non-major factions by numeric faction ID from the `Faction` DB2 table (`RenownFactionID != 0` marks a renown/major faction).

## Endpoints

| Endpoint                                  | Notes                                                                                                         |
| ----------------------------------------- | ------------------------------------------------------------------------------------------------------------- |
| `/api/builds/latest`                      | latest build per product; values are objects with `version`                                                   |
| `/api/files?product=X&format=csv`         | authoritative per-version listfile, `fdid;filename`; `presence --source listfile` fallback                    |
| `/api/info/{fdid}`                        | FileDataID -> filename                                                                                        |
| `/db2/{table}/csv?build=X`                | DB2 export; `UiTextureKit`, `UiTextureAtlasMember`, `Faction`                                                 |
| `/api/casc/{fdid}?product=X`              | raw file bytes; IS product-filtered via body size, not status — see pitfalls; what `presence` uses by default |
| `github.com/wowdev/wow-listfile` releases | cross-product name index, no presence data — see pitfalls                                                     |

## Products

`wow` (Retail), `wow_classic` (MoP Classic), `wow_classic_era`, `wow_anniversary` (TBC) — keep `FLAVORS` in the script in sync with the `## Interface` line in `RPGLootFeed/RPGLootFeed.toc`.

Rationale: `docs/agent/decisions.md`.
