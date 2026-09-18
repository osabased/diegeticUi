--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Fusion = require(ReplicatedStorage.Packages.Fusion)
local UILabs = require(ReplicatedStorage.Packages.UILabs)

local Button = require(script.Parent.Button)

return UILabs.CreateFusionStory({
	fusion = Fusion,
	summary = "Luminous action buttons with hold confirmation, results, cooldowns, and semantic states.",
}, function(props)
	local scope = props.scope :: Fusion.Scope<typeof(Fusion)>
	local showcase = scope:New("Frame")({
		Name = "ButtonShowcase",
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(176, 362),
		Parent = props.target,
	})

	local function slot(y: number): Frame
		return scope:New("Frame")({
			AnchorPoint = Vector2.new(0.5, 0),
			BackgroundTransparency = 1,
			Position = UDim2.new(0.5, 0, 0, y),
			Size = UDim2.fromOffset(176, 52),
			Parent = showcase,
		}) :: Frame
	end

	Button(scope, {
		Parent = slot(0),
		Text = "Server action",
		IconText = ">",
		Variant = "primary",
		ActionId = "story_deploy",
		CooldownDuration = 2,
		RequestAction = function()
			task.wait(0.35)
			return {
				accepted = true,
				message = "Confirmed",
				cooldownSeconds = 2,
			}
		end,
	})
	Button(scope, {
		Parent = slot(62),
		Text = "Connected",
		IconText = "+",
		Variant = "success",
	})
	Button(scope, {
		Parent = slot(124),
		Text = "Hold to delete",
		IconText = "!",
		Variant = "danger",
		HoldDuration = 0.8,
	})
	Button(scope, {
		Parent = slot(186),
		Text = "Publish",
		Loading = true,
	})
	Button(scope, {
		Parent = slot(248),
		Text = "Cooldown",
		IconText = "3",
		CooldownDuration = 3,
	})
	Button(scope, {
		Parent = slot(310),
		Text = "Locked",
		IconText = "x",
		Disabled = true,
	})
	-- UI Labs owns props.scope and calls Fusion.doCleanup on unmount/reload.
	return nil
end)
