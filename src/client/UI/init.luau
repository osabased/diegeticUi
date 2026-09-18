--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Fusion = require(ReplicatedStorage.Packages.Fusion)

local Button = require(script.Components.Button)
local ButtonActionClient = require(script.ButtonActionClient)

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
	local activity = scope:Value("Hold to send a verified server action")
	local latestInteractionSequence = 0

	Button(scope, {
		Parent = screenGui,
		Text = "Deploy",
		IconText = ">",
		ActionId = "demo_deploy",
		HoldDuration = 0.65,
		CooldownDuration = 1,
		RequestAction = ButtonActionClient.request,
		OnInteraction = function(event)
			if event.sequence <= latestInteractionSequence then
				return
			end
			latestInteractionSequence = event.sequence
			if event.kind == "holding" then
				activity:set(string.format("Confirming %d%%", math.round((event.progress or 0) * 100)))
			elseif event.message ~= nil then
				activity:set(event.message)
			else
				activity:set(event.kind)
			end
		end,
	})

	scope:New("TextLabel")({
		Name = "ActivityLabel",
		AnchorPoint = Vector2.new(0.5, 0),
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamMedium,
		Position = UDim2.new(0.5, 0, 0.5, 38),
		Size = UDim2.fromOffset(280, 24),
		Text = activity,
		TextColor3 = Color3.fromRGB(184, 205, 235),
		TextSize = 13,
		Parent = screenGui,
	})
end

return UI
