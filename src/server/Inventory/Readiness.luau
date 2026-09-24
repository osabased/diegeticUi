--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SnapshotValidation = require(ReplicatedStorage.Shared.Inventory.SnapshotValidation)

export type FailureReason = "Loading" | "Unavailable" | "Malformed" | "SpatialInvalid"
export type Result = SnapshotValidation.Success | {
	Ok: false,
	Reason: FailureReason,
}
export type ServerData = {
	WaitForData: (Player, number?) -> ({ Inventory: { Get: () -> unknown } }?, string?),
}
export type CurrentServerData = {
	Get: (Player) -> { Inventory: { Get: () -> unknown, Set: (unknown) -> () } },
}

local Readiness = {}

-- WaitForData never yields a usable accessor on load failure. A timeout while
-- Scribe is still loading remains a separate, retryable state.
function Readiness.read(serverData: ServerData, player: Player, timeout: number?): Result
	local waitOk, data, reason = pcall(serverData.WaitForData, player, timeout)
	if not waitOk then
		return { Ok = false, Reason = "Unavailable" }
	end
	if data == nil then
		return {
			Ok = false,
			Reason = if reason == "still-loading" then "Loading" else "Unavailable",
		}
	end
	local readOk, snapshot = pcall(function()
		return data.Inventory.Get()
	end)
	if not readOk then
		return { Ok = false, Reason = "Unavailable" }
	end
	return SnapshotValidation.validate(snapshot)
end

-- This path cannot yield and is safe to call inside a Scribe transaction.
function Readiness.readCurrent(serverData: CurrentServerData, player: Player): Result
	local readOk, snapshot = pcall(function()
		return serverData.Get(player).Inventory.Get()
	end)
	if not readOk then
		return { Ok = false, Reason = "Unavailable" }
	end
	return SnapshotValidation.validate(snapshot)
end

return table.freeze(Readiness)
