--!strict
--# selene: allow(incorrect_standard_library_use)

local Lest = require("@lest")
local describe, it = Lest.describe, Lest.it

local Fixture = require("../../.agents/skills/roblox-fusion/fixtures/FusionIntegrationFixture")

local function formatFailure(result: Fixture.Result): string
	local failed: { string } = {}
	for name, passed in result.checks do
		if not passed then
			table.insert(failed, tostring(name))
		end
	end
	table.sort(failed)
	return `error={result.error or "none"}; failed={table.concat(failed, ",")}; diagnostics={table.concat(
		result.diagnostics,
		" | "
	)}`
end

describe("Fusion 0.3 maintained integration fixture", function()
	it("updates reactive UI and cleans successful and failed construction", function()
		local holder = Instance.new("ScreenGui")
		local result = Fixture.run(holder)
		local failure = if result.ok then "" else formatFailure(result)
		holder:Destroy()

		assert(result.ok, failure)
	end)
end)

return nil
