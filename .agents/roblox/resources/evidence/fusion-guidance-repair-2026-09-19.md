# Fusion generated-child guidance repair — 2026-09-19

## Outcome

This authorized repair corrected three bounded defects in the project-local `roblox-fusion` child without changing Fusion, Janitor, project source, tests, or dependency pins.

1. The maintained strict fixture now demonstrates `ForPairs` with a numeric `Tween` using only the essential processor annotation, `rowScope: Fusion.Scope<typeof(Fusion)>`. Narrow `luau-lsp analyze` accepts the fixture with no extra callback, key/value, return, `Computed`, or `Tween` annotations.
2. The Fusion-to-Janitor guidance now reflects pinned Janitor 1.18.3: cleanup entry order is unspecified and a throwing cleaner aborts remaining cleanup. An order-sensitive mount registers one protected feature-local composite before fallible acquisition, detaches handles before invocation, attempts producer cleanup before the Fusion scope, accumulates labelled failures without throwing through Janitor, and preserves a construction error ahead of appended cleanup failures.
3. The fixture now records every warning or error emitted during its listener window. The skill explicitly limits that result to the in-fixture window; the fixture cannot observe output after listener disconnection or prove warning-free Studio process exit.

The one-enrollment invariant is explicit: an Instance enters a given scope through one `New` or `Hydrate` call, with known reactive properties and special keys supplied there. No wrapper, generic project-wide Fusion framework, vendor patch, or private Fusion scheduler hook was added.

## Basis

- `.agents/roblox/resources/evidence/fusion-guidance-diagnosis-2026-09-19.md` established that annotating only the `ForPairs` calculation scope fixes the strict inference failure and that separate Janitor entries cannot provide the required teardown order or failure isolation.
- `.agents/roblox/resources/evidence/fusion-teardown-diagnosis-2026-09-19.md` established that the prior diagnostic claim excluded generic warnings and could not cover final RunScript/Studio teardown. It did not attribute the observed callback warning to Fusion.
- Installed Fusion 0.3.0 types define the `ForPairs` processor scope and numeric `Tween` inference used by the fixture.
- Installed Janitor 1.18.3 cleanup uses unordered table iteration and direct cleaner invocation, so an error can stop later cleanup.

## Checks run

- `luau-lsp analyze --platform roblox --definitions @roblox=tooling/roblox/globalTypes.d.luau --sourcemap sourcemap.json .agents/skills/roblox-fusion/fixtures/FusionIntegrationFixture.luau` — exit 0, no analyzer diagnostics.
- `stylua --check .agents/skills/roblox-fusion/fixtures/FusionIntegrationFixture.luau` — exit 0.
- `selene .agents/skills/roblox-fusion/fixtures/FusionIntegrationFixture.luau` — exit 0, no errors, warnings, or parse errors.
- `python .../validate_skill.py .agents/skills/roblox-fusion` — PASS, with only the accepted no-DevForum warning.
- `python .../quick_validate.py .agents/skills/roblox-fusion` — PASS.
- `python .../validate_resource_record.py .agents/roblox/resources/records/elttob-fusion.yaml --current-skill .agents/skills/roblox-fusion` — PASS.
- `python .../validate_resource_bundle.py .agents/roblox/resources/records/elttob-fusion.yaml .agents/skills/roblox-fusion` — PASS.
- `python .../validate_learnings_store.py .agents/roblox/resources/learnings` — PASS, including the failure-baseline repair outcome added after the focused red result.
- `python .../validate_skill_catalog.py` over the five generated Roblox children and three recorded routing competitors retained fingerprint `sha256:faa3fbe107414566bf3eb0960d48373786b21f57ef4e151c3e9edbda89fcf16c`. Fusion has no catalog error or overlap; the overall catalog remains non-green because the same 13 contract errors persist in four sibling skills.

## Focused Studio red result and fixture correction

After the static repair, the root ran the canonical verifier successfully (`.verify/reports/20260919T053038833Z-000.json`) and then ran the real focused Studio fixture. Studio reported `error=none; failed=failureCleanup; diagnostics=`. The newly added `FusionFixtureRows` root is a second normal top-level child, while the old failure assertion still expected `baselineChildren + 1` from the earlier one-root fixture.

The corrected check snapshots `#parent:GetChildren()` immediately before creating the injected-failure scope and requires cleanup to restore that exact pre-failure count, while separately requiring `failureRoot.Parent == nil`. The final cleanup assertion still requires the original entry baseline. This preserves both meaningful invariants without weakening the count check. The failed run is evidence for the stale assertion only.

After this correction, the fixture again passed narrow formatting, lint, and strict analysis, and the Fusion skill, record, bundle, and learnings validators all passed. These static results do not replace the focused Studio rerun.

The root then reran `lest run fusion-integration --config lest.toml --forbid-only` against the unchanged prepared `.verify/diegeticUi.rbxlx`; Lest bundles the maintained fixture source for the suite. The rerun passed with exit 0: one suite, one test, 2.37 seconds in the fixture and 14.15 seconds total. This is current proof only for the fixture's named assertions and warnings/errors captured during its connected diagnostic window.

No Lest, Roblox Studio, or canonical verifier run was performed by this child repair itself. The root-owned canonical verifier passed before the assertion-only correction, and the root-owned focused rerun passed after that correction. The reproducible sequence is:

```text
rojo build default.project.json --output .verify/diegeticUi.rbxlx
lest run fusion-integration --config lest.toml --forbid-only
```

That run establishes only the fixture assertions and in-window diagnostics. It cannot establish clean process-exit diagnostics until the Studio runner itself is repaired and its forced-warning regression passes. Interactive input and rendered motion remain subject to the project Studio playtest sequence.

The focused fixture does not prove the new Fusion-to-Janitor composite contract. A current lifecycle claim also needs owner-level Studio cases for partial acquisition, a throwing producer while later phases still run, simultaneous body and cleanup failure ordering, repeated destroy, and post-disposal producer isolation, using the real pinned Janitor/Fusion success path and narrow injected failures.

## Evidence state

The earlier `fusion-studio-integration` and `fusion-failure-cleanup` checks remain truthful history because they cover the earlier fixture. New command-mode checks record the repaired fixture separately. The current narrow integration and direct Fusion scope cleanup assertions passed, while the independent behavioral aggregate remains unclaimed because this deterministic Lest command was not a fresh independent skill-use evaluation. The Codex host remains `installed` with explicit activation `not-run` because this runtime execution was not an activation test. Catalog routing evidence remains current because the skill name, description, and routing boundaries did not change. Upstream resource verification remains `unverified`; the Fusion-to-Janitor composite, actual interactive animation/input, rendered motion, and process-exit diagnostics are still missing.
