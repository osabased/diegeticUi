--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PlayerDataModule = ReplicatedStorage.Shared.Inventory.PlayerData

local Inventory = {}

function Inventory:Init()
	local _clientData = require(PlayerDataModule).Client
end

return Inventory
