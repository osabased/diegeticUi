--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Fusion = require(ReplicatedStorage.Packages.Fusion)
local UILabs = require(ReplicatedStorage.Packages.UILabs)

local View = require(script.Parent.View)

local StoryFactory = {}

function StoryFactory.create(name: string, summary: string, initialState: unknown)
	return UILabs.CreateFusionStory({
		name = name,
		summary = summary,
		fusion = Fusion,
	}, function(props)
		local state = props.scope:Value(initialState)
		return View.create(props.scope, props.target, state, {
			onToggle = function() end,
			onClose = function() end,
			onSelect = function() end,
			onEquip = function() end,
		})
	end)
end

return StoryFactory
