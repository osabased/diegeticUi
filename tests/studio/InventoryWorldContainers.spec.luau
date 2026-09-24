--!strict
--# selene: allow(incorrect_standard_library_use)

local Lest = require("@lest")
local describe, it = Lest.describe, Lest.it
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local WorldContainers = require("../../src/server/Inventory/WorldContainers")

local function fixture()
	local part = Instance.new("Part")
	part.Anchored = true
	part.Position = Vector3.new(0, 3, 0)
	part.Parent = Workspace

	local character = Instance.new("Model")
	local root = Instance.new("Part")
	root.Name = "HumanoidRootPart"
	root.Anchored = true
	root.Position = Vector3.new(0, 3, 6)
	root.Parent = character
	Instance.new("Humanoid").Parent = character
	character.Parent = Workspace

	local fake: any = { Parent = Players, Character = character }
	local world = WorldContainers.new()
	local bound = world.bind(part, {
		{ DefinitionId = "Bandage", Placement = { Column = 1, Row = 1, Rotated = false } },
	})
	assert(bound.Ok, "world binding failed")
	local itemId: string? = nil
	for id in bound.Snapshot.Items do
		itemId = id
	end
	assert(itemId ~= nil, "seeded item missing")
	return world, bound.Id, itemId, part, root, character, fake
end

local function dataFixture()
	local snapshot: any = { Revision = 0, Items = {} }
	local writes = 0
	local onWait: (() -> ())? = nil
	local afterCommit: (() -> ())? = nil
	local data: any = {
		WaitForData = function()
			if onWait ~= nil then
				onWait()
			end
			return { Inventory = {
				Get = function()
					return snapshot
				end,
			} }, nil
		end,
		Get = function()
			return {
				Inventory = {
					Get = function()
						return snapshot
					end,
					Set = function(value)
						writes += 1
						snapshot = value
					end,
				},
			}
		end,
		Transaction = function(_player, callback)
			callback()
			if afterCommit ~= nil then
				afterCommit()
			end
			return true, nil
		end,
	}
	return data,
		{
			writes = function()
				return writes
			end,
			onWait = function(callback)
				onWait = callback
			end,
			afterCommit = function(callback)
				afterCommit = callback
			end,
		}
end

describe("world container access", function()
	it("binds one part, returns copied snapshots, and rejects unavailable players", function()
		local world, id, _, part, root, character, fake = fixture()
		assert(part:GetAttribute("ContainerId") == id, "replicated lookup ID missing")
		local duplicate = world.bind(part, {})
		assert(not duplicate.Ok and duplicate.Reason == "ContainerExists", "part received two inventories")
		local read = world.inspect(fake, id)
		assert(read.Ok and read.Snapshot.Revision == 0, "nearby player could not inspect")
		if read.Ok then
			read.Snapshot.Revision = 20
		end
		local again = world.inspect(fake, id)
		assert(again.Ok and again.Snapshot.Revision == 0, "inspection leaked mutable state")
		root.Position = Vector3.new(0, 3, 40)
		local distant = world.inspect(fake, id)
		assert(not distant.Ok and distant.Reason == "NotEligible", "distant player inspected")
		root.Position = Vector3.new(0, 3, 6)
		fake.Character = nil
		local noCharacter = world.inspect(fake, id)
		assert(not noCharacter.Ok and noCharacter.Reason == "NotEligible", "missing character inspected")
		fake.Character = character
		fake.Parent = nil
		local departed = world.inspect(fake, id)
		assert(not departed.Ok and departed.Reason == "NotEligible", "departed player inspected")
		part.Parent = nil
		local stale = world.inspect(fake, id)
		assert(not stale.Ok and stale.Reason == "ContainerMissing", "removed world part remained readable")
		world.destroy()
		part:Destroy()
		character:Destroy()
	end)

	it("checks distance for claims and retires a part after an in-flight commit", function()
		local world, id, itemId, part, root, character, fake = fixture()
		local data, state = dataFixture()
		root.Position = Vector3.new(0, 3, 40)
		local distant = world.claim(data, fake, id, itemId, 0, 0, 0)
		assert(not distant.Ok and distant.Reason == "NotEligible" and state.writes() == 0, "distant claim wrote")
		root.Position = Vector3.new(0, 3, 6)
		local reentered: any = nil
		state.afterCommit(function()
			local expired = world.expire(id)
			assert(expired.Ok, "removal during claim failed")
			reentered = world.claim(data, fake, id, itemId, 1, 0, 0)
		end)
		local accepted = world.claim(data, fake, id, itemId, 0, 0, 0)
		assert(accepted.Ok and state.writes() == 1, "eligible claim did not commit once")
		assert(not reentered.Ok and reentered.Reason == "ContainerMissing", "closing container admitted claim")
		assert(part.Parent == nil, "expired world part remained")
		local stale = world.inspect(fake, id)
		assert(not stale.Ok and stale.Reason == "ContainerMissing", "expired inventory remained visible")
		world.destroy()
		character:Destroy()
	end)

	it("rejects a claim when the world part disappears during player readiness", function()
		local world, id, itemId, part, _, character, fake = fixture()
		local data, state = dataFixture()
		state.onWait(function()
			part.Parent = nil
		end)
		local result = world.claim(data, fake, id, itemId, 0, 0, 0)
		assert(not result.Ok and result.Reason == "NotEligible", "claim ignored removal during readiness")
		assert(state.writes() == 0, "removed container wrote player state")
		local stale = world.inspect(fake, id)
		assert(not stale.Ok and stale.Reason == "ContainerMissing", "removed inventory survived")
		world.destroy()
		part:Destroy()
		character:Destroy()
	end)

	it("retires its inventory when the bound part is destroyed directly", function()
		local world, id, _, part, _, character, fake = fixture()
		part:Destroy()
		local result = world.inspect(fake, id)
		assert(not result.Ok and result.Reason == "ContainerMissing", "destroyed part retained a readable inventory")
		world.destroy()
		character:Destroy()
	end)
end)

return nil
