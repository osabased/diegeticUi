---
name: sol-led-workflow
description: Route work across Sol, Luna, and Astra while preserving the active workflow. Use for the Sol-led pilot or selective Astra consultation.
---

# Sol-led workflow

Change who performs the work, not what the active workflow requires. Sol owns ordinary work and coordination; Luna supplies worthwhile bounded evidence; Astra handles consequential solutions and framing. Optimize total usage per accepted task, including verification and rework.

## 1. Bind to the active task

Use an actual Sol root at medium, high, or xhigh. A different or unknown root configuration requires one concise handoff to an eligible Sol root; invoking this skill cannot switch the running model. A delegated child keeps its assigned leaf role and returns routing requests to the root. Before the first dispatch, read [RUNTIME.md](references/RUNTIME.md) completely; reuse verified setup until relevant settings change.

Read the governing installed workflow/skill or reuse its applicable loaded instructions. Follow referenced procedures when their conditions apply. Identify in working context the current stage, next authorized action, required output/checks, pending approvals, stopping point, and return owner. For a task without a named workflow, use the user's request and applicable instructions; no synthetic stages or extra specification are needed.

The active workflow retains its procedure, dependencies, deliverable, and completion conditions within applicable user and higher-priority constraints. Routing controls allocation only. Keep user-reserved decisions with the user. Surface an incompatible model, permission, invocation, or procedure requirement as a blocker; do not silently substitute a different workflow.

**Complete when:** an eligible owner and the current task boundary are clear, or the specific handoff/blocker is returned.

## 2. Route the next authorized action

Reuse established evidence and decisions. Choose the smallest sufficient route within the active stage:

- **Ready action:** Sol performs the required interview step, synthesis, review, documentation, diagnosis, or authorized implementation directly. An established solution is not permission to edit, publish, commit, or advance to another stage.
- **Missing facts:** Sol reads directly when simpler. Use `slw_luna_evidence` for an independently answerable, bounded evidence question when delegation earns its cost.
- **Delegated analysis or synthesis:** Sol normally does this directly. Use `slw_sol_analysis` for a bounded read-only analytical assignment when an independent perspective, parallel decomposition, or caller-required separate analysis materially helps.
- **Consequential solution or framing:** prepare a focused `slw_astra_decision` consultation. Ask for framing when the difficult part is selecting the problem or investigation. A workflow name such as “specification” does not itself justify Astra.
- **Required user decision or approval:** ask as the active workflow requires and wait for that decision; continue only independent, already-authorized work. Evidence and specialist recommendations cannot supply user consent.

Optional delegation must justify its coordination cost. Mandatory delegation, independent review, and other required checks remain mandatory. For delegated Sol analysis/synthesis, use the contract in [HANDOFFS.md — Sol analysis or synthesis assignment](references/HANDOFFS.md#sol-analysis-or-synthesis-assignment). For delegated review or a nested requirement, read [HANDOFFS.md — Required reviews and nested calls](references/HANDOFFS.md#required-reviews-and-nested-calls). Use `slw_sol_review` for a compatible formal read-only review; use `slw_sol_implementation` only for an authorized implementation assignment. A clear task needs no worker or separate consolidator.

Converge reviews: freeze one tip, launch compatible required axes together against that tip, wait for every result, and aggregate findings before remediation. Apply one remediation batch, rerun affected checks, then launch one targeted confirmation batch for affected axes. Restart broad review only when remediation materially expands the diff or changes the chosen design. Do not multiply reviewers for an unchanged axis or let a stale-tip report trigger edits without rechecking it against the current tip.

**Complete when:** the next action is supported, a bounded assignment/consultation is ready, or a required user response or capability is awaited.

## 3. Delegate within the owning stage

Before dispatch or a cross-thread handoff, read the shared context and relevant role contract in [HANDOFFS.md](references/HANDOFFS.md). Carry applicable workflow obligations with the assignment. Use verified isolated dispatch from RUNTIME.md. Assign explicit write boundaries for implementation; serialize overlapping writes or use existing supported isolation. All packaged children are leaves.

Astra returns SOLUTION, FRAMING, NEEDS_EVIDENCE, or BLOCKED. Sol gathers requested evidence and resumes the same decision with the useful delta and preserved constraints. Treat a solution as a scoped technical result, not automatic user approval. A framing result proposes investigation; pursue it only within current authorization. Preserve any scoped Direction Gate and the active workflow's decision authority.

Workers return to the interrupted stage, not to a generic implementation phase. Keep required independent reports and their presentation separate. Otherwise consolidate useful evidence without suppressing contradictions or turning worker preferences into decisions. Broaden investigation only for a named material gap; there is no mandatory worker count or packet length.

**Complete when:** each assignment returns its local result, remaining obligations, and return owner, or a precise blocker; worker completion is not whole-workflow completion.

## 4. Resume and stop at the agreed boundary

When scope or approval changes, stop affected assignments where possible and rebind the action before accepting their results. Check returned work against the current task/revision, constraints, and required output before using it. Refresh only affected stale evidence. Sol resumes the next authorized action of the same stage, including any remaining required review, approval, or delivery step. Continue to a later stage only when progression is authorized. Preserve useful stage-to-stage context and any workflow-required fresh-context boundary; do not restart discovery or force a new thread at every stage name.

Complete required checks; add optional checks only for a named risk or uncertainty. Repair concrete failures within scope and rerun affected checks. Repeated failure calls for diagnosis, not automatic Astra promotion or another generic review. Reopen Astra only for a consequential invalidated premise, unresolved choice, or specified reopen condition; pause only affected dependent work and pass the new evidence and known consequences.

Use native blocking waits/completion events when useful work is exhausted. Give meaningful updates without polling loops. Close completed or superseded leaves; retain useful results and unresolved obligations in the existing task record when authorized.

**Complete when:** the current authorized deliverable and required checks are done, its approval/stopping point is reached, or a blocker has a named owner and next action. Use the active workflow's required response format. Otherwise return a short result, actual verification, and material caveat; omit internal routing reports unless requested.
