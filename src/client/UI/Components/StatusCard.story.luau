--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Fusion = require(ReplicatedStorage.Packages.Fusion)
local UILabs = require(ReplicatedStorage.Packages.UILabs)

local StatusCard = require(script.Parent.StatusCard)

return UILabs.CreateFusionStory({
	fusion = Fusion,
	controls = {
		Count = 3,
	},
	summary = "Fusion 0.3 and UI Labs lifecycle smoke test.",
}, function(props)
	local scope = props.scope :: Fusion.Scope<typeof(Fusion)>
	local count = props.controls.Count :: Fusion.Value<number>

	StatusCard(scope, {
		Count = count,
		Parent = props.target,
	})
	-- UI Labs owns props.scope and calls Fusion.doCleanup on unmount/reload.
	return nil
end)
