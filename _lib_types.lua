---@class TSM_API
---@field public ToItemString fun(item: string)
---@field public GetCustomPriceValue fun(priceSource: string, itemString: string)

---@class ElvUIApp : AceAddon

---@class ElvUILocale: table<string, string>

---@class ElvUIPrivateDb : table

---@class ElvUIProfileDb : table

---@class ElvUIGlobalDb : table

---@class ElvUISkinsModule : AceModule
---@field HandleItemButton fun(self: ElvUISkinsModule, button: Button, setInline: boolean)
---@field HandleIconBorder fun(self: ElvUISkinsModule, borderTexture: Texture)

--- EllesmereUI's third-party skinning facade, handed to the callback passed to
--- EllesmereUI.RegisterSkin.  Plain table of functions -- call with a dot, not
--- a colon.  Only the members RPGLootFeed uses are declared here; the full
--- surface is documented in EllesmereUI's SKINNING_API.md.
---@class EllesmereUISkinFacade
---@field apiVersion integer
---@field IsEnabled fun(): boolean
---@field SquareIcon fun(icon: Texture, parent?: Frame)

---@class EllesmereUIApp
---@field RegisterSkin fun(name: string, applyFn: fun(S: EllesmereUISkinFacade)): boolean?
