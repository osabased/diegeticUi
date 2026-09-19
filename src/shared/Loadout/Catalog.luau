--!strict

export type Item = {
	id: string,
	name: string,
	category: string,
	description: string,
	stat: string,
	accent: { number },
	available: boolean,
	lockReason: string?,
}

local items: { Item } = {
	{
		id = "pulse-carbine",
		name = "Pulse Carbine",
		category = "PRIMARY",
		description = "A balanced ion rifle built for controlled bursts at medium range.",
		stat = "68 POWER  •  82 CONTROL",
		accent = { 92, 225, 255 },
		available = true,
	},
	{
		id = "arc-shield",
		name = "Arc Shield",
		category = "DEFENSE",
		description = "Projects a compact directional barrier that rewards deliberate positioning.",
		stat = "90 GUARD  •  54 RECOVERY",
		accent = { 116, 142, 255 },
		available = true,
	},
	{
		id = "recon-drone",
		name = "Recon Drone",
		category = "UTILITY",
		description = "Tags nearby movement and extends the squad's awareness through cover.",
		stat = "76 RANGE  •  70 UPTIME",
		accent = { 91, 240, 173 },
		available = true,
	},
	{
		id = "field-medkit",
		name = "Field Medkit",
		category = "SUPPORT",
		description = "A rapid stabilizer pack for recovering between encounters.",
		stat = "84 RESTORE  •  62 SPEED",
		accent = { 255, 185, 102 },
		available = true,
	},
	{
		id = "grav-hammer",
		name = "Grav Hammer",
		category = "HEAVY",
		description = "A prototype impact system awaiting clearance from the quartermaster.",
		stat = "??? POWER  •  ??? CONTROL",
		accent = { 255, 103, 126 },
		available = false,
		lockReason = "Complete the field certification to unlock.",
	},
}

local byId: { [string]: Item } = {}
for _, item in items do
	byId[item.id] = item
end

local Catalog = {}

function Catalog.all(): { Item }
	return items
end

function Catalog.get(itemId: string): Item?
	return byId[itemId]
end

function Catalog.defaultId(): string
	return "pulse-carbine"
end

return Catalog
