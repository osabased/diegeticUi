--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StateMachine = require(ReplicatedStorage.Shared.Loadout.StateMachine)
local StoryFactory = require(script.Parent.StoryFactory)

local state = StateMachine.setOpen(StateMachine.initial(), true)
state = StateMachine.select(state, "field-medkit")
state = StateMachine.beginEquip(state, "story-request")
state =
	StateMachine.resolveEquip(state, "story-request", false, state.equippedId, "Server rejected the loadout change.")

return StoryFactory.create("Loadout / Error", "Rejected server acknowledgement with recovery feedback.", state)
