--!strict
--# selene: allow(incorrect_standard_library_use)

local json = require("@std/json")

local StudioDiagnosticGuard = {}

StudioDiagnosticGuard.CAPTURE_START = "@@DIEGETIC_UI_DIAGNOSTIC_CAPTURE_START@@"
StudioDiagnosticGuard.CAPTURE_END = "@@DIEGETIC_UI_DIAGNOSTIC_CAPTURE_END@@"
StudioDiagnosticGuard.DIAGNOSTIC = "@@DIEGETIC_UI_DIAGNOSTIC@@"
StudioDiagnosticGuard.MISSING_EXPECTED = "@@DIEGETIC_UI_MISSING_EXPECTED_DIAGNOSTIC@@"

export type ProblemKind =
	"unexpected_output"
	| "unexpected_stderr"
	| "unexpected_diagnostic"
	| "missing_expected_diagnostic"
	| "protocol"

export type Problem = {
	kind: ProblemKind,
	context: string,
	message: string,
}

export type Analysis = {
	problems: { Problem },
}

export type ProcessResult = {
	ok: boolean,
	exitcode: number,
	stdout: string,
	stderr: string,
}

export type Verdict = {
	ok: boolean,
	exitCode: number,
	problems: { Problem },
}

local JSON_EVENT_KINDS: { [string]: boolean } = {
	run_start = true,
	suite_start = true,
	suite_end = true,
	test_start = true,
	test_pass = true,
	test_fail = true,
	test_skip = true,
	run_end = true,
	summary = true,
}

local function isNumberField(object: json.Object, field: string): boolean
	return type(object[field]) == "number"
end

local function isStringField(object: json.Object, field: string): boolean
	return type(object[field]) == "string"
end

local function hasLestEventShape(object: json.Object, kind: string): boolean
	if kind == "run_start" then
		return isNumberField(object, "specCount")
			and isNumberField(object, "protocolVersion")
			and isStringField(object, "suite")
			and isStringField(object, "backend")
	elseif kind == "suite_start" or kind == "suite_end" then
		return type(object.path) == "table" and isStringField(object, "suite") and isStringField(object, "backend")
	elseif kind == "test_start" or kind == "test_pass" or kind == "test_fail" or kind == "test_skip" then
		return type(object.path) == "table"
			and isStringField(object, "name")
			and isStringField(object, "suite")
			and isStringField(object, "backend")
	elseif kind == "run_end" then
		return isNumberField(object, "passed")
			and isNumberField(object, "failed")
			and isNumberField(object, "skipped")
			and isStringField(object, "suite")
			and isStringField(object, "backend")
	elseif kind == "summary" then
		return isNumberField(object, "passed")
			and isNumberField(object, "failed")
			and isNumberField(object, "skipped")
			and isNumberField(object, "durationMs")
	end
	return false
end

local function decodeHex(encoded: string): string?
	if #encoded % 2 ~= 0 or string.find(encoded, "[^0-9A-F]", 1) ~= nil then
		return nil
	end

	local decoded = ""
	for index = 1, #encoded, 2 do
		local byte = tonumber(string.sub(encoded, index, index + 1), 16)
		if byte == nil then
			return nil
		end
		decoded ..= string.char(byte)
	end
	return decoded
end

local function protocolEvent(line: string): (string?, string?)
	local ok, value = pcall(json.deserialize, line)
	if not ok or type(value) ~= "table" then
		return nil, nil
	end

	local object = value :: json.Object
	local rawKind = object.kind
	if type(rawKind) ~= "string" or not JSON_EVENT_KINDS[rawKind] or not hasLestEventShape(object, rawKind) then
		return nil, nil
	end

	local context: string? = nil
	if rawKind == "test_start" then
		local rawName = object.name
		if type(rawName) == "string" then
			local rawSuite = object.suite
			context = if type(rawSuite) == "string"
				then string.format("suite %q, test %q", rawSuite, rawName)
				else string.format("test %q", rawName)
		end
	end
	return rawKind, context
end

local function addProblem(problems: { Problem }, kind: ProblemKind, context: string, message: string)
	local problem: Problem = {
		kind = kind,
		context = context,
		message = message,
	}
	table.insert(problems, problem)
end

local function addProtocolProblem(problems: { Problem }, context: string, message: string)
	addProblem(problems, "protocol", context, message)
end

local function exactMarkerPayload(line: string, marker: string): string?
	if string.sub(line, 1, #marker) ~= marker then
		return nil
	end
	return string.sub(line, #marker + 1)
end

local function splitMessageLines(message: string): { string }
	local lines: { string } = {}
	for line in string.gmatch((string.gsub(message, "\r\n", "\n")) .. "\n", "([^\n]*)\n") do
		table.insert(lines, line)
	end
	return lines
end

type StructuredDiagnostic = {
	message: string,
	messageType: string,
}

local function consumeExactMessage(
	rawLines: { string },
	consumedRawLines: { [number]: boolean },
	diagnostic: StructuredDiagnostic
): boolean
	local message = diagnostic.message
	local messageLines = splitMessageLines(message)
	for startIndex = 1, #rawLines - #messageLines + 1 do
		local matches = true
		for offset, messageLine in messageLines do
			local rawIndex = startIndex + offset - 1
			local actualLine = rawLines[rawIndex]
			-- Studio appends this source label outside LogService's exact MessageError text.
			local isFinalStudioErrorLine = diagnostic.messageType == "MessageError"
				and offset == #messageLines
				and actualLine == messageLine .. "  -  Edit"
			if consumedRawLines[rawIndex] or (actualLine ~= messageLine and not isFinalStudioErrorLine) then
				matches = false
				break
			end
		end
		if matches then
			local consumedThrough = startIndex + #messageLines - 1
			for offset = 1, #messageLines do
				consumedRawLines[startIndex + offset - 1] = true
			end
			if
				diagnostic.messageType == "MessageError"
				and not consumedRawLines[consumedThrough + 1]
				and rawLines[consumedThrough + 1] == "Stack Begin"
				and not consumedRawLines[consumedThrough + 2]
				and rawLines[consumedThrough + 2] == "Stack End"
			then
				-- The pinned backend renders an empty stack as two adjacent framing lines.
				consumedRawLines[consumedThrough + 1] = true
				consumedRawLines[consumedThrough + 2] = true
			end
			return true
		end
	end
	return false
end

local function reconcileCapture(
	problems: { Problem },
	context: string,
	rawLines: { string },
	diagnostics: { StructuredDiagnostic }
)
	local consumedRawLines: { [number]: boolean } = {}
	for _, diagnostic in diagnostics do
		if not consumeExactMessage(rawLines, consumedRawLines, diagnostic) then
			addProtocolProblem(
				problems,
				context,
				"structured diagnostic had no exact raw output match: " .. diagnostic.message
			)
		end
	end
	for index, rawLine in rawLines do
		if not consumedRawLines[index] then
			addProblem(problems, "unexpected_output", context, rawLine)
		end
	end
end

function StudioDiagnosticGuard.analyze(stdout: string): Analysis
	local problems: { Problem } = {}
	local captureDepth = 0
	local captureContext = "Studio suite before the first test"
	local captureRawLines: { string } = {}
	local captureDiagnostics: { StructuredDiagnostic } = {}
	local activeContext: string? = nil
	local lastContext = "Studio suite before the first test"

	for line in string.gmatch(stdout .. "\n", "([^\r\n]*)\r?\n") do
		if line == "" and captureDepth == 0 then
			continue
		end

		if line == StudioDiagnosticGuard.CAPTURE_START then
			if captureDepth ~= 0 then
				addProtocolProblem(
					problems,
					activeContext or lastContext,
					"diagnostic capture markers may not be nested"
				)
			end
			captureDepth += 1
			if captureDepth == 1 then
				captureContext = activeContext or lastContext
				captureRawLines = {}
				captureDiagnostics = {}
			end
			continue
		end
		if line == StudioDiagnosticGuard.CAPTURE_END then
			if captureDepth == 0 then
				addProtocolProblem(
					problems,
					activeContext or lastContext,
					"diagnostic capture ended without a start marker"
				)
			else
				captureDepth -= 1
				if captureDepth == 0 then
					reconcileCapture(problems, captureContext, captureRawLines, captureDiagnostics)
				end
			end
			continue
		end

		local context = activeContext or lastContext
		local diagnosticPayload = exactMarkerPayload(line, StudioDiagnosticGuard.DIAGNOSTIC)
		if diagnosticPayload ~= nil then
			local expectedFlag, messageType, encoded = string.match(diagnosticPayload, "^([01])|([%w]+)|([0-9A-F]*)$")
			local message = if encoded == nil then nil else decodeHex(encoded)
			if captureDepth == 0 or expectedFlag == nil or messageType == nil or message == nil then
				addProtocolProblem(problems, context, "malformed or out-of-window diagnostic marker: " .. line)
			else
				table.insert(captureDiagnostics, { message = message, messageType = messageType })
				if expectedFlag == "0" then
					addProblem(problems, "unexpected_diagnostic", context, message)
				end
			end
			continue
		end

		local missingPayload = exactMarkerPayload(line, StudioDiagnosticGuard.MISSING_EXPECTED)
		if missingPayload ~= nil then
			local messageType, encoded = string.match(missingPayload, "^([%w]+)|([0-9A-F]*)$")
			local message = if encoded == nil then nil else decodeHex(encoded)
			if captureDepth == 0 or messageType == nil or message == nil then
				addProtocolProblem(problems, context, "malformed or out-of-window missing-expectation marker: " .. line)
			else
				addProblem(problems, "missing_expected_diagnostic", context, message)
			end
			continue
		end

		local kind, startedContext = protocolEvent(line)
		if kind ~= nil then
			if kind == "test_start" then
				activeContext = startedContext or "unnamed Studio test"
				lastContext = activeContext
			elseif kind == "test_pass" or kind == "test_fail" or kind == "test_skip" then
				activeContext = nil
			end
			continue
		end

		if captureDepth == 0 then
			addProblem(problems, "unexpected_output", context, line)
		else
			table.insert(captureRawLines, line)
		end
	end

	if captureDepth ~= 0 then
		addProtocolProblem(problems, activeContext or lastContext, "diagnostic capture did not emit its end marker")
	end

	return { problems = problems }
end

function StudioDiagnosticGuard.analyzeStderr(stderr: string): Analysis
	local problems: { Problem } = {}
	for line in string.gmatch(stderr .. "\n", "([^\r\n]*)\r?\n") do
		if line == "" then
			continue
		end
		if string.match(line, "^Launching Roblox Studio %(budget %d+s%)…$") == nil then
			addProblem(problems, "unexpected_stderr", "Lest Studio backend", line)
		end
	end
	return { problems = problems }
end

function StudioDiagnosticGuard.evaluate(result: ProcessResult): Verdict
	local analysis = StudioDiagnosticGuard.analyze(result.stdout)
	local stderrAnalysis = StudioDiagnosticGuard.analyzeStderr(result.stderr)
	for _, problem in stderrAnalysis.problems do
		table.insert(analysis.problems, problem)
	end
	local ok = result.ok and #analysis.problems == 0
	local exitCode = if ok then 0 else if result.exitcode ~= 0 then result.exitcode else 1
	return {
		ok = ok,
		exitCode = exitCode,
		problems = analysis.problems,
	}
end

return StudioDiagnosticGuard
