--!strict

local Lest = require("@lest")
local describe, it, expect = Lest.describe, Lest.it, Lest.expect

local Grid = require("../../src/shared/Inventory/Grid")

local GRID_SIZE = {
	Columns = 4,
	Rows = 4,
}

local DEFINITIONS = {
	Bandage = {
		Id = "Bandage",
		DisplayName = "Bandage",
		Width = 1,
		Height = 2,
		Rotatable = false,
	},
	Rifle = {
		Id = "Rifle",
		DisplayName = "Rifle",
		Width = 2,
		Height = 3,
		Rotatable = true,
	},
}

describe("inventory grid", function()
	it("places an item against the bottom-right edges without mutating the prior snapshot", function()
		local before = {
			Revision = 0,
			Items = {},
		}

		local result = Grid.place(GRID_SIZE, DEFINITIONS, before, {
			Id = "rifle-1",
			DefinitionId = "Rifle",
		}, {
			Column = 3,
			Row = 2,
			Rotated = false,
		})

		expect(result).toEqual({
			Ok = true,
			Snapshot = {
				Revision = 1,
				Items = {
					["rifle-1"] = {
						DefinitionId = "Rifle",
						Column = 3,
						Row = 2,
						Rotated = false,
					},
				},
			},
		})
		expect(before).toEqual({
			Revision = 0,
			Items = {},
		})
	end)

	it("rejects an out-of-bounds placement without changing state or revision", function()
		local before = {
			Revision = 7,
			Items = {},
		}

		local result = Grid.place(GRID_SIZE, DEFINITIONS, before, {
			Id = "rifle-1",
			DefinitionId = "Rifle",
		}, {
			Column = 4,
			Row = 2,
			Rotated = false,
		})

		expect(result).toEqual({
			Ok = false,
			Error = {
				Code = "OutOfBounds",
			},
		})
		expect(before).toEqual({
			Revision = 7,
			Items = {},
		})
	end)

	it("rejects non-cell placement coordinates without changing state", function()
		local before = {
			Revision = 5,
			Items = {},
		}

		local result = Grid.place(GRID_SIZE, DEFINITIONS, before, {
			Id = "rifle-1",
			DefinitionId = "Rifle",
		}, {
			Column = 1.5,
			Row = 1,
			Rotated = false,
		})

		expect(result).toEqual({
			Ok = false,
			Error = {
				Code = "InvalidPlacement",
			},
		})
		expect(before.Revision).toBe(5)
	end)

	it("rejects placement when the item instance is already present", function()
		local before = {
			Revision = 1,
			Items = {
				["rifle-1"] = {
					DefinitionId = "Rifle",
					Column = 1,
					Row = 1,
					Rotated = false,
				},
			},
		}

		local result = Grid.place(GRID_SIZE, DEFINITIONS, before, {
			Id = "rifle-1",
			DefinitionId = "Rifle",
		}, {
			Column = 3,
			Row = 2,
			Rotated = false,
		})

		expect(result).toEqual({
			Ok = false,
			Error = {
				Code = "ItemAlreadyPlaced",
			},
		})
		expect(before.Items["rifle-1"].Column).toBe(1)
		expect(before.Revision).toBe(1)
	end)

	it("rejects an item whose definition is unknown", function()
		local before = {
			Revision = 0,
			Items = {},
		}

		local result = Grid.place(GRID_SIZE, DEFINITIONS, before, {
			Id = "unknown-1",
			DefinitionId = "Unknown",
		}, {
			Column = 1,
			Row = 1,
			Rotated = false,
		})

		expect(result).toEqual({
			Ok = false,
			Error = {
				Code = "UnknownDefinition",
			},
		})
		expect(before.Revision).toBe(0)
	end)

	it("rejects invalid grid and definition inputs with explicit errors", function()
		local before = {
			Revision = 0,
			Items = {},
		}
		local invalidDefinitions = {
			Invalid = {
				Id = "Invalid",
				DisplayName = "Invalid",
				Width = 0,
				Height = 1,
				Rotatable = false,
			},
		}

		expect(Grid.place({ Columns = 0, Rows = 4 }, DEFINITIONS, before, {
			Id = "rifle-1",
			DefinitionId = "Rifle",
		}, {
			Column = 1,
			Row = 1,
			Rotated = false,
		})).toEqual({
			Ok = false,
			Error = {
				Code = "InvalidGridSize",
			},
		})

		expect(Grid.place(GRID_SIZE, invalidDefinitions, before, {
			Id = "invalid-1",
			DefinitionId = "Invalid",
		}, {
			Column = 1,
			Row = 1,
			Rotated = false,
		})).toEqual({
			Ok = false,
			Error = {
				Code = "InvalidDefinition",
			},
		})
	end)

	it("returns the same collision error for the same overlapping placement", function()
		local before = {
			Revision = 2,
			Items = {
				["rifle-1"] = {
					DefinitionId = "Rifle",
					Column = 1,
					Row = 1,
					Rotated = false,
				},
			},
		}
		local item = {
			Id = "rifle-2",
			DefinitionId = "Rifle",
		}
		local placement = {
			Column = 2,
			Row = 2,
			Rotated = false,
		}

		local first = Grid.place(GRID_SIZE, DEFINITIONS, before, item, placement)
		local second = Grid.place(GRID_SIZE, DEFINITIONS, before, item, placement)

		expect(first).toEqual({
			Ok = false,
			Error = {
				Code = "Occupied",
			},
		})
		expect(second).toEqual(first)
		expect(before.Revision).toBe(2)
		expect(before.Items["rifle-2"]).toBe(nil)
	end)

	it("removes exactly one item and advances the revision once", function()
		local before = {
			Revision = 4,
			Items = {
				["rifle-1"] = {
					DefinitionId = "Rifle",
					Column = 1,
					Row = 1,
					Rotated = false,
				},
				["rifle-2"] = {
					DefinitionId = "Rifle",
					Column = 3,
					Row = 2,
					Rotated = false,
				},
			},
		}

		local result = Grid.remove(GRID_SIZE, DEFINITIONS, before, "rifle-1")

		expect(result).toEqual({
			Ok = true,
			Snapshot = {
				Revision = 5,
				Items = {
					["rifle-2"] = {
						DefinitionId = "Rifle",
						Column = 3,
						Row = 2,
						Rotated = false,
					},
				},
			},
		})
		assert(before.Items["rifle-1"] ~= nil, "remove mutated the prior snapshot")
		assert(result.Ok, "expected removal to succeed")
		result.Snapshot.Items["rifle-2"].Column = 4
		expect(before.Items["rifle-2"].Column).toBe(3)
	end)

	it("rejects removal of an absent item without advancing the revision", function()
		local before = {
			Revision = 4,
			Items = {},
		}

		local result = Grid.remove(GRID_SIZE, DEFINITIONS, before, "missing")

		expect(result).toEqual({
			Ok = false,
			Error = {
				Code = "ItemNotPlaced",
			},
		})
		expect(before).toEqual({
			Revision = 4,
			Items = {},
		})
	end)

	it("rejects an operation when the prior snapshot violates grid invariants", function()
		local before = {
			Revision = 2,
			Items = {
				["rifle-1"] = {
					DefinitionId = "Rifle",
					Column = 1,
					Row = 1,
					Rotated = false,
				},
				["bandage-1"] = {
					DefinitionId = "Bandage",
					Column = 2,
					Row = 2,
					Rotated = false,
				},
			},
		}

		local result = Grid.remove(GRID_SIZE, DEFINITIONS, before, "bandage-1")

		expect(result).toEqual({
			Ok = false,
			Error = {
				Code = "InvalidSnapshot",
			},
		})
		expect(before.Revision).toBe(2)
		assert(before.Items["bandage-1"] ~= nil, "failed removal mutated the prior snapshot")
	end)

	it("repositions an item atomically and advances the revision once", function()
		local before = {
			Revision = 8,
			Items = {
				["rifle-1"] = {
					DefinitionId = "Rifle",
					Column = 1,
					Row = 1,
					Rotated = false,
				},
			},
		}

		local result = Grid.reposition(GRID_SIZE, DEFINITIONS, before, "rifle-1", {
			Column = 3,
			Row = 2,
			Rotated = false,
		})

		expect(result).toEqual({
			Ok = true,
			Snapshot = {
				Revision = 9,
				Items = {
					["rifle-1"] = {
						DefinitionId = "Rifle",
						Column = 3,
						Row = 2,
						Rotated = false,
					},
				},
			},
		})
		expect(before.Items["rifle-1"].Column).toBe(1)
	end)

	it("rotates an item in place and advances the revision once", function()
		local before = {
			Revision = 10,
			Items = {
				["rifle-1"] = {
					DefinitionId = "Rifle",
					Column = 1,
					Row = 1,
					Rotated = false,
				},
			},
		}

		local result = Grid.rotate(GRID_SIZE, DEFINITIONS, before, "rifle-1")

		expect(result).toEqual({
			Ok = true,
			Snapshot = {
				Revision = 11,
				Items = {
					["rifle-1"] = {
						DefinitionId = "Rifle",
						Column = 1,
						Row = 1,
						Rotated = true,
					},
				},
			},
		})
		expect(before.Items["rifle-1"].Rotated).toBe(false)
	end)

	it("rejects rotation when the item definition is not rotatable", function()
		local before = {
			Revision = 3,
			Items = {
				["bandage-1"] = {
					DefinitionId = "Bandage",
					Column = 1,
					Row = 1,
					Rotated = false,
				},
			},
		}

		local result = Grid.rotate(GRID_SIZE, DEFINITIONS, before, "bandage-1")

		expect(result).toEqual({
			Ok = false,
			Error = {
				Code = "RotationNotAllowed",
			},
		})
		expect(before.Items["bandage-1"].Rotated).toBe(false)
		expect(before.Revision).toBe(3)
	end)

	it("rolls rotation back when the rotated footprint collides", function()
		local before = {
			Revision = 6,
			Items = {
				["rifle-1"] = {
					DefinitionId = "Rifle",
					Column = 1,
					Row = 1,
					Rotated = false,
				},
				["bandage-1"] = {
					DefinitionId = "Bandage",
					Column = 3,
					Row = 1,
					Rotated = false,
				},
			},
		}

		local result = Grid.rotate(GRID_SIZE, DEFINITIONS, before, "rifle-1")

		expect(result).toEqual({
			Ok = false,
			Error = {
				Code = "Occupied",
			},
		})
		expect(before).toEqual({
			Revision = 6,
			Items = {
				["rifle-1"] = {
					DefinitionId = "Rifle",
					Column = 1,
					Row = 1,
					Rotated = false,
				},
				["bandage-1"] = {
					DefinitionId = "Bandage",
					Column = 3,
					Row = 1,
					Rotated = false,
				},
			},
		})
	end)

	it("finds the first fit in row-major order without changing the snapshot", function()
		local before = {
			Revision = 12,
			Items = {
				["rifle-1"] = {
					DefinitionId = "Rifle",
					Column = 1,
					Row = 1,
					Rotated = false,
				},
				["bandage-1"] = {
					DefinitionId = "Bandage",
					Column = 3,
					Row = 1,
					Rotated = false,
				},
			},
		}

		local first = Grid.findFirstFit(GRID_SIZE, DEFINITIONS, before, "Bandage", false)
		local second = Grid.findFirstFit(GRID_SIZE, DEFINITIONS, before, "Bandage", false)

		expect(first).toEqual({
			Ok = true,
			Placement = {
				Column = 4,
				Row = 1,
				Rotated = false,
			},
		})
		expect(second).toEqual(first)
		expect(before.Revision).toBe(12)
	end)

	it("returns a stable error when no first-fit placement exists", function()
		local before = {
			Revision = 2,
			Items = {},
		}

		local result = Grid.findFirstFit({
			Columns = 1,
			Rows = 1,
		}, DEFINITIONS, before, "Bandage", false)

		expect(result).toEqual({
			Ok = false,
			Error = {
				Code = "NoFit",
			},
		})
		expect(before).toEqual({
			Revision = 2,
			Items = {},
		})
	end)

	it("uses rotated dimensions during first-fit search", function()
		local before = {
			Revision = 0,
			Items = {},
		}

		local result = Grid.findFirstFit({ Columns = 3, Rows = 2 }, DEFINITIONS, before, "Rifle", true)

		expect(result).toEqual({
			Ok = true,
			Placement = {
				Column = 1,
				Row = 1,
				Rotated = true,
			},
		})
	end)
end)

describe("revision limit", function()
	it("validates the largest accepted revision but rejects mutations that would exceed it", function()
		local full = {
			Revision = 9007199254740990,
			Items = {
				["bandage-1"] = { DefinitionId = "Bandage", Column = 1, Row = 1, Rotated = false },
			},
		}
		expect(Grid.validateSnapshot(GRID_SIZE, DEFINITIONS, full)).toEqual({ Ok = true })
		expect(Grid.remove(GRID_SIZE, DEFINITIONS, full, "bandage-1")).toEqual({
			Ok = false,
			Error = { Code = "RevisionOverflow" },
		})
		expect(Grid.place(GRID_SIZE, DEFINITIONS, full, { Id = "bandage-2", DefinitionId = "Bandage" }, {
			Column = 2,
			Row = 1,
			Rotated = false,
		})).toEqual({ Ok = false, Error = { Code = "RevisionOverflow" } })
	end)
end)

return nil
