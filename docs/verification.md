# Verification

## Canonical and focused runs

The required local and CI gate remains:

```sh
lute run scripts/verify.luau
```

With no arguments, the verifier checks prepared dependencies, checks Blink generation while restoring its randomized output, creates the Rojo sourcemap, checks formatting, lints and analyzes Luau, runs unit tests, and builds a disposable place. This is the only invocation that can print `[verify] PASS`. Verification never installs packages or rewrites package typings, so it can run while Rojo serves the project.

On initial setup or when verification reports missing or stale preparation, stop Rojo and run:

```sh
lute run scripts/prepare-dependencies.luau
```

Preparation runs Wally, generates a Rojo sourcemap, then generates package typings. It fails on lockfile drift and restores the original lockfile; reconcile intentional dependency changes before retrying. The preparation stamp is invalidated at the start and recorded only after all steps succeed. Start Rojo after preparation succeeds. Wally 0.3.2 replaces the live `Packages/` tree, which can crash Rojo 7.7.0's watcher; the preparation command requires Rojo to be stopped but does not stop it automatically. The pinned typing generator requires fresh Wally shims, so preparation always installs before generating types. CI prepares dependencies before running the gate.

A single local SHA-256 stamp in `.verify/dependencies.sha256` covers `rokit.toml`, `wally.toml`, `wally.lock`, `default.project.json`, and every prepared package file. Changed inputs or missing, added, or modified package files require preparation again. Ordinary source edits and sourcemap regeneration do not. Deleting `.verify/` also removes the stamp. The verifier checks this stamp under the `wally` prerequisite and fails with the exact preparation command when it is stale; it never repairs dependencies implicitly.

The unit stage also runs `lute run tests/unit/Dependencies.regression.luau` to check preparation freshness with disposable filesystem fixtures.

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

## Reports and failures

Every valid run writes a unique schema-version-1 JSON report beneath `.verify/reports/` and prints its path. Reports contain the selected stages, whether the full gate ran, the overall outcome, ordered stage records with status, duration, exit code, and reason, and an additive `errors` collection for report, orchestration, or cleanup failures.

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

The verifier builds `.verify/diegeticUi.rbxlx`, launches the non-default `studio` Lest suite, and removes only that exact place file afterward. Lest retains `.lest/studio-run.luau` and `.lest/studio-output.log` when Studio startup or a test fails.

The suite mounts the real Fusion Button and verifies its label, property configuration, children, cleanup, and absence of unexpected Fusion diagnostics. A deliberate invalid-property fixture must produce `cannotAssignProperty`; this proves the suite detects Fusion errors that can still return a partially constructed Instance.

Because Studio Lest runs in edit mode, it cannot verify client startup or real pointer interaction. UI/input changes still require the following playtest.

## Studio Button interaction playtest

Use `tests/studio/ButtonPlaytest.luau` as the filesystem-owned client assertion probe. Inject or execute it transiently through Studio MCP during the play session; never save it into the Studio DataModel. The probe observes settled presentation state but does not synthesize Roblox input, so the pointer steps remain real interaction checks.

1. Select the Studio instance opened for this checkout and note the current console position.
2. Start a client play session and wait for `PlayerGui.ButtonDemo.Button`.
3. Execute `ButtonPlaytest.waitForState("default")` with the pointer away from the button.
4. Move the real pointer over the button, then execute `waitForState("hover")`.
5. Hold the primary pointer button down and execute `waitForState("pressed")` before releasing it.
6. Release while still hovering and execute `waitForState("hover")`; move away and execute `waitForState("default")`.
7. Inspect only console messages emitted since step 1 and fail the playtest on new project or Fusion errors.
8. Stop the play session if this verification started it.

The probe compares settled colors and scale with tolerances. Its timeout covers both startup hierarchy discovery and state settling, and missing instances are reported by path. When Roblox reduced motion is enabled, every state expects scale `1` while still requiring distinct state colors.

Studio MCP pointer injection may land in CoreGUI instead of the experience viewport, and assistant-executed Luau may lack the `RobloxScript` capability required by `VirtualInputManager`. After either failure appears, stop retrying automated input. Collect the fallback evidence that remains available: inspect the rendered UI, confirm the expected client UI and server lifecycle roots loaded, count the Blink transport instances, and inspect new console output. Then stop Play and report each interaction or network round trip that remains unverified.

One reliable and one unreliable Blink transport instance prove that the generated network module initialized. Their presence does not prove that an action request reached the server or that its response reached the client.
