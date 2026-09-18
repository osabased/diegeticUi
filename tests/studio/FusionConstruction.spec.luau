--!strict
--# selene: allow(incorrect_standard_library_use)

local Lest = require("@lest")
local describe, it, expect = Lest.describe, Lest.it, Lest.expect

local Fusion = require("../../Packages/Fusion")
local DiagnosticCapture = require("./DiagnosticCapture")

type Scope = Fusion.Scope<typeof(Fusion)>

local function assertCleanResult(result: DiagnosticCapture.Result, allowedPatterns: { string }?)
	local problems: { string } = {}
	if result.bodyError ~= nil then
		table.insert(problems, "Test body failed:\n" .. result.bodyError)
	end
	if result.cleanupError ~= nil then
		table.insert(problems, "Cleanup failed:\n" .. result.cleanupError)
	end
	for _, diagnostic in DiagnosticCapture.unexpected(result.diagnostics, allowedPatterns) do
		table.insert(problems, diagnostic)
	end
	assert(#problems == 0, table.concat(problems, "\n\n"))
end

local function traceError(problem: unknown): string
	return debug.traceback(tostring(problem), 2)
end

local function assertText(label: TextLabel, expected: string)
	assert(label.Text == expected, string.format("expected text %q, got %q", expected, label.Text))
end

local function withHolder(runCase: (Folder) -> ())
	local holder = Instance.new("Folder")
	local caseOk, caseError = xpcall(function()
		runCase(holder)
	end, traceError)
	local destroyOk, destroyError = xpcall(function()
		holder:Destroy()
	end, traceError)

	if not caseOk then
		local message = tostring(caseError)
		if not destroyOk then
			message ..= "\nHolder destruction also failed:\n" .. tostring(destroyError)
		end
		error(message, 0)
	elseif not destroyOk then
		error(tostring(destroyError), 0)
	end
end

describe("Fusion infrastructure", function()
	it("constructs, updates, and cleans scoped instances without diagnostics", function()
		withHolder(function(holder)
			local scope: Scope? = nil
			local label: TextLabel? = nil
			local result = DiagnosticCapture.run(function()
				local currentScope = Fusion.scoped(Fusion)
				scope = currentScope
				local text = currentScope:Value("Initial")
				local screenGui = currentScope:New("ScreenGui")({ Parent = holder })
				local currentLabel = currentScope:New("TextLabel")({
					Parent = screenGui,
					Text = text,
				})
				assert(currentLabel:IsA("TextLabel"), "Fusion constructed the wrong instance class")
				label = currentLabel
				assertText(currentLabel, "Initial")
				text:set("Updated")
				task.wait()
				assertText(currentLabel, "Updated")
			end, function()
				if scope ~= nil then
					Fusion.doCleanup(scope)
				end
			end)

			assertCleanResult(result, nil)
			assert(#holder:GetChildren() == 0, "scope cleanup left instances in the holder")
			local cleanedLabel = assert(label, "label was never constructed")
			assert(cleanedLabel.Parent == nil, "scope cleanup left the label parented")
		end)
	end)

	it("detects a non-fatal invalid Fusion property", function()
		withHolder(function(holder)
			local scope: Scope? = nil
			local result = DiagnosticCapture.run(function()
				local currentScope = Fusion.scoped(Fusion)
				scope = currentScope
				currentScope:New("TextLabel")({
					Parent = holder,
					InvalidSmokeTestProperty = true,
				})
			end, function()
				if scope ~= nil then
					Fusion.doCleanup(scope)
				end
			end)

			assertCleanResult(result, { "cannotAssignProperty" })
			assert(
				DiagnosticCapture.contains(result.diagnostics, "cannotAssignProperty"),
				"Fusion error was not captured"
			)
			local cleanOk, cleanError = pcall(function()
				assertCleanResult(result, nil)
				return true
			end)
			assert(not cleanOk, "unexpected Fusion diagnostics must fail the test")
			assert(
				string.find(tostring(cleanError), "cannotAssignProperty", 1, true) ~= nil,
				"Fusion diagnostic was lost"
			)
		end)
	end)

	it("preserves original body and cleanup failures in the reported error", function()
		local result = DiagnosticCapture.run(function()
			error("injected contract assertion failure")
		end, function()
			error("injected cleanup failure")
		end)
		local cleanOk, cleanError = pcall(function()
			assertCleanResult(result, nil)
			return true
		end)
		assert(not cleanOk, "captured failures must fail the test")
		local message = tostring(cleanError)
		assert(string.find(message, "injected contract assertion failure", 1, true) ~= nil, "body failure was lost")
		assert(string.find(message, "injected cleanup failure", 1, true) ~= nil, "cleanup failure was lost")
	end)

	it("destroys the holder when a construction assertion fails", function()
		local capturedHolder: Folder? = nil
		local caseOk, caseError = pcall(function()
			withHolder(function(holder)
				capturedHolder = holder
				error("injected construction assertion failure")
			end)
		end)
		expect(caseOk).toBe(false)
		assert(string.find(tostring(caseError), "injected construction assertion failure", 1, true) ~= nil)
		local holder = assert(capturedHolder, "withHolder did not expose its holder")
		local reparentOk = pcall(function()
			holder.Parent = workspace
		end)
		if reparentOk then
			holder:Destroy()
		end
		assert(not reparentOk, "holder was not destroyed after the assertion failed")
	end)
end)
