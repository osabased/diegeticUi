--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Charm = require(ReplicatedStorage.Packages.Charm)
local Janitor = require(ReplicatedStorage.Packages.Janitor)
local Network = require(ReplicatedStorage.Shared.Network.Server)
local Catalog = require(ReplicatedStorage.Shared.Loadout.Catalog)
local Validator = require(ReplicatedStorage.Shared.Loadout.Validator)

local Loadout = {}
local janitor = Janitor.new()
local getEquipped, setEquipped = Charm.signal({} :: { [Player]: string })
local lastRequestByPlayer: { [Player]: string } = {}

local function equippedFor(player: Player): string
	return getEquipped()[player] or Catalog.defaultId()
end

local function forgetPlayer(player: Player)
	lastRequestByPlayer[player] = nil
	setEquipped(function(current)
		if current[player] == nil then
			return current
		end
		local nextEquipped = table.clone(current)
		nextEquipped[player] = nil
		return nextEquipped
	end)
end

function Loadout.Start()
	janitor:Cleanup()
	table.clear(lastRequestByPlayer)
	setEquipped({})

	janitor:Add(Players.PlayerRemoving:Connect(forgetPlayer), "Disconnect", "PlayerRemoving")
	janitor:Add(
		Network.exports.LoadoutEquipRequest.On(function(player, requestId, itemId)
			local equippedId = equippedFor(player)
			if lastRequestByPlayer[player] == requestId then
				Network.exports.LoadoutEquipResult.Fire(
					player,
					requestId,
					false,
					equippedId,
					"That request was already handled."
				)
				return
			end

			lastRequestByPlayer[player] = requestId
			local accepted, message = Validator.validate(requestId, itemId)
			if accepted then
				setEquipped(function(current)
					local nextEquipped = table.clone(current)
					nextEquipped[player] = itemId
					return nextEquipped
				end)
				equippedId = itemId
			end
			Network.exports.LoadoutEquipResult.Fire(player, requestId, accepted, equippedId, message)
		end),
		true,
		"NetworkListener"
	)
end

function Loadout.Destroy()
	janitor:Cleanup()
	for _, player in Players:GetPlayers() do
		forgetPlayer(player)
	end
end

return Loadout
