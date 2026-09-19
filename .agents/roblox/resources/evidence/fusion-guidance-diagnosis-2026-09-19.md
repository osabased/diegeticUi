# Fusion guidance root-fix diagnosis — 2026-09-19

## Decision

The three findings do not have one common remedy.

1. The `ForPairs`/numeric `Tween` failure is a worker annotation omission exposed by a strict-Luau inference edge, not a defect in Fusion's reusable API or installed typings. The smallest correction is to type the processor's calculation scope (`rowScope: Scope`). A maintained, statically analyzed exemplar should demonstrate that boundary. The extra `Fusion.Use`, key/value, return, `Fusion.Computed<number>`, and `Fusion.Tween<number>` annotations currently in the demo are valid but not required to make this case type-check.
2. The cleanup finding exposes a real integration seam. Janitor 1.18.3 cannot by itself promise producer-before-scope ordering or best-effort cleanup after a cleaner throws. The production Loadout feature also acquires and mounts its Fusion scope before registering cleanup. Documentation alone has therefore not kept the unsafe pattern out of production. A narrow feature-local mount owner is warranted; Janitor should contain that owner, while one protected composite teardown encodes the ordered failure contract.
3. The `New` plus `Hydrate` mistake is already prohibited clearly by the Fusion reference. The current code uses one `New` call with `scope.Children`, so the mistake is gone. Elevating the one-owner invariant into the strict typed exemplar/review checklist is reasonable, but a wrapper, vendor patch, or regression test that inspects scope internals would add complexity without guarding an observed behavior failure.

No source, skill, policy, package, or test file was changed in this investigation.

## Evidence boundary

This diagnosis used the current project source through CodeGraph first, then inspected the installed Fusion 0.3.0 and Janitor 1.18.3 sources. It did not run Studio or Lest. Four temporary strict-Luau probes were analyzed with the project's pinned Roblox definitions and sourcemap, then removed. The probes varied only the `ForPairs` callback annotations; no package, test, or generated dependency was mutated.

The evaluation report records the original failure and fix at `.agents/roblox/resources/evidence/fusion-usage-evaluation-2026-09-19.md:51-55`. The final callback is at `src/client/Loadout/PresetPickerDemo/View.luau:139-147`, the corrected one-step list construction is at `src/client/Loadout/PresetPickerDemo/View.luau:220-232`, and the handwritten controller is at `src/client/Loadout/PresetPickerDemo/Mount.luau:25-100`.

## 1. Strict `ForPairs` inner-scope and numeric `Tween` inference

### What the installed types require

Fusion's installed `ForPairsConstructor` is generic over the input/output key and value types plus a scope-constructor type `S`. It passes that same `S` into the processor as its second argument (`Packages/_Index/elttob_fusion@0.3.0/fusion/src/Types.luau:125-129`). `Computed` similarly passes the containing scope type into its callback (`Types.luau:116-119`), while `Tween` infers `T` directly from `UsedAs<T>` (`Types.luau:153-161`). The runtime implementation supplies each item processor with a calculation scope and destroys that scope when the item processor fails or the item is discarded (`State/ForPairs.luau:46-73`, `77-94`).

The types express the real runtime contract. The problem is contextual inference of the recursive scoped-constructor intersection when the processor's second parameter is left unconstrained. Once `rowScope` is explicitly typed as `Fusion.Scope<typeof(Fusion)>`, the compiler can infer the input key/value, output pair, numeric `Computed`, numeric `Tween`, and downstream `use(selectedMotion)` without further annotations.

### Probe results

Each probe reproduced the demo's essential `ForPairs -> Computed<number> -> Tween<number> -> Computed<UDim2> -> New` chain under `--!strict`.

| Processor annotations | Inner state annotations | Analyzer result |
| --- | --- | --- |
| none | none | failed with the same escaping generic/cascading `Computed`, `Tween`, and `UDim2.new` errors |
| only `rowScope: Scope` | none | passed |
| full `Fusion.Use`, `Scope`, key/value, and return types | none | passed |
| no processor annotations | explicit `Computed<number>` and `Tween<number>` | failed; annotating downstream symptoms did not constrain the processor scope |

This falsifies the idea that four explicit callback types plus two animation types are inherently required. It also rules out a numeric-Tween typing defect: numeric inference succeeds after the scope generic is fixed at the callback boundary.

### Ideal correction

Use the public API directly and annotate the second processor parameter:

```luau
local rows = scope:ForPairs(filteredById, function(_use, rowScope: Scope, presetId, preset)
	local selectedGoal = rowScope:Computed(function(use)
		return if use(state).selectedId == presetId then 1 else 0
	end)
	local selectedMotion = rowScope:Tween(selectedGoal, TweenInfo.new(0.18))
	-- row-owned Instances, state, and connections use rowScope
	return presetId, button
end)
```

The current fully annotated callback is safe and readable, so production code need not churn merely to remove annotations. The root guidance improvement is a compact strict-typed `ForPairs` plus `Tween` exemplar that says the calculation-scope parameter is the critical annotation under strict Luau. Put the exemplar on a path reached by the canonical analyzer so future package-typing or compiler changes make the example fail mechanically.

Do not add a wrapper around `ForPairs` or `Tween`: it would duplicate generic signatures and hide item-scope ownership. Do not use type assertions to silence the errors: they would suppress evidence when the processor's input/output types actually drift. Do not edit generated/vendor typings: the installed signature is accurate and the public API passes once the callback boundary is constrained.

The existing reference already explains that `ForPairs` supplies an item scope and that row resources belong in it (`.agents/skills/roblox-fusion/references/fusion-0.3.md:23`). What is missing is the strict-Luau annotation at that exact boundary and an executable example; the ownership rule itself is not missing.

## 2. Cleanup owner, ordering, and failure contract

### Required contract

The mount boundary owns the following resources:

- all producer callbacks that can write to the Fusion snapshot or invoke UI/domain behavior (at minimum the Charm subscription; in runtime Loadout, also networking and input);
- the Fusion scope and every scope-owned Instance, observer, event connection, and item scope;
- optional root-destruction linkage; and
- the controller's final, idempotent transition from alive to destroyed.

Teardown must stop producers before consuming the Fusion scope. Every top-level cleanup phase must be attempted even when an earlier phase fails. Explicit destroy must report all cleanup failures. Construction failure must keep the construction error primary, attempt the same teardown, and append cleanup failures without replacing the original error. Each owned callback and the scope must be detached from the owner before invocation so reentrant or repeated destroy cannot run them twice. A subscription API must either return its disposer after successful acquisition or leave no subscription behind when it throws; no owner can clean an acquisition that throws after side effects without returning a handle.

The scope itself has a stricter limit: Fusion performs reverse-order cleanup, but a throwing scope task aborts the remaining scope loop (`Packages/_Index/elttob_fusion@0.3.0/fusion/src/Memory/doCleanup.luau:61-76`). The mount owner can ensure that producer cleanup and `Fusion.doCleanup` are both attempted; it cannot make Fusion continue inside a failed scope. Project-owned scope cleanup callbacks must therefore be non-throwing after recording useful diagnostics.

### Why separate Janitor entries are insufficient

The pinned Janitor stores cleanup methods in a table and iterates with `next` (`Packages/_Index/howmanysmall_janitor@1.18.3/janitor/src/init.luau:824-895`). It gives no reverse or insertion-order guarantee. A function or custom method is invoked directly, so an error exits `Cleanup` before later resources, namespace clearing, and state restoration (`init.luau:833-895`). `Destroy` simply calls that cleanup and then removes the metatable (`init.luau:907-910`). `LinkToInstance` registers a `Destroying` connection that calls `Cleanup` (`init.luau:915-920`).

Those details agree with the Janitor guidance: deterministic ordering is out of scope (`.agents/skills/roblox-janitor/SKILL.md:19`), throwing cleaners interrupt cleanup (`SKILL.md:112,124-125`; `references/api.md:29`), and ordered teardown belongs inside one callback (`SKILL.md:124`). Consequently, registering the subscription and `Fusion.doCleanup(scope)` as two ordinary Janitor entries does not satisfy the Fusion contract even though both entries nominally have an owner.

There is a cross-skill integration gap. Fusion says to register the disposer and `Fusion.doCleanup(scope)` with the feature Janitor (`.agents/skills/roblox-fusion/references/fusion-0.3.md:57`) while also requiring the owner to unsubscribe first and preserve body and cleanup failures (`.agents/skills/roblox-fusion/SKILL.md:85-86`). Janitor documents the constraints elsewhere, but the Fusion seam does not say that the two actions must be grouped into one protected, non-throwing Janitor task. Reading only the Fusion common path invites an implementation Janitor cannot guarantee.

### Current implementation risk

The demo's handwritten `cleanup` does preserve the order and independently protects the unsubscribe and Fusion scope (`src/client/Loadout/PresetPickerDemo/Mount.luau:25-48`). It also makes returned `destroy` idempotent and preserves a view-construction error (`Mount.luau:64-99`). Its main gaps are earlier acquisition and project integration: the scope, `Value`, and subscription are acquired before the protected construction block (`Mount.luau:56-66`), and the controller does not use the adopted lifecycle owner.

The same issue already exists on the production path. `src/client/Loadout/init.luau:29-56` creates the scope, root, and complete view before registering the scope callback, subscription, network listener, keyboard connection, and root link at lines 58-89. A failure during `View.create` can therefore leave already-created Fusion resources unowned. After successful setup, the scope and producers are separate Janitor entries, so their relative cleanup order is unspecified and one failure can prevent the others.

That existing production shape is evidence that prose alone does not suffice. The finding is broader than the demo worker's choice.

### Ideal integration

Add one narrow feature-local mount owner beneath the Loadout lifecycle root, for example `src/client/Loadout/ViewMountOwner.luau`, and use it from both runtime Loadout and the demo mount. Keeping it below the existing feature root follows `.agents/roblox/structure.md`'s rule that helpers live beneath their owning lifecycle root and avoids creating a new loader-discovered root.

The owner should:

1. create its Janitor before acquiring the Fusion scope;
2. immediately register one composite teardown function with the Janitor;
3. let the composite own optional producer disposers and the optional scope, detach each handle before calling it, stop every producer first, then call `Fusion.doCleanup`;
4. protect each top-level action independently and accumulate labelled tracebacks into owner state; the composite itself must not throw while Janitor is iterating;
5. wrap the entire acquisition and view-construction body, including scope, state, subscriptions, listeners, view creation, and root linkage;
6. on construction failure, destroy the owner, then raise the body traceback followed by accumulated cleanup failures;
7. on explicit final destroy, call `janitor:Destroy()` once, then surface accumulated failures after Janitor has completed; repeated destroy is a no-op; and
8. if root destruction is an automatic teardown trigger, route it through the same guarded destroy path and report stored errors without throwing out of the `Destroying` callback.

Janitor remains the containing lifecycle owner and handles linkage/final invalidation. The composite callback is necessary sequencing logic, not a replacement cleanup library. Avoid relying on Janitor indices to imply order. Avoid letting the composite throw while Janitor is active, because Janitor 1.18.3 would abort and leave the owner partially cleaned.

A project-wide generic Fusion framework is not warranted yet. The seam is specific to the existing Loadout feature, and the scope type plus producer/failure policy are small enough for one deep helper. Extract farther only after another client feature demonstrates the same contract.

### Executable regression checks

Extend the owner-level Studio coverage rather than testing Janitor implementation details:

- fail after the scope and a partial root exist; assert the body message remains primary and the holder returns to baseline;
- inject a throwing producer disposer; assert later producers and Fusion cleanup still run, the root is removed, and the labelled disposer error is surfaced;
- inject both a body failure and a producer cleanup failure; assert both appear and the body failure is first;
- destroy twice; assert each producer and scope cleanup is attempted once;
- if root-destruction linkage is part of the public contract, destroy the root externally and assert producer disposal once with no callback error;
- run the canonical analyzer over the owner and the strict typed `ForPairs`/`Tween` exemplar.

Do not add a test that assumes Janitor reverse order; the pinned source expressly provides none. Do not inject a throwing task inside a real Fusion scope and expect later scope tasks to run; that would assert behavior Fusion 0.3.0 does not provide. Use injectable top-level producer/scope-cleanup functions to test the mount owner's isolation, and keep a separate ordinary Fusion cleanup case to prove the real root is removed.

## 3. Duplicate `New` plus `Hydrate` ownership

The reference is already exact: both constructors add the target Instance to the scope, and hydrating a caller-owned Instance transfers destruction ownership (`.agents/skills/roblox-fusion/references/fusion-0.3.md:11`). The installed code confirms that `New` inserts its created Instance before applying properties (`Packages/_Index/elttob_fusion@0.3.0/fusion/src/Instances/New.luau:31-49`) and `Hydrate` inserts the target again (`Instances/Hydrate.luau:16-29`). The corrected view constructs `rows` first and supplies them through `scope.Children` in the single `New("ScrollingFrame")` call (`src/client/Loadout/PresetPickerDemo/View.luau:139-218,220-232`).

This was an implementation mistake caught by already-sufficient guidance, not a missing API. A useful invariant to state prominently is: **an owned Instance is enrolled in a given scope once; choose `New` for creation or `Hydrate` for ownership transfer, and include all known reactive properties/special keys in that call.** Later direct property assignment is appropriate only for non-reactive mutation whose ownership does not change.

Fusion's `alreadyDestroying` guard covers active recursive cleanup, then clears after each task (`Memory/doCleanup.luau:22-30,76`). The same Instance listed twice is therefore presented to `Destroy` twice sequentially; this does not produce Fusion's `destroyedTwice` diagnostic. The evaluation observed no runtime failure. A regression test that counts internal scope entries, bans every later hydration syntactically, or expects a warning would test representation or style rather than user behavior.

No wrapper should track Instances merely to reject duplicate enrollment, and no vendor change is justified. Keep the invariant in the typed exemplar/review guidance. Add an executable behavior test only if a real component later demonstrates a double-cleanup symptom (for example, a duplicated custom cleanup task with an observable second call); then assert that symptom and final ownership outcome rather than Fusion's internal array shape.

## Recommended change order

1. Implement the feature-local mount owner and move runtime Loadout plus demo mounting onto it; this closes an existing production leak window and reconciles Fusion's failure contract with Janitor's real behavior.
2. Add the owner failure-path Studio cases and retain the current ordinary mount/remount assertions at `tests/studio/LoadoutPresetPickerDemo.spec.luau:61-113`.
3. Add a maintained strict typed `ForPairs` plus numeric `Tween` exemplar on a canonically analyzed path, using `rowScope: Scope` as the essential boundary annotation.
4. Clarify the Fusion-to-Janitor integration text: separate Janitor entries do not encode order or error isolation; use one protected composite task when producer-before-scope teardown matters.
5. Promote the one-enrollment `New`/`Hydrate` invariant, without adding a wrapper or style-only regression test.

