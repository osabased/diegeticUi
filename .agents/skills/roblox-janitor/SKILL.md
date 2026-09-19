---
name: roblox-janitor
description: Implement or troubleshoot lifecycle cleanup with howmanysmall/Janitor in Roblox feature modules when code owns connections, instances, callbacks, threads, promises, tweens, or replaceable resources; skip one-off cleanup with no durable owner.
---

# Janitor

Use **Janitor** to give each Roblox feature or object one explicit owner for its disposable resources. Guidance targets **1.18.3** (source reviewed **2026-09-16**). Resource verification: **verified** in isolated Roblox Studio tests of this exact Wally package.

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
2. The project pin is `Janitor = "howmanysmall/janitor@1.18.3"` under `[dependencies]`. For installation or an authorized declaration change, follow [dependency preparation and updates](../../../docs/verification.md#dependency-preparation-and-updates), including stopping this checkout's Rojo server before installation and reviewing intentional lockfile changes.
3. Require `ReplicatedStorage.Packages.Janitor` from client, server, or shared Luau code. Acquire the module at top level, but create a Janitor where its owning feature or object is initialized.

## Repair interrupt

- Trigger: Invoke `roblox-resource-acquisition` in `repair/reconcile` mode when this Janitor guidance requires guessing, bypassing an instruction, repeated rediscovery, or an undocumented workaround likely to recur; a harmless task-local adjustment is not an interrupt.
- Hard defect: If correctness, security, canonical identity, selected version, or verification is unreliable, stop dependent work and enter parent reconciliation and repair before continuing.
- Soft defect: If the workaround is safe and reversible, immediate work may continue, but invoke the parent repair diagnosis and surface the reproduction, workaround, and durable correction before completion.
- Handoff: Capture the task, installed state, expected behavior, observed behavior, smallest reproduction, workaround, and proposed durable correction. Parent activation authorizes diagnosis and reporting, not edits without current authorization.

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

## Operational reconciliation

- Policy: conditional — the Wally declaration and lock resolution identify healthy ordinary use while generated package integrity can drift.
- Installed-state check: Confirm `wally.toml` declares `Janitor = "howmanysmall/janitor@1.18.3"` and `wally.lock` resolves `howmanysmall/janitor` at `1.18.3`.
- Expected identity/state: Resource slug `howmanysmall-janitor`, canonical source `https://github.com/howmanysmall/Janitor`, Wally package `howmanysmall/janitor`, and reviewed state `1.18.3`.
- Current-block check: Before affected use, run `python "$env:USERPROFILE/.agents/skills/roblox-resource-acquisition/scripts/check_resource_status.py" --pair .agents/skills/roblox-janitor .agents/roblox/resources/records/howmanysmall-janitor.yaml`. Proceed only on `HEALTHY`; route `BLOCKED` or `UNKNOWN` to full parent-state reconciliation.
- Integrity gate: Run `lute run scripts/verify.luau` before completing the task; pass only when it prints `[verify] PASS` and exits with code `0`.
- Escalation triggers: Escalate for a missing or mismatched declaration/lock; adoption, upgrade, or an authorized repair; verifier failure or drift; a hard defect; or an already-known block.
- Parent-state check: After an escalation trigger, resolve the project root, read the matching schema-version 3 record at `.agents/roblox/resources/records/howmanysmall-janitor.yaml` and resource-bound learnings under `.agents/roblox/resources/learnings/`, and match resource slug plus canonical identity before inspecting package provenance or internals.
- Mismatch/unknown action: For every state escalation trigger, stop the affected version-sensitive use, perform the Parent-state check, and invoke `roblox-resource-acquisition` in `repair/reconcile` mode before continuing.
- Defect handoff: Follow the earlier Repair interrupt handoff as the source of truth for evidence and parent activation.

## Lifecycle and cleanup

- Initialization: Create the owner-scoped Janitor with `Janitor.new()` when the feature, session, or component lifetime starts; this activates the cleanup owner. Add each resource as ownership is acquired.
- Functions and threads: Register each immediately as `janitor:Add(resource, true, "Worker")`; `true` calls a function or cancels a thread during cleanup. Reuse the stable index when a new worker must replace the old one.
- Reuse: Call `Cleanup()` to release current entries while keeping the Janitor usable; use stable indices when resources can be replaced individually.
- Cleanup/destruction: Janitor owns no package background task or wait. Call `Destroy()` for final teardown: it cancels every registered pending thread, invokes callable cleanup entries, disconnects/destroys the other activated resources, and removes the Janitor metatable. `LinkToInstance(instance)` calls `Cleanup()` when that Instance is destroyed; keep a separate final `Destroy()` path for the owner itself.

## API used by this skill

The common surface is `Janitor.new()`, `Janitor.Is()`, `janitor:Add()`, `janitor:AddObject()`, `janitor:AddPromise()`, `janitor:Get()`, `janitor:GetAll()`, `janitor:Remove()`, `janitor:RemoveNoClean()`, `janitor:Cleanup()`, `janitor:Destroy()`, `janitor:LinkToInstance()`, and `janitor:LinkToInstances()`. Read [references/api.md](references/api.md) before using promise integration, multiple instance links, specialized thread settings, or the list-removal variants.

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

Executable fixture: not-applicable — this repair establishes advice-only instruction and routing guidance; the prior disposable Studio script was not retained as a maintained fixture, so it is historical resource proof rather than current generated-child executable evidence.

Run: With dependencies current under [dependency preparation and updates](../../../docs/verification.md#dependency-preparation-and-updates), execute this code in a disposable Roblox Studio server Script mapped with `ReplicatedStorage.Packages`; ordinary proof reruns do not require reinstalling packages:

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
