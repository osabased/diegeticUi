---
name: roblox-lemonsignal
description: Implement or troubleshoot local typed event flows with Data-Oriented-House/LemonSignal in Roblox client, server, or shared feature modules; use RemoteEvents for cross-runtime communication and roblox-resource-acquisition for adoption or upgrades.
---

# LemonSignal

Use **LemonSignal** for lightweight in-process signals with reconnectable connections. Guidance targets **2.0.0**, canonical tag `v2.0.0` at commit `540ce9dc5fdce5cb275a7c69c66669706d9c9bd2` (source reviewed **2026-09-16**). Resource verification: **verified** in a Roblox Studio server play session.

## Use when

- A feature needs a typed local event that is not represented by a Roblox Instance.
- A module exposes state changes without coupling producers to consumers.
- An `RBXScriptSignal` needs a LemonSignal-compatible wrapper or reconnectable connection.

## Do not use when

- Client and server must communicate; use a structurally owned `RemoteEvent` or `RemoteFunction` and validate client input on the server.
- A direct function call or one obvious Roblox connection is simpler.
- The task is choosing, adopting, replacing, or upgrading the signal dependency; use `roblox-resource-acquisition` for that lifecycle decision.
- The installed identity or version does not reconcile with the expected package state below.

## Prerequisites and installation

1. From the Roblox project root, inspect `wally.toml` and `wally.lock` before changing dependencies.
2. Declare `LemonSignal = "data-oriented-house/lemonsignal@2.0.0"` under `[dependencies]`, then run `wally install`; let Wally generate `Packages/` and the lockfile.
3. Require `ReplicatedStorage.Packages.LemonSignal` from client, server, or shared Luau code.

## Operational reconciliation

- Policy: required — Wally manifests, lockfiles, and restored package contents can drift independently while this guidance is version-sensitive.
- Installed-state check: Read `wally.toml` for alias `LemonSignal = "data-oriented-house/lemonsignal@2.0.0"`, confirm `wally.lock` resolves `data-oriented-house/lemonsignal` version `2.0.0`, and inspect `Packages/LemonSignal.lua` plus the installed package manifest after `wally install`.
- Expected identity/state: Resource slug `data-oriented-house-lemonsignal`, canonical source `https://github.com/Data-Oriented-House/LemonSignal`, package `data-oriented-house/lemonsignal`, and reviewed state `2.0.0; tag v2.0.0; commit 540ce9dc5fdce5cb275a7c69c66669706d9c9bd2`.
- Parent-state check: Resolve the affected Roblox project root, then read the matching schema-version 3 record at `.agents/roblox/resources/records/data-oriented-house-lemonsignal.yaml` and resource-bound learnings under `.agents/roblox/resources/learnings/`; without a project root, use `~/.roblox-resources/records/data-oriented-house-lemonsignal.yaml` and `~/.roblox-resources/learnings/`. Match the resource slug plus canonical URL and package identity, and stop on a current `blocked_use_or_version`.
- Mismatch/unknown action: Stop the affected version-sensitive use and invoke `roblox-resource-acquisition` in `repair/reconcile` mode.
- Defect handoff: Capture the task, installed identity and version, expected behavior, observed behavior, and smallest reproduction; then invoke `roblox-resource-acquisition` in `repair/reconcile` mode.

## Common path

Create the signal with its owning object or feature, connect consumers, and discard it after final cleanup:

```luau
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LemonSignal = require(ReplicatedStorage.Packages.LemonSignal)

local HealthChanged = LemonSignal.new()

local connection = HealthChanged:Connect(function(health: number)
	print("health", health)
end)

HealthChanged:Fire(75)

connection:Disconnect()
HealthChanged:Destroy()
```

`Fire` schedules each callback asynchronously with `task.spawn` in Roblox. Code after `Fire` may run before callbacks finish, and callback completion order is not a contract.

## Client/server placement

LemonSignal is a shared-realm package and may be required by client, server, and shared modules. Each signal exists only inside the Luau runtime that created it: a client signal does not notify the server, and a server signal does not replicate to clients. Keep authoritative gameplay state and decisions on the server. Use remotes for network boundaries, validate every client-controlled payload on the server, then fan validated results into local LemonSignals if decoupled server-side or client-side observers are useful.

## Mental model

A signal owns a linked set of connections. `Connect` inserts a listener and returns a connection with `Connected`, `Disconnect`, and `Reconnect`. `Once` disconnects its connection before invoking the callback. `Wait` installs a one-shot listener and yields until a future fire. `wrap` forwards an `RBXScriptSignal` through a LemonSignal and stores the backing Roblox connection in `RBXScriptConnection`.

## Lifecycle and cleanup

- Initialization: Create a signal with `LemonSignal.new()` at the lifetime boundary that owns the event.
- Reuse: Connections may disconnect and reconnect. `DisconnectAll()` releases current listeners while leaving their connection objects reconnectable.
- Cleanup/destruction: Call `Destroy()` to disconnect listeners and the backing connection created by `wrap`, then discard the signal reference. `Destroy()` intentionally leaves the signal object reusable; do not treat it as a terminal invalidation guard.
- Janitor integration: Register a LemonSignal connection as `janitor:Add(connection, "Disconnect")`. Janitor otherwise treats the table as a generic object and looks for `Destroy`, which a connection does not expose. A whole signal may be registered with the explicit `"Destroy"` method.

## API used by this skill

- `LemonSignal.new()` creates a signal.
- `LemonSignal.wrap(rbxSignal)` creates a signal backed by an `RBXScriptSignal`.
- `signal:Connect(callback)` and `signal:Once(callback)` return reconnectable connection objects.
- `signal:Wait()` yields until a future `Fire` and returns its arguments.
- `signal:Fire(...)` asynchronously schedules connected callbacks.
- `signal:DisconnectAll()` disconnects every current listener.
- `signal:Destroy()` also disconnects and clears a wrapped `RBXScriptConnection`.
- `connection.Connected`, `connection:Disconnect()`, and `connection:Reconnect()` expose connection state and lifecycle.

## Failure modes

### State checked immediately after `Fire` is stale

Callbacks run through `task.spawn`. Move sequencing into the callback, await a separate completion signal, or yield only in test code; do not assume `Fire` is synchronous.

### Janitor warns that the connection has no `Destroy` method

The connection was added without its cleanup method. Register it as `janitor:Add(connection, "Disconnect")`.

### A coroutine waiting on `Wait` never resumes

`Fire` may have happened before `Wait` connected, or cleanup disconnected the hidden waiter. Establish the waiter before the future event and design cancellation separately; `DisconnectAll()` or `Destroy()` does not resume waiting coroutines.

### A wrapped Roblox event still needs direct engine semantics

Use the original `RBXScriptSignal` when wrapping adds no useful API. When wrapping is justified, retain and destroy the LemonSignal owner so its backing `RBXScriptConnection` is released.

### Calls still work after `Destroy`

This is the documented 2.0.0 behavior. Discard the owner reference or add lifecycle state in the owning module if use-after-cleanup must be rejected.

## Limitations

- The package is local event dispatch, not networking or state replication.
- Callback execution is asynchronous in Roblox and does not provide completion or ordering guarantees.
- `Wait` has no timeout or cancellation API.
- `Destroy` performs cleanup but does not make the signal unusable.
- The package has no dependencies, but it remains a pinned third-party supply-chain input.

## Security notes

LemonSignal introduces no remote, HTTP, credential, persistence, or dynamic-code boundary; it dispatches values inside one runtime. Values are passed to callbacks without validation or copying, so validate untrusted remote input at the server boundary before firing a local signal and avoid treating a client-side signal as authority. Keep the exact Wally pin and review source changes before upgrading.

## Verify after installation

Run: In a disposable Roblox Studio server play session mapped with `ReplicatedStorage.Packages`, execute this from a temporary server Script or SSA feature and remove it afterward:

```luau
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LemonSignal = require(ReplicatedStorage.Packages.LemonSignal)

local signal = LemonSignal.new()
local calls = 0
local connection = signal:Connect(function(value: number)
	calls += value
end)

signal:Fire(2)
task.wait()
assert(calls == 2, `expected asynchronous delivery, got {calls}`)

connection:Disconnect()
signal:Fire(4)
task.wait()
assert(calls == 2, "disconnected callback fired")

connection:Reconnect()
signal:Fire(3)
task.wait()
assert(calls == 5, `expected reconnected delivery, got {calls}`)

signal:Destroy()
print("LEMONSIGNAL_VERIFY_PASS")
```

Pass condition: Studio produces no assertion or require error and prints exactly `LEMONSIGNAL_VERIFY_PASS` once.

## Alternatives

Use a direct callback for a single owner and consumer. Use Roblox `BindableEvent` when an Instance-based event, engine tooling, or Instance hierarchy integration matters more than a pure-Luau signal. GoodSignal is the closest conventional pure-Luau alternative. LemonSignal is the adopted project standard; changing that project-wide decision belongs to `roblox-resource-acquisition`, not an ordinary feature task.

## Provenance

- Resource slug: data-oriented-house-lemonsignal
- Package identity: data-oriented-house/lemonsignal
- DevForum: No DevForum topic is used or applicable
- Canonical source/docs: https://github.com/Data-Oriented-House/LemonSignal
- Source version/release/commit: 2.0.0; tag v2.0.0; commit 540ce9dc5fdce5cb275a7c69c66669706d9c9bd2
- Source review date: 2026-09-16
- Resource verification: verified

## Version drift

Before using a version newer than `2.0.0`, compare its manifest, source, and documentation with the behavior above, especially asynchronous dispatch, connection reconnection, `Wait`, wrapping, and reusable-after-`Destroy` semantics. Rerun the focused Studio proof, then revalidate this skill and its resource bundle before advancing the project pin.
