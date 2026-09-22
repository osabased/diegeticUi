--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PlayerDataModule = ReplicatedStorage.Shared.Inventory.PlayerData

local Inventory = {}

function Inventory:Init()
	local _serverData = require(PlayerDataModule).Server
end

return Inventory
