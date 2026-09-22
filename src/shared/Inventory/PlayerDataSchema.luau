--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Scribe = require(ReplicatedStorage.Packages.Scribe)

export type Mode = "Live" | "Mock" | "NoSave"

export type Options = {
	ProfileStoreIndex: string,
	ProfileKeyPrefix: string,
	Mode: Mode?,
	IsRunning: boolean?,
	Banner: boolean?,
}

local PlayerDataSchema = {}

local function createTemplate()
	return {
		Inventory = {
			Revision = Scribe.Int(0, {
				Min = 0,
			}),
			Items = Scribe.DictOf({
				DefinitionId = Scribe.String("", {
					MaxLength = 64,
				}),
				Column = Scribe.Int(1, {
					Min = 1,
					Max = 255,
				}),
				Row = Scribe.Int(1, {
					Min = 1,
					Max = 255,
				}),
				Rotated = false,
			}, {
				MaxKeys = 256,
				MaxKeyLength = 64,
			}),
		},
	}
end

function PlayerDataSchema.createBundle(options: Options)
	return Scribe.new({
		Template = createTemplate(),
		ProfileStoreIndex = options.ProfileStoreIndex,
		ProfileKeyPrefix = options.ProfileKeyPrefix,
		Mode = options.Mode,
		IsRunning = options.IsRunning,
		Banner = options.Banner,
	})
end

return table.freeze(PlayerDataSchema)
