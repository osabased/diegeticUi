--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Fusion = require(ReplicatedStorage.Packages.Fusion)
local Janitor = require(ReplicatedStorage.Packages.Janitor)

local Domain = require(script.Parent.Domain)
local View = require(script.Parent.View)

type Scope = Fusion.Scope<typeof(Fusion)>
export type ViewFactory = (Scope, Instance, Fusion.Value<Domain.State>, View.Handlers) -> Frame
export type Options = {
	viewFactory: ViewFactory?,
	decorateProducerDisposer: ((() -> ()) -> () -> ())?,
}

export type Controller = {
	root: Frame,
	domain: Domain.Domain,
	destroy: () -> (),
}

local Mount = {}

local function traceError(problem: unknown): string
	return debug.traceback(tostring(problem), 2)
end

local function appendProtectedFailure(failures: { string }, label: string, callback: () -> ())
	local failure: string? = nil
	local ok = xpcall(callback, function(problem)
		failure = traceError(problem)
		return failure
	end)
	if not ok then
		table.insert(failures, label .. ":\n" .. tostring(failure))
	end
end

function Mount.mount(parent: Instance, presets: { Domain.Preset }, selectedId: string?, options: Options?): Controller
	local janitor = Janitor.new()
	local failures: { string } = {}
	local scope: Scope? = nil
	local unsubscribe: (() -> ())? = nil
	local domain: Domain.Domain? = nil
	local root: Frame? = nil
	local teardownComplete = false

	local function teardown()
		if teardownComplete then
			return
		end
		teardownComplete = true

		local producerDisposer = unsubscribe
		unsubscribe = nil
		if producerDisposer ~= nil then
			appendProtectedFailure(failures, "domain unsubscribe failed", producerDisposer)
		end

		local ownedScope = scope
		scope = nil
		if ownedScope ~= nil then
			appendProtectedFailure(failures, "Fusion cleanup failed", function()
				Fusion.doCleanup(ownedScope)
			end)
		end
	end

	-- Janitor owns one non-throwing composite so producer shutdown always precedes
	-- the Fusion graph and one failed disposer cannot skip the remaining teardown.
	janitor:Add(teardown, true, "CompositeTeardown")

	local bodyError: string? = nil
	local ok = xpcall(function()
		local acquiredDomain = Domain.new(presets, selectedId)
		domain = acquiredDomain

		local acquiredScope = Fusion.scoped(Fusion)
		scope = acquiredScope
		local state = acquiredScope:Value(acquiredDomain.get())

		local acquiredUnsubscribe = acquiredDomain.subscribe(function(nextState)
			state:set(nextState)
		end)
		unsubscribe = acquiredUnsubscribe
		if options ~= nil and options.decorateProducerDisposer ~= nil then
			unsubscribe = options.decorateProducerDisposer(acquiredUnsubscribe)
		end

		local factory: ViewFactory = if options ~= nil and options.viewFactory ~= nil
			then options.viewFactory
			else View.create :: ViewFactory
		root = factory(acquiredScope, parent, state, {
			onQueryChanged = acquiredDomain.setQuery,
			onSelect = function(presetId)
				acquiredDomain.select(presetId)
			end,
		})
	end, function(problem)
		bodyError = traceError(problem)
		return bodyError
	end)
	if not ok then
		janitor:Destroy()
		local message = tostring(bodyError)
		if #failures > 0 then
			message ..= "\n\n" .. table.concat(failures, "\n\n")
		end
		error(message, 0)
	end

	local alive = true
	return {
		root = assert(root, "view factory did not return a root"),
		domain = assert(domain, "domain acquisition did not complete"),
		destroy = function()
			if not alive then
				return
			end
			alive = false
			janitor:Destroy()
			if #failures > 0 then
				error(table.concat(failures, "\n\n"), 0)
			end
		end,
	}
end

return Mount
