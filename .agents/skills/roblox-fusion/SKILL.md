---
name: roblox-fusion
description: Implement or troubleshoot Roblox UI with this project's pinned Fusion 0.3 scoped API; use for Fusion components, reactive presentation state, animation, cleanup, and UI Labs stories, not for domain state owned by Charm or non-UI lifecycle code.
---

# Fusion 0.3

Use **Fusion** for reactive Roblox UI rendering, UI-local state, and UI animation. Guidance targets **0.3.0** (source reviewed **2026-09-19**). Resource verification remains **unverified** overall. The maintained core fixture is available for API and direct-scope checks; the removed UI benchmark's composition and input results are historical evidence in the resource record.

## Use when

- Building or repairing client UI components with scoped Fusion state, computed properties, special keys, tweens, or springs.
- Connecting a Charm-owned application/domain state snapshot to a rendered Fusion view.
- Creating a UI Labs Fusion story or diagnosing scope lifetime, cleanup, or old-API errors.

## Do not use when

- A plain Roblox Instance with no reactive behavior is clearer.
- State expresses shared application or domain behavior; keep that state in Charm and bridge a snapshot into Fusion at the view owner.
- The task concerns networking, persistence, service startup, or non-UI lifecycle ownership.

## Prerequisites and installation

1. Confirm `wally.toml` declares `Fusion = "elttob/fusion@0.3.0"` and `wally.lock` resolves the same version.
2. Import the prepared mapping at `ReplicatedStorage.Packages.Fusion` under `--!strict` and use `Fusion.Scope<typeof(Fusion)>` for component scope parameters.

Preserve this project's existing target; this skill grants no dependency upgrade.

## Repair interrupt

- Trigger: Invoke `roblox-resource-acquisition` in `repair/reconcile` mode when this guidance requires guessing, bypassing an instruction, repeating a workaround, or making an undocumented adjustment likely to recur. A harmless task-local adjustment with no reusable guidance defect is not an interrupt.
- Hard defect: Stop dependent work and enter parent repair when correctness, security, canonical identity, selected version, or verification is unreliable.
- Soft defect: Safe reversible immediate work may continue, but invoke the parent `roblox-resource-acquisition` repair diagnosis and surface the reproduction, workaround, and durable correction before completion.
- Handoff: Capture the task, installed state, expected behavior, observed behavior, smallest reproduction, workaround, and proposed durable correction. Parent invocation authorizes diagnosis and reporting, not package edits outside current task authorization.

## Common path

Let the client feature lifecycle root own one scope. Components accept that scope and return their root Instance; they do not clean a borrowed scope.

```luau
--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Fusion = require(ReplicatedStorage.Packages.Fusion)

type Scope = Fusion.Scope<typeof(Fusion)>

local function createLabel(scope: Scope, parent: Instance, text: Fusion.UsedAs<string>): TextLabel
	return scope:New("TextLabel")({
		Parent = parent,
		Text = text,
	}) :: TextLabel
end

return createLabel
```

For list transforms, animation, inner scopes, special keys, and older-example hazards, read [Fusion 0.3 API and project patterns](references/fusion-0.3.md). The maintained core fixture is the compact executable API reference. Keep snippets here smaller than that fixture. Verify owner-level Charm producer disposal, Janitor ownership, and Fusion scope teardown in the feature that uses them.

## Operational reconciliation

- Policy: conditional — the declared pin and lock can establish the expected ordinary-use version cheaply, while the project verifier checks prepared package integrity before completion.
- Installed-state check: Read `wally.toml` and `wally.lock`; both must name `elttob/fusion@0.3.0`, and `Packages/Fusion.lua` must redirect to the installed `elttob_fusion@0.3.0` package.
- Expected identity/state: Resource slug `elttob-fusion`, canonical source `https://github.com/dphfox/Fusion`, package `elttob/fusion`, reviewed release `0.3.0`.
- Current-block check: Before affected use, run `python "$env:USERPROFILE/.agents/skills/roblox-resource-acquisition/scripts/check_resource_status.py" --pair .agents/skills/roblox-fusion .agents/roblox/resources/records/elttob-fusion.yaml`; proceed only on `HEALTHY` (exit 0), and enter full parent-state reconciliation on `BLOCKED` or `UNKNOWN`.
- Integrity gate: Before task completion run `lute run scripts/verify.luau`; it passes only when the command exits 0 and prints `[verify] PASS`.
- Escalation triggers: Enter full reconciliation for a missing or mismatched pin, lock, redirect, or installed package; adoption, upgrade, or an authorized repair that invalidates evidence; verifier failure or drift; a hard defect; or an already-known current block.
- Parent-state check: From the project root, read the matching schema-version 3 record at `.agents/roblox/resources/records/elttob-fusion.yaml` and Fusion-bound entries in `.agents/roblox/resources/learnings/`. Match resource slug `elttob-fusion` and canonical identity `https://github.com/dphfox/Fusion`.
- Mismatch/unknown action: For every state escalation trigger, stop the affected version-sensitive use, perform the parent-state check, and invoke `roblox-resource-acquisition` in `repair/reconcile` mode before continuing.
- Defect handoff: Follow the earlier Repair interrupt handoff as the source of truth for defect evidence and parent activation.

## Client/server placement

Create and render Fusion UI in client feature modules under `src/client/`; UI Labs stories also exercise client presentation. The server does not render with Fusion. Server-owned gameplay state and validated remote outcomes cross the boundary through the project's typed protocol, then the client domain layer translates them into application state. Visual state must never grant authority, validate purchases, or decide server gameplay outcomes.

## Mental model

A scope is an ordered cleanup owner, not component state or an identity token. `Value` stores mutable presentation data; `Computed` derives data and tracks only values read through its `use` callback; `Fusion.peek` reads a snapshot without adding a dependency. `New` and `Hydrate` bind state objects to properties and put created/owned Instances, observers, and connections into the scope. Cleanup runs tasks in reverse construction order and makes the scope unusable, but a throwing scope task aborts the remaining Fusion cleanup.

Charm remains the source of truth for domain and shared application state. The feature root subscribes once and mirrors each current snapshot into a Fusion `Value`. Janitor contains that mount lifetime, but producer disposal and `Fusion.doCleanup(scope)` belong in one protected feature-local composite task when their order matters. Keep hover, focus, responsive layout, and animation goals in Fusion when they are local to the rendered view.

## Lifecycle and cleanup

- Initialization: Create the feature Janitor first and immediately register one composite teardown callback whose captured producer handles and Fusion scope are initially absent. Only then begin fallible acquisition, assigning each handle as soon as acquisition succeeds. This closes the failure window before the scope, subscription, view, input, or network listener exists.
- Reuse: A child whose lifetime exactly matches the owner receives the same typed scope. Use `scope:innerScope()` for a replaceable subtree that may be cleaned early but must not outlive its parent; `deriveScope()` is independent and does not inherit cleanup.
- Cleanup/destruction: This component pattern starts no pending waits or spawned background tasks; if the owning feature adds them, the composite stops or invalidates that pending work before producers and the view. Janitor 1.18.3 iterates entries without an order guarantee and aborts when a cleaner throws, so separate Janitor entries cannot guarantee producer-before-scope teardown or best-effort cleanup. The one composite callback detaches each stored handle before invoking it, protects every producer disposer independently, then protects `Fusion.doCleanup(scope)`. It accumulates labelled errors and returns normally so Janitor can finish; explicit final destruction reports the accumulated errors afterward. Forget the scope and every scoped state object after cleanup because Fusion poisons a cleaned scope to catch reuse.
- Failure: Wrap the whole acquisition and construction body. If it throws, run the same composite teardown, keep the body traceback primary, and append labelled cleanup failures without replacing it. An acquisition API must return its disposer after success or roll back its own partial side effects before throwing; an owner cannot clean a handle it never received. Keep this owner feature-local rather than introducing a project-wide Fusion framework.

## API used by this skill

Use `Fusion.scoped`, `Fusion.doCleanup`, `Fusion.peek`, and the scoped `Value`, `Computed`, `Observer`, `ForKeys`/`ForPairs`/`ForValues`, `New`, `Hydrate`, `Spring`, and `Tween` constructors. Property tables may use `scope.Children`, `scope.OnEvent(name)`, `scope.OnChange(name)`, and `scope.Out(name)`. These are public APIs confirmed in the installed 0.3.0 source. The maintained core fixture covers construction, reactive updates, events, direct scope cleanup, and the strict typed `ForPairs` plus numeric `Tween` construction boundary. Owner-level composition requires feature-specific tests for early acquisition and partial-view failures, a throwing producer disposer, repeated destruction, and a producer write after disposal. Overall resource verification remains unverified because rendered motion and UI Labs behavior are not proven.

## Failure modes

### `scopeMissing`, `stateGetWasRemoved`, or cleanup warnings

An older Fusion example was copied. Convert constructors to scoped method calls, replace `state:get()` with dependency-tracked `use(state)` inside a reactive processor or `Fusion.peek(state)` for an untracked read, and replace `Fusion.cleanup` with `Fusion.doCleanup`.

### `possiblyOutlives`, poisoned scope, or leaked UI

The construction order or ownership boundary is wrong. Create source state before its consumers, ensure dependents do not outlive dependencies, use an inner scope for an early-disposed subtree, and let only the owner clean the scope once. A component must not clean a scope it received.

### UI does not react to a Charm change

Charm and Fusion were treated as one graph. Keep the Charm signal authoritative, subscribe at the feature root, and call `fusionState:set(snapshot)` from the subscription; dispose that subscription during the same feature teardown.

### UI Labs story leaks or differs from runtime

Use `UILabs.CreateFusionStory`, accept `props.scope` and `props.target`, and call the same component factory used by runtime. UI Labs owns the story scope; the story body must not create an unrelated long-lived scope or clean `props.scope` itself.

## Limitations

- Guidance is pinned to Fusion 0.3.0 and does not authorize upgrades or API substitutions.
- Historical desktop benchmark input results do not validate new features. Exercise their actual input, lifecycle, and rendering in Studio.
- The maintained fixture deliberately uses deterministic state changes rather than timing-sensitive Spring/Tween completion.
- The guarded Studio wrapper rejects unexpected warning/error output from the first Lest protocol record through process exit, including output after the done marker. Pinned Lest suppresses ordinary Studio output before its first protocol record, so Studio boot diagnostics remain unobserved.
- UI Labs reload and story interaction remain unverified.

## Security notes

Fusion adds no special credential, HTTP, persistence, or remote trust boundary. Preserve normal Roblox server-authoritative expectations: treat every client callback and displayed value as untrusted presentation, validate all client-controlled remote input on the server, and never make access or economy decisions from Fusion state. Keep the Wally pin and prepared package integrity checks to limit supply-chain drift.

## Verify after installation

- Executable fixture: `fixtures/FusionIntegrationFixture.luau`
- Core runner: `tests/studio/FusionSkillIntegration.spec.luau` imports that compact API and direct-scope reference.
- Run: From the project root after host adoption, run `lute run scripts/verify.luau`, then `lute run scripts/verify.luau --stage studio`. The Studio stage builds its prerequisite disposable place and invokes the guarded `scripts/run-studio-tests.luau` wrapper; use `lute run scripts/run-studio-tests.luau --filter "<test-name-substring>"` only for a focused repeat after the place exists.
- Pass condition: The full verifier exits 0 and prints `[verify] PASS`; the staged Studio verifier exits 0 and prints `[verify] SELECTED STAGES PASS`; the Studio wrapper reports no diagnostic-guard problem; the core fixture reports every named check true and restores its parent baseline. Add feature-owned tests for normal mount/reactivity, early and partial acquisition failure, throwing-producer cleanup continuation, repeated destruction, and post-disposal producer isolation when using that composition.

The Studio wrapper observes warning/error output from the first Lest protocol record through process exit, but pinned Lest omits ordinary Studio boot output before that boundary. The 2026-09-19 benchmark suite and desktop replay are historical after removal of the demo and its tests; re-run the retained fixture for current API evidence. Overall resource verification remains `unverified` because rendered Spring/Tween behavior, UI Labs reload, touch, and gamepad are not covered; see the matching record for the exact proof scope.

## Alternatives

Plain Roblox Instances are the better fit for static, one-off UI with no reactive lifetime. Charm is the project standard for shared/domain application state and complements rather than replaces Fusion rendering. React-Lua is a credible component framework, but replacement or upgrade decisions are informational here and remain with the project's resource authority.

## Provenance

- Resource slug: elttob-fusion
- Package identity: elttob/fusion
- DevForum: No DevForum topic is used or applicable.
- Canonical source/docs: https://github.com/dphfox/Fusion
- Source version/release/commit: 0.3.0
- Source review date: 2026-09-19
- Resource verification: unverified

## Version drift

Before using another Fusion release, inspect that release's source and migration notes for scope construction, graph reads, cleanup, special keys, lifetime checks, and animation changes. Re-run static verification and the maintained Studio fixture before changing this skill's source state or verification claim. Report a newer candidate or incompatibility to the project resource authority instead of advancing the pin independently.
