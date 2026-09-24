--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SnapshotValidation = require(ReplicatedStorage.Shared.Inventory.SnapshotValidation)

export type Result = SnapshotValidation.Result | { Ok: false, Reason: "Loading" | "Unavailable" }
export type ClientData = {
	IsReady: () -> boolean,
	WaitForData: (number?) -> boolean,
	Inventory: {
		Get: () -> unknown,
		Observe: ((unknown) -> ()) -> () -> (),
	},
}

local Snapshot = {}

function Snapshot.read(clientData: ClientData): Result
	local readyOk, ready = pcall(clientData.IsReady)
	if not readyOk then
		return { Ok = false, Reason = "Unavailable" }
	end
	if not ready then
		return { Ok = false, Reason = "Loading" }
	end
	local readOk, value = pcall(clientData.Inventory.Get)
	if not readOk then
		return { Ok = false, Reason = "Unavailable" }
	end
	return SnapshotValidation.validate(value)
end

function Snapshot.subscribe(clientData: ClientData, callback: (Result) -> ()): () -> ()
	local active = true
	local disconnectObserver: (() -> ())? = nil

	local function publish()
		if active then
			callback(Snapshot.read(clientData))
		end
	end

	local function observe()
		if not active then
			return
		end
		local observeOk, disconnect = pcall(function()
			return clientData.Inventory.Observe(function()
				publish()
			end)
		end)
		if observeOk then
			disconnectObserver = disconnect
		else
			callback({ Ok = false, Reason = "Unavailable" })
		end
	end

	local initial = Snapshot.read(clientData)
	if not initial.Ok and initial.Reason == "Loading" then
		callback(initial)
		task.spawn(function()
			while active do
				local waitOk, ready = pcall(clientData.WaitForData, 1)
				if not active then
					return
				end
				if not waitOk then
					callback({ Ok = false, Reason = "Unavailable" })
					return
				end
				if ready then
					observe()
					return
				end
			end
		end)
	else
		observe()
	end

	return function()
		if not active then
			return
		end
		active = false
		if disconnectObserver ~= nil then
			disconnectObserver()
			disconnectObserver = nil
		end
	end
end

return table.freeze(Snapshot)
