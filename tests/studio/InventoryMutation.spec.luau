--!strict
--# selene: allow(incorrect_standard_library_use)

local Lest = require("@lest")
local describe, it = Lest.describe, Lest.it
local Mutation = require("../../src/server/Inventory/Mutation")

local player = (game:GetService("Players") :: unknown) :: Player

local function snapshot()
	return {
		Revision = 7,
		Items = {
			["rifle-1"] = { DefinitionId = "Rifle", Column = 1, Row = 1, Rotated = false },
			["bandage-1"] = { DefinitionId = "Bandage", Column = 4, Row = 1, Rotated = false },
		},
	}
end

local function fixture(initial: unknown)
	local current: any = initial
	local writes = 0
	local beforeTransaction: (() -> ())? = nil
	local failSet = false
	local ended = false
	local data: Mutation.ServerData = {
		WaitForData = function(_player: Player, _timeout: number?): ({ Inventory: { Get: () -> unknown } }?, string?)
			if ended then
				return nil, "load-failed"
			end
			return {
				Inventory = {
					Get = function()
						return current
					end,
				},
			}, nil
		end,
		Get = function(_player: Player)
			if ended then
				error("session ended")
			end
			return {
				Inventory = {
					Get = function()
						return current
					end,
					Set = function(value: unknown)
						writes += 1
						current = value
						if failSet then
							error("injected write failure")
						end
					end,
				},
			}
		end,
		Transaction = function(_player: Player, callback: () -> ()): (boolean, string?)
			if beforeTransaction then
				beforeTransaction()
			end
			if ended then
				error("session ended")
			end
			local previous = current
			local ok, reason = pcall(function(): string
				callback()
				return ""
			end)
			if not ok then
				current = previous
				return false, tostring(reason)
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
			beforeTransaction = function(callback)
				beforeTransaction = callback
			end,
			failSet = function()
				failSet = true
			end,
			endSession = function()
				ended = true
			end,
		}
end

describe("inventory mutation", function()
	it("commits reposition and rotation as whole snapshots", function()
		local data, state = fixture(snapshot())
		local moved = Mutation.reposition(data, player, 7, "rifle-1", { Column = 1, Row = 2, Rotated = false }, 0)
		assert(moved.Ok and moved.Snapshot.Revision == 8, "reposition did not commit revision 8")
		assert(state.get().Items["rifle-1"].Row == 2, "reposition was not stored")
		local rotated = Mutation.rotate(data, player, 8, "rifle-1", 0)
		assert(rotated.Ok and rotated.Snapshot.Revision == 9, "rotation did not commit revision 9")
		assert(state.get().Items["rifle-1"].Rotated, "rotation was not stored")
		rotated.Snapshot.Items["rifle-1"].Rotated = false
		assert(state.get().Items["rifle-1"].Rotated, "result exposed the stored snapshot")
		assert(state.writes() == 2, "each accepted operation must use one whole-snapshot write")
	end)

	it("rejects a revision changed after readiness", function()
		local data, state = fixture(snapshot())
		state.beforeTransaction(function()
			state.get().Revision = 8
		end)
		local result = Mutation.rotate(data, player, 7, "rifle-1", 0)
		assert(not result.Ok and result.Reason == "StaleRevision", "stale request was accepted")
		assert(state.get().Revision == 8 and state.writes() == 0, "stale request changed accepted state")
	end)

	it("rejects invalid placement without writing", function()
		local data, state = fixture(snapshot())
		local result = Mutation.reposition(data, player, 7, "rifle-1", { Column = 4, Row = 4, Rotated = false }, 0)
		assert(not result.Ok and result.Reason == "OutOfBounds", "invalid placement was accepted")
		assert(state.get().Revision == 7 and state.writes() == 0, "invalid placement changed state")
	end)

	it("rejects invalid loaded data at commit", function()
		local data, state = fixture(snapshot())
		state.beforeTransaction(function()
			state.get().Revision = "bad"
		end)
		local result = Mutation.rotate(data, player, 7, "rifle-1", 0)
		assert(not result.Ok and result.Reason == "Malformed", "malformed current data was accepted")
		assert(state.writes() == 0, "malformed data was overwritten")
	end)

	it("does not commit a revision beyond the validated snapshot limit", function()
		local initial = snapshot()
		initial.Revision = 9007199254740990
		local data, state = fixture(initial)
		local result = Mutation.rotate(data, player, initial.Revision, "rifle-1", 0)
		assert(not result.Ok and result.Reason == "RevisionOverflow", "overflowing revision was accepted")
		assert(state.get().Revision == initial.Revision and state.writes() == 0, "overflow changed accepted state")
	end)

	it("reports an ended session and a rolled-back transaction without success", function()
		local endedData, endedState = fixture(snapshot())
		endedState.beforeTransaction(endedState.endSession)
		local ended = Mutation.rotate(endedData, player, 7, "rifle-1", 0)
		assert(not ended.Ok and ended.Reason == "Unavailable", "ended session was reported as committed")
		assert(endedState.writes() == 0, "ended session wrote data")

		local data, state = fixture(snapshot())
		state.failSet()
		local rolledBack = Mutation.rotate(data, player, 7, "rifle-1", 0)
		assert(not rolledBack.Ok and rolledBack.Reason == "TransactionFailed", "rollback was reported as committed")
		assert(state.get().Revision == 7 and not state.get().Items["rifle-1"].Rotated, "rollback lost accepted state")
	end)
end)

return nil
