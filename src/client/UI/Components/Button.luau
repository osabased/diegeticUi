--!strict

local GuiService = game:GetService("GuiService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Fusion = require(ReplicatedStorage.Packages.Fusion)
local Janitor = require(ReplicatedStorage.Packages.Janitor)
local LemonSignal = require(ReplicatedStorage.Packages.LemonSignal)

local Children = Fusion.Children
local OnEvent = Fusion.OnEvent

type Scope = Fusion.Scope<typeof(Fusion)>
export type Variant = "primary" | "success" | "danger"
export type InteractionKind =
	"hovered"
	| "idle"
	| "pressed"
	| "holding"
	| "cancelled"
	| "activated"
	| "submitting"
	| "succeeded"
	| "failed"
	| "cooldown"
export type InteractionEvent = {
	kind: InteractionKind,
	sequence: number,
	progress: number?,
	message: string?,
}
export type ActionResult = {
	accepted: boolean,
	message: string,
	cooldownSeconds: number,
}

export type Props = {
	Parent: Instance?,
	OnActivated: (() -> ())?,
	OnInteraction: ((InteractionEvent) -> ())?,
	Text: Fusion.UsedAs<string>?,
	IconText: Fusion.UsedAs<string>?,
	Variant: Variant?,
	Disabled: Fusion.UsedAs<boolean>?,
	Loading: Fusion.UsedAs<boolean>?,
	HoldDuration: number?,
	CooldownDuration: number?,
	ActionId: string?,
	RequestAction: ((string) -> ActionResult)?,
}

local INK_COLOR = Color3.fromRGB(237, 245, 255)
local TRANSITION = TweenInfo.new(0.14, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)

type Palette = {
	default: Color3,
	hover: Color3,
	pressed: Color3,
	accent: Color3,
	shadow: Color3,
	gradient: ColorSequence,
}

local PALETTES: { [Variant]: Palette } = {
	primary = {
		default = Color3.fromRGB(47, 103, 211),
		hover = Color3.fromRGB(59, 130, 246),
		pressed = Color3.fromRGB(29, 78, 216),
		accent = Color3.fromRGB(168, 139, 250),
		shadow = Color3.fromRGB(17, 24, 62),
		gradient = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(111, 74, 232)),
			ColorSequenceKeypoint.new(0.52, Color3.fromRGB(45, 125, 238)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(20, 184, 166)),
		}),
	},
	success = {
		default = Color3.fromRGB(15, 118, 110),
		hover = Color3.fromRGB(20, 184, 166),
		pressed = Color3.fromRGB(13, 84, 80),
		accent = Color3.fromRGB(94, 234, 212),
		shadow = Color3.fromRGB(7, 55, 54),
		gradient = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(170, 255, 230)),
			ColorSequenceKeypoint.new(0.55, Color3.fromRGB(150, 255, 235)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(160, 240, 255)),
		}),
	},
	danger = {
		default = Color3.fromRGB(190, 52, 76),
		hover = Color3.fromRGB(244, 63, 94),
		pressed = Color3.fromRGB(159, 36, 58),
		accent = Color3.fromRGB(253, 164, 175),
		shadow = Color3.fromRGB(76, 18, 39),
		gradient = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 165, 210)),
			ColorSequenceKeypoint.new(0.55, Color3.fromRGB(255, 210, 210)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 220, 150)),
		}),
	},
}

local function Button(scope: Scope, props: Props): TextButton
	local variant: Variant = props.Variant or "primary"
	local palette = PALETTES[variant]
	local text = props.Text or "Click me"
	local iconText = props.IconText or ">"
	local disabled = props.Disabled or false
	local loading = props.Loading or false
	local holdDuration = math.max(props.HoldDuration or 0, 0)
	local defaultCooldown = math.max(props.CooldownDuration or 0, 0)
	local janitor = Janitor.new()
	local interactionSignal = LemonSignal.new()
	local isHovered = scope:Value(false)
	local isPressed = scope:Value(false)
	local isBusy = scope:Value(false)
	local holdProgress = scope:Value(0)
	local cooldownRemaining = scope:Value(0)
	local statusText = scope:Value("")
	local statusIcon = scope:Value("")
	local reducedMotion = scope:Value(GuiService.ReducedMotionEnabled)
	local suppressActivatedUntil = 0
	local alive = true
	local interactionSequence = 0

	janitor:Add(interactionSignal, "Destroy", "InteractionSignal")
	if props.OnInteraction ~= nil then
		local onInteraction = props.OnInteraction
		janitor:Add(
			interactionSignal:Connect(function(event: InteractionEvent)
				if alive then
					onInteraction(event)
				end
			end),
			"Disconnect",
			"InteractionListener"
		)
	end
	table.insert(scope, function()
		alive = false
		janitor:Destroy()
	end)

	local function emit(kind: InteractionKind, progress: number?, message: string?)
		interactionSequence += 1
		interactionSignal:Fire({
			kind = kind,
			sequence = interactionSequence,
			progress = progress,
			message = message,
		})
	end

	table.insert(
		scope,
		GuiService:GetPropertyChangedSignal("ReducedMotionEnabled"):Connect(function()
			reducedMotion:set(GuiService.ReducedMotionEnabled)
		end)
	)

	local isUnavailable = scope:Computed(function(use)
		return use(disabled) or use(loading) or use(isBusy) or use(cooldownRemaining) > 0
	end)
	local isInteractable = scope:Computed(function(use)
		return not use(isUnavailable)
	end)
	local displayText = scope:Computed(function(use)
		if use(isBusy) or use(loading) then
			return "Working..."
		end
		local currentStatus = use(statusText)
		return if currentStatus ~= "" then currentStatus else use(text)
	end)
	local displayIcon = scope:Computed(function(use)
		if use(isBusy) or use(loading) then
			return "..."
		end
		local remaining = use(cooldownRemaining)
		if remaining > 0 then
			return tostring(math.max(math.ceil(remaining), 1))
		end
		local currentStatusIcon = use(statusIcon)
		return if currentStatusIcon ~= "" then currentStatusIcon else use(iconText)
	end)
	local backgroundGoal = scope:Computed(function(use)
		if use(isUnavailable) then
			return palette.default
		elseif use(isPressed) then
			return palette.pressed
		elseif use(isHovered) then
			return palette.hover
		else
			return palette.default
		end
	end)
	local scaleGoal = scope:Computed(function(use)
		if use(reducedMotion) or use(isUnavailable) then
			return 1
		elseif use(isPressed) then
			return 0.97
		elseif use(isHovered) then
			return 1.02
		else
			return 1
		end
	end)
	local strokeTransparencyGoal = scope:Computed(function(use)
		if use(disabled) then
			return 0.68
		elseif use(loading) then
			return 0.3
		elseif use(isPressed) then
			return 0.08
		elseif use(isHovered) then
			return 0.16
		else
			return 0.38
		end
	end)
	local sheenOffsetGoal = scope:Computed(function(use)
		if use(reducedMotion) or use(isUnavailable) then
			return Vector2.new(-0.25, 0)
		elseif use(isPressed) then
			return Vector2.new(0.05, 0)
		elseif use(isHovered) then
			return Vector2.new(0.35, 0)
		else
			return Vector2.new(-0.25, 0)
		end
	end)
	local shadowPositionGoal = scope:Computed(function(use)
		if use(reducedMotion) or use(isUnavailable) or use(isPressed) then
			return UDim2.new(0.5, 0, 0.5, 2)
		else
			return UDim2.new(0.5, 0, 0.5, 6)
		end
	end)
	local backgroundTransparencyGoal = scope:Computed(function(use)
		return if use(disabled) then 0.28 else 0
	end)
	local contentTransparencyGoal = scope:Computed(function(use)
		return if use(disabled) then 0.34 else 0
	end)
	local holdSize = scope:Computed(function(use)
		return UDim2.fromScale(math.clamp(use(holdProgress), 0, 1), 1)
	end)
	local holdVisible = scope:Computed(function(use)
		return use(holdProgress) > 0
	end)

	local function beginCooldown(duration: number)
		janitor:Remove("CooldownConnection")
		if duration <= 0 then
			cooldownRemaining:set(0)
			return
		end

		local endsAt = os.clock() + duration
		cooldownRemaining:set(duration)
		emit("cooldown", 1, string.format("Ready in %.1fs", duration))
		janitor:Add(
			RunService.Heartbeat:Connect(function()
				local remaining = math.max(endsAt - os.clock(), 0)
				cooldownRemaining:set(remaining)
				if remaining <= 0 then
					janitor:Remove("CooldownConnection")
					emit("idle")
				end
			end),
			"Disconnect",
			"CooldownConnection"
		)
	end

	local function showStatus(message: string, accepted: boolean)
		statusText:set(message)
		statusIcon:set(if accepted then "+" else "!")
		janitor:Add(
			task.delay(1.4, function()
				janitor:RemoveNoClean("StatusTimer")
				statusText:set("")
				statusIcon:set("")
			end),
			true,
			"StatusTimer"
		)
	end

	local function activate()
		if Fusion.peek(isUnavailable) then
			return
		end

		isPressed:set(false)
		holdProgress:set(0)
		emit("activated")
		if props.OnActivated ~= nil then
			props.OnActivated()
		end

		local actionId = props.ActionId
		local requestAction = props.RequestAction
		if actionId == nil or requestAction == nil then
			beginCooldown(defaultCooldown)
			return
		end

		isBusy:set(true)
		emit("submitting", nil, "Contacting server")
		janitor:Add(
			task.spawn(function()
				local ok, result = pcall(requestAction, actionId)
				janitor:RemoveNoClean("ActionThread")
				isBusy:set(false)

				if not ok then
					local message = "Server unavailable"
					showStatus(message, false)
					emit("failed", nil, message)
					return
				end

				local response = result :: ActionResult
				showStatus(response.message, response.accepted)
				emit(if response.accepted then "succeeded" else "failed", nil, response.message)
				beginCooldown(math.max(defaultCooldown, response.cooldownSeconds))
			end),
			true,
			"ActionThread"
		)
	end

	local function cancelHold(emitCancellation: boolean)
		local progress = Fusion.peek(holdProgress)
		janitor:Remove("HoldConnection")
		holdProgress:set(0)
		isPressed:set(false)
		if emitCancellation and progress > 0 then
			emit("cancelled", progress, "Hold cancelled")
		end
	end

	local function beginHold()
		if Fusion.peek(isUnavailable) then
			return
		end

		isPressed:set(true)
		if holdDuration <= 0 then
			emit("pressed")
			return
		end

		local startedAt = os.clock()
		local lastReportedStep = -1
		holdProgress:set(0.001)
		emit("holding", 0, "Keep holding")
		janitor:Add(
			RunService.Heartbeat:Connect(function()
				local progress = math.clamp((os.clock() - startedAt) / holdDuration, 0, 1)
				holdProgress:set(progress)
				local reportedStep = math.floor(progress * 10)
				if reportedStep > lastReportedStep then
					lastReportedStep = reportedStep
					emit("holding", progress)
				end
				if progress >= 1 then
					janitor:Remove("HoldConnection")
					activate()
				end
			end),
			"Disconnect",
			"HoldConnection"
		)
	end

	local button = scope:New("TextButton")({
		Name = "Button",
		Parent = props.Parent,
		Active = isInteractable,
		AnchorPoint = Vector2.new(0.5, 0.5),
		AutoButtonColor = false,
		BackgroundColor3 = scope:Tween(backgroundGoal, TRANSITION),
		BackgroundTransparency = scope:Tween(backgroundTransparencyGoal, TRANSITION),
		BorderSizePixel = 0,
		Font = Enum.Font.GothamBold,
		Position = UDim2.fromScale(0.5, 0.5),
		Selectable = isInteractable,
		Size = UDim2.fromOffset(176, 52),
		Text = text,
		TextColor3 = INK_COLOR,
		TextSize = 16,
		TextTransparency = 1,
		ZIndex = 2,

		[OnEvent("MouseEnter")] = function()
			if not Fusion.peek(isUnavailable) then
				isHovered:set(true)
				emit("hovered")
			end
		end,
		[OnEvent("MouseLeave")] = function()
			isHovered:set(false)
			cancelHold(true)
			emit("idle")
		end,
		[OnEvent("MouseButton1Down")] = function()
			beginHold()
		end,
		[OnEvent("MouseButton1Up")] = function()
			if holdDuration > 0 then
				suppressActivatedUntil = os.clock() + 0.15
				cancelHold(true)
			else
				isPressed:set(false)
			end
		end,
		[OnEvent("Activated")] = function()
			if os.clock() < suppressActivatedUntil then
				return
			end
			activate()
		end,

		[Children] = {
			scope:New("Frame")({
				Name = "Shadow",
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundColor3 = palette.shadow,
				BackgroundTransparency = 0.18,
				BorderSizePixel = 0,
				Position = scope:Tween(shadowPositionGoal, TRANSITION),
				Size = UDim2.fromScale(1, 1),
				ZIndex = 0,

				[Children] = {
					scope:New("UICorner")({
						CornerRadius = UDim.new(0, 14),
					}),
					scope:New("UIStroke")({
						Color = palette.accent,
						Thickness = 4,
						Transparency = 0.78,
					}),
				},
			}),
			scope:New("UIGradient")({
				Color = palette.gradient,
				Offset = scope:Tween(sheenOffsetGoal, TRANSITION),
				Rotation = -8,
			}),
			scope:New("UICorner")({
				CornerRadius = UDim.new(0, 14),
			}),
			scope:New("UIStroke")({
				ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
				Color = Color3.fromRGB(216, 230, 255),
				Thickness = 1.4,
				Transparency = scope:Tween(strokeTransparencyGoal, TRANSITION),
			}),
			scope:New("UIScale")({
				Scale = scope:Tween(scaleGoal, TRANSITION),
			}),
			scope:New("TextLabel")({
				Name = "Label",
				BackgroundTransparency = 1,
				Font = Enum.Font.GothamBold,
				Position = UDim2.fromOffset(14, 0),
				Size = UDim2.new(1, -60, 1, 0),
				Text = displayText,
				TextColor3 = INK_COLOR,
				TextSize = 16,
				TextTransparency = scope:Tween(contentTransparencyGoal, TRANSITION),
				ZIndex = 3,
			}),
			scope:New("Frame")({
				Name = "InnerHighlight",
				AnchorPoint = Vector2.new(0.5, 0),
				BackgroundColor3 = Color3.fromRGB(255, 255, 255),
				BackgroundTransparency = 0.64,
				BorderSizePixel = 0,
				Position = UDim2.new(0.5, 0, 0, 2),
				Size = UDim2.new(1, -24, 0, 1),
				ZIndex = 3,

				[Children] = {
					scope:New("UIGradient")({
						Transparency = NumberSequence.new({
							NumberSequenceKeypoint.new(0, 1),
							NumberSequenceKeypoint.new(0.22, 0),
							NumberSequenceKeypoint.new(0.78, 0),
							NumberSequenceKeypoint.new(1, 1),
						}),
					}),
				},
			}),
			scope:New("Frame")({
				Name = "ActionBadge",
				AnchorPoint = Vector2.new(1, 0.5),
				BackgroundColor3 = Color3.fromRGB(255, 255, 255),
				BackgroundTransparency = scope:Tween(
					scope:Computed(function(use)
						return if use(disabled) then 0.92 else 0.82
					end),
					TRANSITION
				),
				BorderSizePixel = 0,
				Position = UDim2.new(1, -10, 0.5, 0),
				Size = UDim2.fromOffset(30, 30),
				ZIndex = 3,

				[Children] = {
					scope:New("UICorner")({
						CornerRadius = UDim.new(1, 0),
					}),
					scope:New("UIStroke")({
						Color = Color3.fromRGB(255, 255, 255),
						Thickness = 1,
						Transparency = 0.68,
					}),
					scope:New("TextLabel")({
						BackgroundTransparency = 1,
						Font = Enum.Font.GothamBold,
						Size = UDim2.fromScale(1, 1),
						Text = displayIcon,
						TextColor3 = INK_COLOR,
						TextSize = 16,
						TextTransparency = scope:Tween(contentTransparencyGoal, TRANSITION),
						ZIndex = 4,
					}),
				},
			}),
			scope:New("Frame")({
				Name = "HoldTrack",
				AnchorPoint = Vector2.new(0.5, 1),
				BackgroundColor3 = Color3.fromRGB(8, 18, 38),
				BackgroundTransparency = 0.35,
				BorderSizePixel = 0,
				ClipsDescendants = true,
				Position = UDim2.new(0.5, 0, 1, -3),
				Size = UDim2.new(1, -24, 0, 4),
				Visible = holdVisible,
				ZIndex = 5,

				[Children] = {
					scope:New("UICorner")({
						CornerRadius = UDim.new(1, 0),
					}),
					scope:New("Frame")({
						Name = "Fill",
						BackgroundColor3 = palette.accent,
						BorderSizePixel = 0,
						Size = holdSize,

						[Children] = {
							scope:New("UICorner")({
								CornerRadius = UDim.new(1, 0),
							}),
						},
					}),
				},
			}),
		},
	})
	janitor:LinkToInstance(button)

	return button :: TextButton
end

return Button
