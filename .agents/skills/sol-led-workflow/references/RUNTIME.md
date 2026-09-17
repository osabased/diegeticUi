# Runtime and routing contract

Read before the first dispatch in a session, after configuration changes, or when a dispatch disagrees with expectations. Use current tool schemas and authoritative runtime metadata. Documentation and configuration express intent; they do not prove what a running child used.

## Eligibility

The following user allowlist is exhaustive. The pilot narrows responsibilities without expanding this allowlist. Changes require explicit user approval. Existing stricter project or organization restrictions still apply; surface conflicts rather than overriding them.

| Model | Allowed effort | Responsibility |
|---|---|---|
| GPT-6 Astra | Any level supported by the actual model | Direction, roadmaps, specifications, orchestration, oversight; this pilot reserves it for consequential solutions and framing |
| GPT-5.6 Sol | medium, high, xhigh | Execution planning, management, implementation |
| GPT-5.6 Sol | max | Implementation only |
| GPT-5.6 Luna | max | Bounded worker tasks |

Terra, Sol low, and every other unlisted configuration are ineligible. Availability or cost uncertainty does not create an exception. Select among eligible configurations or return the blocker. Compare model and effort jointly, including coordination, verification, and rework. Do not infer a cost ranking from model names.

The root may create any eligible child. Under the user's general policy, non-root agents may spawn only models confirmed strictly cheaper than themselves and otherwise request a sibling through the root. This pilot is narrower: every packaged child is a leaf and returns escalation requests to the root. Sol max never becomes a coordinator or reviewer.

## Installed roles

Choose root effort from the allowed coordinating settings for the task; medium is a provisional trial starting point, not a universal optimum. The root is selected in the client, not created as another packaged manager.

Read the actual role files when a setting matters; they are the source of truth for packaged defaults. Each pins model and effort, and disables its own agent spawning. `slw_sol_analysis` is a reusable read-only analysis/synthesis leaf for bounded delegated analytical work. `slw_sol_review` remains the dedicated formal review leaf; neither role is a mandatory consolidation layer, and neither can replace an incompatible required role. Custom-agent settings can take precedence over explicit spawn settings. A different eligible effort requires an actually supported alternate configuration, not a conflicting request to the same pinned role. Do not edit installed policy/configuration during task execution to bypass a restriction.

The model identifiers shipped here come from the user's observed Codex rollout names. Resolve an identifier or alias against the installed model catalog before use. A public API alias is not proof of equivalence in this Codex client. Unresolved aliases, unavailable efforts, and hidden effective settings must be labeled unverified; never silently substitute another model.

## Dispatch

1. Check the exposed collaboration tool, available role, eligible model/effort, scope, and context policy. Reuse known runtime evidence when applicable.
2. Immediately before each spawn, declare the assignment, role, requested model, and effort in one sentence. For parallel work, declare each distinct assignment.
3. Select the role explicitly and set both model and effort to its verified effective defaults when the exposed tool supports these fields. Do not rely on inheriting settings from a different model. Keep application permissions intact.
4. Disable history copying explicitly. In the inspected legacy schema, use `fork_context: false`. In the inspected MultiAgentV2 schema, use `fork_turns: "none"`; omitting it defaults to all history and the legacy field is rejected. Use only the branch supported by the live tool schema. Never send both fields. For another schema, require its documented equivalent.
5. Verify effective model/effort and history mode from exposed runtime metadata or the actual child/session record when available. A child's claim about its own identity or its inability to recall a phrase is not verification. Check the first real dispatch rather than buying a separate Astra smoke test. Stop a mismatched child when possible; preserve useful results as potentially affected evidence, and reroute only after resolving the mismatch. Already-used allowance cannot be undone.

An isolated conversation can still include normal system/developer instructions, project AGENTS.md, skill metadata, and configured memory. It is not an empty system prompt. Audit unexpectedly large input rather than claiming the entire input equals the packet.

Read-only settings on evidence, decision, analysis, and review roles are defense in depth. Live parent permission overrides can supersede defaults. Their role contracts still prohibit source edits and connector mutations; never relax security controls to make this workflow run. Builds/tests that require writes belong to the authorized Sol executor unless a suitable disposable environment already exists.

## Unsupported or unverified runtime

When native dispatch or context isolation cannot be established, perform supported work directly on an eligible Sol root only where this preserves the caller's requirements. Optional delegation may stay local. Work that requires another agent, independent context, or a specialist role uses the cross-thread contract in HANDOFFS.md when its semantics can be preserved; otherwise return the specific capability blocker. Do not substitute a full-history fork or an API/CLI subprocess.

The generic fallback is a new, non-forked local Codex app thread with the necessary project/source access, the appropriate eligible model/effort, and only the assignment packet plus role constraints. Astra handoffs remain read-only solution/framing consultations. Sol analysis/review handoffs remain read-only and preserve required independence; implementation handoffs preserve their explicit write boundary. The user performs the thread switch when no authorized native tool supports it. State the required action rather than claiming it happened.

If effective settings remain unverified after the first dispatch, report the limitation and pause further automatic dispatches until runtime evidence or user confirmation of the visible configuration resolves it. Do not repeatedly launch workers to discover their settings. Unsupported parallelism permits direct Sol work only where it satisfies the active workflow. Mandatory independent review or delegation remains unmet when neither native dispatch nor a semantics-preserving fresh-thread route is compatible; return that blocker. Neither runtime limits nor workflow requirements permit expanding the allowlist.
