--!strict

local StoryFactory = require(script.Parent.StoryFactory)

return StoryFactory.create(
	"Preset picker / Empty",
	"No local presets are available; the empty state remains visible and searchable.",
	{},
	nil
)
