# Setup production evaluation — 2026-09-19

## Outcome

The preset picker now has a complete development-to-release path using the project pins: Charm 0.11.0 owns its domain signal, Fusion 0.3.0 renders a mirrored snapshot, and Janitor 1.18.3 owns protected composite teardown. A direct-child development lifecycle root is started by the existing `ClientMain`/ModuleLoader path without yielding inside `Start`. A thin release profile excludes that root, the complete demo subtree, every authored `*.story.luau` and `*.storybook.luau` file, and the dedicated Loadout story factory while retaining the shared default mapping and Loadout runtime.

No dependency, lockfile, loader, generated network module, global skill, resource record, diagnostic harness, `lest.toml`, or canonical verifier source was changed by this evaluation.

## Implemented artifacts

- `src/client/Loadout/PresetPickerDemo/Mount.luau`: Janitor-first acquisition, producer-before-Fusion teardown, independent protected cleanup, primary construction error retention, idempotent final destroy, and a narrow disposer decorator used to reproduce cleanup failure.
- `src/client/PresetPickerDemoBootstrap.luau`: development-only SSA lifecycle root mounting the actual picker in `LocalPlayer.PlayerGui` through normal startup. Each `Start` destroys the prior pinned-Janitor owner before acquiring a fresh one; the non-throwing composite teardown is registered before GUI creation, captures labelled failures for reporting only after `Janitor:Destroy()` returns, and `Start` uses a non-yielding `PlayerGui` prerequisite check. `Destroy` finalizes the active owner and a later `Start` creates a new owner.
- `development.project.json` and `release.project.json`: wrappers over `default.project.json`; release excludes `PresetPickerDemoBootstrap.luau`, the `PresetPickerDemo` node and descendants, all authored story/storybook files, and the dedicated Loadout story factory.
- `tests/studio/LoadoutPresetPickerDemo.spec.luau`: real-package coverage for domain behavior, reactive mount/remount, partial view failure, early acquisition failure, throwing producer cleanup continuation, repeated destroy, and post-disposal producer isolation.
- `scripts/check_rojo_artifact.py`: repository-owned, standard-library checker vendored with provenance from the reviewed `structure-roblox-projects` helper.
- `tests/artifacts/verify_preset_picker_profiles.py`: cross-platform profile builder and generated sourcemap plus text-place assertions for 12 shared runtime ModuleScript paths, all 14 development-only bootstrap/story/demo ModuleScript paths, release exclusion, and singleton services.
- `tests/artifacts/test_check_rojo_artifact.py`: synthetic regressions proving that the checker detects required-runtime loss and a development-artifact leak in the built place even when its paired sourcemap is clean, a missing seven-module demo subtree with the bootstrap retained, and missing server/shared/network runtime modules with both entrypoints retained.
- `docs/preset-picker-development.md`: build, playtest, and release-boundary workflow.

## Executed evidence

### Artifact composition

Command:

```sh
python tests/artifacts/verify_preset_picker_profiles.py
```

Result: PASS.

- Development: 208 sourcemap instances and 218 place instances; required all 12 shared runtime ModuleScript paths plus 14 exact development-only paths. The development set includes the bootstrap, all existing Loadout stories/storybook and dedicated factory, and exact `PresetPickerDemo` paths for `Domain`, `Mount`, `View`, `StoryFactory`, `Empty.story`, `Populated.story`, and `PresetPicker.storybook`.
- Release: 193 sourcemap instances and 203 place instances; required the same 12 exact runtime paths: both entrypoints, client Loadout root/domain/view, authoritative server Loadout root, shared Loadout catalog/state machine/validator, and generated Network client/server/types. It forbids every `PresetPickerDemo`, `.story`, and dedicated Loadout story-factory path.
- Both artifacts contained exactly one `ReplicatedStorage` and one `ServerScriptService`.
- Final development place SHA-256: `97EFD2AF90C40A2226AF296C2B8E3FE268C1BF2F9D4D960932A51E1F665D449A`.
- Final release place SHA-256: `5E40CF4C5979F6B5E3D563FC1826B5E9BD3EC4F1FC4CA031E489FBC999C4172D`.

Checker regression command:

```sh
python -m unittest discover -s tests/artifacts -p "test_*.py" -v
```

Result: PASS, 4 tests. The generic checker regression separately removed a required runtime module from the built place and leaked a forbidden `.story` module into the built place while the paired sourcemap remained clean; each mutation produced the expected contract failure. The profile-specific regressions removed all seven exact demo subtree paths while retaining `PresetPickerDemoBootstrap`, then removed seven authoritative/shared runtime paths while retaining `ClientMain` and `ServerMain`. Each profile mutation produced the expected 14 missing-path failures across sourcemap and place. The clean retained-runtime/excluded-story fixture passed.

### Pinned-library lifecycle and construction

Commands:

```powershell
rojo build default.project.json --output .verify/diegeticUi.rbxlx
lest run studio --config lest.toml --forbid-only
```

Result: PASS, 13 tests in one Studio suite. The five preset picker tests passed, including partial acquisition/construction cleanup, continuation after a real Charm disposer was invoked and the decorated producer disposer threw, repeated destroy, and a Charm write after disposal without a poisoned Fusion update.

Focused static commands also passed:

```powershell
stylua --check src/client/Loadout/PresetPickerDemo src/client/PresetPickerDemoBootstrap.luau tests/studio/LoadoutPresetPickerDemo.spec.luau
selene src/client/Loadout/PresetPickerDemo src/client/PresetPickerDemoBootstrap.luau tests/studio/LoadoutPresetPickerDemo.spec.luau
luau-lsp analyze --platform roblox --definitions @roblox=tooling/roblox/globalTypes.d.luau --sourcemap sourcemap.json --ignore src/shared/Network/*.luau --ignore .lest/**/*.luau src/client/Loadout/PresetPickerDemo src/client/PresetPickerDemoBootstrap.luau tests/studio/LoadoutPresetPickerDemo.spec.luau
```

Selene reported 0 errors, 0 warnings, and 0 parse errors. Strict Luau analysis exited 0.

After replacing the bootstrap's manual module-global lifetime bookkeeping with the pinned Janitor and removing the unbounded wait, these final focused commands passed:

```sh
stylua --check src/client/PresetPickerDemoBootstrap.luau
selene src/client/PresetPickerDemoBootstrap.luau
luau-lsp analyze --platform roblox --definitions @roblox=tooling/roblox/globalTypes.d.luau --sourcemap sourcemap.json --ignore src/shared/Network/*.luau --ignore .lest/**/*.luau src/client/PresetPickerDemoBootstrap.luau
```

### Normal client startup and actual input

The attached Studio instance was in Edit mode with `ReplicatedStorage.Client.PresetPickerDemoBootstrap` under the existing loader root. Immediately before the final play, the Studio `Source` and dirty filesystem bytes for every runtime demo script were normalized to LF and hashed independently with the same 32-bit DJB2 procedure. All byte lengths and hashes matched exactly:

- `PresetPickerDemoBootstrap`: `3681:8ee13ab6`
- `PresetPickerDemo/Domain`: `3429:29eef0d5`
- `PresetPickerDemo/Mount`: `3596:581ccc67`
- `PresetPickerDemo/View`: `7926:8c283798`

No Studio source edits occurred between that comparison and play. This is direct evidence that the attached normal-startup run executed the final dirty filesystem sources, beyond relying on two locally built places having the same hash.

The final replay started one play session and confirmed `Players.Venuist.PlayerGui.PresetPickerDevelopmentPreview.PresetPicker` with `DevelopmentOnly = true`. The Studio input bridge sent a real pointer click to `PresetPicker.Search`, text input `drone`, then a real pointer click to the visible `recon` button. Observed client state was `Search.Text == "drone"`, `ResultCount.Text == "1 PRESET"`, `PresetList.recon.Visible == true`, and `SelectedSummary.Text == "Selected: Ghost Recon"`. The final rendered capture showed only Ghost Recon with its selected treatment. Studio console output was empty before and after interaction. The evaluation stopped only the play session it started and confirmed Studio returned to Edit mode.

## Demonstrated friction and residual limits

Final integration after the profile-assertion repairs passed the canonical verifier: `.verify/reports/20260919T061915500Z-000.json`. This includes 14 native tests, four Python artifact regressions, the diagnostic/dependency/report regressions, strict analysis, and real development/release builds. The separate guarded Studio and actual-input evidence above remains applicable; the profile assertion repair changed no runtime source.

- The first artifact verifier depended on Windows PowerShell and `%USERPROFILE%/.agents`, so it could not be a portable CI contract. The replacement is repository-contained Python using only the standard library; both its mutation regression and the real profile build now pass. Root integration wired `python tests/artifacts/verify_preset_picker_profiles.py` into the canonical build stage.
- An interim root integration run of `lute run scripts/verify.luau` passed and wrote `.verify/reports/20260919T060935789Z-000.json`, including 14 native tests, diagnostic/dependency/report regressions, two Python artifact regressions, and the 208/218 development plus 193/203 release profile counts. Later review found that this checker version used a required `PresetPickerDemo` fragment that could be satisfied by `PresetPickerDemoBootstrap` and did not yet require every retained server/shared/network runtime path. Treat that report as historical evidence for the checks it actually ran, not current proof of the strengthened release profile. Its Studio stage is explicitly `not_run`; the separate guarded 13-test Studio pass remains current runtime evidence above and in `studio-diagnostic-guard-2026-09-19.md`.
- The strengthened checker now uses 26 exact development paths and one shared 12-path runtime contract for both profiles. Four focused Python regressions and both real profile builds passed after this correction; root still owns the final canonical verifier report.
- The first strict-analysis attempt exposed two Luau `pcall` overload errors when destructuring a no-return callback. Replacing those calls with captured-error `xpcall` fixed the source; the final focused analysis and Studio suite passed.
- A separately launched explicit-development Studio window did not attach to the Studio MCP bridge and was closed without saving. The final replay instead used the existing attached Studio after exact runtime-script source comparison against the dirty filesystem, which is stronger source-binding evidence than the earlier artifact equality.
- The native Windows computer-use inventory did not expose Studio windows; actual pointer/text events and captures were completed through the Roblox Studio MCP input and screen-capture tools instead.
- The playtest proves desktop pointer and keyboard text behavior. Touch/gamepad behavior was not in scope and remains unverified.
