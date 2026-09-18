--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Janitor = require(ReplicatedStorage.Packages.Janitor)
local Network = require(ReplicatedStorage.Shared.Network.Server)

type ActionConfig = {
	message: string,
	cooldownSeconds: number,
}

local ACTIONS: { [string]: ActionConfig } = {
	demo_deploy = {
		message = "Deployed",
		cooldownSeconds = 2,
	},
	demo_connect = {
		message = "Connected",
		cooldownSeconds = 1,
	},
}

local ButtonActions = {}
local janitor = Janitor.new()
local lastAcceptedAt: { [Player]: { [string]: number } } = {}
local initialized = false

local function requestAction(player: Player, actionId: string): (boolean, string, number)
	local config = ACTIONS[actionId]
	if config == nil then
		return false, "Action unavailable", 0
	end

	local now = os.clock()
	local playerActions = lastAcceptedAt[player]
	if playerActions == nil then
		playerActions = {}
		lastAcceptedAt[player] = playerActions
	end

	local lastAccepted = playerActions[actionId]
	if lastAccepted ~= nil then
		local remaining = config.cooldownSeconds - (now - lastAccepted)
		if remaining > 0 then
			return false, string.format("Ready in %.1fs", remaining), remaining
		end
	end

	playerActions[actionId] = now
	return true, config.message, config.cooldownSeconds
end

function ButtonActions:Init()
	if initialized then
		return
	end
	initialized = true

	janitor:Add(
		Players.PlayerRemoving:Connect(function(player)
			lastAcceptedAt[player] = nil
		end),
		"Disconnect",
		"PlayerRemoving"
	)
	janitor:Add(Network.exports.RequestButtonAction.On(requestAction), true, "RequestButtonAction")
end

return ButtonActions
