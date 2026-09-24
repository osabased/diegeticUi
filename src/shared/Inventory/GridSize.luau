--!strict

local Types = require(script.Parent.Types)

local gridSize: Types.GridSize = {
	Columns = 4,
	Rows = 4,
}

return table.freeze(gridSize)
