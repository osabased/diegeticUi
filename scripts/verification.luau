--!strict

local Verification = {}

export type StageName = "format" | "lint" | "analyze" | "unit" | "build" | "studio"
export type StepName = "preflight" | "wally" | "blink" | "sourcemap" | "package_types" | "lest_core" | StageName
export type StageStatus = "passed" | "failed" | "not_run"
export type Outcome = "pending" | "passed" | "failed"
export type ReportErrorKind = "report" | "orchestration" | "cleanup"

export type ReportError = {
	kind: ReportErrorKind,
	message: string,
}

export type Selection = {
	selectedStages: { StageName },
	fullGate: boolean,
}

export type StageRecord = {
	name: StepName,
	status: StageStatus,
	durationMs: number,
	exitCode: number?,
	reason: string?,
}

export type Report = {
	schemaVersion: number,
	startedAt: string,
	selectedStages: { StageName },
	fullGate: boolean,
	outcome: Outcome,
	stages: { StageRecord },
	errors: { ReportError },
}

export type StepResult = {
	ok: boolean,
	exitCode: number?,
	reason: string?,
}

export type Runner = (StepName) -> StepResult
export type Clock = () -> number
export type OnUpdate = (Report) -> ()
export type Persist = (Report) -> ()
export type Cleanup = () -> ()
export type OrchestrationResult = {
	ok: boolean,
	durableReport: boolean,
	finalReportPersisted: boolean,
}

local PUBLIC_STAGE_ORDER: { StageName } = {
	"format",
	"lint",
	"analyze",
	"unit",
	"build",
	"studio",
}

local FULL_GATE_STAGES: { StageName } = {
	"format",
	"lint",
	"analyze",
	"unit",
	"build",
}

local STEP_ORDER: { StepName } = {
	"preflight",
	"wally",
	"blink",
	"sourcemap",
	"package_types",
	"lest_core",
	"format",
	"lint",
	"analyze",
	"unit",
	"build",
	"studio",
}

local VALID_STAGES: { [string]: StageName } = {}
for _, stage in PUBLIC_STAGE_ORDER do
	VALID_STAGES[stage] = stage
end

local function copyStages(stages: { StageName }): { StageName }
	local result: { StageName } = {}
	for _, stage in stages do
		table.insert(result, stage)
	end
	return result
end

function Verification.parseArguments(arguments: { string }): (Selection?, string?)
	if #arguments == 0 then
		return {
			selectedStages = copyStages(FULL_GATE_STAGES),
			fullGate = true,
		}, nil
	end

	local requested: { [StageName]: boolean } = {}
	local index = 1
	while index <= #arguments do
		if arguments[index] ~= "--stage" then
			return nil, string.format("unknown argument: %s", arguments[index])
		end

		local stageArgument = arguments[index + 1]
		if stageArgument == nil then
			return nil, "--stage requires a stage name"
		end

		local stage = VALID_STAGES[stageArgument]
		if stage == nil then
			return nil, string.format("unknown stage: %s", stageArgument)
		end
		requested[stage] = true
		index += 2
	end

	local selectedStages: { StageName } = {}
	for _, stage in PUBLIC_STAGE_ORDER do
		if requested[stage] then
			table.insert(selectedStages, stage)
		end
	end

	return {
		selectedStages = selectedStages,
		fullGate = false,
	}, nil
end

local function addDependencies(needed: { [StepName]: boolean }, stage: StageName)
	needed[stage] = true

	if stage == "unit" or stage == "build" then
		needed.wally = true
	elseif stage == "analyze" then
		needed.wally = true
		needed.sourcemap = true
		needed.package_types = true
		needed.lest_core = true
	elseif stage == "studio" then
		needed.wally = true
		needed.build = true
	end
end

function Verification.plan(selection: Selection): { StepName }
	local needed: { [StepName]: boolean } = {
		preflight = true,
	}

	for _, stage in selection.selectedStages do
		addDependencies(needed, stage)
	end

	if selection.fullGate then
		needed.wally = true
		needed.blink = true
		needed.sourcemap = true
		needed.package_types = true
	end

	local plan: { StepName } = {}
	for _, step in STEP_ORDER do
		if needed[step] then
			table.insert(plan, step)
		end
	end
	return plan
end

function Verification.newReport(selection: Selection, startedAt: string): Report
	local planned: { [StepName]: boolean } = {}
	for _, step in Verification.plan(selection) do
		planned[step] = true
	end

	local records: { StageRecord } = {}
	for _, step in STEP_ORDER do
		local record: StageRecord = {
			name = step,
			status = "not_run",
			durationMs = 0,
			reason = if planned[step] then "pending" else "unselected",
		}
		table.insert(records, record)
	end

	return {
		schemaVersion = 1,
		startedAt = startedAt,
		selectedStages = copyStages(selection.selectedStages),
		fullGate = selection.fullGate,
		outcome = "pending",
		stages = records,
		errors = {},
	}
end

local function findRecord(report: Report, name: StepName): StageRecord
	for _, record in report.stages do
		if record.name == name then
			return record
		end
	end
	error(string.format("missing verification report record: %s", name))
end

local function blockRemaining(report: Report, plan: { StepName }, failedStep: StepName)
	local reachedFailure = false
	for _, step in plan do
		if step == failedStep then
			reachedFailure = true
		elseif reachedFailure then
			local record = findRecord(report, step)
			record.reason = "blocked_by:" .. failedStep
		end
	end
end

local function blockPending(report: Report, reason: string)
	for _, record in report.stages do
		if record.status == "not_run" and record.reason == "pending" then
			record.reason = reason
		end
	end
end

local function addError(report: Report, kind: ReportErrorKind, message: string)
	table.insert(report.errors, {
		kind = kind,
		message = message,
	})
	report.outcome = "failed"
end

function Verification.execute(
	report: Report,
	plan: { StepName },
	runner: Runner,
	clock: Clock,
	onUpdate: OnUpdate?
): Report
	for _, step in plan do
		local record = findRecord(report, step)
		local started = clock()
		local callOk, resultOrError = pcall(runner, step)
		record.durationMs = math.max(0, math.floor((clock() - started) * 1000 + 0.5))

		local result: StepResult
		if callOk then
			result = resultOrError :: StepResult
		else
			result = {
				ok = false,
				exitCode = 1,
				reason = tostring(resultOrError),
			}
		end

		if result.ok then
			record.status = "passed"
			record.reason = nil
		else
			record.status = "failed"
			record.exitCode = if result.exitCode ~= nil and result.exitCode ~= 0 then result.exitCode else 1
			record.reason = result.reason or "command failed"
			report.outcome = "failed"
			blockRemaining(report, plan, step)
			if onUpdate ~= nil then
				onUpdate(report)
			end
			return report
		end

		if onUpdate ~= nil then
			onUpdate(report)
		end
	end

	report.outcome = "passed"
	return report
end

function Verification.orchestrate(
	report: Report,
	plan: { StepName },
	runner: Runner,
	clock: Clock,
	persist: Persist,
	cleanup: Cleanup
): OrchestrationResult
	local durableReport = false
	local initialWriteOk, initialWriteError = pcall(persist, report)
	if initialWriteOk then
		durableReport = true

		local writingStageUpdate = false
		local orchestrationOk, orchestrationError = pcall(function()
			Verification.execute(report, plan, runner, clock, function(updatedReport)
				writingStageUpdate = true
				persist(updatedReport)
				durableReport = true
				writingStageUpdate = false
			end)
		end)
		if not orchestrationOk then
			local kind: ReportErrorKind = if writingStageUpdate then "report" else "orchestration"
			addError(report, kind, tostring(orchestrationError))
			blockPending(report, "blocked_by:" .. kind)
		end
	else
		addError(report, "report", "initial report write failed: " .. tostring(initialWriteError))
		blockPending(report, "blocked_by:report")
	end

	local cleanupOk, cleanupError = pcall(cleanup)
	if not cleanupOk then
		addError(report, "cleanup", tostring(cleanupError))
		blockPending(report, "blocked_by:cleanup")
	end

	local finalWriteOk, finalWriteError = pcall(persist, report)
	if finalWriteOk then
		durableReport = true
	else
		addError(report, "report", "final report write failed: " .. tostring(finalWriteError))
	end

	return {
		ok = report.outcome == "passed" and #report.errors == 0 and finalWriteOk,
		durableReport = durableReport,
		finalReportPersisted = finalWriteOk,
	}
end

function Verification.resultMessage(report: Report): string
	if report.outcome == "failed" then
		for _, record in report.stages do
			if record.status == "failed" then
				return string.format("[verify] FAILED: %s", record.name)
			end
		end
		return "[verify] FAILED"
	elseif report.outcome == "passed" and report.fullGate then
		return "[verify] PASS"
	elseif report.outcome == "passed" then
		return "[verify] SELECTED STAGES PASS — full gate not run"
	end
	return "[verify] INCOMPLETE"
end

return Verification
