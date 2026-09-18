---
name: roblox-blink
description: Define, generate, or troubleshoot typed Roblox client/server protocols with 1Axen/Blink in this project; use for .blink schemas, generated modules, remote events or functions, and codegen drift, not in-process LemonSignal events, Scribe-owned replication, or Blink adoption and upgrades.
---

# Blink

Use **Blink** to define typed client/server protocols once and generate compact Luau serializers plus realm-specific networking modules. Guidance targets prerelease **1.0.0-pre.8**, tag `v1.0.0-pre.8` at commit `324caf3aec16c209d9d31e335e321783fb89256f` (source reviewed **2026-09-17**).

## Use when

- A project-authored feature needs typed client/server events or request/response functions.
- `src/shared/Network/main.blink` or its generated `Client.luau`, `Server.luau`, or `Types.luau` modules must change.
- Blink generation is stale, fails, or produces a protocol mismatch.

## Do not use when

- Events remain inside one client or server runtime; use LemonSignal or a direct callback.
- Persistent replicated player data is already owned by Scribe; do not layer a duplicate Blink transport over it.
- The task is choosing, installing, replacing, or upgrading Blink; use `roblox-resource-acquisition` for that lifecycle decision.
- The installed identity or version does not reconcile with the expected tool state below.

## Prerequisites and installation

1. From the repository root, inspect `rokit.toml`, the schema, and generated modules before changing anything.
2. Keep `blink = "1Axen/blink@1.0.0-pre.8"` under `[tools]`, then run `rokit install`.
3. Define protocols in `src/shared/Network/main.blink` and run `lute run scripts/generate-blink.luau`. The wrapper invokes `blink compile --profile release src/shared/Network/main.blink` and refreshes the integrity stamp.
4. Commit the generated `Client.luau`, `Server.luau`, `Types.luau`, and `main.blink.stamp` files. Never hand-edit them.

Blink 1.0.0-pre.8 requires the `compile` subcommand, places CLI options before the input path, and uses snake_case schema options such as `client_output`. Older stable documentation shows a different command and option format; follow this project guidance for the pinned prerelease.

## Repair interrupt

- Trigger: Invoke `roblox-resource-acquisition` in `repair/reconcile` mode when this Blink guidance requires guessing, bypassing an instruction, repeated rediscovery, or an undocumented workaround likely to recur; a harmless task-local adjustment is not an interrupt.
- Hard defect: If correctness, security, canonical identity, selected version, or verification is unreliable, stop dependent work and enter parent reconciliation and repair before continuing.
- Soft defect: If the workaround is safe and reversible, immediate work may continue, but invoke the parent repair diagnosis and surface the reproduction, workaround, and durable correction before completion.
- Handoff: Capture the task, installed state, expected behavior, observed behavior, smallest reproduction, workaround, and proposed durable correction. Parent activation authorizes diagnosis and reporting, not edits without current authorization.

## Mental model

The `.blink` file is the protocol source of truth. Blink compiles it into separate client, server, and type modules. Requiring the generated server module creates and owns Blink's hashed `RemoteEvent` and `UnreliableRemoteEvent` instances directly under `ReplicatedStorage`; requiring the client module waits for those instances. Reliable payloads are queued and flushed on `RunService.Heartbeat`, while unreliable payloads are sent immediately. Generated modules expose declared names under `exports` and use PascalCase methods in this project.

## Client/server placement

Keep the schema and all generated modules under `src/shared/Network` so both realms can resolve them, but require each realm-specific module only from its matching lifecycle root:

```luau
-- Server feature
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Network = require(ReplicatedStorage.Shared.Network.Server)

-- Client feature
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Network = require(ReplicatedStorage.Shared.Network.Client)
```

The server remains authoritative. Blink validates and serializes the declared wire shape; it does not establish permission, ownership, rate, distance, sequencing, or gameplay validity. Validate every client-originating request on the server.

## Common path

Add declarations to the existing schema without changing its output paths or casing. For example:

```blink
event Ready = {
	from: Client,
	type: Reliable,
	call: SingleSync,
	data: (loadout_id: string)
}

function GetInventory = {
	data: (),
	return: (items: string[])
}
```

Regenerate with `lute run scripts/generate-blink.luau`, inspect the generated API and diff, then use `Network.exports.Ready.On(...)` on the server and `Network.exports.Ready.Fire(...)` on the client. Functions expose `On` on the server and `Invoke` on the client. The callback returned by `On` disconnects that listener; give it to the owning Janitor as a cleanup callback.

## Operational reconciliation

- Policy: conditional — the Rokit pin and generated version headers identify healthy ordinary use while executable and codegen integrity can drift.
- Installed-state check: Confirm `rokit.toml` pins `blink = "1Axen/blink@1.0.0-pre.8"` and the generated Blink module headers name `1.0.0-pre.8`.
- Expected identity/state: Resource slug `1axen-blink`, canonical source `https://github.com/1Axen/blink`, package identity `1Axen/blink@1.0.0-pre.8`, and reviewed state `1.0.0-pre.8 / v1.0.0-pre.8 / 324caf3aec16c209d9d31e335e321783fb89256f`.
- Integrity gate: Run `lute run scripts/verify.luau` before completing the task; pass only when it prints `[verify] PASS` and exits with code `0`.
- Escalation triggers: Escalate for a missing or mismatched pin/header; adoption, upgrade, or an authorized repair; verifier failure or drift; a hard defect; or an already-known block.
- Parent-state check: After an escalation trigger, resolve the project root, read the matching schema-version 3 record at `.agents/roblox/resources/records/1axen-blink.yaml` and resource-bound learnings under `.agents/roblox/resources/learnings/`, and match resource slug plus canonical identity before inspecting package provenance or internals.
- Mismatch/unknown action: For every state escalation trigger, stop the affected version-sensitive use, perform the Parent-state check, and invoke `roblox-resource-acquisition` in `repair/reconcile` mode before continuing.
- Defect handoff: Follow the earlier Repair interrupt handoff as the source of truth; include the schema, exact command, generated header, and Studio realm in its reproduction.

## Lifecycle and cleanup

- Initialization: Require the generated server module before any client module can depend on its remotes; acquire listeners in the owning SSA feature's `Init` or `Start` phase.
- Reuse: One generated module owns the realm-wide protocol queues and remote bindings. Reuse that module instead of requiring copied generated output or creating parallel Roblox remotes.
- Cleanup/destruction: Every `On` registration returns a zero-argument disconnect function. Register it with the feature's Janitor immediately. Blink's module-level heartbeat and remote connections live for the realm; feature cleanup should release feature listeners, not destroy Blink's shared remotes.
- Replacement: Regenerate all three outputs together after a schema change and deploy compatible client/server code atomically.

## API used by this skill

- Schema declarations: `type`, `event`, `function`, and `scope`.
- Event options: `from` (`Client`, `Server`, or `Both`), `type` (`Reliable` or `Unreliable`), `call` (`SingleSync`, `SingleAsync`, `ManySync`, `ManyAsync`, or `Polling`), and `data`.
- Generated event methods in this project's PascalCase mode: `Fire`, `FireAll`, `FireList`, `FireExcept`, `On`, and `Iter` when applicable to the declaration and realm.
- Generated function methods: server `On`, client `Invoke`.
- Root method: `StepReplication`; normal project use relies on automatic Heartbeat flushing because `manual_replication` is not enabled.

Inspect the generated type signatures before calling a method; direction and call mode intentionally change which methods exist and whether server callbacks receive `Player` first.

## Failure modes

### The CLI rejects an otherwise valid command

For 1.0.0-pre.8, use `blink compile --profile release src/shared/Network/main.blink`. The subcommand is required, and `--profile` must precede the input path.

### Verification says generated modules are stale

The committed integrity stamp no longer matches the schema or exact generated modules. Run `lute run scripts/generate-blink.luau` from the repository root and commit all changed generated outputs plus the stamp. Do not repair generated Luau or the stamp by hand.

### The client waits forever for a hashed remote

The generated server module was not required, failed while loading, or a client/server schema pair is mismatched. Inspect the server console first, confirm both generated headers and hashes came from the same generation, and require `Shared.Network.Server` during server feature startup.

### Selene or formatting reports generated code

The 1.0.0-pre.8 generator emits newer Luau syntax, trailing whitespace, and its own formatting. Keep the generated files in the narrow exclusions in `selene.toml` and `.styluaignore`; validate them through the integrity stamp, canonical verifier, Rojo build, and Studio playtest. Exclude `Client.luau`, `Server.luau`, and `Types.luau` from generic `git diff --check` runs. Do not format or repair them by hand, because that creates permanent codegen drift.

### A listener is silently replaced

`SingleSync` and `SingleAsync` support one listener. Choose a `Many*` call mode when multiple consumers are intentional, or register one boundary listener and fan out locally through LemonSignal.

## Limitations

- `1.0.0-pre.8` is a prerelease and its CLI, IDL, and generated API can change before stable 1.0.0.
- Current stable documentation still describes the older 0.18 command and option format.
- Each compile randomizes paired remote names and numeric event IDs, even when the schema is unchanged. Use the project wrapper for intentional generation, and avoid running it or committing output churn when the schema did not change.
- Generated remotes have hashed names and are implementation details; never look them up or fire them directly.
- Reliable events batch until Heartbeat, so a call does not imply immediate network delivery.
- Blink wire validation is not authorization or abuse prevention.

## Security notes

Treat every client-originating Blink event and function as hostile input even when decoding succeeds. Enforce server-side authorization, object ownership, state transitions, bounds, rate limits, and replay-sensitive rules. Keep secrets and authoritative state off the client. Hashed remote names, compact buffers, and native/optimized generated code are not security boundaries. Review release source and assets before changing the exact prerelease pin.

## Verify after installation

Run: Execute `rokit install`, `blink --version`, `lute run scripts/generate-blink.luau` after an intentional schema change, and `lute run scripts/verify.luau`.

2. In a disposable Studio play session of the built/synced project, require `ReplicatedStorage.Shared.Network.Server` on the server, then require `ReplicatedStorage.Shared.Network.Client` on the client.
3. Confirm both requires return tables with `exports`, the server creates exactly one `RemoteEvent` and one `UnreliableRemoteEvent` for this empty scaffold, print `BLINK_VERIFY_PASS`, inspect the console for parse/runtime errors, and return Studio to Edit mode.

Pass condition: The CLI identifies exactly `1.0.0-pre.8`; the integrity stamp matches the schema and exact generated modules; the verifier's compile smoke test restores Blink's randomized output and prints `[verify] PASS`; the Studio proof prints both `BLINK_SERVER_VERIFY_PASS` and `BLINK_CLIENT_VERIFY_PASS`; the two expected remote classes exist once; no console parse/runtime error appears; and Studio returns to Edit mode.

## Alternatives

Use LemonSignal or direct callbacks for local-only events. Use Scribe for its adopted persistent player-data and replication workflow. A manually owned `RemoteEvent` or `RemoteFunction` can be justified for an engine/tooling integration that Blink cannot model, but document that exception under `Remotes/<Feature>` and keep server validation explicit. Changing the project-wide networking standard belongs to `roblox-resource-acquisition`.

## Provenance

- Resource slug: 1axen-blink
- Package identity: 1Axen/blink@1.0.0-pre.8
- DevForum: No DevForum topic is used or applicable
- Canonical source/docs: https://github.com/1Axen/blink
- Official installation documentation: https://1axen.github.io/blink/getting-started/1-installation
- Source version/release/commit: 1.0.0-pre.8 / v1.0.0-pre.8 / 324caf3aec16c209d9d31e335e321783fb89256f
- Source review date: 2026-09-17
- Resource verification: verified

## Version drift

Before updating beyond `1.0.0-pre.8`, compare the official release and source with this guidance, review CLI and schema-option changes, regenerate a representative protocol, rerun the canonical verifier and both-realm Studio proof, and revalidate this skill plus `.agents/roblox/resources/records/1axen-blink.yaml`.
