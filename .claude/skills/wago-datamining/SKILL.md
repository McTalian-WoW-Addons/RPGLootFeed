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

# extract needs Pillow; everything else is stdlib-only
uv run --with pillow .scripts/wago_lookup.py extract 7903180 majorfactions_icons_ritualsites512
```

`extract` writes PNGs to `.scripts/.output/wago-icons`. All-digit arguments are
FileDataIDs, anything else is an atlas member name (cropped out of its sheet).
**Look at the art before hardcoding an ID** — a filename matching a faction name
is a heuristic, not proof.

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
  retries and caches. Cached listfiles are **build-pinned by filename**, so a patch cannot
  be answered from last patch's data — a new build is a file that has not been downloaded
  yet, and re-downloads itself on next use with a note saying so. `make wago_cache` shows
  cached vs live builds; `make wago_prune` deletes superseded ones.
- **If wago is unreachable**, the tool falls back to the last known build list and warns
  loudly that it could not confirm the build is current. Pass `--strict` to make that an
  error instead — worth using in any unattended or scripted run.
- **Faction icon filenames are wildly inconsistent.** All of these are real in 12.1:
  `ui_majorfactions_storm.blp` (plural), `ui_majorfaction_storm.blp` (singular),
  `ui_majorfactions_nightfall.blp` but with a stray space after the underscore,
  `ui_majorfaction_renown_zuljarrasforces.blp`
  (`renown_`, and the kit name is only a prefix), and `ui_prey.blp` / `ui_delves.blp`
  (no `majorfaction` at all). Never conclude a faction has no icon from one pattern
  failing to match — `find` under several spellings first.
- **Filenames containing spaces are quoted in the listfile CSV.** A naive
  `grep '^[0-9]\+;interface/icons/'` silently skips every entry whose name carries
  the stray space (nightfall, karesh) because the line starts with a quote.
  `listfile()` strips the quotes; ad-hoc greps do not. Use the script.
- **BLP2 encoding 3 (raw BGRA) breaks Pillow** with "Unknown BLP encoding 3", and
  the major faction atlas sheets all use it. `extract` handles it; anything else
  decoding BLPs needs to.

## Adding an icon for a new faction

1. `make faction_icon_audit` — lists texture kits present in game data but missing from
   `majorFactionTextureKitIconMap` in `RPGLootFeed/utils/ReputationHelpers.lua`.
2. For a kit reported with an **icon file**, confirm the art is really that faction's:
   `make faction_icon_preview TARGETS="<fdid>"`, then look at the PNG. The audit matches
   on filename, which is a guess.
3. Check it ships everywhere: `make asset_presence FDIDS="<fdid>"`. Then add
   `["<kit>"] = <fdid>,` to the map with a trailing comment naming the faction.
4. For a kit reported as **no `ui_*` icon matched**, run the suggested `find` searches
   before believing it — `ui_prey.blp` and `ui_delves.blp` are both real icons that no
   faction-name pattern would catch. If it is genuinely atlas-only (Ritual Sites in
   12.0.5 only ever shipped `majorfactions_icons_ritualsites512`, frame art and a minimap
   icon), it needs the atlas render path or a substitute icon.
5. The map is keyed by `mfd.textureKit:lower()` from `C_MajorFactions.GetMajorFactionData`,
   so the key must be the lowercased kit prefix — `atlas`/`kits` output already matches.

Beware kit aliases: `denizens`, `gold` and `vines` are Dream Wardens, Silvermoon Court and
Hara'ti, already mapped as `dream`, `light` and `root` pointing at the same FileDataIDs.
The audit dedupes on FileDataID, so an alias only surfaces if it has genuinely new art.

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
