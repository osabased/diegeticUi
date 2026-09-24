--!strict

local LogService = game:GetService("LogService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Fusion = require(ReplicatedStorage.Packages.Fusion)

type Scope = Fusion.Scope<typeof(Fusion)>

export type Checks = {
	[string]: boolean,
	version: boolean,
	initialBinding: boolean,
	reactiveBinding: boolean,
	observer: boolean,
	eventConnection: boolean,
	strictForPairsTween: boolean,
	injectedFailure: boolean,
	failureCleanup: boolean,
	finalCleanup: boolean,
	cleanDiagnostics: boolean,
}

export type Result = {
	ok: boolean,
	checks: Checks,
	error: string?,
	diagnostics: { string },
}

local Fixture = {}

-- Specialize Fusion's UsedAs<T> callbacks for the new Luau solver.
local function useNumber(use: Fusion.Use, value: Fusion.UsedAs<number>): number
	return (use :: (Fusion.UsedAs<number>) -> number)(value)
end

local function useString(use: Fusion.Use, value: Fusion.UsedAs<string>): string
	return (use :: (Fusion.UsedAs<string>) -> string)(value)
end

local peekNumber = Fusion.peek :: (Fusion.UsedAs<number>) -> number
local tweenNumber =
	Fusion.Tween :: (Fusion.Scope<unknown>, Fusion.UsedAs<number>, Fusion.UsedAs<TweenInfo>?) -> Fusion.Tween<number>

local function traceError(problem: unknown): string
	return debug.traceback(tostring(problem), 2)
end

local function waitUntil(predicate: () -> boolean, timeoutSeconds: number): boolean
	local deadline = os.clock() + timeoutSeconds
	repeat
		if predicate() then
			return true
		end
		task.wait()
	until os.clock() >= deadline
	return predicate()
end

local function allChecksPass(checks: Checks): boolean
	return checks.version
		and checks.initialBinding
		and checks.reactiveBinding
		and checks.observer
		and checks.eventConnection
		and checks.strictForPairsTween
		and checks.injectedFailure
		and checks.failureCleanup
		and checks.finalCleanup
		and checks.cleanDiagnostics
end

function Fixture.run(parent: Instance): Result
	local baselineChildren = #parent:GetChildren()
	local diagnostics: { string } = {}
	local connection = LogService.MessageOut:Connect(function(message, messageType)
		local isError = messageType == Enum.MessageType.MessageError
		local isWarning = messageType == Enum.MessageType.MessageWarning
		if isError or isWarning then
			table.insert(diagnostics, message)
		end
	end)

	local checks: Checks = {
		version = Fusion.version.major == 0 and Fusion.version.minor == 3 and Fusion.version.isRelease,
		initialBinding = false,
		reactiveBinding = false,
		observer = false,
		eventConnection = false,
		strictForPairsTween = false,
		injectedFailure = false,
		failureCleanup = false,
		finalCleanup = false,
		cleanDiagnostics = false,
	}

	local scope = Fusion.scoped(Fusion)
	local bodyError: string? = nil
	local bodyOk = xpcall(function()
		local count = scope:Value(1)
		local doubled = scope:Computed(function(use)
			return useNumber(use, count) * 2
		end)
		local observerCalls = 0
		scope:Observer(doubled):onChange(function()
			observerCalls += 1
		end)

		local eventCalls = 0
		local event = scope:New("BindableEvent")({
			[scope.OnEvent("Event")] = function()
				eventCalls += 1
			end,
		}) :: BindableEvent
		local label = scope:New("TextLabel")({
			Name = "FusionFixtureLabel",
			Text = scope:Computed(function(use)
				return `count:{useNumber(use, count)} double:{useNumber(use, doubled)}`
			end),
		}) :: TextLabel
		scope:New("Frame")({
			Name = "FusionFixtureRoot",
			Parent = parent,
			[scope.Children] = { label, event } :: { Instance },
		})

		checks.initialBinding = label.Text == "count:1 double:2"
		event:Fire()
		checks.eventConnection = waitUntil(function()
			return eventCalls == 1
		end, 1)
		count:set(2)
		checks.reactiveBinding = waitUntil(function()
			return label.Text == "count:2 double:4"
		end, 1)
		checks.observer = waitUntil(function()
			return observerCalls >= 1 and peekNumber(doubled) == 4
		end, 1)

		local selectedId = scope:Value("alpha")
		local rows = scope:ForPairs({
			alpha = { label = "Alpha" },
		}, function(_use, rowScope: Scope, presetId, preset)
			local selectedGoal = rowScope:Computed(function(use)
				return if useString(use, selectedId) == presetId then 0 else 1
			end)
			local selectedMotion = tweenNumber(rowScope, selectedGoal, TweenInfo.new(0.01))
			local row = rowScope:New("TextButton")({
				Name = "FusionFixtureRow",
				Text = preset.label,
				BackgroundTransparency = selectedMotion,
			}) :: TextButton
			return presetId, row
		end)
		local rowsRoot = scope:New("Frame")({
			Name = "FusionFixtureRows",
			Parent = parent,
			[scope.Children] = rows,
		}) :: Frame
		local renderedRow = rowsRoot:FindFirstChild("FusionFixtureRow")
		checks.strictForPairsTween = renderedRow ~= nil
			and renderedRow:IsA("TextButton")
			and renderedRow.Text == "Alpha"

		local beforeFailureChildren = #parent:GetChildren()
		local failureScope = Fusion.scoped(Fusion)
		local failureRoot: Frame? = nil
		local failureMessage: string? = nil
		local failureOk = xpcall(function()
			failureRoot = failureScope:New("Frame")({
				Name = "FusionFixtureFailureRoot",
				Parent = parent,
			}) :: Frame
			error("intentional fixture construction failure")
		end, function(problem)
			failureMessage = traceError(problem)
			return failureMessage
		end)
		local failureCleanupOk = xpcall(function()
			Fusion.doCleanup(failureScope)
		end, function(problem)
			return traceError(problem)
		end)
		checks.injectedFailure = not failureOk
			and failureMessage ~= nil
			and string.find(failureMessage, "intentional fixture construction failure", 1, true) ~= nil
		checks.failureCleanup = failureCleanupOk
			and failureRoot ~= nil
			and failureRoot.Parent == nil
			and #parent:GetChildren() == beforeFailureChildren
	end, function(problem)
		bodyError = traceError(problem)
		return bodyError
	end)

	local cleanupError: string? = nil
	local cleanupOk = xpcall(function()
		Fusion.doCleanup(scope)
	end, function(problem)
		cleanupError = traceError(problem)
		return cleanupError
	end)
	checks.finalCleanup = cleanupOk and #parent:GetChildren() == baselineChildren

	for _ = 1, 3 do
		task.wait()
	end
	connection:Disconnect()
	checks.cleanDiagnostics = #diagnostics == 0

	local combinedError: string? = nil
	if not bodyOk then
		combinedError = bodyError or "fixture body failed"
	end
	if not cleanupOk then
		combinedError = if combinedError == nil
			then cleanupError or "fixture cleanup failed"
			else combinedError .. "\n" .. (cleanupError or "fixture cleanup failed")
	end

	return {
		ok = bodyOk and cleanupOk and allChecksPass(checks),
		checks = checks,
		error = combinedError,
		diagnostics = diagnostics,
	}
end

return Fixture
