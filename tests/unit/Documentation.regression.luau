--!strict

local fs = require("@std/fs")

local function normalizePath(path: string): string
	local parts: { string } = {}
	for part in string.gmatch(string.gsub(path, "\\", "/"), "[^/]+") do
		if part == ".." then
			assert(#parts > 0, "documentation link escapes the repository: " .. path)
			table.remove(parts)
		elseif part ~= "." and part ~= "" then
			table.insert(parts, part)
		end
	end
	return table.concat(parts, "/")
end

local function directory(path: string): string
	return string.match(path, "^(.*)/[^/]+$") or ""
end

local function resolveTarget(documentPath: string, target: string): string?
	if string.match(target, "^%a[%w+.-]*:") or string.sub(target, 1, 1) == "#" then
		return nil
	end

	local path = string.match(target, "^[^#?]+") or target
	path = string.gsub(path, "^<(.+)>$", "%1")
	local base = directory(documentPath)
	return normalizePath((base == "" and "" or base .. "/") .. path)
end

local function localTargets(documentPath: string, document: string): { string }
	local targets: { string } = {}
	for target in string.gmatch(document, "%[[^%]]*%]%(([^%)]+)%)") do
		local resolved = resolveTarget(documentPath, target)
		if resolved ~= nil then
			table.insert(targets, resolved)
		end
	end
	return targets
end

local function collectMarkdown(root: string, output: { string })
	for _, entry in fs.listDirectory(root) do
		local path = root .. "/" .. entry.name
		if entry.type == "dir" then
			collectMarkdown(path, output)
		elseif entry.type == "file" and string.match(entry.name, "%.md$") then
			table.insert(output, path)
		end
	end
end

local function append(output: { string }, values: { string })
	for _, value in values do
		table.insert(output, value)
	end
end

local function assertLinksExist(paths: { string })
	local missing: { string } = {}
	for _, documentPath in paths do
		for _, target in localTargets(documentPath, fs.readFileToString(documentPath)) do
			if not fs.exists(target) then
				table.insert(missing, documentPath .. " -> " .. target)
			end
		end
	end
	table.sort(missing)
	assert(#missing == 0, "documentation references missing local files:\n" .. table.concat(missing, "\n"))
end

local function targetCounts(indexPath: string): { [string]: number }
	local counts: { [string]: number } = {}
	for _, target in localTargets(indexPath, fs.readFileToString(indexPath)) do
		if string.match(target, "%.md$") then
			counts[target] = (counts[target] or 0) + 1
		end
	end
	return counts
end

local function assertIndexedOnce(indexPath: string, expected: { string })
	local counts = targetCounts(indexPath)
	local failures: { string } = {}
	for _, path in expected do
		local count = counts[path] or 0
		if count ~= 1 then
			table.insert(failures, string.format("%s is indexed %d times", path, count))
		end
	end
	for path, count in counts do
		if count > 1 then
			table.insert(failures, string.format("%s has duplicate target %s", indexPath, path))
		end
	end
	table.sort(failures)
	assert(#failures == 0, "documentation index failures:\n" .. table.concat(failures, "\n"))
end

local function assertContainsTargets(documentPath: string, required: { string })
	local present: { [string]: boolean } = {}
	for _, target in localTargets(documentPath, fs.readFileToString(documentPath)) do
		present[target] = true
	end
	local missing: { string } = {}
	for _, target in required do
		if not present[target] then
			table.insert(missing, target)
		end
	end
	assert(#missing == 0, documentPath .. " is missing required documentation links:\n" .. table.concat(missing, "\n"))
end

assert(normalizePath("docs/guides/../verification.md") == "docs/verification.md", "path normalization failed")
assert(
	resolveTarget("docs/guides/setup.md", "../verification.md#canonical-gate") == "docs/verification.md",
	"nested relative link resolution failed"
)
assert(resolveTarget("README.md", "https://example.com") == nil, "remote URL was treated as local")
assert(resolveTarget("README.md", "#setup") == nil, "anchor was treated as a local file")

local agentDocuments: { string } = {}
collectMarkdown(".agents/docs", agentDocuments)
table.insert(agentDocuments, ".agents/roblox/structure.md")

local projectDocuments: { string } = {}
collectMarkdown("docs", projectDocuments)
table.insert(projectDocuments, "tooling/roblox/README.md")

local activeDocuments = { "AGENTS.md", "README.md" }
append(activeDocuments, agentDocuments)
append(activeDocuments, projectDocuments)
assertLinksExist(activeDocuments)

local agentIndexed: { string } = {}
for _, path in agentDocuments do
	if path ~= ".agents/docs/README.md" then
		table.insert(agentIndexed, path)
	end
end
assertIndexedOnce(".agents/docs/README.md", agentIndexed)

local projectIndexed: { string } = {}
for _, path in projectDocuments do
	if path ~= "docs/README.md" then
		table.insert(projectIndexed, path)
	end
end
assertIndexedOnce("docs/README.md", projectIndexed)

assertContainsTargets("AGENTS.md", {
	".agents/docs/README.md",
	".agents/roblox/structure.md",
	"docs/README.md",
})
assertContainsTargets("README.md", { "docs/README.md" })

print(string.format("[documentation] %d active documents and both indexes passed", #activeDocuments))
