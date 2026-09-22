# Visions

## Outcomes

- **Trustworthy spatial inventory** — Players can arrange uniquely identified, variable-sized items in rectangular inventories, producing deterministic placements with no overlap or out-of-bounds occupancy. Complete when every accepted state satisfies those invariants and every rejected operation preserves the prior state.
- **Direct item manipulation** — Players can reposition and rotate compatible items with clear valid and invalid outcomes. Complete when successful actions commit exactly once and failed actions restore the last valid state without item loss or duplication.
- **Shared looting** — Players can inspect a world container alongside their own inventory and transfer items between them under the same placement rules. Complete when ownership remains singular and concurrent attempts cannot corrupt either inventory.
- **Quick transfer** — Players can request an automatic transfer into an open inventory, producing the same deterministic destination for the same state. Complete when a valid destination is selected without overlap and failure leaves both inventories unchanged.
- **Server authority** — The server controls inventory ownership and validates every placement, rotation, and transfer request. Complete when a modified client cannot create items, duplicate them, force invalid placement, or mutate another player's inventory.
- **Configurable items** — Developers can add item definitions and create distinct instances without changing grid logic. Complete when definitions express footprint, rotation capability, and optional presentation metadata while instances retain independent identity and extension space.
- **Durable player inventory** — A player's inventory survives leaving, rejoining, autosaves, and practical shutdown paths. Complete when versioned data restores item identity, definition, placement, and rotation, and failed loads or saves preserve a safe authoritative state.
- **Portfolio-ready experience** — A viewer can immediately understand placement, invalid drops, rotation, looting, quick transfer, and persistence from short demonstrations. Complete when each behavior is reliable, visually legible, and recordable without debug-only setup.

## Boundaries

- **In scope** — One reusable rectangular-grid model for player inventories and shared loot containers, server-authoritative operations, persistent player state, responsive presentation, and focused portfolio demonstrations.
- **Integrity boundary** — Every item has exactly one owner, every committed operation is atomic, and client prediction or presentation never becomes authoritative state.
- **Delivery boundary** — Favor a polished, demonstrable v1 and stop expanding once the confirmed outcomes are reliable and presentable.
- **Out of scope** — Crafting, vendors, trading, a full economy, procedural loot generation, progression, complex equipment, combat, survival systems, and extra inventory variants added only for breadth.
- **Dependency boundary** — Add framework surface only when it owns a concrete lifecycle, event flow, protocol, state concern, or verification need.
