--!strict

local fs = require("@std/fs")
local json = require("@std/json")
local process = require("@lute/process")

local Verification = require("../../scripts/verification")

-- Exercise the actual CLI in an isolated checkout, without touching live source,
-- packages, Studio, or the parent run's reports. Only the format stage runs.
local fixtureParent = process.cwd() .. "/.verify/"
local root = fixtureParent .. string.format("diagnostics-test-%d-%d", os.time(), math.random(1, 1000000000))
assert(not fs.exists(root), "diagnostic fixture already exists")
fs.createDirectory(root .. "/scripts", { makeParents = true })

local ok, failure = pcall(function()
	fs.createDirectory(root .. "/src")
	fs.createDirectory(root .. "/tests")
	for _, file in { "verify.luau", "verification.luau", "dependencies.luau" } do
		fs.writeStringToFile(root .. "/scripts/" .. file, fs.readFileToString("scripts/" .. file))
	end
	fs.writeStringToFile(root .. "/rokit.toml", fs.readFileToString("rokit.toml"))
	fs.writeStringToFile(root .. "/default.project.json", "{}\n")
	local fixture = root .. "/src/DiagnosticFixture.luau"
	fs.writeStringToFile(fixture, "--!strict\nlocal diagnostic_fixture = \n")

	local function run(): (process.ProcessResult, string, Verification.Report)
		local result = process.run({ process.execPath(), "run", "scripts/verify.luau", "--stage", "format" }, {
			cwd = root,
		})
		local output = result.stdout .. result.stderr
		local relativePath = assert(string.match(output, "%[verify%] report: ([^\r\n]+)"), output)
		local path = root .. "/" .. relativePath
		local report = (json.deserialize(fs.readFileToString(path)) :: unknown) :: Verification.Report
		return result, path, report
	end

	local failedResult, failedPath, failedReport = run()
	assert(not failedResult.ok and failedReport.outcome == "failed", "malformed source unexpectedly passed")
	assert(not failedReport.fullGate, "focused failure claimed a full gate")
	local format: Verification.StageRecord? = nil
	for _, stage in failedReport.stages do
		if stage.name == "format" then
			format = stage
		end
	end
	local failedStage = assert(format, "report omitted the format stage")
	assert(failedStage.status == "failed", "format failure was not recorded")
	assert(failedStage.exitCode == failedResult.exitcode, "checker exit code was lost")
	local diagnostics = assert(failedStage.diagnostics, "report omitted original checker diagnostics")
	assert(table.concat(diagnostics.arguments, " ") == "stylua --check src tests scripts", "checker arguments changed")
	assert(
		string.find(diagnostics.stdout .. diagnostics.stderr, "DiagnosticFixture.luau", 1, true) ~= nil,
		"report lost the original error location"
	)
	local output = failedResult.stdout .. failedResult.stderr
	assert(string.find(output, "DiagnosticFixture.luau", 1, true) ~= nil, "checker diagnostics were not echoed")
	assert(string.find(output, "[verify] PASS", 1, true) == nil, "failed run claimed PASS")
	local originalReport = fs.readFileToString(failedPath)

	fs.writeStringToFile(fixture, "--!strict\n\nreturn {}\n")
	local passedResult, passedPath, passedReport = run()
	assert(passedResult.ok, "corrected fixture failed:\n" .. passedResult.stdout .. passedResult.stderr)
	assert(passedReport.outcome == "passed" and not passedReport.fullGate, "focused success was misreported")
	assert(passedPath ~= failedPath, "a later run reused the failed report path")
	assert(fs.readFileToString(failedPath) == originalReport, "successful run overwrote original failure evidence")
	for _, stage in passedReport.stages do
		assert(stage.diagnostics == nil, "successful run retained failure diagnostics")
	end
end)

-- The absolute target is the unique fixture created above, under this checkout.
assert(string.sub(root, 1, #fixtureParent) == fixtureParent and root ~= fixtureParent, "unsafe fixture cleanup target")
local cleanupOk, cleanupError = pcall(fs.removeDirectory, root, { recursive = true })
if not ok then
	error(tostring(failure) .. (if cleanupOk then "" else "\nCleanup failed: " .. tostring(cleanupError)))
end
assert(cleanupOk, tostring(cleanupError))
print("[verification] Diagnostic capture and report retention regression passed")
