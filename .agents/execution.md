# Execution

## Status

active

## Objective

Deliver a pure deterministic grid-domain engine that can validate and apply placement, removal, repositioning, rotation, and first-fit operations without Roblox services or partial mutation.

## Priority Outcomes

- Variable item footprints resolve to exact occupied cells, including rotated dimensions.
- Bounds and overlap validation return stable success or error results for identical inputs.
- Failed operations preserve the complete prior inventory state; successful operations advance revision exactly once.
- First-fit search is deterministic and follows one documented traversal order.
- Focused tests cover edges, corners, collisions, rotation, rollback, revision behavior, and first-fit determinism.

## Hotspots

- `src/shared/Inventory/Types.luau` — Defines the existing inventory, placement, snapshot, and operation contracts.
- `src/shared/Inventory/Definitions.luau` — Supplies immutable footprints and rotation capabilities without coupling definitions to grid logic.
- `CONTEXT.md` — Owns canonical inventory language and the distinction between repositioning and transfer.
- `docs/adr/0001-inventory-state-ownership.md` — Records atomicity, ownership, persistence, and future integration seams.
- `tests/unit/` — Hosts the fast deterministic behavior coverage that should drive the grid engine.
