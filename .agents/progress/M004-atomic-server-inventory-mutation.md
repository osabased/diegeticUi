# M004 — Atomic server inventory mutation

- Completed: 2026-09-22
- Result: Server reposition and rotation use the M003 readiness gate, then validate and compare the latest loaded revision inside a non-yielding Scribe transaction. Accepted changes write one whole snapshot and return a separate copy; stale, invalid, malformed, unavailable, and rolled-back changes return failures without advancing accepted state.
- Verification: The canonical verifier passed after implementation. The Studio suite passed 17 tests, including mutation success, stale revision after readiness, invalid placement and loaded data, revision overflow, ended session, rollback, and returned-snapshot isolation. A connected Studio server probe with a disposable Scribe mock profile observed revisions 4→5→6, rejected a stale request, and read the committed placement and rotation. The task-owned play session was stopped. Mock mode did not verify live DataStore durability or client request/replication behavior.
