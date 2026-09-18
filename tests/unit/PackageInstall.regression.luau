--!strict

local fs = require("@std/fs")
local path = require("@std/path")
local process = require("@std/process")
local PackageInstall = require("../../scripts/package-install")

if process.args[2] == "--cache-fixture" then
	assert(not PackageInstall.isCurrent(), "an unstamped installation must be restored")
	PackageInstall.remember()
	assert(PackageInstall.isCurrent(), "identical inputs must reuse the installation")
	fs.writeStringToFile("sourcemap.json", "{}")
	PackageInstall.rememberTypes()
	assert(PackageInstall.typesCurrent(), "generated typings must be reusable")
	fs.writeStringToFile("sourcemap.json", "changed")
	assert(not PackageInstall.typesCurrent(), "changed sourcemap must invalidate typings")
	fs.writeStringToFile("sourcemap.json", "{}")
	local ok, reason = PackageInstall.install()
	assert(ok, reason) -- No registry or Wally invocation: these are intentionally invalid manifests.
	for _, file in { "wally.toml", "wally.lock", "rokit.toml", "Packages/lib/init.lua" } do
		local original = fs.readFileToString(file)
		fs.writeStringToFile(file, original .. "changed")
		assert(not PackageInstall.isCurrent(), "changed file must invalidate cache: " .. file)
		fs.writeStringToFile(file, original)
		assert(PackageInstall.isCurrent(), "restored file must match cache: " .. file)
	end
	fs.remove("Packages/lib/init.lua")
	assert(not PackageInstall.isCurrent(), "missing package file must invalidate cache")
	return
end

local root = string.format(".verify/package-sync-test-%d-%d", os.time(), math.random(1, 1000000000))
local source, destination = root .. "/source", root .. "/Packages"
fs.createDirectory(source .. "/lib", { makeParents = true })
fs.createDirectory(destination .. "/lib", { makeParents = true })
local ok, failure = pcall(function()
	fs.writeStringToFile(source .. "/lib/init.lua", "return {}")
	fs.writeStringToFile(destination .. "/lib/init.lua", "return {}")
	assert(PackageInstall.sync(source, destination) == 0, "unchanged files must not be rewritten")
	fs.writeStringToFile(source .. "/lib/init.lua", "return { changed = true }")
	assert(PackageInstall.sync(source, destination) == 1, "one changed file must be copied")
	assert(fs.readFileToString(destination .. "/lib/init.lua") == "return { changed = true }", "copy must match source")
	fs.writeStringToFile(destination .. "/obsolete.lua", "return {}")
	fs.writeStringToFile(source .. "/lib/init.lua", "return { unsafe = true }")
	assert(not pcall(PackageInstall.sync, source, destination), "removals must require a stopped Rojo server")
	assert(
		fs.readFileToString(destination .. "/lib/init.lua") == "return { changed = true }",
		"failed sync must not write"
	)
	assert(fs.exists(destination .. "/obsolete.lua"), "failed sync must preserve old files")
	fs.createDirectory(root .. "/.verify")
	for _, file in { "wally.toml", "wally.lock", "rokit.toml" } do
		fs.writeStringToFile(root .. "/" .. file, "fixture")
	end
	local scriptPath = path.format(path.join(process.cwd(), "tests/unit/PackageInstall.regression.luau"))
	local result = process.run(
		{ path.format(process.execPath()), "run", scriptPath, "--cache-fixture" },
		{ cwd = root, stdio = "inherit" }
	)
	assert(result.ok, "package cache regression failed")
end)
fs.removeDirectory(root, { recursive = true })
assert(ok, tostring(failure))
print("[package-install] Regression checks passed")
