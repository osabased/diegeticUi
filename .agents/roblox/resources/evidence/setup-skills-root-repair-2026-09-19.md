# Setup skill root repairs — 2026-09-19

Implemented reusable setup safeguards in the existing parent skills, with library-specific details retained in the Fusion child. Existing production source, release mappings, dependency pins, loader, and Lest runner were not changed by this repair.

## Changes

- `roblox-resource-acquisition`: inspect actual pinned lifecycle behavior; register cleanup before fallible acquisition; use protected ordered cleanup when composition requires it; distinguish component ownership from shared runtime lifetime. Maintain executable examples and separate construction, lifecycle, real UI, and diagnostic evidence. Require deliberate warning/error failures before claiming a clean console, respecting task-owned host boundaries.
- `structure-roblox-projects`: establish explicit release inclusion/exclusion, verify the actual generated sourcemap and place, and preserve one mapping authority. Establish normal client startup in the same Studio used for interaction and capture, with source/configuration fingerprints. Added an artifact checker and behavioral regressions; profile design remains conditional.
- `roblox-fusion`: minimal strict `ForPairs` scope annotation, pinned Janitor composition guidance, single scope enrollment, expanded executable fixture, and bounded diagnostic claims. Historical evidence remains distinguishable from current proof.

## Validation

- Acquisition package: 163 tests plus 2 subtests passed; metadata validated. The later host-ownership prose clarification also passed 13 document-contract tests.
- Structure package: 8 behavioral tests passed, including a real Rojo 7.7 build/sourcemap fixture; metadata validated. Required paths use exact matching, with regression coverage against a similarly named wrong path.
- Independent Sol High forward evaluation identified the seeded setup defects, accepted a valid artifact pair and rejected the defective pair, and avoided unnecessary setup for a label change or inert helper. See [independent report](setup-skills-forward-evaluation-2026-09-19.md). This is reduced-fixture acceptance evidence, not an end-to-end new project implementation.
- Project canonical verifier passed, including 14 native tests: `.verify/reports/20260919T053038833Z-000.json`.
- The expanded Fusion fixture initially failed on a stale child-count expectation. After correcting the exact pre-failure baseline, narrow strict/style/lint checks passed and the focused Studio rerun passed: 1 suite, 1 test, 2.37 seconds test time, 14.15 seconds overall. See [Fusion repair evidence](fusion-guidance-repair-2026-09-19.md).

## Boundaries and remaining work

These skills now teach and require the missing contracts; prose cannot guarantee compliance on its own. Future authorized integrations must install the applicable executable assertions in their project gates. This project's production owner, release composition, real-input preview path, and outer Studio diagnostic runner still need their separately identified repairs. Full Janitor-composite runtime proof, rendered animation/input proof, and process-exit diagnostic proof remain unclaimed. The wider catalog still has 13 pre-existing contract errors in four sibling skills; Fusion has none.

Pre-edit recovery archive and manifest: `C:/Users/Lowle/.codex/tmp/skill-root-fixes-87c36bf5`. No task-owned branches or worktrees were created. The task-generated place was removed after testing.
