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
```

If `YOLO_ACTIVE` is "true", use AskUserQuestion to ask:

"A prior YOLO run exists from phase ${YOLO_START} (started ${YOLO_TS}). What would you like to do?"

Options:
1. "Clear and start fresh" — run `node ~/.claude/get-shit-done/bin/gsd-tools.cjs yolo-state clear` then proceed to Phase B
2. "Abort" — stop workflow

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

Determine the stopped phase: `STOPPED_PHASE` = the value of `next_phase` from roadmap analyze. This is the phase that did NOT complete.

Check for VERIFICATION.md to distinguish verification failure from unexpected error:

```bash
PADDED=$(printf "%02d" "$STOPPED_PHASE")
PHASE_DIR=$(ls -d ".planning/phases/${PADDED}-"* 2>/dev/null | head -1)
VERIFY_FILE="${PHASE_DIR}/${PADDED}-VERIFICATION.md"
```

**Case B1: Verification failure (FAIL-01, FAIL-02)**

Condition: `VERIFY_FILE` exists AND contains `status: gaps_found` (or similar indication of verification gaps).

Read the "What's Missing" or gaps section from VERIFICATION.md for display. Present the section verbatim — do not parse individual gap fields.

Write failure state (preserve yolo stanza for Phase 4 resume):

```bash
node ~/.claude/get-shit-done/bin/gsd-tools.cjs yolo-state fail --phase "${STOPPED_PHASE}" --reason "verification gaps found"
node ~/.claude/get-shit-done/bin/gsd-tools.cjs config-set workflow.auto_advance false
```

Display YOLO STOPPED banner (locked decision: show phase number + gaps, NO resume command):

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
 GSD ► YOLO STOPPED — Phase {STOPPED_PHASE}
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Verification failed: Phase {STOPPED_PHASE} has unmet requirements.

**What was missing:**
{gaps section from VERIFICATION.md}

YOLO state preserved. See {VERIFY_FILE} for full report.
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
- Do NOT implement resume logic (Phase 4 scope)
- Do NOT parse Task() return text for chain outcome detection — always use disk state (roadmap analyze, yolo-state read, VERIFICATION.md)

</process>
