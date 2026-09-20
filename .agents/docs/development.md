# Development Workflow

## Source and code standards

The filesystem is authoritative. Rojo projects `src/` into Studio; make lasting source changes in the filesystem, not the Studio DataModel. Follow the [Roblox structure profile](../roblox/structure.md) for runtime ownership, placement, startup, and lifecycle decisions.

All project-authored Luau uses `--!strict`. Keep types precise, prefer `unknown` over `any`, and use type casts deliberately. New project-authored client/server protocols use Blink-generated networking. Libraries that own their transport, such as Scribe, keep that boundary; LemonSignal is for in-process events.

## Dependencies and generated inputs

Install Python 3.10 or newer as `python`, then install the pinned toolchain with `rokit install`; CI uses Python 3.12. Before any package installation, including direct `wally install`, stop the Rojo server serving this checkout. Follow [dependency preparation and updates](../../docs/verification.md#dependency-preparation-and-updates) for initial setup, stale preparation, or intentional dependency changes. Resume a previously running Rojo server only after preparation succeeds.

`Packages/`, `sourcemap.json`, `.lest/`, and `.verify/` are generated; never hand-edit them. `tooling/roblox/globalTypes.d.luau` and `roblox.yml` are vendored generated inputs; follow the [Roblox tooling guide](../../tooling/roblox/README.md) to refresh them.

## Verification

Before implementation, derive verification from the intended behavior, including relevant failure and cancellation cases. Change test expectations only when the intended contract changes or an expectation is demonstrably wrong; preserve useful failure diagnostics. Follow [behavior verification](../../docs/verification.md#behavior-verification) for coverage and evidence requirements.

The single required local and CI gate is:

```sh
lute run scripts/verify.luau
```

Use `stylua src tests scripts` to apply formatting and `lest run unit` for the fastest test-only loop. Fast native tests belong under `tests/unit/**/*.spec.luau`. A test that truly depends on the Roblox DataModel belongs in a separate non-default Lest Studio suite run through `lute run scripts/verify.luau --stage studio`; direct `lest run studio` bypasses the outer diagnostic guard.

Runtime changes involving replication, remotes, lifecycle order, UI/input/camera, physics, or other engine behavior also require a Roblox Studio MCP playtest after the static gate. Follow the [Studio playtest sequence](../../docs/verification.md#studio-behavior-playtest), preserve any existing user session, and stop only play sessions started by the current task.

Before completion, run the canonical verifier, inspect the final diff, and report any validation that the environment prevented.

