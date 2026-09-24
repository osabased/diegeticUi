--!strict

export type ItemDefinitionId = string
export type ItemInstanceId = string

export type GridSize = {
	Columns: number,
	Rows: number,
}

export type GridPosition = {
	Column: number,
	Row: number,
}

export type ItemDefinition = {
	Id: ItemDefinitionId,
	DisplayName: string,
	Width: number,
	Height: number,
	Rotatable: boolean,
	Icon: string?,
}

export type ItemDefinitionMap = { [ItemDefinitionId]: ItemDefinition }

export type ItemInstance = {
	Id: ItemInstanceId,
	DefinitionId: ItemDefinitionId,
}

export type ItemPlacement = {
	Column: number,
	Row: number,
	Rotated: boolean,
}

export type PlacedItem = {
	DefinitionId: ItemDefinitionId,
	Column: number,
	Row: number,
	Rotated: boolean,
}

export type InventorySnapshot = {
	Revision: number,
	Items: { [ItemInstanceId]: PlacedItem },
}

export type InventoryState = {
	Id: string,
	GridSize: GridSize,
	Snapshot: InventorySnapshot,
}

export type GridErrorCode =
	"InvalidDefinition"
	| "InvalidGridSize"
	| "InvalidPlacement"
	| "InvalidSnapshot"
	| "ItemAlreadyPlaced"
	| "ItemNotPlaced"
	| "NoFit"
	| "Occupied"
	| "OutOfBounds"
	| "RotationNotAllowed"
	| "RevisionOverflow"
	| "UnknownDefinition"

export type GridError = {
	Code: GridErrorCode,
}

export type SnapshotSuccess = {
	Ok: true,
	Snapshot: InventorySnapshot,
}

export type Failure = {
	Ok: false,
	Error: GridError,
}

export type SnapshotResult = SnapshotSuccess | Failure

export type ValidationSuccess = {
	Ok: true,
}

export type ValidationResult = ValidationSuccess | Failure

export type PlacementSuccess = {
	Ok: true,
	Placement: ItemPlacement,
}

export type PlacementResult = PlacementSuccess | Failure

export type TransferErrorCode = GridErrorCode | "SameInventory"
export type TransferResult =
	{ Ok: true, Source: InventorySnapshot, Destination: InventorySnapshot }
	| { Ok: false, Error: { Code: TransferErrorCode } }

-- Keep every produced revision inside the snapshot schema's accepted range.
local MAX_REVISION = 9007199254740990
local MAX_SAFE_INTEGER = 9007199254740991

local Grid = {}
Grid.MAX_REVISION = MAX_REVISION

local function failure(code: GridErrorCode): Failure
	return {
		Ok = false,
		Error = {
			Code = code,
		},
	}
end

local function isNonNegativeInteger(value: number): boolean
	return value >= 0 and value <= MAX_REVISION and value % 1 == 0
end

local function isPositiveInteger(value: number): boolean
	return value >= 1 and value <= MAX_SAFE_INTEGER and value % 1 == 0
end

local function isValidDefinition(definitionId: ItemDefinitionId, definition: ItemDefinition): boolean
	return definition.Id == definitionId
		and isPositiveInteger(definition.Width)
		and isPositiveInteger(definition.Height)
end

local function footprint(definition: ItemDefinition, rotated: boolean): (number, number)
	if rotated then
		return definition.Height, definition.Width
	end
	return definition.Width, definition.Height
end

local function overlaps(
	columnA: number,
	rowA: number,
	widthA: number,
	heightA: number,
	columnB: number,
	rowB: number,
	widthB: number,
	heightB: number
): boolean
	return columnA < columnB + widthB and columnB < columnA + widthA and rowA < rowB + heightB and rowB < rowA + heightA
end

local function isWithinBounds(gridSize: GridSize, placement: ItemPlacement, width: number, height: number): boolean
	return placement.Column + width - 1 <= gridSize.Columns and placement.Row + height - 1 <= gridSize.Rows
end

local function placementError(
	gridSize: GridSize,
	definitions: ItemDefinitionMap,
	snapshot: InventorySnapshot,
	definition: ItemDefinition,
	placement: ItemPlacement
): GridErrorCode?
	if not isPositiveInteger(placement.Column) or not isPositiveInteger(placement.Row) then
		return "InvalidPlacement"
	end
	if placement.Rotated and not definition.Rotatable then
		return "RotationNotAllowed"
	end

	local width, height = footprint(definition, placement.Rotated)
	if not isWithinBounds(gridSize, placement, width, height) then
		return "OutOfBounds"
	end

	for _, existingPlacement in snapshot.Items do
		local existingDefinition = definitions[existingPlacement.DefinitionId]
		local existingWidth, existingHeight = footprint(existingDefinition, existingPlacement.Rotated)
		if
			overlaps(
				placement.Column,
				placement.Row,
				width,
				height,
				existingPlacement.Column,
				existingPlacement.Row,
				existingWidth,
				existingHeight
			)
		then
			return "Occupied"
		end
	end

	return nil
end

local function stateError(
	gridSize: GridSize,
	definitions: ItemDefinitionMap,
	snapshot: InventorySnapshot
): GridErrorCode?
	if not isPositiveInteger(gridSize.Columns) or not isPositiveInteger(gridSize.Rows) then
		return "InvalidGridSize"
	end
	if not isNonNegativeInteger(snapshot.Revision) then
		return "InvalidSnapshot"
	end

	for _, placement in snapshot.Items do
		local definition = definitions[placement.DefinitionId]
		if definition == nil or not isValidDefinition(placement.DefinitionId, definition) then
			return "InvalidSnapshot"
		end
		if not isPositiveInteger(placement.Column) or not isPositiveInteger(placement.Row) then
			return "InvalidSnapshot"
		end
		if placement.Rotated and not definition.Rotatable then
			return "InvalidSnapshot"
		end

		local width, height = footprint(definition, placement.Rotated)
		if not isWithinBounds(gridSize, placement, width, height) then
			return "InvalidSnapshot"
		end
	end

	for itemIdA, placementA in snapshot.Items do
		local definitionA = definitions[placementA.DefinitionId]
		local widthA, heightA = footprint(definitionA, placementA.Rotated)
		for itemIdB, placementB in snapshot.Items do
			if itemIdA < itemIdB then
				local definitionB = definitions[placementB.DefinitionId]
				local widthB, heightB = footprint(definitionB, placementB.Rotated)
				if
					overlaps(
						placementA.Column,
						placementA.Row,
						widthA,
						heightA,
						placementB.Column,
						placementB.Row,
						widthB,
						heightB
					)
				then
					return "InvalidSnapshot"
				end
			end
		end
	end

	return nil
end

local function cloneItems(items: { [ItemInstanceId]: PlacedItem }): { [ItemInstanceId]: PlacedItem }
	local clone = {}
	for itemId, placement in items do
		clone[itemId] = {
			DefinitionId = placement.DefinitionId,
			Column = placement.Column,
			Row = placement.Row,
			Rotated = placement.Rotated,
		}
	end
	return clone
end

function Grid.validateSnapshot(
	gridSize: GridSize,
	definitions: ItemDefinitionMap,
	snapshot: InventorySnapshot
): ValidationResult
	local invalidState = stateError(gridSize, definitions, snapshot)
	if invalidState ~= nil then
		return failure(invalidState :: GridErrorCode)
	end
	return { Ok = true }
end

function Grid.place(
	gridSize: GridSize,
	definitions: ItemDefinitionMap,
	snapshot: InventorySnapshot,
	item: ItemInstance,
	placement: ItemPlacement
): SnapshotResult
	local invalidState = stateError(gridSize, definitions, snapshot)
	if invalidState ~= nil then
		return failure(invalidState :: GridErrorCode)
	end
	if snapshot.Items[item.Id] ~= nil then
		return failure("ItemAlreadyPlaced")
	end
	if snapshot.Revision == MAX_REVISION then
		return failure("RevisionOverflow")
	end

	local definition = definitions[item.DefinitionId]
	if definition == nil then
		return failure("UnknownDefinition")
	end
	if not isValidDefinition(item.DefinitionId, definition) then
		return failure("InvalidDefinition")
	end

	local invalidPlacement = placementError(gridSize, definitions, snapshot, definition, placement)
	if invalidPlacement ~= nil then
		return failure(invalidPlacement :: GridErrorCode)
	end

	local items = cloneItems(snapshot.Items)
	items[item.Id] = {
		DefinitionId = item.DefinitionId,
		Column = placement.Column,
		Row = placement.Row,
		Rotated = placement.Rotated,
	}

	return {
		Ok = true,
		Snapshot = {
			Revision = snapshot.Revision + 1,
			Items = items,
		},
	}
end

function Grid.remove(
	gridSize: GridSize,
	definitions: ItemDefinitionMap,
	snapshot: InventorySnapshot,
	itemId: ItemInstanceId
): SnapshotResult
	local invalidState = stateError(gridSize, definitions, snapshot)
	if invalidState ~= nil then
		return failure(invalidState :: GridErrorCode)
	end
	if snapshot.Items[itemId] == nil then
		return failure("ItemNotPlaced")
	end
	if snapshot.Revision == MAX_REVISION then
		return failure("RevisionOverflow")
	end

	local items = cloneItems(snapshot.Items)
	items[itemId] = nil
	return {
		Ok = true,
		Snapshot = {
			Revision = snapshot.Revision + 1,
			Items = items,
		},
	}
end

function Grid.reposition(
	gridSize: GridSize,
	definitions: ItemDefinitionMap,
	snapshot: InventorySnapshot,
	itemId: ItemInstanceId,
	destination: ItemPlacement
): SnapshotResult
	local invalidState = stateError(gridSize, definitions, snapshot)
	if invalidState ~= nil then
		return failure(invalidState :: GridErrorCode)
	end

	local existing = snapshot.Items[itemId]
	if existing == nil then
		return failure("ItemNotPlaced")
	end

	local itemsWithoutTarget = cloneItems(snapshot.Items)
	itemsWithoutTarget[itemId] = nil
	return Grid.place(gridSize, definitions, {
		Revision = snapshot.Revision,
		Items = itemsWithoutTarget,
	}, {
		Id = itemId,
		DefinitionId = existing.DefinitionId,
	}, destination)
end

function Grid.rotate(
	gridSize: GridSize,
	definitions: ItemDefinitionMap,
	snapshot: InventorySnapshot,
	itemId: ItemInstanceId
): SnapshotResult
	local invalidState = stateError(gridSize, definitions, snapshot)
	if invalidState ~= nil then
		return failure(invalidState :: GridErrorCode)
	end

	local existing = snapshot.Items[itemId]
	if existing == nil then
		return failure("ItemNotPlaced")
	end

	return Grid.reposition(gridSize, definitions, snapshot, itemId, {
		Column = existing.Column,
		Row = existing.Row,
		Rotated = not existing.Rotated,
	})
end

-- Traversal is row-major: top to bottom, then left to right within each row.
function Grid.findFirstFit(
	gridSize: GridSize,
	definitions: ItemDefinitionMap,
	snapshot: InventorySnapshot,
	definitionId: ItemDefinitionId,
	rotated: boolean
): PlacementResult
	local invalidState = stateError(gridSize, definitions, snapshot)
	if invalidState ~= nil then
		return failure(invalidState :: GridErrorCode)
	end

	local definition = definitions[definitionId]
	if definition == nil then
		return failure("UnknownDefinition")
	end
	if not isValidDefinition(definitionId, definition) then
		return failure("InvalidDefinition")
	end
	if rotated and not definition.Rotatable then
		return failure("RotationNotAllowed")
	end

	local width, height = footprint(definition, rotated)
	local finalColumn = gridSize.Columns - width + 1
	local finalRow = gridSize.Rows - height + 1
	for row = 1, finalRow do
		for column = 1, finalColumn do
			local placement: ItemPlacement = {
				Column = column,
				Row = row,
				Rotated = rotated,
			}
			if placementError(gridSize, definitions, snapshot, definition, placement) == nil then
				return {
					Ok = true,
					Placement = placement,
				}
			end
		end
	end

	return failure("NoFit")
end

local function transferFailure(code: TransferErrorCode): TransferResult
	return { Ok = false, Error = { Code = code } }
end

local function transfer(
	definitions: ItemDefinitionMap,
	source: InventoryState,
	destination: InventoryState,
	itemId: ItemInstanceId,
	placement: ItemPlacement?
): TransferResult
	if source.Id == destination.Id then
		return transferFailure("SameInventory")
	end

	local sourceValidation = Grid.validateSnapshot(source.GridSize, definitions, source.Snapshot)
	if not sourceValidation.Ok then
		return transferFailure(sourceValidation.Error.Code)
	end
	local destinationValidation = Grid.validateSnapshot(destination.GridSize, definitions, destination.Snapshot)
	if not destinationValidation.Ok then
		return transferFailure(destinationValidation.Error.Code)
	end

	local existing = source.Snapshot.Items[itemId]
	if existing == nil then
		return transferFailure("ItemNotPlaced")
	end
	if destination.Snapshot.Items[itemId] ~= nil then
		return transferFailure("ItemAlreadyPlaced")
	end

	local selectedPlacement: ItemPlacement
	if placement == nil then
		local fit = Grid.findFirstFit(
			destination.GridSize,
			definitions,
			destination.Snapshot,
			existing.DefinitionId,
			existing.Rotated
		)
		if not fit.Ok then
			return transferFailure(fit.Error.Code)
		end
		selectedPlacement = fit.Placement
	else
		selectedPlacement = placement
	end

	local placed = Grid.place(destination.GridSize, definitions, destination.Snapshot, {
		Id = itemId,
		DefinitionId = existing.DefinitionId,
	}, selectedPlacement)
	if not placed.Ok then
		return transferFailure(placed.Error.Code)
	end

	local removed = Grid.remove(source.GridSize, definitions, source.Snapshot, itemId)
	if not removed.Ok then
		return transferFailure(removed.Error.Code)
	end

	return { Ok = true, Source = removed.Snapshot, Destination = placed.Snapshot }
end

function Grid.transferToPlacement(
	definitions: ItemDefinitionMap,
	source: InventoryState,
	destination: InventoryState,
	itemId: ItemInstanceId,
	placement: ItemPlacement
): TransferResult
	return transfer(definitions, source, destination, itemId, placement)
end

-- Quick transfer keeps the item's orientation and uses row-major first fit.
function Grid.transferFirstFit(
	definitions: ItemDefinitionMap,
	source: InventoryState,
	destination: InventoryState,
	itemId: ItemInstanceId
): TransferResult
	return transfer(definitions, source, destination, itemId, nil)
end

return table.freeze(Grid)
