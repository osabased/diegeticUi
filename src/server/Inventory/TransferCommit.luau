--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Definitions = require(ReplicatedStorage.Shared.Inventory.Definitions)
local Grid = require(ReplicatedStorage.Shared.Inventory.Grid)
local GridSize = require(ReplicatedStorage.Shared.Inventory.GridSize)
local SnapshotValidation = require(ReplicatedStorage.Shared.Inventory.SnapshotValidation)
local Containers = require(script.Parent.Containers)
local Readiness = require(script.Parent.Readiness)
local Mutation = require(script.Parent.Mutation)

export type FailureReason =
	Readiness.FailureReason
	| Containers.FailureReason
	| Grid.TransferErrorCode
	| "StaleRevision"
	| "InvalidRequest"
	| "TransactionFailed"
	| "CommitUnknown"
	| "NotEligible"
export type Result =
	{ Ok: true, PlayerRevision: number, ContainerRevision: number }
	| { Ok: false, Reason: FailureReason }

type Store = {
	reserve: (string) -> Containers.ReserveResult,
	commit: (Containers.Lease, Grid.InventorySnapshot) -> (),
	release: (Containers.Lease) -> (),
	quarantine: (Containers.Lease) -> (),
}

local TransferCommit = {}

local function validRevision(value: unknown): boolean
	return type(value) == "number" and value >= 0 and value <= Grid.MAX_REVISION and value % 1 == 0
end

local function validId(value: unknown): boolean
	return type(value) == "string" and #value > 0 and #value <= 64
end

local function sameSnapshot(a: Grid.InventorySnapshot, b: Grid.InventorySnapshot): boolean
	if a.Revision ~= b.Revision then
		return false
	end
	for id, placement in a.Items do
		local other = b.Items[id]
		if
			other == nil
			or placement.DefinitionId ~= other.DefinitionId
			or placement.Column ~= other.Column
			or placement.Row ~= other.Row
			or placement.Rotated ~= other.Rotated
		then
			return false
		end
	end
	for id in b.Items do
		if a.Items[id] == nil then
			return false
		end
	end
	return true
end

function TransferCommit.take(
	serverData: Mutation.ServerData,
	containers: Store,
	player: Player,
	containerId: unknown,
	itemId: unknown,
	expectedPlayerRevision: unknown,
	expectedContainerRevision: unknown,
	timeout: number?,
	canAccess: (() -> boolean)?
): Result
	if
		not validId(containerId)
		or not validId(itemId)
		or not validRevision(expectedPlayerRevision)
		or not validRevision(expectedContainerRevision)
	then
		return { Ok = false, Reason = "InvalidRequest" }
	end

	local ready = Readiness.read(serverData, player, timeout)
	if not ready.Ok then
		return { Ok = false, Reason = ready.Reason }
	end
	if canAccess ~= nil and not canAccess() then
		return { Ok = false, Reason = "NotEligible" }
	end

	local reservation = containers.reserve(containerId :: string)
	if not reservation.Ok then
		return { Ok = false, Reason = reservation.Reason }
	end
	local lease = reservation.Lease
	local source = reservation.Snapshot
	local beforePlayer: Grid.InventorySnapshot? = nil
	local afterContainer: Grid.InventorySnapshot? = nil
	local afterPlayer: Grid.InventorySnapshot? = nil
	local wrotePlayer = false
	local outcome: Result = { Ok = false, Reason = "TransactionFailed" }

	local callOk, transactionOk = pcall(function(): boolean
		local succeeded = serverData.Transaction(player, function()
			if canAccess ~= nil and not canAccess() then
				outcome = { Ok = false, Reason = "NotEligible" }
				return
			end
			local current = Readiness.readCurrent(serverData, player)
			if not current.Ok then
				outcome = { Ok = false, Reason = current.Reason }
				return
			end
			beforePlayer = current.Snapshot
			if current.Snapshot.Revision ~= expectedPlayerRevision or source.Revision ~= expectedContainerRevision then
				outcome = { Ok = false, Reason = "StaleRevision" }
				return
			end
			local transfer = Grid.transferFirstFit(
				Definitions,
				{ Id = `container:{containerId}`, GridSize = GridSize, Snapshot = source },
				{ Id = "player", GridSize = GridSize, Snapshot = current.Snapshot },
				itemId :: string
			)
			if not transfer.Ok then
				outcome = { Ok = false, Reason = transfer.Error.Code }
				return
			end
			local validated = SnapshotValidation.validate(transfer.Destination)
			if not validated.Ok then
				outcome = { Ok = false, Reason = validated.Reason }
				return
			end
			afterContainer = transfer.Source
			afterPlayer = validated.Snapshot
			-- Set is the last fallible action in the transaction body. The container
			-- remains reserved until Scribe finishes dispatching commit callbacks.
			wrotePlayer = true
			serverData.Get(player).Inventory.Set(validated.Snapshot)
			outcome = {
				Ok = true,
				PlayerRevision = validated.Snapshot.Revision,
				ContainerRevision = transfer.Source.Revision,
			}
		end)
		return succeeded
	end)

	if callOk and transactionOk then
		if afterContainer ~= nil and outcome.Ok then
			containers.commit(lease, afterContainer)
		else
			containers.release(lease)
		end
		return outcome
	end
	if callOk or not wrotePlayer then
		-- Scribe's false return guarantees rollback. An exception before Set
		-- cannot have changed the player through this claim.
		containers.release(lease)
		return { Ok = false, Reason = "TransactionFailed" }
	end

	-- An exception after Set may happen after Scribe committed. Reconcile before
	-- making the source item available again; uncertain state stays quarantined.
	local current = Readiness.readCurrent(serverData, player)
	if current.Ok and beforePlayer ~= nil and sameSnapshot(current.Snapshot, beforePlayer) then
		containers.release(lease)
		return { Ok = false, Reason = "TransactionFailed" }
	end
	if current.Ok and afterContainer ~= nil and afterPlayer ~= nil then
		local actual = current.Snapshot.Items[itemId :: string]
		local expected = afterPlayer.Items[itemId :: string]
		if actual ~= nil and expected ~= nil and actual.DefinitionId == expected.DefinitionId then
			containers.commit(lease, afterContainer)
			return {
				Ok = true,
				PlayerRevision = current.Snapshot.Revision,
				ContainerRevision = afterContainer.Revision,
			}
		end
	end
	containers.quarantine(lease)
	return { Ok = false, Reason = "CommitUnknown" }
end

return table.freeze(TransferCommit)
