# Older sibling skill parent-contract repair — 2026-09-19

## Scope

Repaired the project-local `roblox-blink`, `roblox-janitor`, `roblox-lemonsignal`, and `roblox-scribe` children against the current generated-resource-skill contract. No application source, package state, upstream pin, Fusion artifact, or global parent skill changed.

## Reproduction

The Codex catalog validator reported 13 errors:

- all four children lacked `Current-block check` and `Executable fixture` fields;
- all four cleanup contracts omitted pending wait/task cancellation or an explicit absence;
- Janitor initialization did not identify the behavior-activating operation and owner lifetime.

Command:

```powershell
python C:/Users/Lowle/.agents/skills/roblox-resource-acquisition/scripts/validate_skill_catalog.py --host codex .agents/skills/roblox-blink .agents/skills/roblox-janitor .agents/skills/roblox-lemonsignal .agents/skills/roblox-scribe
```

## Correction

- Added the exact read-only `check_resource_status.py --pair` query to each conditional reconciliation contract, with `HEALTHY` as the only ordinary-use result and `BLOCKED`/`UNKNOWN` routed to full reconciliation.
- Grounded cleanup in the pinned implementations: Blink feature listeners and listener-spawned work remain feature-owned; Janitor cancels registered threads but owns no package background task; LemonSignal cannot cancel already spawned callbacks or resume a coroutine abandoned in `Wait`; Scribe feature waits remain feature-owned while the bundle owner alone uses idempotent `Stop`, flushing server data first when needed.
- Marked the executable-fixture boundary truthfully. The disposable scripts used by the older upstream resource proofs were not retained, so this child repair claims advice-only guidance and does not relabel those runs as current generated-child executable evidence.
- Preserved upstream resource verification. Downgraded repaired host entries to `installed`, current independent behavioral/catalog status to unclaimed/unverified, and recorded the earlier child behavior/routing claims as historical until independent instruction-response and explicit-activation checks are rerun.

## Validation

Fresh results after the correction:

- `validate_skill.py` passes for all four children, with only the expected no-DevForum advisory.
- The four-child catalog passes with fingerprint `sha256:23de91baa7c76ec8591bba87354cbe9b533e59959281039650cd602198cd273f`.
- The project catalog plus `roblox-resource-acquisition`, `structure-roblox-projects`, and `codebase-design` routing competitors passes with unchanged activation fingerprint `sha256:aaf6fea8dcfe9fe4baffba705a8b58ed53db8e49223751eb6dcd8810f9962a42` and no static overlap cluster.
- Same-agent instruction-response audit passed the boundaries below. This is contract evidence only; it is not independent activation or runtime proof.

No Roblox Studio session or package command ran during this repair.

## Independent qualification scenarios

Use these prompts with a fresh independent agent before restoring `operational` host state:

1. **Blink:** “Add a client-to-server loadout request and ensure feature teardown cannot keep applying late results.” Expected boundary: select `roblox-blink`; require a `HEALTHY` block query; validate client input on the server; own the returned listener disconnect and cancel/invalidate listener-spawned work; preserve realm-global Blink remotes and heartbeat.
2. **Janitor:** “Give a session owner one replaceable worker thread and a final teardown path.” Expected boundary: select `roblox-janitor`; create `Janitor.new()` at the owner lifetime boundary; register the thread immediately with callable/cancel cleanup and a stable index; use `Destroy()` for final teardown; make no cleanup-order guarantee.
3. **LemonSignal:** “A feature waits for a local event while it can be destroyed before the event fires.” Expected boundary: select `roblox-lemonsignal`; state that `Destroy()` disconnects the hidden waiter but does not resume/cancel its coroutine; require an external cancellation/invalidation path; avoid Blink because the event is in-process.
4. **Scribe:** “A UI feature waits for player data and is removed while the shared player-data bundle remains live.” Expected boundary: select `roblox-scribe`; cancel/invalidate the feature-owned wait task and observer; do not call bundle-level `Data.Stop()` from the feature; reserve `Stop()` for the bundle owner and flush server data first when persistence matters.
5. **Negative routing:** “Format a plain Luau table as a debug string.” Expected boundary: select none of the four resource skills.

Each positive scenario must also exercise explicit `$skill-name` invocation and the conditional `HEALTHY`/`BLOCKED`/`UNKNOWN` branch without executing commands recorded inside resource evidence.

## Material limitations

- Structural and static catalog validation are current.
- Independent instruction-response, explicit activation, and runtime integration were not rerun in this repair.
- The prior upstream resource proofs remain valid only as upstream resource evidence; they do not establish current generated-child executable integration.
