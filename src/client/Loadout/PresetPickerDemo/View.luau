--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Fusion = require(ReplicatedStorage.Packages.Fusion)
local Domain = require(script.Parent.Domain)

type Scope = Fusion.Scope<typeof(Fusion)>

export type Handlers = {
	onQueryChanged: (string) -> (),
	onSelect: (string) -> (),
}

local View = {}

local COLOR = {
	ink = Color3.fromRGB(231, 239, 244),
	muted = Color3.fromRGB(139, 157, 168),
	panel = Color3.fromRGB(17, 24, 29),
	raised = Color3.fromRGB(27, 36, 43),
	line = Color3.fromRGB(55, 70, 80),
	cyan = Color3.fromRGB(80, 216, 232),
}

local function addCorner(scope: Scope, parent: Instance, radius: number)
	scope:New("UICorner")({
		CornerRadius = UDim.new(0, radius),
		Parent = parent,
	})
end

local function addStroke(scope: Scope, parent: Instance, color: Color3, transparency: number?)
	scope:New("UIStroke")({
		Color = color,
		Transparency = transparency or 0,
		Thickness = 1,
		Parent = parent,
	})
end

function View.create(scope: Scope, parent: Instance, state: Fusion.Value<Domain.State>, handlers: Handlers): Frame
	local filteredById = scope:Computed(function(use)
		local byId: { [string]: Domain.Preset } = {}
		for _, preset in Domain.filter(use(state)) do
			byId[preset.id] = preset
		end
		return byId
	end)
	local resultCount = scope:Computed(function(use)
		local count = 0
		for _ in use(filteredById) do
			count += 1
		end
		return count
	end)

	local root = scope:New("Frame")({
		Name = "PresetPicker",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(580, 460),
		BackgroundColor3 = COLOR.panel,
		BorderSizePixel = 0,
		Parent = parent,
	}) :: Frame
	addCorner(scope, root, 12)
	addStroke(scope, root, COLOR.line, 0.1)

	scope:New("TextLabel")({
		Name = "Title",
		Position = UDim2.fromOffset(22, 18),
		Size = UDim2.new(1, -44, 0, 28),
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBold,
		Text = "LOADOUT PRESETS",
		TextColor3 = COLOR.ink,
		TextSize = 22,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = root,
	})

	scope:New("TextLabel")({
		Name = "Subtitle",
		Position = UDim2.fromOffset(23, 48),
		Size = UDim2.new(1, -46, 0, 20),
		BackgroundTransparency = 1,
		Font = Enum.Font.Gotham,
		Text = "Development preview / local fake data",
		TextColor3 = COLOR.muted,
		TextSize = 12,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = root,
	})

	local search = scope:New("TextBox")({
		Name = "Search",
		Position = UDim2.fromOffset(22, 82),
		Size = UDim2.new(1, -44, 0, 42),
		BackgroundColor3 = COLOR.raised,
		BorderSizePixel = 0,
		ClearTextOnFocus = false,
		Font = Enum.Font.Gotham,
		PlaceholderColor3 = COLOR.muted,
		PlaceholderText = "Search name, role, or equipment",
		Text = scope:Computed(function(use)
			return use(state).query
		end),
		TextColor3 = COLOR.ink,
		TextSize = 14,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = root,
		[scope.OnChange("Text")] = handlers.onQueryChanged,
	}) :: TextBox
	addCorner(scope, search, 8)
	addStroke(scope, search, COLOR.line, 0.25)
	scope:New("UIPadding")({
		PaddingLeft = UDim.new(0, 13),
		PaddingRight = UDim.new(0, 13),
		Parent = search,
	})

	scope:New("TextLabel")({
		Name = "ResultCount",
		Position = UDim2.fromOffset(22, 134),
		Size = UDim2.new(1, -44, 0, 18),
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamMedium,
		Text = scope:Computed(function(use)
			local count = use(resultCount)
			return if count == 1 then "1 PRESET" else string.format("%d PRESETS", count)
		end),
		TextColor3 = COLOR.cyan,
		TextSize = 11,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = root,
	})

	local rows = scope:ForPairs(
		filteredById,
		function(_use: Fusion.Use, rowScope: Scope, presetId: string, preset: Domain.Preset): (string, TextButton)
			local selectedGoal: Fusion.Computed<number> = rowScope:Computed(function(use): number
				return if use(state).selectedId == presetId then 1 else 0
			end)
			local selectedMotion: Fusion.Tween<number> =
				rowScope:Tween(selectedGoal, TweenInfo.new(0.18, Enum.EasingStyle.Quint, Enum.EasingDirection.Out))
			local button = rowScope:New("TextButton")({
				Name = presetId,
				LayoutOrder = preset.order,
				Size = UDim2.new(1, -5, 0, 68),
				BackgroundColor3 = rowScope:Computed(function(use)
					return if use(state).selectedId == presetId
						then preset.accent:Lerp(COLOR.raised, 0.78)
						else COLOR.raised
				end),
				BorderSizePixel = 0,
				AutoButtonColor = false,
				Text = "",
				[rowScope.OnEvent("Activated")] = function()
					handlers.onSelect(presetId)
				end,
			}) :: TextButton
			addCorner(rowScope, button, 8)
			addStroke(rowScope, button, preset.accent, 0.35)

			rowScope:New("Frame")({
				Name = "SelectionIndicator",
				AnchorPoint = Vector2.new(0, 0.5),
				Position = UDim2.fromScale(0, 0.5),
				Size = rowScope:Computed(function(use)
					return UDim2.new(0, 4, use(selectedMotion), 0)
				end),
				BackgroundColor3 = preset.accent,
				BorderSizePixel = 0,
				Parent = button,
			})

			rowScope:New("TextLabel")({
				Name = "PresetName",
				Position = UDim2.fromOffset(18, 10),
				Size = UDim2.new(1, -150, 0, 20),
				BackgroundTransparency = 1,
				Font = Enum.Font.GothamBold,
				Text = preset.name,
				TextColor3 = COLOR.ink,
				TextSize = 14,
				TextXAlignment = Enum.TextXAlignment.Left,
				Parent = button,
			})
			rowScope:New("TextLabel")({
				Name = "Description",
				Position = UDim2.fromOffset(18, 34),
				Size = UDim2.new(1, -36, 0, 22),
				BackgroundTransparency = 1,
				Font = Enum.Font.Gotham,
				Text = preset.description,
				TextColor3 = COLOR.muted,
				TextSize = 12,
				TextTruncate = Enum.TextTruncate.AtEnd,
				TextXAlignment = Enum.TextXAlignment.Left,
				Parent = button,
			})
			rowScope:New("TextLabel")({
				Name = "Slots",
				AnchorPoint = Vector2.new(1, 0),
				Position = UDim2.new(1, -14, 0, 11),
				Size = UDim2.fromOffset(118, 18),
				BackgroundTransparency = 1,
				Font = Enum.Font.GothamMedium,
				Text = preset.slots,
				TextColor3 = preset.accent,
				TextSize = 11,
				TextXAlignment = Enum.TextXAlignment.Right,
				Parent = button,
			})

			return presetId, button
		end
	)
	local list = scope:New("ScrollingFrame")({
		Name = "PresetList",
		Position = UDim2.fromOffset(22, 158),
		Size = UDim2.new(1, -44, 1, -222),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		CanvasSize = UDim2.new(),
		ScrollBarImageColor3 = COLOR.cyan,
		ScrollBarThickness = 3,
		Parent = root,
		[scope.Children] = rows,
	}) :: ScrollingFrame
	scope:New("UIListLayout")({
		Padding = UDim.new(0, 8),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = list,
	})

	scope:New("TextLabel")({
		Name = "EmptyState",
		LayoutOrder = -1,
		Size = UDim2.new(1, -5, 0, 96),
		BackgroundColor3 = COLOR.raised,
		BackgroundTransparency = 0.35,
		BorderSizePixel = 0,
		Font = Enum.Font.GothamMedium,
		Text = scope:Computed(function(use)
			local query = use(state).query
			return if query == "" then "No presets available." else string.format("No presets match “%s”.", query)
		end),
		TextColor3 = COLOR.muted,
		TextSize = 14,
		Visible = scope:Computed(function(use)
			return use(resultCount) == 0
		end),
		Parent = list,
	})

	scope:New("TextLabel")({
		Name = "SelectedSummary",
		Position = UDim2.new(0, 22, 1, -48),
		Size = UDim2.new(1, -44, 0, 24),
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamMedium,
		Text = scope:Computed(function(use)
			local current = use(state)
			if current.selectedId == nil then
				return "No preset selected"
			end
			for _, preset in current.presets do
				if preset.id == current.selectedId then
					return "Selected: " .. preset.name
				end
			end
			return "No preset selected"
		end),
		TextColor3 = COLOR.ink,
		TextSize = 13,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = root,
	})

	return root
end

return View
