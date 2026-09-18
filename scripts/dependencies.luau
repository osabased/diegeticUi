--!strict

local fs = require("@std/fs")
local crypto = require("@lute/crypto")

local Dependencies = {}
local STAMP = "/.verify/dependencies.sha256"

local function digest(contents: string): string
	return (
		string.gsub(buffer.tostring(crypto.digest(crypto.hash.sha256, contents)), ".", function(byte)
			return string.format("%02x", string.byte(byte))
		end)
	)
end

function Dependencies.inputs(root: string): string
	local entries = { "prepared-dependencies-v1" }
	for _, file in { "rokit.toml", "wally.toml", "wally.lock", "default.project.json" } do
		table.insert(entries, digest(fs.readFileToString(root .. "/" .. file)))
	end
	return digest(table.concat(entries, "\n"))
end

local function packageFiles(root: string, relative: string, entries: { string })
	for _, entry in fs.listDirectory(root .. "/Packages/" .. relative) do
		local path = relative .. entry.name
		if entry.type == "dir" then
			packageFiles(root, path .. "/", entries)
		else
			assert(entry.type == "file", "unsupported package entry: " .. path)
			table.insert(entries, path .. "\0" .. digest(fs.readFileToString(root .. "/Packages/" .. path)))
		end
	end
end

local function fingerprint(root: string): string
	local entries: { string } = {}
	packageFiles(root, "", entries)
	assert(#entries > 0, "Packages is empty")
	table.sort(entries)
	return digest(Dependencies.inputs(root) .. "\n" .. table.concat(entries, "\n"))
end

function Dependencies.isPrepared(root: string): boolean
	local ok, matches = pcall(function()
		return fs.exists(root .. STAMP) and fs.readFileToString(root .. STAMP) == fingerprint(root)
	end)
	return ok and matches == true
end

function Dependencies.invalidate(root: string)
	if fs.exists(root .. STAMP) then
		fs.remove(root .. STAMP)
	end
end

function Dependencies.recordPrepared(root: string)
	fs.createDirectory(root .. "/.verify", { makeParents = true })
	fs.writeStringToFile(root .. STAMP, fingerprint(root))
end

return Dependencies
