# Forward evaluation: setup skills

## Scope and evidence status

This is a read-only review of the reduced starter at `forward-evaluation/starter`. The supplied context says the starter is not a runnable application, `View.luau` is an intentionally omitted rendering implementation, and its APIs are fixture contracts rather than claims about a real library. I did not modify or execute the starter and did not treat the reported construction run as a runtime UI test.

I used the current copies of:

- `C:/Users/Lowle/.agents/skills/roblox-resource-acquisition/SKILL.md`
- `C:/Users/Lowle/.agents/skills/roblox-resource-acquisition/references/{generation-validation,integration-proof,operational-lifecycle,repair-loop,state-policy,testing-protocol}.md`
- `C:/Users/Lowle/.agents/skills/structure-roblox-projects/SKILL.md`
- `C:/Users/Lowle/.agents/skills/structure-roblox-projects/references/core/practices.md`
- `C:/Users/Lowle/.agents/skills/structure-roblox-projects/references/workflows/rojo.md`, SHA-256 `67A2375800F6A2CAC6AFF18A3DC86022BD6D5501F0271B238B5D7E0B24DD52B8`
- `C:/Users/Lowle/.agents/skills/structure-roblox-projects/scripts/check_rojo_artifact.py`, SHA-256 `0AB39730BCE2309B85392D82A8468225FC72BF621AF75297BD2B4406E83235FA`

The final two hashes identify the corrected reference/helper version used for the final checker runs; neither file exposes a semantic version.

## Task A: starter review

Verdict: the setup and verification are insufficient for building real UI. The reported passing assertions establish only a narrow construction/domain-state lane.

| Finding | Evidence and impact | Smallest supported correction |
| --- | --- | --- |
| Release composition includes development content | `default.project.json` maps all of `src/client`; `Panel.story.luau` and `PreviewDemo/Data.luau` are therefore inside the only mapped artifact. There is no release profile. Lack of an entrypoint does not exclude either module from a build. | Keep one runtime mapping source of truth and derive a development and release composition without duplicating services. Give the story and preview explicit `exclude` intent. On the project's actual Rojo pin, build a sourcemap and text `.rbxlx`; require exact retained runtime paths, forbid story/preview markers, and count each affected singleton service exactly once. Keep excluded source in strict analysis and tests. The Rojo 7.7 wrapper/glob example in the skill is a candidate, not established behavior for this unpinned starter. |
| The mapped tree is not an executable, dependency-complete client setup | The only mapping is `ReplicatedStorage.Client -> src/client`. `Panel` is a ModuleScript with `Start`, but no client Script invokes it. `libraries/Owner.luau` is outside the mapping, while `Panel/init.luau` requires a `libraries` descendant from the DataModel; that target will not exist in the generated tree. `View.luau` is intentionally only a stub. | Add one explicit normal client bootstrap in a supported client execution location and have it require/start `Panel`. Put `Owner` in the same authoritative mapping at the required path, or move it under the owning client feature and update the require. Do not label this canonical SSA: no ModuleLoader entrypoint exists. Replace the `View` stub before making runtime claims. |
| Construction and teardown ownership are unsafe under the stated fixture contract | The durable owner exists before acquisition, but `View.dispose(state)` is registered only after fallible `View.create(state)`. The contract says `create` can fail after allocating UI. The supplied owner stores callbacks in an unordered table, clears after callbacks, and stops at the first thrown callback; separate cleanup entries therefore do not supply ordering, continuation, or reentrancy guarantees. | Register one idempotent owner-held composite cleanup before `create`. It should detach the subscription before disposing reachable state/view, clear handles before invoking them, attempt each labelled phase even if one fails, and run on construction failure and explicit/repeated teardown. Preserve the construction error as primary and append cleanup failures. If `create` can leak side effects that `dispose(state)` cannot roll back, treat that API behavior as an integration defect rather than claiming caller cleanup solves it. |
| The current verification cannot support UI, input, lifecycle, or clean-diagnostics claims | The construction test calls domain setters and reads labels. The Studio session available to input/screenshot tools cannot require the module because of its Script Capabilities boundary. No pointer, keyboard, focus, screenshot, or normal-startup observation exists. Diagnostic capture recognizes only errors and library-prefixed warnings, disconnects before shutdown, and therefore did not guard the intermittent shutdown callback message. | Keep four evidence lanes separate. Run strict/static and construction checks on the real mapped implementation. Add owned-lifecycle cases for each fallible acquisition boundary, cleanup-phase failure with later phases still attempted, repeated/reentrant destroy, and post-disposal producer isolation. For UI/input claims, run the filesystem/Rojo source through a capability-compatible normal client startup in the same Studio session, fingerprint source plus project config, confirm a UI marker, then use real pointer/text events and rendered-state captures. Capture generic warnings/errors from before load through owned teardown/process exit; force an unallowlisted generic warning and error to prove the harness turns red and retains the diagnostic artifact. |

The Script Capabilities failure is an environment/runtime-path blocker for the Studio lane, not evidence that the stub API or cleanup library is defective. The intermittent `Script that implemented this callback has been destroyed while calling callback` message remains unattributed. First make diagnostics red-capable through shutdown, then reduce and isolate the producer. Widening capabilities or bypassing normal startup would not be a supported correction.

Resource status is intentionally not manufactured: the fixture names no canonical community resource, version, project adoption authority, or generated child. There is no resource to mark trusted, verified, failed, or operational. The verification defect blocks only the affected clean-diagnostics/runtime claims; it does not block this structural review.

## Artifact-checker execution

The checker applies because development and release artifacts are intended to differ. I created synthetic disposable sourcemap/`.rbxlx` pairs in `output/scratch`; they exercise the checker and are not represented as builds of the non-runnable starter.

The final command shape for each pair was:

```text
python C:/Users/Lowle/.agents/skills/structure-roblox-projects/scripts/check_rojo_artifact.py --sourcemap <pair>.sourcemap.json --place <pair>.rbxlx --label <label> --require-path ReplicatedStorage/Client/Panel/View --require-path StarterPlayer/StarterPlayerScripts/ClientBootstrap --forbid-path-fragment Panel.story --forbid-path-fragment PreviewDemo --singleton-class ReplicatedStorage --singleton-class StarterPlayer
```

- Valid release: exit `0`; `valid-release-exact: OK (7 sourcemap instances, 7 place instances)`.
- Deliberately defective release: exit `1`. In both sourcemap and place it detected the missing exact bootstrap path, retained story and preview, two `ReplicatedStorage` instances, and zero `StarterPlayer` instances.

This is a falsifiability check for the helper only. The starter still needs real artifacts built with its selected/pinned Rojo version before release exclusion can pass.

## Task B: label-only established component change

No structural setup or resource-acquisition work is appropriate. This is the established-project fast path: edit the authoritative label from `Ready` to `Available`, update a directly affected expectation only because the requested contract changed, and run the smallest existing focused check. The unchanged mapping, runtime, ownership, and release topology do not justify a profile, migration plan, artifact composition check, lifecycle redesign, project preference question, resource search, or resource record.

## Task C: inert pure mathematical helper, advice-only guidance

Do not acquire a library or invent runtime/lifecycle proof. Ground the advice in the helper's current source, public contract, existing unit/property tests, and a stable source revision or scoped hash. If reusable agent guidance is authored, label its claim scope `advice-only` and collect independent instruction-response evidence for:

- justified positive activation and a negative case where a built-in or tiny local expression is better;
- setup from documented prerequisites, correct use of the real API, representative math behavior, domain/precision/invalid-input edge cases, and troubleshooting without invented methods;
- truthful source/provenance visibility and an explicit boundary that no Studio/runtime integration was proved.

A generated-skill structural validator, if a skill artifact is actually created, proves only structure. Advice responses and existing math tests remain different evidence types. Studio, UI, teardown, cancellation, task, connection, and instance tests are not applicable when source inspection confirms the helper is inert. If someone later claims executable integration, strict/unit execution may support the mathematical behavior and the evidence should explicitly record the absence of owned lifecycle work rather than fabricate cleanup cases.

## Confusion, failed approaches, and contradictions

- The task named `forward-evaluation/logs/context.txt`; the supplied file was actually `forward-evaluation/starter/logs/context.txt`. The first read failed, then a directory-only listing located it. No unrelated reports or conversations were opened.
- The structure helper/reference changed during evaluation. An earlier fragment-based retention run was superseded; the final runs above used the corrected exact `--require-path` interface and the recorded hashes.
- The Rojo guidance deliberately limits its thin-wrapper/glob evidence to pinned 7.7 and now describes the dual-pattern evidence more narrowly. Copying that shape into this starter without a project pin and generated-output check would be a false claim.
- `roblox-resource-acquisition` can be confusing in Tasks A/C because neither task supplies a community-resource identity. Its evidence-boundary rules are useful, but creating acquisition candidates, trust state, portable records, host adoption, or cleanup gates here would be unnecessary work and would contradict the fixture/advice-only scope.
- No contradiction was found between the two skills: structure owns Rojo composition/startup topology; resource guidance owns truthful integration/lifecycle evidence when a real resource or reusable resource child is in scope. The review keeps those authorities separate.
