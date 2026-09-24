# Visions

This records the project's intended product outcomes, not an implementation plan or a sequence of mandatory tasks. Keep only product intent confirmed by user direction when revising the catalog; a prior agent's entry alone is not proof of confirmation. Treat an outcome with unclear provenance as a hypothesis until it matters to a current decision, and do not silently remove it. A move becomes current scope only when selected in [execution.md](execution.md). Record evidence and completion decisions in [progress.md](progress.md); revise desired outcomes when evidence or user priorities change.

## Outcomes

### V1 — Trustworthy spatial inventory

Players can arrange distinct, variable-sized items in rectangular inventories without overlap, out-of-bounds placement, or item loss.

### V2 — Direct item manipulation

Players can reposition and rotate compatible items and understand whether an attempted change succeeded.

### V3 — Shared looting

Players can inspect a world container alongside their inventory and transfer items without ambiguous or duplicate ownership.

### V4 — Quick transfer

Players can request an automatic transfer and receive the same valid placement for the same authoritative state, or a clear failure without losing an item.

### V5 — Server authority

The server validates state-changing inventory requests and owns authoritative inventory state.

### V6 — Configurable items

Developers can add definitions and distinct instances without changing grid rules.

### V7 — Durable player inventory

Accepted player inventory state survives leaving, rejoining, autosaves, and practical shutdown paths.

### V8 — Portfolio-ready experience

A viewer can understand placement, rejected drops, rotation, looting, quick transfer, and persistence through a short, ordinary play session.

## Boundaries

- **Integrity** — An item has one authoritative owner; committed operations are atomic; rejected operations preserve accepted state; presentation never grants authority.
- **Delivery** — Prefer a polished, demonstrable v1 over breadth. Reassess which outcomes remain desired as play and implementation evidence accumulate.
- **Out of scope** — Crafting, vendors, trading, a full economy, procedural loot generation, progression, complex equipment, combat, survival systems, and extra inventory variants added only for breadth unless the user explicitly changes direction.
