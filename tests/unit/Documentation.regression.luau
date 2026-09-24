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
}

local function secondLevelSections(document: string): Sections
	local bodies: { [string]: string } = {}
	local current: string? = nil
	local lines: { string } = {}

	local function finishSection()
		if current ~= nil then
			assert(bodies[current] == nil, "duplicate documentation section: " .. current)
			bodies[current] = table.concat(lines, "\n")
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

	return { bodies = bodies }
end

local function hasContent(value: string?): boolean
	return value ~= nil and trim(value) ~= ""
end

local function appendFailure(failures: { string }, condition: boolean, message: string)
	if not condition then
		table.insert(failures, message)
	end
end

local function visionCatalog(document: string): ({ [string]: boolean }, { string })
	local sections = secondLevelSections(document)
	local failures: { string } = {}
	local outcomes = sections.bodies["## Outcomes"] or ""
	appendFailure(failures, sections.bodies["## Outcomes"] ~= nil, "vision requires an Outcomes section")

	local ids: { [string]: boolean } = {}
	local described: { [string]: boolean } = {}
	local current: string? = nil
	for line in string.gmatch(outcomes .. "\n", "(.-)\n") do
		local id, title = string.match(line, "^### (V%d+) — (.+)$")
		if id ~= nil then
			appendFailure(failures, ids[id] == nil, "duplicate outcome " .. id)
			ids[id] = true
			current = id
			appendFailure(failures, trim(title) ~= "", "empty outcome title " .. id)
		elseif string.match(line, "^### ") then
			table.insert(failures, "malformed outcome heading: " .. line)
		elseif current ~= nil and trim(line) ~= "" then
			described[current] = true
		end
	end
	for id in ids do
		appendFailure(failures, described[id] == true, "outcome lacks a description: " .. id)
	end
	return ids, failures
end

local function completedMilestones(document: string): (number, { string })
	local sections = secondLevelSections(document)
	local failures: { string } = {}
	appendFailure(failures, sections.bodies["## Completed Milestones"] ~= nil, "progress requires completed milestones")
	local records = sections.bodies["## Completed Milestones"] or ""
	local count = 0
	local fields: { [string]: string } = {}

	local function finishRecord()
		if count == 0 then
			return
		end
		for _, field in { "Completed", "Result", "Verification" } do
			appendFailure(failures, hasContent(fields[field]), string.format("M%03d lacks %s", count, field))
		end
		appendFailure(
			failures,
			string.match(fields.Completed or "", "^%d%d%d%d%-%d%d%-%d%d$") ~= nil,
			string.format("M%03d requires an ISO completion date", count)
		)
	end

	for line in string.gmatch(records .. "\n", "(.-)\n") do
		local id, number = string.match(line, "^### (M(%d%d%d)) — .+$")
		if id ~= nil then
			finishRecord()
			count += 1
			appendFailure(failures, tonumber(number) == count, "completed milestone IDs must be contiguous: " .. id)
			fields = {}
		elseif string.match(line, "^### ") then
			table.insert(failures, "malformed completed milestone heading: " .. line)
		elseif count > 0 then
			local field, value = string.match(line, "^%- ([^:]+):%s*(.-)%s*$")
			if field ~= nil then
				appendFailure(failures, fields[field] == nil, "duplicate milestone field: " .. field)
				fields[field] = value
			end
		end
	end
	finishRecord()
	return count, failures
end

local function archiveStructureFailures(path: string, record: string): { string }
	local failures: { string } = {}
	local fileId = string.match(path, "^%.agents/progress/(M%d%d%d)%-[a-z0-9-]+%.md$")
	appendFailure(failures, fileId ~= nil, "invalid milestone archive path: " .. path)
	local headingId = string.match(record, "^# (M%d%d%d) — [^\r\n]+")
	appendFailure(failures, headingId ~= nil, "invalid milestone archive heading: " .. path)
	appendFailure(failures, fileId == headingId, "milestone archive ID mismatch: " .. path)
	appendFailure(
		failures,
		string.find(record, "\n#+ M%d%d%d — ") == nil,
		"milestone archive contains more than one record: " .. path
	)
	return failures
end

local function archivedMilestones(paths: { string }): (number, { string })
	local failures: { string } = {}
	local records: { string } = {}
	table.sort(paths)
	for _, path in paths do
		local record = fs.readFileToString(path)
		append(failures, archiveStructureFailures(path, record))
		local combinedRecord = string.gsub(record, "^# ", "### ", 1)
		table.insert(records, combinedRecord)
	end
	local count, recordFailures =
		completedMilestones("# Progress\n## Completed Milestones\n" .. table.concat(records, "\n"))
	append(failures, recordFailures)
	appendFailure(failures, count == #paths, "milestone archive must contain one record per file")
	return count, failures
end

local function latestMilestoneFailures(document: string, paths: { string }): { string }
	local sections = secondLevelSections(document)
	local failures: { string } = {}
	local latest = sections.bodies["## Latest Completed Milestone"]
	appendFailure(failures, latest ~= nil, "progress requires latest completed milestone section")
	appendFailure(
		failures,
		sections.bodies["## Completed Milestones"] == nil,
		"progress must keep history in milestone files"
	)
	if #paths == 0 then
		appendFailure(failures, not hasContent(latest), "empty milestone history requires an empty latest link")
		return failures
	end
	local id, linkedTitle, target = string.match(trim(latest or ""), "^%[M(%d%d%d) — ([^%]]+)%]%(([^%)]+)%)$")
	appendFailure(failures, id ~= nil, "latest milestone requires one titled link")
	appendFailure(failures, tonumber(id) == #paths, "latest milestone ID must match archive history")
	local expected = string.gsub(paths[#paths], "^%.agents/", "")
	appendFailure(failures, target == expected, "latest milestone link must target the newest archive record")
	local newestTitle = string.match(fs.readFileToString(paths[#paths]), "^# M%d%d%d — ([^\r\n]+)")
	appendFailure(failures, linkedTitle == newestTitle, "latest milestone title must match the archive record")
	return failures
end

local function outcomeDecisions(document: string, visionOutcomes: { [string]: boolean }): { string }
	local records = secondLevelSections(document).bodies["## Outcome Decisions"]
	local failures: { string } = {}
	if records == nil then
		return failures
	end

	local seen: { [string]: boolean } = {}
	local current: string? = nil
	local fields: { [string]: string } = {}

	local function finishRecord()
		if current == nil then
			return
		end
		appendFailure(failures, hasContent(fields.Decided), current .. " lacks Decided")
		appendFailure(failures, hasContent(fields.Basis), current .. " lacks Basis")
		appendFailure(
			failures,
			string.match(fields.Decided or "", "^%d%d%d%d%-%d%d%-%d%d$") ~= nil,
			current .. " requires an ISO decision date"
		)
	end

	for line in string.gmatch(records .. "\n", "(.-)\n") do
		local id, decision = string.match(line, "^### (V%d+) — (.+)$")
		if id ~= nil then
			finishRecord()
			appendFailure(failures, seen[id] == nil, "duplicate outcome decision " .. id)
			appendFailure(
				failures,
				decision == "complete" or decision == "retired",
				"invalid outcome decision: " .. line
			)
			if decision == "complete" then
				appendFailure(failures, visionOutcomes[id] == true, "completed outcome missing from visions: " .. id)
			elseif decision == "retired" then
				appendFailure(failures, visionOutcomes[id] == nil, "retired outcome remains in visions: " .. id)
			end
			seen[id] = true
			current = id
			fields = {}
		elseif string.match(line, "^### ") then
			table.insert(failures, "malformed outcome decision heading: " .. line)
		elseif current ~= nil then
			local field, value = string.match(line, "^%- ([^:]+):%s*(.-)%s*$")
			if field ~= nil then
				appendFailure(failures, fields[field] == nil, "duplicate outcome decision field: " .. field)
				fields[field] = value
			end
		end
	end
	finishRecord()
	return failures
end

local function executionFailures(document: string, outcomes: { [string]: boolean }, completed: number): { string }
	local sections = secondLevelSections(document)
	local failures: { string } = {}
	for _, heading in { "## Milestone", "## Status", "## Objective", "## Hotspots" } do
		appendFailure(failures, sections.bodies[heading] ~= nil, "missing execution section: " .. heading)
	end
	for _, heading in { "## Later", "## Last Checkpoint" } do
		appendFailure(failures, sections.bodies[heading] == nil, "unsupported execution section: " .. heading)
	end

	local milestone = trim(sections.bodies["## Milestone"] or "")
	local status = trim(sections.bodies["## Status"] or "")
	local objective = sections.bodies["## Objective"]
	local context = sections.bodies["## Outcome Context"]
	local blocking = sections.bodies["## Blocking Condition"]
	local hotspots = sections.bodies["## Hotspots"]
	local populated = false
	for _, body in sections.bodies do
		if hasContent(body) then
			populated = true
			break
		end
	end
	if not populated then
		appendFailure(failures, blocking == nil, "unfilled execution cannot have a blocking condition")
		return failures
	end

	appendFailure(failures, status == "active" or status == "blocked", "execution status must be active or blocked")

	if status == "active" or status == "blocked" then
		appendFailure(
			failures,
			milestone == string.format("M%03d", completed + 1),
			"current milestone must follow completed history"
		)
		appendFailure(failures, hasContent(objective), "populated execution requires an objective")
		appendFailure(
			failures,
			status == "blocked" or blocking == nil,
			"active milestone cannot have a blocking condition"
		)
		if status == "blocked" then
			appendFailure(failures, hasContent(blocking), "blocked milestone requires a blocking condition")
			local fields: { [string]: boolean } = {
				Cause = false,
				Owner = false,
				["Unblock when"] = false,
			}
			for line in string.gmatch((blocking or "") .. "\n", "(.-)\n") do
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
	for line in string.gmatch((hotspots or "") .. "\n", "(.-)\n") do
		if trim(line) ~= "" then
			local entry, explanation = string.match(line, "^%- `([^`]+)` — (.+)$")
			appendFailure(
				failures,
				entry ~= nil and trim(entry) ~= "" and explanation ~= nil and trim(explanation) ~= "",
				"hotspot entries must use `path or symbol` — explanation"
			)
		end
	end

	local tick = string.char(96)
	for line in string.gmatch((context or "") .. "\n", "(.-)\n") do
		if trim(line) ~= "" then
			local id = string.match(line, "^%- " .. tick .. "(V%d+)" .. tick .. " — .+$")
			appendFailure(
				failures,
				id ~= nil and outcomes[id] == true,
				"execution references an unknown outcome: " .. line
			)
		end
	end
	return failures
end

local function assertFailure(failures: { string }, expected: string)
	for _, failure in failures do
		if string.find(failure, expected, 1, true) ~= nil then
			return
		end
	end
	assert(false, "expected failure containing " .. expected .. "; got: " .. table.concat(failures, "; "))
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

local milestoneDocuments: { string } = {}
collectMarkdown(".agents/progress", milestoneDocuments)

local projectDocuments: { string } = {}
collectMarkdown("docs", projectDocuments)
table.insert(projectDocuments, "tooling/roblox/README.md")

local continuityDocuments = {
	".agents/visions.md",
	".agents/execution.md",
	".agents/progress.md",
	".agents/templates/visions.md",
	".agents/templates/execution.md",
}

local activeDocuments = { "AGENTS.md", "README.md" }
append(activeDocuments, agentDocuments)
append(activeDocuments, projectDocuments)
append(activeDocuments, continuityDocuments)
append(activeDocuments, milestoneDocuments)
assertLinksExist(activeDocuments)

local agentIndexed: { string } = {}
for _, path in agentDocuments do
	if path ~= ".agents/docs/README.md" then
		table.insert(agentIndexed, path)
	end
end
append(agentIndexed, continuityDocuments)
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
	".agents/docs/continuity.md",
	".agents/execution.md",
	".agents/visions.md",
	".agents/progress.md",
	".agents/roblox/structure.md",
	"docs/README.md",
})
assertContainsTargets("README.md", { "docs/README.md" })
assertContainsTargets(".agents/docs/continuity.md", {
	".agents/execution.md",
	".agents/visions.md",
	".agents/progress.md",
	".agents/templates/execution.md",
	".agents/templates/visions.md",
})

local visionTemplate = secondLevelSections(fs.readFileToString(".agents/templates/visions.md"))
for _, heading in { "## Outcomes", "## Boundaries" } do
	assert(visionTemplate.bodies[heading] ~= nil, "vision template lacks " .. heading)
	assert(not hasContent(visionTemplate.bodies[heading]), "vision template is prefilled: " .. heading)
end
local executionTemplate = secondLevelSections(fs.readFileToString(".agents/templates/execution.md"))
for _, heading in { "## Milestone", "## Status", "## Objective", "## Questions", "## Hotspots" } do
	assert(executionTemplate.bodies[heading] ~= nil, "execution template lacks " .. heading)
	assert(not hasContent(executionTemplate.bodies[heading]), "execution template is prefilled: " .. heading)
end
assert(
	#executionFailures(fs.readFileToString(".agents/templates/execution.md"), {}, 0) == 0,
	"unfilled execution scaffold is invalid"
)

local visionFixture = [[
# Visions
## Outcomes
### V1 — First outcome
One observable capability.
### V9 — Candidate outcome
Another capability; numbering need not predict intervening work.
## Boundaries
- Integrity matters.
]]
local fixtureOutcomes, fixtureVisionFailures = visionCatalog(visionFixture)
assert(#fixtureVisionFailures == 0, table.concat(fixtureVisionFailures, "\n"))
local _, outcomesOnlyFailures = visionCatalog([[# Visions
## Outcomes
### V1 — Current direction
One observable capability.
]])
assert(#outcomesOnlyFailures == 0, "vision required optional boundaries")
local emptyCatalog, emptyCatalogFailures = visionCatalog("# Visions\n## Outcomes\n")
assert(next(emptyCatalog) == nil and #emptyCatalogFailures == 0, "an empty vision catalog was rejected")
local _, duplicateOutcomeFailures = visionCatalog(string.gsub(visionFixture, "V9", "V1", 1))
assertFailure(duplicateOutcomeFailures, "duplicate outcome")

local progressFixture = [[
# Progress
## Observations
- An observed fact with evidence.
## Open Questions
## Completed Milestones
### M001 — First result
- Completed: 2026-09-22
- Result: A capability was delivered.
- Verification: Focused and canonical checks passed.
]]
local fixtureCompleted, fixtureProgressFailures = completedMilestones(progressFixture)
assert(#fixtureProgressFailures == 0, table.concat(fixtureProgressFailures, "\n"))
local blankHandoffFixture = [[# Execution
## Milestone
## Status
## Objective
## Hotspots
]]
assert(
	#executionFailures(blankHandoffFixture, fixtureOutcomes, fixtureCompleted) == 0,
	"unfilled execution after a completed move was rejected"
)
assertFailure(
	executionFailures(
		string.gsub(blankHandoffFixture, "## Milestone\n", "## Milestone\nM002\n", 1),
		fixtureOutcomes,
		fixtureCompleted
	),
	"status must be active or blocked"
)
local minimalCompleted, minimalProgressFailures = completedMilestones([[# Progress
## Completed Milestones
### M001 — First result
- Completed: 2026-09-22
- Result: A capability was delivered.
- Verification: Focused and canonical checks passed.
]])
assert(minimalCompleted == 1 and #minimalProgressFailures == 0, "progress required optional sections")
local _, skippedHistoryFailures = completedMilestones(string.gsub(progressFixture, "M001", "M002", 1))
assertFailure(skippedHistoryFailures, "must be contiguous")

local archiveFixture = [[# M001 — First result
- Completed: 2026-09-22
- Result: A capability was delivered.
- Verification: Focused and canonical checks passed.
]]
local archivePath = ".agents/progress/M001-first-result.md"
assert(#archiveStructureFailures(archivePath, archiveFixture) == 0, "valid milestone archive was rejected")
for _, heading in { "# M002 — Second result", "### M002 — Second result" } do
	assertFailure(
		archiveStructureFailures(archivePath, archiveFixture .. "\n" .. heading .. "\n"),
		"more than one record"
	)
end

local decisionFixture = [[# Progress
## Outcome Decisions
### V9 — complete
- Decided: 2026-09-22
- Basis: Runtime evidence covers the whole capability.
### V10 — retired
- Decided: 2026-09-22
- Basis: User changed product direction.
]]
assert(#outcomeDecisions(decisionFixture, { V9 = true }) == 0, "valid outcome decisions failed")
assertFailure(outcomeDecisions(decisionFixture, {}), "completed outcome missing from visions")
assertFailure(outcomeDecisions(decisionFixture, { V9 = true, V10 = true }), "retired outcome remains in visions")
assertFailure(
	outcomeDecisions(string.gsub(decisionFixture, "V10", "V9", 1), { V9 = true }),
	"duplicate outcome decision"
)
assertFailure(
	outcomeDecisions(string.gsub(decisionFixture, "retired", "planned", 1), { V9 = true }),
	"invalid outcome decision"
)
assertFailure(
	outcomeDecisions(string.gsub(decisionFixture, "Runtime evidence covers the whole capability.", "", 1), {}),
	"lacks Basis"
)

local executionFixture = [[
# Execution
## Milestone
M002
## Status
active
## Objective
Prove one next capability.
## Outcome Context
- `V1` — Relevant direction.
## Questions
- Which boundary works?
## Completion Checks
- Accepted work is observable.
## Verification
- Repository: focused tests and canonical gate.
- Studio: determine from runtime changes.
## Hotspots
- `src/example.luau` — Entry point.
]]
assert(#executionFailures(executionFixture, fixtureOutcomes, fixtureCompleted) == 0, "valid active execution failed")
local discoveryFixture = [[
# Execution
## Milestone
M002
## Status
active
## Objective
Determine which observed contract permits the next move.
## Hotspots
]]
assert(
	#executionFailures(discoveryFixture, fixtureOutcomes, fixtureCompleted) == 0,
	"valid discovery execution required speculative fields"
)
assertFailure(
	executionFailures(string.gsub(executionFixture, "M002", "M003", 1), fixtureOutcomes, fixtureCompleted),
	"must follow completed history"
)
assertFailure(
	executionFailures(string.gsub(executionFixture, "V1", "V99", 1), fixtureOutcomes, fixtureCompleted),
	"unknown outcome"
)
for _, status in { "ready", "complete", "paused" } do
	assertFailure(
		executionFailures(string.gsub(executionFixture, "active", status, 1), fixtureOutcomes, fixtureCompleted),
		"status must be active or blocked"
	)
end
assertFailure(
	executionFailures(
		string.gsub(executionFixture, "Prove one next capability%.", "", 1),
		fixtureOutcomes,
		fixtureCompleted
	),
	"requires an objective"
)
assertFailure(
	executionFailures(
		string.gsub(executionFixture, "`src/example%.luau` — Entry point%.", "Feature code", 1),
		fixtureOutcomes,
		fixtureCompleted
	),
	"hotspot entries"
)
for _, heading in { "## Later", "## Last Checkpoint" } do
	assertFailure(
		executionFailures(executionFixture .. "\n" .. heading .. "\n", fixtureOutcomes, fixtureCompleted),
		"unsupported execution section"
	)
end

local blockedFixture = [[
# Execution
## Milestone
M002
## Status
blocked
## Objective
Resolve the required product decision before implementing the next capability.
## Hotspots
- `src/example.luau` — Relevant entry point after the decision.
## Blocking Condition
- Cause: Required direction is unavailable.
- Owner: Product owner.
- Unblock when: The product direction is recorded.
]]
assert(#executionFailures(blockedFixture, fixtureOutcomes, fixtureCompleted) == 0, "valid blocked execution failed")
assertFailure(
	executionFailures(
		string.gsub(blockedFixture, "%- Owner: Product owner%.\n", "", 1),
		fixtureOutcomes,
		fixtureCompleted
	),
	"non-empty Owner"
)
for field, pattern in
	{
		Cause = "%- Cause: Required direction is unavailable%.\n",
		["Unblock when"] = "%- Unblock when: The product direction is recorded%.\n",
	}
do
	assertFailure(
		executionFailures(string.gsub(blockedFixture, pattern, "", 1), fixtureOutcomes, fixtureCompleted),
		"non-empty " .. field
	)
end
assertFailure(
	executionFailures(string.gsub(blockedFixture, "blocked", "active", 1), fixtureOutcomes, fixtureCompleted),
	"active milestone cannot have a blocking condition"
)

local activeVision = fs.readFileToString(".agents/visions.md")
local activeOutcomes, visionFailures = visionCatalog(activeVision)
assert(#visionFailures == 0, "active vision failures:\n" .. table.concat(visionFailures, "\n"))

local activeProgress = fs.readFileToString(".agents/progress.md")
local completed, progressFailures = archivedMilestones(milestoneDocuments)
assert(#progressFailures == 0, "active progress failures:\n" .. table.concat(progressFailures, "\n"))
local latestFailures = latestMilestoneFailures(activeProgress, milestoneDocuments)
assert(#latestFailures == 0, "active latest milestone failures:\n" .. table.concat(latestFailures, "\n"))
local decisionFailures = outcomeDecisions(activeProgress, activeOutcomes)
assert(#decisionFailures == 0, "active outcome decision failures:\n" .. table.concat(decisionFailures, "\n"))

local activeExecution = fs.readFileToString(".agents/execution.md")
local activeExecutionFailures = executionFailures(activeExecution, activeOutcomes, completed)
assert(#activeExecutionFailures == 0, "active execution failures:\n" .. table.concat(activeExecutionFailures, "\n"))

print(
	string.format("[documentation] %d active documents passed link and continuity structure checks", #activeDocuments)
)
