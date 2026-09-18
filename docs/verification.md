# Verification

## Canonical and focused runs

The required local and CI gate remains:

```sh
lute run scripts/verify.luau
```

With no arguments, the verifier installs the locked Wally graph, checks Blink generation while restoring its randomized output, creates the Rojo sourcemap and package typings, checks formatting, lints and analyzes Luau, runs native unit tests, and builds a disposable place. This is the only invocation that can print `[verify] PASS`.

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
| `unit`, `build` | Locked Wally installation |
| `analyze` | Locked Wally installation, Rojo sourcemap, package typings, Lest framework bootstrap |
| `studio` | Locked Wally installation, disposable place build |

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

## MCP Button interaction playtest

Use `tests/studio/ButtonPlaytest.luau` as the filesystem-owned client assertion probe. Inject or execute it transiently through Studio MCP during the play session; never save it into the Studio DataModel.

1. Select the Studio instance opened for this checkout and note the current console position.
2. Start a client play session and wait for `PlayerGui.ButtonDemo.Button`.
3. Execute `ButtonPlaytest.waitForState("default")` with the pointer away from the button.
4. Move the real pointer over the button, then execute `waitForState("hover")`.
5. Hold the primary pointer button down and execute `waitForState("pressed")` before releasing it.
6. Release while still hovering and execute `waitForState("hover")`; move away and execute `waitForState("default")`.
7. Inspect only console messages emitted since step 1 and fail the playtest on new project or Fusion errors.
8. Stop the play session if this verification started it.

The probe compares settled colors and scale with tolerances. Its timeout covers both startup hierarchy discovery and state settling, and missing instances are reported by path. When Roblox reduced motion is enabled, every state expects scale `1` while still requiring distinct state colors.
