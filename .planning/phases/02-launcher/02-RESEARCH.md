# Phase 2: Launcher - Research

**Researched:** 2026-02-17
**Domain:** Claude Code command authoring, GSD workflow orchestration, config.json state management
**Confidence:** HIGH

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| CHAIN-01 | User can invoke `/gsd:yolo` with no args to run all remaining phases | Command file pattern (frontmatter + `<process>` block) established; `roadmap analyze` provides next_phase; plan-phase invocation pattern is known |
| CHAIN-03 | YOLO respects config.json workflow agents (research, plan-check, verifier) | Confirmed: existing plan-phase reads these flags from config.json; yolo must not override them; prerequisite check reads current values to display |
</phase_requirements>

## Summary

Phase 2 builds the `/gsd:yolo` command as a new Claude Code slash command (`commands/gsd/yolo.md`) backed by a workflow (`~/.claude/get-shit-done/workflows/yolo.md`). It is a pure orchestrator: it validates prerequisites, writes state, then invokes `plan-phase` with `--auto`. The existing auto-advance chain in plan-phase and execute-phase handles the rest — YOLO does not re-implement those loops.

The command must address a subtle state ordering problem: `mode: "yolo"` already exists in config.json (set at project creation). What YOLO adds is `workflow.auto_advance: true` and the `workflow.yolo` stanza. These two writes happen before invoking plan-phase, so if the run is interrupted before reaching plan-phase, the stanza exists on disk and can be detected as stale on the next invocation.

The prerequisite check has three parts: (1) structural — does a roadmap exist and is `.planning/` present; (2) positional — is the next phase valid and available to plan; (3) stale-state — does `workflow.yolo.active === true` from a prior run that was never completed or cleaned up. The stale-state check is the most nuanced because it must distinguish "YOLO is mid-run and legitimately active" from "a prior YOLO run failed and left state behind" — but since the launcher is invoked fresh (no existing run in progress), any `active: true` stanza should be treated as stale.

**Primary recommendation:** Implement yolo as a two-file addition (command + workflow), reusing existing gsd-tools CLI commands for all state operations. The workflow has three phases: (1) prerequisite check with user-friendly error messages, (2) state setup (config-set mode, config-set auto_advance, yolo-state write), (3) launch by spawning plan-phase via Task() or SlashCommand.

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| gsd-tools.cjs | existing | All state operations: yolo-state write/read, config-get, config-set, roadmap analyze | All existing GSD commands use this CLI exclusively; never direct file I/O |
| Claude Code slash command (`.md` file) | N/A | Entry point at `commands/gsd/yolo.md` | This is the GSD command registration pattern for all existing commands |
| GSD workflow file | N/A | Logic at `~/.claude/get-shit-done/workflows/yolo.md` | All commands with non-trivial logic delegate to a workflow file via `@-reference` |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| `roadmap analyze` gsd-tools command | existing | Detect next_phase, is_last_phase, phase status | Used in prerequisite check to find which phase to launch |
| `yolo-state read` | existing | Detect stale YOLO state | Used in prerequisite check step |
| `config-set workflow.auto_advance` | existing | Enable auto-chain through plan-phase and execute-phase | Set in state setup before invoking plan-phase |
| `config-set mode` | existing | Set mode to "yolo" | Set in state setup (may already be yolo; idempotent) |
| `yolo-state write --start-phase N` | existing | Atomic stanza creation with read-after-write verification | Called after config-set steps, before plan-phase launch |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Task() to invoke plan-phase | SlashCommand("/gsd:plan-phase N --auto") | Task() is more reliable for subagent spawning with fresh context; SlashCommand is allowed but Task() is the established pattern in discuss-phase and plan-phase auto-advance flows |
| Separate yolo-check gsd-tools command | Inline bash checks in workflow | Inline bash keeps the implementation self-contained; a dedicated gsd-tools command would require gsd-tools.cjs modification (adds Phase 1-style work to Phase 2) |

**Installation:** No new packages. This phase modifies markdown files only.

## Architecture Patterns

### Recommended Project Structure
```
commands/gsd/
└── yolo.md                    # New: slash command entry point

~/.claude/get-shit-done/workflows/
└── yolo.md                    # New: workflow logic
```

### Pattern 1: Command Entry Point (Minimal Command File)
**What:** The command file (`commands/gsd/yolo.md`) is minimal — frontmatter, objective, execution_context @-reference, context block, process delegation.
**When to use:** All non-trivial GSD commands follow this pattern (plan-phase, execute-phase, quick).
**Example:**
```markdown
---
name: gsd:yolo
description: Run all remaining phases automatically without manual intervention
argument-hint: ""
allowed-tools:
  - Read
  - Bash
  - Write
  - Task
  - AskUserQuestion
---
<objective>
Run all remaining phases to completion automatically.
...
</objective>

<execution_context>
@~/.claude/get-shit-done/workflows/yolo.md
@~/.claude/get-shit-done/references/ui-brand.md
</execution_context>

<context>
@.planning/STATE.md
@.planning/ROADMAP.md
</context>

<process>
Execute the yolo workflow from @~/.claude/get-shit-done/workflows/yolo.md end-to-end.
</process>
```

### Pattern 2: Prerequisite Check Block
**What:** Early-exit validation before any state mutation. Uses `roadmap analyze` and `yolo-state read`.
**When to use:** Any command that should fail fast before writing state.
**Example:**
```bash
# Check roadmap exists
ROADMAP_EXISTS=$(node /home/junbeom/.claude/get-shit-done/bin/gsd-tools.cjs init phase-op "2" 2>/dev/null | jq -r '.roadmap_exists')
if [ "$ROADMAP_EXISTS" != "true" ]; then
  # Show error box and exit
fi

# Find next phase to run
ANALYZE=$(node /home/junbeom/.claude/get-shit-done/bin/gsd-tools.cjs roadmap analyze 2>/dev/null)
NEXT_PHASE=$(echo "$ANALYZE" | jq -r '.next_phase // empty')
if [ -z "$NEXT_PHASE" ]; then
  # All phases complete — show milestone complete message and exit
fi

# Check for stale YOLO state
YOLO_STATE=$(node /home/junbeom/.claude/get-shit-done/bin/gsd-tools.cjs yolo-state read --raw 2>/dev/null)
YOLO_ACTIVE=$(echo "$YOLO_STATE" | jq -r '.active // false')
if [ "$YOLO_ACTIVE" = "true" ]; then
  # Stale state — prompt user to clear or abort
fi
```

### Pattern 3: State Setup Before Launch
**What:** Write all state atomically before invoking plan-phase. Order matters: mode first, auto_advance second, yolo stanza third (the yolo stanza is the "point of no return" sentinel).
**When to use:** When a command needs to set up persistent state before handing off to a chain.
**Example:**
```bash
# 1. Ensure mode is yolo (may already be set; config-set is idempotent)
node /home/junbeom/.claude/get-shit-done/bin/gsd-tools.cjs config-set mode "yolo"

# 2. Enable auto-advance (this is what activates the chain in plan-phase and execute-phase)
node /home/junbeom/.claude/get-shit-done/bin/gsd-tools.cjs config-set workflow.auto_advance true

# 3. Write YOLO stanza (sentinel — if this exists on next invocation, it's stale)
node /home/junbeom/.claude/get-shit-done/bin/gsd-tools.cjs yolo-state write --start-phase ${NEXT_PHASE}
```

### Pattern 4: Invoking plan-phase as Task
**What:** Spawn plan-phase as a subagent Task, passing `--auto` to propagate the chain.
**When to use:** When handing off to an existing GSD workflow that handles the rest of the chain.
**Example (from discuss-phase.md):**
```
Task(
  prompt="Run /gsd:plan-phase ${NEXT_PHASE} --auto",
  subagent_type="general-purpose",
  description="Plan Phase ${NEXT_PHASE}"
)
```
Handle return values:
- `## PLANNING COMPLETE` / phase execution success → display summary
- `## PLANNING INCONCLUSIVE` / checkpoint / failure → stop chain, show recovery instructions

### Anti-Patterns to Avoid
- **Writing yolo stanza before mode/auto_advance:** If yolo-state write succeeds but config-set mode fails, the stanza exists but auto-advance is not set. Order: mode → auto_advance → yolo stanza.
- **Reading workflow agents from config and overriding them:** Success Criteria #4 requires YOLO to NOT modify research/plan_check/verifier. Read them only for display; do not config-set them.
- **Invoking plan-phase without --auto:** Without `--auto`, plan-phase stops after planning and waits for user input. The `workflow.auto_advance: true` setting enables the auto-chain, but `--auto` also triggers immediate advance within that session.
- **Treating all `active: true` stanza as fatal:** Stale state should prompt the user (clear and continue, or abort) — not hard-fail. The user may want to resume rather than restart.
- **Using `config-get workflow.auto_advance` to check if already in a chain:** This creates circular detection problems. Use `yolo-state read` active flag instead.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Reading next incomplete phase | Custom ROADMAP.md parser | `gsd-tools roadmap analyze` → `next_phase` | Already handles disk_status, plan/summary counts, decimal phases |
| Writing mode to config | Direct fs.writeFileSync | `gsd-tools config-set mode "yolo"` | Handles path resolution, JSON serialization, file locking |
| Writing auto_advance | Direct JSON edit | `gsd-tools config-set workflow.auto_advance true` | Same; preserves all other config fields |
| YOLO stanza creation | Three separate config-set calls | `gsd-tools yolo-state write --start-phase N` | Atomic write + read-after-write verification; prevents partial states |
| Stale state detection | Timestamp comparison | `yolo-state read` active flag check | Simple boolean: if `active: true` exists from a prior run, it's stale |
| Phase existence check | ROADMAP.md string parsing | `gsd-tools roadmap get-phase N` → `found` field | Handles decimal phases, returns structured data |

**Key insight:** All state operations must go through gsd-tools.cjs. Direct file reads/writes bypass the atomic write pattern and read-after-write verification that Phase 1 established.

## Common Pitfalls

### Pitfall 1: Stale YOLO State After Failed Run
**What goes wrong:** A prior YOLO run fails mid-execution. The `workflow.yolo.active` field remains `true` in config.json. The next `/gsd:yolo` invocation sees active state and must decide: is this a running session or stale state?
**Why it happens:** YOLO sets `active: true` in the stanza before launching plan-phase. If plan-phase fails or the session is cleared, the stanza is not auto-cleaned (Phase 1 decision: preserve state on failure for Phase 4 resume).
**How to avoid:** Prerequisite check reads `yolo-state read`. If `active: true`, prompt the user: "A prior YOLO run exists from phase N (started TIMESTAMP). Clear it and start fresh?" This is a user decision, not an auto-action.
**Warning signs:** Config.json has `workflow.yolo.active: true` but no plan-phase invocation is currently running.

### Pitfall 2: auto_advance Not Cleared After Chain Finishes
**What goes wrong:** YOLO sets `workflow.auto_advance: true`. After the milestone completes, transition.md is supposed to `config-set workflow.auto_advance false` at the milestone boundary. If this doesn't happen, the next non-YOLO `plan-phase` invocation auto-advances unexpectedly.
**Why it happens:** The transition.md `offer_next_phase` step (Route B: milestone complete) includes `config-set workflow.auto_advance false`, but this is in a future phase (Phase 3). Phase 2 (Launcher) does not own cleanup.
**How to avoid:** Document this in the SUMMARY. Phase 2 is responsible only for setting auto_advance, not clearing it. Phase 3 will address the cleanup guard.
**Warning signs:** Running `/gsd:plan-phase N` after a YOLO run auto-advances without being asked.

### Pitfall 3: Skipping CONTEXT.md Check in plan-phase
**What goes wrong:** plan-phase checks for CONTEXT.md and prompts "No context found — continue without context?" when running interactively. In YOLO mode with `--auto`, the plan-phase `workflow.md` step 4 says "If context_content is null → Use AskUserQuestion." With `--auto`, this would block the chain.
**Why it happens:** Looking at plan-phase.md Step 4: "If `context_content` is null → AskUserQuestion." The `--auto` flag behavior here is not explicitly documented — it may or may not auto-select "Continue without context."
**How to avoid:** The `--auto` flag passed to plan-phase should cause it to auto-select "Continue without context" rather than prompting. Verify this behavior in plan-phase.md workflow Step 4 before planning. If the current plan-phase.md does not handle `--auto` in this step, that is a gap to note.
**Warning signs:** plan-phase pauses at "No context found" prompt even with `--auto`.

### Pitfall 4: `config-get workflow.auto_advance` Returns Error (Key Missing)
**What goes wrong:** `config-get workflow.auto_advance` exits with code 1 (key not found) in existing commands. Code like `AUTO_CFG=$(... || echo "false")` handles this gracefully, but if the key is missing before YOLO writes it, dependent code may behave unexpectedly.
**Why it happens:** The existing config.json in this project does not have `workflow.auto_advance` (confirmed: running config-get returns exit 1). YOLO writes it as part of state setup.
**How to avoid:** Always use `config-get workflow.auto_advance 2>/dev/null || echo "false"` pattern (already established in plan-phase, execute-phase, discuss-phase workflows). YOLO itself will write the key before invoking plan-phase.
**Warning signs:** Chain stops unexpectedly in plan-phase or execute-phase auto-advance check.

### Pitfall 5: plan-phase Step 4 Context Check Blocking Auto-Chain
**What goes wrong:** When no CONTEXT.md exists for a phase, plan-phase Step 4 prompts "Continue without context or run discuss-phase first?" This is an `AskUserQuestion` call. In YOLO mode (unattended), this would block the automated run.
**Why it happens:** plan-phase workflow is designed for interactive use. The `--auto` flag is meant to bypass interactive gates but the context check may not be treated as a bypassable gate.
**How to avoid:** YOLO should pass `--auto` to plan-phase AND (if needed) the workflow plan may need to confirm that plan-phase handles `--auto` + no-CONTEXT.md by auto-selecting "Continue without context." This should be verified and if not handled, a note in the plan.
**Warning signs:** The YOLO chain hangs waiting for user input at the "No context found" prompt.

## Code Examples

Verified patterns from official sources (gsd-tools.cjs + workflow files in this codebase):

### Prerequisite Validation Pattern
```bash
# Source: inferred from plan-phase.md Step 1, health.md, execute-phase.md
INIT=$(node /home/junbeom/.claude/get-shit-done/bin/gsd-tools.cjs init phase-op "2" 2>/dev/null)
PLANNING_EXISTS=$(echo "$INIT" | jq -r '.planning_exists')
ROADMAP_EXISTS=$(echo "$INIT" | jq -r '.roadmap_exists')

if [ "$PLANNING_EXISTS" != "true" ] || [ "$ROADMAP_EXISTS" != "true" ]; then
  # Error: no project. Run /gsd:new-project first.
  exit 1
fi
```

### Finding Next Phase
```bash
# Source: transition.md offer_next_phase step
ANALYZE=$(node /home/junbeom/.claude/get-shit-done/bin/gsd-tools.cjs roadmap analyze 2>/dev/null)
NEXT_PHASE=$(echo "$ANALYZE" | jq -r '.next_phase // empty')
COMPLETED=$(echo "$ANALYZE" | jq -r '.completed_phases')
TOTAL=$(echo "$ANALYZE" | jq -r '.phase_count')

if [ -z "$NEXT_PHASE" ]; then
  # All phases complete — milestone done
  exit 0
fi
```

### Stale State Detection
```bash
# Source: yolo-state command in gsd-tools.cjs (Phase 1)
YOLO_JSON=$(node /home/junbeom/.claude/get-shit-done/bin/gsd-tools.cjs yolo-state read --raw 2>/dev/null || echo '{}')
YOLO_ACTIVE=$(echo "$YOLO_JSON" | jq -r '.active // false')
YOLO_START=$(echo "$YOLO_JSON" | jq -r '.start_phase // "?"')
YOLO_TS=$(echo "$YOLO_JSON" | jq -r '.timestamp // ""')

if [ "$YOLO_ACTIVE" = "true" ]; then
  # Prompt: stale YOLO state detected from phase $YOLO_START ($YOLO_TS)
  # Options: 1) Clear and start fresh, 2) Abort
fi
```

### State Setup (Three Config Writes)
```bash
# Source: discuss-phase.md auto_advance step, new-project.md config creation
# 1. Mode (idempotent — likely already "yolo" in this project)
node /home/junbeom/.claude/get-shit-done/bin/gsd-tools.cjs config-set mode "yolo"

# 2. Auto-advance
node /home/junbeom/.claude/get-shit-done/bin/gsd-tools.cjs config-set workflow.auto_advance true

# 3. YOLO stanza (atomic, with verification)
node /home/junbeom/.claude/get-shit-done/bin/gsd-tools.cjs yolo-state write --start-phase "${NEXT_PHASE}"
```

### Spawning plan-phase (from discuss-phase.md auto_advance step)
```
Task(
  prompt="Run /gsd:plan-phase ${NEXT_PHASE} --auto",
  subagent_type="general-purpose",
  description="Plan Phase ${NEXT_PHASE}"
)
```

### Config Display (Not Modification)
```bash
# Source: settings.md, to DISPLAY workflow agents without overriding them
RESEARCH=$(node /home/junbeom/.claude/get-shit-done/bin/gsd-tools.cjs config-get workflow.research 2>/dev/null || echo "true")
PLAN_CHECK=$(node /home/junbeom/.claude/get-shit-done/bin/gsd-tools.cjs config-get workflow.plan_check 2>/dev/null || echo "true")
VERIFIER=$(node /home/junbeom/.claude/get-shit-done/bin/gsd-tools.cjs config-get workflow.verifier 2>/dev/null || echo "true")
# Use these for display/confirmation only — NEVER config-set them
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Manual `/gsd:plan-phase N` per phase | `--auto` flag propagates through plan-phase → execute-phase → transition chain | Existing (built into plan-phase, execute-phase, discuss-phase) | YOLO only needs to set `workflow.auto_advance: true` and invoke plan-phase; the rest is already wired |
| Direct config.json writes | `gsd-tools config-set` / `config-delete` / `yolo-state` commands | Phase 1 (2026-02-17) | Atomic writes with error handling; YOLO must use these, not direct file writes |
| No YOLO state persistence | `workflow.yolo` stanza in config.json | Phase 1 (2026-02-17) | State survives `/clear`; enables stale detection and future resume (Phase 4) |

**Deprecated/outdated:**
- Direct `config.json` file reads/writes: Phase 1 established gsd-tools as the canonical interface. YOLO must not bypass it.

## Open Questions

1. **Does plan-phase handle `--auto` + no CONTEXT.md gracefully?**
   - What we know: plan-phase Step 4 calls AskUserQuestion when no CONTEXT.md; `--auto` flag exists
   - What's unclear: Whether `--auto` causes plan-phase to auto-select "Continue without context" or still prompts
   - Recommendation: Read plan-phase.md Step 4 more carefully during planning. If `--auto` does not bypass the context check, the yolo workflow may need to explicitly pass `--skip-research` or the plan may need to note this as a known gate that will prompt the user.

2. **Should YOLO display workflow agent settings before launching?**
   - What we know: CHAIN-03 says YOLO respects agents without overriding them; success criteria #4
   - What's unclear: Whether the planner should include a "YOLO starting with: research=true, plan-check=true, verifier=true" display step
   - Recommendation: Yes — add a confirmation display showing which agents are enabled. This builds user trust that their config is respected.

3. **What is the exact stale state interaction model?**
   - What we know: `yolo-state read` returns `{}` if no stanza, `{active: true, ...}` if stanza exists
   - What's unclear: Should YOLO offer to resume (use existing start_phase) vs restart fresh?
   - Recommendation: For Phase 2 (Launcher), always offer clear-and-restart or abort. Resume logic is Phase 4's scope (STATE-04). This avoids over-engineering Phase 2.

## Sources

### Primary (HIGH confidence)
- Direct codebase inspection: `/home/junbeom/.claude/get-shit-done/bin/gsd-tools.cjs` — examined yolo-state, config-set, config-get, roadmap analyze implementations
- Direct codebase inspection: `/home/junbeom/.claude/get-shit-done/workflows/plan-phase.md` — auto-advance pattern, Step 4 context check, Task() spawn pattern
- Direct codebase inspection: `/home/junbeom/.claude/get-shit-done/workflows/execute-phase.md` — auto_advance detection, Task() patterns
- Direct codebase inspection: `/home/junbeom/.claude/get-shit-done/workflows/transition.md` — mode detection, auto-advance clearing at milestone boundary
- Direct codebase inspection: `/home/junbeom/.claude/get-shit-done/workflows/discuss-phase.md` — `--auto` flag propagation, config-set auto_advance pattern
- Direct codebase inspection: `commands/gsd/*.md` — command file structure patterns (plan-phase, execute-phase, quick, health)
- Runtime verification: `node gsd-tools.cjs roadmap analyze` — confirmed output format including `next_phase`
- Runtime verification: `node gsd-tools.cjs yolo-state read` — confirmed returns `{}` when no stanza
- Runtime verification: `node gsd-tools.cjs config-get mode` — confirmed returns `"yolo"` for this project
- Runtime verification: `node gsd-tools.cjs config-get workflow.auto_advance` — confirmed exits 1 (key missing, YOLO must write it)
- Runtime verification: `cat .planning/config.json` — confirmed schema: `mode`, `workflow.research/plan_check/verifier`, no `workflow.auto_advance` present

### Secondary (MEDIUM confidence)
- Plan-phase workflow auto-advance step (lines 346-400): discusses `--auto` flag behavior and `AUTO_CFG` check, but the interaction of `--auto` with the AskUserQuestion in Step 4 (no context found) is inferred, not explicitly documented

### Tertiary (LOW confidence)
- None

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — all components already exist and are verified in this codebase
- Architecture: HIGH — command and workflow file patterns are directly observed in 12+ existing commands
- Pitfalls: HIGH — Pitfalls 1, 3, 4 verified by runtime testing; Pitfall 2 and 5 are design-level observations from reading workflow files

**Research date:** 2026-02-17
**Valid until:** Stable (workflows are markdown files, changes tracked in git; valid until any workflow file changes)
