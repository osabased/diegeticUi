--!strict

local Mutation = require(script.Parent.Mutation)
local WorldContainers = require(script.Parent.WorldContainers)
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Grid = require(ReplicatedStorage.Shared.Inventory.Grid)

export type WireItem = {
	Id: string,
	DefinitionId: string,
	Column: number,
	Row: number,
	Rotated: boolean,
}

export type InventoryApi = {
	Reposition: (Player, unknown, unknown, unknown, number?) -> Mutation.Result,
	Rotate: (Player, unknown, unknown, number?) -> Mutation.Result,
	InspectWorldContainer: (Player, unknown) -> WorldContainers.SnapshotResult,
	TakeFromContainer: (Player, unknown, unknown, unknown, unknown, number?) -> WorldContainers.TransferResult,
}
export type NetworkExports = {
	RepositionInventory: {
		On: ((Player, number, string, number, number, boolean) -> (boolean, number?, string?)) -> () -> (),
	},
	RotateInventory: {
		On: ((Player, number, string) -> (boolean, number?, string?)) -> () -> (),
	},
	InspectWorldContainer: {
		On: ((Player, string) -> (boolean, number?, { WireItem }?, string?)) -> () -> (),
	},
	ClaimWorldContainerItem: {
		On: ((Player, string, string, number, number) -> (boolean, number?, number?, string?)) -> () -> (),
	},
}

local Protocol = {}

local function toWire(result: Mutation.Result): (boolean, number?, string?)
	if result.Ok then
		return true, result.Snapshot.Revision, nil
	end
	return false, nil, result.Reason
end

local function snapshotToWire(snapshot: Grid.InventorySnapshot): { WireItem }
	local ids = {}
	for id in snapshot.Items do
		table.insert(ids, id)
	end
	table.sort(ids)
	local items: { WireItem } = {}
	for _, id in ids do
		local placement = snapshot.Items[id]
		table.insert(items, {
			Id = id,
			DefinitionId = placement.DefinitionId,
			Column = placement.Column,
			Row = placement.Row,
			Rotated = placement.Rotated,
		})
	end
	return items
end

function Protocol.bind(network: NetworkExports, inventory: InventoryApi): () -> ()
	local disconnectReposition = network.RepositionInventory.On(
		function(player, expectedRevision, itemId, column, row, rotated)
			return toWire(inventory.Reposition(player, expectedRevision, itemId, {
				Column = column,
				Row = row,
				Rotated = rotated,
			}, 0))
		end
	)
	local disconnectRotate = network.RotateInventory.On(function(player, expectedRevision, itemId)
		return toWire(inventory.Rotate(player, expectedRevision, itemId, 0))
	end)
	local disconnectInspect = network.InspectWorldContainer.On(function(player, containerId)
		local result = inventory.InspectWorldContainer(player, containerId)
		if not result.Ok then
			return false, nil, nil, result.Reason
		end
		return true, result.Snapshot.Revision, snapshotToWire(result.Snapshot), nil
	end)
	local disconnectClaim = network.ClaimWorldContainerItem.On(
		function(player, containerId, itemId, playerRevision, containerRevision)
			local result =
				inventory.TakeFromContainer(player, containerId, itemId, playerRevision, containerRevision, 0)
			if not result.Ok then
				return false, nil, nil, result.Reason
			end
			return true, result.PlayerRevision, result.ContainerRevision, nil
		end
	)

	return function()
		disconnectReposition()
		disconnectRotate()
		disconnectInspect()
		disconnectClaim()
	end
end

return table.freeze(Protocol)
