<!-- structure-roblox-projects:onboarding:start -->
## Roblox structure onboarding

Before making a structural placement, startup, source-of-truth, organization, or structurally owned dependency decision, read `.agents/roblox/structure.md` for the project's durable structural conventions.
<!-- structure-roblox-projects:onboarding:end -->

## Development workflow

The filesystem is authoritative. Rojo projects `src/` into Studio; do not make lasting source edits in the Studio DataModel. Keep runtime boundaries explicit:

All project-authored Luau uses `--!strict`. Keep types precise, prefer `unknown` over `any`, and use type casts deliberately.

- `src/server/` owns server-authoritative feature roots.
- `src/client/` owns client-only feature roots and presentation.
- `src/shared/` contains runtime-neutral modules that are required explicitly.
- Each direct-child ModuleScript under `Server` or `Client` is an SSA lifecycle root. Put implementation modules beneath the root that owns them.
- New project-authored client/server protocols use Blink-generated networking. Libraries that own their transport, such as Scribe, keep that boundary; LemonSignal is only for in-process events.

Install the pinned toolchain with `rokit install`. The single required local and CI gate is:

```sh
lute run scripts/verify.luau
```

Use `stylua src tests scripts` to apply formatting and `lest run unit` for the fastest test-only loop. The verifier installs the locked Wally graph, generates the real Rojo sourcemap and package types, checks formatting and lint, analyzes strict Luau with pinned Roblox API definitions, runs unit tests, and performs a disposable place build.

`Packages/`, `sourcemap.json`, `.lest/`, and `.verify/` are generated; never hand-edit them. `tooling/roblox/globalTypes.d.luau` and `roblox.yml` are vendored generated inputs for luau-lsp and Selene respectively; follow `tooling/roblox/README.md` to refresh them rather than editing them.

Fast native tests belong under `tests/unit/**/*.spec.luau`. If a test truly depends on the Roblox DataModel, add a separate non-default Lest Studio suite instead of weakening native isolation. Runtime changes involving replication, remotes, lifecycle order, UI/input/camera, physics, or other engine behavior also require a Roblox Studio MCP playtest after the static gate. Inspect the Studio console, stop the play session when finished, and report any visual or interactive behavior that could not be verified automatically.

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
