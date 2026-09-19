--!strict

local StoryFactory = require(script.Parent.StoryFactory)

return StoryFactory.create("Preset picker / Populated", "Search and choose among several local loadout presets.", {
	{
		id = "breacher",
		name = "Breach & Clear",
		description = "Close-range entry kit with crowd control.",
		slots = "SHOTGUN / FLASH",
		accent = Color3.fromRGB(255, 177, 92),
		order = 1,
	},
	{
		id = "recon",
		name = "Ghost Recon",
		description = "Quiet scout package with a drone and suppressed rifle.",
		slots = "DRONE / DMR",
		accent = Color3.fromRGB(83, 214, 231),
		order = 2,
	},
	{
		id = "field-medic",
		name = "Field Medic",
		description = "Support preset for stabilizing the squad under fire.",
		slots = "MEDKIT / SMG",
		accent = Color3.fromRGB(105, 220, 153),
		order = 3,
	},
}, "recon")
