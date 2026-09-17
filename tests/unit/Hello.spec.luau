--!strict

local Lest = require("@lest")
local describe, it, expect = Lest.describe, Lest.it, Lest.expect

local hello = require("../../src/shared/Hello")

describe("Hello", function()
	it("exports a callable module", function()
		expect(type(hello)).toBe("function")
	end)
end)

return nil
