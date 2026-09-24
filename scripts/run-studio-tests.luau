--!strict
--# selene: allow(incorrect_standard_library_use)

local fs = require("@std/fs")
local process = require("@lute/process")

local Guard = require("./studio-diagnostic-guard")

local EVIDENCE_DIRECTORY = ".verify/studio-diagnostics"
local cliArguments: { string } = { ... }
local rawArguments: { string } = {}
for index = 2, #cliArguments do
	table.insert(rawArguments, cliArguments[index])
end
local suite = "studio"
if #rawArguments >= 2 and rawArguments[1] == "--suite" then
	if
		rawArguments[2] ~= "studio"
		and rawArguments[2] ~= "studio-shutdown"
		and rawArguments[2] ~= "studio-autosave"
	then
		print("unknown Studio suite: " .. rawArguments[2])
		process.exit(2)
	end
	suite = rawArguments[2]
	table.remove(rawArguments, 1)
	table.remove(rawArguments, 1)
end

local arguments = {
	"lest",
	"run",
	suite,
	"--config",
	if suite == "studio-autosave" then "lest-autosave.toml" else "lest.toml",
	"--forbid-only",
	"--reporter",
	"json",
	"--no-color",
}

if #rawArguments > 0 then
	if #rawArguments ~= 2 or rawArguments[1] ~= "--filter" or rawArguments[2] == "" then
		print(
			"usage: lute run scripts/run-studio-tests.luau [--suite studio|studio-shutdown|studio-autosave] [--filter <test-name-substring>]"
		)
		process.exit(2)
	end
	table.insert(arguments, "--filter")
	table.insert(arguments, rawArguments[2])
end

local function evidencePath(): string
	fs.createDirectory(EVIDENCE_DIRECTORY, { makeParents = true })
	for suffix = 0, 999 do
		local path = string.format("%s/%d-%03d.log", EVIDENCE_DIRECTORY, os.time(), suffix)
		if not fs.exists(path) then
			return path
		end
	end
	error("could not allocate Studio diagnostic evidence path")
end

local result = process.run(arguments)
if result.stdout ~= "" then
	print(result.stdout)
end
if result.stderr ~= "" then
	print(result.stderr)
end

local verdict = Guard.evaluate(result)
if verdict.ok then
	return
end

local path = evidencePath()
local problemLines: { string } = {}
for _, problem in verdict.problems do
	table.insert(problemLines, string.format("[%s] %s\n%s", problem.kind, problem.context, problem.message))
end
local contents = table.concat({
	"command: " .. table.concat(arguments, " "),
	"exit code: " .. tostring(result.exitcode),
	"",
	"guard problems:",
	table.concat(problemLines, "\n\n"),
	"",
	"stdout:",
	result.stdout,
	"",
	"stderr:",
	result.stderr,
}, "\n")
fs.writeStringToFile(path, contents)

for _, problem in verdict.problems do
	print(string.format("[studio-diagnostics] %s in %s:\n%s", problem.kind, problem.context, problem.message))
end
print("[studio-diagnostics] retained output: " .. path)
process.exit(verdict.exitCode)
