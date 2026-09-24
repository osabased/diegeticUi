--!strict

local Grid = require(script.Parent.Grid)
local Definitions = require(script.Parent.Definitions)
local GridSize = require(script.Parent.GridSize)

export type Success = {
	Ok: true,
	Snapshot: Grid.InventorySnapshot,
}

export type Failure = {
	Ok: false,
	Reason: "Malformed" | "SpatialInvalid",
}

export type Result = Success | Failure

local SnapshotValidation = {}

local function hasOnlyKeys(value: { [string]: unknown }, allowed: { [string]: boolean }): boolean
	for key in value do
		if not allowed[key] then
			return false
		end
	end
	return true
end

local function isInteger(value: unknown, minimum: number, maximum: number): boolean
	return type(value) == "number" and value >= minimum and value <= maximum and value % 1 == 0
end

function SnapshotValidation.validate(value: unknown): Result
	if type(value) ~= "table" then
		return { Ok = false, Reason = "Malformed" }
	end
	local root = value :: { [string]: unknown }
	if
		not hasOnlyKeys(root, { Revision = true, Items = true })
		or not isInteger(root.Revision, 0, Grid.MAX_REVISION)
		or type(root.Items) ~= "table"
	then
		return { Ok = false, Reason = "Malformed" }
	end

	local items = root.Items :: { [string]: unknown }
	local checkedItems: { [string]: Grid.PlacedItem } = {}
	local count = 0
	for itemId, rawPlacement in items do
		count += 1
		if count > 256 or type(itemId) ~= "string" or #itemId == 0 or #itemId > 64 or type(rawPlacement) ~= "table" then
			return { Ok = false, Reason = "Malformed" }
		end
		local placement = rawPlacement :: { [string]: unknown }
		if
			not hasOnlyKeys(placement, { DefinitionId = true, Column = true, Row = true, Rotated = true })
			or type(placement.DefinitionId) ~= "string"
			or #placement.DefinitionId == 0
			or #placement.DefinitionId > 64
			or not isInteger(placement.Column, 1, 255)
			or not isInteger(placement.Row, 1, 255)
			or type(placement.Rotated) ~= "boolean"
		then
			return { Ok = false, Reason = "Malformed" }
		end
		checkedItems[itemId] = {
			DefinitionId = placement.DefinitionId :: string,
			Column = placement.Column :: number,
			Row = placement.Row :: number,
			Rotated = placement.Rotated :: boolean,
		}
	end

	local snapshot: Grid.InventorySnapshot = {
		Revision = root.Revision :: number,
		Items = checkedItems,
	}
	if not Grid.validateSnapshot(GridSize, Definitions, snapshot).Ok then
		return { Ok = false, Reason = "SpatialInvalid" }
	end
	return { Ok = true, Snapshot = snapshot }
end

return table.freeze(SnapshotValidation)
