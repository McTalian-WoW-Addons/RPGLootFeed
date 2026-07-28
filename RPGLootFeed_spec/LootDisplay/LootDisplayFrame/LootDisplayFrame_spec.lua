local nsMocks = require("RPGLootFeed_spec._mocks.Internal.addonNamespace")
local assert = require("luassert")
local match = require("luassert.match")
local busted = require("busted")
local before_each = busted.before_each
local describe = busted.describe
local it = busted.it
local spy = busted.spy
local stub = busted.stub

describe("LootDisplayFrameMixin", function()
	local ns, _
	_ = match._

	describe("load order", function()
		it("loads the file successfully", function()
			ns = nsMocks:unitLoadedAfter(nsMocks.LoadSections.LootDisplay)
			local loaded =
				assert(loadfile("RPGLootFeed/LootDisplay/LootDisplayFrame/LootDisplayFrame.lua"))("TestAddon", ns)
			assert.is_not_nil(loaded)
			assert.is_not_nil(_G.LootDisplayFrameMixin)
			assert.is_not_nil(_G.LootDisplayFrameMixin.Load)
			assert.is_not_nil(_G.LootDisplayFrameMixin.getFrameHeight)
			assert.is_not_nil(_G.LootDisplayFrameMixin.LeaseRow)
			assert.is_not_nil(_G.LootDisplayFrameMixin.ReleaseRow)
			assert.is_not_nil(_G.LootDisplayFrameMixin.UpdateSize)
			assert.is_not_nil(_G.LootDisplayFrameMixin.IsFeatureEnabled)
			assert.is_not_nil(_G.LootDisplayFrameMixin.PassesPerFrameFilters)
		end)
	end)

	local frame, mockSizing, mockPositioning, mockStyling, mockAnimations, mockGlobalFns
	before_each(function()
		mockGlobalFns = require("RPGLootFeed_spec._mocks.WoWGlobals.Functions")
		-- Define the global G_RLF
		ns = nsMocks:unitLoadedAfter(nsMocks.LoadSections.All)

		-- Load the module before each test
		frame = assert(loadfile("RPGLootFeed/LootDisplay/LootDisplayFrame/LootDisplayFrame.lua"))("TestAddon", ns)

		-- Set up necessary mocks for DBAccessor
		mockSizing = stub(ns.DbAccessor, "Sizing").returns({
			maxRows = 5,
			rowHeight = 40,
			padding = 8,
			feedWidth = 300,
		})

		mockPositioning = stub(ns.DbAccessor, "Positioning").returns({
			anchorPoint = "CENTER",
			relativePoint = "UIParent",
			xOffset = 1,
			yOffset = 2,
			frameStrata = "MEDIUM",
		})

		mockStyling = stub(ns.DbAccessor, "Styling").returns({
			growUp = true,
		})

		mockAnimations = stub(ns.DbAccessor, "Animations").returns({
			reposition = { duration = 0 },
		})
	end)

	it("initializes correctly with Load method", function()
		mockGlobalFns.CreateFramePool.returns({})

		local testList = {}
		nsMocks.list.returns(testList)
		local stubGetPositioningDetails = stub(frame, "getPositioningDetails")
		local stubInitQueueLabel = stub(frame, "InitQueueLabel")
		local stubUpdateSize = stub(frame, "UpdateSize")
		local stubSetPoint = stub(frame, "SetPoint")
		local stubSetFrameStrata = stub(frame, "SetFrameStrata")
		local stubConfigureTestArea = stub(frame, "ConfigureTestArea")
		local stubCreateTab = stub(frame, "CreateTab")
		stub(frame, "UpdateOverlayFrameDepth")
		stub(frame, "CreateScrollWheelTarget")

		frame:Load(ns.Frames.MAIN)

		assert.equal(ns.Frames.MAIN, frame.frameType)
		assert.equal(testList, frame.rows)
		assert.equal(0, frame.keyRowMap.length)
		assert.equal(0, #frame.rowHistory)
		assert.is_not_nil(frame.rowFramePool)
		assert.stub(stubGetPositioningDetails).was.called(1)
		assert.stub(mockPositioning).was.called(1)
		assert.stub(mockPositioning).was.called_with(ns.DbAccessor, ns.Frames.MAIN)
		assert.stub(stubUpdateSize).was.called(1)
		assert.stub(stubSetPoint).was.called(1)
		assert.stub(stubSetPoint).was.called_with(frame, "CENTER", _G["UIParent"], 1, 2)
		assert.stub(stubSetFrameStrata).was.called(1)
		assert.stub(stubSetFrameStrata).was.called_with(frame, "MEDIUM")
		assert.stub(stubConfigureTestArea).was.called(1)
		assert.stub(stubCreateTab).was.called(1)
	end)

	it("calculates frame height correctly with getFrameHeight", function()
		local mockSizingData = {
			maxRows = 3,
			rowHeight = 20,
			padding = 5,
		}
		mockSizing.returns(mockSizingData)
		frame.frameType = ns.Frames.MAIN

		local result = frame:getFrameHeight()

		-- Expected height calculation from actual implementation: maxRows * (rowHeight + padding) - padding
		local expectedHeight = mockSizingData.maxRows * (mockSizingData.rowHeight + mockSizingData.padding)
			- mockSizingData.padding
		assert.equal(expectedHeight, result)
		assert.stub(mockSizing).was.called(1)
		assert.stub(mockSizing).was.called_with(ns.DbAccessor, ns.Frames.MAIN)
	end)

	it("returns correct row count with getNumberOfRows", function()
		frame.rows = { length = 3 }
		local result = frame:getNumberOfRows()
		assert.equal(3, result)
	end)

	it("retrieves positioning details correctly with getPositioningDetails", function()
		mockStyling.returns({ growUp = true })
		frame.frameType = ns.Frames.MAIN
		mockSizing.returns({ padding = 8 })

		local vertDir, opposite, yOffset = frame:getPositioningDetails()

		assert.equal("BOTTOM", vertDir)
		assert.equal("TOP", opposite)
		assert.equal(8, yOffset)

		-- Test with growUp = false
		mockStyling.returns({ growUp = false })
		vertDir, opposite, yOffset = frame:getPositioningDetails()

		assert.equal("TOP", vertDir)
		assert.equal("BOTTOM", opposite)
		assert.equal(-8, yOffset) -- negative when growing down
	end)

	it("leases a row correctly with LeaseRow", function()
		-- Set up mocks
		local mockRow = {
			Init = spy.new(function() end),
			SetParent = spy.new(function() end),
			UpdatePosition = spy.new(function() end),
			Hide = spy.new(function() end),
			ResetHighlightBorder = spy.new(function() end),
		}
		frame.rowFramePool = {
			Acquire = spy.new(function()
				return mockRow
			end),
		}
		frame.frameType = ns.Frames.MAIN
		frame.rows = {
			push = spy.new(function()
				return true
			end),
			length = 0,
		}
		frame.keyRowMap = { length = 0 }
		frame.rowHistory = {}

		local stubUpdateTabVisibility = stub(frame, "UpdateTabVisibility")
		local stubGetNumberOfRows = stub(frame, "getNumberOfRows").returns(0)
		mockSizing.returns({ maxRows = 5 })

		local key = "testKey"
		local result = frame:LeaseRow(key)

		-- Check basic setup
		assert.equal(mockRow, result)
		assert.equal(key, mockRow.key)
		assert.equal(frame.frameType, mockRow.frameType)

		-- Check that necessary methods were called
		assert.spy(frame.rowFramePool.Acquire).was.called(1)
		assert.spy(frame.rows.push).was.called(1)
		assert.spy(frame.rows.push).was.called_with(frame.rows, mockRow)
		assert.spy(mockRow.Init).was.called(1)
		assert.spy(mockRow.SetParent).was.called(1)
		assert.equal(frame, mockRow.SetParent.calls[1].refs[2])
		assert.equal(mockRow, frame.keyRowMap[key])
		assert.equal(1, frame.keyRowMap.length)
		assert.spy(mockRow.UpdatePosition).was.called(1)
		assert.spy(mockRow.UpdatePosition).was.called_with(mockRow, frame)

		-- Check keyRowMap updates
		assert.equal(1, frame.keyRowMap.length)
		assert.equal(mockRow, frame.keyRowMap[key])

		-- Check that RunNextFrame was called twice
		assert.spy(mockGlobalFns.RunNextFrame).was.called(2)

		-- Check UpdateTabVisibility was called
		assert.stub(stubUpdateTabVisibility).was.called(1)
	end)

	it("doesn't lease a row when at max capacity", function()
		frame.frameType = ns.Frames.MAIN
		local stubGetNumberOfRows = stub(frame, "getNumberOfRows").returns(5)
		mockSizing.returns({ maxRows = 5 })

		local result = frame:LeaseRow("testKey")

		assert.is_nil(result)
	end)

	it("leases a sample row even when at max capacity", function()
		local mockRow = {
			Init = spy.new(function() end),
			SetParent = spy.new(function() end),
			UpdatePosition = spy.new(function() end),
			Hide = spy.new(function() end),
			ResetHighlightBorder = spy.new(function() end),
		}
		frame.rowFramePool = {
			Acquire = spy.new(function()
				return mockRow
			end),
		}
		frame.frameType = ns.Frames.MAIN
		frame.rows = {
			push = spy.new(function()
				return true
			end),
			length = 0,
		}
		frame.keyRowMap = { length = 0 }
		stub(frame, "UpdateTabVisibility")
		stub(frame, "getNumberOfRows").returns(5)
		mockSizing.returns({ maxRows = 5 })

		local result = frame:LeaseRow("sample_item_loot", true)

		assert.is_not_nil(result)
		assert.equal(mockRow, result)
	end)

	it("releases a row correctly with ReleaseRow", function()
		-- Set up mocks
		local mockRow = {
			key = "testKey",
			UpdateNeighborPositions = spy.new(function() end),
			SetParent = spy.new(function() end),
			Reset = spy.new(function() end),
			Dump = spy.new(function()
				return "mockRowDump"
			end),
		}
		frame.rowFramePool = {
			Release = spy.new(function() end),
		}
		-- FLIP is disabled by the default mockAnimations (duration = 0),
		-- so rows only needs `remove` — no `iterate` required.
		frame.rows = {
			remove = spy.new(function(self, row)
				return true
			end), -- Return true to indicate success
		}
		frame.keyRowMap = {
			length = 1,
			["testKey"] = mockRow,
		}
		local stubStoreRowHistory = stub(frame, "StoreRowHistory")
		local stubUpdateTabVisibility = stub(frame, "UpdateTabVisibility")
		frame.frameType = ns.Frames.MAIN
		frame.shiftingRowCount = 0
		frame.bypassShiftAnimation = false

		frame:ReleaseRow(mockRow)

		-- Check that the keyRowMap was updated
		assert.is_nil(mockRow.key)
		assert.equal(0, frame.keyRowMap.length)
		assert.is_nil(frame.keyRowMap["testKey"])

		-- Check that methods were called
		assert.stub(stubStoreRowHistory).was.called(1)
		assert.equal(mockRow, stubStoreRowHistory.calls[1].refs[2])
		assert.spy(mockRow.UpdateNeighborPositions).was.called(1)
		assert.equal(frame, mockRow.UpdateNeighborPositions.calls[1].refs[2])
		assert.spy(frame.rows.remove).was.called(1)
		assert.equal(mockRow, frame.rows.remove.calls[1].refs[2])
		assert.spy(mockRow.SetParent).was.called(1)
		assert.equal(nil, mockRow.SetParent.calls[1].refs[2])
		assert.spy(mockRow.Reset).was.called(1)
		assert.spy(frame.rowFramePool.Release).was.called(1)
		assert.spy(frame.rowFramePool.Release).was.called_with(frame.rowFramePool, mockRow)

		-- Check that SendMessage was called with the frame type
		assert.spy(nsMocks.SendMessage).was.called(1)
		assert.spy(nsMocks.SendMessage).was.called_with(ns, "RLF_ROW_RETURNED", ns.Frames.MAIN)

		-- Check that UpdateTabVisibility was called
		assert.stub(stubUpdateTabVisibility).was.called(1)
	end)

	it("updates size correctly with UpdateSize", function()
		-- Set up mocks
		local stubGetFrameHeight = stub(frame, "getFrameHeight").returns(100)
		local stubSetSize = stub(frame, "SetSize")
		frame.frameType = ns.Frames.MAIN
		mockSizing.returns({
			feedWidth = 300,
		})

		-- Properly mock rows with finite iteration
		local mockRow = {
			UpdateStyles = spy.new(function() end),
		}

		-- Create a proper iterator function that returns exactly one row and then nil
		local iteratorCalled = false
		frame.rows = {
			iterate = function()
				return function()
					if not iteratorCalled then
						iteratorCalled = true
						return mockRow
					end
					return nil -- Return nil to end iteration
				end
			end,
		}

		frame:UpdateSize()

		-- Check that getFrameHeight was called
		assert.stub(stubGetFrameHeight).was.called(1)

		-- Check that SetSize was called with correct values
		assert.stub(stubSetSize).was.called(1)
		assert.stub(stubSetSize).was.called_with(frame, 300, 100)

		-- Check that row styles were updated
		assert.spy(mockRow.UpdateStyles).was.called(1)

		assert.stub(mockSizing).was.called(1)
		assert.stub(mockSizing).was.called_with(ns.DbAccessor, ns.Frames.MAIN)
	end)

	it("configures test area correctly", function()
		-- Set up mocks
		frame.BoundingBox = {
			Hide = spy.new(function() end),
		}
		frame.InstructionText = {
			SetText = spy.new(function() end),
			Hide = spy.new(function() end),
		}
		local stubMakeUnmovable = stub(frame, "MakeUnmovable")
		local stubCreateArrowsTestArea = stub(frame, "CreateArrowsTestArea")

		frame.frameType = ns.Frames.MAIN
		ns.L = {
			["Party Loot"] = "Party Loot",
			["Drag to Move"] = "Drag to Move",
		}

		frame:ConfigureTestArea()

		-- Check that methods were called
		assert.spy(frame.BoundingBox.Hide).was.called(1)
		assert.stub(stubMakeUnmovable).was.called(1)
		assert.spy(frame.InstructionText.SetText).was.called(1)
		assert
			.spy(frame.InstructionText.SetText).was
			.called_with(frame.InstructionText, "TestAddon - Main\nDrag to Move")
		assert.spy(frame.InstructionText.Hide).was.called(1)
		assert.stub(stubCreateArrowsTestArea).was.called(1)
	end)

	it("creates frame tab correctly", function()
		frame.frameType = ns.Frames.MAIN

		local mockTab = {
			SetClampedToScreen = spy.new(function() end),
			SetSize = spy.new(function() end),
			SetPoint = spy.new(function() end),
			ClearAllPoints = spy.new(function() end),
			SetAlpha = spy.new(function() end),
			Hide = spy.new(function() end),
			SetScript = spy.new(function() end),
			CreateTexture = spy.new(function()
				return {
					SetTexture = spy.new(function() end),
					SetAllPoints = spy.new(function() end),
				}
			end),
		}

		mockGlobalFns.CreateFrame.returns(mockTab)
		mockStyling.returns({ growUp = true })
		stub(frame, "UpdateOverlayFrameDepth")

		frame:CreateTab()

		-- Check that CreateFrame was called correctly
		assert.spy(mockGlobalFns.CreateFrame).was.called(1)
		assert.spy(mockGlobalFns.CreateFrame).was.called_with("Button", nil, _G.UIParent, "UIPanelButtonTemplate")

		-- Check that the tab was configured
		assert.spy(mockTab.SetSize).was.called(1)
		assert.spy(mockTab.SetSize).was.called_with(mockTab, 14, 14)
		assert.spy(mockTab.SetPoint).was.called(1)
		assert.spy(mockTab.SetPoint).was.called_with(mockTab, "BOTTOMLEFT", frame, "BOTTOMLEFT", -14, 0)
		assert.spy(mockTab.SetAlpha).was.called(1)
		assert.spy(mockTab.SetAlpha).was.called_with(mockTab, 0.2)
		assert.spy(mockTab.Hide).was.called(1)

		-- Check that texture was created
		assert.spy(mockTab.CreateTexture).was.called(1)

		-- Check that scripts were set
		assert.spy(mockTab.SetScript).was.called(3) -- OnEnter, OnLeave, OnClick
	end)

	it("creates tab with different positioning when growing down", function()
		frame.frameType = ns.Frames.MAIN

		local mockTab = {
			SetClampedToScreen = spy.new(function() end),
			SetSize = spy.new(function() end),
			SetPoint = spy.new(function() end),
			ClearAllPoints = spy.new(function() end),
			SetAlpha = spy.new(function() end),
			Hide = spy.new(function() end),
			SetScript = spy.new(function() end),
			CreateTexture = spy.new(function()
				return {
					SetTexture = spy.new(function() end),
					SetAllPoints = spy.new(function() end),
				}
			end),
		}

		mockGlobalFns.CreateFrame.returns(mockTab)
		mockStyling.returns({ growUp = false }) -- Growing down
		stub(frame, "UpdateOverlayFrameDepth")

		frame:CreateTab()

		-- Check tab position was set correctly for growUp = false
		assert.spy(mockTab.SetPoint).was.called(1)
		assert.spy(mockTab.SetPoint).was.called_with(mockTab, "TOPLEFT", frame, "TOPLEFT", 0, 0)
	end)

	it("creates arrows test area correctly", function()
		frame.ArrowUp = { SetRotation = spy.new(function() end), Hide = spy.new(function() end) }
		frame.ArrowDown = { SetRotation = spy.new(function() end), Hide = spy.new(function() end) }
		frame.ArrowLeft = { SetRotation = spy.new(function() end), Hide = spy.new(function() end) }
		frame.ArrowRight = { SetRotation = spy.new(function() end), Hide = spy.new(function() end) }

		frame:CreateArrowsTestArea()

		-- Check arrows array was created
		assert.are.same({ frame.ArrowUp, frame.ArrowDown, frame.ArrowLeft, frame.ArrowRight }, frame.arrows)

		-- Check arrow rotations
		assert.spy(frame.ArrowUp.SetRotation).was.called(1)
		assert.spy(frame.ArrowUp.SetRotation).was.called_with(frame.ArrowUp, 0)
		assert.spy(frame.ArrowDown.SetRotation).was.called(1)
		assert.spy(frame.ArrowDown.SetRotation).was.called_with(frame.ArrowDown, math.pi)
		assert.spy(frame.ArrowLeft.SetRotation).was.called(1)
		assert.spy(frame.ArrowLeft.SetRotation).was.called_with(frame.ArrowLeft, math.pi * 0.5)
		assert.spy(frame.ArrowRight.SetRotation).was.called(1)
		assert.spy(frame.ArrowRight.SetRotation).was.called_with(frame.ArrowRight, math.pi * 1.5)

		-- Check all arrows are hidden
		assert.spy(frame.ArrowUp.Hide).was.called(1)
		assert.spy(frame.ArrowDown.Hide).was.called(1)
		assert.spy(frame.ArrowLeft.Hide).was.called(1)
		assert.spy(frame.ArrowRight.Hide).was.called(1)
	end)

	describe("IsFeatureEnabled", function()
		before_each(function()
			frame.frameType = ns.Frames.MAIN
		end)

		it("returns true when the feature is enabled for this frame", function()
			ns.db.global.frames[ns.Frames.MAIN] = {
				features = {
					itemLoot = { enabled = true },
				},
			}
			local element = { type = ns.FeatureModule.ItemLoot }
			assert.is_true(frame:IsFeatureEnabled(element))
		end)

		it("returns false when the feature is disabled for this frame", function()
			ns.db.global.frames[ns.Frames.MAIN] = {
				features = {
					itemLoot = { enabled = false },
				},
			}
			local element = { type = ns.FeatureModule.ItemLoot }
			assert.is_false(frame:IsFeatureEnabled(element))
		end)

		it("returns false for an unknown element type when IsEnabled returns false", function()
			ns.db.global.frames[ns.Frames.MAIN] = {
				features = {
					itemLoot = { enabled = true },
				},
			}
			local element = {
				type = "UNKNOWN_FEATURE",
				IsEnabled = function()
					return false
				end,
			}
			assert.is_false(frame:IsFeatureEnabled(element))
		end)

		it("returns true for a non-feature element on the main frame when IsEnabled returns true", function()
			frame.frameType = ns.Frames.MAIN
			local element = {
				type = "Notifications",
				IsEnabled = function()
					return true
				end,
			}
			assert.is_true(frame:IsFeatureEnabled(element))
		end)

		it("returns false for a non-feature element on a secondary frame", function()
			frame.frameType = 2
			local element = {
				type = "Notifications",
				IsEnabled = function()
					return true
				end,
			}
			assert.is_false(frame:IsFeatureEnabled(element))
		end)

		it("returns false when the frame has no config", function()
			ns.db.global.frames[ns.Frames.MAIN] = nil
			local element = { type = ns.FeatureModule.ItemLoot }
			assert.is_false(frame:IsFeatureEnabled(element))
		end)

		it("returns false when the feature key is missing from config", function()
			ns.db.global.frames[ns.Frames.MAIN] = {
				features = {},
			}
			local element = { type = ns.FeatureModule.ItemLoot }
			assert.is_false(frame:IsFeatureEnabled(element))
		end)
	end)

	-- ── PassesPerFrameFilters ───────────────────────────────────────────────────

	describe("PassesPerFrameFilters", function()
		before_each(function()
			frame.frameType = ns.Frames.MAIN
		end)

		it("returns true for non-feature element types", function()
			local element = { type = "Notifications", filterItemQuality = nil }
			assert.is_true(frame:PassesPerFrameFilters(element))
		end)

		it("returns true when frame has no config", function()
			ns.db.global.frames[ns.Frames.MAIN] = nil
			local element = { type = ns.FeatureModule.ItemLoot, filterItemQuality = 2 }
			assert.is_true(frame:PassesPerFrameFilters(element))
		end)

		describe("ItemLoot quality filter", function()
			it("returns true when quality tier is enabled", function()
				ns.db.global.frames[ns.Frames.MAIN] = {
					features = {
						itemLoot = {
							enabled = true,
							itemQualitySettings = { [2] = { enabled = true, duration = 0 } },
						},
					},
				}
				local element = { type = ns.FeatureModule.ItemLoot, filterItemQuality = 2 }
				assert.is_true(frame:PassesPerFrameFilters(element))
			end)

			it("returns false when quality tier is disabled", function()
				ns.db.global.frames[ns.Frames.MAIN] = {
					features = {
						itemLoot = {
							enabled = true,
							itemQualitySettings = { [2] = { enabled = false, duration = 0 } },
						},
					},
				}
				local element = { type = ns.FeatureModule.ItemLoot, filterItemQuality = 2 }
				assert.is_false(frame:PassesPerFrameFilters(element))
			end)

			it("returns false when quality tier is absent from settings", function()
				ns.db.global.frames[ns.Frames.MAIN] = {
					features = {
						itemLoot = { enabled = true, itemQualitySettings = {} },
					},
				}
				local element = { type = ns.FeatureModule.ItemLoot, filterItemQuality = 2 }
				assert.is_false(frame:PassesPerFrameFilters(element))
			end)
		end)

		describe("PartyLoot quality filter", function()
			it("returns true when quality is in itemQualityFilter", function()
				ns.db.global.frames[ns.Frames.MAIN] = {
					features = {
						partyLoot = { enabled = true, itemQualityFilter = { [4] = true } },
					},
				}
				local element = { type = ns.FeatureModule.PartyLoot, filterItemQuality = 4 }
				assert.is_true(frame:PassesPerFrameFilters(element))
			end)

			it("returns false when quality is not in itemQualityFilter", function()
				ns.db.global.frames[ns.Frames.MAIN] = {
					features = {
						partyLoot = { enabled = true, itemQualityFilter = { [4] = true } },
					},
				}
				local element = { type = ns.FeatureModule.PartyLoot, filterItemQuality = 2 }
				assert.is_false(frame:PassesPerFrameFilters(element))
			end)
		end)

		describe("item ID deny list", function()
			it("returns true when ignoreItemIds is empty", function()
				ns.db.global.frames[ns.Frames.MAIN] = {
					features = {
						itemLoot = {
							enabled = true,
							itemQualitySettings = { [2] = { enabled = true } },
							ignoreItemIds = {},
						},
					},
				}
				local element = {
					type = ns.FeatureModule.ItemLoot,
					filterItemQuality = 2,
					filterItemId = 18803,
				}
				assert.is_true(frame:PassesPerFrameFilters(element))
			end)

			it("returns false when item ID is in the deny list", function()
				ns.db.global.frames[ns.Frames.MAIN] = {
					features = {
						itemLoot = {
							enabled = true,
							itemQualitySettings = { [2] = { enabled = true } },
							ignoreItemIds = { 18803 },
						},
					},
				}
				local element = {
					type = ns.FeatureModule.ItemLoot,
					filterItemQuality = 2,
					filterItemId = 18803,
				}
				assert.is_false(frame:PassesPerFrameFilters(element))
			end)
		end)

		describe("currency ID deny list", function()
			it("returns true when ignoreCurrencyIds is empty", function()
				ns.db.global.frames[ns.Frames.MAIN] = {
					features = {
						currency = { enabled = true, ignoreCurrencyIds = {} },
					},
				}
				local element = { type = ns.FeatureModule.Currency, filterCurrencyId = 1792 }
				assert.is_true(frame:PassesPerFrameFilters(element))
			end)

			it("returns false when currency ID is in the deny list", function()
				ns.db.global.frames[ns.Frames.MAIN] = {
					features = {
						currency = { enabled = true, ignoreCurrencyIds = { 1792 } },
					},
				}
				local element = { type = ns.FeatureModule.Currency, filterCurrencyId = 1792 }
				assert.is_false(frame:PassesPerFrameFilters(element))
			end)
		end)

		it("frame 1 and frame 2 can have independent quality settings", function()
			ns.db.global.frames[ns.Frames.MAIN] = {
				features = {
					itemLoot = {
						enabled = true,
						itemQualitySettings = { [2] = { enabled = false } },
					},
				},
			}
			ns.db.global.frames[2] = {
				features = {
					itemLoot = {
						enabled = true,
						itemQualitySettings = { [2] = { enabled = true } },
					},
				},
			}
			local element = { type = ns.FeatureModule.ItemLoot, filterItemQuality = 2 }

			frame.frameType = ns.Frames.MAIN
			assert.is_false(frame:PassesPerFrameFilters(element))

			frame.frameType = 2
			assert.is_true(frame:PassesPerFrameFilters(element))
		end)
	end)

	-- ── SetCombatClickThrough ──────────────────────────────────────────────

	describe("SetCombatClickThrough", function()
		local function makeIterableRows(rows)
			return {
				iterate = function()
					local i = 0
					return function()
						i = i + 1
						return rows[i]
					end
				end,
			}
		end

		it(
			"sets isClickThrough=true and calls SetClickThrough(true) on rows when in combat and setting enabled",
			function()
				ns.db.global.interactions = { disableMouseInCombat = true, disableAllInteraction = false }
				local mockRow = { SetClickThrough = spy.new(function() end) }
				frame.rows = makeIterableRows({ mockRow })

				frame:SetCombatClickThrough(true)

				assert.is_true(frame.isClickThrough)
				assert.spy(mockRow.SetClickThrough).was.called_with(mockRow, true)
			end
		)

		it("sets isClickThrough=false when leaving combat", function()
			ns.db.global.interactions = { disableMouseInCombat = true, disableAllInteraction = false }
			local mockRow = { SetClickThrough = spy.new(function() end) }
			frame.rows = makeIterableRows({ mockRow })

			frame:SetCombatClickThrough(false)

			assert.is_false(frame.isClickThrough)
			assert.spy(mockRow.SetClickThrough).was.called_with(mockRow, false)
		end)

		it("does not set isClickThrough when setting is disabled", function()
			ns.db.global.interactions = { disableMouseInCombat = false, disableAllInteraction = false }
			local mockRow = { SetClickThrough = spy.new(function() end) }
			frame.rows = makeIterableRows({ mockRow })

			frame:SetCombatClickThrough(true)

			assert.is_false(frame.isClickThrough)
			assert.spy(mockRow.SetClickThrough).was.called_with(mockRow, false)
		end)
	end)

	-- ── LeaseRow click-through propagation ────────────────────────────────

	describe("LeaseRow with isClickThrough", function()
		it("calls SetClickThrough(true) on a new row when frame is in click-through mode", function()
			local mockRow = {
				Init = spy.new(function() end),
				SetParent = spy.new(function() end),
				UpdatePosition = spy.new(function() end),
				Hide = spy.new(function() end),
				ResetHighlightBorder = spy.new(function() end),
				SetClickThrough = spy.new(function() end),
			}
			frame.rowFramePool = {
				Acquire = spy.new(function()
					return mockRow
				end),
			}
			frame.frameType = ns.Frames.MAIN
			frame.rows = {
				push = spy.new(function()
					return true
				end),
				length = 0,
			}
			frame.keyRowMap = { length = 0 }
			frame.isClickThrough = true
			stub(frame, "UpdateTabVisibility")
			stub(frame, "getNumberOfRows").returns(0)
			mockSizing.returns({ maxRows = 5 })

			frame:LeaseRow("testKey")

			assert.spy(mockRow.SetClickThrough).was.called_with(mockRow, true)
		end)

		it("does not call SetClickThrough when frame is not in click-through mode", function()
			local mockRow = {
				Init = spy.new(function() end),
				SetParent = spy.new(function() end),
				UpdatePosition = spy.new(function() end),
				Hide = spy.new(function() end),
				ResetHighlightBorder = spy.new(function() end),
				SetClickThrough = spy.new(function() end),
			}
			frame.rowFramePool = {
				Acquire = spy.new(function()
					return mockRow
				end),
			}
			frame.frameType = ns.Frames.MAIN
			frame.rows = {
				push = spy.new(function()
					return true
				end),
				length = 0,
			}
			frame.keyRowMap = { length = 0 }
			frame.isClickThrough = false
			stub(frame, "UpdateTabVisibility")
			stub(frame, "getNumberOfRows").returns(0)
			mockSizing.returns({ maxRows = 5 })

			frame:LeaseRow("testKey")

			assert.spy(mockRow.SetClickThrough).was_not.called()
		end)
	end)

	-- ── ReleaseRow shift animation (FLIP) ──────────────────────────────────

	describe("ReleaseRow shift animation", function()
		--- Build a minimal iterable rows mock with the given list of row tables.
		local function makeIterableRows(rows)
			return {
				last = rows[#rows],
				iterate = function()
					local i = 0
					return function()
						i = i + 1
						return rows[i]
					end
				end,
				remove = spy.new(function() end),
			}
		end

		--- Build a minimal mock row with the layout methods FLIP needs.
		local function makeShiftRow(key, bottomY)
			local r = {
				key = key,
				isSampleRow = false,
				UpdateNeighborPositions = spy.new(function() end),
				SetParent = spy.new(function() end),
				Reset = spy.new(function() end),
				AnimateShift = spy.new(function() end),
				ClearAllPoints = spy.new(function() end),
				SetPoint = spy.new(function() end),
				UpdatePosition = spy.new(function() end),
				GetBottom = function()
					return bottomY
				end,
				GetTop = function()
					return bottomY + 22
				end,
				ShiftAnimation = nil,
				_shiftFinalFrameOffset = nil,
				_textHiddenForShift = false,
				PrimaryLineLayout = { SetAlpha = spy.new(function() end) },
				SecondaryLineLayout = { SetAlpha = spy.new(function() end) },
				Dump = function()
					return key
				end,
			}
			return r
		end

		before_each(function()
			frame.frameType = ns.Frames.MAIN
			frame.vertDir = "BOTTOM"
			frame.shiftingRowCount = 0
			frame.bypassShiftAnimation = false
			frame.keyRowMap = { length = 0 }
			frame.rowHistory = {}
			frame.rowFramePool = { Release = spy.new(function() end) }
			stub(frame, "StoreRowHistory")
			stub(frame, "UpdateTabVisibility")
			stub(frame, "GetBottom").returns(0)
		end)

		it("skips FLIP and sends RLF_ROW_RETURNED immediately when duration <= 0.04", function()
			mockAnimations.returns({ reposition = { duration = 0 } })
			local releasedRow = makeShiftRow("key1", 100)
			local remainingRow = makeShiftRow("key2", 150)
			frame.rows = makeIterableRows({ releasedRow, remainingRow })
			frame.keyRowMap = { length = 1, key1 = releasedRow }

			frame:ReleaseRow(releasedRow)

			assert.spy(remainingRow.AnimateShift).was_not.called()
			assert.spy(nsMocks.SendMessage).was.called_with(ns, "RLF_ROW_RETURNED", ns.Frames.MAIN)
		end)

		it("calls AnimateShift on remaining rows that moved", function()
			mockAnimations.returns({ reposition = { duration = 0.2 } })
			local releasedRow = makeShiftRow("key1", 100)
			-- Remaining row sits at 150 before snap, snaps to 120 after
			local snapCount = 0
			local remainingRow = makeShiftRow("key2", 150)
			remainingRow.GetBottom = function()
				snapCount = snapCount + 1
				-- First call (snapshot) = 150; after UpdateNeighborPositions = 120
				if snapCount == 1 then
					return 150
				end
				return 120
			end
			frame.rows = makeIterableRows({ releasedRow, remainingRow })
			frame.keyRowMap = { length = 1, key1 = releasedRow }

			frame:ReleaseRow(releasedRow)

			assert.spy(remainingRow.AnimateShift).was.called(1)
			-- yDelta = oldEdge - newEdge = 150 - 120 = 30, oldEdgeY = 150
			assert.spy(remainingRow.AnimateShift).was.called_with(remainingRow, 30, 150)
		end)

		it("does NOT send RLF_ROW_RETURNED immediately when at least one row shifts", function()
			mockAnimations.returns({ reposition = { duration = 0.2 } })
			local releasedRow = makeShiftRow("key1", 100)
			local snapCount = 0
			local remainingRow = makeShiftRow("key2", 150)
			remainingRow.GetBottom = function()
				snapCount = snapCount + 1
				if snapCount == 1 then
					return 150
				end
				return 120
			end
			frame.rows = makeIterableRows({ releasedRow, remainingRow })
			frame.keyRowMap = { length = 1, key1 = releasedRow }

			frame:ReleaseRow(releasedRow)

			-- RLF_ROW_RETURNED must NOT be sent immediately; OnFinished will send it
			assert.spy(nsMocks.SendMessage).was_not.called()
		end)

		it("skips AnimateShift for rows that did not move (sub-pixel delta)", function()
			mockAnimations.returns({ reposition = { duration = 0.2 } })
			local releasedRow = makeShiftRow("key1", 100)
			-- Remaining row doesn't actually move (still at 150 after snap)
			local remainingRow = makeShiftRow("key2", 150)
			remainingRow.GetBottom = function()
				return 150
			end
			frame.rows = makeIterableRows({ releasedRow, remainingRow })
			frame.keyRowMap = { length = 1, key1 = releasedRow }

			frame:ReleaseRow(releasedRow)

			assert.spy(remainingRow.AnimateShift).was_not.called()
			-- No shifts → message sent immediately
			assert.spy(nsMocks.SendMessage).was.called_with(ns, "RLF_ROW_RETURNED", ns.Frames.MAIN)
		end)

		it("fast-forwards a mid-shift row to _shiftFinalFrameOffset before re-FLIP", function()
			mockAnimations.returns({ reposition = { duration = 0.2 } })
			local releasedRow = makeShiftRow("key1", 100)
			local remainingRow = makeShiftRow("key2", 150)
			remainingRow.GetBottom = function()
				return 150
			end
			remainingRow._shiftFinalFrameOffset = 35
			-- Capture the args passed to SetPoint so we can verify them
			local capturedSetPointArgs
			remainingRow.SetPoint = function(self, ...)
				capturedSetPointArgs = { ... }
			end
			-- Simulate an in-progress ShiftAnimation on the remaining row
			remainingRow.ShiftAnimation = {
				IsPlaying = function()
					return true
				end,
				Stop = spy.new(function() end),
			}
			frame.shiftingRowCount = 1
			frame.rows = makeIterableRows({ releasedRow, remainingRow })
			frame.keyRowMap = { length = 1, key1 = releasedRow }

			frame:ReleaseRow(releasedRow)

			assert.spy(remainingRow.ShiftAnimation.Stop).was.called(1)
			assert.spy(remainingRow.ClearAllPoints).was.called(1)
			assert.is_not_nil(capturedSetPointArgs)
			assert.equal(frame.vertDir, capturedSetPointArgs[1])
			assert.equal(frame, capturedSetPointArgs[2])
			assert.equal(frame.vertDir, capturedSetPointArgs[3])
			assert.equal(0, capturedSetPointArgs[4])
			assert.equal(35, capturedSetPointArgs[5])
			-- The chain-restore loop (added to fix upstream-row blink) also calls
			-- UpdatePosition once on each remaining row after fast-forwarding.
			assert.spy(remainingRow.UpdatePosition).was.called(1)
			assert.spy(remainingRow.PrimaryLineLayout.SetAlpha).was.called_with(remainingRow.PrimaryLineLayout, 1)
			assert.spy(remainingRow.SecondaryLineLayout.SetAlpha).was.called_with(remainingRow.SecondaryLineLayout, 1)
		end)

		it("falls back to UpdatePosition when _shiftFinalFrameOffset is nil", function()
			mockAnimations.returns({ reposition = { duration = 0.2 } })
			local releasedRow = makeShiftRow("key1", 100)
			local remainingRow = makeShiftRow("key2", 150)
			remainingRow.GetBottom = function()
				return 150
			end
			-- _shiftFinalFrameOffset remains nil (fallback path)
			remainingRow.ShiftAnimation = {
				IsPlaying = function()
					return true
				end,
				Stop = spy.new(function() end),
			}
			frame.shiftingRowCount = 1
			frame.rows = makeIterableRows({ releasedRow, remainingRow })
			frame.keyRowMap = { length = 1, key1 = releasedRow }

			frame:ReleaseRow(releasedRow)

			assert.spy(remainingRow.ShiftAnimation.Stop).was.called(1)
			-- Fallback UpdatePosition (no _shiftFinalFrameOffset) + chain-restore loop = 2 calls.
			assert.spy(remainingRow.UpdatePosition).was.called(2)
		end)

		it("stops releasing row's mid-shift animation and restores text alpha", function()
			mockAnimations.returns({ reposition = { duration = 0.2 } })
			local releasedRow = makeShiftRow("key1", 100)
			releasedRow.ShiftAnimation = {
				IsPlaying = function()
					return true
				end,
				Stop = spy.new(function() end),
			}
			frame.shiftingRowCount = 1
			frame.rows = makeIterableRows({ releasedRow })
			frame.keyRowMap = { length = 1, key1 = releasedRow }

			frame:ReleaseRow(releasedRow)

			assert.spy(releasedRow.ShiftAnimation.Stop).was.called(1)
			assert.spy(releasedRow.PrimaryLineLayout.SetAlpha).was.called_with(releasedRow.PrimaryLineLayout, 1)
			assert.spy(releasedRow.SecondaryLineLayout.SetAlpha).was.called_with(releasedRow.SecondaryLineLayout, 1)
		end)

		it("bypasses FLIP when bypassShiftAnimation is true (ClearFeed path)", function()
			mockAnimations.returns({ reposition = { duration = 0.2 } })
			frame.bypassShiftAnimation = true
			local releasedRow = makeShiftRow("key1", 100)
			local remainingRow = makeShiftRow("key2", 150)
			frame.rows = makeIterableRows({ releasedRow, remainingRow })
			frame.keyRowMap = { length = 1, key1 = releasedRow }

			frame:ReleaseRow(releasedRow)

			assert.spy(remainingRow.AnimateShift).was_not.called()
			assert.spy(nsMocks.SendMessage).was.called_with(ns, "RLF_ROW_RETURNED", ns.Frames.MAIN)
		end)
	end)

	-- ── ReleaseRow pin state ──────────────────────────────────────────────

	describe("ReleaseRow clears hasPinnedRow for pinned rows", function()
		local function makeIterableRows(rows)
			return {
				last = rows[#rows],
				iterate = function()
					local i = 0
					return function()
						i = i + 1
						return rows[i]
					end
				end,
				remove = spy.new(function() end),
			}
		end

		local function makePinnedRow(key, isPinned)
			return {
				key = key,
				isPinned = isPinned,
				isSampleRow = false,
				onReleased = nil,
				UpdateNeighborPositions = spy.new(function() end),
				SetParent = spy.new(function() end),
				Reset = spy.new(function() end),
				AnimateShift = spy.new(function() end),
				ClearAllPoints = spy.new(function() end),
				SetPoint = spy.new(function() end),
				UpdatePosition = spy.new(function() end),
				ShiftAnimation = nil,
				_shiftFinalFrameOffset = nil,
				_textHiddenForShift = false,
				PrimaryLineLayout = { SetAlpha = spy.new(function() end) },
				SecondaryLineLayout = { SetAlpha = spy.new(function() end) },
				GetBottom = function()
					return 100
				end,
				GetTop = function()
					return 122
				end,
				Dump = function()
					return key
				end,
			}
		end

		before_each(function()
			frame.frameType = ns.Frames.MAIN
			frame.vertDir = "BOTTOM"
			frame.shiftingRowCount = 0
			frame.bypassShiftAnimation = false
			frame.keyRowMap = { length = 0 }
			frame.rowHistory = {}
			frame.rowFramePool = { Release = spy.new(function() end) }
			stub(frame, "StoreRowHistory")
			stub(frame, "UpdateTabVisibility")
			stub(frame, "GetBottom").returns(0)
		end)

		it("clears hasPinnedRow when releasing a pinned row", function()
			mockAnimations.returns({ reposition = { duration = 0 } })
			local row = makePinnedRow("key1", true)
			frame.hasPinnedRow = true
			frame.rows = makeIterableRows({ row })
			frame.keyRowMap = { length = 1, key1 = row }

			frame:ReleaseRow(row)

			assert.is_false(frame.hasPinnedRow)
		end)

		it("does not clear hasPinnedRow when releasing an unpinned row", function()
			mockAnimations.returns({ reposition = { duration = 0 } })
			local row = makePinnedRow("key1", false)
			frame.hasPinnedRow = true
			frame.rows = makeIterableRows({ row })
			frame.keyRowMap = { length = 1, key1 = row }

			frame:ReleaseRow(row)

			assert.is_true(frame.hasPinnedRow)
		end)

		it("clears hasPinnedRow before calling row:Reset()", function()
			mockAnimations.returns({ reposition = { duration = 0 } })
			local row = makePinnedRow("key1", true)
			frame.hasPinnedRow = true
			local hasPinnedAtReset
			row.Reset = function(self)
				hasPinnedAtReset = frame.hasPinnedRow
			end
			frame.rows = makeIterableRows({ row })
			frame.keyRowMap = { length = 1, key1 = row }

			frame:ReleaseRow(row)

			-- hasPinnedRow must already be false when Reset() runs
			assert.is_false(hasPinnedAtReset)
		end)
	end)

	-- ── Load initializes shiftingRowCount ─────────────────────────────────

	describe("Load", function()
		it("initializes shiftingRowCount to 0", function()
			mockGlobalFns.CreateFramePool.returns({})
			local testList = {}
			nsMocks.list.returns(testList)
			stub(frame, "getPositioningDetails")
			stub(frame, "InitQueueLabel")
			stub(frame, "UpdateSize")
			stub(frame, "SetPoint")
			stub(frame, "SetFrameStrata")
			stub(frame, "ConfigureTestArea")
			stub(frame, "CreateTab")
			stub(frame, "UpdateOverlayFrameDepth")
			stub(frame, "CreateScrollWheelTarget")

			frame:Load(ns.Frames.MAIN)

			assert.equal(0, frame.shiftingRowCount)
			assert.is_false(frame.bypassShiftAnimation)
		end)

		it("initializes hasPinnedRow to false", function()
			mockGlobalFns.CreateFramePool.returns({})
			local testList = {}
			nsMocks.list.returns(testList)
			stub(frame, "getPositioningDetails")
			stub(frame, "InitQueueLabel")
			stub(frame, "UpdateSize")
			stub(frame, "SetPoint")
			stub(frame, "SetFrameStrata")
			stub(frame, "ConfigureTestArea")
			stub(frame, "CreateTab")
			stub(frame, "UpdateOverlayFrameDepth")
			stub(frame, "CreateScrollWheelTarget")

			frame:Load(ns.Frames.MAIN)

			assert.is_false(frame.hasPinnedRow)
		end)
	end)

	-- ── ReleasePin ─────────────────────────────────────────────────────────

	describe("ReleasePin", function()
		local function makeIterableRows(rows)
			return {
				iterate = function()
					local i = 0
					return function()
						i = i + 1
						return rows[i]
					end
				end,
			}
		end

		local function makePinnedRow(bottomY)
			return {
				isPinned = true,
				pinnedFrameOffset = 50,
				UpdatePosition = spy.new(function() end),
				AnimateShift = spy.new(function() end),
				ClearAllPoints = spy.new(function() end),
				SetPoint = spy.new(function() end),
				ShiftAnimation = nil,
				_shiftFinalFrameOffset = nil,
				_textHiddenForShift = false,
				PrimaryLineLayout = { SetAlpha = spy.new(function() end) },
				SecondaryLineLayout = { SetAlpha = spy.new(function() end) },
				GetBottom = function()
					return bottomY
				end,
				GetTop = function()
					return bottomY + 22
				end,
			}
		end

		before_each(function()
			frame.vertDir = "BOTTOM"
			frame.frameType = ns.Frames.MAIN
			frame.shiftingRowCount = 0
			frame.hasPinnedRow = true
			stub(frame, "GetBottom").returns(100)
		end)

		it("is a no-op when row is not pinned", function()
			local row = makePinnedRow(200)
			row.isPinned = false
			frame.rows = makeIterableRows({ row })

			frame:ReleasePin(row)

			assert.spy(row.UpdatePosition).was_not.called()
		end)

		it("clears isPinned and hasPinnedRow", function()
			local row = makePinnedRow(200)
			-- Row doesn't move after unpin (same position)
			row.UpdatePosition = function(self, f)
				-- no actual anchor change in test
			end
			frame.rows = makeIterableRows({ row })

			frame:ReleasePin(row)

			assert.is_false(row.isPinned)
			assert.is_nil(row.pinnedFrameOffset)
			assert.is_false(frame.hasPinnedRow)
		end)

		it("calls UpdatePosition on the unpinned row", function()
			local row = makePinnedRow(200)
			frame.rows = makeIterableRows({ row })

			frame:ReleasePin(row)

			assert.spy(row.UpdatePosition).was.called_with(row, frame)
		end)

		it("sends RLF_ROW_RETURNED immediately when no rows shift", function()
			local row = makePinnedRow(200)
			-- Row stays at same position before and after unpin
			frame.rows = makeIterableRows({ row })

			frame:ReleasePin(row)

			assert.spy(nsMocks.SendMessage).was.called_with(ns, "RLF_ROW_RETURNED", ns.Frames.MAIN)
		end)

		it("calls AnimateShift on rows that moved during unpin", function()
			-- Row was pinned at 200; after UpdatePosition it snaps to 150
			local callCount = 0
			local row = makePinnedRow(200)
			row.GetBottom = function()
				callCount = callCount + 1
				if callCount == 1 then
					return 200 -- snapshot
				end
				return 150 -- after UpdatePosition snap
			end
			frame.rows = makeIterableRows({ row })

			frame:ReleasePin(row)

			assert.spy(row.AnimateShift).was.called(1)
			assert.spy(row.AnimateShift).was.called_with(row, 50, 200)
		end)

		it("does NOT send RLF_ROW_RETURNED immediately when at least one row shifts", function()
			local callCount = 0
			local row = makePinnedRow(200)
			row.GetBottom = function()
				callCount = callCount + 1
				return callCount == 1 and 200 or 150
			end
			frame.rows = makeIterableRows({ row })

			frame:ReleasePin(row)

			assert.spy(nsMocks.SendMessage).was_not.called()
		end)

		it("stops in-progress ShiftAnimation and fast-forwards to final offset", function()
			local row = makePinnedRow(200)
			local stopSpy = spy.new(function() end)
			row._shiftFinalFrameOffset = 42
			-- Capture SetPoint args to verify fast-forward
			local capturedSetPointArgs
			row.SetPoint = function(self, ...)
				capturedSetPointArgs = { ... }
			end
			row.ShiftAnimation = {
				IsPlaying = function()
					return true
				end,
				Stop = stopSpy,
			}
			frame.shiftingRowCount = 1
			frame.rows = makeIterableRows({ row })

			frame:ReleasePin(row)

			assert.spy(stopSpy).was.called(1)
			assert.spy(row.ClearAllPoints).was.called(1)
			assert.is_not_nil(capturedSetPointArgs)
			assert.equal(frame.vertDir, capturedSetPointArgs[1])
			assert.equal(frame, capturedSetPointArgs[2])
			assert.equal(frame.vertDir, capturedSetPointArgs[3])
			assert.equal(0, capturedSetPointArgs[4])
			assert.equal(42, capturedSetPointArgs[5])
			assert.spy(row.PrimaryLineLayout.SetAlpha).was.called_with(row.PrimaryLineLayout, 1)
			assert.spy(row.SecondaryLineLayout.SetAlpha).was.called_with(row.SecondaryLineLayout, 1)
		end)
	end)

	-- ── RestoreRowChain pin guard ──────────────────────────────────────────

	describe("RestoreRowChain", function()
		local function makeIterableRows(rows)
			return {
				iterate = function()
					local i = 0
					return function()
						i = i + 1
						return rows[i]
					end
				end,
			}
		end

		it("calls UpdatePosition on non-pinned rows", function()
			local r = { isPinned = false, UpdatePosition = spy.new(function() end) }
			frame.rows = makeIterableRows({ r })

			frame:RestoreRowChain()

			assert.spy(r.UpdatePosition).was.called_with(r, frame)
		end)

		it("skips UpdatePosition on pinned rows", function()
			local r = { isPinned = true, UpdatePosition = spy.new(function() end) }
			frame.rows = makeIterableRows({ r })

			frame:RestoreRowChain()

			assert.spy(r.UpdatePosition).was_not.called()
		end)

		it("skips the pinned row but still repositions its free neighbors", function()
			local pinned = { isPinned = true, UpdatePosition = spy.new(function() end) }
			local free = { isPinned = false, UpdatePosition = spy.new(function() end) }
			frame.rows = makeIterableRows({ pinned, free })

			frame:RestoreRowChain()

			assert.spy(pinned.UpdatePosition).was_not.called()
			assert.spy(free.UpdatePosition).was.called_with(free, frame)
		end)
	end)

	-- ── InitQueueLabel ─────────────────────────────────────────────────────
	-- The "Pending Items" label is styled from the same per-frame font config
	-- as the rows, so it has to read that frame's settings, not frame 1's.

	describe("InitQueueLabel", function()
		local stylingDb

		before_each(function()
			stylingDb = {
				useFontObjects = false,
				font = "GameFontNormalSmall",
				fontFace = "Friz Quadrata TT",
				fontSize = 12,
				fontShadowColor = { 0.1, 0.2, 0.3, 0.4 },
				fontShadowOffsetX = 3,
				fontShadowOffsetY = -4,
			}
			ns.DbAccessor.Styling.returns(stylingDb)
			nsMocks.lsm.Fetch.returns("Fonts\\FRIZQT__.TTF")
			nsMocks.FontFlagsToString.returns("OUTLINE, SLUG")
			-- Frame IDs are plain integers; 2 is the first non-main frame.
			frame.frameType = 2
			frame.vertDir, frame.opposite, frame.horizDir = "TOP", "BOTTOM", "LEFT"
		end)

		it("reads font flags for its own frame, not the main frame", function()
			frame:InitQueueLabel()
			assert.stub(nsMocks.FontFlagsToString).was.called_with(ns, 2)
		end)

		it("applies size, flags and shadow through the shared font helper", function()
			frame:InitQueueLabel()
			assert
				.stub(nsMocks.ApplyFontStyle).was
				.called_with(ns, frame.QueueLabel, "Fonts\\FRIZQT__.TTF", 12, "OUTLINE, SLUG", stylingDb.fontShadowColor, 3, -4)
		end)

		it("uses the font object path without the helper when useFontObjects is set", function()
			stylingDb.useFontObjects = true
			frame:InitQueueLabel()
			assert.stub(frame.QueueLabel.SetFontObject).was.called_with(frame.QueueLabel, "GameFontNormalSmall")
			assert.stub(nsMocks.ApplyFontStyle).was_not.called()
		end)
	end)
end)
