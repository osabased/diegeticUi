--!strict

local Lest = require("@lest")
local describe, it, expect = Lest.describe, Lest.it, Lest.expect

local Grid = require("../../src/shared/Inventory/Grid")

local DEFINITIONS: Grid.ItemDefinitionMap = {
	Bandage = { Id = "Bandage", DisplayName = "Bandage", Width = 1, Height = 1, Rotatable = false },
	Rifle = { Id = "Rifle", DisplayName = "Rifle", Width = 2, Height = 1, Rotatable = true },
}

local function inventory(id: string, revision: number, items: { [string]: Grid.PlacedItem }): Grid.InventoryState
	return { Id = id, GridSize = { Columns = 4, Rows = 4 }, Snapshot = { Revision = revision, Items = items } }
end

local function fixtures(): (Grid.InventoryState, Grid.InventoryState)
	return inventory("player", 7, {
		["rifle-1"] = { DefinitionId = "Rifle", Column = 1, Row = 1, Rotated = false },
		["bandage-1"] = { DefinitionId = "Bandage", Column = 4, Row = 1, Rotated = false },
	}),
		inventory("container", 11, {
			["bandage-2"] = { DefinitionId = "Bandage", Column = 1, Row = 1, Rotated = false },
		})
end

local function copySnapshot(snapshot: Grid.InventorySnapshot): Grid.InventorySnapshot
	local items: { [string]: Grid.PlacedItem } = {}
	for itemId, placement in snapshot.Items do
		items[itemId] = table.clone(placement)
	end
	return { Revision = snapshot.Revision, Items = items }
end

local function expectFailure(
	source: Grid.InventoryState,
	destination: Grid.InventoryState,
	itemId: string,
	placement: Grid.ItemPlacement?,
	code: Grid.TransferErrorCode
)
	local priorSource = copySnapshot(source.Snapshot)
	local priorDestination = copySnapshot(destination.Snapshot)
	local result = if placement == nil
		then Grid.transferFirstFit(DEFINITIONS, source, destination, itemId)
		else Grid.transferToPlacement(DEFINITIONS, source, destination, itemId, placement)
	expect(result).toEqual({ Ok = false, Error = { Code = code } })
	expect(source.Snapshot).toEqual(priorSource)
	expect(destination.Snapshot).toEqual(priorDestination)
end

describe("inventory transfer", function()
	it("accepts a test-only definition and keeps its instances distinct", function()
		local definitions: Grid.ItemDefinitionMap = {
			Fixture = { Id = "Fixture", DisplayName = "Fixture", Width = 2, Height = 1, Rotatable = true },
		}
		local size = { Columns = 4, Rows = 4 }
		local empty: Grid.InventorySnapshot = { Revision = 0, Items = {} }
		local first = Grid.place(size, definitions, empty, { Id = "fixture-a", DefinitionId = "Fixture" }, {
			Column = 1,
			Row = 1,
			Rotated = false,
		})
		assert(first.Ok, "new definition was not placed")
		local second = Grid.place(size, definitions, first.Snapshot, { Id = "fixture-b", DefinitionId = "Fixture" }, {
			Column = 3,
			Row = 1,
			Rotated = false,
		})
		assert(second.Ok, "second instance was not placed")
		local rotated = Grid.rotate(size, definitions, second.Snapshot, "fixture-b")
		assert(rotated.Ok, "new definition did not rotate")
		local moved = Grid.transferFirstFit(
			definitions,
			{ Id = "source", GridSize = size, Snapshot = rotated.Snapshot },
			{ Id = "destination", GridSize = size, Snapshot = empty },
			"fixture-a"
		)
		assert(moved.Ok, "new definition did not transfer")
		expect(moved.Source.Items["fixture-a"]).toBe(nil)
		expect(moved.Source.Items["fixture-b"]).toEqual({
			DefinitionId = "Fixture",
			Column = 3,
			Row = 1,
			Rotated = true,
		})
		expect(moved.Destination.Items["fixture-a"]).toEqual({
			DefinitionId = "Fixture",
			Column = 1,
			Row = 1,
			Rotated = false,
		})
		expect(Grid.validateSnapshot(size, definitions, moved.Destination)).toEqual({ Ok = true })
		expect(Grid.validateSnapshot(size, {}, moved.Destination)).toEqual({
			Ok = false,
			Error = { Code = "InvalidSnapshot" },
		})
	end)

	it("moves one instance to an explicit placement with one revision per inventory", function()
		local source, destination = fixtures()
		local priorSource = copySnapshot(source.Snapshot)
		local priorDestination = copySnapshot(destination.Snapshot)
		local result = Grid.transferToPlacement(DEFINITIONS, source, destination, "rifle-1", {
			Column = 2,
			Row = 2,
			Rotated = true,
		})

		expect(result).toEqual({
			Ok = true,
			Source = {
				Revision = 8,
				Items = { ["bandage-1"] = priorSource.Items["bandage-1"] },
			},
			Destination = {
				Revision = 12,
				Items = {
					["bandage-2"] = priorDestination.Items["bandage-2"],
					["rifle-1"] = { DefinitionId = "Rifle", Column = 2, Row = 2, Rotated = true },
				},
			},
		})
		expect(source.Snapshot).toEqual(priorSource)
		expect(destination.Snapshot).toEqual(priorDestination)
	end)

	it("uses the same row-major first fit for the same destination and keeps orientation", function()
		local source, destination = fixtures()
		local first = Grid.transferFirstFit(DEFINITIONS, source, destination, "rifle-1")
		local second = Grid.transferFirstFit(DEFINITIONS, source, destination, "rifle-1")
		expect(first).toEqual(second)
		assert(first.Ok, "first fit should succeed")
		expect(first.Destination.Items["rifle-1"]).toEqual({
			DefinitionId = "Rifle",
			Column = 2,
			Row = 1,
			Rotated = false,
		})
		local rotatedSource, rotatedDestination = fixtures()
		rotatedSource.Snapshot.Items["rifle-1"].Rotated = true
		local rotated = Grid.transferFirstFit(DEFINITIONS, rotatedSource, rotatedDestination, "rifle-1")
		assert(rotated.Ok, "rotated first fit should succeed")
		expect(rotated.Destination.Items["rifle-1"].Rotated).toBe(true)
	end)

	it("rejects invalid states, missing or duplicate items, and the same owner", function()
		local source, destination = fixtures()
		source.Snapshot.Items["bandage-1"].Column = 1
		expectFailure(source, destination, "rifle-1", nil, "InvalidSnapshot")

		source, destination = fixtures()
		destination.Snapshot.Items["bandage-2"].Column = 5
		expectFailure(source, destination, "rifle-1", nil, "InvalidSnapshot")

		source, destination = fixtures()
		expectFailure(source, destination, "missing", nil, "ItemNotPlaced")

		source, destination = fixtures()
		destination.Snapshot.Items["rifle-1"] = {
			DefinitionId = "Rifle",
			Column = 2,
			Row = 3,
			Rotated = false,
		}
		expectFailure(source, destination, "rifle-1", nil, "ItemAlreadyPlaced")

		source, destination = fixtures()
		destination.Id = source.Id
		expectFailure(source, destination, "rifle-1", nil, "SameInventory")
	end)

	it("rolls back explicit placement and quick no-fit failures", function()
		local source, destination = fixtures()
		expectFailure(source, destination, "rifle-1", { Column = 4, Row = 4, Rotated = false }, "OutOfBounds")
		expectFailure(source, destination, "rifle-1", { Column = 1, Row = 1, Rotated = false }, "Occupied")

		source, destination = fixtures()
		destination.GridSize = { Columns = 1, Rows = 1 }
		expectFailure(source, destination, "rifle-1", nil, "NoFit")
	end)

	it("rejects revision overflow on either inventory", function()
		local source, destination = fixtures()
		source.Snapshot.Revision = 9007199254740990
		expectFailure(source, destination, "rifle-1", nil, "RevisionOverflow")

		source, destination = fixtures()
		destination.Snapshot.Revision = 9007199254740990
		expectFailure(source, destination, "rifle-1", nil, "RevisionOverflow")
	end)
end)

return nil
