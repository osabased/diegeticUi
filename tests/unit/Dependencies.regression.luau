--!strict

local fs = require("@std/fs")
local Dependencies = require("../../scripts/dependencies")

local root = string.format(".verify/dependencies-test-%d-%d", os.time(), math.random(1, 1000000000))
fs.createDirectory(root .. "/Packages/lib", { makeParents = true })
local ok, failure = pcall(function()
	for _, file in { "wally.toml", "wally.lock", "rokit.toml", "default.project.json", "Packages/lib/init.lua" } do
		fs.writeStringToFile(root .. "/" .. file, "fixture")
	end
	assert(not Dependencies.isPrepared(root), "missing preparation must fail")
	Dependencies.recordPrepared(root)
	assert(Dependencies.isPrepared(root), "prepared dependencies must pass")
	for _, file in { "wally.toml", "wally.lock", "rokit.toml", "default.project.json", "Packages/lib/init.lua" } do
		fs.writeStringToFile(root .. "/" .. file, "changed")
		assert(not Dependencies.isPrepared(root), "changed file must invalidate preparation: " .. file)
		fs.writeStringToFile(root .. "/" .. file, "fixture")
		assert(Dependencies.isPrepared(root), "restored file must match preparation: " .. file)
	end
	fs.writeStringToFile(root .. "/sourcemap.json", "changed source map")
	assert(Dependencies.isPrepared(root), "ordinary source map changes must not require reinstalling packages")
	fs.writeStringToFile(root .. "/Packages/extra.lua", "extra")
	assert(not Dependencies.isPrepared(root), "added package files must invalidate preparation")
	fs.remove(root .. "/Packages/extra.lua")
	fs.remove(root .. "/Packages/lib/init.lua")
	assert(not Dependencies.isPrepared(root), "missing package files must invalidate preparation")
	fs.writeStringToFile(root .. "/Packages/lib/init.lua", "fixture")
	Dependencies.invalidate(root)
	assert(not Dependencies.isPrepared(root), "starting preparation must invalidate previous success")
	assert(fs.readFileToString(root .. "/Packages/lib/init.lua") == "fixture", "checks must preserve package contents")
end)
-- This exact fixture directory was created above and contains no live packages.
fs.removeDirectory(root, { recursive = true })
assert(ok, tostring(failure))
print("[dependencies] Regression checks passed")
