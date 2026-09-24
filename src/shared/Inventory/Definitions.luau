--!strict

local Types = require(script.Parent.Types)

local definitions: Types.ItemDefinitionMap = {
	Bandage = table.freeze({
		Id = "Bandage",
		DisplayName = "Bandage",
		Width = 1,
		Height = 2,
		Rotatable = false,
	}),
	Rifle = table.freeze({
		Id = "Rifle",
		DisplayName = "Rifle",
		Width = 2,
		Height = 3,
		Rotatable = true,
	}),
}

return table.freeze(definitions)
