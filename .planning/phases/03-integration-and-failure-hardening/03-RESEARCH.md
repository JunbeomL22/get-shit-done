# Phase 3: Integration and Failure Hardening - Research

**Researched:** 2026-02-17
**Domain:** GSD workflow integration, auto-advance chain, failure propagation, state lifecycle
**Confidence:** HIGH

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

**Phase chain flow**
- In YOLO mode, plan-phase auto-skips the "No CONTEXT.md" gate — plans with research + requirements only, no user prompt
- verify-work runs as part of execute-phase's existing flow — YOLO does not insert it as a separate step
- The existing auto-chain pipeline (plan-phase → execute-phase → verify → advance) is used as-is; YOLO's job is to ensure the flags stay set so the chain doesn't break

**Failure stop behavior**
- On verification failure, keep the yolo stanza in config.json intact — Phase 4 (resume) needs it to detect where we stopped
- On failure stop, show: phase number that failed + specific unmet requirements from verify-work — no resume command (user figures out next step)
- Distinguish verification failures from unexpected errors: verification failures show gaps found; unexpected errors (agent crash, tool failure) show the raw error and suggest manual investigation

**Milestone completion**
- On milestone completion, just stop with a banner — no suggested next steps
- YOLO does not chain into the next milestone (MILE-01)

### Claude's Discretion
- Transition behavior: determine minimal change needed to keep auto_advance alive during YOLO (whether to modify transition.md or re-set flag on each phase)
- auto_advance protection strategy: pick safest approach for the existing pipeline (YOLO stanza as guard vs re-write on each transition)
- Milestone boundary detection method: pick most reliable way to know we're on the last phase
- Completion display format: pick appropriate summary output
- State cleanup on completion: decide what to clean (yolo stanza, auto_advance, mode) based on Phase 1/2 setup
- auto_advance handling on failure: pick based on safety and resume implications

### Deferred Ideas (OUT OF SCOPE)
None — discussion stayed within phase scope
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| CHAIN-02 | Each phase runs plan → execute → verify → advance automatically | The auto-chain pipeline is already wired via `workflow.auto_advance` flag read by plan-phase Step 14 and execute-phase offer_next step; Phase 3 must ensure this flag is not prematurely cleared and that plan-phase's CONTEXT.md gate is bypassed in YOLO mode |
| FAIL-01 | YOLO hard-stops when verification finds gaps (requirements not met) | execute-phase `verify_phase_goal` step already stops the auto-advance chain when `gaps_found` (skips offer_next); Phase 3 must capture this condition in yolo.md and write the failure state |
| FAIL-02 | On stop, user sees which phase failed, what went wrong, and how to recover | VERIFICATION.md written by gsd-verifier contains structured gap data; yolo.md post-Task() detection reads roadmap + VERIFICATION.md to produce the failure report |
| MILE-01 | YOLO stops after the last phase completes (does not chain into next milestone) | transition.md Route B already detects `is_last_phase: true` from `phase complete`; in yolo mode it currently invokes complete-milestone — must be changed to stop with a banner instead |
</phase_requirements>

## Summary

Phase 3 wires the existing auto-chain pipeline for YOLO mode by making three targeted changes to existing workflow files and enhancing yolo.md's post-Task() handling. The auto-chain (plan-phase → execute-phase → verify → transition) is already built and works when `workflow.auto_advance` is true. Phase 3 addresses four gaps that prevent the chain from running correctly in YOLO mode:

The first gap is plan-phase Step 4, which uses `AskUserQuestion` when no CONTEXT.md is found. In YOLO mode this would block the unattended chain. The locked decision says plan-phase must auto-skip this gate. A minimal change to plan-phase.md adds an auto-skip condition when `workflow.auto_advance` is true.

The second and third gaps are in transition.md. Route B (milestone complete) in yolo mode currently invokes `SlashCommand("/gsd:complete-milestone")` — the locked decision says to stop with a banner instead. Additionally, transition.md clears `workflow.auto_advance false` at milestone boundary before the yolo check, which would break the flag for any subsequent phases if the check order is wrong. The fix is to guard this clear with a YOLO active check, or simply not clear it in yolo mode and let yolo.md own cleanup.

The fourth gap is yolo.md's post-chain handling. Currently yolo.md fires a Task() for plan-phase and handles only `## PLANNING COMPLETE` / `## PLANNING INCONCLUSIVE` — it does not handle the full chain completion signal, verification failures within execute-phase, or milestone completion. Phase 3 extends yolo.md with post-chain state analysis: read `roadmap analyze` and VERIFICATION.md after the Task() returns to determine what happened, then write appropriate state and display appropriate output.

**Primary recommendation:** Three targeted workflow file edits (plan-phase.md Step 4, transition.md Route A yolo, transition.md Route B yolo) plus yolo.md Phase C return-handler expansion. No new gsd-tools commands needed — all state operations use existing `yolo-state fail`, `yolo-state clear`, `roadmap analyze`, `config-get workflow.yolo.active`.

## Standard Stack

### Core
| Tool | Version | Purpose | Why Standard |
|------|---------|---------|--------------|
| `gsd-tools yolo-state fail` | Phase 1 (built) | Record failure: sets active=false, failed_phase, failure_reason | Already exists, Phase 1 built it specifically for this purpose |
| `gsd-tools yolo-state clear` | Phase 1 (built) | Remove yolo stanza on milestone success | Already exists |
| `gsd-tools roadmap analyze` | existing | Post-chain state detection: next_phase, completed_phases, phase_count | Already used in yolo.md Phase A; reuse in Phase C detection |
| `gsd-tools config-get workflow.yolo.active` | existing | Guard: check if YOLO is active before transition.md clears auto_advance | Established in Phase 1/2 |
| `gsd-tools config-set workflow.auto_advance false` | existing | Cleanup on YOLO completion or failure | Already in transition.md Route B; Phase 3 guards when it runs |

### No New Commands Needed
All operations are covered by existing gsd-tools commands. Phase 3 is pure workflow file changes.

**Installation:** No new packages or commands.

## Architecture Patterns

### Recommended File Change Surface

```
~/.claude/get-shit-done/workflows/
├── plan-phase.md          # Change Step 4: add YOLO auto-skip condition
├── transition.md          # Change Route A (yolo): always go to plan-phase --auto
│                          # Change Route B (yolo): stop with banner, skip complete-milestone
└── yolo.md                # Extend Phase C return handler: chain result analysis
```

No new files. Four targeted edits across three existing files.

### Pattern 1: plan-phase Step 4 Auto-Skip (CHAIN-02)

**What:** When `workflow.auto_advance` is true (YOLO mode), plan-phase skips the "No CONTEXT.md" AskUserQuestion and proceeds with research + requirements only.

**Current behavior (Step 4):**
```markdown
If `context_content` is null (no CONTEXT.md exists):
  Use AskUserQuestion:
  - "Continue without context" → Proceed
  - "Run discuss-phase first" → Exit
```

**Change:**
```markdown
If `context_content` is null (no CONTEXT.md exists):
  Check AUTO_CFG:
    AUTO_CFG=$(node .../gsd-tools.cjs config-get workflow.auto_advance 2>/dev/null || echo "false")

  If `--auto` flag present OR AUTO_CFG is "true":
    Log: "No CONTEXT.md — auto-continuing with research + requirements (YOLO mode)"
    Proceed to step 5 (no user prompt)
  Else:
    Use AskUserQuestion (existing behavior)
```

**Confidence:** HIGH — the check pattern matches Step 14's auto-advance check exactly; minimal change.

### Pattern 2: transition.md Route A yolo Mode (CHAIN-02)

**What:** Currently transition.md Route A checks if CONTEXT.md exists for the next phase before deciding to invoke discuss-phase or plan-phase. In yolo mode with the new auto-skip, plan-phase can handle missing CONTEXT.md. So Route A in yolo mode should always invoke plan-phase --auto.

**Current behavior (Route A, yolo mode):**
```markdown
If CONTEXT.md exists: SlashCommand("/gsd:plan-phase [X+1] --auto")
If CONTEXT.md does NOT exist: SlashCommand("/gsd:discuss-phase [X+1] --auto")
```

**Change:** In yolo mode, always invoke plan-phase --auto (skip the CONTEXT.md check):
```markdown
If mode="yolo":
  SlashCommand("/gsd:plan-phase [X+1] --auto")
  [Plan-phase handles missing CONTEXT.md via auto-skip — no discuss-phase needed]
```

**Why:** discuss-phase --auto would set auto_advance and spawn plan-phase anyway, but adds a round-trip and extra code path. Since plan-phase now auto-skips the CONTEXT.md gate in YOLO mode, going directly to plan-phase is simpler and more direct.

**Confidence:** HIGH — follows the locked decision exactly; matches the chain flow described in CONTEXT.md.

### Pattern 3: transition.md Route B yolo Mode — Stop with Banner (MILE-01)

**What:** When `is_last_phase: true` in yolo mode, stop with a completion banner instead of chaining into complete-milestone.

**Current behavior (Route B, yolo mode):**
```markdown
node .../config-set workflow.auto_advance false
SlashCommand("/gsd:complete-milestone {version}")
```

**Change:**
```markdown
# Route B, yolo mode:
# 1. Clean up YOLO state (milestone complete = success)
node .../gsd-tools.cjs yolo-state clear
node .../gsd-tools.cjs config-set workflow.auto_advance false

# 2. Show completion banner (do NOT invoke complete-milestone)
Show:
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
 GSD ► YOLO COMPLETE
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

All {N} phases complete. Milestone done.

[Summary table: phase | plans executed]

Stop here. Return to user.
```

**Why clear yolo stanza here vs. in yolo.md:** transition.md is the natural milestone boundary. When Route B executes in yolo mode, the milestone is definitively complete. Clearing state here is cleaner than doing it in yolo.md post-Task() (which may not reliably detect milestone complete). The yolo.md Phase C handler can verify the cleanup happened.

**auto_advance handling on failure:** On verification failure, execute-phase stops before reaching transition.md — so transition.md's `config-set workflow.auto_advance false` never runs. This means `workflow.auto_advance` stays `true` after a failure stop. This is intentional: Phase 4's resume flow needs YOLO to be detectable via the yolo stanza (`active: false` + `failed_phase` set), and auto_advance being true is a secondary signal. The planner should decide: clear auto_advance in yolo-state fail (in yolo.md Phase C failure handler) to prevent unexpected auto-advance on next manual command. Recommendation: YES — clear auto_advance when writing failure state.

### Pattern 4: yolo.md Phase C — Chain Result Analysis

**What:** Extend yolo.md Phase C's Task() return handler to detect chain outcome and display appropriate output.

**Current behavior (Phase C return handler):**
```markdown
If plan-phase returns `## PLANNING COMPLETE` → display summary
If plan-phase returns `## PLANNING INCONCLUSIVE` → display failure, show recovery
```

This only handles plan-phase failures, not the full chain.

**The challenge:** The Task() wraps plan-phase, which chains to execute-phase, which chains to transition.md, which potentially chains through multiple phases via SlashCommand. The Task() doesn't return until the entire chain completes or fails. The return value is whatever the last command in the chain outputs.

**What returns from the chain:**
- If the chain runs all phases successfully and hits Route B (milestone): transition.md shows the YOLO COMPLETE banner, then returns. The Task() return looks like a success.
- If the chain stops at a verification failure: execute-phase shows "Gaps Found" output, skips auto-advance, and returns. The Task() return includes the gaps output.
- If the chain stops at plan-phase failure: plan-phase returns `## PLANNING INCONCLUSIVE`. Same as current behavior.
- If unexpected error: the Task() may return with an error or partial output.

**Post-Task() state analysis approach (Claude's Discretion):**
After Task() returns, yolo.md reads state from disk to determine what happened:

```bash
# 1. Check if yolo stanza was cleared (milestone complete path clears it)
YOLO_STATE=$(node .../gsd-tools.cjs yolo-state read --raw 2>/dev/null || echo '{}')
YOLO_ACTIVE=$(echo "$YOLO_STATE" | jq -r '.active // "absent"')

# 2. Check roadmap state
ANALYZE=$(node .../gsd-tools.cjs roadmap analyze 2>/dev/null)
NEXT_PHASE=$(echo "$ANALYZE" | jq -r '.next_phase // empty')
COMPLETED=$(echo "$ANALYZE" | jq -r '.completed_phases')
TOTAL=$(echo "$ANALYZE" | jq -r '.phase_count')

# Case A: All phases complete + stanza cleared = milestone success (handled by Route B)
if [ -z "$NEXT_PHASE" ] && [ "$YOLO_ACTIVE" = "absent" ]; then
  # Milestone complete banner already shown by transition.md; yolo.md echoes confirmation
  # Nothing more to do

# Case B: Phases incomplete = something stopped the chain
elif [ -n "$NEXT_PHASE" ]; then
  STOPPED_PHASE="$NEXT_PHASE"
  # Read VERIFICATION.md for the stopped phase to get gap details
  PHASE_DIR=$(echo "$ANALYZE" | jq -r --arg p "$STOPPED_PHASE" '.phases[] | select(.number == $p) | .dir // empty')
  # ... read VERIFICATION.md from phase dir to extract gaps

  # Write failure state
  node .../gsd-tools.cjs yolo-state fail --phase "$STOPPED_PHASE" --reason "verification gaps found"
  node .../gsd-tools.cjs config-set workflow.auto_advance false

  # Display FAIL-02 output: phase number, specific gaps
```

**Why state-based (not return-value-based):** The Task() return value is a natural language block that varies by context. Parsing it reliably is fragile. Disk state (config.json, roadmap, VERIFICATION.md) is machine-readable and authoritative.

**Confidence:** HIGH — roadmap analyze and yolo-state read are already used in Phase A of yolo.md; VERIFICATION.md path follows the same pattern as execute-phase's own verification step.

### Pattern 5: FAIL-02 Display Format

**What:** On verification failure, show the user: phase number, specific unmet requirements, and NO resume command.

**Source for gap details:** `{phase_dir}/{phase_num}-VERIFICATION.md` — written by the gsd-verifier agent. Contains the `gaps` section with structured failure data.

```bash
# Read VERIFICATION.md gap data
VERIFY_FILE=$(ls ".planning/phases/"*"${STOPPED_PHASE}-"*"/"*"-VERIFICATION.md" 2>/dev/null | head -1)
```

**Display format:**
```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
 GSD ► YOLO STOPPED — Phase {N}
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Verification failed: Phase {N} has unmet requirements.

**What was missing:**
{gaps from VERIFICATION.md — each gap's "truth" field}

YOLO state preserved. Check .planning/phases/{dir}/{N}-VERIFICATION.md for full report.
```

**Unexpected error format (different from gaps_found):**
```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
 GSD ► YOLO STOPPED — Unexpected Error
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

{raw error from Task() return}

This may be an agent crash or tool failure. Investigate manually.
YOLO state preserved at Phase {N}.
```

**How to distinguish gaps_found from unexpected error:**
- gaps_found: `roadmap analyze` shows `disk_status: "verified_fail"` or VERIFICATION.md exists with `status: gaps_found`
- unexpected error: VERIFICATION.md is absent for the stopped phase, or Task() returned a non-standard error

### Anti-Patterns to Avoid

- **Parsing Task() return text to detect success/failure:** Natural language output is unpredictable. Always use disk state (config.json, VERIFICATION.md, ROADMAP.md) as the authoritative signal.
- **Clearing `workflow.auto_advance` in execute-phase:** execute-phase does not own the YOLO lifecycle. Only transition.md (Route B) and yolo.md Phase C should clear it.
- **Invoking `complete-milestone` from transition.md in yolo mode:** User locked decision says milestone completion = stop with banner. Complete-milestone is a separate interactive command the user runs after review.
- **Modifying execute-phase.md:** The user decision says verify-work is already part of execute-phase's flow and YOLO does not insert separate steps. Do not touch execute-phase.md.
- **Modifying verify-work.md:** verify-work is an interactive command (UAT sessions, user confirms each test). In YOLO mode, the gsd-verifier agent runs automatically within execute-phase — verify-work.md is not in the chain. Do not confuse the two.
- **Forgetting to clear auto_advance on failure:** If auto_advance stays `true` after a YOLO failure stop, the next manual `/gsd:plan-phase N` will auto-advance unexpectedly. Clear it in the failure handler.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Detect milestone complete | Parse ROADMAP.md text | `roadmap analyze` → `next_phase empty` | Already used; handles all edge cases |
| Find VERIFICATION.md path | String concatenation | `roadmap analyze` phases array + known naming convention | Consistent with Phase 1/2 patterns |
| Write failure state | Direct config.json edit | `yolo-state fail --phase N --reason "text"` | Phase 1 built this specifically for the failure path |
| Clear YOLO state on success | Direct config.json edit | `yolo-state clear` | Idempotent, atomic, verified by Phase 1 tests |
| Detect verification vs unexpected error | Text parsing | Check VERIFICATION.md existence + status field | Machine-readable, reliable |

**Key insight:** Phase 3 does not need any new gsd-tools commands. All state operations are covered by Phase 1's yolo-state commands and existing config/roadmap commands.

## Common Pitfalls

### Pitfall 1: transition.md auto_advance Clear Runs Before YOLO Check

**What goes wrong:** transition.md Route B runs `config-set workflow.auto_advance false` unconditionally BEFORE checking `is_last_phase`. If there are multiple phases and the clear happens at phase N-1, the chain breaks at phase N.

**Why it happens:** The current transition.md Route B is:
```
node .../config-set workflow.auto_advance false
[if yolo mode] SlashCommand complete-milestone
```
The clear happens regardless of mode. If this ran at a non-last-phase boundary (which it shouldn't — Route B only fires when is_last_phase is true), it would break the chain. This is actually fine as written, but the order matters for the yolo-mode edit.

**How to avoid:** In the Route B yolo mode edit, clear auto_advance AFTER stopping the chain (not before). Sequence: show YOLO COMPLETE banner → `yolo-state clear` → `config-set workflow.auto_advance false`. This ensures auto_advance is cleared only at the definitive end.

**Warning signs:** Chain stops after first phase completes; subsequent phases don't run.

### Pitfall 2: VERIFICATION.md Not Present When Chain Stops

**What goes wrong:** The chain stops because an agent crashed (not a verification failure). VERIFICATION.md was never written. Post-Task() detection reads the file and gets FileNotFoundError.

**Why it happens:** Verification failure and agent crash both result in the chain stopping before completion, but only verification failure produces a VERIFICATION.md.

**How to avoid:** Check for VERIFICATION.md existence before reading. If absent, treat as unexpected error (show raw error, not gaps-found format). If present, read `status:` field — `gaps_found` = verification failure, anything else = unexpected state.

**Warning signs:** Post-Task() read of VERIFICATION.md fails; chain returned early without creating verification artifacts.

### Pitfall 3: plan-phase Auto-Skip Triggers in Non-YOLO Manual Runs

**What goes wrong:** A user manually runs `/gsd:plan-phase 4` and `workflow.auto_advance` happens to be `true` (left over from a previous YOLO run that wasn't cleaned up). The CONTEXT.md gate is auto-skipped even though the user might have wanted to discuss-phase first.

**Why it happens:** The auto-skip condition checks `workflow.auto_advance`, which is a persistent config key.

**How to avoid:** The Phase 1 decision is that YOLO state left over from a prior run is cleaned up at /gsd:yolo launch (stale state check A3). If a user manually runs plan-phase with auto_advance=true left over, that's already a known risk (documented in Phase 2 Pitfall 2). The Phase 3 plan-phase edit should check BOTH `--auto` flag AND `workflow.auto_advance` — consistent with the existing pattern in Step 14.

**Warning signs:** plan-phase skips CONTEXT.md gate when user invokes it manually without expecting unattended behavior.

### Pitfall 4: SlashCommand vs Task() in transition.md Route A

**What goes wrong:** transition.md Route A currently uses `SlashCommand("/gsd:plan-phase [X+1] --auto")` to advance. This exits the current agent and spawns a new one. If the change to "always invoke plan-phase in yolo mode" accidentally removes the --auto flag, the chain breaks at the next phase.

**Why it happens:** Editing transition.md's Route A logic is straightforward, but the `--auto` flag must be preserved.

**How to avoid:** The edit to Route A yolo mode is minimal: remove the CONTEXT.md check and always invoke `SlashCommand("/gsd:plan-phase [X+1] --auto")` regardless of whether CONTEXT.md exists. The `--auto` flag must appear in the SlashCommand.

**Warning signs:** Chain pauses at plan-phase "Auto-Advance Check" step because `--auto` is missing and `workflow.auto_advance` was cleared.

### Pitfall 5: Circular Detection After Route B Cleanup

**What goes wrong:** yolo.md Phase C post-Task() handler reads `yolo-state read` to detect milestone completion. But if transition.md Route B already called `yolo-state clear`, the stanza is gone and `yolo-state read` returns `{}`. yolo.md then doesn't know if the chain succeeded (all phases done, stanza cleared) or if the stanza was never written (shouldn't happen but worth guarding).

**Why it happens:** Both milestone completion (Route B) and absence of stanza are represented as `{}` from `yolo-state read`.

**How to avoid:** Use `roadmap analyze` as the primary signal, not `yolo-state read`. Milestone success = `next_phase` is null/empty AND `completed_phases == phase_count`. Stanza state is secondary confirmation.

## Code Examples

Verified patterns from existing codebase:

### Plan-Phase Step 4 Auto-Skip Condition
```bash
# Source: plan-phase.md Step 14 auto-advance pattern + config-get established pattern
AUTO_CFG=$(node /home/junbeom/.claude/get-shit-done/bin/gsd-tools.cjs config-get workflow.auto_advance 2>/dev/null || echo "false")

# In Step 4, before AskUserQuestion:
if [ "${FLAGS_AUTO}" = "true" ] || [ "$AUTO_CFG" = "true" ]; then
  # Auto-skip: log and proceed to step 5
  echo "No CONTEXT.md — auto-continuing with research + requirements (YOLO mode)"
  # Fall through to step 5
else
  # Existing AskUserQuestion behavior
fi
```

### transition.md Route A Yolo Mode (Simplified)
```markdown
**Route A, yolo mode:**

<!-- No CONTEXT.md check needed — plan-phase handles the gate -->
Phase [X] marked complete.

Next: Phase [X+1] — [Name]

⚡ Auto-continuing: Plan Phase [X+1]

Exit skill and invoke SlashCommand("/gsd:plan-phase [X+1] --auto")
```

### transition.md Route B Yolo Mode (Stop with Banner)
```markdown
**Route B, yolo mode:**

<!-- Do NOT invoke complete-milestone -->
<!-- Do NOT run config-set workflow.auto_advance false here — yolo.md Phase C owns cleanup -->
<!-- Actually: yolo-state clear + auto_advance false happen here since this is the natural endpoint -->

node .../gsd-tools.cjs yolo-state clear
node .../gsd-tools.cjs config-set workflow.auto_advance false

Show:
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
 GSD ► YOLO COMPLETE 🎉
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

All {N} phases complete.

| Phase | Status |
|-------|--------|
| {N}   | Done   |

Stop. Return.
```

### yolo.md Phase C Post-Task() Detection
```bash
# Source: roadmap analyze + yolo-state read patterns established in Phase A
ANALYZE=$(node /home/junbeom/.claude/get-shit-done/bin/gsd-tools.cjs roadmap analyze 2>/dev/null)
NEXT_PHASE=$(echo "$ANALYZE" | jq -r '.next_phase // empty')
COMPLETED=$(echo "$ANALYZE" | jq -r '.completed_phases')
TOTAL=$(echo "$ANALYZE" | jq -r '.phase_count')

YOLO_STATE=$(node /home/junbeom/.claude/get-shit-done/bin/gsd-tools.cjs yolo-state read --raw 2>/dev/null || echo '{}')

if [ -z "$NEXT_PHASE" ]; then
  # Milestone complete — Route B already showed the banner and cleared state
  # Nothing more to do in yolo.md
  echo "Chain complete."
else
  # Chain stopped before completing all phases
  STOPPED_PHASE="$NEXT_PHASE"

  # Check if VERIFICATION.md exists for the stopped phase
  # If yes: verification failure. If no: unexpected error.
  PHASE_DIR=$(ls -d ".planning/phases/"*"-"* 2>/dev/null | grep -E "^.*/0*${STOPPED_PHASE}-" | head -1)
  VERIFY_FILE=$(ls "${PHASE_DIR}/"*"-VERIFICATION.md" 2>/dev/null | head -1)

  if [ -n "$VERIFY_FILE" ]; then
    VERIFY_STATUS=$(grep "^status:" "$VERIFY_FILE" | cut -d: -f2 | tr -d ' ')
    if [ "$VERIFY_STATUS" = "gaps_found" ]; then
      # Verification failure — write state, show FAIL-02 output
      node .../gsd-tools.cjs yolo-state fail --phase "$STOPPED_PHASE" --reason "verification gaps found"
      node .../gsd-tools.cjs config-set workflow.auto_advance false
      # Display phase number + gap details from VERIFICATION.md
    else
      # Unexpected state in VERIFICATION.md
      # Show as unexpected error
    fi
  else
    # No VERIFICATION.md — unexpected error
    node .../gsd-tools.cjs yolo-state fail --phase "$STOPPED_PHASE" --reason "unexpected error — no verification artifact"
    node .../gsd-tools.cjs config-set workflow.auto_advance false
    # Show raw Task() return + manual investigation message
  fi
fi
```

### Finding VERIFICATION.md for a Phase
```bash
# Source: execute-phase.md verify_phase_goal step pattern
# Phase directories are named like "03-integration-and-failure-hardening"
# VERIFICATION.md is named like "03-VERIFICATION.md"
PADDED_PHASE=$(printf "%02d" "$STOPPED_PHASE")
PHASE_DIR=$(ls -d ".planning/phases/${PADDED_PHASE}-"* 2>/dev/null | head -1)
VERIFY_FILE="${PHASE_DIR}/${PADDED_PHASE}-VERIFICATION.md"
```

## State of the Art

| Old Approach | Current Approach (after Phase 3) | Impact |
|--------------|----------------------------------|--------|
| plan-phase always prompts for CONTEXT.md | plan-phase auto-skips when workflow.auto_advance=true | Unblocks YOLO chain on phases without CONTEXT.md |
| transition.md Route B (yolo) → complete-milestone | Stop with YOLO COMPLETE banner | Honors MILE-01; user reviews before archiving |
| yolo.md only detects plan-phase failure | yolo.md detects full chain outcome via disk state | Complete failure handling: verification gaps vs unexpected errors |
| auto_advance not guarded in Route B | auto_advance cleared by YOLO-aware code in Route B | Prevents flag orphan on unexpected termination |

**Existing behavior that works correctly (do not change):**
- execute-phase `verify_phase_goal` step already skips auto-advance when `gaps_found` — FAIL-01 stop behavior is already there
- execute-phase `checkpoint_handling` step already auto-approves `human-verify` and `decision` checkpoints when `AUTO_CFG` is true
- The `workflow.auto_advance` flag propagation through plan-phase Step 14 and execute-phase offer_next is already correct
- transition.md Route A (interactive mode) behavior is unchanged by Phase 3

## Open Questions

1. **Where does yolo.md get the gap details from VERIFICATION.md for display?**
   - What we know: VERIFICATION.md has a structured `## What's Missing` section and `gaps` YAML (from execute-phase.md pattern)
   - What's unclear: The exact field names in VERIFICATION.md's gaps section — gsd-verifier determines the format
   - Recommendation: Read the full VERIFICATION.md content and present the "What's Missing" section verbatim. No parsing needed — just include the relevant sections in the failure display.

2. **Should Route B (milestone complete) display a summary table of all phases run?**
   - What we know: User decision says "just stop with a banner — no suggested next steps"
   - What's unclear: Does "banner" mean minimal (just the completion message) or can it include a phase summary?
   - Recommendation: Include a simple phase summary table (phase | plans executed) since it adds value with minimal complexity. This is Claude's Discretion on completion display format.

3. **What if the Task() from yolo.md returns before ANY phases complete?**
   - What we know: Plan-phase can fail at planning stage (PLANNING INCONCLUSIVE) before execute-phase even runs. In this case VERIFICATION.md won't exist.
   - What's unclear: Is this a "no VERIFICATION.md = unexpected error" case or a distinct "planning failed" case?
   - Recommendation: Handle as a third case: if `NEXT_PHASE == START_PHASE` (the phase YOLO started on is still incomplete), then the Task() returned early from plan-phase. Show the raw Task() return and treat as unexpected error. The yolo stanza has `start_phase` to compare against `next_phase`.

4. **Does transition.md Route A currently use `SlashCommand` or `Task()` for yolo mode?**
   - What we know: Current transition.md shows `SlashCommand("/gsd:plan-phase [X+1] --auto")` for yolo mode Route A
   - What's unclear: Whether `SlashCommand` and `Task()` have different behavior in terms of context propagation in the chain
   - Recommendation: Keep using `SlashCommand` as the current code does. The --auto flag in the SlashCommand is what propagates the chain.

## Sources

### Primary (HIGH confidence)
- Direct codebase read: `/home/junbeom/.claude/get-shit-done/workflows/plan-phase.md` — Step 4 (CONTEXT.md check, AskUserQuestion), Step 14 (auto-advance check); read 2026-02-17
- Direct codebase read: `/home/junbeom/.claude/get-shit-done/workflows/transition.md` — Route A (yolo, CONTEXT.md check, SlashCommand), Route B (auto_advance clear, yolo complete-milestone call); read 2026-02-17
- Direct codebase read: `/home/junbeom/.claude/get-shit-done/workflows/execute-phase.md` — checkpoint_handling (auto-approve logic), verify_phase_goal (gaps_found stop), offer_next (gaps exception); read 2026-02-17
- Direct codebase read: `/home/junbeom/.claude/get-shit-done/workflows/yolo.md` — Phase A/B/C structure, explicit deferral of Phase 3 work, Task() pattern; read 2026-02-17
- Direct codebase read: `/home/junbeom/.claude/get-shit-done/bin/gsd-tools.cjs` — yolo-state read/write/clear/fail (lines 779-896), roadmap analyze output format, is_last_phase computation in phase complete (lines 3387-3406); read 2026-02-17
- Runtime verification: `node gsd-tools.cjs yolo-state read --raw` → `{}` (no active stanza); verified 2026-02-17
- Runtime verification: `node gsd-tools.cjs roadmap analyze` → confirmed next_phase: "3", is_last_phase: null (null from roadmap analyze, field only in phase complete); verified 2026-02-17
- Phase 1 RESEARCH.md and VERIFICATION.md — confirmed yolo-state commands available and tested
- Phase 2 RESEARCH.md and VERIFICATION.md — confirmed yolo.md Phase C deferral scope, stale state handling, auto_advance Pitfall 2

### Secondary (MEDIUM confidence)
- Phase 2 SUMMARY.md Pitfall 2 note: "Phase 3 (guard-rails) can now implement auto_advance cleanup at milestone boundary" — confirms Phase 3 owns this
- REQUIREMENTS.md "Out of Scope" note: "Modifying existing plan-phase/execute-phase/verify-work workflows" — this note predates the discuss-phase decisions; the CONTEXT.md locked decisions supersede it for plan-phase.md. execute-phase.md and verify-work.md remain unmodified.

### Tertiary (LOW confidence)
- None — all findings verified against source files or runtime

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — no new commands needed, all verified in Phases 1/2
- Architecture: HIGH — all four change points verified in workflow source files; patterns match existing code style exactly
- Pitfalls: HIGH — Pitfalls 1-3 verified from source code; Pitfalls 4-5 derived from analysis of transition.md/yolo.md interaction

**Research date:** 2026-02-17
**Valid until:** Until any of plan-phase.md, transition.md, execute-phase.md, or yolo.md change (all workflow files, stable within a milestone)
