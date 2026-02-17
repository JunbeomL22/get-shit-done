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

## Phase C: Launch

Spawn plan-phase as a subagent Task with `--auto` flag to propagate the auto-advance chain:

```
Task(
  prompt="Run /gsd:plan-phase ${NEXT_PHASE} --auto",
  subagent_type="general-purpose",
  description="Plan Phase ${NEXT_PHASE}"
)
```

**Handle return values:**

- If plan-phase returns `## PLANNING COMPLETE` or phase execution succeeds:
  Display a summary of what was accomplished. The chain handles itself from here (plan-phase auto-advances to execute-phase, execute-phase auto-advances via transition.md).

- If plan-phase returns `## PLANNING INCONCLUSIVE` or any failure:
  Display the failure message verbatim. Show recovery instructions:

  ```
  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
   GSD ► YOLO STOPPED
  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  YOLO run stopped at Phase ${NEXT_PHASE}.

  **To resume manually:**
  `/gsd:plan-phase ${NEXT_PHASE}` — plan the stopped phase
  `/gsd:execute-phase ${NEXT_PHASE}` — execute it directly

  **To retry YOLO from this point:**
  `/gsd:yolo` — YOLO will detect stale state and ask what to do
  ```

  Stop. Do NOT auto-retry (project decision: stop on failure, user resolves).

**Constraints:**
- Do NOT use `config-set` on `workflow.research`, `workflow.plan_check`, or `workflow.verifier`
- Do NOT implement cleanup of `workflow.auto_advance` or `workflow.yolo` stanza (Phase 3 scope)
- Do NOT implement resume logic (Phase 4 scope)

</process>
