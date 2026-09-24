--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Definitions = require(ReplicatedStorage.Shared.Inventory.Definitions)
local Grid = require(ReplicatedStorage.Shared.Inventory.Grid)
local GridSize = require(ReplicatedStorage.Shared.Inventory.GridSize)
local SnapshotValidation = require(ReplicatedStorage.Shared.Inventory.SnapshotValidation)
local Readiness = require(script.Parent.Readiness)

export type FailureReason =
	Readiness.FailureReason
	| Grid.GridErrorCode
	| "StaleRevision"
	| "InvalidRequest"
	| "TransactionFailed"
export type Result = { Ok: true, Snapshot: Grid.InventorySnapshot } | { Ok: false, Reason: FailureReason }
export type ServerData = Readiness.ServerData & Readiness.CurrentServerData & {
	Transaction: (Player, () -> ()) -> (boolean, string?),
}

local Mutation = {}

local function validRevision(value: unknown): boolean
	return type(value) == "number" and value >= 0 and value <= Grid.MAX_REVISION and value % 1 == 0
end

local function validItemId(value: unknown): boolean
	return type(value) == "string" and #value > 0 and #value <= 64
end

local function validDestination(value: unknown): boolean
	if type(value) ~= "table" then
		return false
	end
	local destination = value :: { [string]: unknown }
	return type(destination.Column) == "number"
		and type(destination.Row) == "number"
		and type(destination.Rotated) == "boolean"
end

local function change(
	serverData: ServerData,
	player: Player,
	expectedRevision: number,
	itemId: string,
	destination: Grid.ItemPlacement?,
	timeout: number?
): Result
	local ready = Readiness.read(serverData, player, timeout)
	if not ready.Ok then
		return { Ok = false, Reason = ready.Reason }
	end

	local outcome: Result = { Ok = false, Reason = "TransactionFailed" }
	local callOk, committed = pcall(function(): boolean
		local transactionOk = serverData.Transaction(player, function()
			local current = Readiness.readCurrent(serverData, player)
			if not current.Ok then
				outcome = { Ok = false, Reason = current.Reason }
				return
			end
			if current.Snapshot.Revision ~= expectedRevision then
				outcome = { Ok = false, Reason = "StaleRevision" }
				return
			end

			local nextSnapshot = if destination == nil
				then Grid.rotate(GridSize, Definitions, current.Snapshot, itemId)
				else Grid.reposition(GridSize, Definitions, current.Snapshot, itemId, destination)
			if not nextSnapshot.Ok then
				outcome = { Ok = false, Reason = nextSnapshot.Error.Code }
				return
			end
			local validatedNext = SnapshotValidation.validate(nextSnapshot.Snapshot)
			if not validatedNext.Ok then
				outcome = { Ok = false, Reason = validatedNext.Reason }
				return
			end

			serverData.Get(player).Inventory.Set(validatedNext.Snapshot)
			outcome = { Ok = true, Snapshot = nextSnapshot.Snapshot }
		end)
		return transactionOk
	end)
	if not callOk or not committed then
		local current = Readiness.readCurrent(serverData, player)
		if not current.Ok then
			return { Ok = false, Reason = current.Reason }
		end
		return { Ok = false, Reason = "TransactionFailed" }
	end
	return outcome
end

function Mutation.reposition(
	serverData: ServerData,
	player: Player,
	expectedRevision: unknown,
	itemId: unknown,
	destination: unknown,
	timeout: number?
): Result
	if not validRevision(expectedRevision) or not validItemId(itemId) or not validDestination(destination) then
		return { Ok = false, Reason = "InvalidRequest" }
	end
	return change(
		serverData,
		player,
		expectedRevision :: number,
		itemId :: string,
		destination :: Grid.ItemPlacement,
		timeout
	)
end

function Mutation.rotate(
	serverData: ServerData,
	player: Player,
	expectedRevision: unknown,
	itemId: unknown,
	timeout: number?
): Result
	if not validRevision(expectedRevision) or not validItemId(itemId) then
		return { Ok = false, Reason = "InvalidRequest" }
	end
	return change(serverData, player, expectedRevision :: number, itemId :: string, nil, timeout)
end

return table.freeze(Mutation)
