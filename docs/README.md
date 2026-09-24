# Project Documentation

## Active documentation

- [Inventory domain language](../CONTEXT.md) — canonical vocabulary for inventory ownership, placement, and movement.
- [Inventory state ownership](adr/0001-inventory-state-ownership.md) — persistence and integration-seam decision record.
- [Session container transfer commit](adr/0002-session-container-transfer-commit.md) — permitted transfer direction and the two-owner commit boundary.
- [World container access](adr/0003-world-container-access.md) — world binding, eligibility, removal, and scoped snapshot delivery.
- [Verification](verification.md) — dependency preparation, verification stages and reports, behavior evidence, and Studio workflows.
- [Roblox tooling](../tooling/roblox/README.md) — provenance and refresh procedures for vendored Roblox analysis inputs.

Agent-specific routing begins at the [agent documentation index](../.agents/docs/README.md). Durable Roblox placement and lifecycle conventions live in the [structure profile](../.agents/roblox/structure.md).

## Maintenance policy

The project and agent indexes define the active documentation set. Keep changing facts such as versions, dependency inventories, schemas, directory contents, and feature behavior authoritative in code, configuration, and tests. Documentation should preserve rationale, ownership boundaries, exceptional procedures, and non-obvious failure modes that cannot be recovered cheaply from those sources.

Remove known-stale documentation and its incoming links from the working tree; Git is the archive. Reconstruct a replacement from current authoritative sources rather than incrementally patching untrusted prose. Add the replacement to an index only after its claims have been checked.

The documentation regression validates local links and index coverage mechanically. It cannot prove that prose is semantically current, so minimize duplicated facts and encode enforceable claims in tests or configuration.
