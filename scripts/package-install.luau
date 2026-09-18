--!strict

local fs = require("@std/fs")
local process = require("@std/process")
local crypto = require("@lute/crypto")

local PackageInstall = {}
local CACHE = ".verify/wally-install.sha256"
local TYPES_CACHE = ".verify/wally-types.sha256"
local restored = false

local function files(directory: string, prefix: string, result: { [string]: string })
	if not fs.exists(directory) then
		return
	end
	for _, entry in fs.listDirectory(directory) do
		local relative = prefix .. entry.name
		local path = directory .. "/" .. entry.name
		if entry.type == "dir" then
			files(path, relative .. "/", result)
		else
			assert(entry.type == "file", "unsupported package entry: " .. path)
			result[relative] = fs.readFileToString(path)
		end
	end
end

local function digest(contents: string): string
	return (
		string.gsub(buffer.tostring(crypto.digest(crypto.hash.sha256, contents)), ".", function(byte)
			return string.format("%02x", string.byte(byte))
		end)
	)
end

local function fingerprint(): string
	local installed: { [string]: string } = {}
	files("Packages", "", installed)
	local entries = {
		"wally-install-v1",
		digest(fs.readFileToString("rokit.toml")),
		digest(fs.readFileToString("wally.toml")),
		digest(fs.readFileToString("wally.lock")),
	}
	local paths: { string } = {}
	for path in installed do
		table.insert(paths, path)
	end
	table.sort(paths)
	for _, path in paths do
		table.insert(entries, path .. "\0" .. digest(installed[path]))
	end
	return digest(table.concat(entries, "\n"))
end

function PackageInstall.remember()
	fs.writeStringToFile(CACHE, fingerprint())
end

function PackageInstall.isCurrent(): boolean
	return fs.exists(CACHE) and fs.exists("Packages") and fs.readFileToString(CACHE) == fingerprint()
end

local function typesFingerprint(): string
	return digest(fingerprint() .. fs.readFileToString("sourcemap.json"))
end

function PackageInstall.typesCurrent(): boolean
	return fs.exists(TYPES_CACHE) and fs.readFileToString(TYPES_CACHE) == typesFingerprint()
end

function PackageInstall.rememberTypes()
	PackageInstall.remember()
	fs.writeStringToFile(TYPES_CACHE, typesFingerprint())
end

-- Never tear down the tree watched by Rojo. In particular, deleting a package
-- directory during `wally install` can crash Rojo 7.7's change processor.
function PackageInstall.sync(source: string, destination: string): number
	local incoming: { [string]: string } = {}
	local installed: { [string]: string } = {}
	files(source, "", incoming)
	files(destination, "", installed)
	for relative in installed do
		assert(
			incoming[relative] ~= nil,
			"package removal required: " .. relative .. ". Stop Rojo, run `wally install`, then restart Rojo."
		)
	end

	local changed = 0
	for relative, contents in incoming do
		if installed[relative] ~= contents then
			local parent = string.match(relative, "^(.*)/[^/]+$")
			fs.createDirectory(destination .. (if parent then "/" .. parent else ""), { makeParents = true })
			fs.writeStringToFile(destination .. "/" .. relative, contents)
			changed += 1
		end
	end
	return changed
end

function PackageInstall.install(force: boolean?): (boolean, string?, number?)
	if not force and PackageInstall.isCurrent() then
		print("[verify] Reusing verified Wally dependencies (inputs and package contents unchanged)")
		return true, nil, nil
	end
	local manifest = fs.readFileToString("wally.toml")
	local lock = fs.readFileToString("wally.lock")
	fs.createDirectory(".verify", { makeParents = true })
	local staging = string.format(".verify/wally-%d-%d", os.time(), math.random(1, 1000000000))
	fs.createDirectory(staging)
	local ok, failure = pcall(function()
		fs.writeStringToFile(staging .. "/wally.toml", manifest)
		fs.writeStringToFile(staging .. "/wally.lock", lock)
		local result = process.run({ "wally", "install", "--project-path", staging }, { stdio = "inherit" })
		assert(result.ok, "Wally dependency installation failed (exit " .. tostring(result.exitcode) .. ")")
		assert(
			fs.readFileToString(staging .. "/wally.lock") == lock,
			"Wally dependency declarations do not match wally.lock"
		)
		assert(
			fs.readFileToString("wally.toml") == manifest and fs.readFileToString("wally.lock") == lock,
			"Wally inputs changed during installation; retry verification"
		)
		local changed = PackageInstall.sync(staging .. "/Packages", "Packages")
		restored = true
		PackageInstall.remember()
		print(string.format("[verify] Wally restored in staging; updated %d package files", changed))
	end)
	-- This exact directory was created above; it never contains the live Packages.
	fs.removeDirectory(staging, { recursive = true })
	return ok, if ok then nil else tostring(failure), if ok then nil else 1
end

function PackageInstall.prepareTypes(): (boolean, string?, number?)
	-- wally-package-types 1.6.2 only accepts original Wally require shims.
	if restored then
		return true, nil, nil
	end
	return PackageInstall.install(true)
end

return PackageInstall
