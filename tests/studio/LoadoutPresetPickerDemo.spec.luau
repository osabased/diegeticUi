--!strict
--# selene: allow(incorrect_standard_library_use)

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Lest = require("@lest")
local describe, it, expect = Lest.describe, Lest.it, Lest.expect

local Domain = require(ReplicatedStorage.Client.Loadout.PresetPickerDemo.Domain)
local Mount = require(ReplicatedStorage.Client.Loadout.PresetPickerDemo.Mount)

local PRESETS: { Domain.Preset } = {
	{
		id = "breacher",
		name = "Breach & Clear",
		description = "Close-range entry kit.",
		slots = "SHOTGUN / FLASH",
		accent = Color3.fromRGB(255, 177, 92),
		order = 1,
	},
	{
		id = "recon",
		name = "Ghost Recon",
		description = "Quiet scout package with a drone.",
		slots = "DRONE / DMR",
		accent = Color3.fromRGB(83, 214, 231),
		order = 2,
	},
	{
		id = "field-medic",
		name = "Field Medic",
		description = "Support preset for the squad.",
		slots = "MEDKIT / SMG",
		accent = Color3.fromRGB(105, 220, 153),
		order = 3,
	},
}

local function findLabel(root: Instance, name: string): TextLabel
	local found = root:FindFirstChild(name, true)
	assert(found ~= nil and found:IsA("TextLabel"), string.format("expected TextLabel %q", name))
	return found
end

describe("loadout preset picker demo", function()
	it("filters case-insensitively and clears a removed selection", function()
		local domain = Domain.new(PRESETS, "recon")
		domain.setQuery("DRoNe")
		local matches = Domain.filter(domain.get())
		expect(#matches).toBe(1)
		expect(matches[1].id).toBe("recon")

		domain.select("breacher")
		expect(domain.get().selectedId).toBe("breacher")
		domain.removePreset("breacher")
		expect(domain.get().selectedId).toBe(nil)
		domain.select("missing")
		expect(domain.get().selectedId).toBe(nil)
	end)

	it("mounts, reacts, cleans up, and remounts in the same owner", function()
		local holder = Instance.new("Folder")
		local first = Mount.mount(holder, PRESETS, "recon")
		expect(first.root.Parent).toBe(holder)
		expect(findLabel(first.root, "ResultCount").Text).toBe("3 PRESETS")

		first.domain.setQuery("MEDIC")
		task.wait()
		expect(findLabel(first.root, "ResultCount").Text).toBe("1 PRESET")
		expect(first.root:FindFirstChild("field-medic", true) ~= nil).toBe(true)
		expect(first.root:FindFirstChild("recon", true)).toBe(nil)

		first.domain.setQuery("no-match")
		task.wait()
		expect(findLabel(first.root, "EmptyState").Visible).toBe(true)

		first.domain.setQuery("")
		first.domain.select("field-medic")
		task.wait()
		expect(findLabel(first.root, "SelectedSummary").Text).toBe("Selected: Field Medic")
		first.domain.removePreset("field-medic")
		task.wait()
		expect(findLabel(first.root, "SelectedSummary").Text).toBe("No preset selected")

		first.destroy()
		first.destroy()
		expect(#holder:GetChildren()).toBe(0)
		local producerOk = pcall(function()
			first.domain.setQuery("producer still usable")
		end)
		expect(producerOk).toBe(true)

		local second = Mount.mount(holder, PRESETS, "breacher")
		expect(second.root.Parent).toBe(holder)
		expect(findLabel(second.root, "SelectedSummary").Text).toBe("Selected: Breach & Clear")
		second.destroy()
		expect(#holder:GetChildren()).toBe(0)
		holder:Destroy()
	end)

	it("cleans partial UI and preserves the construction error", function()
		local holder = Instance.new("Folder")
		local partial: Frame? = nil
		local ok, problem = pcall(function()
			Mount.mount(holder, PRESETS, nil, {
				viewFactory = function(scope, parent, _state, _handlers)
					partial = scope:New("Frame")({
						Name = "PartialPresetPicker",
						Parent = parent,
					}) :: Frame
					error("injected preset picker construction failure")
				end,
			})
		end)
		expect(ok).toBe(false)
		assert(string.find(tostring(problem), "injected preset picker construction failure", 1, true) ~= nil)
		expect(#holder:GetChildren()).toBe(0)
		local partialFrame = assert(partial, "failure factory did not construct its partial frame")
		expect(partialFrame.Parent).toBe(nil)
		holder:Destroy()
	end)

	it("continues Fusion cleanup after a throwing producer disposer", function()
		local holder = Instance.new("Folder")
		local controller = Mount.mount(holder, PRESETS, "recon", {
			decorateProducerDisposer = function(disconnect)
				return function()
					disconnect()
					error("injected producer cleanup failure")
				end
			end,
		})
		local root = controller.root

		local problem: unknown = nil
		local firstDestroyOk = xpcall(controller.destroy, function(reason)
			problem = reason
			return reason
		end)
		expect(firstDestroyOk).toBe(false)
		assert(string.find(tostring(problem), "injected producer cleanup failure", 1, true) ~= nil)
		expect(root.Parent).toBe(nil)
		expect(#holder:GetChildren()).toBe(0)

		local producerOk = pcall(function()
			controller.domain.setQuery("after disposal")
		end)
		expect(producerOk).toBe(true)
		expect(pcall(controller.destroy)).toBe(true)
		holder:Destroy()
	end)

	it("cleans an early acquisition failure and permits a later mount", function()
		local holder = Instance.new("Folder")
		local invalid = table.clone(PRESETS)
		table.insert(invalid, PRESETS[1])
		local ok, problem = pcall(function()
			Mount.mount(holder, invalid, nil)
		end)
		expect(ok).toBe(false)
		assert(string.find(tostring(problem), "duplicate preset id", 1, true) ~= nil)
		expect(#holder:GetChildren()).toBe(0)

		local recovered = Mount.mount(holder, PRESETS, nil)
		expect(recovered.root.Parent).toBe(holder)
		recovered.destroy()
		expect(#holder:GetChildren()).toBe(0)
		holder:Destroy()
	end)
end)

return nil
