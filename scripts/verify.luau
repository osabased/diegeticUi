--!strict

local fs = require("@std/fs")
local json = require("@std/json")
local process = require("@std/process")
local system = require("@lute/system")

local Verification = require("./verification")
local Dependencies = require("./dependencies")

type JsonObject = json.Object
type OrchestrationResult = Verification.OrchestrationResult
type Report = Verification.Report
type Selection = Verification.Selection
type StageRecord = Verification.StageRecord
type StepName = Verification.StepName
type StepResult = Verification.StepResult

local PROJECT_FILE = "default.project.json"
local SOURCEMAP = "sourcemap.json"
local ROBLOX_DEFINITIONS = "tooling/roblox/globalTypes.d.luau"
local SELENE_ROBLOX_STD = "roblox.yml"
local BUILD_DIRECTORY = ".verify"
local BUILD_OUTPUT = BUILD_DIRECTORY .. "/diegeticUi.rbxlx"
local REPORT_DIRECTORY = BUILD_DIRECTORY .. "/reports"
local BLINK_VERSION = "1.0.0-pre.8"
local BLINK_SCHEMA = "src/shared/Network/main.blink"
local BLINK_STAMP = "src/shared/Network/main.blink.stamp"
local BLINK_GENERATED = {
	"src/shared/Network/Types.luau",
	"src/shared/Network/Client.luau",
	"src/shared/Network/Server.luau",
}
local HASH_MODULUS = 4294967296

local STEP_LABELS: { [StepName]: string } = {
	preflight = "Check repository prerequisites",
	wally = "Check prepared Wally dependencies and package types",
	blink = "Check Blink-generated networking modules",
	sourcemap = "Generate the Rojo sourcemap",
	lest_core = "Prepare the Lest framework",
	format = "Check formatting",
	lint = "Lint Luau",
	analyze = "Analyze Luau with Roblox, Rojo, and package types",
	unit = "Run fast unit tests",
	build = "Build the Rojo place",
	studio = "Run Studio construction tests",
}

local function trim(value: string): string
	return (string.gsub(value, "^%s*(.-)%s*$", "%1"))
end

local function utcTimestamp(): string
	local command = if string.find(string.lower(system.os), "windows", 1, true) ~= nil
		then {
			"powershell.exe",
			"-NoProfile",
			"-NonInteractive",
			"-Command",
			"[DateTime]::UtcNow.ToString('yyyy-MM-ddTHH:mm:ss.fffZ')",
		}
		else { "date", "-u", "+%Y-%m-%dT%H:%M:%S.%3NZ" }
	local runOk, result = pcall(function()
		return process.run(command)
	end)
	if runOk and result.ok then
		local timestamp = trim(result.stdout)
		if timestamp ~= "" then
			return timestamp
		end
	end

	return string.format("uptime-%.3f", system.uptime())
end

local function reportPathFor(startedAt: string): string
	fs.createDirectory(REPORT_DIRECTORY, { makeParents = true })
	local safeTimestamp = string.gsub(startedAt, "[^%w]", "")
	for suffix = 0, 999 do
		local candidate = string.format("%s/%s-%03d.json", REPORT_DIRECTORY, safeTimestamp, suffix)
		if not fs.exists(candidate) then
			return candidate
		end
	end
	error("could not allocate a unique verification report path")
end

local reportWriteSequence = 0

local function powershellLiteral(value: string): string
	return "'" .. string.gsub(value, "'", "''") .. "'"
end

local function moveFile(source: string, destination: string)
	local command = if string.find(string.lower(system.os), "windows", 1, true) ~= nil
		then {
			"powershell.exe",
			"-NoProfile",
			"-NonInteractive",
			"-Command",
			string.format(
				"Move-Item -LiteralPath %s -Destination %s -Force",
				powershellLiteral(source),
				powershellLiteral(destination)
			),
		}
		else { "mv", "-f", "--", source, destination }
	local result = process.run(command)
	if not result.ok then
		error(
			string.format(
				"could not move %s to %s (exit %d): %s",
				source,
				destination,
				result.exitcode,
				trim(result.stderr)
			)
		)
	end
end

local function writeReport(path: string, report: Report)
	local value = (report :: unknown) :: JsonObject
	local contents = json.serialize(value, true) .. "\n"
	reportWriteSequence += 1
	local temporaryPath = string.format("%s.tmp-%03d", path, reportWriteSequence)
	local backupPath = string.format("%s.bak-%03d", path, reportWriteSequence)

	fs.writeStringToFile(temporaryPath, contents)
	if not fs.exists(path) then
		local moveOk, moveError = pcall(moveFile, temporaryPath, path)
		if not moveOk then
			pcall(fs.remove, temporaryPath)
			error(moveError)
		end
		return
	end

	moveFile(path, backupPath)
	local replaceOk, replaceError = pcall(moveFile, temporaryPath, path)
	if not replaceOk then
		local restoreOk, restoreError = pcall(moveFile, backupPath, path)
		pcall(fs.remove, temporaryPath)
		if not restoreOk then
			error(
				string.format(
					"report replacement failed (%s) and the previous report remains at %s (%s)",
					tostring(replaceError),
					backupPath,
					tostring(restoreError)
				)
			)
		end
		error("report replacement failed; previous report restored: " .. tostring(replaceError))
	end

	fs.remove(backupPath)
end

local function fingerprint(source: string): string
	local hash = 5381
	for index = 1, #source do
		hash = (hash * 33 + string.byte(source, index)) % HASH_MODULUS
	end
	return string.format("%08x", hash)
end

local function expectedBlinkStamp(): string
	return table.concat({
		"blink_version=" .. BLINK_VERSION,
		"schema_djb2=" .. fingerprint(fs.readFileToString(BLINK_SCHEMA)),
		"types_djb2=" .. fingerprint(fs.readFileToString(BLINK_GENERATED[1])),
		"client_djb2=" .. fingerprint(fs.readFileToString(BLINK_GENERATED[2])),
		"server_djb2=" .. fingerprint(fs.readFileToString(BLINK_GENERATED[3])),
	}, "\n") .. "\n"
end

local function cleanupBuildArtifact()
	if fs.exists(BUILD_OUTPUT) then
		fs.remove(BUILD_OUTPUT)
	end

	if fs.exists(BUILD_DIRECTORY) then
		-- Only remove the directory when it is empty. Reports and diagnostics are
		-- durable artifacts and must never be removed recursively here.
		pcall(function()
			fs.removeDirectory(BUILD_DIRECTORY)
		end)
	end

	if fs.exists(BUILD_OUTPUT) then
		error("could not remove disposable place: " .. BUILD_OUTPUT)
	end
end

local function failed(reason: string, exitCode: number?): StepResult
	return {
		ok = false,
		exitCode = if exitCode ~= nil and exitCode ~= 0 then exitCode else 1,
		reason = reason,
	}
end

local function passed(): StepResult
	return { ok = true }
end

local function requireFile(path: string, reason: string): StepResult?
	if not fs.exists(path) then
		return failed(reason)
	end
	return nil
end

local function runCommand(arguments: { string }, reason: string): StepResult
	local result = process.run(arguments)
	-- Echo captured output after the command completes; preserve the original
	-- streams in failed reports so a later agent can diagnose without rerunning.
	if result.stdout ~= "" then
		print(result.stdout)
	end
	if result.stderr ~= "" then
		print(result.stderr)
	end
	if not result.ok then
		local failure = failed(reason, result.exitcode)
		failure.diagnostics = {
			arguments = table.clone(arguments),
			stdout = result.stdout,
			stderr = result.stderr,
		}
		return failure
	end
	return passed()
end

local function runPreflight(): StepResult
	cleanupBuildArtifact()
	if not fs.exists(PROJECT_FILE) or not fs.exists("rokit.toml") then
		return failed("run this command from the repository root")
	end
	return passed()
end

local function runWally(): StepResult
	local missing = requireFile("wally.lock", "wally.lock is required for deterministic dependency verification")
	if missing ~= nil then
		return missing
	end

	if not Dependencies.isPrepared(".") then
		return failed(
			"Dependencies are missing or stale. Stop Rojo, run `lute run scripts/prepare-dependencies.luau`, then restart Rojo."
		)
	end
	return passed()
end

local function runBlink(): StepResult
	local missingSchema = requireFile(BLINK_SCHEMA, "the Blink network schema is missing")
	if missingSchema ~= nil then
		return missingSchema
	end

	local blinkBefore: { [string]: string } = {}
	for _, path in BLINK_GENERATED do
		if not fs.exists(path) then
			return failed(string.format("Blink-generated module is missing: %s", path))
		end
		blinkBefore[path] = fs.readFileToString(path)
	end
	if not fs.exists(BLINK_STAMP) or fs.readFileToString(BLINK_STAMP) ~= expectedBlinkStamp() then
		return failed("Blink schema or generated modules changed without `lute run scripts/generate-blink.luau`")
	end

	-- Blink pre.8 randomizes identifiers on each compile. Smoke-test the pinned
	-- generator, then restore the exact committed output on every result path.
	local result = runCommand(
		{ "blink", "compile", "--profile", "release", BLINK_SCHEMA },
		"Blink network schema compilation failed"
	)
	local blinkHeader = "--file generated by blink " .. BLINK_VERSION
	local versionMatched = true
	for _, path in BLINK_GENERATED do
		local after = if fs.exists(path) then fs.readFileToString(path) else ""
		if string.find(after, blinkHeader, 1, true) == nil then
			versionMatched = false
		end
		if after ~= blinkBefore[path] then
			fs.writeStringToFile(path, blinkBefore[path])
		end
	end

	if not result.ok then
		return result
	end
	if not versionMatched then
		return failed("Blink-generated module headers do not match the pinned CLI version")
	end
	return passed()
end

local function runLint(): StepResult
	local robloxLint = runCommand({ "selene", "src", "tests/tooling", "tests/studio" }, "Roblox Luau lint failed")
	if not robloxLint.ok then
		return robloxLint
	end
	return runCommand(
		{ "selene", "--config", "selene.luau.toml", "tests/unit", "scripts" },
		"tooling or unit-test lint failed"
	)
end

local function runStep(step: StepName): StepResult
	print(string.format("[verify] %s", STEP_LABELS[step]))

	if step == "preflight" then
		return runPreflight()
	elseif step == "wally" then
		return runWally()
	elseif step == "blink" then
		return runBlink()
	elseif step == "sourcemap" then
		return runCommand(
			{ "rojo", "sourcemap", PROJECT_FILE, "--output", SOURCEMAP },
			"Rojo sourcemap generation failed"
		)
	elseif step == "lest_core" then
		local result = runCommand({ "lest", "run", "bootstrap", "--forbid-only" }, "Lest framework preparation failed")
		if not result.ok then
			return result
		end
		return if fs.exists(".lest/core/init.luau")
			then passed()
			else failed("Lest framework preparation did not create .lest/core/init.luau")
	elseif step == "format" then
		return runCommand({ "stylua", "--check", "src", "tests", "scripts" }, "formatting check failed")
	elseif step == "lint" then
		return runLint()
	elseif step == "analyze" then
		local definitionsMissing = requireFile(ROBLOX_DEFINITIONS, "pinned Roblox API definitions are missing")
		if definitionsMissing ~= nil then
			return definitionsMissing
		end
		local seleneDefinitionsMissing = requireFile(SELENE_ROBLOX_STD, "pinned Selene Roblox definitions are missing")
		if seleneDefinitionsMissing ~= nil then
			return seleneDefinitionsMissing
		end
		return runCommand({
			"luau-lsp",
			"analyze",
			"--platform",
			"roblox",
			"--definitions",
			"@roblox=" .. ROBLOX_DEFINITIONS,
			"--sourcemap",
			SOURCEMAP,
			"--ignore",
			"src/shared/Network/*.luau",
			"--ignore",
			".lest/**/*.luau",
			"src",
			"tests/tooling/RobloxDefinitions.luau",
			"tests/studio",
		}, "Luau analysis failed")
	elseif step == "unit" then
		local documentation = runCommand(
			{ "lute", "run", "tests/unit/Documentation.regression.luau" },
			"documentation link regression failed"
		)
		if not documentation.ok then
			return documentation
		end
		local packages = runCommand(
			{ "lute", "run", "tests/unit/Dependencies.regression.luau" },
			"dependency preparation regression failed"
		)
		if not packages.ok then
			return packages
		end
		local diagnostics = runCommand(
			{ "lute", "run", "tests/unit/VerificationDiagnostics.regression.luau" },
			"verification diagnostic regression failed"
		)
		if not diagnostics.ok then
			return diagnostics
		end
		return runCommand({ "lest", "run", "unit", "--forbid-only" }, "unit tests failed")
	elseif step == "build" then
		fs.createDirectory(BUILD_DIRECTORY, { makeParents = true })
		return runCommand({ "rojo", "build", PROJECT_FILE, "--output", BUILD_OUTPUT }, "Rojo place build failed")
	elseif step == "studio" then
		local buildMissing = requireFile(BUILD_OUTPUT, "the disposable Studio test place is missing")
		if buildMissing ~= nil then
			return buildMissing
		end
		return runCommand({ "lest", "run", "studio", "--forbid-only" }, "Studio construction tests failed")
	end

	return failed("unsupported verification step: " .. tostring(step))
end

local function usageError(message: string): never
	print("[verify] " .. message)
	print("usage: lute run scripts/verify.luau [--stage format|lint|analyze|unit|build|studio]...")
	process.exit(2)
	error("process.exit returned unexpectedly")
end

local rawArguments: { string } = { ... }
local arguments: { string } = {}
-- Lute supplies the script path as the first top-level vararg.
for index = 2, #rawArguments do
	table.insert(arguments, rawArguments[index])
end
local selection, argumentError = Verification.parseArguments(arguments)
if selection == nil then
	usageError(argumentError or "invalid arguments")
end
local resolvedSelection = selection :: Selection

-- Treat repository-root discovery as invocation validation so a mistyped cwd
-- does not create a .verify directory in an unrelated location.
if not fs.exists(PROJECT_FILE) or not fs.exists("rokit.toml") then
	print("[verify] FAILED: run this command from the repository root")
	process.exit(1)
end

local startedAt = utcTimestamp()
local report = Verification.newReport(resolvedSelection, startedAt)
local pathOk, pathOrError = pcall(reportPathFor, startedAt)
local reportPath = if pathOk then pathOrError :: string else "<unavailable>"
if pathOk then
	print("[verify] report: " .. reportPath)
end

local plan = Verification.plan(resolvedSelection)
local orchestration: OrchestrationResult = Verification.orchestrate(
	report,
	plan,
	runStep,
	system.uptime,
	function(updatedReport)
		if not pathOk then
			error("could not allocate report path: " .. tostring(pathOrError))
		end
		writeReport(reportPath, updatedReport)
	end,
	cleanupBuildArtifact
)
print(Verification.resultMessage(report))
for _, record in report.stages do
	if record.status == "failed" and record.reason ~= nil then
		print("[verify] " .. record.reason)
	end
end
if pathOk and orchestration.durableReport then
	print("[verify] report: " .. reportPath)
else
	print("[verify] no durable report was written")
end

if not orchestration.finalReportPersisted then
	local snapshotOk, snapshot = pcall(function()
		return json.serialize((report :: unknown) :: JsonObject, true)
	end)
	print("[verify] final report persistence failed")
	if snapshotOk then
		print(snapshot)
	end
end

if not orchestration.ok then
	local exitCode = 1
	for _, record: StageRecord in report.stages do
		if record.status == "failed" and record.exitCode ~= nil then
			exitCode = record.exitCode
			break
		end
	end
	process.exit(exitCode)
end
