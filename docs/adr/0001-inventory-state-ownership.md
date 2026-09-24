# Keep durable ownership in player profiles

The shared Scribe bundle is the persistence boundary for player inventory data. The server validates loaded snapshots and commits player-only mutations in one Scribe transaction. An item must retain one authoritative owner, and a transfer must not lose a durable player item on shutdown. The session-container transfer direction and commit boundary are decided in [ADR 0002](0002-session-container-transfer-commit.md).
