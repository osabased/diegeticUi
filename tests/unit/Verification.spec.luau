--!strict

local Lest = require("@lest")
local describe, it, expect = Lest.describe, Lest.it, Lest.expect

local Verification = require("../../scripts/verification")

type Report = Verification.Report
type StageRecord = Verification.StageRecord
type StepName = Verification.StepName

local function planNames(arguments: { string }): string
	local selection, parseError = Verification.parseArguments(arguments)
	assert(selection ~= nil, parseError)
	return table.concat(Verification.plan(selection), ",")
end

local function findRecord(report: Report, name: StepName): StageRecord
	for _, record in report.stages do
		if record.name == name then
			return record
		end
	end
	error("missing record: " .. name)
end

describe("verification planning", function()
	it("closes dependencies and preserves canonical order", function()
		expect(planNames({ "--stage", "analyze", "--stage", "lint" })).toBe(
			"preflight,wally,sourcemap,package_types,lest_core,lint,analyze"
		)
		expect(planNames({ "--stage", "build", "--stage", "unit" })).toBe("preflight,wally,unit,build")
		expect(planNames({ "--stage", "studio" })).toBe("preflight,wally,build,studio")
	end)

	it("deduplicates repeated stages", function()
		local selection, parseError = Verification.parseArguments({
			"--stage",
			"analyze",
			"--stage",
			"analyze",
		})
		assert(selection ~= nil, parseError)
		expect(table.concat(selection.selectedStages, ",")).toBe("analyze")
		expect(planNames({ "--stage", "analyze", "--stage", "analyze" })).toBe(
			"preflight,wally,sourcemap,package_types,lest_core,analyze"
		)
	end)

	it("rejects invalid arguments", function()
		local missingSelection, missingError = Verification.parseArguments({ "--stage" })
		expect(missingSelection).toBe(nil)
		expect(missingError).toBe("--stage requires a stage name")

		local unknownSelection, unknownError = Verification.parseArguments({ "--stage", "deploy" })
		expect(unknownSelection).toBe(nil)
		expect(unknownError).toBe("unknown stage: deploy")

		local flagSelection, flagError = Verification.parseArguments({ "--all" })
		expect(flagSelection).toBe(nil)
		expect(flagError).toBe("unknown argument: --all")
	end)

	it("finalizes reports and cleanup across injected failures", function()
		local focusedSelection = assert(Verification.parseArguments({ "--stage", "format" }))

		local function newFocusedReport(): Report
			return Verification.newReport(focusedSelection, "focused")
		end

		local initialFailureReport = newFocusedReport()
		local initialRunnerCalls = 0
		local initialCleanupCalls = 0
		local initialResult = Verification.orchestrate(
			initialFailureReport,
			Verification.plan(focusedSelection),
			function()
				initialRunnerCalls += 1
				return { ok = true }
			end,
			function()
				return 0
			end,
			function()
				error("injected initial write failure")
			end,
			function()
				initialCleanupCalls += 1
			end
		)
		expect(initialResult.ok).toBe(false)
		expect(initialRunnerCalls).toBe(0)
		expect(initialCleanupCalls).toBe(1)
		expect(initialFailureReport.errors[1].kind).toBe("report")

		local clockFailureReport = newFocusedReport()
		local clockCleanupCalls = 0
		local clockResult = Verification.orchestrate(clockFailureReport, Verification.plan(focusedSelection), function()
			return { ok = true }
		end, function()
			error("injected clock failure")
		end, function() end, function()
			clockCleanupCalls += 1
		end)
		expect(clockResult.ok).toBe(false)
		expect(clockCleanupCalls).toBe(1)
		expect(clockFailureReport.errors[1].kind).toBe("orchestration")

		local cleanupFailureReport = newFocusedReport()
		local cleanupResult = Verification.orchestrate(
			cleanupFailureReport,
			Verification.plan(focusedSelection),
			function()
				return { ok = true }
			end,
			function()
				return 0
			end,
			function() end,
			function()
				error("injected cleanup failure")
			end
		)
		expect(cleanupResult.ok).toBe(false)
		expect(cleanupFailureReport.errors[1].kind).toBe("cleanup")
		expect(Verification.resultMessage(cleanupFailureReport)).toBe("[verify] FAILED")
	end)

	it("preserves passed stages when report updates or final writes fail", function()
		local buildSelection = assert(Verification.parseArguments({ "--stage", "build" }))
		local buildReport = Verification.newReport(buildSelection, "build")
		local updateWrites = 0
		local cleanupCalls = 0
		local updateResult = Verification.orchestrate(buildReport, Verification.plan(buildSelection), function()
			return { ok = true }
		end, function()
			return 0
		end, function()
			updateWrites += 1
			if updateWrites == 4 then
				error("injected post-build report failure")
			end
		end, function()
			cleanupCalls += 1
		end)
		expect(updateResult.ok).toBe(false)
		expect(cleanupCalls).toBe(1)
		expect(findRecord(buildReport, "build").status).toBe("passed")
		expect(buildReport.errors[1].kind).toBe("report")

		local formatSelection = assert(Verification.parseArguments({ "--stage", "format" }))
		local finalReport = Verification.newReport(formatSelection, "final")
		local finalWrites = 0
		local finalResult = Verification.orchestrate(finalReport, Verification.plan(formatSelection), function()
			return { ok = true }
		end, function()
			return 0
		end, function()
			finalWrites += 1
			if finalWrites == 4 then
				error("injected final report failure")
			end
		end, function() end)
		expect(finalResult.ok).toBe(false)
		expect(finalResult.durableReport).toBe(true)
		expect(finalResult.finalReportPersisted).toBe(false)
		expect(findRecord(finalReport, "format").status).toBe("passed")
		expect(finalReport.errors[1].kind).toBe("report")
		expect(Verification.resultMessage(finalReport)).toBe("[verify] FAILED")
	end)
end)

describe("verification execution", function()
	it("stops after a failure and records blocked stages", function()
		local selection = assert(Verification.parseArguments({ "--stage", "analyze" }))
		local plan = Verification.plan(selection)
		local report = Verification.newReport(selection, "2026-09-18T00:00:00.000Z")
		local calls: { StepName } = {}
		local clockValue = 0

		Verification.execute(report, plan, function(step)
			table.insert(calls, step)
			if step == "sourcemap" then
				return {
					ok = false,
					exitCode = 7,
					reason = "injected failure",
				}
			end
			return { ok = true }
		end, function()
			clockValue += 0.001
			return clockValue
		end)

		expect(table.concat(calls, ",")).toBe("preflight,wally,sourcemap")
		expect(report.outcome).toBe("failed")
		expect(findRecord(report, "sourcemap").exitCode).toBe(7)
		expect(findRecord(report, "package_types").reason).toBe("blocked_by:sourcemap")
		expect(findRecord(report, "analyze").reason).toBe("blocked_by:sourcemap")
		expect(findRecord(report, "format").reason).toBe("unselected")
	end)

	it("distinguishes full and focused success", function()
		local fullSelection = assert(Verification.parseArguments({}))
		local fullReport = Verification.newReport(fullSelection, "full")
		Verification.execute(fullReport, Verification.plan(fullSelection), function()
			return { ok = true }
		end, function()
			return 0
		end)
		expect(Verification.resultMessage(fullReport)).toBe("[verify] PASS")

		local focusedSelection = assert(Verification.parseArguments({ "--stage", "build" }))
		local focusedReport = Verification.newReport(focusedSelection, "focused")
		Verification.execute(focusedReport, Verification.plan(focusedSelection), function()
			return { ok = true }
		end, function()
			return 0
		end)
		expect(Verification.resultMessage(focusedReport)).toBe("[verify] SELECTED STAGES PASS — full gate not run")
		expect(findRecord(focusedReport, "unit").reason).toBe("unselected")
	end)
end)

return nil
