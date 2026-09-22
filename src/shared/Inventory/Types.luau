--!strict

export type InventoryId = string
export type ItemDefinitionId = string
export type ItemInstanceId = string
export type Revision = number

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
	Revision: Revision,
	Items: { [ItemInstanceId]: PlacedItem },
}

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

export type InventoryOperation = RepositionOperation | TransferOperation

return nil
