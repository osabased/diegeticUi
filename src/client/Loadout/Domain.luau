--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Charm = require(ReplicatedStorage.Packages.Charm)
local StateMachine = require(ReplicatedStorage.Shared.Loadout.StateMachine)

export type State = StateMachine.State
export type Domain = {
	get: () -> State,
	subscribe: ((State, State) -> ()) -> () -> (),
	setOpen: (boolean) -> (),
	select: (string) -> (),
	beginEquip: (string) -> boolean,
	resolveEquip: (string, boolean, string, string) -> (),
}

local Domain = {}

function Domain.new(initialState: State?): Domain
	local getState, setState = Charm.signal(initialState or StateMachine.initial())

	return {
		get = getState,
		subscribe = function(callback)
			return Charm.subscribe(getState, callback)
		end,
		setOpen = function(isOpen)
			setState(function(state)
				return StateMachine.setOpen(state, isOpen)
			end)
		end,
		select = function(itemId)
			setState(function(state)
				return StateMachine.select(state, itemId)
			end)
		end,
		beginEquip = function(requestId)
			local before = getState()
			local after = StateMachine.beginEquip(before, requestId)
			if before == after then
				return false
			end
			setState(after)
			return true
		end,
		resolveEquip = function(requestId, accepted, equippedId, message)
			setState(function(state)
				return StateMachine.resolveEquip(state, requestId, accepted, equippedId, message)
			end)
		end,
	}
end

return Domain
