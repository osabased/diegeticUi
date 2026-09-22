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

local function trim(value: string): string
	return string.match(value, "^%s*(.-)%s*$") or ""
end

local function stripHtmlComments(document: string): string
	local parts: { string } = {}
	local cursor = 1
	while true do
		local commentStart = string.find(document, "<!--", cursor, true)
		if commentStart == nil then
			table.insert(parts, string.sub(document, cursor))
			break
		end

		table.insert(parts, string.sub(document, cursor, commentStart - 1))
		local commentEnd = string.find(document, "-->", commentStart + 4, true)
		assert(commentEnd ~= nil, "documentation contains an unterminated HTML comment")
		cursor = commentEnd + 3
	end
	return table.concat(parts)
end

type Sections = {
	bodies: { [string]: string },
	order: { string },
}

local function secondLevelSections(document: string): Sections
	local bodies: { [string]: string } = {}
	local order: { string } = {}
	local current: string? = nil
	local lines: { string } = {}

	local function finishSection()
		if current ~= nil then
			assert(bodies[current] == nil, "duplicate documentation section: " .. current)
			bodies[current] = table.concat(lines, "\n")
			table.insert(order, current)
		end
		lines = {}
	end

	local normalized = string.gsub(stripHtmlComments(document), "\r\n", "\n")
	for line in string.gmatch(normalized .. "\n", "(.-)\n") do
		if string.match(line, "^## .+") then
			finishSection()
			current = line
		elseif current ~= nil then
			table.insert(lines, line)
		end
	end
	finishSection()

	return {
		bodies = bodies,
		order = order,
	}
end

local function hasContent(value: string?): boolean
	return value ~= nil and trim(value) ~= ""
end

local function appendFailure(failures: { string }, condition: boolean, message: string)
	if not condition then
		table.insert(failures, message)
	end
end

local EXECUTION_CORE = {
	"## Status",
	"## Objective",
	"## Priority Outcomes",
	"## Hotspots",
}

local function executionFailures(document: string): { string }
	local sections = secondLevelSections(document)
	local failures: { string } = {}
	local allowed = {
		["## Status"] = true,
		["## Objective"] = true,
		["## Priority Outcomes"] = true,
		["## Hotspots"] = true,
		["## Blocking Condition"] = true,
	}

	for index, heading in EXECUTION_CORE do
		appendFailure(failures, sections.bodies[heading] ~= nil, "missing execution section: " .. heading)
		appendFailure(failures, sections.order[index] == heading, "execution section is out of order: " .. heading)
	end
	for _, heading in sections.order do
		appendFailure(failures, allowed[heading] == true, "unsupported execution section: " .. heading)
	end

	local status = trim(sections.bodies["## Status"] or "")
	local objective = sections.bodies["## Objective"]
	local priorities = sections.bodies["## Priority Outcomes"]
	local hotspots = sections.bodies["## Hotspots"]
	local blocking = sections.bodies["## Blocking Condition"]
	local populated = status ~= ""
		or hasContent(objective)
		or hasContent(priorities)
		or hasContent(hotspots)
		or blocking ~= nil

	if not populated then
		return failures
	end

	appendFailure(failures, status == "active" or status == "blocked", "execution status must be active or blocked")
	if status == "active" then
		appendFailure(failures, hasContent(objective), "active execution requires an objective")
		appendFailure(failures, hasContent(priorities), "active execution requires priority outcomes")
		appendFailure(failures, blocking == nil, "active execution cannot include a blocking condition")
	elseif status == "blocked" then
		appendFailure(failures, blocking ~= nil, "blocked execution requires a blocking condition")
		if blocking ~= nil then
			local fields = {
				["Cause"] = false,
				["Owner"] = false,
				["Unblock when"] = false,
			}
			for line in string.gmatch(blocking .. "\n", "(.-)\n") do
				local field, value = string.match(line, "^%- ([^:]+):%s*(.-)%s*$")
				if field ~= nil and fields[field] ~= nil and value ~= "" then
					fields[field] = true
				end
			end
			for field, present in fields do
				appendFailure(failures, present, "blocked execution requires a non-empty " .. field .. " field")
			end
		end
	end

	if hasContent(hotspots) then
		for line in string.gmatch(hotspots .. "\n", "(.-)\n") do
			if trim(line) ~= "" then
				appendFailure(
					failures,
					string.match(line, "^%- `[^`]+` — .+") ~= nil,
					"hotspot entries must use `path or symbol` — explanation"
				)
			end
		end
	end

	return failures
end

local function assertExecutionValid(document: string)
	local failures = executionFailures(document)
	assert(#failures == 0, "execution.md contract failures:\n" .. table.concat(failures, "\n"))
end

local function assertExecutionInvalid(document: string, expected: string)
	for _, failure in executionFailures(document) do
		if string.find(failure, expected, 1, true) ~= nil then
			return
		end
	end
	assert(false, "expected execution contract failure containing: " .. expected)
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
	".agents/templates/visions.md",
	".agents/templates/execution.md",
})
assertContainsTargets("README.md", { "docs/README.md" })

local function assertVisionsStructure(path: string): Sections
	local visions = secondLevelSections(fs.readFileToString(path))
	assert(visions.bodies["## Outcomes"] ~= nil, path .. " is missing ## Outcomes")
	assert(visions.bodies["## Boundaries"] ~= nil, path .. " is missing ## Boundaries")
	assert(#visions.order == 2, path .. " supports only ## Outcomes and ## Boundaries")
	assert(visions.order[1] == "## Outcomes", path .. " must begin with ## Outcomes")
	assert(visions.order[2] == "## Boundaries", path .. " must end with ## Boundaries")
	return visions
end

local visionsTemplate = assertVisionsStructure(".agents/templates/visions.md")
assert(not hasContent(visionsTemplate.bodies["## Outcomes"]), "visions template outcomes must remain unfilled")
assert(not hasContent(visionsTemplate.bodies["## Boundaries"]), "visions template boundaries must remain unfilled")

local executionTemplate = fs.readFileToString(".agents/templates/execution.md")
assertExecutionValid(executionTemplate)
local executionTemplateSections = secondLevelSections(executionTemplate)
for _, heading in EXECUTION_CORE do
	assert(
		not hasContent(executionTemplateSections.bodies[heading]),
		"execution template must remain unfilled: " .. heading
	)
end
assert(executionTemplateSections.bodies["## Blocking Condition"] == nil, "execution template cannot start blocked")
assert(
	string.find(stripHtmlComments(executionTemplate), "## Later", 1, true) == nil,
	"execution template cannot include ## Later"
)
assert(
	string.find(stripHtmlComments(executionTemplate), "## Last Checkpoint", 1, true) == nil,
	"execution template cannot include ## Last Checkpoint"
)

local activeFixture = [[
# Execution
## Status
active
## Objective
Ship observable behavior.
## Priority Outcomes
- The behavior works.
## Hotspots
- `src/shared/Feature/init.luau` — Defines the behavior contract.
]]
assertExecutionValid(activeFixture)
assertExecutionInvalid(string.gsub(activeFixture, "active", "paused", 1), "status must be active or blocked")
assertExecutionInvalid(string.gsub(activeFixture, "Ship observable behavior%.", "", 1), "requires an objective")
assertExecutionInvalid(
	string.gsub(activeFixture, "`src/shared/Feature/init%.luau` — Defines the behavior contract%.", "Feature code", 1),
	"hotspot entries"
)

local blockedFixture = [[
# Execution
## Status
blocked
## Objective
## Priority Outcomes
## Hotspots
## Blocking Condition
- Cause: Required decision is unavailable.
- Owner: Product owner.
- Unblock when: The product direction is recorded.
]]
assertExecutionValid(blockedFixture)
assertExecutionInvalid(string.gsub(blockedFixture, "%- Owner: Product owner%.\n", "", 1), "non-empty Owner")

print(string.format("[documentation] %d active documents and both indexes passed", #activeDocuments))
