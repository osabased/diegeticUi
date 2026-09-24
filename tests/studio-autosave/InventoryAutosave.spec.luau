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

local STORE_NAME = "DiegeticUi_InventoryAutosaveTest"
local KEY_PREFIX = "TestPlayer_"
local USER_ID = 987654323

local function assertSameSnapshot(expected: any, actual: any)
	assert(actual ~= nil, "saved profile has no inventory")
	assert(actual.Revision == expected.Revision, "autosaved revision differs from accepted revision")
	local count = 0
	for itemId, item in expected.Items do
		count += 1
		local saved = actual.Items[itemId]
		assert(saved ~= nil, `autosave lost item {itemId}`)
		assert(saved.DefinitionId == item.DefinitionId, `autosave changed definition for {itemId}`)
		assert(saved.Column == item.Column and saved.Row == item.Row, `autosave changed placement for {itemId}`)
		assert(saved.Rotated == item.Rotated, `autosave changed rotation for {itemId}`)
	end
	local savedCount = 0
	for _ in actual.Items do
		savedCount += 1
	end
	assert(savedCount == count, "autosave changed item count")
end

describe("inventory mock autosave", function()
	it("saves an accepted mutation while the player session remains active", function()
		local data: any = nil
		local context: any = nil
		local fakePlayer: any = nil
		local player: Player? = nil
		local expectedOutput = { "[ProfileStore]: Roblox API services unavailable - data will not be saved" }
		local result = DiagnosticCapture.run(function()
			local ProfileStore = require(scribeModule.Internal.Store)
			-- SaveInterval changes ProfileStore's process-global cadence. This test
			-- runs in a separate Studio process from the ordinary and shutdown suites.
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
				Name = "InventoryAutosaveTest",
				SendToClient = function() end,
				SendToAllClients = function() end,
				ListenServer = function() end,
			}
			data, context = Server.build({
				ProfileStoreIndex = STORE_NAME,
				ProfileKeyPrefix = KEY_PREFIX,
				Mode = "Mock",
				SaveInterval = 15,
				Transport = transport,
				LogLevel = "Error",
				Banner = false,
			}, compiled)
			fakePlayer = {
				Name = "InventoryAutosaveTest",
				UserId = USER_ID,
				Parent = Players,
			}
			local currentPlayer = (fakePlayer :: any) :: Player
			player = currentPlayer
			context.Persistence.OnPlayerAdded(currentPlayer)
			local ready, reason = data.WaitForData(currentPlayer, 4)
			assert(ready ~= nil, `mock session failed: {tostring(reason)}`)
			ready.Inventory.Set({
				Revision = 7,
				Items = {
					["rifle-1"] = { DefinitionId = "Rifle", Column = 1, Row = 1, Rotated = false },
					["bandage-1"] = { DefinitionId = "Bandage", Column = 4, Row = 1, Rotated = false },
				},
			})
			local accepted = Mutation.rotate(data, currentPlayer, 7, "rifle-1", 0)
			assert(accepted.Ok, "production mutation did not accept the rotation")
			assert(accepted.Snapshot.Revision == 8, "accepted mutation did not advance the revision")
			assert(accepted.Snapshot.Items["rifle-1"].Rotated, "accepted mutation did not rotate the rifle")

			local mockStore = ProfileStore.Test().UserMockStore[STORE_NAME]
			local loadedRecord = mockStore and mockStore[KEY_PREFIX .. USER_ID]
			assert(loadedRecord ~= nil, "session load did not create a mock store record")
			local loadVersion = loadedRecord.VersionId
			local saved: any = nil
			local deadline = os.clock() + 32
			while os.clock() < deadline do
				assert(data.GetState(currentPlayer) == "Ready", "session ended before autosave")
				mockStore = ProfileStore.Test().UserMockStore[STORE_NAME]
				saved = mockStore and mockStore[KEY_PREFIX .. USER_ID]
				if saved ~= nil and saved.VersionId > loadVersion then
					break
				end
				task.wait(0.1)
			end
			assert(
				saved ~= nil and saved.VersionId > loadVersion,
				"autosave did not write the mock store within 32 seconds"
			)
			assert(data.GetState(currentPlayer) == "Ready", "session ended before autosave completed")
			assert(fakePlayer.Parent == Players, "player was removed before autosave completed")
			assertSameSnapshot(accepted.Snapshot, saved.Data and saved.Data.Data and saved.Data.Data.Inventory)
		end, function()
			if fakePlayer ~= nil and context ~= nil and player ~= nil then
				fakePlayer.Parent = nil
				context.Persistence.OnPlayerRemoving(player)
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
