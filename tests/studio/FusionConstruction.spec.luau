--!strict
--# selene: allow(incorrect_standard_library_use)

local Lest = require("@lest")
local describe, it, expect = Lest.describe, Lest.it, Lest.expect

local Fusion = require("../../Packages/Fusion")
local Button = require("../../src/client/UI/Components/Button")
local DiagnosticCapture = require("./DiagnosticCapture")

type Scope = Fusion.Scope<typeof(Fusion)>

local function assertCleanResult(result: DiagnosticCapture.Result, allowedPatterns: { string }?)
	expect(result.bodyError).toBe(nil)
	expect(result.cleanupError).toBe(nil)
	local unexpected = DiagnosticCapture.unexpected(result.diagnostics, allowedPatterns)
	assert(#unexpected == 0, table.concat(unexpected, "\n\n"))
end

local function traceError(problem: unknown): string
	return debug.traceback(tostring(problem), 2)
end

local function withHolder(runCase: (Folder) -> ())
	local holder = Instance.new("Folder")
	local caseError: string? = nil
	local caseOk = xpcall(function()
		runCase(holder)
	end, function(problem)
		caseError = traceError(problem)
		return caseError
	end)

	local destroyError: string? = nil
	local destroyOk = xpcall(function()
		holder:Destroy()
	end, function(problem)
		destroyError = traceError(problem)
		return destroyError
	end)

	if not caseOk then
		local message = caseError or "construction case failed"
		if not destroyOk then
			message ..= "\nHolder destruction also failed:\n" .. (destroyError or "unknown destruction failure")
		end
		error(message, 0)
	elseif not destroyOk then
		error(destroyError or "holder destruction failed", 0)
	end
end

describe("Fusion construction", function()
	it("mounts and cleans the real Button without diagnostics", function()
		withHolder(function(holder)
			local scope: Scope? = nil
			local button: TextButton? = nil

			local result = DiagnosticCapture.run(function()
				local currentScope = Fusion.scoped(Fusion)
				scope = currentScope
				local screenGui = currentScope:New("ScreenGui")({
					Name = "FusionConstructionTest",
					Parent = holder,
				})
				button = Button(currentScope, {
					Parent = screenGui,
				})

				local currentButton = assert(button, "Button construction returned nil")
				assert(currentButton:IsA("TextButton"), "Button must construct a TextButton")
				assert(currentButton.Text == "Click me", "Button label changed")
				assert(currentButton.AutoButtonColor == false, "Button must disable Roblox's automatic colors")
				assert(currentButton:FindFirstChildOfClass("UICorner") ~= nil, "Button is missing its UICorner")
				assert(currentButton:FindFirstChildOfClass("UIStroke") ~= nil, "Button is missing its UIStroke")
				assert(currentButton:FindFirstChildOfClass("UIScale") ~= nil, "Button is missing its UIScale")
			end, function()
				if scope ~= nil then
					Fusion.doCleanup(scope)
				end
			end)

			assertCleanResult(result, nil)
			expect(#holder:GetChildren()).toBe(0)
			if button ~= nil then
				expect(button.Parent).toBe(nil)
			end
		end)
	end)

	it("detects a non-fatal invalid Fusion property", function()
		withHolder(function(holder)
			local scope: Scope? = nil
			local badButton: TextButton? = nil

			local result = DiagnosticCapture.run(function()
				local currentScope = Fusion.scoped(Fusion)
				scope = currentScope
				badButton = currentScope:New("TextButton")({
					Name = "InvalidPropertyFixture",
					Parent = holder,
					AutomaticButtonColor = false,
				}) :: TextButton
				assert(
					badButton ~= nil and badButton:IsA("TextButton"),
					"invalid-property fixture must still return a TextButton"
				)
			end, function()
				if scope ~= nil then
					Fusion.doCleanup(scope)
				end
			end)

			assertCleanResult(result, { "cannotAssignProperty" })
			expect(DiagnosticCapture.contains(result.diagnostics, "cannotAssignProperty")).toBe(true)
			expect(#holder:GetChildren()).toBe(0)
		end)
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
			error("destroyed holder was unexpectedly reparentable")
		end
	end)
end)

return nil
