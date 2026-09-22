--!strict
--# selene: allow(incorrect_standard_library_use)

local Lest = require("@lest")
local describe, it = Lest.describe, Lest.it

local PlayerDataSchema = require("../../src/shared/Inventory/PlayerDataSchema")

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
end)

return nil
