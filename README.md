# diegeticUi

A Roblox project using Rojo and canonical Single Script Architecture (SSA).

## Getting started

Install the pinned CLI toolchain and run the canonical verification gate:

```bash
rokit install
lute run scripts/verify.luau
```

That one command is also used in CI. It restores the locked Wally graph, generates the actual Rojo sourcemap and Wally package types, checks formatting, lints and typechecks strict Luau with Roblox API definitions, runs the native unit suite, and proves that the place builds.

Use the same verifier for focused evidence without claiming the full gate:

```bash
lute run scripts/verify.luau --stage format
lute run scripts/verify.luau --stage lint --stage analyze
lute run scripts/verify.luau --stage unit
lute run scripts/verify.luau --stage build
lute run scripts/verify.luau --stage studio
```

Repeated `--stage` flags are deduplicated and run in canonical order with their required preparation. Every started run writes an ignored JSON report under `.verify/reports/`; only the no-argument command can print `[verify] PASS`. See [`docs/verification.md`](docs/verification.md) for stage dependencies, report semantics, Studio setup, and the required UI interaction playtest.

Verifier builds are disposable. Create the persistent development place before opening it in Roblox Studio:

```bash
rojo build default.project.json --output diegeticUi.rbxlx
```

Then start the Rojo server for live development:

```bash
rojo serve
```

For more help, check out [the Rojo documentation](https://rojo.space/docs).

Generated artifacts are intentionally untracked: `Packages/`, `sourcemap.json`, `.lest/`, and `.verify/`. Standalone analysis uses the vendored Roblox definitions described in [`tooling/roblox/README.md`](tooling/roblox/README.md), so verification does not depend on editor caches or machine-local Studio state.

## Networking

Blink owns new project-authored client/server protocols. Define them in `src/shared/Network/main.blink`, then regenerate the committed Luau modules with:

```sh
lute run scripts/generate-blink.luau
```

The wrapper runs `blink compile --profile release src/shared/Network/main.blink` and updates the committed integrity stamp. Server features require `Shared.Network.Server`; client features require `Shared.Network.Client`. Do not edit the generated `Client.luau`, `Server.luau`, `Types.luau`, or stamp by hand. The canonical verifier checks their integrity and performs a restored compile smoke test.

## UI development

Charm owns domain and shared application state. Fusion 0.3 owns UI rendering and local presentation state, including springs and tweens. UI Labs owns isolated component stories.

Install the [UI Labs Studio plugin](https://create.roblox.com/store/asset/14293316215/UI-Labs), run `rojo serve`, and open the `UI` storybook to preview the Button component states. Wally installs the matching UI Labs utility package with the rest of the project dependencies.

## Project structure

- `src/server/` contains server lifecycle-root ModuleScripts.
- `src/client/` contains client lifecycle-root ModuleScripts.
- `src/shared/` contains dependencies used by both runtimes; these are not loaded automatically.
- `src/ServerMain.server.luau` and `src/ClientMain.client.luau` are minimal SSA bootstraps.

Each direct-child ModuleScript under `Server` or `Client` is a feature lifecycle root. A root may return a table with optional `Init` and `Start` methods. Put helper modules below their owning feature root so the loader does not discover them as separate features.
