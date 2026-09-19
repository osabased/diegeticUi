# Verification

## Canonical gate

The required local and CI gate remains:

```sh
lute run scripts/verify.luau
```

Python 3.10 or newer must be available as `python`; CI uses Python 3.12. With no arguments, the verifier checks prepared dependencies, checks Blink generation while restoring its randomized output, creates the Rojo sourcemap, checks formatting, lints and analyzes Luau, runs Luau and Python regression tests, builds the default disposable place, and verifies the development and release profiles. This is the only invocation that can print `[verify] PASS`. Verification never installs packages or rewrites package typings, so it can run while Rojo serves the project.

## Dependency preparation and updates

Before any package installation, stop the Rojo server serving this checkout, including before direct `wally install`. Record whether it was running so it can be resumed after successful preparation. Preserve unrelated Rojo servers.

For initial setup with the committed lockfile, or when verification reports missing or stale preparation without an intentional dependency change, run:

```sh
lute run scripts/prepare-dependencies.luau
```

For an authorized dependency addition, removal, or version change:

1. Update the intended declaration in `wally.toml`.
2. With Rojo still stopped, run `wally install` to resolve the new graph and update `wally.lock`.
3. Inspect `git diff -- wally.toml wally.lock`; confirm the intended direct dependency and explain any transitive changes before continuing. Keep both files in the change.
4. Run `lute run scripts/prepare-dependencies.luau` against that reviewed lockfile, then run the canonical verifier.

Preparation runs Wally, generates a Rojo sourcemap, then generates package typings. It fails on lockfile drift and restores the original lockfile; it does not authorize or resolve intentional updates. Its stamp is invalidated at the start and recorded only after all steps succeed. Resume a previously running Rojo server after preparation succeeds; leave it stopped if preparation fails. Wally 0.3.2 replaces the live `Packages/` tree, which can crash Rojo 7.7.0's watcher; the preparation command does not stop Rojo automatically. The pinned typing generator requires fresh Wally shims, so preparation always installs before generating types. CI prepares dependencies before running the gate.

A single local SHA-256 stamp in `.verify/dependencies.sha256` covers `rokit.toml`, `wally.toml`, `wally.lock`, `default.project.json`, and every prepared package file. Changed inputs or missing, added, or modified package files require preparation again. Ordinary source edits and sourcemap regeneration do not. Deleting `.verify/` also removes the stamp. The verifier checks this stamp under the `wally` prerequisite and fails with the exact preparation command when it is stale; it never repairs dependencies implicitly.

The unit stage also runs `lute run tests/unit/Dependencies.regression.luau` to check preparation freshness with disposable filesystem fixtures.

It also checks README's relative file links with `lute run tests/unit/Documentation.regression.luau`, including any linked UI example entry points. This detects deleted or moved linked examples; it does not validate prose, remote URLs, or Markdown anchors.

Python's standard-library `unittest` runner executes `tests/artifacts/test_*.py` during the unit stage. These regressions exercise the profile artifact checker without changing project source.

## Focused runs

For a narrower loop, select one or more stages:

```sh
lute run scripts/verify.luau --stage format
lute run scripts/verify.luau --stage lint --stage analyze
lute run scripts/verify.luau --stage unit
lute run scripts/verify.luau --stage build
lute run scripts/verify.luau --stage studio
```

Selections are deduplicated and execute once in canonical order. The verifier adds only the preparation required by each selected stage:

| Selected stage | Automatic preparation |
| --- | --- |
| `format`, `lint` | None |
| `unit`, `build` | Prepared dependency check |
| `analyze` | Prepared dependency check, Rojo sourcemap, Lest framework bootstrap |
| `studio` | Prepared dependency check, disposable place build |

The Studio stage is deliberately absent from the canonical gate. It requires a local Roblox Studio installation and runs Lest in edit-mode `RunScript`, while CI remains platform-neutral.

## Build profiles

The build stage first creates the disposable default place at `.verify/diegeticUi.rbxlx`, then runs `python tests/artifacts/verify_preset_picker_profiles.py`. The checker retains its generated development and release place files and sourcemaps beneath `.verify/preset-picker-profiles/`. It proves that the development profile contains the complete preset picker preview and authored stories, while `release.project.json` excludes demos, stories, and their dedicated helpers but retains the Loadout runtime and normal service roots.

## Reports and failures

Every valid run writes a unique schema-version-1 JSON report beneath `.verify/reports/` and prints its path. Reports contain the selected stages, whether the full gate ran, the overall outcome, ordered stage records with status, duration, exit code, and reason, and an additive `errors` collection for report, orchestration, or cleanup failures.

Failed checker commands also retain `diagnostics.arguments`, `diagnostics.stdout`, and `diagnostics.stderr` on the failed stage. Read these fields for the original error before rerunning a check; the short `reason` identifies only the failed stage. Command output is captured and echoed after each command completes. Successful command output is not stored in the report, and failures before a checker launches use `reason` without command diagnostics. Older reports may omit these additive fields.

The unit stage runs `lute run tests/unit/VerificationDiagnostics.regression.luau` to exercise the actual CLI in a disposable fixture: an invalid source must fail with its original checker output and exit code preserved; a corrected run must pass without overwriting that failure report. The fixture uses only formatting and never installs packages or changes live project source.

- `passed` means the stage or prerequisite completed.
- `failed` identifies the first failing stage and preserves its nonzero exit code.
- `not_run` with `unselected` means the stage was outside the request.
- `not_run` with `blocked_by:<stage-or-finalizer>` means a stage, report update, or cleanup failure prevented it from running.

Reports are replaced through same-directory temporary and backup files so a failed update retains the last parseable snapshot. The verifier always attempts exact disposable-place cleanup before its final report write; cleanup or persistence failures force a nonzero result and suppress PASS.

A focused success prints `[verify] SELECTED STAGES PASS — full gate not run`. Reports are retained across runs so independent build evidence does not overwrite an earlier unit-test failure. They are generated artifacts and remain ignored by Git.

## Studio construction suite

Run the engine-backed construction tests through the verifier:

```sh
lute run scripts/verify.luau --stage studio
```

The verifier builds `.verify/diegeticUi.rbxlx`, then invokes `scripts/run-studio-tests.luau` to launch the non-default `studio` Lest suite and apply the outer diagnostic guard. It removes only that exact place file afterward. Guard failures retain the complete process streams and attributed problems beneath `.verify/studio-diagnostics/`; Lest also retains `.lest/studio-run.luau` and `.lest/studio-output.log` when Studio startup or a test fails.

The guard accepts a local expected diagnostic only when its complete `Enum.MessageType`, complete text, and multiplicity match the test's declaration. It reconciles every structured warning or error with its raw Studio output, rejects unmatched raw output, and checks stderr while allowing only Lest's exact Studio-launch progress line. Its observable boundary begins with the first Lest protocol record and continues through Studio process exit, including output decoded after Lest's done marker. The pinned backend suppresses ordinary Studio boot output before that first protocol record, so this suite does not claim coverage of that earlier interval. Run Studio tests through the verifier; direct `lest run studio` bypasses the outer guard.

The suite checks scoped Fusion construction, reactive updates, and cleanup, plus the preset picker's real Fusion/Charm/Janitor composition, remount, failed acquisition, throwing cleanup, and repeated destruction. A deliberate invalid-property fixture must produce the exact expected `cannotAssignProperty` diagnostic and fail the clean-result assertion; this proves the suite detects Fusion errors that can still return a partially constructed Instance. Injected body and cleanup failures must preserve both original messages, and an assertion failure must still destroy the test holder.

Because Studio Lest runs in edit mode, it cannot verify client startup or real pointer interaction. UI/input changes still require the following playtest.

## Behavior verification

For each behavior change, define observable expected outcomes from the request and governing contracts before implementing it. Select only relevant scenarios: normal completion, invalid or unauthorized input, interruption or cancellation, dependency failure, and cleanup. State the supported input devices when input handling is involved. Resolve discrepancies between tests and implementation against that contract, and explain expectation changes in the final diff or report.

Use native tests for runtime-neutral logic, Studio construction tests for engine objects, and a Studio playtest for behavior that depends on input, lifecycle startup, replication, or other engine execution. Choose assertions that would detect the relevant failure; constructing a control does not prove it handles input, and creating a transport does not prove a request reached the server or its response reached the client. Keep reusable tooling checks independent of disposable experiments.

Report which scenarios passed, failed, or remain unverified. A canonical-gate pass establishes only the stages it executes; a required Studio or interaction check that fails or cannot run remains an explicit completion limitation. Preserve original assertion messages, observed values, and cleanup failures so the next investigation can identify the failed contract.

## Studio behavior playtest

1. Select the Studio instance opened for this checkout, confirm it contains the changed source, and note the current console position.
2. Reuse an existing client play session when suitable. If it cannot support the check, preserve it and report the limitation. When no session is running, start one and record that this verification owns it.
3. Wait for the feature's expected startup state with a bounded timeout. For a removal, confirm the remaining lifecycle roots start and the removed behavior is absent.
4. Exercise the selected scenarios using real input and the required client/server realms. Assert observable outcomes, including non-activation when an action is rejected or cancelled. Use bounded waits for asynchronous state; UI checks should account for supported reduced-motion behavior.
5. Inspect only console messages emitted since step 1 and fail the playtest on new project or unexpected Fusion errors.
6. Stop the play session if this verification started it, including after a failed check.

Keep reusable assertion probes in the filesystem. Execute them transiently through Studio MCP; never save test probes into the Studio DataModel.

Use current-session failures to scope input limitations. A historical console error is not evidence that the current pointer tool is blocked. Drive controls with real input and observe rendered state through read-only probes. If an input tool rejects a key because it is bound to a CoreGUI action, stop that blocked input path, retain successful evidence for other inputs, and report that key as unverified. Do not substitute direct callback invocation for input or change runtime capabilities to satisfy a probe.

Studio MCP pointer injection may land in CoreGUI instead of the experience viewport, and assistant-executed Luau may lack the `RobloxScript` capability required by `VirtualInputManager`. After either failure appears, stop retrying automated input. Collect the available hierarchy, rendered-state, and console evidence, then report each interaction or network round trip that remains unverified. Fallback observations retain their narrower scope of evidence.
