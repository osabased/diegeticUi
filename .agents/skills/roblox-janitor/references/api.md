# Janitor 1.18.3 API notes

These notes cover only the public Luau surface used by project features. They are derived from the installed `howmanysmall/janitor@1.18.3` source.

## Construction and identity

- `Janitor.new() -> Janitor` creates an empty reusable cleanup scope.
- `Janitor.Is(value) -> boolean` and its `instanceof` alias check the Janitor metatable.

## Adding resources

- `janitor:Add(object, methodName?, index?) -> object` registers and returns the object. Functions and threads default to `true`, connections to `Disconnect`, and other objects to `Destroy`. Prefer an explicit method for tweens and unfamiliar objects.
- Supplying `index` first cleans the previous resource at that index. Without an index, the object itself is the internal key, so the same object does not become multiple independent entries.
- `janitor:AddObject(constructor, methodName?, index?, ...)` calls `constructor.new(...)`, registers the result, and returns it.
- `janitor:AddPromise(promise, index?)` accepts a compatible started Promise and returns Janitor's wrapper promise. Cleaning the entry cancels the original promise. An already settled promise is returned without registration; a non-Promise raises an error.

## Indexed access and removal

- `janitor:Get(index)` returns the resource stored at an index, if present.
- `janitor:GetAll()` returns a frozen copy of indexed resources only.
- `janitor:Remove(index)` cleans and removes the indexed resource.
- `janitor:RemoveNoClean(index)` forgets the indexed resource without cleaning it, transferring responsibility to the caller.
- `janitor:RemoveList(...)` and `janitor:RemoveListNoClean(...)` apply the corresponding operation to several indices.

## Scope cleanup

- `janitor:Cleanup()` cleans all current entries and leaves the Janitor reusable. Calling the Janitor object performs the same operation through `__call`.
- `janitor:Destroy()` calls cleanup, clears the object, and removes its metatable. The object is unusable afterward.
- Cleanup iteration order is unspecified. An error from a registered function or custom cleanup method interrupts cleanup, so registered cleaners should complete without throwing.

## Instance lifetimes

- `janitor:LinkToInstance(instance, allowMultiple?) -> RBXScriptConnection` registers a `Destroying` connection that calls `Cleanup()`. With `allowMultiple` false or omitted, a new link replaces the prior single link; true creates another independent link.
- `janitor:LinkToInstances(...) -> Janitor` links the receiver to each valid Instance and returns a separate Janitor whose cleanup disconnects those links manually.

## Thread settings

The instance properties `SuppressInstanceReDestroy` and `UnsafeThreadCleanup` alter specialized cleanup behavior. Preserve their defaults unless a demonstrated compatibility problem requires a change: suppressing instance re-destroy uses protected destruction, while unsafe thread cleanup may surface thread-related errors.
