--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Fusion = require(ReplicatedStorage.Packages.Fusion)
local UILabs = require(ReplicatedStorage.Packages.UILabs)

local Domain = require(script.Parent.Domain)
local View = require(script.Parent.View)

local StoryFactory = {}

function StoryFactory.create(name: string, summary: string, presets: { Domain.Preset }, selectedId: string?)
	return UILabs.CreateFusionStory({
		name = name,
		summary = summary,
		fusion = Fusion,
	}, function(props)
		local domain = Domain.new(presets, selectedId)
		local state = props.scope:Value(domain.get())
		local function apply(operation: () -> ())
			operation()
			state:set(domain.get())
		end

		return View.create(props.scope, props.target, state, {
			onQueryChanged = function(query)
				apply(function()
					domain.setQuery(query)
				end)
			end,
			onSelect = function(presetId)
				apply(function()
					domain.select(presetId)
				end)
			end,
		})
	end)
end

return StoryFactory
