<!-- structure-roblox-projects:onboarding:start -->
## Roblox structure onboarding

Before making a structural placement, startup, source-of-truth, organization, or structurally owned dependency decision, read the [Roblox structure profile](.agents/roblox/structure.md) for the project's durable structural conventions.
<!-- structure-roblox-projects:onboarding:end -->

## Address issues at their source

Don't be compliant towards issues. Needing a workaround is evidence of a defect. Investigate why the intended path fails, capture expected versus observed behavior, and pursue a durable correction. A workaround may unblock the task, but it does not resolve the underlying issue.

Fix defects within the task's authorized scope and use the owning repair workflow when one exists. If an issue makes dependent work or verification unreliable, stop that work until the issue is reconciled. Otherwise, continue with a safe, reversible workaround while making the defect explicit. When the durable correction is outside scope, report the evidence and proposed fix before completion.

## Development workflow

Development: Before changing source, dependencies, generated artifacts, verification, tests, or runtime behavior, read the [development workflow](.agents/docs/development.md).

Documentation: Use the [agent documentation index](.agents/docs/README.md) for task-specific guidance and the [project documentation index](docs/README.md) for active project documentation and its maintenance policy.

Continuity: When asked to create or refresh long-running project handoff documents, use the [visions template](.agents/templates/visions.md) for durable outcome targets and the [execution template](.agents/templates/execution.md) for current work and entry points.

<!-- roblox-resource-acquisition:onboarding:start -->
## Roblox resources

Use the project-standard resources below when their listed roles apply. If a resource choice conflicts with other governing project guidance, surface the conflict before changing either direction.

- **ActualFire-Games Module Loader** — Canonical SSA lifecycle discovery and startup. Structural selection is governed by `.agents/roblox/structure.md`.
- **Janitor** — Project-standard lifecycle cleanup and resource ownership for client, server, and shared feature modules.
- **LemonSignal** — Project-standard in-process typed signals and event dispatch for client, server, and shared feature modules.
- **Blink** — Project-standard typed, generated client/server networking and remote protocol definitions.
- **Scribe** — Project-standard persistent, typed, automatically replicated player data and server-authoritative data workflows.
- **Charm** — Project-standard domain and shared application state.
- **Fusion 0.3** — Project-standard UI rendering, UI-local presentation state, springs, and tweens. Use `$roblox-fusion` for implementation guidance.
- **UI Labs** — Project-standard isolated visual development and component stories.
<!-- roblox-resource-acquisition:onboarding:end -->
