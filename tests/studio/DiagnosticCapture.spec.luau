--!strict
--# selene: allow(incorrect_standard_library_use)

local Lest = require("@lest")
local describe, it = Lest.describe, Lest.it

local DiagnosticCapture = require("./DiagnosticCapture")

local function contains(problems: { string }, expected: string): boolean
	for _, problem in problems do
		if string.find(problem, expected, 1, true) ~= nil then
			return true
		end
	end
	return false
end

describe("Studio diagnostic capture", function()
	it("accepts one exact local warning emitted during owned cleanup", function()
		local expected: DiagnosticCapture.ExpectedDiagnostic = {
			message = "forced expected cleanup warning",
			messageType = Enum.MessageType.MessageWarning,
		}
		local result = DiagnosticCapture.run(function() end, function()
			warn(expected.message)
		end, { expected })

		assert(result.bodyError == nil and result.cleanupError == nil, "expected warning disrupted body or cleanup")
		assert(#DiagnosticCapture.unexpected(result.diagnostics, { expected }) == 0, "exact warning was rejected")
		assert(DiagnosticCapture.contains(result.diagnostics, expected.message), "cleanup warning was not captured")
	end)

	it("rejects generic warnings and errors unless type and text match exactly", function()
		local diagnostics: { DiagnosticCapture.Diagnostic } = {
			{
				message = "forced generic warning",
				messageType = Enum.MessageType.MessageWarning,
			},
			{
				message = "forced generic error",
				messageType = Enum.MessageType.MessageError,
			},
		}
		local mismatched: DiagnosticCapture.ExpectedDiagnostic = {
			message = "forced generic warning with changed text",
			messageType = Enum.MessageType.MessageWarning,
		}

		local problems = DiagnosticCapture.unexpected(diagnostics, { mismatched })
		assert(#problems == 3, "generic diagnostics or the missing exact expectation were accepted")
		assert(contains(problems, "forced generic warning"), "generic warning text was lost")
		assert(contains(problems, "forced generic error"), "generic error text was lost")
		assert(contains(problems, "Missing expected MessageWarning"), "missing exact expectation was lost")
	end)
end)
