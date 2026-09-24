--!strict
--# selene: allow(incorrect_standard_library_use)

local Lest = require("@lest")
local describe, it = Lest.describe, Lest.it

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local PlayerDataSchema = require("../../src/shared/Inventory/PlayerDataSchema")
local Mutation = require("../../src/server/Inventory/Mutation")
local Readiness = require("../../src/server/Inventory/Readiness")
local DiagnosticCapture = require("./DiagnosticCapture")

local scribeModule = ReplicatedStorage.Packages._Index["ericplane_scribe@2.3.0"].scribe
local Template = require(scribeModule.Internal.Template)
local Server = require(scribeModule.Server)

local function sameSnapshot(expected: any, actual: any)
	assert(actual.Revision == expected.Revision, "reopened revision differs from the accepted revision")
	local count = 0
	for itemId, item in expected.Items do
		count += 1
		local restored = actual.Items[itemId]
		assert(restored ~= nil, `reopened inventory lost item {itemId}`)
		assert(restored.DefinitionId == item.DefinitionId, `reopened definition differs for {itemId}`)
		assert(restored.Column == item.Column and restored.Row == item.Row, `reopened placement differs for {itemId}`)
		assert(restored.Rotated == item.Rotated, `reopened rotation differs for {itemId}`)
	end
	local restoredCount = 0
	for _ in actual.Items do
		restoredCount += 1
	end
	assert(restoredCount == count, "reopened inventory gained an item")
end

describe("inventory mock persistence", function()
	it("reloads an accepted production mutation after ending the session", function()
		local data: any = nil
		local context: any = nil
		local fakePlayer: any = nil
		local player: Player? = nil
		local expectedOutput = { "[ProfileStore]: Roblox API services unavailable - data will not be saved" }
		local result = DiagnosticCapture.run(function()
			-- Scribe's edit-mode bundle exposes the exact source template, but builds
			-- only a client half. Its pinned server test seam drives a player lifecycle
			-- without a running Studio server or live DataStore.
			local schemaBundle = PlayerDataSchema.createBundle({
				ProfileStoreIndex = "DiegeticUi_InventoryRoundTripTest",
				ProfileKeyPrefix = "TestPlayer_",
				Mode = "Mock",
				IsRunning = false,
				Banner = false,
			})
			local compiled = Template.Compile((schemaBundle :: any).__ScribeTemplate)
			schemaBundle.Client.Stop()

			local transport = {
				Name = "InventoryRoundTripTest",
				SendToClient = function() end,
				SendToAllClients = function() end,
				ListenServer = function() end,
			}
			data, context = Server.build({
				ProfileStoreIndex = "DiegeticUi_InventoryRoundTripTest",
				ProfileKeyPrefix = "TestPlayer_",
				Mode = "Mock",
				Transport = transport,
				LogLevel = "Error",
				Banner = false,
			}, compiled)
			fakePlayer = {
				Name = "InventoryRoundTripTest",
				UserId = 987654321,
				Parent = Players,
			}
			local currentPlayer = (fakePlayer :: any) :: Player
			player = currentPlayer
			context.Persistence.OnPlayerAdded(currentPlayer)
			local ready, reason = data.WaitForData(currentPlayer, 4)
			assert(ready ~= nil, `first mock session failed: {tostring(reason)}`)
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
			assert(data.Flush(currentPlayer, { Timeout = 4 }), "mock store did not confirm the accepted snapshot save")

			fakePlayer.Parent = nil
			context.Persistence.OnPlayerRemoving(currentPlayer)
			fakePlayer.Parent = Players
			context.Persistence.OnPlayerAdded(currentPlayer)
			local reopened, reopenReason = data.WaitForData(currentPlayer, 4)
			assert(reopened ~= nil, `reopened mock session failed: {tostring(reopenReason)}`)
			local restored = Readiness.read(data, currentPlayer, 0)
			assert(restored.Ok, "reopened snapshot failed production validation")
			sameSnapshot(accepted.Snapshot, restored.Snapshot)
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
