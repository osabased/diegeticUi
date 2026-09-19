# Setup production qualification — 2026-09-19

## Verdict and scope

The production-readiness work for the two parent setup skills, `structure-roblox-projects` and `roblox-resource-acquisition`, is implemented and locally qualified. The project now carries executable release-composition, lifecycle, Studio-diagnostic, and normal-startup evidence rather than relying on setup prose alone.

The default and development profiles both mount the preset picker preview. The release profile excludes the bootstrap, demo subtree, authored stories/storybooks, and dedicated story helper while retaining the production Loadout runtime and normal service roots.

Focused evidence:

- [Production implementation and input evidence](setup-production-evaluation-2026-09-19.md)
- [Studio diagnostic guard evidence](studio-diagnostic-guard-2026-09-19.md)
- [Parent setup-skill repair](setup-skills-root-repair-2026-09-19.md)
- [Independent setup-skill forward evaluation](setup-skills-forward-evaluation-2026-09-19.md)
- [Sibling contract repair](sibling-skills-repair-2026-09-19.md)
- [Independent sibling acceptance](sibling-skills-independent-acceptance-2026-09-19.md)

## Final verification

- Final canonical verifier after the assertion repairs: PASS at `.verify/reports/20260919T061915500Z-000.json`.
- The gate covers 14 native tests, 4 Python artifact-checker tests, and the dependency, documentation, verifier-diagnostic, and Studio-guard regressions.
- Retained profile evidence is under `.verify/preset-picker-profiles/`: development has 208 sourcemap / 218 place instances; release has 193 / 203.
- The repository-owned Python checker is now part of the canonical build stage. CI declares Python 3.12; local guidance requires Python 3.10+ as `python`.
- The parent Rojo reference now teaches the portable checker path rather than a host-specific PowerShell dependency.
- Existing executable parent-package proof remains applicable to unchanged code: resource acquisition 163 tests plus 2 subtests; project structure 8 tests. The later Rojo reference clarification passed skill metadata validation.
- Four sibling skills' 13 contract errors were repaired. Independent advice-only instruction-response acceptance passed, and the current nine-skill catalog reports zero errors.
- Forced real Studio warning and error cases reproduced Lest false greens and were rejected by the outer guard; the final guarded Studio suite passed 13 tests.
- The final bootstrap and demo sources matched the filesystem after LF normalization before normal client startup. Real desktop pointer/text input exercised filtering and selection, and the current-session Studio console remained clean.

Useful checkpoints: `.verify/preset-picker-profiles/`, `.verify/studio-diagnostics/`, the canonical report above, and the parent-skill recovery archive `C:/Users/Lowle/.codex/tmp/skill-root-fixes-87c36bf5`.

## Defect classification

Project-level defects corrected:

- Studio warnings/errors could remain green because direct Lest output was not guarded through owned teardown/process exit.
- No release artifact established preview/story exclusion while preserving runtime code.
- Older generated child skills had drifted from the current parent contract.
- The first artifact gate depended on machine-local PowerShell/global-skill state instead of a portable repository-owned checker.

Worker mistakes found and corrected during review:

- Luau `pcall` result destructuring violated the strict overload for no-return callbacks.
- A Janitor cleanup callback could throw and abort later cleanup.
- Bootstrap startup used an unbounded wait.
- The first release exclusion omitted part of the authored story/helper surface.

Final review also caught two false-green profile assertions: a required preview fragment matched the bootstrap name, and entrypoints could survive while required server/shared modules were absent. Both now use exact paths, with deterministic missing-subtree/runtime regressions. The parent Rojo reference now requires checking affected dependency paths and testing project assertions against these mutations.

## Boundaries and status

Rendered motion, UI Labs operation, touch/gamepad input, and Studio boot output before the first Lest protocol record remain unverified. The historical callback-destruction message was not causally reproduced or attributed. The existing production Loadout feature was not audited wholesale.

CI is configured but was not executed on the remote/Linux runner in this session. Earlier root-repair and forward-evaluation reports remain historical evidence; their completed-work gaps are superseded by this qualification.

Independent review findings are repaired, and current skill/record/bundle/learnings/catalog validation passes. Fusion's overall resource status remains unverified for its untested capabilities, and its latest wording has not had a fresh explicit-activation evaluation. No task-owned branches or worktrees were created; the pre-task recovery checkpoint at `C:/Users/Lowle/.codex/tmp/production-skill-eval-20260919T014638` is retained.
