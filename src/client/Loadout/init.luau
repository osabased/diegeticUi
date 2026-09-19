--!strict

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Fusion = require(ReplicatedStorage.Packages.Fusion)
local Janitor = require(ReplicatedStorage.Packages.Janitor)
local Network = require(ReplicatedStorage.Shared.Network.Client)

local Domain = require(script.Domain)
local View = require(script.View)

local Loadout = {}
local janitor = Janitor.new()

local function destroy()
	janitor:Cleanup()
end

function Loadout.Start()
	destroy()

	local player = Players.LocalPlayer
	local playerGui = player:WaitForChild("PlayerGui")
	local currentDomain = Domain.new()

	local scope = Fusion.scoped(Fusion)
	local fusionState = scope:Value(currentDomain.get())
	local screenGui = scope:New("ScreenGui")({
		Name = "SessionLoadout",
		DisplayOrder = 30,
		IgnoreGuiInset = true,
		ResetOnSpawn = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		Parent = playerGui,
	})

	local function toggle()
		currentDomain.setOpen(not currentDomain.get().isOpen)
	end

	View.create(scope, screenGui, fusionState, {
		onToggle = toggle,
		onClose = function()
			currentDomain.setOpen(false)
		end,
		onSelect = currentDomain.select,
		onEquip = function()
			local requestId = HttpService:GenerateGUID(false)
			if currentDomain.beginEquip(requestId) then
				Network.exports.LoadoutEquipRequest.Fire(requestId, currentDomain.get().selectedId)
			end
		end,
	})

	janitor:Add(function()
		Fusion.doCleanup(scope)
	end, true, "FusionScope")
	janitor:Add(
		currentDomain.subscribe(function(state)
			fusionState:set(state)
		end),
		true,
		"DomainSubscription"
	)
	janitor:Add(
		Network.exports.LoadoutEquipResult.On(function(requestId, accepted, equippedId, message)
			currentDomain.resolveEquip(requestId, accepted, equippedId, message)
		end),
		true,
		"NetworkListener"
	)
	janitor:Add(
		UserInputService.InputBegan:Connect(function(input, processed)
			if processed then
				return
			end
			if input.KeyCode == Enum.KeyCode.L then
				toggle()
			elseif input.KeyCode == Enum.KeyCode.Escape and currentDomain.get().isOpen then
				currentDomain.setOpen(false)
			end
		end),
		"Disconnect",
		"Keyboard"
	)
	janitor:LinkToInstance(screenGui)
end

function Loadout.Destroy()
	destroy()
end

return Loadout
