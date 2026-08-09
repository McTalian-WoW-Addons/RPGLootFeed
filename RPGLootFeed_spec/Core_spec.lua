local nsMocks = require("RPGLootFeed_spec._mocks.Internal.addonNamespace")
local assert = require("luassert")
local match = require("luassert.match")
local busted = require("busted")
local before_each = busted.before_each
local describe = busted.describe
local it = busted.it
local setup = busted.setup
local spy = busted.spy
local stub = busted.stub

describe("Core module", function()
	local ns, RLF
	local _ = match._
	local libStubReturn

	setup(function()
		libStubReturn = require("RPGLootFeed_spec._mocks.Libs.LibStub")
	end)

	describe("load order", function()
		it("loads the file correctly", function()
			---@type test_G_RLF
			ns = nsMocks:unitLoadedAfter(nsMocks.LoadSections.None)
			RLF = assert(loadfile("RPGLootFeed/Core.lua"))("TestAddon", ns)
			assert.is_not_nil(RLF)
		end)
	end)

	describe("functionality", function()
		before_each(function()
			---@type test_G_RLF
			ns = nsMocks:unitLoadedAfter(nsMocks.LoadSections.All)
			RLF = assert(loadfile("RPGLootFeed/Core.lua"))("TestAddon", ns)
		end)

		describe("addon initialization", function()
			it("should initialize correctly", function()
				spy.on(RLF, "OnInitialize")
				RLF:OnInitialize()
				assert.spy(RLF.OnInitialize).was.called(1)
			end)

			describe("DbMigrations (new install)", function()
				it("seeds migrationVersion to latestMigrationVersion on fresh install", function()
					ns.migrations = {
						{ run = function() end }, -- 1
						{ run = function() end }, -- 2
						{ run = function() end }, -- 3
						{ run = function() end }, -- 4
						{ run = function() end }, -- 5
						{ run = function() end }, -- 6
						{ run = function() end }, -- 7
					}

					RLF:OnInitialize()

					assert.are.equal(7, ns.db.global.migrationVersion)
				end)

				it("calls no migration run functions", function()
					local run1 = spy.new(function() end)
					local run2 = spy.new(function() end)
					ns.migrations = {
						{ run = run1 },
						{ run = run2 },
					}

					RLF:OnInitialize()

					-- Core always calls every migration:run(); each migration decides
					-- internally (via ShouldRunMigration) whether to do anything.
					assert.spy(run1).was.not_called()
					assert.spy(run2).was.not_called()
				end)

				it("does not skip migrations when migrationVersion > 0", function()
					local run1 = spy.new(function() end)
					ns.migrations = { { run = run1 } }
					-- Override AceDB mock to return a db with an existing version
					local aceDb = libStubReturn["AceDB-3.0"]
					local origNew = aceDb.New
					stub(aceDb, "New", function()
						return { global = { migrationVersion = 1 } }
					end)

					RLF:OnInitialize()

					assert.spy(run1).was.called()
					aceDb.New = origNew
				end)
			end)
		end)

		describe("OnSlashCommand", function()
			it("should handle test mode command correctly", function()
				local TestMode = {
					ToggleTestMode = function() end,
				}
				local spyToggleTestMode = spy.on(TestMode, "ToggleTestMode")
				RLF.GetModule = function(_, moduleName)
					if moduleName == "TestMode" then
						return TestMode
					end
				end

				RLF:OnInitialize()
				RLF:SlashCommand("test")
				assert.spy(spyToggleTestMode).was.called(1)
			end)

			it("should handle unknown command correctly", function()
				local acd = libStubReturn["AceConfigDialog-3.0"]
				spy.on(acd, "Open")
				RLF:OnInitialize()
				RLF:SlashCommand("unknown")
				assert.spy(acd.Open).was.called_with(_, "TestAddon")
			end)
		end)

		describe("PLAYER_ENTERING_WORLD", function()
			it("should handle PLAYER_ENTERING_WORLD event correctly", function()
				ns.db.global.blizzOverrides.enableAutoLoot = true
				ns.RLF_MainLootFrame = {
					UpdateTabVisibility = spy.new(function() end),
				}
				nsMocks.RGBAToHexFormat.returns("|cFFFFFFFF")
				local fakeNotifModule = {
					ViewAllNotifications = spy.new(function() end),
				}
				local stubGetModule = stub(RLF, "GetModule", function(_, moduleName)
					if moduleName == "Notifications" then
						return fakeNotifModule
					end
				end)
				spy.on(RLF, "PLAYER_ENTERING_WORLD")
				RLF:PLAYER_ENTERING_WORLD("PLAYER_ENTERING_WORLD", true, false)
				assert.spy(RLF.PLAYER_ENTERING_WORLD).was.called(1)
				assert.spy(fakeNotifModule.ViewAllNotifications).was.called(1)
				assert.spy(ns.RLF_MainLootFrame.UpdateTabVisibility).was.called(1)
			end)
		end)

		describe("OnOptionsOpen/OnOptionsClose", function()
			it("shows the bounding box when the options are opened", function()
				local spyScheduleTimer = spy.on(RLF, "ScheduleTimer")
				local spySetBoundingBoxViz = spy.on(ns.LootDisplay, "SetBoundingBoxVisibility")
				RLF:OnOptionsOpen(nil, "TestAddon", nil, nil)
				assert.spy(spyScheduleTimer).was.called(1)
				assert.spy(spySetBoundingBoxViz).was.called_with(_, true)
			end)

			it("does nothing if the options are already open", function()
				local spyScheduleTimer = spy.on(RLF, "ScheduleTimer")
				local spySetBoundingBoxViz = spy.on(ns.LootDisplay, "SetBoundingBoxVisibility")
				RLF:OnOptionsOpen(nil, "TestAddon", nil, nil)
				RLF:OnOptionsOpen(nil, "TestAddon", nil, nil)
				assert.spy(spyScheduleTimer).was.called(1)
				assert.spy(spySetBoundingBoxViz).was.called(1)
			end)

			it("hides the bounding box when the options are closed", function()
				local spySetBoundingBoxViz = spy.on(ns.LootDisplay, "SetBoundingBoxVisibility")
				local spyHook = spy.on(RLF, "Hook")
				local stubScheduleTimer = stub(RLF, "ScheduleTimer", function(self, func, delay)
					func()
				end)
				ns.acd = {
					OpenFrames = {
						TestAddon = {
							Hide = function() end,
						},
					},
				}
				RLF:OnOptionsOpen(nil, "TestAddon", nil, nil)
				RLF:OnOptionsClose(nil, "TestAddon", nil, nil)
				assert.spy(spySetBoundingBoxViz).was.called_with(_, false)
				assert.spy(spyHook).was.called(1)
			end)
		end)
	end)

	describe("EllesmereUI skin registration", function()
		local after_each = busted.after_each

		local function loadCoreWithEllesmereUI(ellesmereUI)
			_G.EllesmereUI = ellesmereUI
			---@type test_G_RLF
			ns = nsMocks:unitLoadedAfter(nsMocks.LoadSections.All)
			RLF = assert(loadfile("RPGLootFeed/Core.lua"))("TestAddon", ns)
			return ns
		end

		after_each(function()
			_G.EllesmereUI = nil
		end)

		it("leaves both handles nil when EllesmereUI is absent", function()
			loadCoreWithEllesmereUI(nil)
			assert.is_nil(ns.EllesmereUI)
			assert.is_nil(ns.EUISkin)
		end)

		it("registers under the addon name when EllesmereUI is present", function()
			local eui = { RegisterSkin = function() end }
			stub(eui, "RegisterSkin")
			loadCoreWithEllesmereUI(eui)
			assert.stub(eui.RegisterSkin).was.called(1)
			assert.equal("TestAddon", eui.RegisterSkin.calls[1].vals[1])
		end)

		it("captures the facade when the callback is dispatched", function()
			local facade = { SquareIcon = function() end }
			local eui = {
				-- EllesmereUI dispatches at PLAYER_LOGIN; calling straight
				-- through models a late/LoD registration.
				RegisterSkin = function(_, applyFn)
					applyFn(facade)
				end,
			}
			loadCoreWithEllesmereUI(eui)
			assert.equal(eui, ns.EllesmereUI)
			assert.equal(facade, ns.EUISkin)
		end)

		it("exposes EllesmereUI but no facade until the callback runs", function()
			-- Queued registration, or third-party skinning disabled in
			-- EllesmereUI's own options: the callback never fires.
			local eui = { RegisterSkin = function() end }
			loadCoreWithEllesmereUI(eui)
			assert.equal(eui, ns.EllesmereUI)
			assert.is_nil(ns.EUISkin)
		end)

		it("does not register when EllesmereUI predates the skinning API", function()
			local eui = {}
			loadCoreWithEllesmereUI(eui)
			assert.equal(eui, ns.EllesmereUI)
			assert.is_nil(ns.EUISkin)
		end)
	end)
end)
