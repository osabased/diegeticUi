--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Fusion = require(ReplicatedStorage.Packages.Fusion)
local UILabs = require(ReplicatedStorage.Packages.UILabs)

local Button = require(script.Parent.Button)

return UILabs.CreateFusionStory({
	fusion = Fusion,
	summary = "A minimal button with default, hover, and pressed states.",
}, function(props)
	local scope = props.scope :: Fusion.Scope<typeof(Fusion)>

	Button(scope, {
		Parent = props.target,
	})
	-- UI Labs owns props.scope and calls Fusion.doCleanup on unmount/reload.
	return nil
end)
