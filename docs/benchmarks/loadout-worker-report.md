# Session loadout benchmark report

## Behavior contract

- The on-screen button and `L` key open or close the panel; Escape closes it.
- Five equipment entries are shown. Selecting any entry updates the detail view, while the Grav Hammer remains visibly locked.
- Selection alone never equips. A valid, available, changed selection requires a separate Equip action.
- The server validates request shape and catalog availability, owns each player's session-only equipped item, and acknowledges accepted or rejected requests.
- A submitted request visibly enters pending state, cannot be submitted twice, and ends in visible accepted or rejected feedback.
- Closing before submission leaves the equipped item unchanged. Closing during a request leaves the request alive; its acknowledgement updates domain state while hidden and is visible after reopen.
- Cleanup disconnects input, networking, reactive subscriptions, player lifecycle hooks, and destroys the UI.
- Mouse and keyboard are supported. The panel changes to a stacked layout below 560 pixels of rendered width.

## Verification

- `lute run scripts/verify.luau` passed the canonical Blink integrity, format, lint, strict analysis, 14 native tests, and disposable Rojo build gate (`.verify/reports/20260918T210419854Z-000.json`).
- Native loadout tests cover no-equip close, locked and duplicate submission blocking, acknowledgement while closed, stale acknowledgement handling, and server validation of available, locked, unknown, and malformed requests.
- `lute run scripts/verify.luau --stage studio` constructed the Fusion view, observed its pending transition, and proved scope cleanup (`.verify/reports/20260918T210502617Z-000.json`). The repository's existing Fusion diagnostic tests also passed.
- A disposable Studio play session created `SessionLoadout` without project errors. Real `L` input opened the panel. Pointer input selected Arc Shield and confirmed Equip; the resulting UI read `Equipped Arc Shield for this session.` and became inactive, proving the Blink client/server acknowledgement path. Closing and reopening with `L` preserved that authoritative state.
- A first Galaxy A06 800×360 landscape capture found the panel's minimum height clipping its header/footer and the open button obscuring the modal. The constraints were corrected, the open button now hides while the modal is open, and a second capture showed the full header, details, status, and action area inside the viewport. Studio was returned to Edit mode and the device simulator was reset to its default viewport.
- A real close during the brief network in-flight window and a live malicious locked request were not deterministically exercised. Their state/validation paths passed native tests; the pending, locked, and error presentations are also isolated in UI Labs stories. The UI Labs plugin itself was not opened during this run.

## Project friction

- The repository had no feature or UI Labs story example. Implementing the first feature required reading the installed UI Labs `Types` and `StoryCreators` package files to establish the expected story shape. The resulting storybook and four stories compile, but discoverability would improve with a project-owned example or a short story workflow note.
- Native Lest executes source modules without Roblox's `script` global, while runtime modules conventionally resolve siblings through `script.Parent`. `StateMachine` and `Validator` therefore use a dual runtime/native require guarded by a narrow Selene allowance. A project test loader that supplies ModuleScript semantics would remove this recurring compatibility seam.
- The Studio device simulator guidance said orientation could be set before device activation, but Studio returned `orientation can only be set on mobile (phone or tablet) devices` until the phone preset was activated first. Reversing those calls worked. This is a shared guidance mismatch and was reported here rather than repaired.
- Studio pointer automation emitted repeated `VirtualInput::SendMousePosition ... hits CoreGUI` diagnostics even though the targeted experience controls did activate and the authoritative result appeared. Per the project verification guidance, no further pointer paths were retried after that evidence; keyboard checks and read-only UI probes remained reliable.
- The final Studio construction run printed an unrelated `MaterialManager` plugin `debug.profileEnd() - No active profile annotation` stack while all five tests passed. It did not originate from project code or affect assertions, but it adds noise to engine-backed verification.
- Blink regeneration rewrites large randomized generated modules for a two-event schema change, producing a much larger review surface than the hand-authored protocol. This is expected for the pinned prerelease and the canonical verifier confirmed the generated stamp.
