# AceConfig → HTML Renderer Utility

> **Status (2026-03-12):** Steps 1–5 and 7 are complete and working.
> Multi-frame config (FramesConfig, DbAccessors, per-frame mocks, per-frame DB
> setup, tab bar renderer, 3-level nav) fully supported — `make options-dump`
> produces ~150 KB JSON with `global`, `frame_1`, `newFrame`, and
> `manageFrames` subtrees; `make options-html` renders them with a tab bar and
> 3-level sidebar. Serializer robustness hardened (enriched INFO_STUB, `_error`
> handling). Steps 6 and 8 remain; see [Remaining Work](#remaining-work) below.
> Run `make options-html` to regenerate the output at any time.

## Purpose

A developer/contributor tool that loads RPGLootFeed's AceConfig options tables
outside the game (using the existing busted mock infrastructure), serializes
them to JSON, and renders a static HTML page that visually mirrors the in-game
settings panel. Primary use cases:

1. **Design and iteration** — see the real option structure without launching
   WoW; rapidly prototype layout reorganizations.
2. **Localization contributions** — translators see every option name and
   description string in context, with the locale key annotated, so they can
   propose translations outside the game.
3. **Documentation / demos** — a linkable, shareable snapshot of what the
   settings look like for a given version. Could be generated as a CI artifact.

---

## Existing Infrastructure

The following pieces already exist and should be reused rather than rebuilt:

| Asset                                                 | Role in this utility                                                                                                       |
| ----------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------- |
| `RPGLootFeed_spec/_mocks/helper.lua`                  | Bootstraps all WoW global stubs (bit, Enum, Constants, C\_\* namespaces, etc.)                                             |
| `RPGLootFeed_spec/_mocks/Internal/addonNamespace.lua` | `addonNamespaceMocks:unitLoadedAfter(section)` — builds the `ns` table up to any load section, including locale and enums  |
| `RPGLootFeed_spec/_mocks/Libs/`                       | LibStub, AceAddon, AceLocale, LSM stubs needed so config files load cleanly                                                |
| `RPGLootFeed/locale/enUS.lua`                         | English locale — already loadable via `addonNamespaceMocks` at the `Locale` section                                        |
| `RPGLootFeed/utils/Enums.lua`                         | Loaded at `UtilsEnums` section; provides `G_RLF.EnterAnimationType`, `G_RLF.RowBackground`, etc. needed by config defaults |
| `addonNamespaceMocks.LoadSections.Config` (4)         | Loading through this section fully constructs `G_RLF.options` and `G_RLF.defaults`                                         |
| `.scripts/` (Python, `uv run`)                        | Pattern for standalone Python tooling; existing scripts (locale checkers, etc.) follow this convention                     |
| `Makefile`                                            | Pattern for adding `make` targets                                                                                          |

---

## What's Built

### Files

```plain
.scripts/
  dump_options.lua          ← Stage 1 entry point (busted spec)
  aceconfig_serializer.lua  ← recursive walk + JSON serialization logic
  render_options.py         ← Stage 2 HTML renderer
  assets/
    worldsoul.png           ← Atlas icon for Global tab (UI-EventPoi-WorldSoulMemory)
    lootall.png             ← Atlas icon for frame tabs (Crosshair_lootall_32)
.scripts/.output/
  options_dump.json         ← Stage 1 output (gitignored)
  options.html              ← Stage 2 output (gitignored)
```

### Stage 1 — Lua → JSON dump (`dump_options.lua` + `aceconfig_serializer.lua`)

Implemented as a busted spec so it reuses the existing `package.path` setup.
Loads all config files in correct order (matching `config.xml` / `features.xml`)
and builds a fake live DB from `G_RLF.defaults` so `get()`/`hidden()`/`disabled()`
closures resolve real default values.

**Serialization behaviour per field type:**

| Field                                                                          | Serialization                                                                |
| ------------------------------------------------------------------------------ | ---------------------------------------------------------------------------- |
| `type`, `name`, `desc`, `order`, `width`, `inline`, `guiInline`, `childGroups` | Copied as-is                                                                 |
| `args`                                                                         | Recurse into child nodes                                                     |
| `values` (table)                                                               | Copied as-is (`{key: label}`)                                                |
| `values` (function)                                                            | Called; result stored in `_resolved`; always `_dynamic: true`                |
| `get` (non-color)                                                              | Called; result stored in `_value`; `_dynamic: true`                          |
| `get` (color node)                                                             | Called; all four channels stored as `_r`, `_g`, `_b`, `_a`; `_dynamic: true` |
| `hidden`, `disabled`                                                           | Called; result stored in `_value`; `_dynamic: true`                          |
| `set`, `func`                                                                  | Not called; recorded as `{_type: "function"}`                                |
| `validate`, `confirm`, `image`, other fn fields                                | Not called; recorded as `{_type: "function"}`                                |
| `sorting`, `imageCoords`, other tables                                         | Copied as-is                                                                 |
| Non-standard extra keys                                                        | Captured with `_extra_` prefix                                               |

**Mock enrichments** (`dump_options.lua` sets these up before loading configs):

- LSM `HashTable()` returns representative sample tables for font/background/border/sound
- `GetFonts()` returns a representative list of WoW font object names
- `ns.AuctionIntegrations` stub so ItemConfig closures don't error
- `CreateAtlasMarkup` mock returns `<AtlasMarkup:atlas-name>` so the atlas name survives into JSON
- `ns.LootDisplay` stub with no-op methods (`RefreshSampleRowsIfShown`, `UpdatePosition`, `UpdateSize`, etc.) — called by `wrapSettersWithRefresh()` and per-frame config setters
- `ns.HistoryService` stub (`ToggleHistoryFrame` no-op) — referenced by General.lua
- `ns.Notifications` stub (`AddNotification` no-op) — referenced by FramesConfig.lua
- `ns.RLF.GetModule()` stub returning `{ ToggleTestMode = noop }` — referenced by General.lua

**Per-frame DB setup:**

- After `deepCopy(ns.defaults)`, an explicit `frames[1]` entry is created from the `"**"` wildcard defaults with `name = "Main"` and all features enabled
- `ns.db.global.nextFrameId = 2`
- The `"**"` wildcard key is removed to avoid mixed string/number key sort errors
- `ns.FramesConfig:RebuildArgs()` is called after all config files are loaded

**Config file load order** (matches `config.xml` / `features.xml`):

- `common/common.lua`, `common/db.utils.lua`, `common/styling.base.lua`
- `ConfigOptions.lua`, `General.lua`
- `Features/Features.lua`, all feature configs
- `Positioning.lua`, `Sizing.lua`, `Styling.lua`, `Animations.lua`
- `FramesConfig.lua`, `BlizzardUI.lua`, `DbAccessors.lua`, `About.lua`

### Stage 2 — HTML renderer (`render_options.py`)

Self-contained HTML output (all CSS/JS inlined, no external deps).

**Layout — multi-frame (root `childGroups="select"`):**

- Fixed top bar with addon title
- Tab bar below the top bar: one tab per root-level `select` group (`⚙ Global`, `Main`, `+ New Frame`, `Manage Frames`); gold highlight on active tab
- Per-tab two-column workspace: left sidebar nav tree | right scrollable content panels
- Sidebar groups are scoped to the active tab — switching tabs swaps the sidebar and content
- 3-level nav: tab → tree parent (e.g. Appearance, Loot Feeds) → tree children (collapsible); clicking navigates to the panel
- Content: each nav leaf has a dedicated panel; sub-groups render as `<fieldset>` with `<legend>`

**Layout — flat (no root `select`):**

- Fixed top bar with addon title + root-level `execute` buttons
- Two-column workspace: left sidebar nav tree | right scrollable content panels
- Sidebar: gold top-level section headers, indented white sub-items; clicking navigates to the panel
- Content: each nav item has a dedicated panel; sub-groups render as `<fieldset>` with `<legend>`

**Widget rendering:**

| AceConfig type               | HTML                                                                                      |
| ---------------------------- | ----------------------------------------------------------------------------------------- |
| `group` (non-inline)         | `<fieldset>` + `<legend>` (gold header)                                                   |
| `group` (inline / guiInline) | `<fieldset class="opt-group-inline">` (dashed border)                                     |
| `toggle`                     | ✔ / □ symbol + label                                                                      |
| `range`                      | `<input type="range">` disabled, with current value display                               |
| `select`                     | `<select>` disabled, options from `values`; respects `sorting`; `dialogControl` annotated |
| `multiselect`                | Flex group of disabled checkboxes per key                                                 |
| `color`                      | Colored swatch with real `rgba(r,g,b,a)` from captured defaults                           |
| `input`                      | `<input type="text">` or `<textarea>` disabled; `validate` string shown as badge          |
| `execute`                    | `<button>` disabled; `CreateAtlasMarkup` names shown as `atlas-badge` pill                |
| `description`                | Styled `<p>` with `image` annotation if present                                           |
| `header`                     | `<h4>` divider with gold border                                                           |

**Additional features:**

- **Disabled state**: `opt-disabled` class (opacity) when `disabled()` returned `true`
- **Hidden options**: separated from visible siblings into a collapsed `<details class="hidden-opts-section">` at both panel and group level; not silently excluded
- **Numeric `width`**: fractional AceConfig widths (e.g. `0.35`) applied as inline `width: N%`
- **Dynamic placeholders**: `[dynamic list]` / `[dynamic]` / `[unavailable]` where values depend on live game state or evaluation failed
- **Tooltips**: hovering any option shows internal key, full description, dynamic flags, and `[eval error: ...]` annotation when a closure errored at dump time
- **Nav**: JS-driven panel switching; parent nodes collapse/expand their children; tab switching shows/hides scoped sidebar sections
- **Atlas icons**: `<AtlasMarkup:NAME>` in nav labels and execute buttons replaced with inline `<img>` tags using base64-embedded PNGs from `.scripts/assets/` (falls back to styled text badge when no PNG is available)

**Makefile targets:**

- `make options-dump` — runs Stage 1, writes `options_dump.json`
- `make options-html` — runs Stage 1 then Stage 2, writes `options.html`

---

## Architecture

The utility is two decoupled stages:

```
Stage 1: Lua dump script
  Loads config files via mock infrastructure → serializes G_RLF.options to JSON
  Output includes: global, frame_1 (appearance + loot feeds), newFrame, manageFrames
  Assertions verify: no _error markers, handler propagation resolves styling
  method-refs, per-frame keys present

Stage 2: HTML renderer
  Reads JSON → renders static HTML page
  Root childGroups="select" → tab bar + 3-level nav (tab → parent → leaf)
  No root select → legacy flat 2-level nav with top-bar execute buttons
  Atlas icon PNGs in .scripts/assets/ are base64-embedded into the self-contained HTML
```

Keeping them separate means the renderer can be iterated in isolation (just
feed it updated JSON) and the JSON becomes a useful artifact on its own (e.g.
for diffs, tests, or other tooling).

---

## Stage 1 — Lua → JSON Dump (reference)

The following notes are kept for context; the implementation lives in
`.scripts/dump_options.lua` and `.scripts/aceconfig_serializer.lua`.

### Mock environment

`dump_options.lua` bootstraps the namespace through `addonNamespaceMocks.LoadSections.Utils`
then manually loads each config file (same order as `config.xml`/`features.xml`)
with `loadfile()`. It enriches the LSM, `GetFonts`, `AuctionIntegrations`,
`LootDisplay`, `HistoryService`, `Notifications`, and `RLF.GetModule` stubs
before loading so that per-frame config closures resolve without error.

A deep-copy of `G_RLF.defaults` is assigned to `ns.db`, with an explicit
`frames[1]` entry (from the `"**"` wildcard defaults) so that `get()`/`hidden()`/
`disabled()` closures that read `G_RLF.db.global.frames[frameId]` see real
default values. After all config files load, `FramesConfig:RebuildArgs()` is
called to generate per-frame subtrees.

### Not yet implemented in Stage 1 — CLI flags

The dump script was designed to accept flags for parameterising the evaluation
environment, but these have not been built yet:

- `--expansion <level>` — controls expansion-gated `disabled` evaluations
- `--retail <true|false>` — controls retail-only `hidden` evaluations
- `--locale <code>` — load an alternative locale file (default: `enUS`)

The current implementation always uses: retail = `true`, enUS locale, and the
default expansion level returned by the `GetExpansionLevel` stub.

---

## Stage 2 — HTML Renderer (reference)

Implementation lives in `.scripts/render_options.py`.

`render_options.py --input PATH --output PATH` (both have defaults pointing at
`.scripts/.output/`). Called automatically by `make options-html`.

The `Renderer` class detects whether the root node uses `childGroups="select"`
and branches into `_render_tabbed()` or the legacy flat path.

- **`_build_tabs(root)`** — builds a list of tab dicts, each containing a
  `has_tree` flag and its own `nav_items` produced by `_build_nav()`.
- **`_build_nav(root_args, prefix)`** — classifies child groups as `container`
  (have sub-groups → collapsible sidebar parent) or `leaf` (rendered directly).
  The `prefix` namespaces panel IDs so sibling tabs don't collide.
- **`_render_tabbed()`** — emits the tab bar HTML and per-tab sidebar/panel
  sections; JS hides all but the active tab's sidebar and panels.
- **`_render_*()` methods** — one per AceConfig widget type; dispatch from
  `_render_node()`.

All CSS and JS are inlined in `HTML_HEAD` / `HTML_FOOT` constants.

---

## Build Order — Progress

| Step | Status             | Description                                                                                             |
| ---- | ------------------ | ------------------------------------------------------------------------------------------------------- |
| 1    | ✅ Done            | Skeleton JSON serializer — locale strings resolved, structural skeleton output                          |
| 2    | ✅ Done            | Function evaluation — `get()`/`hidden()`/`disabled()` with `_dynamic` annotations                       |
| 3    | ✅ Done            | Values resolution — LSM, `GetFonts`, auction integrations stubs                                         |
| 4    | ✅ Done            | Basic HTML renderer — nav, groups, toggles, ranges                                                      |
| 5    | ✅ Done            | Full widget coverage — all 10 types; color RGBA, atlas badges, validate, numeric width, hidden sections |
| 6    | ⬜ Todo            | Locale annotation mode — `--mode=locale` translator output                                              |
| 7    | ✅ Done            | Makefile targets — `make options-dump` and `make options-html`                                          |
| 8    | ⬜ Todo (optional) | CI artifact — attach `options.html` to releases or PR comments                                          |
| 9    | ✅ Done            | Multi-frame support — FramesConfig/DbAccessors loaded, per-frame mocks, DB setup, `RebuildArgs()` call  |
| 10   | ✅ Done            | Tab bar + 3-level nav renderer — `childGroups="select"` root → tabbed layout with scoped sidebar        |
| 11   | ✅ Done            | Serializer robustness — enriched INFO_STUB, `_error` handling, handler propagation assertion            |

---

## Remaining Work

### Step 6 — Locale annotation mode

Add a `--mode=locale` flag to `render_options.py` that, instead of the full visual
HTML, produces a simplified translator-focused table. The design doc specified:

> Just a table of `locale_key | context (option name) | value (English text)`
> for every `name` and `desc` string encountered.

**Implementation sketch:**

- Walk the JSON the same way the renderer does.
- For each node with a non-empty `name` or `desc` string value, emit a row.
  - **locale_key**: the value itself is the already-resolved English string; the
    key cannot be recovered from the dump. Two options:
    1. Compare against `G_RLF.L` at dump time and record `_name_key` / `_desc_key`
       in the JSON (requires Stage 1 change).
    2. Accept that the table is `english_text | context | section` — still useful
       for translators scanning what to translate, even without the raw key.
- Output as either: a standalone HTML `<table>` (share-friendly), or a TSV file
  (paste into a spreadsheet).
- A new Makefile target `make options-locale` would invoke
  `uv run .scripts/render_options.py --mode=locale`.

**Preferred approach:** Option 1 (record keys in JSON) gives translators the raw
locale key they need to submit a patch. The serializer already has access to
`G_RLF.L` at dump time; it can reverse-lookup `name`/`desc` strings.

### Step 8 — CI artifact (optional)

A GitHub Actions workflow step that runs `make options-html` and attaches
`options.html` as a build artifact on each push / release tag. Low priority
until the tool is stable.

---

## Edge Cases (resolved and open)

### Resolved

- **Circular / forward references** — PartyLootConfig loaded before
  Positioning/Sizing/Styling so `Get*Options()` calls work; circular table
  detection in the serializer handles any remaining cases.
- **`width` as a number** — renderer applies inline `width: N%` via the
  `width-numeric` CSS class.
- **`dialogControl`** — annotated as a small `dialog-ctrl` badge next to the
  `<select>` widget.
- **`validate` as a string** — shown as a `validate-badge` on `input` nodes.
- **`inline = true` groups** — rendered with a dashed `opt-group-inline` border
  instead of a solid one.
- **`CreateAtlasMarkup` names** — the mock now returns `<AtlasMarkup:name>` so
  execute button names survive into the JSON and render as `atlas-badge` pills.
- **Color multi-return** — `get()` on color nodes returns `r, g, b, a`; all
  four channels are now captured separately and used to render real color swatches.
- **Multi-frame layout** — `FramesConfig.lua` and `DbAccessors.lua` now loaded;
  per-frame mocks (`LootDisplay`, `HistoryService`, `Notifications`,
  `RLF.GetModule`) added; fake DB populated with an explicit `frames[1]` entry;
  `FramesConfig:RebuildArgs()` called before serialization. JSON output grew
  from ~16 KB to ~150 KB.
- **`childGroups="select"` at root** — renderer detects this and switches to
  the tabbed layout path (`_render_tabbed`); legacy flat path preserved for
  future alternative root shapes.
- **3-level nav hierarchy** — `_build_tabs()` + `_build_nav(prefix)` generate
  a tab → parent → leaf structure; JS scopes sidebar visibility to the active tab.
- **INFO_STUB enrichment** — previously a plain `{}`, now a module-level
  metatabled table that returns `""` for any key so `info[#info]`-style
  closures degrade safely rather than erroring.
- **`_error` resilience** — `_raw_str` returns `[unavailable]`, `_resolve_bool`
  falls back to default, and tooltips annotate `[eval error: ...]` when a
  `get`/`hidden`/`disabled` closure fails at dump time.

### Open

- **`--locale` flag** — non-enUS locales not yet loadable via the dump script.
- **`--expansion` / `--retail` flags** — expansion-gated and retail-only
  `hidden`/`disabled` results are always evaluated with the default stubs; you
  cannot currently simulate a non-retail or older-expansion run.
