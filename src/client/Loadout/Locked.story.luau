--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StateMachine = require(ReplicatedStorage.Shared.Loadout.StateMachine)
local StoryFactory = require(script.Parent.StoryFactory)

local state = StateMachine.setOpen(StateMachine.initial(), true)
state = StateMachine.select(state, "grav-hammer")

return StoryFactory.create("Loadout / Locked", "Unavailable equipment with its locked confirmation state.", state)
