--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PlayerDataModule = ReplicatedStorage.Shared.Inventory.PlayerData
local Snapshot = require(script.Snapshot)
local WorldContainerRequests = require(script.WorldContainerRequests)

export type RequestResult = { Ok: true, Revision: number } | { Ok: false, Reason: string }
export type SnapshotResult = Snapshot.Result
export type WorldInspectResult = WorldContainerRequests.InspectResult
export type WorldClaimResult = WorldContainerRequests.ClaimResult

local Inventory = {}
local network: typeof(require(ReplicatedStorage.Shared.Network.Client))? = nil
local clientData: Snapshot.ClientData? = nil

function Inventory:Init()
	clientData = (require(PlayerDataModule).Client :: unknown) :: Snapshot.ClientData
end

function Inventory:Start()
	network = require(ReplicatedStorage.Shared.Network.Client)
end

function Inventory:Destroy()
	network = nil
	clientData = nil
end

function Inventory.ReadSnapshot(): SnapshotResult
	local currentData = clientData
	if currentData == nil then
		return { Ok = false, Reason = "Unavailable" } :: SnapshotResult
	end
	return Snapshot.read(currentData)
end

function Inventory.Subscribe(callback: (SnapshotResult) -> ()): () -> ()
	local currentData = clientData
	if currentData == nil then
		callback({ Ok = false, Reason = "Unavailable" } :: SnapshotResult)
		return function() end
	end
	return Snapshot.subscribe(currentData, callback)
end

local function request(call: () -> (boolean, number?, string?)): RequestResult
	local callOk, response = pcall(function()
		local accepted, revision, reason = call()
		return { Accepted = accepted, Revision = revision, Reason = reason }
	end)
	if not callOk then
		return { Ok = false, Reason = "Unavailable" }
	end
	if response.Accepted and response.Revision ~= nil then
		return { Ok = true, Revision = response.Revision }
	end
	return { Ok = false, Reason = response.Reason or "Unavailable" }
end

function Inventory.RequestReposition(
	expectedRevision: number,
	itemId: string,
	column: number,
	row: number,
	rotated: boolean
): RequestResult
	local currentNetwork = network
	if currentNetwork == nil then
		return { Ok = false, Reason = "Unavailable" }
	end
	return request(function()
		return currentNetwork.exports.RepositionInventory.Invoke(expectedRevision, itemId, column, row, rotated)
	end)
end

function Inventory.RequestRotate(expectedRevision: number, itemId: string): RequestResult
	local currentNetwork = network
	if currentNetwork == nil then
		return { Ok = false, Reason = "Unavailable" }
	end
	return request(function()
		return currentNetwork.exports.RotateInventory.Invoke(expectedRevision, itemId)
	end)
end

function Inventory.InspectWorldContainer(id: string): WorldInspectResult
	local currentNetwork = network
	if currentNetwork == nil then
		return { Ok = false, Reason = "Unavailable" }
	end
	return WorldContainerRequests.inspect(currentNetwork.exports, id)
end

function Inventory.ClaimWorldContainerItem(
	id: string,
	itemId: string,
	playerRevision: number,
	containerRevision: number
): WorldClaimResult
	local currentNetwork = network
	if currentNetwork == nil then
		return { Ok = false, Reason = "Unavailable" }
	end
	return WorldContainerRequests.claim(currentNetwork.exports, id, itemId, playerRevision, containerRevision)
end

return Inventory
