# Fusion Studio teardown warning diagnosis — 2026-09-19

## Decision

The callback warning's producer remains **unproved**. It did not recur in one exact unfiltered nine-test rerun, the focused Fusion/demo runs were clean, and a bounded direct `RunScript` probe that left a `BindToRenderStep` callback registered also exited cleanly. The available evidence does not justify attributing the warning to the demo, Fusion, Lest, or Studio itself.

There is, however, a confirmed verification defect: the current Studio suite can report PASS while a new unhandled generic warning is present. Lest 0.6.0 treats its done marker and test outcomes as authoritative and only echoes ordinary Studio output. The project's diagnostic helpers capture generic warnings but deliberately exclude them from `unexpected`, and their connections end before final RunScript/Studio teardown. Therefore the earlier clean-diagnostics claims are stronger than the harness can prove.

The durable first correction is to make unexpected Studio diagnostics affect the suite result and remain observable through process exit. Only after that guard is red-capable should the callback warning be attributed and its owning lifecycle changed. Do not patch Fusion internals, add arbitrary waits, or suppress this message based on the present evidence.

## Observations and bounded reproduction

The original evaluation recorded one unfiltered run in which all nine tests passed and Studio then printed:

```text
Script that implemented this callback has been destroyed while calling callback
```

The focused three-test demo rerun was clean. See `fusion-usage-evaluation-2026-09-19.md:44-45,65`.

This diagnosis used the smallest checks that could distinguish a repeatable failure from a teardown race:

1. `lest run studio --config lest.toml --forbid-only` was rerun once against a freshly built disposable place. All nine tests passed. The expected `[Fusion] cannotAssignProperty` fixture diagnostic appeared, but the callback-destruction warning did not.
2. A one-spec disposable Lest probe registered a render-step callback and intentionally failed so the callback remained registered at suite completion. It did not print the target warning.
3. A direct Studio `--task RunScript` probe registered `BindToRenderStep`, waited up to two seconds for entry, and returned without unbinding it. The callback never entered in edit mode (`DIRECT_CALLBACK_PROBE_RETURNING false`), Studio exited 0, and the output contained no target warning.

These checks show that a live render-step binding alone is insufficient to reproduce the warning. They do not disprove a timing-sensitive callback already in flight. Repeating broad suites would add frequency data but would not establish ownership, so no wider loop was run.

## Proven false-green path

### Project capture excludes this warning

`tests/studio/DiagnosticCapture.luau:24-52` connects `LogService.MessageOut`, runs the body and cleanup, waits three scheduler turns, and disconnects. Its `unexpected` function at lines 78-97 rejects only `MessageError` or a `MessageWarning` containing `[Fusion]`. The exact callback message is a generic warning, so it is accepted even if emitted inside the capture window. Anything emitted after disconnect or during final RunScript destruction is not observed.

The maintained skill fixture has the same gap: `.agents/skills/roblox-fusion/fixtures/FusionIntegrationFixture.luau:59-65,155-165` filters for errors and `[Fusion]` warnings, then disconnects after three waits. Its passing result proves the assertions and the selected diagnostic policy, not a warning-free Studio lifetime.

### Lest does not fail ordinary Studio output

The repository uses Lest 0.6.0. Its Studio bundle resets and runs each spec, emits test events, then immediately prints the done sentinel; it has no process-level finalizer after the last spec. The backend explicitly says the done marker is the completion authority. After protocol start, `Decoded::Output` is printed and returns `Ok(())`; it does not create a failure. Successful infrastructure completion removes both generated script and output log, even when an ordinary warning was echoed.

Primary source at the inspected v0.6.0 commit:

- [Studio backend completion and output decoding](https://github.com/lest-luau/lest/blob/240698e30c0496b21b7a3d7811a0567fde7efdbf/src/backend/studio.rs#L185-L300)
- [ordinary output handling](https://github.com/lest-luau/lest/blob/240698e30c0496b21b7a3d7811a0567fde7efdbf/src/backend/studio.rs#L540-L577)
- [generated Studio suite tail](https://github.com/lest-luau/lest/blob/240698e30c0496b21b7a3d7811a0567fde7efdbf/src/backend/cloud/bundle.rs#L473-L558)
- [Studio execution context](https://github.com/lest-luau/lest/blob/240698e30c0496b21b7a3d7811a0567fde7efdbf/docs/studio.md#execution-context)

The last source also documents that Studio `RunScript` is an edit-mode context in which both `RunService:IsClient()` and `RunService:IsServer()` return true and simulation does not step. This matters to the Fusion candidate below.

### The default verifier does not exercise this suite

`scripts/verification.luau:74-80` defines the full/default gate as format, lint, analyze, unit, and build. Studio is available only as the explicit `--stage studio` path (`scripts/verify.luau:393-398`). This is consistent with the project's separate Studio-playtest rule, but it means `[verify] PASS` alone supplies no runtime teardown evidence.

## Candidate mechanism, not attribution

Requiring the installed Fusion 0.3.0 module starts a package-global scheduler:

- `Packages/_Index/elttob_fusion@0.3.0/fusion/src/init.luau:34-39` installs `RobloxExternal` during module initialization.
- `External.setExternalProvider` stops an old provider and starts the new one (`External.luau:36-47`).
- `RobloxExternal.startScheduler` chooses `BindToRenderStep` when `IsClient()` is true and otherwise uses `Heartbeat`; the corresponding stop function is private (`RobloxExternal.luau:63-96`).
- The frozen public Fusion table exposes scope cleanup but no external-provider or scheduler shutdown API.

Because Lest's edit-mode context reports `IsClient() == true`, Fusion registers a render-step callback on first require. `Fusion.doCleanup(scope)` correctly releases feature-owned scopes but cannot stop that package-global scheduler. A RunScript teardown racing a callback from that module is therefore a plausible explanation for a post-suite warning, especially because all specs share one generated RunScript and native module cache. It is not a validated root cause: the direct render-step probe did not reproduce the warning, the callback did not enter in edit mode, and the same Fusion suite has completed cleanly more than once.

Other possible producers remain open: a different spec's callback, an engine/plugin callback outside the test body, or Studio shutdown itself. The warning lacks a source trace, and the original output artifact was deleted after the successful Lest run, so those candidates cannot be distinguished retrospectively.

## Test ownership gaps

The demo's production owner is substantially correct: `Mount.destroy()` unsubscribes the domain first, calls `Fusion.doCleanup(scope)`, is idempotent, and performs the same cleanup after partial construction failure (`src/client/Loadout/PresetPickerDemo/Mount.luau:25-45,68-99`). The warning is not evidence that this cleanup failed.

Two test gaps still weaken failure-path isolation:

- `tests/studio/LoadoutPresetPickerDemo.spec.luau:62-94` destroys the mount and holder only after all assertions. An earlier assertion failure can leave the feature mounted for later specs. The construction-failure case has the same unprotected holder at lines 98-114. Test fixtures should own these resources with `afterEach`/a protected finalizer so cleanup runs on failure.
- The remount test asserts zero descendants after destroy but does not mutate the returned domain afterward to prove its subscription no longer reaches Fusion state. Add a post-destroy domain change and an observable callback/subscription assertion. Do not make feature owners stop Fusion's package-global scheduler; that lifecycle belongs to the package/runtime host.

The custom owner does not use the project's standard Janitor. Migrating it may improve uniform failure aggregation, but it would not address the unproved package/RunScript teardown warning by itself.

## Recommended correction order

1. **Repair the Studio diagnostic contract.** Extend the Lest Studio head/backend, or adopt an upstream Lest release that does so, to preserve structured `LogService` warning/error events from before spec loading through suite finalization and to inspect output through Studio process exit. Any unexpected engine error or warning must create a synthetic test failure/nonzero result. Keep intentional diagnostics as narrow, explicit expectations attached to the test that produces them; do not globally allow all `[Fusion]` warnings.
2. **Retain evidence on diagnostic failure.** Keep the generated Studio output and identify the active/last spec when an unexpected diagnostic appears. The report path should be printed. This makes a later occurrence attributable instead of ephemeral.
3. **Add suite finalization.** Run registered cleanup/finalizers after the last spec, allow a bounded quiescence turn, then disconnect the structured diagnostic listener and emit the done marker. The backend must still examine output written after the marker and before process exit, because destruction warnings can occur after in-script listeners are gone.
4. **Make the guard falsifiable.** Add a runner-level regression in which an ordinary generic warning fails the Studio suite. Add a teardown regression that deliberately produces the callback-destruction message, or the closest deterministic engine callback-destruction case available, and require a nonzero outcome. A passing assertion followed by that warning must never remain green.
5. **Re-run an attribution matrix only after the guard is red-capable.** Use fresh single-process cases in this order: empty Lest bundle, Fusion require only, scoped `Value`/`Computed`, Tween, maintained fixture, demo, full suite. Stop at the first diagnostic-producing case and reduce it. This prevents a nondeterministic full-suite warning from being assigned to the most visible feature.
6. **If Fusion is then confirmed, fix the runtime seam upstream.** Prefer a supported Fusion host/test shutdown API or provider injection that calls its private provider stop exactly once when the entire test runtime ends. An alternative is a persistent Studio-owned test host whose lifetime outlives Fusion's scheduler. Do not require individual UI components to stop a shared scheduler, reach through Fusion's private modules, vendor-patch `Packages/`, or add timing waits.
7. **Harden test owners.** Guarantee mount/holder cleanup on assertion failures and verify post-destroy domain activity cannot reach the view. This removes cross-spec pollution independently of the warning attribution.

## Acceptance checks for a future implementation

- A spec that emits an unallowlisted generic `MessageWarning` fails the Studio suite and retains its output artifact.
- A spec that emits a `MessageError` after its assertions but before process exit also fails.
- The deterministic callback-destruction regression fails before the repair and passes only when its callback owner is explicitly finalized.
- The existing intentional `cannotAssignProperty` case passes through a test-local exact expectation; changing its text or emitting a second warning fails.
- The demo still passes mount, reaction, idempotent destroy, remount, and partial-construction cleanup checks, plus post-destroy subscription isolation and failure-path cleanup.
- The unfiltered nine-test suite exits cleanly with no unexpected structured or post-marker diagnostics. A focused demo run is also clean.
- No project code imports Fusion private modules, no generated dependency is edited, and no component assumes ownership of Fusion's process-global scheduler.
- Runtime-relevant changes complete the canonical verifier and the project-required Studio playtest; the console remains clean through start and stop.

## Resource/skill status implication

This evidence does not validate a Fusion resource defect or a production regression. It does invalidate the broad claim that the current maintained fixture proves there were no Studio diagnostics. Keep the resource `unverified` and mark the clean-teardown/clean-generic-console portion of the behavioral evidence stale until the diagnostic guard passes its forced-warning regression. The Fusion skill's scope-cleanup guidance remains supported by the inspected component behavior; scheduler shutdown guidance should not be added unless the attribution matrix confirms Fusion and an upstream-supported lifecycle seam exists.

