# Fusion usage evaluation — 2026-09-19

## Outcome

Implemented an isolated, development-only searchable loadout preset picker under the existing client Loadout feature. It is a nested demo folder with no `init.luau`, so the SSA loader does not discover or start it as a gameplay feature. A local Charm domain owns query, preset, and selection state; Fusion renders filtered rows, a visible empty state, and a tweened selected-row indicator. Removing the selected preset clears the selection rather than leaving a dangling id.

The component has populated and empty UI Labs stories. The reusable mount owner subscribes Charm to one Fusion snapshot, cleans the subscription before the scope, tolerates repeated `destroy` calls, and cleans partial Fusion UI while retaining the original construction error.

## Discovery and explicit guidance

The initial skill catalog identified `roblox-fusion` as project-specific Fusion 0.3 guidance for scoped components, UI-local state, animation, cleanup, and UI Labs stories. Before implementation, I explicitly read `.agents/skills/roblox-fusion/SKILL.md` in full, then read its linked `references/fusion-0.3.md` because this demo used `ForPairs`, `Tween`, inner scopes, special keys, and UI Labs. I also read `.agents/roblox/structure.md` before choosing placement.

The explicit skill reading materially added requirements that were not present in the catalog summary:

- Run the current-block resource check before affected use and verify the pin, lock, and installed redirect.
- Create reactive sources before consumers, borrow component scopes without cleaning them, and let the owner call `Fusion.doCleanup` exactly once.
- Use the `ForPairs` calculation inner scope for row-owned state, connections, instances, and animation.
- Keep the UI Labs story on `props.scope` and do not clean that scope in the story.
- Preserve a construction body error separately from cleanup errors.
- Treat edit-mode construction and programmatic assertions as different evidence from pointer input and rendered animation quality.

The pre-use status check returned `HEALTHY`. `wally.toml`, `wally.lock`, and `Packages/Fusion.lua` all resolved `elttob/fusion@0.3.0`.

## Files changed

- `src/client/Loadout/PresetPickerDemo/Domain.luau`
- `src/client/Loadout/PresetPickerDemo/View.luau`
- `src/client/Loadout/PresetPickerDemo/Mount.luau`
- `src/client/Loadout/PresetPickerDemo/StoryFactory.luau`
- `src/client/Loadout/PresetPickerDemo/Populated.story.luau`
- `src/client/Loadout/PresetPickerDemo/Empty.story.luau`
- `src/client/Loadout/PresetPickerDemo/PresetPicker.storybook.luau`
- `tests/studio/LoadoutPresetPickerDemo.spec.luau`
- `.agents/roblox/resources/evidence/fusion-usage-evaluation-2026-09-19.md`

No dependency, loader, existing feature, skill, record, learning, permission, or test configuration file was changed for this evaluation. Existing unrelated uncommitted files were preserved.

## Checks executed

- `python "$env:USERPROFILE/.agents/skills/roblox-resource-acquisition/scripts/check_resource_status.py" --pair .agents/skills/roblox-fusion .agents/roblox/resources/records/elttob-fusion.yaml` — passed with `HEALTHY`.
- `stylua src/client/Loadout/PresetPickerDemo tests/studio/LoadoutPresetPickerDemo.spec.luau` — applied; the final canonical format check passed.
- Focused `luau-lsp analyze` with the same Roblox definitions, sourcemap, ignores, and source/test roots as the verifier — passed after fixing the first-pass callback inference issue.
- `lute run scripts/verify.luau` — final run passed and printed `[verify] PASS`; report: `.verify/reports/20260919T043835180Z-000.json`. This covered prepared dependency integrity, Blink drift, sourcemap generation, formatting, Selene, strict Luau analysis, 14 native unit tests, and a disposable place build.
- `rojo build default.project.json --output .verify/diegeticUi.rbxlx` followed by `lest run studio --config lest.toml --forbid-only` — all 9 Studio tests passed, including the demo's 3 cases. The suite asserted case-insensitive filtering, valid selection changes, removed-selection coherence, visible empty state, reactive rows and summary, mount/unmount/remount, idempotent owner teardown, zero children after cleanup, partial-construction cleanup, and preservation of the injected body error.
- `lest run studio --config lest.toml --forbid-only --filter 'loadout preset picker demo'` — the demo's 3 Studio tests passed in isolation without diagnostics.

Programmatic Studio assertions prove construction, reactive state changes, dynamic row disposal, owner cleanup, remounting, and failure cleanup. They do not prove pointer input, text focus behavior, or the timing and visual quality of the selected-indicator tween.

## Confusion, failed approaches, and workarounds

### My implementation mistakes

The first canonical verifier run failed strict analysis in the `ForPairs` row processor. I relied on inference for the processor's inner scope and numeric tween goal; the resulting generic errors spread across `Computed`, `Tween`, and `New`. Explicit `Fusion.Use`, `Fusion.Scope<typeof(Fusion)>`, `Fusion.Computed<number>`, and `Fusion.Tween<number>` annotations fixed the issue. This was my mistake, not a Fusion or project defect.

I initially created the scrolling frame with `scope:New` and later called `scope:Hydrate` to add dynamic children. The skill reference says both constructors add the target instance to the scope. I changed the order so `ForPairs` rows are created first and passed through `scope.Children` in the original `scope:New` call, avoiding duplicate ownership. No runtime failure was observed; this was an implementation inefficiency caught during review.

### Tooling limitations and unsuccessful validation attempts

The MCP Studio command thread could not require `ReplicatedStorage.Client.Loadout.PresetPickerDemo.Mount`; Studio reported that the module had additional `LoadUnownedAsset` and related capabilities. A play-session-only LocalScript bootstrap was also rejected when the command thread tried to parent it into `PlayerScripts` for the same capability reason. The play session started for this attempt was stopped immediately afterward.

This limit matches the skill's `Verify after installation` explanation that the Lest recipe uses edit-mode `RunScript`, "avoiding assistant-thread capability limits." That guidance accurately predicts the failure, but it does not provide a route for interactive or visual validation of a newly implemented component when the Lest-launched Studio process is not exposed to the Studio MCP bridge.

I tried a temporary Lest visual probe that mounted the UI under `CoreGui` and held it for capture. Lest's CLI Studio was not the Studio instance exposed by the MCP bridge, and the probe exceeded the configured test deadline. The temporary probe was removed. This was an ineffective task-local workaround combined with a tooling topology limitation; it is not evidence of a component defect.

One unfiltered 9-test Studio run printed `Script that implemented this callback has been destroyed while calling callback` after every test had passed. The focused demo-only rerun passed cleanly without that output. The message is therefore an unattributed cross-suite or Studio-shutdown concern, not a validated demo or Fusion guidance defect.

## Guidance implicated

- **Lifecycle and cleanup:** "The feature owner unsubscribes external producers and calls `Fusion.doCleanup(scope)` exactly once" and "If construction or a component callback throws, the owner still cleans its already-created scope. Preserve the original body error separately from any cleanup error."
- **UI Labs stories:** "accept `props.scope` and `props.target`, and call the same component factory used by runtime" and "the story body must not create an unrelated long-lived scope or clean `props.scope` itself."
- **List transforms and animation reference:** use the processor's inner scope for item-specific cleanup and create `scope:Tween` after its goal state.
- **Limitations:** edit-mode construction proves reactive properties and cleanup, while pointer input and rendered animation quality still require playtest observation.
- **Verification:** the canonical integrity gate is `lute run scripts/verify.luau`, and the maintained Studio path uses a built place plus Lest.

The skill was effective for API selection, ownership, dynamic list cleanup, failure handling, and evidence boundaries. The main inefficiency was that its `ForPairs` prose does not warn that strict Luau may need explicit processor, scope, and animation types in a nontrivial callback; this is a usability gap, not a correctness defect. The missing bridge from Lest's Studio process to MCP visual/input tools is a tooling limitation outside the skill's control, though a documented visual-validation route would improve the workflow.

## Remaining unverified behavior

- No actual pointer click or typed TextBox input was observed. The tests called domain operations directly and observed resulting UI state; this does not establish that the input callbacks were triggered.
- The populated and empty UI Labs stories were built and statically analyzed but were not manually opened in UI Labs.
- The selected indicator is implemented with a 0.18-second quintic Fusion tween, but its rendered motion, interruption feel, and final visual quality were not observed.
- No screenshot provides visual proof of layout, typography, clipping, scrolling, or the empty-state presentation.

These limits are explicit evidence boundaries rather than claims of defects.

## Parent review

The Fusion skill and reference hashes match their pre-evaluation values, so the implementation used an unchanged target. Inspection confirms row-local Computed/Tween ownership, scoped event binding, coherent removed selection, and protected view-construction cleanup. The canonical report records success, and the disposable place is absent.

The strongest supported skill improvement is a compact, strict-typed ForPairs plus Tween example, demonstrated by this worker needing explicit annotations. A supported preview/input route shared with the visible Studio instance is a project-tooling improvement; this run did not establish such a route. The worker also wrote a custom mount cleanup owner instead of using the project-standard Janitor; that is an implementation convention deviation, not evidence that the skill lacks ownership guidance. The single unfiltered-run callback warning remains unattributed. No skill or project-policy repair was applied during this evaluation.
