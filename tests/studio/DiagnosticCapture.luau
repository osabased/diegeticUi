--!strict

local LogService = game:GetService("LogService")

local DiagnosticCapture = {}

local CAPTURE_START = "@@DIEGETIC_UI_DIAGNOSTIC_CAPTURE_START@@"
local CAPTURE_END = "@@DIEGETIC_UI_DIAGNOSTIC_CAPTURE_END@@"
local DIAGNOSTIC = "@@DIEGETIC_UI_DIAGNOSTIC@@"
local MISSING_EXPECTED = "@@DIEGETIC_UI_MISSING_EXPECTED_DIAGNOSTIC@@"

export type Diagnostic = {
	message: string,
	messageType: Enum.MessageType,
}

export type ExpectedDiagnostic = Diagnostic

export type Result = {
	bodyError: string?,
	cleanupError: string?,
	diagnostics: { Diagnostic },
}

local function traceError(problem: unknown): string
	return debug.traceback(tostring(problem), 2)
end

local function isGuarded(diagnostic: Diagnostic): boolean
	return diagnostic.messageType == Enum.MessageType.MessageWarning
		or diagnostic.messageType == Enum.MessageType.MessageError
end

local function encodeHex(value: string): string
	local encoded = ""
	for index = 1, #value do
		encoded ..= string.format("%02X", string.byte(value, index))
	end
	return encoded
end

local function reconcile(
	diagnostics: { Diagnostic },
	expectedDiagnostics: { ExpectedDiagnostic }?
): ({ Diagnostic }, { ExpectedDiagnostic }, { [number]: boolean })
	local expected: { ExpectedDiagnostic } = if expectedDiagnostics ~= nil then expectedDiagnostics else {}
	local usedExpected: { [number]: boolean } = {}
	local matchedActual: { [number]: boolean } = {}
	local unexpected: { Diagnostic } = {}

	for actualIndex, diagnostic in diagnostics do
		if not isGuarded(diagnostic) then
			continue
		end

		local matched = false
		for expectedIndex, expectedDiagnostic in expected do
			if
				not usedExpected[expectedIndex]
				and diagnostic.messageType == expectedDiagnostic.messageType
				and diagnostic.message == expectedDiagnostic.message
			then
				usedExpected[expectedIndex] = true
				matchedActual[actualIndex] = true
				matched = true
				break
			end
		end
		if not matched then
			table.insert(unexpected, diagnostic)
		end
	end

	local missing: { ExpectedDiagnostic } = {}
	for expectedIndex, expectedDiagnostic in expected do
		if not usedExpected[expectedIndex] then
			table.insert(missing, expectedDiagnostic)
		end
	end
	return unexpected, missing, matchedActual
end

function DiagnosticCapture.run(body: () -> (), cleanup: () -> (), expectedDiagnostics: { ExpectedDiagnostic }?): Result
	local diagnostics: { Diagnostic } = {}
	local connection = LogService.MessageOut:Connect(function(message, messageType)
		table.insert(diagnostics, {
			message = message,
			messageType = messageType,
		})
	end)
	print(CAPTURE_START)

	local bodyError: string? = nil
	local bodyOk = xpcall(body, function(problem)
		bodyError = traceError(problem)
		return bodyError
	end)
	local cleanupError: string? = nil
	local cleanupOk = xpcall(cleanup, function(problem)
		cleanupError = traceError(problem)
		return cleanupError
	end)
	local flushError: string? = nil
	local flushOk = xpcall(function()
		-- Fusion reports non-fatal construction errors on spawned tasks. Give the
		-- edit-mode scheduler a bounded opportunity to deliver those messages.
		for _ = 1, 3 do
			task.wait()
		end
	end, function(problem)
		flushError = traceError(problem)
		return flushError
	end)
	connection:Disconnect()

	local _, missing, matchedActual = reconcile(diagnostics, expectedDiagnostics)
	for actualIndex, diagnostic in diagnostics do
		if isGuarded(diagnostic) then
			print(
				DIAGNOSTIC
					.. (if matchedActual[actualIndex] then "1" else "0")
					.. "|"
					.. diagnostic.messageType.Name
					.. "|"
					.. encodeHex(diagnostic.message)
			)
		end
	end
	for _, expectedDiagnostic in missing do
		print(MISSING_EXPECTED .. expectedDiagnostic.messageType.Name .. "|" .. encodeHex(expectedDiagnostic.message))
	end
	print(CAPTURE_END)

	bodyError = if bodyOk then nil else bodyError
	cleanupError = if cleanupOk then nil else cleanupError
	if not flushOk then
		cleanupError = if cleanupError == nil
			then flushError
			else cleanupError .. "\n" .. (flushError or "scheduler flush failed")
	end

	return {
		bodyError = bodyError,
		cleanupError = cleanupError,
		diagnostics = diagnostics,
	}
end

function DiagnosticCapture.contains(diagnostics: { Diagnostic }, pattern: string): boolean
	for _, diagnostic in diagnostics do
		if string.find(diagnostic.message, pattern, 1, true) ~= nil then
			return true
		end
	end
	return false
end

function DiagnosticCapture.unexpected(
	diagnostics: { Diagnostic },
	expectedDiagnostics: { ExpectedDiagnostic }?
): { string }
	local unexpected: { string } = {}
	local actual, missing = reconcile(diagnostics, expectedDiagnostics)
	for _, diagnostic in actual do
		table.insert(unexpected, string.format("Unexpected %s:\n%s", diagnostic.messageType.Name, diagnostic.message))
	end
	for _, diagnostic in missing do
		table.insert(
			unexpected,
			string.format("Missing expected %s:\n%s", diagnostic.messageType.Name, diagnostic.message)
		)
	end
	return unexpected
end

return DiagnosticCapture
