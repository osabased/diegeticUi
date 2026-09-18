--!strict

local fs = require("@std/fs")
local process = require("@std/process")
local Dependencies = require("./dependencies")

local ok, failure = pcall(function()
	Dependencies.invalidate(".")
	local inputs = Dependencies.inputs(".")
	local lock = fs.readFileToString("wally.lock")
	print("[prepare] Rojo must be stopped while installing dependencies and generating package types.")
	local installed = process.run({ "wally", "install" }, { stdio = "inherit" })
	if fs.readFileToString("wally.lock") ~= lock then
		fs.writeStringToFile("wally.lock", lock)
		error(
			"Wally changed wally.lock; the original was restored. Reconcile dependency declarations and the lockfile before preparing again."
		)
	end
	assert(installed.ok, "Wally installation failed (exit " .. tostring(installed.exitcode) .. ")")
	for _, command in
		{
			{ "rojo", "sourcemap", "default.project.json", "--output", "sourcemap.json" },
			{ "wally-package-types", "--sourcemap", "sourcemap.json", "Packages" },
		}
	do
		local result = process.run(command, { stdio = "inherit" })
		assert(result.ok, command[1] .. " failed (exit " .. tostring(result.exitcode) .. ")")
	end
	assert(Dependencies.inputs(".") == inputs, "Dependency inputs changed during preparation; run preparation again.")
	Dependencies.recordPrepared(".")
end)

if not ok then
	print("[prepare] FAIL: " .. tostring(failure))
	process.exit(1)
end
print("[prepare] Dependencies and package types prepared. Rojo can be started.")
