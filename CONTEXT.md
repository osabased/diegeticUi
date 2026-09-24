# Inventory Domain

The inventory domain describes spatial item ownership and movement without prescribing presentation or interaction details.

## Language

**Inventory**:
A uniquely identified collection of item instances arranged within a rectangular grid.
_Avoid_: Bag, storage

**Player Inventory**:
The persistent inventory owned by one player.
_Avoid_: Backpack

**Loot Container**:
A server-session inventory shared by players in that server.
_Avoid_: Chest, stash

**World Container**:
A world object through which players can access one Loot Container while that object exists.
_Avoid_: Container ID as authority

**Item Definition**:
The immutable description shared by every instance of an item type, including its footprint and rotation capability.
_Avoid_: Item type, item template

**Item Instance**:
One uniquely identified occurrence of an item definition that can belong to exactly one inventory.
_Avoid_: Item copy

**Placement**:
An item instance's grid position and rotation within an inventory.
_Avoid_: Slot

**Reposition**:
An atomic change to an item instance's placement within the same inventory.
_Avoid_: Move

**Transfer**:
An atomic change of an item instance's ownership from one inventory to another.
_Avoid_: Reposition

**Revision**:
A monotonically increasing inventory version identifying the state produced by committed operations.
_Avoid_: Timestamp
