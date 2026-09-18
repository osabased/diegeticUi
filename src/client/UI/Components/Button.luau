--!strict

local GuiService = game:GetService("GuiService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Fusion = require(ReplicatedStorage.Packages.Fusion)

local Children = Fusion.Children
local OnEvent = Fusion.OnEvent

type Scope = Fusion.Scope<typeof(Fusion)>

export type Props = {
	Parent: Instance?,
	OnActivated: (() -> ())?,
}

local DEFAULT_COLOR = Color3.fromRGB(47, 103, 211)
local HOVER_COLOR = Color3.fromRGB(59, 130, 246)
local PRESSED_COLOR = Color3.fromRGB(29, 78, 216)
local TRANSITION = TweenInfo.new(0.14, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)

local function Button(scope: Scope, props: Props): TextButton
	local isHovered = scope:Value(false)
	local isPressed = scope:Value(false)
	local reducedMotion = scope:Value(GuiService.ReducedMotionEnabled)

	table.insert(
		scope,
		GuiService:GetPropertyChangedSignal("ReducedMotionEnabled"):Connect(function()
			reducedMotion:set(GuiService.ReducedMotionEnabled)
		end)
	)

	local backgroundGoal = scope:Computed(function(use)
		if use(isPressed) then
			return PRESSED_COLOR
		elseif use(isHovered) then
			return HOVER_COLOR
		else
			return DEFAULT_COLOR
		end
	end)
	local scaleGoal = scope:Computed(function(use)
		if use(reducedMotion) then
			return 1
		elseif use(isPressed) then
			return 0.97
		elseif use(isHovered) then
			return 1.02
		else
			return 1
		end
	end)

	local button = scope:New("TextButton")({
		Name = "Button",
		Parent = props.Parent,
		Active = true,
		AnchorPoint = Vector2.new(0.5, 0.5),
		AutoButtonColor = false,
		BackgroundColor3 = scope:Tween(backgroundGoal, TRANSITION),
		BorderSizePixel = 0,
		Font = Enum.Font.GothamBold,
		Position = UDim2.fromScale(0.5, 0.5),
		Selectable = true,
		Size = UDim2.fromOffset(160, 48),
		Text = "Click me",
		TextColor3 = Color3.fromRGB(255, 255, 255),
		TextSize = 16,

		[OnEvent("MouseEnter")] = function()
			isHovered:set(true)
		end,
		[OnEvent("MouseLeave")] = function()
			isHovered:set(false)
			isPressed:set(false)
		end,
		[OnEvent("MouseButton1Down")] = function()
			isPressed:set(true)
		end,
		[OnEvent("MouseButton1Up")] = function()
			isPressed:set(false)
		end,
		[OnEvent("Activated")] = function()
			isPressed:set(false)
			if props.OnActivated ~= nil then
				props.OnActivated()
			end
		end,

		[Children] = {
			scope:New("UICorner")({
				CornerRadius = UDim.new(0, 10),
			}),
			scope:New("UIStroke")({
				ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
				Color = Color3.fromRGB(147, 197, 253),
				Thickness = 1,
				Transparency = 0.55,
			}),
			scope:New("UIScale")({
				Scale = scope:Tween(scaleGoal, TRANSITION),
			}),
		},
	})

	return button :: TextButton
end

return Button
