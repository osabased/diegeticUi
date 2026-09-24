--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PlayerDataModule = ReplicatedStorage.Shared.Inventory.PlayerData
local Readiness = require(script.Readiness)
local Mutation = require(script.Mutation)
local Containers = require(script.Containers)
local WorldContainers = require(script.WorldContainers)
local Protocol = require(script.Protocol)
local Janitor = require(ReplicatedStorage.Packages.Janitor)

local Inventory = {}
local serverData
local worldContainers = WorldContainers.new()
local janitor: Janitor.Janitor? = nil

function Inventory:Init()
	serverData = require(PlayerDataModule).Server
end

function Inventory:Start()
	local network = require(ReplicatedStorage.Shared.Network.Server)
	local owner = Janitor.new()
	owner:LinkToInstance(script)
	owner:Add(Protocol.bind(network.exports, Inventory), true)
	janitor = owner
end

function Inventory:Destroy()
	worldContainers.destroy()
	if janitor ~= nil then
		janitor:Destroy()
		janitor = nil
	end
end

function Inventory.ReadSnapshot(player: Player, timeout: number?): Readiness.Result
	if serverData == nil then
		return { Ok = false, Reason = "Unavailable" } :: Readiness.Result
	end
	return Readiness.read(serverData, player, timeout)
end

function Inventory.Reposition(
	player: Player,
	expectedRevision: unknown,
	itemId: unknown,
	destination: unknown,
	timeout: number?
): Mutation.Result
	if serverData == nil then
		return { Ok = false, Reason = "Unavailable" }
	end
	return Mutation.reposition(serverData, player, expectedRevision, itemId, destination, timeout)
end

function Inventory.Rotate(player: Player, expectedRevision: unknown, itemId: unknown, timeout: number?): Mutation.Result
	if serverData == nil then
		return { Ok = false, Reason = "Unavailable" }
	end
	return Mutation.rotate(serverData, player, expectedRevision, itemId, timeout)
end

-- Binding transfers ownership of the world part to this server feature. Its
-- generated ID is a lookup key, never proof that a player may inspect it.
function Inventory.BindWorldContainer(part: BasePart, seeds: { Containers.Seed }): WorldContainers.SnapshotResult
	return worldContainers.bind(part, seeds)
end

function Inventory.InspectWorldContainer(player: Player, id: unknown): WorldContainers.SnapshotResult
	return worldContainers.inspect(player, id)
end

function Inventory.ExpireWorldContainer(id: unknown): { Ok: boolean, Reason: WorldContainers.FailureReason? }
	return worldContainers.expire(id)
end

function Inventory.TakeFromContainer(
	player: Player,
	containerId: unknown,
	itemId: unknown,
	expectedPlayerRevision: unknown,
	expectedContainerRevision: unknown,
	timeout: number?
): WorldContainers.TransferResult
	if serverData == nil then
		return { Ok = false, Reason = "Unavailable" }
	end
	return worldContainers.claim(
		serverData,
		player,
		containerId,
		itemId,
		expectedPlayerRevision,
		expectedContainerRevision,
		timeout
	)
end

return Inventory
