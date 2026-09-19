# Agentic UI benchmark

## Benchmark boundary

- Baseline: `3c0fa6f91ce44ac7c33669172b95eb666c9d9f87`, initially clean working tree.
- Worker: one fresh `gpt-5.6-sol` agent, medium reasoning, no inherited conversation, no further delegation or parent coaching.
- Task: a session-only loadout selector with four choices, a locked choice, details, explicit server-authoritative equip, pending/success/rejection states, desktop controls, narrow layout, cancellation/reopening, and cleanup.
- Required integration: existing Charm, Fusion 0.3, Janitor, Blink, SSA/Rojo conventions, UI Labs stories, native tests, canonical verifier, and available Studio checks. Persistence and actual equipment gameplay are outside scope.
- Assessment: practical support for an agent to implement and verify a normal UI feature in this development environment. One run cannot establish comparative model productivity or production readiness.
- Authority: project instructions and `docs/verification.md`; the benchmark request prohibits implementation of project-level remedies.

## Evaluation scenarios

1. Client startup renders a usable opener; desktop input opens the panel and selects details.
2. Explicit equip passes through Blink to server validation and returns authoritative state; duplicate confirmation is suppressed.
3. Locked/invalid choices cannot change server state and rejection feedback remains understandable.
4. Close before confirmation has no equip effect; close while pending preserves the later acknowledged state without reopening stale UI.
5. Reopen, teardown, and repeated mounting leave resources and subscriptions correctly owned.
6. Normal, locked, pending, and error stories can construct the same UI independently of a live server.
7. Narrow viewport keeps essential controls visible and reachable.

Static inspection, native tests, engine construction, actual input, screenshots, and plugin execution have different evidentiary reach. Missing runtime evidence is not a passing interaction check. Worker mistakes are not automatically project defects; recommendations require a reproducible project cause or a demonstrated workflow gap.

## Result

The foundation supported an independent implementation through a real client/server equip round trip. It is stronger at source correctness and integration than at repeatable visual acceptance. The benchmark implementation is functional but not acceptance-ready: the parent found a remaining landscape layout defect. This single run does not support replacing the libraries or attributing every omission to the project.

The worker added five choices, an explicit locked state, selection/details, request IDs, authoritative server validation, pending/success/rejection feedback, close/reopen state handling, Janitor ownership, and four UI Labs stories. Charm owns application state; Fusion renders it; Blink carries the request/result; SSA discovers the client/server roots. Persistence, LemonSignal, and animation were not artificially added where this task did not need them.

| Evidence | Outcome and reach |
| --- | --- |
| Canonical gate | Passed formatting, lint, strict analysis, Blink integrity, 14 native tests, tooling regressions, and disposable build. Report: `.verify/reports/20260918T210419854Z-000.json`. |
| Studio construction | Five tests passed, including the new feature construction/pending/cleanup case. Report: `.verify/reports/20260918T210502617Z-000.json`. Construction is not a layout or input test. |
| Worker playtest | Real L input, pointer selection and equip, authoritative success feedback, and close/reopen preservation reported. The worker stopped further pointer testing after CoreGUI diagnostics. See [worker report](loadout-worker-report.md). |
| Parent playtest | L opened the actual UI. The Galaxy A06 landscape preset was configured as 800×360, but the observed camera viewport was 705×338. The rendered status box overlapped the stats. Capture: `LoadoutParentLandscape800x360`. |
| Parent geometry evidence | Stats label: Y=173, H=22; status box: Y=151, H=40, at the same X and width. The 18-pixel overlap covers the stats text. The screenshot visibly lacked those stats. Preset resolution alone is not evidence of the rendered viewport. |
| Stories | Four files and a storybook compile and match the documented Fusion story shape. Plugin discovery, rendering, controls, hot reload, and plugin unmount were not exercised. |
| Race/failure cases | Native tests cover close while pending, duplicate blocking, and locked/unknown/malformed validation. A real close during flight and malicious request through the live transport remain unverified. |
| Escape | Parent input tool rejected the permanently CoreGUI-bound key. The handler remains unverified; this is not proof that it fails for a human. |

The parent reused the passing canonical and Studio reports because production source did not change after the worker's final checks. Final review covered authored feature/test/story files, the protocol diff, and generated-output scope. Generated Blink output contains trailing whitespace and randomized identifiers; the canonical verifier intentionally checks its generation integrity rather than hand-formatting it.

## Supported findings and recommended decisions

### 1. No established native/Roblox import convention for pure modules

**Evidence:** `StateMachine` and `Validator` each branch on `script ~= nil` to choose Instance or filesystem require, and suppress a Selene warning. Native Lest does not supply Roblox's `script`. The project requires both pure native tests and runtime-neutral shared modules, but has no demonstrated shared import pattern. This is a reproducible integration seam, not evidence that Lest or Roblox is broken.

**Recommendation:** standardize relative string imports for pure modules whose filesystem and Rojo sibling topology agree, with one small native/engine regression fixture. Reserve Instance-based acquisition for actual DataModel boundaries and replication readiness. Document that native Lest dependencies load at module top level.

**Investigation:** a disposable fixture using `Probe.luau -> require("./Catalog")` passed (a) pinned Lest 0.6.0 native execution, (b) require from an actual ModuleScript in a Rojo-built place using the Studio backend, and (c) pinned luau-lsp 1.69.0 analysis with the project's Roblox definitions. This validates the recommendation for this environment without changing the benchmark's modules. [Roblox documents these relative paths](https://raw.githubusercontent.com/Roblox/creator-docs/main/content/en-us/reference/engine/globals/LuaGlobals.yaml); [Lest documents native pure-logic testing without engine emulation](https://github.com/lest-luau/lest/blob/main/README.md).

**Alternatives:** a custom ModuleScript-emulating loader would introduce maintenance and false fidelity for a problem the supported import syntax already solves. Dependency injection remains appropriate for services and effects, but injecting a static sibling catalog merely to make require work adds unnecessary interface complexity. Keeping dual imports works today, but repeats the compatibility branch and lint exception.

**Limit:** the experiment proves sibling resolution, not arbitrary aliases, init-module mappings, or replication waiting. String require does not wait for missing Instances. Different mappings should be tested before extending the convention.

### 2. Visual and story verification is still assembled afresh per feature

**Evidence:** the worker read installed UI Labs types and creator code to discover the story shape. It produced static stories but never ran the plugin. Its construction test uses a Folder, so it cannot establish actual viewport layout. The landscape overlap escaped its screenshot review. The baseline correctly documents the separate plugin and honestly says there is no UI example; absence of an example was deliberate, not a broken link or dependency installation failure.

**Recommendation:** add a small maintained Fusion 0.3/UI Labs reference fixture and a focused visual verification path outside production startup. Demonstrate mount, state change, rejection/pending scenarios, and cleanup; reuse the existing diagnostic capture. Make actual rendered dimensions and content/action overlap assertions part of selected UI checks at desktop, narrow portrait, and short landscape sizes. Provide one explicit plugin discovery/mount/unmount procedure, reporting unavailable plugin checks separately. Reuse the current Studio stage and behavior workflow rather than introducing another application framework.

**Why:** this lowers repeated discovery cost and directly targets the observed gap between successful construction and usable layout. UI Labs supplies `props.scope` and cleans it on unmount, so the fixture can follow the [supported Fusion 0.3 contract](https://ui-labs.luau.page/docs/stories/advanced/fusion). The [plugin is separate from the utility package](https://ui-labs.luau.page/docs/installation).

**Tradeoffs:** a prose-only recipe is cheaper but can drift and cannot catch geometry failures. A large starter application would add unrelated behavior and reverse the deliberate cleanup of the starter. A small tested fixture has maintenance cost, but keeps that cost bounded. Keep engine/visual checks opt-in and required by relevant UI changes; do not force a desktop Studio dependency into the platform-neutral gate. Geometry assertions complement screenshots; they cannot judge overall visual quality or replace real input.

**Attribution:** the overlapping layout and omission of diagnostic capture in the new test are worker defects/omissions. Existing guidance already distinguishes construction from behavior and supplies a diagnostic example. They justify a more reusable path; they do not prove the verifier violated its advertised contract.

### 3. Fusion and UI Labs resource records describe removed evidence

**Evidence:** `.agents/roblox/resources/records/elttob-fusion.yaml` and `pepeeltoro41-ui-labs.yaml` still name `src/client/UI`, the removed StatusCard, and obsolete story/control evidence. Commit `1272a15` removed that application code. The README and structure profile describe the current feature-owned layout. Package identity/version reconciliation is still valid, but the usage/proof narrative no longer describes the checkout.

**Recommendation:** reconcile only the stale scope and proof fields. Separate package identity, surviving infrastructure checks, historical evidence tied to a revision, and presently unverified plugin behavior. Add a narrow resource-record reference check for declared local evidence paths, or include those references in the existing documentation regression machinery.

**Why and alternatives:** retaining the records unchanged can send future acquisition/repair agents to nonexistent examples or overstate current proof. Deleting the records would lose valid provenance and pins. Regenerating all resource guidance is unnecessary; preserve supported decisions. A path check cannot validate prose or runtime proof, so explicit revision/status attribution is still necessary. The worker did not report relying on these records; this is a parent-discovered maintenance defect, not an asserted cause of its mistakes.

## Other friction, with attribution

- **External simulator guidance defect:** the supplied `rbx-device-simulator-lua` skill says orientation can be set before a device is active. Parent reproduced `orientation can only be set on mobile (phone or tablet) devices`; activating the phone first worked. Recommend correcting that upstream instruction and using device-first activation plus observed viewport checks in the project's future probe. Do not change runtime permissions. The project did not author this instruction.
- **Input tooling limitations:** pointer CoreGUI diagnostics were reported by the worker; Escape rejection was reproduced by the parent. Existing project guidance already instructs stopping blocked paths and preserving narrower evidence. No project runtime fix is supported by these failures. An upstream input-tool correction and eventual human/working-tool validation are preferable to claiming direct callback invocation proves input.
- **Blink review noise:** hundreds of generated lines for two events, with randomized names and generator whitespace. The pinned generation wrapper and verifier already manage integrity. This run does not justify replacing Blink, changing its pin, or hand-editing output.
- **Plugin console noise:** the worker saw a MaterialManager profiling error during otherwise successful construction tests. No causal connection to the loadout was established; do not weaken project error checks or remove plugins based on this observation alone.
- **Parent investigation limits/mistakes:** transient MCP require probes were blocked by capability/context restrictions; no capabilities were changed. The supported disposable Rojo/Lest fixture supplied the eventual import evidence. The parent's first native probe put require inside the test callback; Lest rejected it with a precise top-level-import diagnostic. Moving that fixture import to the top fixed the test. This is an investigator mistake, not an additional project defect.

## Acceptance work and unresolved scope

The benchmark feature needs a layout correction: reserve separate vertical space for descriptive content, stats, feedback, and the action, using content-driven layout and scrolling at constrained heights. Verify both sides of its 560-pixel breakpoint and short landscape dimensions. This is a feature-level correction, separate from the proposed reusable verification path. No fixes were applied, so the evaluation preserves the worker's output.

UI Labs plugin execution, a deterministic live close-during-flight case, malicious requests through the live transport, complete feature teardown/restart, and Escape input remain unverified. There is no evidence here of a package incompatibility or a need to add a different UI/state/network library.

All benchmark changes remain uncommitted for inspection. The parent stopped its own play session and reset the simulator to the original default; no user play session was stopped. No task-owned branches or worktrees were created. Disposable import fixtures were removed after recording their evidence. No recommended project-level solution has been implemented.
