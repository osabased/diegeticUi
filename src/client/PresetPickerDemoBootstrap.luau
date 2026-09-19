--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Janitor = require(ReplicatedStorage.Packages.Janitor)
local Mount = require(ReplicatedStorage.Client.Loadout.PresetPickerDemo.Mount)

local PresetPickerDemoBootstrap = {}

type JanitorOwner = typeof(Janitor.new())
type Lifetime = {
	owner: JanitorOwner,
	failures: { string },
}

local lifetime: Lifetime? = nil

local PRESETS = {
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
}

local function traceError(reason: unknown): string
	return debug.traceback(tostring(reason), 2)
end

local function appendProtectedFailure(failures: { string }, label: string, cleanup: () -> ())
	local problem: unknown = nil
	local ok = xpcall(cleanup, function(reason)
		problem = reason
		return reason
	end)
	if not ok then
		table.insert(failures, `{label}: {tostring(problem)}`)
	end
end

local function releaseLifetime(): string?
	local active = lifetime
	lifetime = nil
	if active == nil then
		return nil
	end

	appendProtectedFailure(active.failures, "Janitor destruction failed", function()
		active.owner:Destroy()
	end)
	return if #active.failures == 0 then nil else table.concat(active.failures, "\n")
end

function PresetPickerDemoBootstrap.Start()
	local priorFailure = releaseLifetime()
	if priorFailure ~= nil then
		error(priorFailure, 0)
	end

	local active: Lifetime = {
		owner = Janitor.new(),
		failures = {},
	}
	lifetime = active

	local gui: ScreenGui? = nil
	local controller: Mount.Controller? = nil
	active.owner:Add(function()
		local mounted = controller
		controller = nil
		if mounted ~= nil then
			appendProtectedFailure(active.failures, "preset picker mount cleanup failed", mounted.destroy)
		end

		local ownedGui = gui
		gui = nil
		if ownedGui ~= nil then
			appendProtectedFailure(active.failures, "preset picker GUI cleanup failed", function()
				ownedGui:Destroy()
			end)
		end
	end, true, "MountedDemo")

	local bodyError: string? = nil
	local ok, problem = xpcall(function()
		local playerGui = Players.LocalPlayer:FindFirstChildOfClass("PlayerGui")
		if playerGui == nil then
			error("PresetPickerDemoBootstrap requires LocalPlayer.PlayerGui during client activation", 0)
		end

		local acquiredGui = Instance.new("ScreenGui")
		gui = acquiredGui
		acquiredGui.Name = "PresetPickerDevelopmentPreview"
		acquiredGui.DisplayOrder = 100
		acquiredGui.IgnoreGuiInset = true
		acquiredGui.ResetOnSpawn = false
		acquiredGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
		acquiredGui:SetAttribute("DevelopmentOnly", true)
		controller = Mount.mount(acquiredGui, PRESETS, "recon")
		acquiredGui.Parent = playerGui
	end, function(reason)
		bodyError = traceError(reason)
		return bodyError
	end)
	if not ok then
		local cleanupFailure = releaseLifetime()
		local message = tostring(bodyError or problem)
		if cleanupFailure ~= nil then
			message ..= "\n\n" .. cleanupFailure
		end
		error(message, 0)
	end
end

function PresetPickerDemoBootstrap.Destroy()
	local failure = releaseLifetime()
	if failure ~= nil then
		error(failure, 0)
	end
end

return PresetPickerDemoBootstrap
