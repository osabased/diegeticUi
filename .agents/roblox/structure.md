# Roblox Structure Profile

## Freshness

Treat a persisted convention as stale only when following it produces a verified mismatch and focused inspection, using the applicable source-of-truth representation, establishes a different coherent implemented convention at the same scope. A local exception, unresolved mapping, or ambiguous/pre-existing change is not enough. During authorized implementation, repair only the smallest unsupported persisted decision and preserve still-supported guidance; otherwise leave the profile unchanged and report the mismatch.

## Source of truth

Rojo 7.7.0 maps the filesystem into the DataModel. Wally 0.3.2 restores packages declared in `wally.toml`; do not hand-edit `Packages/`.

## Entrypoints

`ReplicatedStorage.ClientMain` is a `Script` with `RunContext = Client`, and `ServerScriptService.ServerMain` is a `Script` with `RunContext = Server`. Each entrypoint directly requires `ReplicatedStorage.Packages.ModuleLoader` and calls `ModuleLoader.Start(...)` on its canonical runtime root.

## Module organization

Use canonical Single Script Architecture with feature-first `Server/<Feature>` and `Client/<Feature>` lifecycle roots. Put client-visible shared dependencies under `Shared/<Feature>` and structurally defined communication instances under `Remotes/<Feature>`. Helpers belong beneath their owning lifecycle root, outside the loader's direct-child discovery slot.

## Module style

Direct-child ModuleScripts under `Server` and `Client` return a feature API with optional `Init` and `Start` lifecycle methods. Top-level execution defines the API and acquires dependencies without activation or permanent yielding. `Init` prepares feature-local state; `Start` activates behavior and returns after activation.

## Structural dependencies

Canonical SSA uses `ActualFire-Games/module-loader`, acquired through Wally as `crusherfire/module-loader@3.0.4`, pinned to upstream commit `b427a3e03fe9368a26e344b5e37f7466fe2ca878`, and mapped through the Wally alias at `ReplicatedStorage/Packages/ModuleLoader`. Its identity, pin, acquisition form, placement, and upgrade or replacement decision are governed by the canonical SSA structure contract.

## Notes

Keep the loader-wide baseline at `FolderSearchDepth = 1` and `ClientWaitForServer = false`, with ordinary serial discovery and no CollectionService, relocation, custom predicate, or custom start. Feature protocols own cross-runtime readiness.
