--!strict

local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")

local ButtonPlaytest = {}

export type StateName = "default" | "hover" | "pressed"
export type Snapshot = {
	color: Color3,
	scale: number,
	reducedMotion: boolean,
}

local EXPECTED = {
	default = {
		color = Color3.fromRGB(47, 103, 211),
		scale = 1,
	},
	hover = {
		color = Color3.fromRGB(59, 130, 246),
		scale = 1.02,
	},
	pressed = {
		color = Color3.fromRGB(29, 78, 216),
		scale = 0.97,
	},
}

local COLOR_TOLERANCE = 2 / 255
local SCALE_TOLERANCE = 0.005
local POLL_INTERVAL_SECONDS = 0.03

local function tryFindButton(): (TextButton?, string?)
	local player = Players.LocalPlayer
	if player == nil then
		return nil, "missing LocalPlayer"
	end
	local playerGui = player:FindFirstChild("PlayerGui")
	if playerGui == nil then
		return nil, "missing LocalPlayer.PlayerGui"
	end
	local screenGui = playerGui:FindFirstChild("ButtonDemo")
	if screenGui == nil then
		return nil, "missing LocalPlayer.PlayerGui.ButtonDemo"
	end
	local button = screenGui:FindFirstChild("Button")
	if button == nil then
		return nil, "missing LocalPlayer.PlayerGui.ButtonDemo.Button"
	end
	assert(button:IsA("TextButton"), "ButtonDemo.Button must be a TextButton")
	assert(button.Text == "Click me", "ButtonDemo.Button has the wrong label")
	return button, nil
end

local function trySnapshot(): (Snapshot?, string?)
	local button, missingReason = tryFindButton()
	if button == nil then
		return nil, missingReason
	end
	local scale = button:FindFirstChildOfClass("UIScale")
	if scale == nil then
		return nil, "missing LocalPlayer.PlayerGui.ButtonDemo.Button.UIScale"
	end
	return {
		color = button.BackgroundColor3,
		scale = scale.Scale,
		reducedMotion = GuiService.ReducedMotionEnabled,
	},
		nil
end

function ButtonPlaytest.snapshot(): Snapshot
	local snapshot, missingReason = trySnapshot()
	return assert(snapshot, missingReason)
end

local function closeNumber(actual: number, expected: number, tolerance: number): boolean
	return math.abs(actual - expected) <= tolerance
end

local function matches(snapshot: Snapshot, state: StateName): boolean
	local expected = EXPECTED[state]
	local expectedScale = if snapshot.reducedMotion then 1 else expected.scale
	return closeNumber(snapshot.color.R, expected.color.R, COLOR_TOLERANCE)
		and closeNumber(snapshot.color.G, expected.color.G, COLOR_TOLERANCE)
		and closeNumber(snapshot.color.B, expected.color.B, COLOR_TOLERANCE)
		and closeNumber(snapshot.scale, expectedScale, SCALE_TOLERANCE)
end

function ButtonPlaytest.waitForState(state: StateName, timeoutSeconds: number?): Snapshot
	local timeout = timeoutSeconds or 1
	assert(timeout >= 0 and timeout < math.huge and timeout == timeout, "timeout must be finite and nonnegative")
	local deadline = os.clock() + timeout
	local lastSnapshot: Snapshot? = nil
	local lastMissingReason: string? = nil

	while true do
		local snapshot, missingReason = trySnapshot()
		lastSnapshot = snapshot
		lastMissingReason = missingReason
		if snapshot ~= nil and matches(snapshot, state) then
			return snapshot
		end

		local remaining = deadline - os.clock()
		if remaining <= 0 then
			break
		end
		task.wait(math.min(POLL_INTERVAL_SECONDS, remaining))
	end

	if lastSnapshot == nil then
		error(
			string.format("button did not settle in %s state before timeout (%s)", state, tostring(lastMissingReason))
		)
	else
		error(
			string.format(
				"button did not settle in %s state before timeout (color %.4f, %.4f, %.4f; scale %.4f; reducedMotion %s)",
				state,
				lastSnapshot.color.R,
				lastSnapshot.color.G,
				lastSnapshot.color.B,
				lastSnapshot.scale,
				tostring(lastSnapshot.reducedMotion)
			)
		)
	end
end

return ButtonPlaytest
