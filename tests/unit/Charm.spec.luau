--!strict

local Lest = require("@lest")
local describe, it, expect = Lest.describe, Lest.it, Lest.expect

local Charm = require("../../Packages/_Index/littensy_charm@0.11.0/charm/src/init")

describe("Charm", function()
	it("updates a computed value from a signal", function()
		local getCount, setCount = Charm.signal(2)
		local getDoubledCount = Charm.computed(function()
			return getCount() * 2
		end)

		expect(getDoubledCount()).toBe(4)

		setCount(function(count)
			return count + 1
		end)

		expect(getCount()).toBe(3)
		expect(getDoubledCount()).toBe(6)
	end)
end)

return nil
