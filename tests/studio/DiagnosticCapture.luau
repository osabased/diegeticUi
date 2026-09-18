--!strict

local LogService = game:GetService("LogService")

local DiagnosticCapture = {}

export type Diagnostic = {
	message: string,
	messageType: Enum.MessageType,
}

export type Result = {
	bodyError: string?,
	cleanupError: string?,
	diagnostics: { Diagnostic },
}

local function traceError(problem: unknown): string
	return debug.traceback(tostring(problem), 2)
end

function DiagnosticCapture.run(body: () -> (), cleanup: () -> ()): Result
	local diagnostics: { Diagnostic } = {}
	local connection = LogService.MessageOut:Connect(function(message, messageType)
		table.insert(diagnostics, {
			message = message,
			messageType = messageType,
		})
	end)

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

function DiagnosticCapture.unexpected(diagnostics: { Diagnostic }, allowedPatterns: { string }?): { string }
	local unexpected: { string } = {}
	local patterns: { string } = allowedPatterns or {}
	for _, diagnostic in diagnostics do
		local allowed = false
		for _, pattern in patterns do
			if string.find(diagnostic.message, pattern, 1, true) ~= nil then
				allowed = true
				break
			end
		end

		local isError = diagnostic.messageType == Enum.MessageType.MessageError
		local isFusionWarning = diagnostic.messageType == Enum.MessageType.MessageWarning
			and string.find(diagnostic.message, "[Fusion]", 1, true) ~= nil
		if not allowed and (isError or isFusionWarning) then
			table.insert(unexpected, diagnostic.message)
		end
	end
	return unexpected
end

return DiagnosticCapture
