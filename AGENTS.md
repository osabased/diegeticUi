<!-- structure-roblox-projects:onboarding:start -->
## Roblox structure onboarding

Before making a structural placement, startup, source-of-truth, organization, or structurally owned dependency decision, read `.agents/roblox/structure.md` for the project's durable structural conventions.
<!-- structure-roblox-projects:onboarding:end -->

## Address issues at their source

Don't be compliant towards issues. Needing a workaround is evidence of a defect. Investigate why the intended path fails, capture expected versus observed behavior, and pursue a durable correction. A workaround may unblock the task, but it does not resolve the underlying issue.

Fix defects within the task's authorized scope and use the owning repair workflow when one exists. If an issue makes dependent work or verification unreliable, stop that work until the issue is reconciled. Otherwise, continue with a safe, reversible workaround while making the defect explicit. When the durable correction is outside scope, report the evidence and proposed fix before completion.

## Development workflow

The filesystem is authoritative. Rojo projects `src/` into Studio; do not make lasting source edits in the Studio DataModel. Keep runtime boundaries explicit:

All project-authored Luau uses `--!strict`. Keep types precise, prefer `unknown` over `any`, and use type casts deliberately.

- `src/server/` owns server-authoritative feature roots.
- `src/client/` owns client-only feature roots and presentation.
- `src/shared/` contains runtime-neutral modules that are required explicitly.
- Each direct-child ModuleScript under `Server` or `Client` is an SSA lifecycle root. Put implementation modules beneath the root that owns them.
- New project-authored client/server protocols use Blink-generated networking. Libraries that own their transport, such as Scribe, keep that boundary; LemonSignal is only for in-process events.

Install the pinned toolchain with `rokit install`. Before any package installation, including direct `wally install`, stop the Rojo server serving this checkout. For initial setup, stale preparation, or intentional dependency updates, follow [`docs/verification.md#dependency-preparation-and-updates`](docs/verification.md#dependency-preparation-and-updates); it distinguishes restoring the locked graph from updating and reviewing the lockfile. Resume a previously running Rojo server only after preparation succeeds. CI prepares dependencies before verification.

The single required local and CI gate is:

```sh
lute run scripts/verify.luau
```

Use `stylua src tests scripts` to apply formatting and `lest run unit` for the fastest test-only loop. The verifier checks prepared dependencies without modifying `Packages/`, generates the real Rojo sourcemap, checks formatting and lint, analyzes strict Luau with pinned Roblox API definitions, runs unit tests, and performs a disposable place build. Missing or stale preparation fails with the preparation command.

`Packages/`, `sourcemap.json`, `.lest/`, and `.verify/` are generated; never hand-edit them. `tooling/roblox/globalTypes.d.luau` and `roblox.yml` are vendored generated inputs for luau-lsp and Selene respectively; follow `tooling/roblox/README.md` to refresh them rather than editing them.

Fast native tests belong under `tests/unit/**/*.spec.luau`. If a test truly depends on the Roblox DataModel, add a separate non-default Lest Studio suite instead of weakening native isolation. Runtime changes involving replication, remotes, lifecycle order, UI/input/camera, physics, or other engine behavior also require a Roblox Studio MCP playtest after the static gate. Inspect the Studio console, stop only play sessions started by this task, preserve an existing user session, and report any visual or interactive behavior that could not be verified automatically. Follow [`docs/verification.md`](docs/verification.md) for focused-stage reporting and the Studio playtest sequence.

Before implementation, derive verification from the intended behavior, including relevant failure and cancellation cases. Change test expectations only when the intended contract changes or the expectation is demonstrably wrong; preserve useful failure diagnostics. Follow [behavior verification](docs/verification.md#behavior-verification) for coverage and evidence requirements.

Before completion, run the canonical verifier, inspect the final diff, and report any validation that the environment prevented.

<!-- roblox-resource-acquisition:onboarding:start -->
## Roblox resources

Use the project-standard resources below when their listed roles apply. If a resource choice conflicts with other governing project guidance, surface the conflict before changing either direction.

- **ActualFire-Games Module Loader** — Canonical SSA lifecycle discovery and startup. Structural selection is governed by `.agents/roblox/structure.md`.
- **Janitor** — Project-standard lifecycle cleanup and resource ownership for client, server, and shared feature modules.
- **LemonSignal** — Project-standard in-process typed signals and event dispatch for client, server, and shared feature modules.
- **Blink** — Project-standard typed, generated client/server networking and remote protocol definitions.
- **Scribe** — Project-standard persistent, typed, automatically replicated player data and server-authoritative data workflows.
- **Charm** — Project-standard domain and shared application state.
- **Fusion 0.3** — Project-standard UI rendering, UI-local presentation state, springs, and tweens.
- **UI Labs** — Project-standard isolated visual development and component stories.
<!-- roblox-resource-acquisition:onboarding:end -->
