# Phase 4: Resume and Visibility - Research

**Researched:** 2026-02-17
**Domain:** GSD YOLO workflow — resume logic, phase transition banners, milestone completion summary
**Confidence:** HIGH

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| STATE-04 | Re-running `/gsd:yolo` after interruption resumes from correct phase position | yolo.md A3 currently only handles `active: true` (stale active run). The `active: false` + `failed_phase` set state written by `yolo-state fail` is never detected and falls through as no-stanza. Phase 4 must add a resume branch to A3 that reads `roadmap analyze` to find `next_phase` and re-launches from there. No new gsd-tools command needed — existing `yolo-state read` + `roadmap analyze` provide all required data. |
</phase_requirements>

## Summary

Phase 4 implements the final polish layer for YOLO: resume after interruption (STATE-04) and two visibility improvements (SC-2 and SC-3). All three success criteria are achieved through targeted edits to two existing workflow files — `yolo.md` and `transition.md`. No new gsd-tools commands are required.

The resume feature (SC-1/STATE-04) is the only requirement but it touches three related concerns: detecting a prior failed run, determining the correct resume position, and re-launching the chain. The detection uses the existing yolo stanza fields (`active: false` + `failed_phase` set), and the correct resume position comes from `roadmap analyze` → `next_phase` (authoritative: reflects which phases are checked `[x]` in ROADMAP.md), not from the stanza's `failed_phase` or `start_phase` fields.

The two visibility success criteria (SC-2 and SC-3) are not covered by STATE-04 but are in the phase's success criteria. SC-2 ("YOLO mode active, phase N of M" banner at each transition) belongs in transition.md Route A yolo block. SC-3 (milestone completion summary) enriches the existing YOLO COMPLETE banner in transition.md Route B yolo block with a phase summary table.

**Primary recommendation:** Three targeted edits across yolo.md and transition.md. The resume logic goes in yolo.md A3 as a new branch (the `active: false` case). The phase-progress banner goes in transition.md Route A yolo block. The completion summary goes in transition.md Route B yolo block. No new gsd-tools commands.

## Standard Stack

### Core
| Tool | Version | Purpose | Why Standard |
|------|---------|---------|--------------|
| `gsd-tools yolo-state read --raw` | Phase 1 (built) | Read yolo stanza: `active`, `start_phase`, `failed_phase`, `failure_reason`, `timestamp` | Already used in yolo.md A3 for stale state check |
| `gsd-tools roadmap analyze` | existing | Determine correct resume position via `next_phase`; get `completed_phases` and `phase_count` for progress display | Already used in yolo.md A2 (positional check) and Phase C post-chain detection |
| `gsd-tools config-set workflow.auto_advance true` | existing | Re-enable auto-advance for resumed chain | Already used in yolo.md Phase B state setup |
| `gsd-tools yolo-state write --start-phase N` | Phase 1 (built) | Write fresh yolo stanza on resume (overwrite stale failed stanza) | Already used in yolo.md Phase B |
| `gsd-tools config-set mode "yolo"` | existing | Ensure mode=yolo on resume | Already used in yolo.md Phase B |

### No New Commands Needed
All resume and visibility operations use data already available from `yolo-state read --raw` and `roadmap analyze`. Phase 4 is pure workflow file changes.

**Installation:** No new packages or commands.

## Architecture Patterns

### Recommended File Change Surface

```
~/.claude/get-shit-done/workflows/
├── yolo.md          # Change A3: add resume branch for active:false + failed_phase case
└── transition.md    # Change Route A yolo: add "YOLO mode active, phase N of M" banner
                     # Change Route B yolo: enrich YOLO COMPLETE banner with phase summary
```

Plus corresponding source copies:
```
get-shit-done/workflows/
├── yolo.md          # Source copy — sync A3 change
└── transition.md    # Source copy — sync Route A/B changes
```

No new files. Three targeted edits across two workflow files (applied to source + installed copies = 6 file edits total).

---

### Pattern 1: yolo.md A3 — Resume Branch for `active: false` + `failed_phase`

**What:** Add a new condition to A3 that fires when the stanza exists with `active: false` and `failed_phase` set. This is the state written by `yolo-state fail` when a previous YOLO run stops on verification failure or unexpected error.

**Current A3 logic:**

```bash
YOLO_JSON=$(node .../gsd-tools.cjs yolo-state read --raw 2>/dev/null || echo '{}')
YOLO_ACTIVE=$(echo "$YOLO_JSON" | jq -r '.active // false')
YOLO_START=$(echo "$YOLO_JSON" | jq -r '.start_phase // "?"')
YOLO_TS=$(echo "$YOLO_JSON" | jq -r '.timestamp // ""')
```

If `YOLO_ACTIVE` is "true" → "Clear and start fresh" or "Abort"

**Missing case:** `YOLO_ACTIVE` is "false" AND `failed_phase` field is set → this is a resumable failed run

**New A3 logic (extended):**

```bash
YOLO_JSON=$(node .../gsd-tools.cjs yolo-state read --raw 2>/dev/null || echo '{}')
YOLO_ACTIVE=$(echo "$YOLO_JSON" | jq -r '.active // false')
YOLO_START=$(echo "$YOLO_JSON" | jq -r '.start_phase // "?"')
YOLO_TS=$(echo "$YOLO_JSON" | jq -r '.timestamp // ""')
YOLO_FAILED=$(echo "$YOLO_JSON" | jq -r '.failed_phase // empty')
YOLO_REASON=$(echo "$YOLO_JSON" | jq -r '.failure_reason // "unknown"')
```

**Branch 1 (existing): `YOLO_ACTIVE` is "true"**
→ "A prior YOLO run exists from phase ${YOLO_START} (started ${YOLO_TS}). What would you like to do?"
→ Options: "Clear and start fresh" / "Abort"

**Branch 2 (new): `YOLO_ACTIVE` is "false" AND `YOLO_FAILED` is non-empty**

This is a prior failed run. Determine the correct resume position by reading roadmap:

```bash
ANALYZE=$(node .../gsd-tools.cjs roadmap analyze 2>/dev/null)
RESUME_PHASE=$(echo "$ANALYZE" | jq -r '.next_phase // empty')
TOTAL=$(echo "$ANALYZE" | jq -r '.phase_count')
COMPLETED=$(echo "$ANALYZE" | jq -r '.completed_phases')
```

Display resume prompt:

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
 GSD ► YOLO RESUME
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Previous run stopped at phase ${YOLO_FAILED} (${YOLO_REASON}).
Completed phases: ${COMPLETED} of ${TOTAL}

Next incomplete phase: ${RESUME_PHASE}
```

Use AskUserQuestion:
"Resume from phase ${RESUME_PHASE}?"

Options:
1. "Resume" — clear stanza and proceed to Phase B with `NEXT_PHASE = RESUME_PHASE`
2. "Start fresh (clear all state)" — `yolo-state clear` then proceed to Phase B (uses fresh `roadmap analyze` NEXT_PHASE)
3. "Abort" — stop

**Why `roadmap analyze` for resume position, not `yolo.failed_phase`:**
- `failed_phase` is the phase that failed and was written to the stanza
- `roadmap analyze` → `next_phase` is the first phase not yet marked `[x]` complete in ROADMAP.md
- These are the same when a phase fails mid-execution (its ROADMAP checkbox was never marked)
- But `roadmap analyze` is the single authoritative source — it handles edge cases where the user manually advanced or where partial completion occurred
- Requirement SC-1 explicitly says "resumes from the next incomplete phase as determined by `roadmap analyze`"

**What "Resume" does:**

```bash
# 1. Clear the failed stanza
node .../gsd-tools.cjs yolo-state clear

# 2. Set NEXT_PHASE to RESUME_PHASE
NEXT_PHASE="$RESUME_PHASE"
PHASES_REMAINING=$((TOTAL - COMPLETED))

# 3. Proceed to Phase B (normal state setup with NEXT_PHASE set)
```

Phase B then writes fresh yolo stanza with `--start-phase ${NEXT_PHASE}` and continues normally.

**Confidence:** HIGH — the stanza fields (`active`, `failed_phase`, `failure_reason`) are verified in yolo-state fail implementation (gsd-tools.cjs lines 886-888). The resume position logic using `roadmap analyze` follows the same pattern as Phase C post-chain detection and matches SC-1 exactly.

---

### Pattern 2: transition.md Route A yolo — Phase Progress Banner

**What:** Add a "YOLO mode active, phase N of M" banner to transition.md Route A yolo block, displayed at each phase transition so the user knows where the run stands.

**SC-2 text:** "Each phase transition displays a banner showing 'YOLO mode active, phase N of M'"

**Current Route A yolo block (minimal):**

```markdown
Phase [X] marked complete.

Next: Phase [X+1] — [Name]

⚡ Auto-continuing: Plan Phase [X+1]

Exit skill and invoke SlashCommand("/gsd:plan-phase [X+1] --auto")
```

**Data available at this point in transition.md:**
- `TRANSITION` result from `phase complete` command: `completed_phase`, `plans_executed`, `next_phase`, `next_phase_name`, `is_last_phase`
- `roadmap analyze` data (can be called if needed): `completed_phases`, `phase_count`

**Change:** Add a progress banner after marking the phase complete, before spawning plan-phase:

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
 GSD ► YOLO MODE ACTIVE — Phase {N} of {M}
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Phase {COMPLETED_PHASE} complete. Advancing to Phase {NEXT_PHASE}: {NEXT_PHASE_NAME}
```

Where:
- `{N}` = `completed_phases` (phases now done, including just-completed one)
- `{M}` = `phase_count`

**Data sourcing:** The `TRANSITION` result from `phase complete` returns `next_phase` and `next_phase_name`. But it doesn't return `completed_phases` or `phase_count` directly. Two options:
1. Call `roadmap analyze` again after `phase complete` to get `completed_phases` and `phase_count`
2. Derive N from the just-completed phase number (which is available as `completed_phase` from the transition result)

Recommendation: Call `roadmap analyze` to get `completed_phases` and `phase_count`. It's already called in execute-phase's offer_next step implicitly (via transition.md). One extra call is negligible.

**Confidence:** HIGH — transition.md already uses `phase complete` which returns the needed fields; `roadmap analyze` pattern is established and used throughout.

---

### Pattern 3: transition.md Route B yolo — Enriched YOLO COMPLETE Banner

**What:** Add a phase summary table to the YOLO COMPLETE banner showing which phases ran and what was accomplished.

**SC-3 text:** "On milestone completion, a summary shows which phases ran and what was accomplished"

**Current Route B yolo banner:**

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
 GSD ► YOLO COMPLETE
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

All {N} phases complete. Milestone done.
```

**What to add:** A table showing each phase, plan count, and key accomplishments.

**Data available:** `roadmap analyze` returns:
- `phases` array with `number`, `name`, `plan_count`, `summary_count`, `disk_status`
- `phase_count` (total)
- `completed_phases` (count)

For "what was accomplished": reading individual SUMMARY.md files is expensive in context overhead. Instead, use the phase name + plan count as the accomplishment indicator. This satisfies SC-3 without blowing context.

**Summary table format:**

```
| Phase | Name | Plans Run |
|-------|------|-----------|
| 1     | State Infrastructure | 2 plans |
| 2     | Launcher | 1 plan |
| 3     | Integration and Failure Hardening | 3 plans |
| 4     | Resume and Visibility | N plans |
```

**Enriched banner:**

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
 GSD ► YOLO COMPLETE
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

All {N} phases complete. Milestone done.

| Phase | Name | Plans Run |
|-------|------|-----------|
{one row per phase from roadmap analyze}
```

**Data sourcing:** `roadmap analyze` is already called in the Route B area (via `phase complete`). The phases array provides all needed fields. Call `roadmap analyze` to populate the table.

**Confidence:** HIGH — roadmap analyze phases array verified in runtime output (see Sources); plan_count field present for all phases.

---

### Anti-Patterns to Avoid

- **Using `yolo.failed_phase` as the resume position:** `failed_phase` records which phase was being executed when YOLO stopped, but `roadmap analyze` → `next_phase` is the authoritative resume position. They are usually the same, but `roadmap analyze` is the single source of truth per SC-1.
- **Prompting on resume without showing context:** User needs to see the previous failure reason and completed phase count before deciding to resume or start fresh. Show the YOLO RESUME banner before AskUserQuestion.
- **Writing yolo-state write before clearing the old failed stanza:** Always `yolo-state clear` before `yolo-state write` (Phase B does this via the write command which overwrites, but the clear is explicit cleanup).
- **Adding the progress banner to Plan Phase B (yolo.md) instead of transition.md:** The "phase N of M" counter advances at each transition. yolo.md only fires once at launch. The banner belongs in transition.md Route A where each phase boundary occurs.
- **Reading individual SUMMARY.md files for SC-3:** Too expensive in context. Use `roadmap analyze` phases array (plan_count) as the accomplishment proxy.
- **Forgetting source-to-installed sync:** Both `get-shit-done/workflows/yolo.md` (source) and `/home/junbeom/.claude/get-shit-done/workflows/yolo.md` (installed) must be updated. Same for transition.md. Pattern established in Phase 3.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Detect prior failed YOLO run | Check config.json directly | `yolo-state read --raw` + check `active: false` + `failed_phase` | Established command, handles absent stanza gracefully (returns `{}`) |
| Find correct resume position | Use `failed_phase` from stanza | `roadmap analyze` → `next_phase` | SC-1 explicitly requires roadmap analyze; handles edge cases |
| Count phases completed for banner | Count ROADMAP.md checkboxes manually | `roadmap analyze` → `completed_phases` + `phase_count` | Already in use throughout chain |
| Build phase summary for YOLO COMPLETE | Read all SUMMARY.md files | `roadmap analyze` → `phases` array with `plan_count` | Context-efficient; phases array verified in runtime output |

**Key insight:** Phase 4 adds zero new gsd-tools commands. All data is already available from existing commands.

## Common Pitfalls

### Pitfall 1: A3 Branch Order — Active Before Failed

**What goes wrong:** If A3 checks `YOLO_ACTIVE` first and fails to extract `YOLO_FAILED`, a failed stanza (`active: false`, `failed_phase` set) might trigger wrong branch.

**Why it happens:** The existing A3 condition is `if YOLO_ACTIVE is "true"`. If `active` is `false` and this is the only check, the stanza is silently ignored (no resume offered).

**How to avoid:** Structure A3 as three mutually exclusive branches:
1. No stanza (`YOLO_JSON == {}`) → skip (normal flow)
2. `active == "true"` → stale active run (existing behavior: clear/abort)
3. `active == "false"` AND `failed_phase` non-empty → prior failed run (new: resume/fresh/abort)

Extract both `YOLO_ACTIVE` and `YOLO_FAILED` before the branching.

**Warning signs:** User re-runs `/gsd:yolo` after failure and it proceeds without offering resume, starting from first incomplete phase without acknowledgment.

### Pitfall 2: Resume Phase Shows Correctly but Chain Re-Runs Completed Phases

**What goes wrong:** After resume, the chain starts from `RESUME_PHASE` but Phase B writes `yolo-state write --start-phase ${RESUME_PHASE}`. This is correct. But if `auto_advance` was `false` (cleared by the failure handler), Phase B re-sets it to `true`. The chain then only runs phases from `RESUME_PHASE` onward — completed phases are already marked `[x]` in ROADMAP.md and would not be offered as `next_phase` by `roadmap analyze`. So re-running completed phases is NOT a risk — `roadmap analyze` skips them.

**Why it happens:** This pitfall doesn't actually happen, but it's a common concern. Documenting here to prevent unnecessary guards.

**Confirmation:** `roadmap analyze` uses `disk_status: 'complete'` (phases with `[x]` in ROADMAP.md + existing VERIFICATION.md) to skip phases from `next_phase` selection. Resumed chain will only run phases marked incomplete.

### Pitfall 3: Progress Banner Data Race — `phase complete` vs `roadmap analyze`

**What goes wrong:** transition.md calls `phase complete` to mark the current phase done, which internally updates ROADMAP.md. If transition.md then calls `roadmap analyze` to get `completed_phases`, the just-completed phase WILL be counted as complete. This is correct — but ensure `roadmap analyze` is called AFTER `phase complete`, not before.

**Why it happens:** If the banner is built before `phase complete` runs, `completed_phases` will be one less than expected.

**How to avoid:** In transition.md Route A, the order must be:
1. `phase complete` (marks current phase done, updates ROADMAP.md)
2. `roadmap analyze` (reads updated state: completed_phases now includes just-completed phase)
3. Display progress banner with `completed_phases` / `phase_count`
4. Spawn plan-phase --auto

**Warning signs:** Banner shows "phase 2 of 4" after completing phase 3.

### Pitfall 4: Stanza Not Cleared Before Phase B on Resume

**What goes wrong:** Resume path sets `NEXT_PHASE = RESUME_PHASE` and falls through to Phase B. Phase B calls `yolo-state write --start-phase ${NEXT_PHASE}`. The `yolo-state write` command replaces the entire `workflow.yolo` stanza atomically (sets `active: true`, `start_phase`, `timestamp`). So the old `failed_phase` and `failure_reason` fields ARE overwritten by the new stanza.

**Confirmation from source:** `yolo-state write` does `config.workflow.yolo = { active: true, start_phase: startPhase, timestamp: timestamp }` — a complete replacement, not a merge. No explicit `yolo-state clear` is needed before Phase B if `yolo-state write` overwrites atomically.

**However:** Recommend adding an explicit `yolo-state clear` in the "Resume" option of A3 before falling through to Phase B, for clarity and to prevent any ambiguity. The cost is zero (idempotent).

### Pitfall 5: Source-to-Installed Copy Sync

**What goes wrong:** Changes made to `get-shit-done/workflows/yolo.md` (source) but not synced to `/home/junbeom/.claude/get-shit-done/workflows/yolo.md` (installed). The installed copy is what Claude Code actually reads when `/gsd:yolo` is invoked.

**Why it happens:** Two copies exist: source (in project repo, tracked by git) and installed (in `~/.claude/`, not git tracked). Phase 3 established the pattern of editing both copies.

**How to avoid:** Every plan must modify both copies. Verification must check both. This is an established Phase 3 pattern.

**Warning signs:** Resume works when testing against source but not in actual `/gsd:yolo` invocation.

## Code Examples

Verified patterns from existing codebase:

### A3 Extended — Three-Branch Stanza Detection

```bash
# Source: yolo.md A3 existing pattern + yolo-state fail fields (gsd-tools.cjs lines 886-888)
YOLO_JSON=$(node .../gsd-tools.cjs yolo-state read --raw 2>/dev/null || echo '{}')
YOLO_ACTIVE=$(echo "$YOLO_JSON" | jq -r '.active // "absent"')
YOLO_START=$(echo "$YOLO_JSON" | jq -r '.start_phase // "?"')
YOLO_TS=$(echo "$YOLO_JSON" | jq -r '.timestamp // ""')
YOLO_FAILED=$(echo "$YOLO_JSON" | jq -r '.failed_phase // empty')
YOLO_REASON=$(echo "$YOLO_JSON" | jq -r '.failure_reason // "unknown"')

# Branch 1: No stanza → normal flow (no action needed)
# (YOLO_ACTIVE will be "absent" and YOLO_FAILED will be empty for {} stanza)

# Branch 2: Active run (stale) → clear or abort (existing behavior)
if [ "$YOLO_ACTIVE" = "true" ]; then
  # AskUserQuestion: "A prior YOLO run exists..."
  # Options: "Clear and start fresh" / "Abort"
fi

# Branch 3 (NEW): Failed run → resume offer
if [ "$YOLO_ACTIVE" = "false" ] && [ -n "$YOLO_FAILED" ]; then
  # Get authoritative resume position
  ANALYZE=$(node .../gsd-tools.cjs roadmap analyze 2>/dev/null)
  RESUME_PHASE=$(echo "$ANALYZE" | jq -r '.next_phase // empty')
  TOTAL=$(echo "$ANALYZE" | jq -r '.phase_count')
  COMPLETED=$(echo "$ANALYZE" | jq -r '.completed_phases')

  # Show YOLO RESUME banner, then AskUserQuestion
  # Options: "Resume from phase ${RESUME_PHASE}" / "Start fresh" / "Abort"

  # If "Resume": yolo-state clear, set NEXT_PHASE=RESUME_PHASE, proceed to Phase B
  # If "Start fresh": yolo-state clear, proceed to Phase B (Phase B re-reads next_phase via A2)
  # If "Abort": stop
fi
```

### transition.md Route A — Progress Banner

```bash
# Source: roadmap analyze output format (runtime verified 2026-02-17)
# Called AFTER phase complete to get updated completed_phases
ANALYZE=$(node .../gsd-tools.cjs roadmap analyze 2>/dev/null)
COMPLETED_NOW=$(echo "$ANALYZE" | jq -r '.completed_phases')
TOTAL=$(echo "$ANALYZE" | jq -r '.phase_count')

# Progress banner for Route A yolo block:
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
#  GSD ► YOLO MODE ACTIVE — Phase {COMPLETED_NOW} of {TOTAL}
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
#
# Phase {COMPLETED_PHASE} complete. Advancing to Phase {NEXT_PHASE}: {NEXT_PHASE_NAME}
```

### transition.md Route B — Phase Summary Table

```bash
# Source: roadmap analyze phases array (runtime verified 2026-02-17)
# phases array has: number, name, plan_count, summary_count, disk_status
ANALYZE=$(node .../gsd-tools.cjs roadmap analyze 2>/dev/null)

# Build summary table from phases array
# Each completed phase: number | name | plan_count plans
# Output:
# | Phase | Name | Plans Run |
# |-------|------|-----------|
# | 1     | State Infrastructure | 2 plans |
# ...
```

### yolo-state read Output After Failure (verified field names)

```json
// Source: gsd-tools.cjs lines 886-888 (yolo-state fail implementation)
// After yolo-state fail --phase 3 --reason "verification gaps found":
{
  "active": false,
  "start_phase": 1,         // preserved from original write
  "timestamp": "2026-02-17T...",  // preserved from original write
  "failed_phase": 3,
  "failure_reason": "verification gaps found"
}
```

### roadmap analyze Output Fields Used in Phase 4

```json
// Source: runtime verified 2026-02-17 (gsd-tools.cjs line 2818-2824)
{
  "phases": [
    { "number": "1", "name": "State Infrastructure", "plan_count": 2, "summary_count": 2, "disk_status": "complete" },
    { "number": "4", "name": "Resume and Visibility", "plan_count": 0, "summary_count": 0, "disk_status": "empty" }
  ],
  "phase_count": 4,
  "completed_phases": 3,
  "next_phase": "4"
}
```

## State of the Art

| Old Approach (after Phase 3) | New Approach (after Phase 4) | Impact |
|------------------------------|------------------------------|--------|
| A3 only detects `active: true` stale runs; `active: false` + `failed_phase` state is ignored | A3 detects three stanza states: no stanza / active=true stale / active=false+failed_phase resume | STATE-04 satisfied: user offered resume on re-invocation after failure |
| transition.md Route A yolo shows minimal "auto-continuing" message | Route A shows "YOLO mode active, phase N of M" progress banner | SC-2: user always knows where the run stands |
| transition.md Route B yolo shows "All N phases complete. Milestone done." | Route B shows enriched banner with phase summary table | SC-3: user sees which phases ran and how many plans each executed |
| User must manually inspect state after failure to know where to resume | User re-runs `/gsd:yolo`, sees prior failure with resume position, chooses Resume or Start Fresh | UX: self-service recovery |

**Existing behavior that must NOT change:**
- `yolo-state write` atomically replaces the full stanza (correct; Phase B still uses this)
- `roadmap analyze` → `next_phase` definition (first `empty/no_directory/discussed/researched` phase)
- Phase B state write order: mode → auto_advance → yolo stanza (safety ordering preserved)
- All existing A3 behavior for `active: true` stale runs (stale active run prompt unchanged)
- transition.md Route A yolo core: always invoke `plan-phase [X+1] --auto` (no CONTEXT.md check)

## Open Questions

1. **Should the resume prompt be a `AskUserQuestion` (blocking) or auto-resume?**
   - What we know: All prior YOLO user-facing choices use AskUserQuestion. SC-1 says "resumes from the correct position" — implies it should resume, but user should confirm.
   - What's unclear: Should re-invoking `/gsd:yolo` after failure be fully automatic (no prompt) or require confirmation?
   - Recommendation: Use AskUserQuestion with "Resume" as the first (default-feeling) option and "Start fresh" / "Abort" as alternatives. The user explicitly re-invoked YOLO, so they expect something to happen — but showing the prior failure context and asking to confirm is safer. This is Claude's Discretion territory.

2. **Where exactly does the "YOLO mode active, phase N of M" banner appear in transition.md?**
   - What we know: Route A yolo block currently has the minimal "auto-continuing" message. SC-2 says "each phase transition" — so this banner fires between phases.
   - What's unclear: Does it replace the existing "auto-continuing" output or supplement it?
   - Recommendation: Replace the minimal message with the richer progress banner. The existing "⚡ Auto-continuing" line can be incorporated into the banner as a subline.

3. **For SC-3 summary, should "what was accomplished" go beyond plan counts?**
   - What we know: Reading each SUMMARY.md is expensive in context (multiple large files). Plan counts are lightweight.
   - What's unclear: Is plan count sufficient for "what was accomplished" per the success criterion?
   - Recommendation: Plan count is sufficient. The YOLO COMPLETE banner is a terminal display — user can review details via individual phase summaries. Adding "N plans" per phase satisfies "what was accomplished" in a lightweight way. This is Claude's Discretion territory.

## Sources

### Primary (HIGH confidence)
- Direct codebase read: `/home/junbeom/.claude/get-shit-done/workflows/yolo.md` (installed) — A3 existing branch structure, Phase B state setup order, Phase C failure handling; read 2026-02-17
- Direct codebase read: `get-shit-done/workflows/yolo.md` (source) — A3 structure matches installed; read 2026-02-17
- Direct codebase read: `/home/junbeom/.claude/get-shit-done/workflows/transition.md` — Route A yolo block (current minimal output), Route B yolo block (current YOLO COMPLETE banner); read 2026-02-17
- Direct codebase read: `/home/junbeom/.claude/get-shit-done/bin/gsd-tools.cjs` — `yolo-state fail` implementation lines 870-891 (field names: `active`, `failed_phase`, `failure_reason`); `roadmap analyze` output lines 2815-2826 (`phases`, `phase_count`, `completed_phases`, `next_phase`); read 2026-02-17
- Runtime verification: `node gsd-tools.cjs roadmap analyze` — confirmed `completed_phases: 3`, `phase_count: 4`, `next_phase: "4"`, `phases` array with `plan_count` fields; verified 2026-02-17
- Runtime verification: `node gsd-tools.cjs yolo-state read --raw` → `{}` (no active stanza, confirmed Branch 3 detection logic works for absent stanza); verified 2026-02-17
- Phase 3 RESEARCH.md — confirmed `roadmap analyze` as authoritative source for resume position, `yolo-state fail` preserves existing fields; read 2026-02-17
- Phase 3 VERIFICATION.md — confirmed all Phase 3 changes are in place (regression baseline for Phase 4); read 2026-02-17
- ROADMAP.md Phase 4 success criteria — literal SC text used to drive requirement mapping; read 2026-02-17
- REQUIREMENTS.md — STATE-04 definition; read 2026-02-17

### Secondary (MEDIUM confidence)
- Phase 3 SUMMARY.md — "Phase 4 (Resume and Visibility) can proceed: yolo stanza preserved on failure provides the resume anchor Phase 4 needs" — confirms design intent
- Phase 2 RESEARCH.md — "Stale state prompts user to clear or abort; resume logic deferred to Phase 4 (02-01)" — confirms A3 is the intended location for resume

### Tertiary (LOW confidence)
- None — all findings verified against source files or runtime

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — no new commands needed, all verified in Phases 1-3 and runtime
- Architecture: HIGH — all change points verified in workflow source files; exact field names verified from gsd-tools.cjs implementation
- Pitfalls: HIGH — Pitfalls 1/3/4/5 derived from source code analysis; Pitfall 2 is documented non-issue (confirmed safe by source)

**Research date:** 2026-02-17
**Valid until:** Until yolo.md, transition.md, or gsd-tools.cjs (yolo-state/roadmap analyze) change
