--!strict
--# selene: allow(incorrect_standard_library_use)

local Lest = require("@lest")
local describe, it = Lest.describe, Lest.it
local Protocol = require("../../src/server/Inventory/Protocol")

type RepositionCallback = (Player, number, string, number, number, boolean) -> (boolean, number?, string?)
type RotateCallback = (Player, number, string) -> (boolean, number?, string?)
type InspectCallback = (Player, string) -> (boolean, number?, { Protocol.WireItem }?, string?)
type ClaimCallback = (Player, string, string, number, number) -> (boolean, number?, number?, string?)

local player = (game:GetService("Players") :: unknown) :: Player

describe("inventory protocol binding", function()
	it("forwards the sender and returns committed revision or rejection reason", function()
		local repositionCallback: RepositionCallback? = nil
		local rotateCallback: RotateCallback? = nil
		local inspectCallback: InspectCallback? = nil
		local claimCallback: ClaimCallback? = nil
		local seenPlayer: Player? = nil
		local network: Protocol.NetworkExports = {
			RepositionInventory = {
				On = function(callback)
					repositionCallback = callback
					return function()
						repositionCallback = nil
					end
				end,
			},
			RotateInventory = {
				On = function(callback)
					rotateCallback = callback
					return function()
						rotateCallback = nil
					end
				end,
			},
			InspectWorldContainer = {
				On = function(callback)
					inspectCallback = callback
					return function()
						inspectCallback = nil
					end
				end,
			},
			ClaimWorldContainerItem = {
				On = function(callback)
					claimCallback = callback
					return function()
						claimCallback = nil
					end
				end,
			},
		}
		local inventory: Protocol.InventoryApi = {
			Reposition = function(sender, expectedRevision, itemId, destination, timeout)
				seenPlayer = sender
				assert(expectedRevision == 7 and itemId == "rifle-1" and timeout == 0, "request fields changed")
				local placement = destination :: { Column: number, Row: number, Rotated: boolean }
				assert(placement.Column == 1 and placement.Row == 2 and not placement.Rotated, "destination changed")
				return { Ok = true, Snapshot = { Revision = 8, Items = {} } }
			end,
			Rotate = function(sender, expectedRevision, itemId, timeout)
				seenPlayer = sender
				assert(expectedRevision == 7 and itemId == "rifle-1" and timeout == 0, "rotation fields changed")
				return { Ok = false, Reason = "StaleRevision" }
			end,
			InspectWorldContainer = function(sender, id)
				seenPlayer = sender
				assert(id == "crate-1", "inspect id changed")
				return {
					Ok = true,
					Id = id :: string,
					Snapshot = {
						Revision = 3,
						Items = {
							z = { DefinitionId = "Bandage", Column = 2, Row = 1, Rotated = false },
							a = { DefinitionId = "Bandage", Column = 1, Row = 1, Rotated = false },
						},
					},
				}
			end,
			TakeFromContainer = function(sender, id, itemId, playerRevision, containerRevision, timeout)
				seenPlayer = sender
				assert(id == "crate-1" and (itemId == "a" or itemId == "z"), "claim identity changed")
				assert(playerRevision == 5 and containerRevision == 3 and timeout == 0, "claim revisions changed")
				if itemId == "z" then
					return { Ok = true, PlayerRevision = 6, ContainerRevision = 4 }
				end
				return { Ok = false, Reason = "NotEligible" }
			end,
		}

		local disconnect = Protocol.bind(network, inventory)
		assert(
			repositionCallback ~= nil and rotateCallback ~= nil and inspectCallback ~= nil and claimCallback ~= nil,
			"requests were not bound"
		)
		local accepted, revision, reason = repositionCallback(player, 7, "rifle-1", 1, 2, false)
		assert(
			accepted and revision == 8 and reason == nil and seenPlayer == player,
			"commit response lost sender or revision"
		)
		local rotated, rejectedRevision, rejection = rotateCallback(player, 7, "rifle-1")
		assert(not rotated and rejectedRevision == nil and rejection == "StaleRevision", "rejection became success")
		local inspected, containerRevision, items, inspectReason = inspectCallback(player, "crate-1")
		assert(
			inspected and containerRevision == 3 and inspectReason == nil and seenPlayer == player,
			"inspect response changed"
		)
		assert(items ~= nil and #items == 2 and items[1].Id == "a" and items[2].Id == "z", "items were not ordered")
		local claimed, playerRevision, claimRevision, claimReason = claimCallback(player, "crate-1", "a", 5, 3)
		assert(
			not claimed
				and playerRevision == nil
				and claimRevision == nil
				and claimReason == "NotEligible"
				and seenPlayer == player,
			"claim rejection changed"
		)
		local acceptedClaim, nextPlayer, nextContainer, successReason = claimCallback(player, "crate-1", "z", 5, 3)
		assert(
			acceptedClaim and nextPlayer == 6 and nextContainer == 4 and successReason == nil and seenPlayer == player,
			"claim success lost either revision"
		)
		disconnect()
		assert(
			repositionCallback == nil and rotateCallback == nil and inspectCallback == nil and claimCallback == nil,
			"bindings survived cleanup"
		)
	end)
end)

return nil
