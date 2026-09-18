--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Fusion = require(ReplicatedStorage.Packages.Fusion)

local Button = require(script.Components.Button)

type Scope = Fusion.Scope<typeof(Fusion)>

local UI = {
	Button = Button,
}

local rootScope: Scope? = nil

function UI:Start()
	if rootScope ~= nil then
		return
	end

	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	local scope = Fusion.scoped(Fusion)
	rootScope = scope
	local screenGui = scope:New("ScreenGui")({
		Name = "ButtonDemo",
		DisplayOrder = 1,
		ResetOnSpawn = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		Parent = playerGui,
	})

	Button(scope, {
		Parent = screenGui,
	})
end

return UI
