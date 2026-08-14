---
name: wago-datamining
description: Look up WoW asset ground truth on wago.tools — resolve FileDataIDs, check whether an icon ships to every flavor RPGLootFeed supports, find texture atlases and major faction texture kits, and audit the faction icon map after a patch. Use when picking or verifying an icon/FileDataID, when a new faction needs an icon, when an icon renders wrong on one flavor but not another, or whenever a hardcoded FileDataID is added or changed.
---

# Datamining WoW assets with wago.tools

`wow-ui-source` (see CLAUDE.md) is ground truth for **API and UI code**. It contains no
asset listing, so it cannot answer "does this FileDataID exist" or "what does this icon
look like". wago.tools answers those.

Use `.scripts/wago_lookup.py` rather than hand-rolling requests — it caches the large
listfiles under `.scripts/.output/wago-cache` (gitignored) and encodes the pitfalls below.

```bash
uv run .scripts/wago_lookup.py --help
uv run .scripts/wago_lookup.py info 236681          # FileDataID -> filename
uv run .scripts/wago_lookup.py presence 236681      # per-flavor presence  <- the important one
uv run .scripts/wago_lookup.py find ui_majorfactions --icons-only
uv run .scripts/wago_lookup.py atlas majorfactions_icons_
uv run .scripts/wago_lookup.py kits ritual
uv run .scripts/wago_lookup.py audit                # unmapped major faction texture kits
```

## The rule that matters

**Never hardcode a FileDataID without running `presence` on it.** The addon ships to
Classic Era, TBC Anniversary, MoP Classic, and Retail from one codebase, and each client
carries a different subset of the asset set. A FileDataID that renders fine on Retail can
be a missing texture on an older flavor.

Real example: `236681` (`achievement_reputation_01.blp`), the default reputation icon, is
present on Retail, Classic Era and MoP Classic but **absent from TBC Anniversary** — that
client is 2.5.6, predating achievements, so it ships no `Achievement_*` icons at all (the
whole 2366xx FileDataID band is missing). Anything in the vanilla band (~13xxxx) is a
safe bet across all flavors.

If an asset is not universal, either pick a different one or branch on
`G_RLF:IsRetail()` / `G_RLF:IsClassic()`.

## Pitfalls

- **`/api/casc/{fdid}` ignores its `product` parameter.** It returns HTTP 200 for
  Retail-only assets queried against Classic, and even for FileDataIDs that do not exist
  (an error body with `Content-Type: application/json` rather than a non-200). It is
  useless for presence checks. Only the `/api/files` listfile is authoritative.
- **Always include a control.** When checking presence, also check an asset you know
  should be absent (a current-expansion icon) and one you know should be present. If the
  controls do not behave, the query is wrong — this exact mistake produced a confidently
  wrong conclusion once already.
- **Cloudflare 403s the default urllib/python User-Agent.** The script sets a browser UA.
- **Listfile downloads are large** (Retail ~40MB) and intermittently 502/504. The script
  retries and caches; pass `--refresh` after a patch drops.
- **Blizzard typos exist in asset names.** `ui_majorfactions_ nightfall.blp` and
  `ui_majorfactions_ karesh.blp` both carry a stray space. Match loosely.

## Adding an icon for a new faction

1. `uv run .scripts/wago_lookup.py audit` — lists texture kits present in game data but
   missing from `majorFactionTextureKitIconMap` in `RPGLootFeed/utils/ReputationHelpers.lua`.
2. For a kit reported with an **icon file**, add `["<kit>"] = <fdid>,` to that map with a
   trailing comment naming the faction. Run `presence <fdid>` first.
3. For a kit reported as **ATLAS ONLY**, there is no FileDataID. Some factions never ship
   an `interface/icons/*.blp` — Ritual Sites (12.0.5) only ever shipped
   `majorfactions_icons_ritualsites512`, frame art, and a minimap icon. Options: render the
   atlas (the paragon reward bag already does this via `paragonIconAtlas` +
   `G_RLF.AtlasIconCoefficients`), or substitute a thematically close icon file.
4. The map is keyed by `mfd.textureKit:lower()` from `C_MajorFactions.GetMajorFactionData`,
   so the key must be the lowercased kit prefix — `atlas`/`kits` output already matches.

Note `factionIdIconMap` in the same file is keyed by numeric faction ID instead, for
non-major factions. Faction IDs and names come from the `Faction` DB2 table
(`RenownFactionID != 0` marks a renown/major faction).

## Endpoints, if you need them directly

| Endpoint                          | Notes                                                         |
| --------------------------------- | ------------------------------------------------------------- |
| `/api/builds/latest`              | latest build per product; values are objects with `version`   |
| `/api/files?product=X&format=csv` | **authoritative** per-version listfile, `fdid;filename`       |
| `/api/info/{fdid}`                | FileDataID -> filename                                        |
| `/db2/{table}/csv?build=X`        | DB2 export; `UiTextureKit`, `UiTextureAtlasMember`, `Faction` |
| `/api/casc/{fdid}`                | raw file bytes; **not** product-filtered — see pitfalls       |

Products relevant here: `wow` (Retail), `wow_classic` (MoP Classic), `wow_classic_era`,
`wow_anniversary` (TBC). Keep `FLAVORS` in the script in sync with the `## Interface`
line in `RPGLootFeed/RPGLootFeed.toc`.

To see what an icon actually looks like, fetch
`https://wow.zamimg.com/images/wow/icons/large/<name>.jpg` (name without the `.blp`) and
open it — worth doing before assuming an icon is wrong.
