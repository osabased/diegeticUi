# diegeticUi

A Roblox project using Rojo and canonical Single Script Architecture (SSA).

## Getting Started

Install the pinned Wally dependencies:

```bash
wally install
```

To build the place from scratch, use:

```bash
rojo build -o "diegeticUi.rbxlx"
```

Next, open `diegeticUi.rbxlx` in Roblox Studio and start the Rojo server:

```bash
rojo serve
```

For more help, check out [the Rojo documentation](https://rojo.space/docs).

## Project structure

- `src/server/` contains server lifecycle-root ModuleScripts.
- `src/client/` contains client lifecycle-root ModuleScripts.
- `src/shared/` contains dependencies used by both runtimes; these are not loaded automatically.
- `src/ServerMain.server.luau` and `src/ClientMain.client.luau` are minimal SSA bootstraps.

Each direct-child ModuleScript under `Server` or `Client` is a feature lifecycle root. A root may return a table with optional `Init` and `Start` methods. Put helper modules below their owning feature root so the loader does not discover them as separate features.
