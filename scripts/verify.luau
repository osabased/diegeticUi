--!strict

local fs = require("@std/fs")
local process = require("@std/process")

local PROJECT_FILE = "default.project.json"
local SOURCEMAP = "sourcemap.json"
local ROBLOX_DEFINITIONS = "tooling/roblox/globalTypes.d.luau"
local SELENE_ROBLOX_STD = "roblox.yml"
local BUILD_DIRECTORY = ".verify"
local BUILD_OUTPUT = BUILD_DIRECTORY .. "/diegeticUi.rbxlx"

local function cleanupBuildArtifact()
	if fs.exists(BUILD_OUTPUT) then
		fs.remove(BUILD_OUTPUT)
	end

	if fs.exists(BUILD_DIRECTORY) then
		-- Only remove the directory when it is empty. Never recursively delete a
		-- directory that may contain diagnostics from another tool.
		pcall(function()
			fs.removeDirectory(BUILD_DIRECTORY)
		end)
	end
end

local function fail(stage: string, exitCode: number?): never
	cleanupBuildArtifact()
	print(string.format("[verify] FAILED: %s", stage))
	process.exit(if exitCode ~= nil and exitCode ~= 0 then exitCode else 1)
	error("process.exit returned unexpectedly")
end

local function run(stage: string, args: { string })
	print(string.format("[verify] %s", stage))
	local result = process.run(args, { stdio = "inherit" })
	if not result.ok then
		fail(stage, result.exitcode)
	end
end

if not fs.exists(PROJECT_FILE) or not fs.exists("rokit.toml") then
	fail("run this command from the repository root")
end

if not fs.exists("wally.lock") then
	fail("wally.lock is required for deterministic dependency verification")
end

if not fs.exists(ROBLOX_DEFINITIONS) or not fs.exists(SELENE_ROBLOX_STD) then
	fail("pinned Roblox API definitions are missing")
end

cleanupBuildArtifact()

-- Wally 0.3.2 predates `wally install --locked`. Preserve its working pin and
-- enforce the same invariant by rejecting and undoing any lockfile mutation.
print("[verify] Install Wally dependencies without lockfile drift")
local lockBefore = fs.readFileToString("wally.lock")
local wallyResult = process.run({ "wally", "install" }, { stdio = "inherit" })
local lockAfter = fs.readFileToString("wally.lock")
if lockAfter ~= lockBefore then
	fs.writeStringToFile("wally.lock", lockBefore)
	fail("Wally dependency declarations do not match wally.lock")
end
if not wallyResult.ok then
	fail("Install Wally dependencies without lockfile drift", wallyResult.exitcode)
end

run("Generate the Rojo sourcemap", { "rojo", "sourcemap", PROJECT_FILE, "--output", SOURCEMAP })
run("Generate Wally package typings", { "wally-package-types", "--sourcemap", SOURCEMAP, "Packages" })
run("Check formatting", { "stylua", "--check", "src", "tests", "scripts" })
run("Lint Roblox Luau", { "selene", "src", "tests/tooling" })
run("Lint tooling and unit tests", { "selene", "--config", "selene.luau.toml", "tests/unit", "scripts" })
run("Analyze Luau with Roblox, Rojo, and package types", {
	"luau-lsp",
	"analyze",
	"--platform",
	"roblox",
	"--definitions",
	"@roblox=" .. ROBLOX_DEFINITIONS,
	"--sourcemap",
	SOURCEMAP,
	"src",
	"tests/tooling/RobloxDefinitions.luau",
})
run("Run fast unit tests", { "lest", "run", "unit", "--forbid-only" })

fs.createDirectory(BUILD_DIRECTORY)
run("Build the Rojo place", { "rojo", "build", PROJECT_FILE, "--output", BUILD_OUTPUT })
cleanupBuildArtifact()

print("[verify] PASS")
