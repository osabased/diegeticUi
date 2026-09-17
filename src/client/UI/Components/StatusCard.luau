--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Fusion = require(ReplicatedStorage.Packages.Fusion)

local Children = Fusion.Children
local OnEvent = Fusion.OnEvent

type Scope = Fusion.Scope<typeof(Fusion)>

export type Props = {
	Count: Fusion.UsedAs<number>,
	Parent: Instance?,
}

local function StatusCard(scope: Scope, props: Props): Frame
	local isHovered = scope:Value(false)
	local transparencyGoal = scope:Computed(function(use)
		return if use(isHovered) then 0.04 else 0.14
	end)
	local backgroundTransparency = scope:Spring(transparencyGoal, 24, 1)

	local card = scope:New("Frame")({
		Name = "StatusCard",
		Parent = props.Parent,
		BackgroundColor3 = Color3.fromRGB(22, 28, 38),
		BackgroundTransparency = backgroundTransparency,
		BorderSizePixel = 0,
		Size = UDim2.fromOffset(240, 112),

		[OnEvent("MouseEnter")] = function()
			isHovered:set(true)
		end,
		[OnEvent("MouseLeave")] = function()
			isHovered:set(false)
		end,

		[Children] = {
			scope:New("UICorner")({
				CornerRadius = UDim.new(0, 12),
			}),
			scope:New("UIStroke")({
				Color = Color3.fromRGB(77, 219, 153),
				Thickness = 1,
				Transparency = 0.25,
			}),
			scope:New("UIPadding")({
				PaddingBottom = UDim.new(0, 18),
				PaddingLeft = UDim.new(0, 18),
				PaddingRight = UDim.new(0, 18),
				PaddingTop = UDim.new(0, 18),
			}),
			scope:New("UIListLayout")({
				FillDirection = Enum.FillDirection.Vertical,
				Padding = UDim.new(0, 10),
				SortOrder = Enum.SortOrder.LayoutOrder,
			}),
			scope:New("TextLabel")({
				Name = "Status",
				BackgroundTransparency = 1,
				Font = Enum.Font.GothamBold,
				LayoutOrder = 1,
				Size = UDim2.new(1, 0, 0, 24),
				Text = "SYSTEM READY",
				TextColor3 = Color3.fromRGB(77, 219, 153),
				TextSize = 16,
				TextXAlignment = Enum.TextXAlignment.Left,
			}),
			scope:New("TextLabel")({
				Name = "Count",
				BackgroundTransparency = 1,
				Font = Enum.Font.Gotham,
				LayoutOrder = 2,
				Size = UDim2.new(1, 0, 0, 24),
				Text = scope:Computed(function(use)
					return `Count: {use(props.Count)}`
				end),
				TextColor3 = Color3.fromRGB(224, 231, 241),
				TextSize = 15,
				TextXAlignment = Enum.TextXAlignment.Left,
			}),
		},
	})

	return card :: Frame
end

return StatusCard
