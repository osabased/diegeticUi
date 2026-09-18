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
				assert(currentButton:FindFirstChild("Label") ~= nil, "Button is missing its visible label")
				assert(currentButton:FindFirstChild("ActionBadge") ~= nil, "Button is missing its action badge")
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

	it("supports custom content, variants, disabled, and loading states", function()
		withHolder(function(holder)
			local scope: Scope? = nil

			local result = DiagnosticCapture.run(function()
				local currentScope = Fusion.scoped(Fusion)
				scope = currentScope
				local screenGui = currentScope:New("ScreenGui")({
					Name = "ButtonFeatureTest",
					Parent = holder,
				})
				local dangerButton = Button(currentScope, {
					Parent = screenGui,
					Text = "Delete",
					IconText = "!",
					Variant = "danger",
					Disabled = true,
				})
				local loadingButton = Button(currentScope, {
					Parent = screenGui,
					Text = "Publish",
					Loading = true,
				})
				local holdButton = Button(currentScope, {
					Parent = screenGui,
					Text = "Hold",
					HoldDuration = 0.8,
					CooldownDuration = 2,
				})

				assert(dangerButton.Text == "Delete", "custom label was not applied")
				assert(dangerButton.Active == false, "disabled button must not be active")
				assert(dangerButton.Selectable == false, "disabled button must not be selectable")
				local dangerLabel = dangerButton:FindFirstChild("Label")
				assert(dangerLabel ~= nil and dangerLabel:IsA("TextLabel"), "disabled button label is missing")
				assert(dangerLabel.Text == "Delete", "visible custom label was not applied")
				local dangerBadge = dangerButton:FindFirstChild("ActionBadge")
				assert(dangerBadge ~= nil and dangerBadge:IsA("Frame"), "custom badge is missing")
				local dangerIcon = dangerBadge:FindFirstChildOfClass("TextLabel")
				assert(dangerIcon ~= nil and dangerIcon.Text == "!", "custom badge icon was not applied")
				local dangerGradient = dangerButton:FindFirstChildOfClass("UIGradient")
				assert(dangerGradient ~= nil, "danger variant gradient is missing")
				assert(
					dangerGradient.Color.Keypoints[1].Value == Color3.fromRGB(255, 165, 210),
					"danger variant palette was not applied"
				)

				assert(loadingButton.Active == false, "loading button must not be active")
				local loadingLabel = loadingButton:FindFirstChild("Label")
				assert(loadingLabel ~= nil and loadingLabel:IsA("TextLabel"), "loading button label is missing")
				assert(loadingLabel.Text == "Loading...", "loading label was not applied")
				local holdTrack = holdButton:FindFirstChild("HoldTrack")
				assert(holdTrack ~= nil and holdTrack:IsA("Frame"), "hold progress track is missing")
				assert(holdTrack:FindFirstChild("Fill") ~= nil, "hold progress fill is missing")
			end, function()
				if scope ~= nil then
					Fusion.doCleanup(scope)
				end
			end)

			assertCleanResult(result, nil)
			expect(#holder:GetChildren()).toBe(0)
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
