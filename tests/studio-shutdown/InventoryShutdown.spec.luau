--!strict
--# selene: allow(incorrect_standard_library_use)

local Lest = require("@lest")
local describe, it = Lest.describe, Lest.it

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local PlayerDataSchema = require("../../src/shared/Inventory/PlayerDataSchema")
local Mutation = require("../../src/server/Inventory/Mutation")
local DiagnosticCapture = require("../studio/DiagnosticCapture")

local scribeModule = ReplicatedStorage.Packages._Index["ericplane_scribe@2.3.0"].scribe
local Template = require(scribeModule.Internal.Template)
local Server = require(scribeModule.Server)

local STORE_NAME = "DiegeticUi_InventoryShutdownTest"
local KEY_PREFIX = "TestPlayer_"
local USER_ID = 987654322

describe("inventory mock shutdown", function()
	it("saves an accepted mutation before the shutdown drain returns", function()
		local data: any = nil
		local context: any = nil
		local fakePlayer: any = nil
		local expectedOutput = { "[ProfileStore]: Roblox API services unavailable - data will not be saved" }
		local result = DiagnosticCapture.run(function()
			local ProfileStore = require(scribeModule.Internal.Store)
			-- Shutdown closes ProfileStore for this process. Keep this test in its
			-- own Studio suite, separate from ordinary persistence tests.
			local schemaBundle = PlayerDataSchema.createBundle({
				ProfileStoreIndex = STORE_NAME,
				ProfileKeyPrefix = KEY_PREFIX,
				Mode = "Mock",
				IsRunning = false,
				Banner = false,
			})
			local compiled = Template.Compile((schemaBundle :: any).__ScribeTemplate)
			schemaBundle.Client.Stop()

			local transport = {
				Name = "InventoryShutdownTest",
				SendToClient = function() end,
				SendToAllClients = function() end,
				ListenServer = function() end,
			}
			data, context = Server.build({
				ProfileStoreIndex = STORE_NAME,
				ProfileKeyPrefix = KEY_PREFIX,
				Mode = "Mock",
				Transport = transport,
				LogLevel = "Error",
				Banner = false,
			}, compiled)
			fakePlayer = {
				Name = "InventoryShutdownTest",
				UserId = USER_ID,
				Parent = Players,
			}
			local player = (fakePlayer :: any) :: Player
			context.Persistence.OnPlayerAdded(player)
			local ready, reason = data.WaitForData(player, 4)
			assert(ready ~= nil, `mock session failed: {tostring(reason)}`)
			ready.Inventory.Set({
				Revision = 7,
				Items = {
					["rifle-1"] = { DefinitionId = "Rifle", Column = 1, Row = 1, Rotated = false },
					["bandage-1"] = { DefinitionId = "Bandage", Column = 4, Row = 1, Rotated = false },
				},
			})
			local accepted = Mutation.rotate(data, player, 7, "rifle-1", 0)
			assert(accepted.Ok, "production mutation did not accept the rotation")
			assert(accepted.Snapshot.Revision == 8, "accepted mutation did not advance the revision")
			assert(accepted.Snapshot.Items["rifle-1"].Rotated, "accepted mutation did not rotate the rifle")

			context.Persistence.Shutdown(4)
			assert(data.GetState(player) == "SessionEnded", "shutdown did not end the player session")
			local mockStore = ProfileStore.Test().UserMockStore[STORE_NAME]
			local saved = mockStore and mockStore[KEY_PREFIX .. USER_ID]
			assert(saved ~= nil, "shutdown returned before the mock save landed")
			local actual = saved.Data and saved.Data.Data and saved.Data.Data.Inventory
			assert(actual ~= nil, "saved profile has no inventory")
			assert(actual.Revision == accepted.Snapshot.Revision, "saved revision differs from accepted revision")
			local count = 0
			for itemId, item in accepted.Snapshot.Items do
				count += 1
				local restored = actual.Items[itemId]
				assert(restored ~= nil, `shutdown save lost item {itemId}`)
				assert(restored.DefinitionId == item.DefinitionId, `shutdown save changed definition for {itemId}`)
				assert(
					restored.Column == item.Column and restored.Row == item.Row,
					`shutdown save changed placement for {itemId}`
				)
				assert(restored.Rotated == item.Rotated, `shutdown save changed rotation for {itemId}`)
			end
			local savedCount = 0
			for _ in actual.Items do
				savedCount += 1
			end
			assert(savedCount == count, "shutdown save changed item count")
		end, function()
			if fakePlayer ~= nil then
				fakePlayer.Parent = nil
			end
			if data ~= nil then
				data.Stop()
			end
			require(scribeModule.Internal.Log).SetLevel("Info")
		end, nil, expectedOutput)
		local problems = {}
		if result.bodyError ~= nil then
			table.insert(problems, result.bodyError)
		end
		if result.cleanupError ~= nil then
			table.insert(problems, result.cleanupError)
		end
		for _, problem in DiagnosticCapture.unexpected(result.diagnostics, nil) do
			table.insert(problems, problem)
		end
		assert(#problems == 0, table.concat(problems, "\n\n"))
	end)
end)

return nil
