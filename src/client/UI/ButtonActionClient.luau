--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Network = require(ReplicatedStorage.Shared.Network.Client)

export type ActionResult = {
	accepted: boolean,
	message: string,
	cooldownSeconds: number,
}

local ButtonActionClient = {}

function ButtonActionClient.request(actionId: string): ActionResult
	local accepted, message, cooldownSeconds = Network.exports.RequestButtonAction.Invoke(actionId)
	return {
		accepted = accepted,
		message = message,
		cooldownSeconds = cooldownSeconds,
	}
end

return ButtonActionClient
