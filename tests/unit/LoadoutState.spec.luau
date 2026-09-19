--!strict

local Lest = require("@lest")
local describe, it, expect = Lest.describe, Lest.it, Lest.expect

local StateMachine = require("../../src/shared/Loadout/StateMachine")
local Validator = require("../../src/shared/Loadout/Validator")

describe("session loadout behavior", function()
	it("does not equip a selection that is closed without confirmation", function()
		local state = StateMachine.setOpen(StateMachine.initial(), true)
		state = StateMachine.select(state, "arc-shield")
		state = StateMachine.setOpen(state, false)

		expect(state.equippedId).toBe("pulse-carbine")
		expect(state.pendingRequestId).toBe(nil)
	end)

	it("blocks locked and duplicate submissions", function()
		local state = StateMachine.setOpen(StateMachine.initial(), true)
		state = StateMachine.select(state, "grav-hammer")
		expect(StateMachine.canEquip(state)).toBe(false)

		state = StateMachine.select(state, "arc-shield")
		state = StateMachine.beginEquip(state, "request-1")
		expect(state.pendingRequestId).toBe("request-1")
		expect(StateMachine.beginEquip(state, "request-2")).toBe(state)
	end)

	it("retains an in-flight acknowledgement while closed", function()
		local state = StateMachine.setOpen(StateMachine.initial(), true)
		state = StateMachine.select(state, "recon-drone")
		state = StateMachine.beginEquip(state, "request-1")
		state = StateMachine.setOpen(state, false)
		state = StateMachine.resolveEquip(state, "request-1", true, "recon-drone", "Equipped Recon Drone.")

		expect(state.isOpen).toBe(false)
		expect(state.equippedId).toBe("recon-drone")
		expect(state.feedback).toBe("success")
		expect(StateMachine.setOpen(state, true).equippedId).toBe("recon-drone")
	end)

	it("ignores stale feedback but accepts authoritative equipment state", function()
		local state = StateMachine.setOpen(StateMachine.initial(), true)
		state = StateMachine.select(state, "arc-shield")
		state = StateMachine.beginEquip(state, "request-new")
		state = StateMachine.resolveEquip(state, "request-old", true, "field-medkit", "Old response")

		expect(state.pendingRequestId).toBe("request-new")
		expect(state.feedback).toBe("pending")
		expect(state.equippedId).toBe("field-medkit")
	end)

	it("validates locked, unknown, malformed, and available requests on the server", function()
		local accepted = Validator.validate("request-1", "arc-shield")
		expect(accepted).toBe(true)
		local locked = Validator.validate("request-2", "grav-hammer")
		expect(locked).toBe(false)
		local unknown = Validator.validate("request-3", "not-real")
		expect(unknown).toBe(false)
		local malformed = Validator.validate("", "arc-shield")
		expect(malformed).toBe(false)
	end)
end)

return nil
