--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StateMachine = require(ReplicatedStorage.Shared.Loadout.StateMachine)
local StoryFactory = require(script.Parent.StoryFactory)

local state = StateMachine.setOpen(StateMachine.initial(), true)
state = StateMachine.select(state, "arc-shield")

return StoryFactory.create("Loadout / Normal", "Available equipment selected and ready to confirm.", state)
