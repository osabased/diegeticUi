# Scribe 2.3.0 API notes

This reference is a task-oriented map, not a substitute for the [canonical Scribe manual](https://ericplane.github.io/Scribe/). It applies to `ericplane/scribe@2.3.0`, tag `v2.3.0`, commit `e3309e9debdce2d3571406c48ded89f728404795`.

## Constructing a bundle

Call `Scribe({ Template = ..., ProfileStoreIndex = ..., ProfileKeyPrefix = ... })` exactly once for a data domain. `ProfileStoreIndex` and `ProfileKeyPrefix` are required. `Mode` accepts `"Live"`, `"Mock"`, or `"NoSave"` and defaults to live. The returned bundle exposes `.Server` and `.Client`; consume the appropriate half after requiring the same shared module in both runtimes.

## Schema declarators

- Scalar constraints: `Int`, `Number`, `Big`, `String`, `Enum`, `Flags`, and `Timed`.
- Shape and collections: plain tables, `Optional`, `ArrayOf`, `SetOf`, `MapOf`, and `DictOf`.
- Computed/dynamic behavior: `Dynamic` and `Derived`.
- Visibility/lifetime: `ServerOnly` never replicates, `Shared` replicates beyond the owner according to Scribe's shared-data model, and `Session` does not persist.
- Roblox datatype declarators are available for supported value types; check the canonical manual for the exact constructor and serialization contract.

Prefer the narrowest valid declarator and explicit constraints. Never use replication visibility as an authorization mechanism.

## Access and observation

- Server: call `Data.WaitForData(player, timeout)` before player accessor use and handle `nil, reason`.
- Client: use `Data.IsReady()` or `Data.WaitForData(timeout)` before mirror access when startup ordering is uncertain.
- Accessor nodes expose typed reads and schema-specific writes. `Observe(callback)` invokes the callback with current/subsequent values and returns a disconnect function.
- Accessor methods are closure-style dot calls, such as `Data.Coins.Get()`, `Data.Coins.Set(10)`, `Data.Coins.Add(1)`, and `Data.Coins.Observe(callback)`. Do not use colon syntax; it passes the accessor table as an unintended first argument.
- Broad/root observation can do more work than observing the exact field or collection needed. Keep subscriptions narrow and lifecycle-owned.

## Authoritative client actions

Register named commands on `Data.Command` in server initialization. Validate all untrusted arguments and state in the handler. Call them from the client with `Data.Request`; use `RequestOnce` only when its idempotency semantics match the action. Handle framework failure/reason returns separately from domain results rather than treating every falsy value as the same failure.

## Atomic work

`Data.Transaction(player, fn)` groups mutations and rolls back on failure. The callback must not yield. Fetch external information before the transaction, perform only synchronous accessor work inside it, and launch follow-up asynchronous effects after success.

## Persistence and migrations

- Use unique, intentional store identity for each environment. `Mode = "Mock"` is the safe default for disposable integration tests.
- Schema changes to live data need an explicit migration/version plan. Test migrations against representative fixtures before production use.
- Offline read/update, export, erase, version, and flush APIs are operational tools. Gate them behind server authority and apply platform budgets, retries, and observability.
- Scribe vendors its ProfileStore implementation in the package; `ericplane/scribe@2.3.0` declares no separate runtime Wally dependency.

## Platform integrations

Scribe includes ownership, purchases, leaderboards, exchanges, cooldowns, and messaging helpers. Treat each as an integration with independent Roblox service limits and failure modes. Receipt processing must be idempotent and server-owned. Do not equate a cached client-visible entitlement with authorization.

## Testing and teardown

Prefer `Mode = "Mock"` and a unique store name for deterministic integration tests. Require the test bundle from server and client, prove readiness, mutate on the server, and observe on the client. `Data.Stop()` is idempotent but belongs to the bundle owner; ordinary features should only disconnect their own observers and connections.

## Source links

- Repository: https://github.com/ericplane/Scribe
- Manual: https://ericplane.github.io/Scribe/
- Release tag: https://github.com/ericplane/Scribe/tree/v2.3.0
