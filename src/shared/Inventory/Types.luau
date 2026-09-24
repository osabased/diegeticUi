--!strict

local Grid = require(script.Parent.Grid)

export type InventoryId = string
export type ItemDefinitionId = Grid.ItemDefinitionId
export type ItemInstanceId = Grid.ItemInstanceId
export type Revision = number

export type GridSize = Grid.GridSize
export type GridPosition = Grid.GridPosition
export type ItemDefinition = Grid.ItemDefinition
export type ItemDefinitionMap = Grid.ItemDefinitionMap
export type ItemInstance = Grid.ItemInstance
export type ItemPlacement = Grid.ItemPlacement
export type PlacedItem = Grid.PlacedItem
export type InventorySnapshot = Grid.InventorySnapshot
export type InventoryState = Grid.InventoryState

export type RepositionOperation = {
	Kind: "Reposition",
	InventoryId: InventoryId,
	ItemId: ItemInstanceId,
	Destination: ItemPlacement,
}

export type TransferOperation = {
	Kind: "Transfer",
	SourceInventoryId: InventoryId,
	DestinationInventoryId: InventoryId,
	ItemId: ItemInstanceId,
	Destination: ItemPlacement,
}

export type QuickTransferOperation = {
	Kind: "QuickTransfer",
	SourceInventoryId: InventoryId,
	DestinationInventoryId: InventoryId,
	ItemId: ItemInstanceId,
}

export type InventoryOperation = RepositionOperation | TransferOperation | QuickTransferOperation

return nil
