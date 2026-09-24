--!strict
--# selene: allow(incorrect_standard_library_use)

local Lest = require("@lest")
local describe, it = Lest.describe, Lest.it

local PlayerDataSchema = require("../../src/shared/Inventory/PlayerDataSchema")
local Readiness = require("../../src/server/Inventory/Readiness")

local function loaded(snapshot)
	return {
		WaitForData = function()
			return {
				Inventory = {
					Get = function()
						return snapshot
					end,
				},
			}
		end,
	}
end

describe("inventory player-data schema", function()
	it("constructs the version-one schema in an isolated mock bundle", function()
		local bundle = PlayerDataSchema.createBundle({
			ProfileStoreIndex = "DiegeticUi_InventorySchemaTest",
			ProfileKeyPrefix = "TestPlayer_",
			Mode = "Mock",
			IsRunning = false,
			Banner = false,
		})

		local template = (bundle :: any).__ScribeTemplate
		assert(type(template) == "table", "Scribe did not expose the compiled Studio template")
		assert(type(template.Inventory) == "table", "inventory root is missing")
		assert(template.Inventory.Revision ~= nil, "inventory revision is missing")
		assert(type(template.Inventory.Items) == "table", "inventory item dictionary is missing")

		bundle.Client.Stop()
	end)

	it("admits fresh and valid restored snapshots without changing loaded data", function()
		local player = (game:GetService("Players") :: unknown) :: Player
		local fresh = { Revision = 0, Items = {} }
		local freshResult = Readiness.read(loaded(fresh), player, 0)
		assert(freshResult.Ok, "fresh inventory should become ready")
		assert(freshResult.Snapshot.Revision == 0, "fresh revision changed")
		assert(next(freshResult.Snapshot.Items) == nil, "fresh inventory gained an item")

		local restored = {
			Revision = 7,
			Items = {
				["rifle-1"] = { DefinitionId = "Rifle", Column = 2, Row = 1, Rotated = false },
				["bandage-1"] = { DefinitionId = "Bandage", Column = 1, Row = 3, Rotated = false },
			},
		}
		local restoredResult = Readiness.read(loaded(restored), player, 0)
		assert(restoredResult.Ok, "valid restored inventory should become ready")
		assert(restoredResult.Snapshot.Revision == 7, "restored revision changed")
		assert(restoredResult.Snapshot.Items["rifle-1"].Column == 2, "restored item moved")
		restoredResult.Snapshot.Items["rifle-1"].Column = 4
		assert(restored.Items["rifle-1"].Column == 2, "caller received the live Scribe value")
	end)

	it("keeps loading and unavailable data closed", function()
		local player = (game:GetService("Players") :: unknown) :: Player
		local loading = Readiness.read({
			WaitForData = function()
				return nil, "still-loading"
			end,
		}, player, 0)
		assert(not loading.Ok and loading.Reason == "Loading", "loading must not return a snapshot")
		local unavailable = Readiness.read({
			WaitForData = function()
				return nil, "load-failed"
			end,
		}, player, 0)
		assert(not unavailable.Ok and unavailable.Reason == "Unavailable", "failed load must not return a snapshot")
		local ended = Readiness.read({
			WaitForData = function()
				error("session ended")
			end,
		}, player, 0)
		assert(not ended.Ok and ended.Reason == "Unavailable", "thrown load must not return a snapshot")
	end)

	it("rejects malformed and overlapping loaded snapshots", function()
		local player = (game:GetService("Players") :: unknown) :: Player
		local malformed = Readiness.read(loaded({ Revision = "bad", Items = {} }), player, 0)
		assert(not malformed.Ok and malformed.Reason == "Malformed", "wrong revision type was admitted")
		local malformedItem = Readiness.read(
			loaded({
				Revision = 2,
				Items = { ["rifle-1"] = { DefinitionId = "Rifle", Column = "1", Row = 1, Rotated = false } },
			}),
			player,
			0
		)
		assert(not malformedItem.Ok and malformedItem.Reason == "Malformed", "wrong coordinate type was admitted")
		local overlapping = Readiness.read(
			loaded({
				Revision = 2,
				Items = {
					["rifle-1"] = { DefinitionId = "Rifle", Column = 1, Row = 1, Rotated = false },
					["bandage-1"] = { DefinitionId = "Bandage", Column = 2, Row = 2, Rotated = false },
				},
			}),
			player,
			0
		)
		assert(not overlapping.Ok and overlapping.Reason == "SpatialInvalid", "overlap was admitted")
		local unknownDefinition = Readiness.read(
			loaded({
				Revision = 2,
				Items = {
					["unknown-1"] = { DefinitionId = "NoLongerCataloged", Column = 1, Row = 1, Rotated = false },
				},
			}),
			player,
			0
		)
		assert(
			not unknownDefinition.Ok and unknownDefinition.Reason == "SpatialInvalid",
			"uncataloged stored item was admitted"
		)
	end)
end)

return nil
