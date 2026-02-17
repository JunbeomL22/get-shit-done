<purpose>
Run all remaining roadmap phases to completion automatically. Validates prerequisites, writes YOLO state in the correct order, then launches plan-phase with --auto to activate the existing auto-advance chain. Stops only on failure — does not retry.
</purpose>

<required_reading>
Read all files referenced by the invoking prompt's execution_context before starting.

@~/.claude/get-shit-done/references/ui-brand.md
</required_reading>

<process>

## Phase A: Prerequisite Checks

All checks happen before any state mutation. If any check fails, stop immediately.

### A1. Structural Check

```bash
INIT=$(node ~/.claude/get-shit-done/bin/gsd-tools.cjs init phase-op "1" 2>/dev/null)
PLANNING_EXISTS=$(echo "$INIT" | jq -r '.planning_exists')
ROADMAP_EXISTS=$(echo "$INIT" | jq -r '.roadmap_exists')
```

If `PLANNING_EXISTS` is not "true" or `ROADMAP_EXISTS` is not "true":

```
╔══════════════════════════════════════════════════════════════╗
║  ERROR                                                       ║
╚══════════════════════════════════════════════════════════════╝

No project found. Run /gsd:new-project first.

**To fix:** Run `/gsd:new-project` to initialize a project with a roadmap.
```

Stop. Do not proceed.

### A2. Positional Check

```bash
ANALYZE=$(node ~/.claude/get-shit-done/bin/gsd-tools.cjs roadmap analyze 2>/dev/null)
NEXT_PHASE=$(echo "$ANALYZE" | jq -r '.next_phase // empty')
TOTAL=$(echo "$ANALYZE" | jq -r '.phase_count')
COMPLETED=$(echo "$ANALYZE" | jq -r '.completed_phases')
PHASES_REMAINING=$((TOTAL - COMPLETED))
```

If `NEXT_PHASE` is empty (all phases complete):

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
 GSD ► MILESTONE COMPLETE 🎉
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

Display: "All {TOTAL} phases complete! Milestone is done."

Stop. Do NOT invoke complete-milestone automatically (Phase 4 scope).

### A3. Stale State Check

```bash
YOLO_JSON=$(node ~/.claude/get-shit-done/bin/gsd-tools.cjs yolo-state read --raw 2>/dev/null || echo '{}')
YOLO_ACTIVE=$(echo "$YOLO_JSON" | jq -r '.active // false')
YOLO_START=$(echo "$YOLO_JSON" | jq -r '.start_phase // "?"')
YOLO_TS=$(echo "$YOLO_JSON" | jq -r '.timestamp // ""')
YOLO_FAILED=$(echo "$YOLO_JSON" | jq -r '.failed_phase // empty')
YOLO_REASON=$(echo "$YOLO_JSON" | jq -r '.failure_reason // "unknown"')
```

Three mutually exclusive stanza states — evaluate in order:

**Branch 1: No stanza** — `YOLO_JSON` is `{}` (no active, no failed_phase). Normal launch. Skip A3 and proceed.

**Branch 2: Active run (stale)** — `YOLO_ACTIVE` is "true".

If `YOLO_ACTIVE` is "true", use AskUserQuestion to ask:

"A prior YOLO run exists from phase ${YOLO_START} (started ${YOLO_TS}). What would you like to do?"

Options:
1. "Clear and start fresh" — run `node ~/.claude/get-shit-done/bin/gsd-tools.cjs yolo-state clear` then proceed to Phase B
2. "Abort" — stop workflow

If the user selects "Abort", stop. Do not proceed.

**Branch 3: Prior failed run** — `YOLO_ACTIVE` is "false" AND `YOLO_FAILED` is non-empty.

If `YOLO_ACTIVE` is "false" AND `YOLO_FAILED` is non-empty:

Read the failure reason to determine which sub-branch to take:

```bash
YOLO_REASON=$(echo "$YOLO_JSON" | jq -r '.failure_reason // "unknown"')
```

Evaluate in order (check 3a before 3b to prevent infinite loops):

**Branch 3a: Prior gap closure already failed** — `YOLO_REASON` contains "gap closure failed".

If `YOLO_REASON` contains "gap closure failed":

Display permanent stop banner:

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
 GSD ► YOLO STOPPED — Manual Intervention Required
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Gap closure was attempted on Phase ${YOLO_FAILED} and failed.
Automatic recovery has been exhausted (one attempt limit).

To resolve manually:
1. Review: .planning/phases/${PADDED}-*/VERIFICATION.md
2. Fix the gaps manually
3. Clear state: run `yolo-state clear`
4. Re-run: `/gsd:yolo`
```

Stop. Do not proceed.

**Branch 3b: Gaps found — enter auto gap-closure mode** — `YOLO_REASON` contains "gaps" (but NOT "gap closure failed").

If `YOLO_REASON` contains "gaps" (and Branch 3a did not match):

Display YOLO GAP CLOSURE banner:

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
 GSD ► YOLO GAP CLOSURE — Phase ${YOLO_FAILED}
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Auto-detected verification gaps on Phase ${YOLO_FAILED}.
Creating targeted fix plans and executing...
```

Run gap closure:

1. Clear the stale stanza: `node ~/.claude/get-shit-done/bin/gsd-tools.cjs yolo-state clear`
2. Spawn gap closure as a subagent Task:

```
Task(
  prompt="Run /gsd:plan-phase ${YOLO_FAILED} --gaps --auto",
  subagent_type="general-purpose",
  description="YOLO: Gap closure for Phase ${YOLO_FAILED}"
)
```

3. After Task() returns, re-read roadmap state from disk (do NOT parse Task() return text):

```bash
ANALYZE=$(node ~/.claude/get-shit-done/bin/gsd-tools.cjs roadmap analyze 2>/dev/null)
```

4. Check if Phase YOLO_FAILED now has `roadmap_complete == true`:

```bash
GAP_PHASE_DONE=$(echo "$ANALYZE" | jq -r --argjson phase "$YOLO_FAILED" '
  .phases[] | select(.number == $phase) | .roadmap_complete
')
```

If `GAP_PHASE_DONE` is "true": gap closure succeeded. Set `NEXT_PHASE` from `roadmap analyze .next_phase`. If `NEXT_PHASE` is empty, all phases done — display completion and stop. Otherwise set `PHASES_REMAINING=$((TOTAL - COMPLETED))` using updated ANALYZE values, then proceed to Phase B to continue chaining remaining phases.

If `GAP_PHASE_DONE` is NOT "true": gap closure failed. Write permanent failure state:

```bash
node ~/.claude/get-shit-done/bin/gsd-tools.cjs yolo-state fail --phase "${YOLO_FAILED}" --reason "gap closure failed — manual intervention required"
node ~/.claude/get-shit-done/bin/gsd-tools.cjs config-set workflow.auto_advance false
```

Display YOLO GAP CLOSURE FAILED banner:

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
 GSD ► YOLO GAP CLOSURE FAILED — Phase ${YOLO_FAILED}
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Gap closure attempt on Phase ${YOLO_FAILED} did not resolve all gaps.
Automatic recovery exhausted (one attempt limit).

To resolve manually:
1. Review: .planning/phases/${PADDED}-*/VERIFICATION.md
2. Fix the gaps manually
3. Clear state: run `yolo-state clear`
4. Re-run: `/gsd:yolo`
```

Stop permanently. Do not proceed.

**Branch 3c: Other failure reason** — `YOLO_REASON` does NOT contain "gaps".

If `YOLO_REASON` does not contain "gaps" (Branches 3a and 3b did not match):

Get the authoritative resume position from roadmap:

```bash
ANALYZE=$(node ~/.claude/get-shit-done/bin/gsd-tools.cjs roadmap analyze 2>/dev/null)
RESUME_PHASE=$(echo "$ANALYZE" | jq -r '.next_phase // empty')
TOTAL=$(echo "$ANALYZE" | jq -r '.phase_count')
COMPLETED=$(echo "$ANALYZE" | jq -r '.completed_phases')
```

Display YOLO RESUME banner:

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
 GSD ► YOLO RESUME
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Previous run stopped at phase ${YOLO_FAILED} (${YOLO_REASON}).
Completed phases: ${COMPLETED} of ${TOTAL}

Next incomplete phase: ${RESUME_PHASE}
```

Use AskUserQuestion: "Resume from phase ${RESUME_PHASE}?"

Options:
1. "Resume" — run `node ~/.claude/get-shit-done/bin/gsd-tools.cjs yolo-state clear`, set `NEXT_PHASE="${RESUME_PHASE}"` and `PHASES_REMAINING=$((TOTAL - COMPLETED))`, then proceed to Phase B
2. "Start fresh" — run `node ~/.claude/get-shit-done/bin/gsd-tools.cjs yolo-state clear`, then proceed to Phase B (Phase B uses NEXT_PHASE from A2 variables already set above)
3. "Abort" — stop workflow

If the user selects "Abort", stop. Do not proceed.

---

## Phase B: State Setup

Display the YOLO MODE banner:

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
 GSD ► YOLO MODE
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

Show launch details:
- Next phase: ${NEXT_PHASE}
- Phases remaining: ${PHASES_REMAINING} of ${TOTAL}

Read workflow agent settings for display only (never override):

```bash
RESEARCH=$(node ~/.claude/get-shit-done/bin/gsd-tools.cjs config-get workflow.research 2>/dev/null || echo "true")
PLAN_CHECK=$(node ~/.claude/get-shit-done/bin/gsd-tools.cjs config-get workflow.plan_check 2>/dev/null || echo "true")
VERIFIER=$(node ~/.claude/get-shit-done/bin/gsd-tools.cjs config-get workflow.verifier 2>/dev/null || echo "true")
```

Display agent status (read-only — YOLO never modifies these):
```
Agents: Research: {enabled/disabled}, Plan check: {enabled/disabled}, Verifier: {enabled/disabled}
```

Where "enabled" = value is "true", "disabled" = value is "false".

### B1. Write state in order (order is critical)

**Step 1:** Set mode to yolo (idempotent — may already be set):

```bash
node ~/.claude/get-shit-done/bin/gsd-tools.cjs config-set mode "yolo"
```

If this fails, display an error box and stop. Do NOT proceed to Step 2.

**Step 2:** Enable auto-advance (activates the chain in plan-phase and execute-phase):

```bash
node ~/.claude/get-shit-done/bin/gsd-tools.cjs config-set workflow.auto_advance true
```

If this fails, display an error box and stop. Do NOT proceed to Step 3.

**Step 3:** Write YOLO stanza (atomic creation — the point-of-no-return sentinel):

```bash
node ~/.claude/get-shit-done/bin/gsd-tools.cjs yolo-state write --start-phase "${NEXT_PHASE}"
```

If this fails, display an error box and stop. Do NOT proceed to Phase C.

Display confirmation: "◆ YOLO state written — launching phase ${NEXT_PHASE}..."

---

## Phase C: Launch and Monitor

Spawn plan-phase as a subagent Task with `--auto` flag to propagate the auto-advance chain:

```
Task(
  prompt="Run /gsd:plan-phase ${NEXT_PHASE} --auto",
  subagent_type="general-purpose",
  description="YOLO: Phase ${NEXT_PHASE}"
)
```

### C1. Post-Chain State Analysis

After Task() returns, determine what happened by reading disk state. Do NOT parse the Task() return text — it is unreliable across different chain termination points.

**Read roadmap state:**

```bash
ANALYZE=$(node ~/.claude/get-shit-done/bin/gsd-tools.cjs roadmap analyze 2>/dev/null)
```

Extract from ANALYZE: `next_phase`, `completed_phases`, `phase_count`.

Calculate: `ALL_DONE` = true if `next_phase` is empty or null (all phases marked complete).

**Read YOLO stanza state:**

```bash
YOLO_STATE=$(node ~/.claude/get-shit-done/bin/gsd-tools.cjs yolo-state read --raw 2>/dev/null || echo '{}')
```

Extract: `active` field. If stanza is empty (`{}`), it was cleared by transition.md Route B (milestone complete path).

### C2. Route by Outcome

**Case A: Milestone Complete**

Condition: `ALL_DONE` is true (no next_phase) AND yolo stanza is empty or has `active: false`.

This means transition.md Route B already ran, showed the YOLO COMPLETE banner, cleared the yolo stanza, and cleared auto_advance. yolo.md has nothing more to do.

Display confirmation:

```
Chain complete. All phases finished.
```

Stop. Return to user.

**Case B: Chain Stopped — Determine Why**

Condition: `ALL_DONE` is false (next_phase exists). The chain stopped before completing all phases.

Determine the stopped phase by scanning the phases array for the first phase with `disk_status == "complete"` AND `roadmap_complete == false`. This uniquely identifies a phase where all plans executed (SUMMARYs written) but verification failed (phase complete never called).

```bash
STOPPED_PHASE=$(echo "$ANALYZE" | jq -r '
  .phases[]
  | select(.disk_status == "complete" and .roadmap_complete == false)
  | .number
' | head -1)
```

Fallback: if no phase matches (unexpected stop before summaries were written), use `next_phase`:

```bash
if [ -z "$STOPPED_PHASE" ]; then
  STOPPED_PHASE=$(echo "$ANALYZE" | jq -r '.next_phase // empty')
fi
```

Compute session summary for display:

```bash
COMPLETED=$(echo "$ANALYZE" | jq -r '.completed_phases')
TOTAL=$(echo "$ANALYZE" | jq -r '.phase_count')

# Elapsed time from YOLO stanza timestamp (read in C1 as YOLO_STATE)
YOLO_TS=$(echo "$YOLO_STATE" | jq -r '.timestamp // ""')
START_EPOCH=$(date -d "$YOLO_TS" +%s 2>/dev/null)
if [ -n "$START_EPOCH" ]; then
  NOW_EPOCH=$(date +%s)
  ELAPSED_SECS=$((NOW_EPOCH - START_EPOCH))
  ELAPSED_MINS=$((ELAPSED_SECS / 60))
  ELAPSED_SECS_REM=$((ELAPSED_SECS % 60))
  ELAPSED="${ELAPSED_MINS}m ${ELAPSED_SECS_REM}s"
else
  ELAPSED="unknown"
fi
```

Check for VERIFICATION.md to distinguish verification failure from unexpected error:

```bash
PADDED=$(printf "%02d" "$STOPPED_PHASE")
PHASE_DIR=$(ls -d ".planning/phases/${PADDED}-"* 2>/dev/null | head -1)
VERIFY_FILE="${PHASE_DIR}/${PADDED}-VERIFICATION.md"
```

**Case B1: Verification failure (FAIL-01, FAIL-02)**

Condition: `VERIFY_FILE` exists AND contains `status: gaps_found` (or similar indication of verification gaps).

Read the "What's Missing" or gaps section from VERIFICATION.md for display. Present the section verbatim — do not parse individual gap fields.

Write failure state (preserve yolo stanza for resume):

```bash
node ~/.claude/get-shit-done/bin/gsd-tools.cjs yolo-state fail --phase "${STOPPED_PHASE}" --reason "verification gaps found on phase ${STOPPED_PHASE}"
node ~/.claude/get-shit-done/bin/gsd-tools.cjs config-set workflow.auto_advance false
```

Display YOLO STOPPED banner (show phase number + session summary + gaps + investigation hint):

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
 GSD ► YOLO STOPPED — Phase {STOPPED_PHASE}
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Session: {COMPLETED} of {TOTAL} phases completed — {ELAPSED} elapsed

Verification failed: Phase {STOPPED_PHASE} has unmet requirements.

**What was missing:**
{gaps section from VERIFICATION.md}

YOLO state preserved. See {VERIFY_FILE} for full report.
To investigate: `/gsd:plan-phase {STOPPED_PHASE} --gaps`
```

Stop. Do NOT auto-retry.

**Case B2: Unexpected error**

Condition: Chain stopped but VERIFICATION.md does not exist for the stopped phase, OR VERIFICATION.md exists with a status other than `gaps_found`.

Write failure state:

```bash
node ~/.claude/get-shit-done/bin/gsd-tools.cjs yolo-state fail --phase "${STOPPED_PHASE}" --reason "unexpected error — chain terminated without verification artifact"
node ~/.claude/get-shit-done/bin/gsd-tools.cjs config-set workflow.auto_advance false
```

Display unexpected error banner (locked decision: show raw error, suggest manual investigation):

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
 GSD ► YOLO STOPPED — Unexpected Error
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

The chain stopped at Phase {STOPPED_PHASE} without producing verification results.

This may be an agent crash, tool failure, or planning failure.
Investigate manually starting from Phase {STOPPED_PHASE}.

YOLO state preserved at Phase {STOPPED_PHASE}.
```

Stop. Do NOT auto-retry.

**Constraints:**
- Do NOT use `config-set` on `workflow.research`, `workflow.plan_check`, or `workflow.verifier`
- Do NOT parse Task() return text for chain outcome detection — always use disk state (roadmap analyze, yolo-state read, VERIFICATION.md)

</process>
