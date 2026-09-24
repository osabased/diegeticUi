--!strict
--# selene: allow(incorrect_standard_library_use)

local Lest = require("@lest")
local describe, it = Lest.describe, Lest.it
local Containers = require("../../src/server/Inventory/Containers")
local TransferCommit = require("../../src/server/Inventory/TransferCommit")

local player = (game:GetService("Players") :: unknown) :: Player

local function emptySnapshot()
	return { Revision = 0, Items = {} }
end

local function makeContainer()
	local store = Containers.new()
	local created = store.create("loot", {
		{ DefinitionId = "Bandage", Placement = { Column = 1, Row = 1, Rotated = false } },
		{ DefinitionId = "Bandage", Placement = { Column = 2, Row = 1, Rotated = false } },
	})
	assert(created.Ok, "container seed failed")
	local ids = {}
	for id in created.Snapshot.Items do
		table.insert(ids, id)
	end
	table.sort(ids)
	return store, ids
end

local function fixture(initial: unknown)
	local current: any = initial
	local failSet = false
	local unavailable = false
	local postCommit: (() -> ())? = nil
	local writes = 0
	local data: any = {
		WaitForData = function()
			return { Inventory = {
				Get = function()
					return current
				end,
			} }, nil
		end,
		Get = function()
			if unavailable then
				error("session unavailable")
			end
			return {
				Inventory = {
					Get = function()
						return current
					end,
					Set = function(value)
						writes += 1
						current = value
						if failSet then
							error("injected Set failure")
						end
					end,
				},
			}
		end,
		Transaction = function(_player, callback): (boolean, string?)
			local previous = current
			local ok, reason = pcall(callback)
			if not ok then
				current = previous
				return false, tostring(reason)
			end
			if postCommit then
				postCommit()
			end
			return true, nil
		end,
	}
	return data,
		{
			get = function()
				return current
			end,
			writes = function()
				return writes
			end,
			failSet = function()
				failSet = true
			end,
			postCommit = function(callback)
				postCommit = callback
			end,
			unavailable = function()
				unavailable = true
			end,
		}
end

describe("session loot transfer", function()
	it("creates isolated session items and commits one claim", function()
		local store, ids = makeContainer()
		local data, state = fixture(emptySnapshot())
		local created = store.read("loot")
		assert(created.Ok and created.Snapshot.Revision == 0, "initial revision changed")
		created.Snapshot.Items[ids[1]].Column = 4
		local again = store.read("loot")
		assert(again.Ok and again.Snapshot.Items[ids[1]].Column ~= 4, "read leaked the stored snapshot")

		local result = TransferCommit.take(data, store, player, "loot", ids[1], 0, 0, 0)
		assert(result.Ok and result.PlayerRevision == 1 and result.ContainerRevision == 1, "claim did not commit")
		local remaining = store.read("loot")
		assert(remaining.Ok and remaining.Snapshot.Items[ids[1]] == nil, "source item remained claimable")
		assert(state.get().Items[ids[1]] ~= nil and state.writes() == 1, "player did not receive exactly one write")
		assert(state.get().Items[ids[2]] == nil, "unclaimed item appeared in player inventory")
		local second = TransferCommit.take(data, store, player, "loot", ids[2], 1, 1, 0)
		assert(
			second.Ok and second.PlayerRevision == 2 and second.ContainerRevision == 2,
			"second claim did not commit"
		)
		assert(ids[1] ~= ids[2], "container reused an item instance ID")
		assert(
			state.get().Items[ids[1]].DefinitionId == "Bandage"
				and state.get().Items[ids[2]].DefinitionId == "Bandage"
				and state.writes() == 2,
			"same-definition instances were not both retained"
		)
		local emptied = store.read("loot")
		assert(emptied.Ok and next(emptied.Snapshot.Items) == nil, "claimed instances remained in the container")
	end)

	it("rejects either stale revision and a full destination", function()
		local store, ids = makeContainer()
		local data, state = fixture(emptySnapshot())
		local first = TransferCommit.take(data, store, player, "loot", ids[1], 0, 0, 0)
		assert(first.Ok, "first claim failed")
		local stalePlayer = TransferCommit.take(data, store, player, "loot", ids[2], 0, 1, 0)
		local staleContainer = TransferCommit.take(data, store, player, "loot", ids[2], 1, 0, 0)
		assert(not stalePlayer.Ok and stalePlayer.Reason == "StaleRevision", "stale player revision accepted")
		assert(not staleContainer.Ok and staleContainer.Reason == "StaleRevision", "stale container revision accepted")
		assert(state.writes() == 1, "stale request wrote player state")

		local full = { Revision = 0, Items = {} }
		for column = 1, 4 do
			for row = 1, 3, 2 do
				full.Items[`full-{column}-{row}`] = {
					DefinitionId = "Bandage",
					Column = column,
					Row = row,
					Rotated = false,
				}
			end
		end
		local fullData, fullState = fixture(full)
		local noFit = TransferCommit.take(fullData, store, player, "loot", ids[2], 0, 1, 0)
		assert(not noFit.Ok and noFit.Reason == "NoFit", "full destination accepted item")
		assert(fullState.writes() == 0, "no-fit claim wrote player state")
	end)

	it("retains source when the player transaction rolls back", function()
		local store, ids = makeContainer()
		local data, state = fixture(emptySnapshot())
		state.failSet()
		local result = TransferCommit.take(data, store, player, "loot", ids[1], 0, 0, 0)
		assert(not result.Ok and result.Reason == "TransactionFailed", "rolled-back claim appeared accepted")
		assert(state.get().Revision == 0 and state.get().Items[ids[1]] == nil, "player rollback failed")
		local source = store.read("loot")
		assert(source.Ok and source.Snapshot.Revision == 0 and source.Snapshot.Items[ids[1]], "source was lost")
	end)

	it("blocks observer reentry and expiration until finalization", function()
		local store, ids = makeContainer()
		local data, state = fixture(emptySnapshot())
		local reentered: any = nil
		local expired: any = nil
		state.postCommit(function()
			reentered = TransferCommit.take(data, store, player, "loot", ids[2], 1, 0, 0)
			expired = store.expire("loot")
		end)
		local result = TransferCommit.take(data, store, player, "loot", ids[1], 0, 0, 0)
		assert(result.Ok, "outer claim failed")
		assert(not reentered.Ok and reentered.Reason == "Busy", "reentry passed reservation")
		assert(not expired.Ok and expired.Reason == "Busy", "container expired while reserved")
		local retry = TransferCommit.take(data, store, player, "loot", ids[2], 0, 0, 0)
		assert(not retry.Ok and retry.Reason == "StaleRevision", "competing stale claim was accepted")
		assert(state.get().Revision == 1 and state.get().Items[ids[2]] == nil, "reentry changed player state")
	end)

	it("quarantines an uncertain post-write failure", function()
		local store, ids = makeContainer()
		local data, state = fixture(emptySnapshot())
		state.postCommit(function()
			state.unavailable()
			error("injected post-commit failure")
		end)
		local result = TransferCommit.take(data, store, player, "loot", ids[1], 0, 0, 0)
		assert(not result.Ok and result.Reason == "CommitUnknown", "uncertain commit was released")
		local read = store.read("loot")
		local expired = store.expire("loot")
		assert(not read.Ok and read.Reason == "CommitUnknown", "quarantined item became readable")
		assert(not expired.Ok and expired.Reason == "CommitUnknown", "quarantined container expired")
	end)

	it("finalizes a proved player commit after a post-write exception", function()
		local store, ids = makeContainer()
		local data, state = fixture(emptySnapshot())
		state.postCommit(function()
			error("injected post-commit failure")
		end)
		local result = TransferCommit.take(data, store, player, "loot", ids[1], 0, 0, 0)
		assert(result.Ok and result.PlayerRevision == 1, "proved commit was reported as failed")
		local source = store.read("loot")
		assert(source.Ok and source.Snapshot.Items[ids[1]] == nil, "proved commit retained source item")
		assert(state.get().Items[ids[1]] ~= nil, "proved commit lost player item")
	end)

	it("rejects revision overflow without changing either owner", function()
		local store, ids = makeContainer()
		local snapshot = { Revision = 9007199254740990, Items = {} }
		local data, state = fixture(snapshot)
		local result = TransferCommit.take(data, store, player, "loot", ids[1], snapshot.Revision, 0, 0)
		assert(not result.Ok and result.Reason == "RevisionOverflow", "overflowing claim was accepted")
		assert(state.writes() == 0, "overflowing claim wrote player state")
		local source = store.read("loot")
		assert(source.Ok and source.Snapshot.Revision == 0 and source.Snapshot.Items[ids[1]], "source changed")
	end)

	it("rejects invalid seed placement and expires an unlocked container", function()
		local store = Containers.new()
		local invalid = store.create("bad", {
			{ DefinitionId = "Bandage", Placement = { Column = 4, Row = 4, Rotated = false } },
		})
		assert(not invalid.Ok and invalid.Reason == "OutOfBounds", "invalid seed was admitted")
		local created = store.create("ok", {})
		assert(created.Ok, "empty container creation failed")
		local reserved = store.reserve("ok")
		assert(reserved.Ok, "container reservation failed")
		local blocked = store.expire("ok")
		assert(not blocked.Ok and blocked.Reason == "Busy", "reserved container expired")
		store.release(reserved.Lease)
		assert(store.expire("ok").Ok, "unlocked container did not expire")
		local missing = store.read("ok")
		assert(not missing.Ok and missing.Reason == "ContainerMissing", "expired container remained")
	end)
end)

return nil
