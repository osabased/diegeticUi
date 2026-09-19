--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Fusion = require(ReplicatedStorage.Packages.Fusion)
local Catalog = require(ReplicatedStorage.Shared.Loadout.Catalog)
local StateMachine = require(ReplicatedStorage.Shared.Loadout.StateMachine)

type Scope = Fusion.Scope<typeof(Fusion)>
type State = StateMachine.State
type Handlers = {
	onToggle: () -> (),
	onClose: () -> (),
	onSelect: (string) -> (),
	onEquip: () -> (),
}

local View = {}

local COLOR = {
	ink = Color3.fromRGB(234, 244, 248),
	muted = Color3.fromRGB(137, 157, 166),
	panel = Color3.fromRGB(15, 22, 27),
	panelRaised = Color3.fromRGB(24, 34, 40),
	line = Color3.fromRGB(53, 70, 77),
	cyan = Color3.fromRGB(92, 225, 255),
	green = Color3.fromRGB(91, 240, 173),
	red = Color3.fromRGB(255, 103, 126),
	amber = Color3.fromRGB(255, 185, 102),
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

local function accent(item: Catalog.Item): Color3
	return Color3.fromRGB(item.accent[1], item.accent[2], item.accent[3])
end

function View.create(scope: Scope, parent: Instance, state: Fusion.Value<State>, handlers: Handlers): Frame
	local isNarrow = scope:Value(false)
	local isOpen = scope:Computed(function(use)
		return use(state).isOpen
	end)
	local selected = scope:Computed(function(use)
		return Catalog.get(use(state).selectedId) or Catalog.all()[1]
	end)
	local canEquip = scope:Computed(function(use)
		return StateMachine.canEquip(use(state))
	end)

	local root = scope:New("Frame")({
		Name = "LoadoutRoot",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Parent = parent,
		[scope.OnChange("AbsoluteSize")] = function(size: Vector2)
			isNarrow:set(size.X < 560)
		end,
	})

	local openButton = scope:New("TextButton")({
		Name = "OpenLoadout",
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -22, 1, -22),
		Size = UDim2.fromOffset(174, 48),
		BackgroundColor3 = COLOR.panelRaised,
		AutoButtonColor = true,
		Font = Enum.Font.GothamBold,
		Text = "LOADOUT  [L]",
		TextColor3 = COLOR.ink,
		TextSize = 13,
		Visible = scope:Computed(function(use)
			return not use(isOpen)
		end),
		ZIndex = 20,
		Parent = root,
		[scope.OnEvent("Activated")] = handlers.onToggle,
	})
	addCorner(scope, openButton, 8)
	addStroke(scope, openButton, COLOR.cyan, 0.25)

	scope:New("TextButton")({
		Name = "ModalShade",
		Text = "",
		AutoButtonColor = false,
		BackgroundColor3 = Color3.fromRGB(3, 7, 9),
		BackgroundTransparency = 0.3,
		Size = UDim2.fromScale(1, 1),
		Visible = isOpen,
		ZIndex = 5,
		Parent = root,
		[scope.OnEvent("Activated")] = handlers.onClose,
	})

	local panel = scope:New("Frame")({
		Name = "LoadoutPanel",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.9, 0.82),
		BackgroundColor3 = COLOR.panel,
		Visible = isOpen,
		ZIndex = 6,
		ClipsDescendants = true,
		Parent = root,
	})
	addCorner(scope, panel, 12)
	addStroke(scope, panel, COLOR.line, 0.05)
	scope:New("UISizeConstraint")({
		MinSize = Vector2.new(286, 300),
		MaxSize = Vector2.new(900, 620),
		Parent = panel,
	})

	scope:New("TextLabel")({
		Name = "Title",
		Position = UDim2.fromOffset(24, 17),
		Size = UDim2.new(1, -100, 0, 28),
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBold,
		Text = "SESSION LOADOUT",
		TextColor3 = COLOR.ink,
		TextSize = 22,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 7,
		Parent = panel,
	})
	scope:New("TextLabel")({
		Position = UDim2.fromOffset(25, 45),
		Size = UDim2.new(1, -110, 0, 18),
		BackgroundTransparency = 1,
		Font = Enum.Font.Gotham,
		Text = "QUARTERMASTER / LOCAL SESSION",
		TextColor3 = COLOR.muted,
		TextSize = 10,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 7,
		Parent = panel,
	})

	local closeButton = scope:New("TextButton")({
		Name = "Close",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -18, 0, 18),
		Size = UDim2.fromOffset(36, 36),
		BackgroundColor3 = COLOR.panelRaised,
		Font = Enum.Font.GothamBold,
		Text = "×",
		TextColor3 = COLOR.muted,
		TextSize = 22,
		ZIndex = 8,
		Parent = panel,
		[scope.OnEvent("Activated")] = handlers.onClose,
	})
	addCorner(scope, closeButton, 7)

	local body = scope:New("Frame")({
		Name = "Body",
		Position = UDim2.fromOffset(20, 70),
		Size = UDim2.new(1, -40, 1, -82),
		BackgroundTransparency = 1,
		ZIndex = 7,
		Parent = panel,
	})

	local list = scope:New("ScrollingFrame")({
		Name = "EquipmentList",
		Size = scope:Computed(function(use)
			return if use(isNarrow) then UDim2.new(1, 0, 0, 166) else UDim2.new(0.41, -8, 1, 0)
		end),
		BackgroundColor3 = Color3.fromRGB(11, 17, 21),
		BorderSizePixel = 0,
		ScrollBarThickness = 3,
		ScrollBarImageColor3 = COLOR.cyan,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		ZIndex = 7,
		Parent = body,
	})
	addCorner(scope, list, 8)
	scope:New("UIPadding")({
		PaddingTop = UDim.new(0, 8),
		PaddingBottom = UDim.new(0, 8),
		PaddingLeft = UDim.new(0, 8),
		PaddingRight = UDim.new(0, 8),
		Parent = list,
	})
	scope:New("UIListLayout")({
		Padding = UDim.new(0, 5),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = list,
	})

	for order, item in Catalog.all() do
		local itemColor = accent(item)
		local button = scope:New("TextButton")({
			Name = item.id,
			LayoutOrder = order,
			Size = UDim2.new(1, 0, 0, 40),
			BackgroundColor3 = scope:Computed(function(use)
				return if use(state).selectedId == item.id then itemColor else COLOR.panelRaised
			end),
			BackgroundTransparency = scope:Computed(function(use)
				return if use(state).selectedId == item.id then 0.73 else 0
			end),
			AutoButtonColor = item.available,
			Font = Enum.Font.GothamBold,
			Text = `{item.name}{if item.available then "" else "  ·  LOCKED"}`,
			TextColor3 = if item.available then COLOR.ink else COLOR.muted,
			TextSize = 12,
			TextXAlignment = Enum.TextXAlignment.Left,
			ZIndex = 8,
			Parent = list,
			[scope.OnEvent("Activated")] = function()
				handlers.onSelect(item.id)
			end,
		})
		addCorner(scope, button, 6)
		scope:New("UIPadding")({ PaddingLeft = UDim.new(0, 14), Parent = button })
	end

	local details = scope:New("Frame")({
		Name = "Details",
		Position = scope:Computed(function(use)
			return if use(isNarrow) then UDim2.fromOffset(0, 176) else UDim2.new(0.41, 8, 0, 0)
		end),
		Size = scope:Computed(function(use)
			return if use(isNarrow) then UDim2.new(1, 0, 1, -176) else UDim2.new(0.59, -8, 1, 0)
		end),
		BackgroundColor3 = COLOR.panelRaised,
		ZIndex = 7,
		Parent = body,
	})
	addCorner(scope, details, 8)

	local accentBar = scope:New("Frame")({
		Position = UDim2.fromOffset(18, 18),
		Size = UDim2.fromOffset(5, 48),
		BackgroundColor3 = scope:Computed(function(use)
			return accent(use(selected))
		end),
		ZIndex = 8,
		Parent = details,
	})
	addCorner(scope, accentBar, 3)
	scope:New("TextLabel")({
		Position = UDim2.fromOffset(35, 15),
		Size = UDim2.new(1, -52, 0, 18),
		BackgroundTransparency = 1,
		Font = Enum.Font.Gotham,
		Text = scope:Computed(function(use)
			return use(selected).category
		end),
		TextColor3 = COLOR.muted,
		TextSize = 10,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 8,
		Parent = details,
	})
	scope:New("TextLabel")({
		Position = UDim2.fromOffset(35, 32),
		Size = UDim2.new(1, -52, 0, 32),
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBold,
		Text = scope:Computed(function(use)
			return use(selected).name
		end),
		TextColor3 = COLOR.ink,
		TextSize = 20,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		ZIndex = 8,
		Parent = details,
	})
	scope:New("TextLabel")({
		Position = UDim2.fromOffset(20, 80),
		Size = UDim2.new(1, -40, 0, 58),
		BackgroundTransparency = 1,
		Font = Enum.Font.Gotham,
		Text = scope:Computed(function(use)
			return use(selected).description
		end),
		TextColor3 = COLOR.muted,
		TextSize = 12,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		ZIndex = 8,
		Parent = details,
	})
	scope:New("TextLabel")({
		Position = UDim2.fromOffset(20, 142),
		Size = UDim2.new(1, -40, 0, 22),
		BackgroundTransparency = 1,
		Font = Enum.Font.RobotoMono,
		Text = scope:Computed(function(use)
			return use(selected).stat
		end),
		TextColor3 = scope:Computed(function(use)
			return accent(use(selected))
		end),
		TextSize = 11,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 8,
		Parent = details,
	})

	local status = scope:New("TextLabel")({
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 20, 1, -58),
		Size = UDim2.new(1, -40, 0, 40),
		BackgroundColor3 = Color3.fromRGB(11, 17, 21),
		Font = Enum.Font.Gotham,
		Text = scope:Computed(function(use)
			return "  " .. use(state).message
		end),
		TextColor3 = scope:Computed(function(use)
			local feedback = use(state).feedback
			if feedback == "success" then
				return COLOR.green
			elseif feedback == "rejected" then
				return COLOR.red
			elseif feedback == "pending" then
				return COLOR.amber
			end
			return COLOR.muted
		end),
		TextSize = 10,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 8,
		Parent = details,
	})
	addCorner(scope, status, 5)

	local equipButton = scope:New("TextButton")({
		Name = "Equip",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 20, 1, -10),
		Size = UDim2.new(1, -40, 0, 40),
		BackgroundColor3 = scope:Computed(function(use)
			return if use(canEquip) then accent(use(selected)) else COLOR.line
		end),
		AutoButtonColor = canEquip,
		Active = canEquip,
		Font = Enum.Font.GothamBold,
		Text = scope:Computed(function(use)
			local current = use(state)
			local item = use(selected)
			if current.pendingRequestId ~= nil then
				return "EQUIPPING…"
			elseif not item.available then
				return "LOCKED"
			elseif current.equippedId == item.id then
				return "EQUIPPED"
			end
			return "EQUIP FOR THIS SESSION"
		end),
		TextColor3 = scope:Computed(function(use)
			return if use(canEquip) then Color3.fromRGB(5, 20, 24) else COLOR.muted
		end),
		TextSize = 11,
		ZIndex = 8,
		Parent = details,
		[scope.OnEvent("Activated")] = handlers.onEquip,
	})
	addCorner(scope, equipButton, 6)

	return root :: Frame
end

return View
