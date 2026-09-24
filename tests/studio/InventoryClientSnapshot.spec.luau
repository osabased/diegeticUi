--!strict
--# selene: allow(incorrect_standard_library_use)

local Lest = require("@lest")
local describe, it = Lest.describe, Lest.it
local Snapshot = require("../../src/client/Inventory/Snapshot")

local function validSnapshot(revision: number)
	return {
		Revision = revision,
		Items = {
			["bandage-1"] = { DefinitionId = "Bandage", Column = 1, Row = 1, Rotated = false },
		},
	}
end

local function fixture(initialReady: boolean, initialValue: unknown)
	local ready = initialReady
	local value = initialValue
	local listeners: { (unknown) -> () } = {}
	local data: Snapshot.ClientData = {
		IsReady = function()
			return ready
		end,
		WaitForData = function(_timeout: number?)
			task.wait(0.01)
			return ready
		end,
		Inventory = {
			Get = function()
				return value
			end,
			Observe = function(callback)
				table.insert(listeners, callback)
				callback(value)
				return function()
					local index = table.find(listeners, callback)
					if index ~= nil then
						table.remove(listeners, index)
					end
				end
			end,
		},
	}
	return data,
		{
			ready = function(nextValue: unknown)
				value = nextValue
				ready = true
			end,
			set = function(nextValue: unknown)
				value = nextValue
				for _, callback in table.clone(listeners) do
					callback(value)
				end
			end,
			listenerCount = function()
				return #listeners
			end,
		}
end

describe("client inventory snapshot", function()
	it("reports loading before Scribe readiness and returns a detached validated copy", function()
		local stored = validSnapshot(4)
		local data, state = fixture(false, stored)
		local before = Snapshot.read(data)
		assert(not before.Ok and before.Reason == "Loading", "template defaults were admitted before replication")

		state.ready(stored)
		local after = Snapshot.read(data)
		assert(after.Ok and after.Snapshot.Revision == 4, "ready revision was not exposed")
		after.Snapshot.Items["bandage-1"].Column = 2
		assert(stored.Items["bandage-1"].Column == 1, "reader changed Scribe's value")
	end)

	it("rejects malformed and spatially invalid data without exposing a snapshot", function()
		local data, state = fixture(true, { Revision = "bad", Items = {} })
		local malformed = Snapshot.read(data)
		assert(not malformed.Ok and malformed.Reason == "Malformed", "malformed snapshot was admitted")
		state.set({
			Revision = 2,
			Items = {
				["rifle-1"] = { DefinitionId = "Rifle", Column = 1, Row = 1, Rotated = false },
				["bandage-1"] = { DefinitionId = "Bandage", Column = 2, Row = 2, Rotated = false },
			},
		})
		local overlapping = Snapshot.read(data)
		assert(not overlapping.Ok and overlapping.Reason == "SpatialInvalid", "overlap was admitted")
		state.set({
			Revision = 3,
			Items = {
				["unknown-1"] = { DefinitionId = "NoLongerCataloged", Column = 1, Row = 1, Rotated = false },
			},
		})
		local unknownDefinition = Snapshot.read(data)
		assert(
			not unknownDefinition.Ok and unknownDefinition.Reason == "SpatialInvalid",
			"uncataloged replicated item was admitted"
		)
	end)

	it("keeps observing after an invalid snapshot so a later valid update can recover", function()
		local data, state = fixture(true, { Revision = "bad", Items = {} })
		local events: { Snapshot.Result } = {}
		local disconnect = Snapshot.subscribe(data, function(result)
			table.insert(events, result)
		end)
		assert(#events == 1, "initial invalid snapshot was not delivered")
		local malformed = events[1]
		assert(not malformed.Ok and malformed.Reason == "Malformed", "invalid initial state was hidden")
		state.set(validSnapshot(3))
		assert(#events == 2, "valid update was not delivered")
		local recovered = events[2]
		assert(recovered.Ok and recovered.Snapshot.Revision == 3, "subscription did not recover")
		disconnect()
	end)

	it("delivers initial and changed snapshots, then disconnects", function()
		local data, state = fixture(false, { Revision = 0, Items = {} })
		local events: { Snapshot.Result } = {}
		local disconnect = Snapshot.subscribe(data, function(result)
			table.insert(events, result)
		end)
		assert(#events == 1, "missing loading event")
		local loading = events[1]
		assert(not loading.Ok and loading.Reason == "Loading", "initial event was not loading")
		assert(state.listenerCount() == 0, "observer attached before initial replication")

		state.ready(validSnapshot(7))
		task.wait(0.05)
		assert(#events == 2, "initial snapshot was not delivered")
		local initial = events[2]
		assert(initial.Ok and initial.Snapshot.Revision == 7, "initial revision changed")
		state.set(validSnapshot(8))
		assert(#events == 3, "whole update was not delivered")
		local updated = events[3]
		assert(updated.Ok and updated.Snapshot.Revision == 8, "updated revision changed")
		disconnect()
		assert(state.listenerCount() == 0, "Scribe observer survived disconnect")
		state.set(validSnapshot(9))
		assert(#events == 3, "callback survived disconnect")
	end)

	it("disconnects a pending readiness subscription", function()
		local data, state = fixture(false, { Revision = 0, Items = {} })
		local calls = 0
		local disconnect = Snapshot.subscribe(data, function()
			calls += 1
		end)
		disconnect()
		state.ready(validSnapshot(1))
		task.wait(0.05)
		assert(calls == 1 and state.listenerCount() == 0, "cancelled subscriber resumed")
	end)
end)

return nil
