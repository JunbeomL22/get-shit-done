# Phase 3: Integration and Failure Hardening - Context

**Gathered:** 2026-02-17
**Status:** Ready for planning

<domain>
## Phase Boundary

The full plan→execute→verify→advance chain runs automatically across all remaining phases and stops hard when verification finds gaps. This phase wires the existing auto-chain pipeline for YOLO mode and hardens failure handling. No new interactive gates, no modifications to individual workflow internals.

</domain>

<decisions>
## Implementation Decisions

### Phase chain flow
- In YOLO mode, plan-phase auto-skips the "No CONTEXT.md" gate — plans with research + requirements only, no user prompt
- verify-work runs as part of execute-phase's existing flow — YOLO does not insert it as a separate step
- The existing auto-chain pipeline (plan-phase → execute-phase → verify → advance) is used as-is; YOLO's job is to ensure the flags stay set so the chain doesn't break

### Failure stop behavior
- On verification failure, keep the yolo stanza in config.json intact — Phase 4 (resume) needs it to detect where we stopped
- On failure stop, show: phase number that failed + specific unmet requirements from verify-work — no resume command (user figures out next step)
- Distinguish verification failures from unexpected errors: verification failures show gaps found; unexpected errors (agent crash, tool failure) show the raw error and suggest manual investigation

### Milestone completion
- On milestone completion, just stop with a banner — no suggested next steps
- YOLO does not chain into the next milestone (MILE-01)

### Claude's Discretion
- Transition behavior: determine minimal change needed to keep auto_advance alive during YOLO (whether to modify transition.md or re-set flag on each phase)
- auto_advance protection strategy: pick safest approach for the existing pipeline (YOLO stanza as guard vs re-write on each transition)
- Milestone boundary detection method: pick most reliable way to know we're on the last phase
- Completion display format: pick appropriate summary output
- State cleanup on completion: decide what to clean (yolo stanza, auto_advance, mode) based on Phase 1/2 setup
- auto_advance handling on failure: pick based on safety and resume implications

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

*Phase: 03-integration-and-failure-hardening*
*Context gathered: 2026-02-17*
