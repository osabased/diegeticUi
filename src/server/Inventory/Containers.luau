--!strict

local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Definitions = require(ReplicatedStorage.Shared.Inventory.Definitions)
local Grid = require(ReplicatedStorage.Shared.Inventory.Grid)
local GridSize = require(ReplicatedStorage.Shared.Inventory.GridSize)
local SnapshotValidation = require(ReplicatedStorage.Shared.Inventory.SnapshotValidation)

export type Seed = { DefinitionId: Grid.ItemDefinitionId, Placement: Grid.ItemPlacement }
export type FailureReason =
	"InvalidRequest"
	| "ContainerExists"
	| "ContainerMissing"
	| "Busy"
	| "CommitUnknown"
	| Grid.GridErrorCode
export type SnapshotResult = { Ok: true, Snapshot: Grid.InventorySnapshot } | { Ok: false, Reason: FailureReason }
export type Lease = { Id: string, Entry: Entry }
export type ReserveResult =
	{ Ok: true, Lease: Lease, Snapshot: Grid.InventorySnapshot }
	| { Ok: false, Reason: FailureReason }

type Entry = {
	Snapshot: Grid.InventorySnapshot,
	Busy: boolean,
	Quarantined: boolean,
}

local Containers = {}

function Containers.new()
	local entries: { [string]: Entry } = {}
	local issuedIds: { [string]: boolean } = {}
	local store = {}

	function store.create(id: string, seeds: { Seed }): SnapshotResult
		if type(id) ~= "string" or #id == 0 or #id > 64 or type(seeds) ~= "table" then
			return { Ok = false, Reason = "InvalidRequest" }
		end
		if entries[id] ~= nil then
			return { Ok = false, Reason = "ContainerExists" }
		end
		local snapshot: Grid.InventorySnapshot = { Revision = 0, Items = {} }
		local generated: { [string]: boolean } = {}
		for _, seed in seeds do
			local itemId = HttpService:GenerateGUID(false)
			while issuedIds[itemId] or generated[itemId] do
				itemId = HttpService:GenerateGUID(false)
			end
			generated[itemId] = true
			local placed = Grid.place(GridSize, Definitions, snapshot, {
				Id = itemId,
				DefinitionId = seed.DefinitionId,
			}, seed.Placement)
			if not placed.Ok then
				return { Ok = false, Reason = placed.Error.Code }
			end
			snapshot = placed.Snapshot
		end
		-- Seeding creates the initial state; it is not a series of player-visible commits.
		snapshot.Revision = 0
		local validated = SnapshotValidation.validate(snapshot)
		if not validated.Ok then
			return { Ok = false, Reason = "InvalidRequest" }
		end
		for itemId in generated do
			issuedIds[itemId] = true
		end
		entries[id] = { Snapshot = snapshot, Busy = false, Quarantined = false }
		return { Ok = true, Snapshot = validated.Snapshot }
	end

	function store.read(id: string): SnapshotResult
		local entry = entries[id]
		if entry == nil then
			return { Ok = false, Reason = "ContainerMissing" }
		end
		if entry.Quarantined then
			return { Ok = false, Reason = "CommitUnknown" }
		end
		if entry.Busy then
			return { Ok = false, Reason = "Busy" }
		end
		local validated = SnapshotValidation.validate(entry.Snapshot)
		if not validated.Ok then
			return { Ok = false, Reason = "InvalidRequest" }
		end
		return { Ok = true, Snapshot = validated.Snapshot }
	end

	function store.reserve(id: string): ReserveResult
		local result = store.read(id)
		if not result.Ok then
			return result
		end
		local entry = entries[id] :: Entry
		entry.Busy = true
		return { Ok = true, Lease = { Id = id, Entry = entry }, Snapshot = result.Snapshot }
	end

	function store.commit(lease: Lease, snapshot: Grid.InventorySnapshot)
		local entry = lease.Entry
		assert(entries[lease.Id] == entry and entry.Busy and not entry.Quarantined, "invalid container lease")
		entry.Snapshot = snapshot
		entry.Busy = false
	end

	function store.release(lease: Lease)
		local entry = lease.Entry
		assert(entries[lease.Id] == entry and entry.Busy and not entry.Quarantined, "invalid container lease")
		entry.Busy = false
	end

	function store.quarantine(lease: Lease)
		local entry = lease.Entry
		assert(entries[lease.Id] == entry and entry.Busy, "invalid container lease")
		entry.Quarantined = true
		entry.Busy = false
	end

	function store.expire(id: string): { Ok: boolean, Reason: FailureReason? }
		local entry = entries[id]
		if entry == nil then
			return { Ok = false, Reason = "ContainerMissing" }
		end
		if entry.Quarantined then
			return { Ok = false, Reason = "CommitUnknown" }
		end
		if entry.Busy then
			return { Ok = false, Reason = "Busy" }
		end
		entries[id] = nil
		return { Ok = true, Reason = nil }
	end

	-- A removed world instance has no recovery path. Its quarantined inventory
	-- may be discarded only after all claims have released their leases.
	function store.discard(id: string): { Ok: boolean, Reason: FailureReason? }
		local entry = entries[id]
		if entry == nil then
			return { Ok = false, Reason = "ContainerMissing" }
		end
		if entry.Busy then
			return { Ok = false, Reason = "Busy" }
		end
		entries[id] = nil
		return { Ok = true, Reason = nil }
	end

	return store
end

return table.freeze(Containers)
