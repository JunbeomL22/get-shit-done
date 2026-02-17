# Phase 5: Fix STOPPED_PHASE Detection - Context

**Gathered:** 2026-02-17
**Status:** Ready for planning

<domain>
## Phase Boundary

Fix YOLO's failure detection so it correctly identifies the failed phase after `gaps_found` verification failure, shows the right banner (B1 not B2), records the correct phase in the stanza, and resumes from the right position. Also install the `/gsd:yolo` command and update requirements checkboxes.

</domain>

<decisions>
## Implementation Decisions

### Stop display
- Show **detailed** error info: phase number + list of specific unmet requirement IDs + investigation guidance
- Include a **YOLO session summary** in the stop banner (phases completed before failure + elapsed time) before the failure details
- Recovery actions: Claude's discretion on what commands/guidance to suggest
- B1 vs B2 distinction: Claude's discretion on how to differentiate "verification found gaps" from "verification failed to run"

### Resume strategy
- After gaps_found failure, YOLO **auto-detects** the situation from the stanza (failed_phase + gaps_found) and automatically enters **gap closure mode** — no explicit user flag needed
- Gap closure creates targeted fix plans based on VERIFICATION.md, then executes those
- After gap closure succeeds, YOLO **continues chaining** to subsequent phases (normal auto-advance)
- If gap closure itself fails (gaps still unresolved), **stop permanently** — one attempt per resume, then require manual intervention

### Command install
- Location and delivery method: Claude's discretion
- Install verification level: Claude's discretion
- Overwrite vs targeted edits if yolo.md already exists: Claude's discretion

### Requirements updates
- This phase **updates REQUIREMENTS.md** checkboxes for FAIL-01, FAIL-02, STATE-04 once the fix is verified — don't leave for audit

### Claude's Discretion
- Recovery action wording in stop banner
- B1 vs B2 banner distinction approach
- Command file location and delivery method
- Install verification (file check vs smoke test)
- Whether to overwrite or targeted-edit existing yolo.md

</decisions>

<specifics>
## Specific Ideas

No specific requirements — open to standard approaches

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 05-fix-stopped-phase-detection*
*Context gathered: 2026-02-17*
