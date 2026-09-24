# Progress Format

The active state page is [progress.md](../progress.md). Full completed milestone records live under `../progress/`, one file per milestone. Record observations only after inspection, testing, or acceptance, and only when they would be costly to recover from code and tests. An outcome without a completion decision remains unverified, not failed or silently complete.

## Observations

<!-- Keep only facts that still affect current decisions. Use one concise claim per bullet, with the command, scenario, or source that supports it. Preserve resolved or superseded evidence in its milestone record rather than repeating it here. -->

## Open Questions

<!-- Keep only questions exposed by current evidence that may affect the next decision. Remove or resolve them when answered. -->

## Latest Completed Milestone

<!-- Link the newest record by ID and title to its file under `progress/`. Leave blank before M001. The next move takes the following number. Find older records under `../progress/` by ID or search by topic. -->

## Completed milestone files

After each move, create `../progress/M###-short-title.md` with this shape:

```md
# M### — Title

- Completed: YYYY-MM-DD
- Result: Observable result and decision-relevant context.
- Verification: Checks, play evidence, and material limits.
```

Keep IDs contiguous and each full record in one file. Preserve the dated result and verification; correct a false record explicitly. Update the latest link in `progress.md` at the same handoff. Earlier design choices remain context, not authority for future work.

## Outcome Decisions

<!-- Add this section to the active ledger only when an outcome is actually resolved. Use one record per ID:
### V1 — complete | retired
- Decided: YYYY-MM-DD
- Basis: Observable evidence covering the whole outcome, or the user direction that retired it.
For complete, verify the actual product behavior in its relevant runtime; a narrower milestone or test is not enough. Keep completed outcomes in visions while they remain desired product behavior. Remove retired outcomes from visions in the same handoff. Never reuse an ID for a different outcome. -->
