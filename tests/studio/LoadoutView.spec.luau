--!strict
--# selene: allow(incorrect_standard_library_use)

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Lest = require("@lest")
local describe, it, expect = Lest.describe, Lest.it, Lest.expect

local Fusion = require(ReplicatedStorage.Packages.Fusion)
local StateMachine = require(ReplicatedStorage.Shared.Loadout.StateMachine)
local View = require(ReplicatedStorage.Client.Loadout.View)

describe("loadout Fusion view", function()
	it("renders selection, pending feedback, and cleanup", function()
		local holder = Instance.new("Folder")
		local scope = Fusion.scoped(Fusion)
		local current = StateMachine.setOpen(StateMachine.initial(), true)
		current = StateMachine.select(current, "arc-shield")
		local state = scope:Value(current)

		local root = View.create(scope, holder, state, {
			onToggle = function() end,
			onClose = function() end,
			onSelect = function() end,
			onEquip = function() end,
		})
		local panel = root:FindFirstChild("LoadoutPanel")
		expect(panel ~= nil).toBe(true)
		local equip = root:FindFirstChild("Equip", true)
		assert(equip ~= nil and equip:IsA("TextButton"), "expected an Equip TextButton")
		expect(equip.Text).toBe("EQUIP FOR THIS SESSION")

		current = StateMachine.beginEquip(current, "studio-request")
		state:set(current)
		task.wait()
		expect(equip.Text).toBe("EQUIPPING…")
		expect(equip.Active).toBe(false)

		Fusion.doCleanup(scope)
		expect(#holder:GetChildren()).toBe(0)
		holder:Destroy()
	end)
end)

return nil
