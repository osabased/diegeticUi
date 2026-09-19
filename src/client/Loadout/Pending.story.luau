--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StateMachine = require(ReplicatedStorage.Shared.Loadout.StateMachine)
local StoryFactory = require(script.Parent.StoryFactory)

local state = StateMachine.setOpen(StateMachine.initial(), true)
state = StateMachine.select(state, "recon-drone")
state = StateMachine.beginEquip(state, "story-request")

return StoryFactory.create("Loadout / Pending", "An in-flight request with duplicate confirmation disabled.", state)
