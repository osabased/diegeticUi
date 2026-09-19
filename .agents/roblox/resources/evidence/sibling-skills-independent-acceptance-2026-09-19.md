# Independent sibling-skill acceptance — 2026-09-19

## Scope and evidence boundary

This is an instruction-response evaluation of the current skills. I did not read earlier repair/evaluation reports or expected answers, did not edit application or Studio state, and did not execute a runtime proof. Proposed checks below are acceptance requirements for a real implementation, not claimed results.

All four required cheap pre-use queries returned `HEALTHY` with exit code 0:

| Skill | Record selector | Result |
| --- | --- | --- |
| `$roblox-blink` | `1axen-blink` | `HEALTHY` |
| `$roblox-janitor` | `howmanysmall-janitor` | `HEALTHY` |
| `$roblox-lemonsignal` | `data-oriented-house-lemonsignal` | `HEALTHY` |
| `$roblox-scribe` | `ericplane-scribe` | `HEALTHY` |

The manifest/lock and installed redirects agree with Janitor 1.18.3, LemonSignal 2.0.0, Scribe 2.3.0, and Fusion 0.3.0. `rokit.toml` and the generated Blink headers agree on Blink 1.0.0-pre.8. This is reconciliation evidence only; it does not prove feature behavior.

## 1. Client-to-server loadout request with destruction-safe late results

**Route: pass — use `$roblox-blink` as the primary skill.** This crosses the client/server runtime boundary, so LemonSignal is not the transport and Scribe is not appropriate unless the loadout is itself part of the persistent player-data schema. Janitor is a secondary lifetime owner for the feature's Blink registrations and any spawned work.

Concrete design:

- Extend `src/shared/Network/main.blink` with a reliable client-originating request and a reliable server-originating result. Include a client-generated opaque `requestId` in both messages plus the requested loadout identifier; return the authoritative equipped identifier, acceptance, and a user-safe reason. A two-event protocol is preferable here because correlation and stale-result rejection are explicit.
- Regenerate all Blink outputs and the integrity stamp together with `lute run scripts/generate-blink.luau`; never edit generated Luau. Require `Shared.Network.Client` only from the client lifecycle root and `Shared.Network.Server` only from the server lifecycle root.
- Register the server request listener in `Server/<Feature>.Start`. Treat every field as hostile: validate player eligibility, item existence, ownership, state transition, rate/replay constraints, and request bounds before mutating authoritative state. The request ID is correlation data, not authorization.
- Register the client result listener in `Client/<Feature>.Start`, store its returned disconnect callback in the feature Janitor, and accept a result only when its request ID still matches the active request.
- Give each feature activation a monotonically increasing lifecycle generation and an `alive` flag. Set `alive = false` and advance the generation before teardown, then disconnect the listener and cancel owned work. Every callback checks both generation and active request before applying; if it yields or starts asynchronous work, it repeats the generation check immediately before the final state/UI mutation. This covers a callback already dispatched before disconnection as well as a network result arriving later.
- If restart is supported, create a fresh Janitor and generation for the new activation; do not reuse a Janitor after final `Destroy()`.

Verification derived from the behavior: native tests for request-correlation and generation rejection; invalid/unauthorized and duplicate request cases; canonical `lute run scripts/verify.luau`; then a two-realm Studio playtest proving a valid request reaches the server and its result reaches the client, and proving that destroying the client feature before a deliberately delayed result leaves domain/UI state unchanged and emits no new feature errors. Blink delivery or generated-module construction alone is insufficient proof.

## 2. Session owner with one replaceable worker and final teardown

**Route: pass — use `$roblox-janitor` as the primary skill.** Create one Janitor when the session lifetime begins. Register the worker immediately as `janitor:Add(workerThread, true, "Worker")`; installing a successor at the same index cleans/cancels the old worker before the replacement is stored.

The session also owns a `destroyed` flag and worker generation. A replacement advances the generation, creates/defer-schedules the worker, and registers it immediately. The worker checks that the session is live and its generation is current before committing results, repeating the check after every yield. Final teardown first marks the session destroyed and invalidates the generation, then calls `janitor:Destroy()`. Public replacement methods reject calls after final teardown. Use `Cleanup()` only for a reset that deliberately keeps the owner reusable; it is not final destruction. If teardown order among multiple resources matters, encode that ordering inside one non-throwing composite cleanup callback because Janitor's table iteration order is unspecified.

Focused verification should prove: a replacement prevents worker A from committing after worker B is installed; only B can commit; final destruction prevents the current worker and any later replacement from committing; final `Destroy()` is not followed by Janitor reuse. For an actual runtime thread/lifecycle change, run the canonical verifier and the smallest Studio lifecycle playtest; do not infer cancellation from static registration alone.

## 3. Feature awaiting a local event that may be destroyed first

**Route: pass with an important shape change — use `$roblox-lemonsignal`.** A bare `signal:Wait()` is unsuitable because its hidden one-shot listener has no timeout/cancellation API; disconnecting or destroying the signal can leave the waiting coroutine suspended forever.

Represent the wait as an owned continuation instead: call `signal:Once(callback)`, register the returned connection with `janitor:Add(connection, "Disconnect", "ReadyWait")`, and let the callback continue the feature's work. The feature sets `alive = false` and advances its generation before cleanup. Because `Fire()` schedules callbacks asynchronously and destroying/disconnecting does not cancel callbacks already spawned, the callback checks the generation before applying state and again after any yield. If the signal is shared, the feature must not destroy it; it owns only its connection. If the feature created the whole signal, it may add the signal to its Janitor with explicit `"Destroy"`, while still using the lifecycle guard. LemonSignal `Destroy()` is cleanup, not terminal invalidation, so the owner reference must be discarded or guarded.

Focused verification should cover event-before-destroy (continuation once), destroy-before-event (no continuation), and `Fire()` immediately followed by destroy before asynchronous callback execution (guard rejects the callback). An actual change needs the canonical verifier and a Studio check for the task scheduler/event behavior. If the caller strictly requires a yielding/cancellable wait interface rather than a continuation, the child skill does not provide one; that requirement needs an explicit cancellation abstraction rather than an abandoned `Wait()` coroutine.

## 4. UI waits for player data, is removed, shared bundle remains live

**Route: pass — use `$roblox-scribe` as the primary skill.** Require the one shared bundle's `.Client` half from the client lifecycle feature; do not construct a duplicate bundle and do not call `Data.Stop()` from the UI. The project-level bundle owner retains that authority.

The UI activation owns a fresh Janitor and lifecycle generation. If `Data.IsReady()` is false, start a feature-owned, Janitor-registered task that calls bounded `Data.WaitForData(timeout)` and handles timeout/failure. After readiness, check the lifecycle generation before creating UI state or subscribing. Register every `Observe` disconnect callback in the same UI Janitor, and guard observer callbacks before writing to a view. Removal first invalidates the generation, then destroys the UI Janitor, cancelling the pending readiness task and disconnecting observers. If the UI is Fusion-rendered, `$roblox-fusion` becomes a secondary skill for its scope/view teardown; data readiness alone does not activate Fusion.

Focused native tests can cover a factored lifecycle/generation reducer, but the material acceptance test is a mock-mode Studio server/client integration: remove the UI while data is unavailable, allow the shared bundle to become ready later, assert the removed UI never mounts or updates, and prove another consumer still receives data from the live bundle. Also cover normal readiness and observer disconnection. Run the canonical verifier. This proof establishes mock integration/replication only, not live DataStore persistence.

## 5. Format an ordinary Luau table as a debug string

**Route: pass without any of the five Roblox resource skills.** For a JSON-compatible acyclic table, a protected `HttpService:JSONEncode(value)` is the smallest built-in answer. For an arbitrary Luau debug table, define a small pure formatter with a visited-table set, deterministic key ordering, a depth/item cap, escaped strings, and explicit placeholders for cycles and unsupported values. Plain `tostring(table)` or interpolation only produces the table identity, not its contents.

Keep a one-off formatter local to its owner. Promote it to `src/shared/` only when both runtimes have real callers and a stable formatting contract. Test arrays, maps, nested values, ordering, escaping, cycles, limits, and unsupported values according to the chosen contract. Pure formatting needs native unit coverage and the canonical verifier only; it does not need Studio.

## Implicit routing assessment

| Candidate | Decision across these tasks |
| --- | --- |
| `$roblox-blink` | Primary only for task 1's cross-runtime protocol. Do not use for tasks 2, 3, or 5; do not duplicate Scribe replication in task 4. |
| `$roblox-janitor` | Primary for task 2; secondary ownership for task 1 listeners, task 3 connection/continuation lifetime, and task 4 wait/observer/UI lifetime. |
| `$roblox-lemonsignal` | Primary only for task 3's in-process event. It cannot cross client/server or replicate state. |
| `$roblox-scribe` | Primary only for task 4 when the player data is the adopted persistent/replicated domain. It is not a generic session worker or local-event tool. |
| `$roblox-fusion` | Not activated by any stated requirement. It becomes secondary in task 4 only if rendered Fusion view/scope code is changed; the current skill truthfully remains overall `unverified`, so its own status query and scoped proof limitations must then be honored. |
| `roblox-resource-acquisition` | No ordinary-use activation is needed because all four affected-resource queries are `HEALTHY` and pins reconcile. If a query returns `BLOCKED`/`UNKNOWN`, a pin/header/lock mismatches, or verification drifts, stop affected version-sensitive work and enter `repair/reconcile`; read the matching record/learnings and preserve the fixed project target rather than substituting a package. A safe reusable instruction gap is a soft repair interrupt; a correctness/identity/verification gap is hard. |
| `structure-roblox-projects` | Relevant only where a task adds or relocates lifecycle roots or changes startup/lifecycle integration. The current profile resolves the placement: canonical SSA roots under `src/client/<Feature>` and `src/server/<Feature>`, shared dependencies under `src/shared`, Blink under `src/shared/Network`, and no loader/entrypoint edit for an ordinary feature. An internal edit in an already placed feature remains on the established-project fast path. |
| `codebase-design` | Do not activate for these concrete lifecycle fixes or a one-off formatter. It becomes relevant only if the request broadens into designing a reusable module interface/seam, such as a shared cancellable-await abstraction. |
| `animate` | Do not activate. None of the tasks requests motion, and this web-animation skill is unrelated to Roblox data readiness or cleanup. |

## Failures, uncertainty, and instruction quality

- No required pre-use query failed, and inspected pins/headers/redirects did not expose an identity mismatch.
- The LemonSignal task exposes a deliberate limitation rather than a skill failure: `Wait()` is not cancellable. The skill gives enough information to reject the unsafe shape and use an owned `Once` continuation.
- Blink and Scribe both require owner-supplied invalidation around already-started work; disconnecting a listener or cancelling a caller is not by itself proof that a late callback cannot mutate state. Their current lifecycle sections state this, and the acceptance design makes the generation check concrete.
- Janitor cleanup order is unspecified and a throwing cleaner can stop remaining cleanup. Any implementation requiring ordered teardown must use one guarded composite cleanup rather than relying on separate entries.
- Fusion's current proof does not cover its Janitor composite, rendered motion/input, or clean process exit. That limitation is immaterial unless task 4 changes Fusion rendering, but must remain explicit if it does.
- No runtime or Studio result is claimed in this report. The dirty worktree contains concurrent task-owned changes; this report did not modify or revert them.

## Sources consulted

- Current project `AGENTS.md`, `.agents/roblox/structure.md`, and `docs/verification.md` (canonical gate, behavior verification, Studio playtest).
- Current project skills: `.agents/skills/roblox-blink/SKILL.md`, `roblox-janitor/SKILL.md`, `roblox-lemonsignal/SKILL.md`, `roblox-scribe/SKILL.md`, and `roblox-fusion/SKILL.md`.
- Global routing competitors: `roblox-resource-acquisition/SKILL.md`, `structure-roblox-projects/SKILL.md` plus its canonical SSA reference, `codebase-design/SKILL.md`, and `animate/SKILL.md`.
- Minimal current state: `wally.toml`, `wally.lock`, `rokit.toml`, `src/shared/Network/main.blink`, Blink generated headers, Wally redirect modules, git status, and a CodeGraph read of the current client/server Loadout lifecycle roots. No earlier evidence report was opened.
