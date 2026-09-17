---
name: roblox-scribe
description: Implement or troubleshoot persistent, typed, automatically replicated player data with ericplane/Scribe in Roblox; use for schemas, lifecycle, commands, migrations, or Scribe-backed UI, not simple session-only state or projects standardized on another persistence library.
---

# Roblox Scribe

Use **Scribe** for one typed player-data schema that persists on the server and automatically mirrors allowed values to the owning client. Guidance targets **2.3.0** at tag `v2.3.0` (source reviewed **2026-09-16**). Resource verification: **verified** by the exact tag's headless suite and a live Roblox Studio mock-mode server/client replication proof; live Roblox DataStore service persistence was not exercised.

## Use when

- A project needs persistent per-player data plus a typed server/client accessor tree.
- UI or client systems should react to authoritative replicated values with `Observe`.
- Client requests should enter named, server-validated commands.
- The task involves Scribe schemas, migrations, transactions, offline access, ownership, purchases, or leaderboards.

## Do not use when

- State is temporary, local to one runtime, or already owned by another adopted persistence layer.
- A feature only needs an in-process event; use LemonSignal instead.
- The installed identity or version does not reconcile with the expected package state below.
- The task would create a second Scribe bundle for the same data domain or let a feature stop a project-wide bundle it does not own.

## Prerequisites and installation

1. Read the project structure guidance before choosing the shared bundle's location. In this project, place the bundle under `src/shared/` and consume it from lifecycle-owned client/server features.
2. Declare `Scribe = "ericplane/scribe@2.3.0"` under `[dependencies]` in `wally.toml`, then run `wally install`; do not edit generated `Packages/` contents.
3. Use the new Luau type solver for Scribe's typed accessor API. Runtime behavior does not depend on that editor/typechecker setting.
4. Choose `ProfileStoreIndex` and `ProfileKeyPrefix` deliberately. They are required persistence identity, not decorative labels.

## Operational reconciliation

- Policy: required — the Wally manifest, lockfile, installed redirect, generated package contents, and source-sensitive API guidance can drift independently.
- Installed-state check: Confirm `wally.toml` contains `Scribe = "ericplane/scribe@2.3.0"`, `wally.lock` resolves `ericplane/scribe` version `2.3.0`, `Packages/Scribe.lua` redirects to that package, and its `Version.luau` reports `2.3.0` after `wally install`.
- Expected identity/state: Resource slug `ericplane-scribe`, canonical source `https://github.com/ericplane/Scribe`, Wally package `ericplane/scribe`, and reviewed state `2.3.0; tag v2.3.0; commit e3309e9debdce2d3571406c48ded89f728404795`.
- Parent-state check: Resolve the affected Roblox project root, then read the matching schema-version 3 record at `.agents/roblox/resources/records/ericplane-scribe.yaml` and resource-bound learnings under `.agents/roblox/resources/learnings/`; without a project root, use `~/.roblox-resources/records/ericplane-scribe.yaml` and `~/.roblox-resources/learnings/`. Match the resource slug plus canonical URL and package identity, and stop on a current `blocked_use_or_version`.
- Mismatch/unknown action: Stop version-sensitive work and invoke `roblox-resource-acquisition` in `repair/reconcile` mode.
- Defect handoff: Capture the task, installed identity/version, persistence mode, expected and observed behavior, relevant warnings, and the smallest reproduction; then invoke `roblox-resource-acquisition` in `repair/reconcile` mode.

## Mental model

Construct one shared bundle from a schema. Requiring that shared module returns both runtime halves: `.Server` owns persistence, validation, mutation, and replication, while `.Client` owns the local mirror and reactive reads. The server remains authoritative. Client-side writes only change the local mirror and are overwritten by authoritative updates, so gameplay mutations must flow through a named `Data.Command` registered on the server and `Data.Request` from the client.

Fields replicate to the owning player by default. Wrap secrets or server-only bookkeeping with `Scribe.ServerOnly`. Use `Scribe.Shared` only when every player should receive that data, and treat it as a deliberate visibility expansion.

## Client/server placement

The shared schema module belongs under the project's replicated `Shared` root so both runtimes construct the same bundle contract. Server lifecycle features consume `.Server` for persistence and all authoritative mutations. Client lifecycle features consume `.Client` for reads, observers, and requests. Keep activation, player connections, and yielding waits inside `Init`/`Start` or an owned callback rather than at feature-module top level.

## Common path

Create one shared bundle module, for example `src/shared/PlayerData.luau`:

```luau
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Scribe = require(ReplicatedStorage.Packages.Scribe)

return Scribe({
	Template = {
		Coins = Scribe.Int(0, { Min = 0 }),
		Settings = {
			MusicEnabled = true,
		},
		Moderation = Scribe.ServerOnly({
			LastReview = 0,
		}),
	},
	ProfileStoreIndex = "PlayerData",
	ProfileKeyPrefix = "PLAYER_",
})
```

Do not switch to `Mode = "Mock"` merely because Studio is running. Use mock mode explicitly in disposable tests; use live mode only when Studio API access and the intended test store are understood.

In a server SSA feature, require the shared bundle without starting behavior at module top level, then wait at the per-player boundary:

```luau
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PlayerData = require(ReplicatedStorage.Shared.PlayerData).Server

local Feature = {}

local function onPlayer(player: Player)
	task.spawn(function()
		local data, reason = PlayerData.WaitForData(player, 30)
		if data == nil then
			warn(`Player data unavailable for {player.UserId}: {tostring(reason)}`)
			return
		end

		data.Coins.Add(1)
	end)
end

function Feature:Start()
	Players.PlayerAdded:Connect(onPlayer)
	for _, player in Players:GetPlayers() do
		onPlayer(player)
	end
end

return Feature
```

Own the connection with the feature's Janitor in production code. Register commands once during server initialization, validate every argument and authorization rule in the handler, and keep the handler's mutation atomic where appropriate.

On the client, require the same shared bundle so Scribe's handshake starts, wait for readiness, and own each observer's disconnect callback:

```luau
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PlayerData = require(ReplicatedStorage.Shared.PlayerData).Client

if PlayerData.WaitForData(30) then
	local disconnect = PlayerData.Coins.Observe(function(coins)
		print(`Coins: {coins}`)
	end)
	-- Add `disconnect` to the UI or feature Janitor as a callable cleanup.
end
```

## Lifecycle and cleanup

- Initialization: Construct the bundle once in the shared module. Require that module from both server and client lifecycle roots; requiring only the server half leaves the client handshake absent.
- Reuse: Keep one bundle alive for the application's data domain. Reuse accessors after readiness and replace UI observers by disconnecting the old callback before registering its successor.
- Readiness: On the server, `WaitForData(player, timeout)` can return `nil, reason`; handle it. On the client, gate reads and observers with `IsReady()` or `WaitForData(timeout)` when startup ordering is uncertain.
- Mutation: Keep writes on the server. Use `Transaction` for grouped non-yielding mutations; do asynchronous work before or after the transaction.
- Cleanup/destruction: Observer calls return disconnect functions; give them to Janitor. `Data.Stop()` is for the project-level owner, tests, or storybooks and is idempotent. Ordinary features must not stop a shared bundle they did not create.

## API used by this skill

The common surface is the `Scribe(options)` constructor, declarators such as `Int`, `Number`, `String`, `Optional`, `ArrayOf`, `SetOf`, `MapOf`, `DictOf`, `ServerOnly`, `Shared`, and `Session`, plus `.Server`, `.Client`, `WaitForData`, accessor `Get`/`Set`/`Observe`, `Transaction`, server `Command`, client `Request`/`RequestOnce`, and `Stop`. Read [references/api.md](references/api.md) before using migrations, offline updates, shared visibility, collections, purchases, ownership, leaderboards, or exchanges.

## Failure modes

### Client never becomes ready

Confirm the same shared bundle module is required in both runtimes and resolves to the same installed Scribe package. Check output for handshake or transport warnings, and avoid constructing duplicate bundles for the same data domain.

### Server access reports loading or returns no accessor

The profile has not become ready or loading failed. Call `WaitForData(player, timeout)` and handle its reason instead of indexing the accessor immediately. Do not hide repeated failures with an infinite yield.

### Studio data appears not to persist

Check the configured mode and Studio API access. `Mode = "Mock"` is intentionally isolated; without usable DataStore access, live persistence cannot be proven. Never point a disposable test at production data unintentionally.

### A client mutation disappears

Client accessor writes are local-only. Move the mutation into a validated server command and call it with `Data.Request` from the client.

### A transaction fails or rolls back

Transactions must not yield. Remove `task.wait`, DataStore, MarketplaceService, or other asynchronous calls from the transaction body, and perform those operations outside it.

## Limitations

- Adoption verified the exact tag through its headless shim/simulation suite and a live Roblox Studio mock-mode server/client replication session, but not through live DataStore service persistence.
- Typed accessor inference requires the new Luau type solver.
- Automatic replication is primarily owner-scoped; `Shared` expands visibility and can increase bandwidth and disclosure risk.
- Persistence, monetization, leaderboards, and cross-server behavior still depend on Roblox service availability and platform limits.
- Guidance is pinned to `2.3.0`; upgrades require an intentional resource refresh.

## Security notes

Treat every client request as untrusted. Validate command names, arguments, ownership, rates, and game-state preconditions on the server; do not accept a client-reported balance, entitlement, receipt, or cooldown. Mark secrets and moderation state `ServerOnly`, and review every `Shared` field for privacy and bandwidth impact. Keep store names and test modes deliberate so development cannot overwrite production profiles. Preserve the exact package pin as part of the supply-chain boundary.

## Verify after installation

Run: From the project root, execute `wally install`, then perform the disposable Roblox Studio mock-mode integration described below.

Run these checks from the project root:

1. Run `wally install` and confirm the manifest, lock entry, redirect, and installed `Version.luau` all resolve `ericplane/scribe@2.3.0`.
2. In a disposable Studio play test, construct a separate test bundle with a unique `ProfileStoreIndex`, `ProfileKeyPrefix`, and `Mode = "Mock"`; require it from both server and client.
3. On player join, assert server `WaitForData` returns an accessor, register a client observer, increment a server field, and confirm the observer receives the authoritative value.
4. Stop only that disposable test bundle during test teardown.

Pass condition: no require, handshake, timeout, or schema error occurs; the server obtains an accessor; and the client observer receives the server mutation. A mock pass verifies integration and replication, not live DataStore persistence.

## Alternatives

Use Roblox `DataStoreService` directly for a small service with intentionally custom session, schema, and replication logic. Use ProfileStore directly when the project wants lower-level session-locked profiles without Scribe's typed accessor and replication layer. Scribe is now the adopted project standard for this role; replacing it is a parent resource decision handled through `roblox-resource-acquisition`.

## Provenance

- Resource slug: ericplane-scribe
- Package identity: ericplane/scribe
- DevForum: No DevForum topic is used or applicable
- Canonical source/docs: https://github.com/ericplane/Scribe
- Source version/release/commit: 2.3.0; tag v2.3.0; commit e3309e9debdce2d3571406c48ded89f728404795
- Source review date: 2026-09-16
- Resource verification: verified

## Version drift

The schema declarators, type-level API, persistence modes, request reasons, service integrations, and transport behavior may change after `2.3.0`. Before upgrading, compare the new tag and package contents, review the changelog, rerun upstream and project integration proofs, refresh the resource record, and revalidate this child skill and the full generated-skill catalog.
