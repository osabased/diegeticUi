---
name: roblox-janitor
description: Implement or troubleshoot lifecycle cleanup with howmanysmall/Janitor in Roblox feature modules when code owns connections, instances, callbacks, threads, promises, tweens, or replaceable resources; skip one-off cleanup with no durable owner.
---

# Janitor

Use **Janitor** to give each Roblox feature or object one explicit owner for its disposable resources. Guidance targets **1.18.3** (source reviewed **2026-09-16**). Resource verification: **verified**.

## Use when

- A feature or object owns several connections, instances, callbacks, threads, promises, or tweens that must end together.
- A replaceable resource needs an index so installing its successor cleans the previous value immediately.
- Cleanup should follow an Instance lifetime through `LinkToInstance`.

## Do not use when

- A single local connection or Instance is created and destroyed in the same obvious lexical scope.
- The task needs deterministic cleanup order; Janitor iterates internal table entries without an order guarantee.
- The installed identity or version does not reconcile with the expected package state below.

## Prerequisites and installation

1. From the Roblox project root, inspect `wally.toml` and `wally.lock` before changing dependencies.
2. Declare `Janitor = "howmanysmall/janitor@1.18.3"` under `[dependencies]`, then run `wally install`; let Wally generate `Packages/` and the lockfile.
3. Require `ReplicatedStorage.Packages.Janitor` from client, server, or shared Luau code. Acquire the module at top level, but create a Janitor where its owning feature or object is initialized.

## Operational reconciliation

- Policy: required — Wally manifests, lockfiles, and restored package contents can drift independently while this guidance is version-sensitive.
- Installed-state check: Read `wally.toml` for alias `Janitor = "howmanysmall/janitor@1.18.3"`, confirm `wally.lock` resolves `howmanysmall/janitor` version `1.18.3`, and inspect the installed Janitor package manifest plus `Packages/Janitor.lua` redirect after `wally install`.
- Expected identity/state: Resource slug `howmanysmall-janitor`, canonical source `https://github.com/howmanysmall/Janitor`, package `howmanysmall/janitor`, version `1.18.3`.
- Parent-state check: Resolve the affected Roblox project root, then read matching schema-version 3 records at `.agents/roblox/resources/records/howmanysmall-janitor.yaml` and resource-bound learnings under `.agents/roblox/resources/learnings/`; without a project root, use `~/.roblox-resources/records/howmanysmall-janitor.yaml` and `~/.roblox-resources/learnings/`. Match the resource slug plus canonical identity and stop on a current `blocked_use_or_version`.
- Mismatch/unknown action: Stop the affected version-sensitive use and invoke `roblox-resource-acquisition` in `repair/reconcile` mode.
- Defect handoff: Capture the task, installed identity and version, expected behavior, observed behavior, and smallest reproduction; then invoke `roblox-resource-acquisition` in `repair/reconcile` mode.

## Mental model

One Janitor represents one ownership boundary. `Add` records both a resource and how to clean it. Functions and threads default to callable/cancel behavior, connections default to `Disconnect`, and other objects default to `Destroy`; prefer an explicit cleanup method when intent matters. An optional index turns a resource into a replaceable named slot: adding another value at that index first cleans the previous value.

## Client/server placement

Janitor is a shared-realm package and may be required by both client and server modules. Client Janitors should own UI, input, camera, and client-only connections; server Janitors should own authoritative gameplay services, player/session resources, and server connections. Janitor performs local cleanup only and sends nothing across the network. Keep game authority on the server and validate every client-controlled remote payload independently of cleanup ownership.

## Common path

Give a component its own Janitor, register every owned side effect immediately, and destroy that Janitor with the component:

```luau
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Janitor = require(ReplicatedStorage.Packages.Janitor)

local WidgetController = {}
WidgetController.__index = WidgetController

function WidgetController.new(root: GuiObject)
	local self = setmetatable({}, WidgetController)
	self._janitor = Janitor.new()
	self._janitor:LinkToInstance(root)

	local button = root:FindFirstChildWhichIsA("GuiButton")
	if button then
		self._janitor:Add(button.Activated:Connect(function()
			local tween = TweenService:Create(root, TweenInfo.new(0.15), {BackgroundTransparency = 0})
			self._janitor:Add(tween, "Cancel", "ActiveTween")
			tween:Play()
		end), "Disconnect")
	end

	return self
end

function WidgetController:Destroy()
	self._janitor:Destroy()
end

return WidgetController
```

Register resources immediately after creation so failures later in setup do not leave them ownerless. In a ModuleLoader lifecycle root, remember that the loader invokes `Init` and `Start`; another owner or `LinkToInstance` must trigger any later teardown.

## Lifecycle and cleanup

- Initialization: Call `Janitor.new()` once when the owning feature, session, or component is created, then add each resource as ownership is acquired.
- Reuse: Call `Cleanup()` to release current entries while keeping the Janitor usable; use stable indices when resources can be replaced individually.
- Cleanup/destruction: Call `Destroy()` for final teardown because it cleans entries and removes the Janitor metatable, making later method calls invalid. `LinkToInstance(instance)` calls `Cleanup()` when that Instance is destroyed.

## API used by this skill

The common surface is `Janitor.new()`, `Janitor.Is()`, `janitor:Add()`, `janitor:AddObject()`, `janitor:AddPromise()`, `janitor:Get()`, `janitor:GetAll()`, `janitor:Remove()`, `janitor:RemoveNoClean()`, `janitor:Cleanup()`, `janitor:Destroy()`, `janitor:LinkToInstance()`, and `janitor:LinkToInstances()`. Read [references/api.md](references/api.md) before using promise integration, multiple instance links, thread cleanup flags, or the list-removal variants.

## Failure modes

### Cleanup warns that a method is missing

The resource fell through Janitor's type defaults and was assumed to expose `Destroy`, or the named method is misspelled. Inspect the concrete object and repair the `Add` call with its real cleanup method, such as `Disconnect` or `Cancel`.

### Cleanup stops before every resource is released

A cleanup callback or custom method threw an error. Janitor 1.18.3 does not isolate those failures, so find the first failing cleaner and make it non-throwing; isolate only deliberately optional cleanup inside that callback after preserving useful error reporting.

### Replacing a resource leaves the old one alive

The calls did not share a stable index. Add both old and new resources under the same index, or call `Remove(index)` before replacement. Use `RemoveNoClean(index)` only when ownership intentionally transfers elsewhere.

### A method call fails after final teardown

`Destroy()` clears the Janitor and removes its metatable. Create a new Janitor for a new lifecycle instead of reusing the destroyed object; use `Cleanup()` when the same owner is intentionally reset.

## Limitations

- Cleanup order is unspecified, so encode ordering inside one cleanup callback when sequencing is required.
- A throwing cleaner can interrupt the remaining cleanup work.
- Adding the exact same object repeatedly without distinct indices does not represent multiple independent cleanup entries.
- `AddPromise` depends on the compatible Promise package resolved through Janitor's Wally dependency chain.

## Security notes

Janitor introduces no special remote, HTTP, credential, persistence, or dynamic-code boundary; it only invokes locally registered cleanup behavior. Treat third-party version changes as a supply-chain decision and keep the exact Wally pin. Preserve normal Roblox server authority: validate client remote inputs on the server, and never let cleanup ownership authorize gameplay actions or trusted state changes.

## Verify after installation

Run: After `wally install`, execute this code in a disposable Roblox Studio server Script mapped with `ReplicatedStorage.Packages`:

```luau
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Janitor = require(ReplicatedStorage.Packages.Janitor)

local janitor = Janitor.new()
local calls = 0
janitor:Add(function()
	calls += 1
end, true, "Callback")

janitor:Cleanup()
janitor:Cleanup()
assert(calls == 1, `expected one cleanup call, got {calls}`)
assert(next(janitor:GetAll()) == nil, "expected no indexed resources after cleanup")
print("JANITOR_VERIFY_PASS")
```

Pass condition: Studio produces no assertion or require error and prints exactly `JANITOR_VERIFY_PASS` once.

## Alternatives

Use direct `Disconnect()` or `Destroy()` calls for a truly local one-resource lifetime. Scythe is the closest package alternative when profiling proves that extremely high cleanup-scope churn matters more than custom cleanup methods and fast indexed removal. Janitor is the adopted project standard; changing that project-wide decision belongs to `roblox-resource-acquisition`, not an ordinary feature task.

## Provenance

- Resource slug: howmanysmall-janitor
- Package identity: howmanysmall/janitor
- DevForum: No DevForum topic is used or applicable
- Canonical source/docs: https://github.com/howmanysmall/Janitor
- Source version/release/commit: 1.18.3
- Source review date: 2026-09-16
- Resource verification: verified

## Version drift

The Wally package version, public methods, default cleanup inference, promise adapter, and instance-link behavior may change in a later upstream release. Before updating beyond `1.18.3`, compare the manifest and source with this guidance, review release notes, rerun the focused Roblox Studio proof, and revalidate both this skill and its resource bundle.
