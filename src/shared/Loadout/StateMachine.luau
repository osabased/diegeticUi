--!strict
--# selene: allow(incorrect_standard_library_use)

local Catalog = if script ~= nil then require(script.Parent.Catalog) else require("./Catalog")

export type Feedback = "idle" | "pending" | "success" | "rejected"
export type State = {
	isOpen: boolean,
	selectedId: string,
	equippedId: string,
	pendingRequestId: string?,
	feedback: Feedback,
	message: string,
}

local StateMachine = {}

function StateMachine.initial(): State
	local defaultId = Catalog.defaultId()
	return {
		isOpen = false,
		selectedId = defaultId,
		equippedId = defaultId,
		pendingRequestId = nil,
		feedback = "idle",
		message = "Select equipment, then confirm your session loadout.",
	}
end

local function copy(state: State): State
	return table.clone(state)
end

function StateMachine.setOpen(state: State, isOpen: boolean): State
	local nextState = copy(state)
	nextState.isOpen = isOpen
	return nextState
end

function StateMachine.select(state: State, itemId: string): State
	if Catalog.get(itemId) == nil or state.pendingRequestId ~= nil then
		return state
	end
	local nextState = copy(state)
	nextState.selectedId = itemId
	if state.feedback ~= "pending" then
		nextState.feedback = "idle"
		nextState.message = "Review the equipment profile before confirming."
	end
	return nextState
end

function StateMachine.beginEquip(state: State, requestId: string): State
	local item = Catalog.get(state.selectedId)
	if not state.isOpen or state.pendingRequestId ~= nil or item == nil or not item.available then
		return state
	end
	if state.selectedId == state.equippedId then
		return state
	end
	local nextState = copy(state)
	nextState.pendingRequestId = requestId
	nextState.feedback = "pending"
	nextState.message = "Awaiting loadout authorization…"
	return nextState
end

function StateMachine.resolveEquip(
	state: State,
	requestId: string,
	accepted: boolean,
	authoritativeEquippedId: string,
	message: string
): State
	local nextState = copy(state)
	if Catalog.get(authoritativeEquippedId) ~= nil then
		nextState.equippedId = authoritativeEquippedId
	end
	if state.pendingRequestId ~= requestId then
		return nextState
	end
	nextState.pendingRequestId = nil
	nextState.feedback = if accepted then "success" else "rejected"
	nextState.message = message
	return nextState
end

function StateMachine.canEquip(state: State): boolean
	local item = Catalog.get(state.selectedId)
	return state.isOpen
		and state.pendingRequestId == nil
		and item ~= nil
		and item.available
		and state.selectedId ~= state.equippedId
end

return StateMachine
