--!strict
--# selene: allow(incorrect_standard_library_use)

local Guard = require("../../scripts/studio-diagnostic-guard")

local function hex(value: string): string
	local encoded = ""
	for index = 1, #value do
		encoded ..= string.format("%02X", string.byte(value, index))
	end
	return encoded
end

local function event(kind: string, name: string): string
	return string.format(
		'{"kind":"%s","path":["diagnostic guard"],"name":"%s","suite":"studio","backend":"studio"}',
		kind,
		name
	)
end

local function runEnd(): string
	return '{"kind":"run_end","passed":1,"failed":0,"skipped":0,"suite":"studio","backend":"studio"}'
end

local function analyze(lines: { string }): Guard.Analysis
	return Guard.analyze(table.concat(lines, "\n") .. "\n")
end

local warning = "forced generic Studio warning"
local warningAnalysis = analyze({
	event("test_start", "warning case"),
	Guard.CAPTURE_START,
	warning,
	Guard.DIAGNOSTIC .. "0|MessageWarning|" .. hex(warning),
	Guard.CAPTURE_END,
	event("test_pass", "warning case"),
	runEnd(),
})
assert(#warningAnalysis.problems == 1, "forced generic warning did not make a green Lest stream fail")
assert(warningAnalysis.problems[1].kind == "unexpected_diagnostic", "warning failure lost its classification")
assert(string.find(warningAnalysis.problems[1].context, "warning case", 1, true) ~= nil, "warning lost spec context")
assert(warningAnalysis.problems[1].message == warning, "warning text was not preserved")

local errorMessage = "forced generic Studio error after assertions"
local errorAnalysis = analyze({
	event("test_start", "error case"),
	Guard.CAPTURE_START,
	errorMessage,
	Guard.DIAGNOSTIC .. "0|MessageError|" .. hex(errorMessage),
	Guard.CAPTURE_END,
	event("test_pass", "error case"),
	runEnd(),
})
assert(#errorAnalysis.problems == 1, "forced generic error did not make a green Lest stream fail")
assert(errorAnalysis.problems[1].kind == "unexpected_diagnostic", "error failure lost its classification")
assert(errorAnalysis.problems[1].message == errorMessage, "error text was not preserved")

local expected = "exact expected local diagnostic"
local expectedAnalysis = analyze({
	event("test_start", "exact expectation case"),
	Guard.CAPTURE_START,
	expected,
	Guard.DIAGNOSTIC .. "1|MessageWarning|" .. hex(expected),
	Guard.CAPTURE_END,
	event("test_pass", "exact expectation case"),
	runEnd(),
})
assert(#expectedAnalysis.problems == 0, "an exact test-local diagnostic expectation was rejected")

local expectedError = "expected error first line\n    expected error detail"
local expectedErrorAnalysis = analyze({
	event("test_start", "expected error rendering case"),
	Guard.CAPTURE_START,
	"expected error first line",
	"    expected error detail  -  Edit",
	"Stack Begin",
	"Stack End",
	Guard.DIAGNOSTIC .. "1|MessageError|" .. hex(expectedError),
	Guard.CAPTURE_END,
	event("test_pass", "expected error rendering case"),
})
assert(#expectedErrorAnalysis.problems == 0, "exact expected Studio error rendering was rejected")

local duplicateExpectedAnalysis = analyze({
	event("test_start", "duplicate expectation case"),
	Guard.CAPTURE_START,
	expected,
	expected,
	Guard.DIAGNOSTIC .. "1|MessageWarning|" .. hex(expected),
	Guard.DIAGNOSTIC .. "1|MessageWarning|" .. hex(expected),
	Guard.CAPTURE_END,
	event("test_pass", "duplicate expectation case"),
})
assert(#duplicateExpectedAnalysis.problems == 0, "exact diagnostic multiplicity was not reconciled")

local missingAnalysis = analyze({
	event("test_start", "missing expectation case"),
	Guard.CAPTURE_START,
	Guard.MISSING_EXPECTED .. "MessageWarning|" .. hex(expected),
	Guard.CAPTURE_END,
	event("test_pass", "missing expectation case"),
	runEnd(),
})
assert(#missingAnalysis.problems == 1, "a missing exact diagnostic expectation did not fail")
assert(missingAnalysis.problems[1].kind == "missing_expected_diagnostic", "missing expectation was misclassified")

local unmatchedCaptureAnalysis = analyze({
	event("test_start", "unmatched raw capture case"),
	Guard.CAPTURE_START,
	"raw warning missed by the structured listener",
	Guard.CAPTURE_END,
	event("test_pass", "unmatched raw capture case"),
})
assert(#unmatchedCaptureAnalysis.problems == 1, "unmatched raw output disappeared inside a capture window")
assert(unmatchedCaptureAnalysis.problems[1].kind == "unexpected_output", "unmatched capture output was misclassified")

local embeddedMarkerAnalysis = analyze({
	event("test_start", "embedded marker case"),
	"prefix " .. Guard.CAPTURE_START .. " suffix",
	Guard.CAPTURE_END,
	event("test_pass", "embedded marker case"),
})
assert(#embeddedMarkerAnalysis.problems == 2, "embedded marker text was accepted as a protocol frame")
assert(embeddedMarkerAnalysis.problems[1].kind == "unexpected_output", "embedded marker text was not retained")
assert(embeddedMarkerAnalysis.problems[2].kind == "protocol", "unframed end marker did not expose protocol state")

local teardownWarning = "Script that implemented this callback has been destroyed while calling callback"
local teardownAnalysis = analyze({
	event("test_start", "teardown case"),
	event("test_pass", "teardown case"),
	runEnd(),
	teardownWarning,
})
assert(#teardownAnalysis.problems == 1, "post-run callback warning remained false-green")
assert(teardownAnalysis.problems[1].kind == "unexpected_output", "post-run warning was misclassified")
assert(
	string.find(teardownAnalysis.problems[1].context, "teardown case", 1, true) ~= nil,
	"teardown warning lost the last spec context"
)
assert(teardownAnalysis.problems[1].message == teardownWarning, "teardown warning text was not preserved")

local verdict = Guard.evaluate({
	ok = true,
	exitcode = 0,
	stdout = table.concat({
		event("test_start", "warning case"),
		warning,
		event("test_pass", "warning case"),
		runEnd(),
	}, "\n"),
	stderr = "",
})
assert(not verdict.ok and verdict.exitCode ~= 0, "green Lest exit code overrode a diagnostic guard failure")

local stderrVerdict = Guard.evaluate({
	ok = true,
	exitcode = 0,
	stdout = runEnd(),
	stderr = "Launching Roblox Studio (budget 255s)…\nWarning: forced backend warning\n",
})
assert(not stderrVerdict.ok, "unexpected Lest stderr remained false-green")
assert(#stderrVerdict.problems == 1, "known launch progress was not distinguished from unexpected stderr")
assert(stderrVerdict.problems[1].kind == "unexpected_stderr", "unexpected stderr was misclassified")
assert(stderrVerdict.problems[1].message == "Warning: forced backend warning", "stderr evidence was not preserved")

local postDoneAnalysis = analyze({
	event("test_start", "post-done case"),
	event("test_pass", "post-done case"),
	runEnd(),
	"generic warning decoded after the Studio done marker",
})
assert(#postDoneAnalysis.problems == 1, "output decoded after Studio done remained false-green")
assert(postDoneAnalysis.problems[1].kind == "unexpected_output", "post-done output was misclassified")
assert(
	string.find(postDoneAnalysis.problems[1].context, "post-done case", 1, true) ~= nil,
	"post-done context was lost"
)

print("[studio-diagnostics] Offline warning, error, exact-expectation, and teardown regressions passed")
