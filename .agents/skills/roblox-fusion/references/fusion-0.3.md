# Fusion 0.3 API and project patterns

Read this reference when implementing beyond the common path, adapting an older Fusion example, adding UI Labs coverage, or diagnosing ownership and reactivity.

## Scope ownership

Create the outer scope in the client feature lifecycle root with `Fusion.scoped(Fusion)`. A component that shares that lifetime accepts `Fusion.Scope<typeof(Fusion)>`; it returns its root Instance and leaves cleanup to the caller. Create sources before consumers so reverse-order cleanup destroys consumers first.

Use `scope:innerScope()` for replaceable UI whose early cleanup is controlled locally and whose maximum lifetime is the parent scope. `scope:deriveScope()` copies methods but has an independent lifetime; use it only when another owner will always clean it. `Fusion.doCleanup(scope)` consumes the scope. Never retain it, use it as a key, or construct from it afterward.

`scope:New` and `scope:Hydrate` both add the target Instance to the scope, so cleanup destroys it. Enrol an owned Instance in a given scope exactly once: use `New` to create it or `Hydrate` to transfer ownership, and include every known reactive property and special key in that one call. Hydrating a caller-owned Instance transfers destruction ownership; make that transfer explicit or use direct property assignment when the caller must retain ownership.

Inside `scope:Computed(function(use, innerScope) ... end)`, the second argument is a calculation-lifetime scope. Put temporary tasks created during that evaluation in `innerScope`; Fusion cleans the previous inner scope on recomputation. A legacy destructor argument is ignored in 0.3 and emits `destructorRedundant`.

## Reactive reads

- `scope:Value(initial)` owns mutable UI-local state; change it with `value:set(next)`.
- Inside `Computed`, `For*`, or another processor, `use(state)` both reads and registers a dependency.
- `Fusion.peek(state)` performs an untracked snapshot read. Use it in event handlers and imperative diagnostics where rerunning a processor would be wrong.
- `state:get()` was removed in 0.3 and reports `stateGetWasRemoved`.
- `scope:Observer(state):onChange(callback)` observes future changes. `onBind` also invokes the callback immediately. The observer's lifetime follows its scope; the per-callback disposer only removes that callback.

For collection state, prefer `ForKeys`, `ForPairs`, or `ForValues` when item-level reuse matters. Their processor receives `use` and an inner scope; return unique keys from `ForPairs`/`ForKeys` and put item-specific cleanup in the provided inner scope. Under strict Luau, annotate the `ForPairs` processor's second parameter as `rowScope: Fusion.Scope<typeof(Fusion)>`; this is the essential boundary that lets the input pair, numeric `Computed`, and numeric `Tween` infer without redundant callback or state annotations. The maintained fixture contains the executable example. A plain `Computed` is enough when rebuilding a small derived table has no identity or cleanup concern.

## Instances and special keys

Use the 0.3 scoped form:

```luau
local button = scope:New("TextButton")({
	Text = labelState,
	[scope.OnEvent("Activated")] = onActivated,
	[scope.OnChange("AbsoluteSize")] = function(size: Vector2)
		-- UI-local responsive state only.
	end,
	[scope.Children] = children,
	Parent = parent,
}) :: TextButton
```

Properties accept constants or state objects. Fusion creates observers for state-backed properties and owns those observers in the same scope. `scope.Children` accepts Instances, nested tables, or state objects yielding children. `scope.OnEvent` and `scope.OnChange` connections are scope-owned. `scope.Out(property)` writes an Instance property into a `Value`; it is the 0.3 output/ref mechanism exposed by this package.

Do not transplant pre-0.3 destructured constructor examples. Prefer `scope:New`, `scope:Computed`, and other method syntax because every constructor requires a scope as its first argument. The compatibility name `Fusion.cleanup` only emits a warning; use `Fusion.doCleanup`.

## Animation

Create `scope:Spring(goal, speed?, damping?)` or `scope:Tween(goal, tweenInfo?)` after the goal state, then bind the returned state object directly to an animatable property. Speed and damping must be non-negative; avoid NaN goals. Springs and tweens use the Roblox frame scheduler and require Studio/playtest observation for timing and visual quality. Keep animation goals in Fusion while the underlying domain state remains in Charm.

## Charm bridge and Janitor ownership

The feature root owns the seam:

1. Create the feature Janitor and register one non-throwing composite teardown callback before any fallible acquisition.
2. Let that callback capture optional producer disposers and the optional Fusion scope; assign each handle immediately after successful acquisition.
3. Construct the Charm domain object, one Fusion scope, the seeded `Value`, and the view; subscribe to Charm and call `value:set(nextSnapshot)`.
4. During teardown, detach handles before invoking them, protect and attempt every producer disposer first, then protect `Fusion.doCleanup(scope)`, and accumulate labelled failures without throwing through Janitor.
5. After Janitor finishes, explicit destruction reports accumulated failures. Construction failure preserves the body traceback first and appends cleanup failures from the same teardown path.

This composition is required because pinned Janitor 1.18.3 has unordered cleanup and a throwing cleaner aborts the remaining entries. Separate Janitor entries for producers and the Fusion scope do not encode their order or failure isolation. Fusion also aborts the remaining scope loop when a scope task throws, so project-owned scope cleanup callbacks must finish without throwing after recording useful diagnostics. Keep the composite at the owning feature seam; do not introduce a generic project-wide Fusion framework without another demonstrated consumer.

Do not mirror each field into separate competing sources of truth without a presentation reason. UI callbacks call domain operations; domain outcomes flow back through the subscription.

## UI Labs stories

Use `UILabs.CreateFusionStory({ name = ..., summary = ..., fusion = Fusion }, function(props) ... end)`. Build state with `props.scope:Value`, parent into `props.target`, and invoke the same component factory used at runtime. UI Labs owns `props.scope`; do not clean it. Stories should vary explicit inputs and domain snapshots, while runtime networking and service startup remain outside the story.

## Source anchors

- Installed `Packages/_Index/elttob_fusion@0.3.0/fusion/src/init.luau` exposes the exact 0.3 surface.
- Installed `Memory/scoped.luau`, `Memory/innerScope.luau`, and `Memory/doCleanup.luau` define ownership and reverse cleanup.
- Installed `State/Value.luau`, `State/Computed.luau`, `Graph/Observer.luau`, and `State/peek.luau` define reactive reads and cleanup.
- Installed `Instances/New.luau`, `Instances/Hydrate.luau`, `Instances/Children.luau`, `Instances/OnEvent.luau`, and `Instances/OnChange.luau` define Instance ownership and special keys.
- Canonical versioned docs: [scopes](https://elttob.uk/Fusion/0.3/tutorials/fundamentals/scopes/), [values](https://elttob.uk/Fusion/0.3/tutorials/fundamentals/values/), [computeds](https://elttob.uk/Fusion/0.3/tutorials/fundamentals/computeds/), and [errors](https://elttob.uk/Fusion/0.3/api-reference/general/errors/).
