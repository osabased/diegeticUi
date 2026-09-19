# Fusion usage evaluation: root-fix recommendations — 2026-09-19

## Scope and conclusion

This is diagnosis and planning; no fixes were applied. Tests established construction, reactive state, and ordinary cleanup, but not real input, rendered layout, or animation quality. The highest-priority finding is an existing production lifecycle flaw. Release composition and observable preview validation are workflow defects; no Fusion component defect is validated. Supporting detail is in the [guidance diagnosis](fusion-guidance-diagnosis-2026-09-19.md) and [teardown diagnosis](fusion-teardown-diagnosis-2026-09-19.md).

## 1. Close the production mount and teardown gap

**Evidence and cause.** Production `src/client/Loadout/init.luau:29-56` creates the Fusion scope, root, and view before registering cleanup, so construction failure can strand partial UI. Producers and `Fusion.doCleanup(scope)` then become separate Janitor entries. Pinned Janitor 1.18.3 iterates a table with `next` and aborts on a throwing cleaner; it guarantees neither order nor continuation. Fusion requires producer-first cleanup and also aborts its scope loop on a throw. The demo protects teardown, but not its earlier scope, state, and subscription acquisition.

**Root fix.** Add one narrow helper beneath the Loadout lifecycle root for runtime and demo mounting. Create Janitor first, immediately register one non-throwing composite cleanup task, and protect all acquisition. The composite detaches handles before calling them, attempts every producer disposer before `Fusion.doCleanup`, and records labelled tracebacks. Explicit destroy surfaces failures after Janitor finishes; construction failure keeps the body error primary and appends cleanup failures. Repeated or reentrant destroy runs each resource once. Project-owned scope callbacks must record rather than throw.

**Acceptance criteria.** Studio owner tests cover partial construction, a throwing producer, combined body/cleanup failure, repeated destroy, and external-root destruction. Later cleanup still runs, the root returns to baseline, errors are ordered and labelled, each resource runs once, and canonical checks pass.

**Alternatives and tradeoffs.** Separate Janitor entries cannot encode this contract. A project-wide mount framework is premature; extract beyond Loadout only after another feature proves the same seam.

## 2. Make the release artifact exclude development UI

**Evidence and cause.** `default.project.json` maps all `src/client` into `ReplicatedStorage.Client`; `sourcemap.json` includes `PresetPickerDemo`, `*.story.luau`, and `*.storybook.luau`. The nested demo has no independent lifecycle entrypoint, so it does not autostart, but it remains in the build. `scripts/verify.luau` hardcodes that project for sourcemap and place build. Thus the default artifact contains development modules; no production publication was observed. Rojo supports `$path` trees and `globIgnorePaths` ([Rojo project format](https://rojo.space/docs/v7/project-format/)).

**Root fix.** Use the proved Rojo composition: one shared runtime project owns the complete map, and thin development/release profiles delegate their whole tree to it with `$path`. The development profile retains explicit preview paths; release uses `globIgnorePaths`, including both a development-only directory node and its descendants (for example `**/Preview` and `**/Preview/**`) plus story/storybook patterns. The verifier builds release and deterministically rejects forbidden paths. Do not add another `ReplicatedStorage` tree in a wrapper: the probe produced duplicate services.

**Acceptance criteria.** Parsed release sourcemap and `.rbxlx` contain one `ReplicatedStorage` and omit every preview module; development contains the shared runtime plus previews; the verifier fails on deliberate reintroduction. A development-only preview may be a normal Module Loader client root, while release retains only production roots. This composition proof is not interactive proof.

**Alternatives and tradeoffs.** Ignore globs are simple but may hinder development serving. Separate files can drift if they copy runtime maps. Moving previews helps only when an artifact assertion proves exclusion.

## 3. Add an observable, capability-supported preview path

**Evidence and cause.** In MCP Studio `e077a0e6-797f-4950-96f9-ec9cf6480fd1`, requiring `Mount` failed because it had `LoadUnownedAsset` and three additional capabilities. Roblox restricts requires and script movement across incompatible capability containers ([Roblox script capabilities](https://create.roblox.com/docs/scripting/capabilities)). Lest's Studio was invisible to MCP, a sleeping probe timed out, and domain calls did not prove callbacks.

**Root fix.** Prototype a development-only, filesystem/Rojo normal-client bootstrap in the MCP-visible Studio. Mount the shared view in `LocalPlayer.PlayerGui` and expose a fingerprint covering committed and uncommitted source, project configuration, and an expected UI marker. Then type into the TextBox, click rows, inspect output, capture key states, and observe tween interruption. This architecture is unproved until that succeeds. UI Labs remains complementary; its Fusion 0.3 contract owns `props.scope` and cleans it on unmount ([UI Labs Fusion stories](https://ui-labs.luau.page/docs/stories/advanced/fusion)).

**Acceptance criteria.** A repeatable same-Studio play proves fingerprint, callbacks, rendered states, animation, screenshots, and a clean console, then stops only its session. Release excludes the bootstrap. Capability widening, MCP injection, sleeping tests, and domain calls do not satisfy the gate.

**Alternatives and tradeoffs.** UI Labs is faster for variants; the normal client path covers PlayerGui, startup, focus, and input. A future Lest-to-MCP bridge may help, but none was demonstrated.

## 4. Improve strict-typing and ownership guidance

**Evidence and cause.** Four analyzer probes showed the `ForPairs`/numeric `Tween` cascade is a strict-Luau inference edge: only `rowScope: Fusion.Scope<typeof(Fusion)>` was essential; downstream numeric annotations alone failed. Public types are accurate. The earlier `New` then `Hydrate` duplication was corrected to one `New` with `scope.Children`; no runtime failure occurred.

**Root fix and acceptance criteria.** Add a canonically analyzed, executable `ForPairs` plus numeric `Tween` exemplar with the critical `rowScope: Scope` annotation and one-enrollment ownership rule: use `New` for creation or `Hydrate` for ownership transfer once per scope. Clarify that producer-before-scope teardown requires one protected Janitor composite. The positive exemplar must pass strict analysis; retain the four probes as evidence, not a permanent test that requires inference to remain limited.

**Alternatives and tradeoffs.** Do not add wrappers, assertions, vendor/type edits, or scope-internal tests; they add machinery without addressing the observed inference boundary or a user-visible duplicate-cleanup defect.

## 5. Make Studio diagnostics red-capable before attribution

**Evidence and cause.** The callback warning did not recur in an exact nine-test rerun or bounded render-step probes, so its producer remains unproved. A real guard gap was confirmed: Lest 0.6.0 treats test events and its done marker as authoritative while ordinary Studio output remains non-fatal. Local diagnostic helpers allow generic warnings and disconnect before final RunScript/Studio teardown. A passing suite therefore cannot prove a warning-free lifecycle.

**Root fix.** Extend or upgrade the Studio runner so structured warnings/errors are captured from before spec loading through owned finalization and process exit. Unexpected diagnostics must create a synthetic failure and retain output with the active/last spec. Add runner finalizers, then harden demo tests with failure-safe mount/holder cleanup and a post-destroy domain mutation proving producers cannot reach the view. Do not attribute or patch Fusion's package-global scheduler until the red-capable guard identifies it.

**Acceptance criteria.** An injected unallowlisted warning fails and retains its artifact; a post-assertion error also fails; intentional diagnostics require exact test-local expectations. The unfiltered and focused suites remain clean through process exit, and post-destroy producer activity cannot update the view.

**Alternatives and tradeoffs.** Arbitrary waits, broad warning allowlists, private Fusion imports, vendor patches, or component ownership of the shared scheduler would hide or misplace the problem. If attribution later identifies Fusion, prefer an upstream-supported host shutdown seam or a persistent test host.

## Recommended order

Implement and test the Loadout mount owner first, then lock the release boundary, make Studio diagnostics red-capable, prove the normal-client preview path, and finally land the small guidance exemplar. Until those checks pass, production cleanup safety, release exclusion, clean Studio teardown, and interactive behavior remain unproved.
