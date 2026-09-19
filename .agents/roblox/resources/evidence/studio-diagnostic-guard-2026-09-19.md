# Studio diagnostic guard evidence — 2026-09-19

## Defect and correction

Pinned Lest 0.6.0 can report a Studio spec and run as passing while ordinary `MessageWarning` or `MessageError` output is present. The Studio suite now runs through `scripts/run-studio-tests.luau`, which requests Lest's JSON reporter, preserves both process streams, and applies `scripts/studio-diagnostic-guard.luau` before accepting the exit code.

`tests/studio/DiagnosticCapture.luau` emits exact, line-framed records for warning/error messages observed during a test-owned body, cleanup, and scheduler flush. A diagnostic is expected only when its complete `Enum.MessageType` and complete message match a test-local expectation, including multiplicity. The outer guard reconciles every structured record with the exact raw stdout lines. Unmatched raw output, malformed or embedded marker text, missing structured/raw counterparts, unexpected stderr, and output after the last test event fail with the relevant spec context. The sole stderr allowance is Lest's exact `Launching Roblox Studio (budget <seconds>s)…` progress line.

The expected Fusion invalid-property error has a deterministic Studio rendering difference: the final line gains `  -  Edit`, followed by adjacent empty `Stack Begin` / `Stack End` lines. The guard accepts only that exact decoration when reconciling a structured `MessageError`; it does not discard an arbitrary capture interval or stack region.

## Pinned backend boundary

The [pinned Lest backend source](https://github.com/lest-luau/lest/blob/240698e30c0496b21b7a3d7811a0567fde7efdbf/src/backend/studio.rs) waits for Studio to exit, reads the complete `studio-output.log`, and then decodes every line. Seeing `@@LEST_STUDIO_DONE@@` changes completion state but does not stop the decode loop; ordinary lines after it are forwarded once the test protocol has started. The wrapper therefore sees and rejects output produced during owned teardown after the done marker. Lest sends its launch note and backend warnings to stderr, which the wrapper now checks separately.

The backend suppresses ordinary Studio output before it sees the first Lest protocol record. This correction therefore proves the test interval from protocol/spec load through Studio process exit; it cannot recover Studio boot output that the pinned backend itself discards.

## Red/green evidence

Temporary proof specs were added, run, and removed from their exact files. They deliberately omitted expected diagnostics so Lest itself returned exit code `0` and emitted `test_pass`; the guard returned nonzero in both cases:

- Real `warn()` / `MessageWarning`: `.verify/studio-diagnostics/1789797734-000.log`
- Real Fusion invalid-property / `MessageError`: `.verify/studio-diagnostics/1789797750-000.log`

Both retained logs contain raw stdout, stderr, the exact structured diagnostic, and the passing Lest event. The wrapper report named the originating suite/test and preserved the full diagnostic text.

After removing the temporary proof specs:

- `lute run tests/unit/StudioDiagnosticGuard.regression.luau` passed. It covers warning/error false-green streams, exact expectations and multiplicity, Studio error decoration, missing expectations, unmatched raw output inside a capture, embedded marker text, unexpected stderr, output after run end, and post-test callback warnings.
- `lute run scripts/run-studio-tests.luau --filter "accepts one exact local warning emitted during owned cleanup"` passed.
- `lute run scripts/run-studio-tests.luau --filter "detects a non-fatal invalid Fusion property"` passed.
- `lute run scripts/run-studio-tests.luau` passed all 13 Studio tests with no unmatched output.
- Focused formatting, Selene, `lute check`, and Luau-LSP analysis passed for the owned files.

The existing user `Place1` Edit session was not changed or closed. Each disposable Lest Studio process exited normally.
