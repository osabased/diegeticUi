# diegeticUi

A Roblox project using Rojo and canonical Single Script Architecture (SSA).

## Getting started

Install the pinned CLI toolchain and run the canonical verification gate:

```bash
rokit install
lute run scripts/verify.luau
```

That one command is also used in CI. It restores the locked Wally graph, generates the actual Rojo sourcemap and Wally package types, checks formatting, lints and typechecks strict Luau with Roblox API definitions, runs the native unit suite, and proves that the place builds.

Useful focused commands are:

```bash
stylua src tests scripts
lest run unit
rojo build default.project.json --output diegeticUi.rbxlx
```

Open the built place in Roblox Studio and start the Rojo server for live development:

```bash
rojo serve
```

For more help, check out [the Rojo documentation](https://rojo.space/docs).

Generated artifacts are intentionally untracked: `Packages/`, `sourcemap.json`, `.lest/`, and `.verify/`. Standalone analysis uses the vendored Roblox definitions described in [`tooling/roblox/README.md`](tooling/roblox/README.md), so verification does not depend on editor caches or machine-local Studio state.

## Project structure

- `src/server/` contains server lifecycle-root ModuleScripts.
- `src/client/` contains client lifecycle-root ModuleScripts.
- `src/shared/` contains dependencies used by both runtimes; these are not loaded automatically.
- `src/ServerMain.server.luau` and `src/ClientMain.client.luau` are minimal SSA bootstraps.

Each direct-child ModuleScript under `Server` or `Client` is a feature lifecycle root. A root may return a table with optional `Init` and `Start` methods. Put helper modules below their owning feature root so the loader does not discover them as separate features.
