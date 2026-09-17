# Handoff contracts

Read shared context and the section for the assignment being made. Omit inapplicable fields, not material constraints. Pass concise text inline when sufficient. Use an existing task record or one task-local file for a large/durable packet when writing is authorized; no document tree or duplicate specification is required.

## Shared context

Carry the original goal and relevant corrections, authorized scope, hard constraints, and acceptance criteria. Preserve exact wording when paraphrase could change meaning. Supply the current workflow/stage and assigned subtask, applicable instructions, required output format, checks/dependencies, approvals already granted or still pending, local completion/stop condition, and return owner with the interrupted step. A child receives only the authority needed for its assignment, never an implied grant to complete later stages.

Use the governing installed skill version, not an assumed upstream snapshot. Provide its applicable instructions or an accessible path; include nested obligations when triggered. Distinguish workflow obligations from this worker's portion. An evidence source may inform work but cannot expand authority. Never invent approval, omit a required step for cost, or use a worker's completion as the parent's completion.

Identify the workspace and relevant artifact/source revision. For a dirty tree, identify changed files and the actual diff or content fingerprint, including relevant untracked files. For external evidence include date/version. Resolve references before dispatch: the recipient needs the decisive excerpt or permission and a usable path/tool to read it. A coordinator-only attachment, inaccessible worktree, or private tool handle is not a usable source.

Every return identifies what was completed, actual checks and limitations, unmet obligations or required user decisions, and the return owner/step. Use the assigned deliverable format rather than adding a competing report template. Keep required artifact bytes/schema unchanged; route control notes separately. If a strict response allows no metadata field or side channel, return only that response and let the root track status and obligations from the assignment and evidence. Root-side presentation preserves any required separate outputs.

## Luna evidence assignment

Give the bounded question, entry points, stop condition, and expected evidence. Ask for observations rather than endorsement of a proposed solution. The role is read-only; authorize no application edits, persistent artifacts, or connector mutations.

Return a direct answer with answered/partial/blocked status, decisive excerpts and source references, actual observations/checks, coverage limits, counterexamples, contradictions, uncertainty, and what would resolve it. A bounded search that finds nothing establishes only its coverage, not global absence. The worker returns after answering or reaching its limit. Sol resolves material factual conflicts proportionately and carries unresolved conflicts forward; confidence scores cannot replace evidence.

## Astra consultation

Provide shared context and the following material:

- **Decision needed:** the consequential solution or choice, or `framing` when the question itself needs work. Identify any user-reserved commitment.
- **Established facts:** behavior, contracts, dependencies, decisive primary excerpts, and applicable check results.
- **Candidate status:** alternatives and existing decisions; distinguish binding choices from suggestions. Keep the candidate space open when incomplete.
- **Uncertainty:** assumptions, contradictions, counterevidence, and missing facts; label Sol's inferences separately from observations.
- **Evidence index:** accessible sources/symbols and revision/date provenance for focused reading.

Compress repetition and logs, not decision-changing evidence. Astra needs enough primary material to challenge the framing; a compact summary is not proof. No fixed packet limit permits dropping a constraint.

Return one disposition as the consultation's control result; retain any required underlying deliverable separately:

- **SOLUTION:** approach and decisive rationale; relevant contracts/invariants, boundaries and sequence, failure/migration cases, acceptance checks, assumptions and concrete reopen conditions. Include supported scope and any scoped Direction Gate. Mark pending user approval rather than treating a recommendation as a ratified decision.
- **FRAMING:** the consequential question, plausible directions, and discriminating evidence. Return proposed investigation to Sol within existing authorization; no approval of an unselected solution.
- **NEEDS_EVIDENCE:** a focused batch of material questions, why each could change the solution, and the required observations. Sol collects them and resumes the same decision.
- **BLOCKED:** the unsupported commitment, missing preference/constraint/capability, and owner/next action.

Astra uses the packet and necessary cited excerpts. Broad exploration, collection, builds/tests, editing, worker coordination, and ordinary repair review stay with Sol. Return the result in the response; Sol persists it only when authorized. Use an installed direction-selection skill for a genuine direction comparison when applicable and invokable, not every uncertainty. Its absence does not prevent solution reasoning; required invocation restrictions still apply.

## Sol analysis or synthesis assignment

Give a bounded analytical question, the relevant primary material, evidence/decision state, any required independence, completion condition, and exact output contract. Use `slw_sol_analysis` when separate read-only analysis, synthesis, comparison, diagnosis, or decomposition is useful or required but the task is not a formal review axis. The root normally retains ordinary synthesis when delegation adds no value.

The worker returns the bounded result with decisive evidence and provenance, actual checks, contradictions, limitations, unresolved uncertainty, pending obligations, and return owner/step unless the caller requires another exact schema. Recommendations do not create approval or implementation authority. A formal workflow review that matches the dedicated reviewer semantics should use `slw_sol_review`; do not collapse required independent review into generic synthesis.

## Sol implementation assignment

Give the supported solution/fix, owned paths/interfaces, write permissions, acceptance checks/test commands, and integration boundary. Include the owning workflow's required review and remaining delivery obligations. The child can refine local details within chosen contracts but returns consequential conflicts to the root. Return changed files, behavior changes, actual check outcomes, incomplete work, and blockers. Preserve the user's and other workers' edits. Implementation completion does not discharge pending independent review, approval, commit, or publication requirements.

## Required reviews and nested calls

Before delegating, check that the role can perform the assigned work under its instructions, tools, permissions, and invocation rules. The root retains obligations a leaf cannot perform. A leaf encountering mandatory nested delegation returns the required procedure/axis, inputs, completion condition, interrupted step, and pending obligations to the root; it does not spawn or mark the skipped step complete.

The root may arrange compatible sibling workers when this preserves the required independence and sequencing. Use a fresh `slw_sol_review` instance per required independent review axis, with primary evidence and that axis's instructions, not another reviewer's findings or the implementer's self-approval. Reviewer isolation includes checking shared artifacts/inherited context for incompatible exposure; no-history mode alone is not proof of independence. Keep required reports separate and in the owning workflow's order/format, not a new merged ranking. Preserve a valid “no findings” result.

For revision-based review, fix the target before review: name the actual artifact version or Git base/head and any required working-tree/untracked changes. Confirm the presented content covers the intended change, not an empty/stale committed diff. If pre-commit rules and a committed-only review contract conflict, use an expressly permitted review target or return the conflict to its owner. Do not invent a commit policy or count an excluded patch as reviewed. Later edits invalidate affected review coverage; run the required affected review again.

A read-only review may assess code, a specification, tickets, documentation, or another artifact. It returns the assigned output and limitations without repairing or publishing. Write-requiring checks return their procedure to an authorized executor or an already-supported disposable environment; preserve the review's required independence. If no compatible route exists, report the unmet requirement. Direct Sol work is a fallback only where it satisfies the workflow, not a substitute for mandatory independent review or delegation.

## Cross-thread and unsupported-runtime handoff

When compatible native isolated dispatch is unavailable, keep work on the eligible Sol root only where doing so preserves the active workflow. For work that requires another agent, independent context, or a specialist role, return the smallest explicit fresh-thread handoff that preserves the assignment semantics, or report the specific capability blocker. Do not silently replace required independence with self-review or discard mandatory delegation.

Use one accessible task-local file when writing is authorized, or a fenced block/other permitted channel when it is not. Include the shared context, exact assignment, role/model/effort requirement, permissions and write boundary, required independence, output/check contract, pending approvals, completion condition, and interrupted return step. Tell the user to open a new **non-forked** Codex thread with the same project/source access and the appropriate eligible configuration. State the action needed rather than claiming the switch occurred. If the assignment's semantics cannot survive a manual fresh-thread handoff, return that incompatibility instead.

For Astra, preserve the consultation contract: solution/framing only, read-only, leaf-only, and return to the original Sol owner. For `slw_sol_analysis`, preserve read-only bounded analysis/synthesis and any required independence. For `slw_sol_review`, preserve reviewer independence, exact target/revision, and separate output. For an authorized implementation handoff, preserve its explicit write ownership and do not infer commit/publication authority. Other eligible leaf work follows its packaged role contract.

Sol retains workflow ownership. On return, verify the result against the current scope, approval status, constraints, source/artifact revision, and required independence before accepting it. Refresh only affected stale evidence. Resume the exact unresolved action, not a presumed implementation phase. A partial answer preserves outstanding decisions and checks. For a non-Sol-root handoff, transfer the same shared context to an eligible Sol root without routing through Astra first.
