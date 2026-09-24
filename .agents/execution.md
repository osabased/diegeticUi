# Execution

<!--
Copy this scaffold to ../execution.md when initializing the active move or replacing a finished one. The live file, not this template, is authoritative.
For active or blocked work, use the next M### after the last completed milestone in ../progress.md. Status describes only whether work can proceed. After a finished move, leave this scaffold unfilled when selecting the next move would be speculative. Use blocked only for a concrete condition that prevents further in-scope work, with a clear owner and unblock condition.
For discovery, name the question and the evidence that would answer it. Before delivery work, name its observable result and relevant verification. Use Outcome Context, Questions, Completion Checks, or Verification only where they clarify this move. Revise the live file as evidence changes the move. Hotspots are current investigation entry points, not file assignments.
-->

## Milestone

M021

## Status

active

## Objective

Determine whether Scribe's ordinary player-leave path saves an accepted inventory mutation and restores the same validated snapshot on a later session in the isolated mock store, without an explicit flush.

## Outcome Context

- `V7` — Durable player inventory through leaving and rejoining. [M020](progress/M020-inventory-mock-persistence-round-trip.md) proved a mock-store round trip only after an explicit flush; it did not establish leave-triggered saving or live DataStore durability.

## Questions

- Does the pinned Scribe 2.3.0 player-removal path finish saving the accepted snapshot before a new session opens in mock mode?
- Does production readiness recover the exact accepted revision, item identities, definitions, positions, and rotations without an explicit flush?
- If the mock path cannot establish this behavior, which lifecycle boundary or observable result prevents a reliable conclusion?

## Hotspots

- `tests/studio/InventoryPersistenceRoundTrip.spec.luau` — existing explicit-flush round trip and isolated Scribe server test seam.
- `src/shared/Inventory/PlayerDataSchema.luau` — mock bundle construction and transport options.
- `src/server/Inventory/Mutation.luau` — accepted mutation path.
- `src/server/Inventory/Readiness.luau` — validated reload path.

## Completion Checks

- A guarded Studio test or probe exercises an accepted production mutation, normal player removal, and a later mock session without calling `Flush`; it compares the restored snapshot with the accepted snapshot or records the exact reason the behavior cannot be established.
- Record the result and its limits in M021. Keep live DataStore durability, autosave timing, and shutdown behavior open unless separately observed.

<!--
When Status is blocked, append this section:

## Blocking Condition

- Cause: [What prevents progress]
- Owner: [Person, system, or decision that can remove the block]
- Unblock when: [Observable condition that permits work to resume]
-->
