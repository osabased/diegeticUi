--!strict
--# selene: allow(incorrect_standard_library_use)

local Lest = require("@lest")
local describe, it = Lest.describe, Lest.it
local Requests = require("../../src/client/Inventory/WorldContainerRequests")

describe("client world container requests", function()
	it("validates an inspected snapshot and returns detached state", function()
		local wire = {
			{ Id = "bandage-1", DefinitionId = "Bandage", Column = 1, Row = 1, Rotated = false },
		}
		local network: Requests.Network = {
			InspectWorldContainer = {
				Invoke = function(id)
					assert(id == "crate-1", "wrong container")
					return true, 4, wire, nil
				end,
			},
			ClaimWorldContainerItem = {
				Invoke = function()
					return true, 6, 5, nil
				end,
			},
		}
		local inspected = Requests.inspect(network, "crate-1")
		assert(inspected.Ok and inspected.Id == "crate-1" and inspected.Snapshot.Revision == 4, "inspection failed")
		inspected.Snapshot.Items["bandage-1"].Column = 2
		assert(wire[1].Column == 1, "wire state was exposed")
		local claimed = Requests.claim(network, "crate-1", "bandage-1", 5, 4)
		assert(claimed.Ok and claimed.PlayerRevision == 6 and claimed.ContainerRevision == 5, "claim result changed")
	end)

	it("rejects malformed, duplicate, expired, and unavailable responses", function()
		local network: Requests.Network = {
			InspectWorldContainer = {
				Invoke = function()
					return true,
						0,
						{
							{ Id = "same", DefinitionId = "Bandage", Column = 1, Row = 1, Rotated = false },
							{ Id = "same", DefinitionId = "Bandage", Column = 2, Row = 1, Rotated = false },
						},
						nil
				end,
			},
			ClaimWorldContainerItem = {
				Invoke = function()
					return false, nil, nil, "NotEligible"
				end,
			},
		}
		local duplicate = Requests.inspect(network, "crate-1")
		assert(not duplicate.Ok and duplicate.Reason == "Malformed", "duplicate item was admitted")
		local lost = Requests.claim(network, "crate-1", "same", 0, 0)
		assert(not lost.Ok and lost.Reason == "NotEligible", "access rejection was lost")
		network.InspectWorldContainer.Invoke = function()
			return false, nil, nil, "ContainerMissing"
		end
		local expired = Requests.inspect(network, "crate-1")
		assert(not expired.Ok and expired.Reason == "ContainerMissing", "expiration rejection was lost")
		network.InspectWorldContainer.Invoke = function(
			_id: string
		): (boolean, number?, { Requests.WireItem }?, string?)
			error("transport failed")
		end
		local unavailable = Requests.inspect(network, "crate-1")
		assert(not unavailable.Ok and unavailable.Reason == "Unavailable", "transport error was exposed")
	end)
end)

return nil
