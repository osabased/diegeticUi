--!strict

local RunService = game:GetService("RunService")

local PlayerDataSchema = require(script.Parent.PlayerDataSchema)

local profileStoreIndex = if RunService:IsStudio() then "DiegeticUi_PlayerData_Studio" else "DiegeticUi_PlayerData"

return PlayerDataSchema.createBundle({
	ProfileStoreIndex = profileStoreIndex,
	ProfileKeyPrefix = "Player_",
	Mode = "Live",
})
