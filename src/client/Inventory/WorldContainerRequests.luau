--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Grid = require(ReplicatedStorage.Shared.Inventory.Grid)
local SnapshotValidation = require(ReplicatedStorage.Shared.Inventory.SnapshotValidation)

export type WireItem = {
	Id: string,
	DefinitionId: string,
	Column: number,
	Row: number,
	Rotated: boolean,
}
export type Network = {
	InspectWorldContainer: {
		Invoke: (string) -> (boolean, number?, { WireItem }?, string?),
	},
	ClaimWorldContainerItem: {
		Invoke: (string, string, number, number) -> (boolean, number?, number?, string?),
	},
}
export type InspectResult = { Ok: true, Id: string, Snapshot: Grid.InventorySnapshot } | { Ok: false, Reason: string }
export type ClaimResult =
	{ Ok: true, PlayerRevision: number, ContainerRevision: number }
	| { Ok: false, Reason: string }

local Requests = {}

local function validRevision(value: unknown): boolean
	return type(value) == "number" and value >= 0 and value <= Grid.MAX_REVISION and value % 1 == 0
end

function Requests.inspect(network: Network, id: string): InspectResult
	local callOk, response = pcall(function()
		local accepted, revision, items, reason = network.InspectWorldContainer.Invoke(id)
		return { Accepted = accepted, Revision = revision, Items = items, Reason = reason }
	end)
	if not callOk then
		return { Ok = false, Reason = "Unavailable" }
	end
	if not response.Accepted then
		return { Ok = false, Reason = response.Reason or "Unavailable" }
	end
	if response.Revision == nil or response.Items == nil then
		return { Ok = false, Reason = "Malformed" }
	end
	local items: { [string]: Grid.PlacedItem } = {}
	for _, item in response.Items do
		if type(item) ~= "table" or type(item.Id) ~= "string" or items[item.Id] ~= nil then
			return { Ok = false, Reason = "Malformed" }
		end
		items[item.Id] = {
			DefinitionId = item.DefinitionId,
			Column = item.Column,
			Row = item.Row,
			Rotated = item.Rotated,
		}
	end
	local validated = SnapshotValidation.validate({ Revision = response.Revision, Items = items })
	if not validated.Ok then
		return { Ok = false, Reason = validated.Reason :: string }
	end
	return { Ok = true, Id = id, Snapshot = validated.Snapshot }
end

function Requests.claim(
	network: Network,
	id: string,
	itemId: string,
	playerRevision: number,
	containerRevision: number
): ClaimResult
	local callOk, response = pcall(function()
		local accepted, nextPlayerRevision, nextContainerRevision, reason =
			network.ClaimWorldContainerItem.Invoke(id, itemId, playerRevision, containerRevision)
		return {
			Accepted = accepted,
			PlayerRevision = nextPlayerRevision,
			ContainerRevision = nextContainerRevision,
			Reason = reason,
		}
	end)
	if not callOk then
		return { Ok = false, Reason = "Unavailable" }
	end
	if not response.Accepted then
		return { Ok = false, Reason = response.Reason or "Unavailable" }
	end
	if
		not validRevision(response.PlayerRevision)
		or not validRevision(response.ContainerRevision)
		or response.PlayerRevision <= playerRevision
		or response.ContainerRevision <= containerRevision
	then
		return { Ok = false, Reason = "Malformed" }
	end
	return {
		Ok = true,
		PlayerRevision = response.PlayerRevision :: number,
		ContainerRevision = response.ContainerRevision :: number,
	}
end

return table.freeze(Requests)
