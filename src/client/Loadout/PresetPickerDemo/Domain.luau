--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Charm = require(ReplicatedStorage.Packages.Charm)

export type Preset = {
	id: string,
	name: string,
	description: string,
	slots: string,
	accent: Color3,
	order: number,
}

export type State = {
	query: string,
	presets: { Preset },
	selectedId: string?,
}

export type Domain = {
	get: () -> State,
	subscribe: ((State, State) -> ()) -> () -> (),
	setQuery: (string) -> (),
	select: (string?) -> (),
	replacePresets: ({ Preset }) -> (),
	removePreset: (string) -> (),
}

local Domain = {}

local function copyAndValidate(presets: { Preset }): { Preset }
	local copy = table.create(#presets)
	local seen: { [string]: boolean } = {}

	for index, preset in presets do
		assert(preset.id ~= "", "preset ids must not be empty")
		assert(not seen[preset.id], string.format("duplicate preset id %q", preset.id))
		seen[preset.id] = true
		copy[index] = preset
	end

	return copy
end

local function containsPreset(presets: { Preset }, presetId: string?): boolean
	if presetId == nil then
		return false
	end
	for _, preset in presets do
		if preset.id == presetId then
			return true
		end
	end
	return false
end

local function withCoherentSelection(state: State, presets: { Preset }): State
	return {
		query = state.query,
		presets = presets,
		selectedId = if containsPreset(presets, state.selectedId) then state.selectedId else nil,
	}
end

function Domain.filter(state: State): { Preset }
	local needle = string.lower(state.query)
	if needle == "" then
		return table.clone(state.presets)
	end

	local matches: { Preset } = {}
	for _, preset in state.presets do
		local haystack = string.lower(table.concat({ preset.name, preset.description, preset.slots }, " "))
		if string.find(haystack, needle, 1, true) ~= nil then
			table.insert(matches, preset)
		end
	end
	return matches
end

function Domain.new(initialPresets: { Preset }, selectedId: string?): Domain
	local presets = copyAndValidate(initialPresets)
	local getState, setState = Charm.signal({
		query = "",
		presets = presets,
		selectedId = if containsPreset(presets, selectedId) then selectedId else nil,
	} :: State)

	return {
		get = getState,
		subscribe = function(callback)
			return Charm.subscribe(getState, callback)
		end,
		setQuery = function(query)
			setState(function(state)
				if state.query == query then
					return state
				end
				return {
					query = query,
					presets = state.presets,
					selectedId = state.selectedId,
				}
			end)
		end,
		select = function(presetId)
			setState(function(state)
				local nextSelected = if containsPreset(state.presets, presetId) then presetId else nil
				if state.selectedId == nextSelected then
					return state
				end
				return {
					query = state.query,
					presets = state.presets,
					selectedId = nextSelected,
				}
			end)
		end,
		replacePresets = function(nextPresets)
			local validated = copyAndValidate(nextPresets)
			setState(function(state)
				return withCoherentSelection(state, validated)
			end)
		end,
		removePreset = function(presetId)
			setState(function(state)
				local remaining: { Preset } = {}
				for _, preset in state.presets do
					if preset.id ~= presetId then
						table.insert(remaining, preset)
					end
				end
				if #remaining == #state.presets then
					return state
				end
				return withCoherentSelection(state, remaining)
			end)
		end,
	}
end

return Domain
