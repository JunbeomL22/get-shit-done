# Architecture Patterns: Auto-Chaining (gsd:yolo)

**Domain:** CLI workflow orchestration — auto-advance loop across context resets
**Researched:** 2026-02-17
**Confidence:** HIGH (based on direct codebase analysis)

---

## Recommended Architecture

The YOLO auto-chaining system is a **state-machine-over-files orchestrator** that drives the existing plan/execute/verify workflows across mandatory context resets. It does not replace or duplicate those workflows — it sequences them by writing state to disk before each `/clear` and reading it back to resume.

The key architectural insight: Claude Code's `SlashCommand()` invocation (already used in `transition.md`) IS the cross-context continuation mechanism. YOLO writes a cursor to `config.json`, then each phase invocation reads that cursor and re-invokes itself with `--auto` propagated forward.

```
┌─────────────────────────────────────────────────────────┐
│  /gsd:yolo  (entry point — sets up the chain)           │
│  - Validates prerequisites                              │
│  - Writes yolo_state to config.json                     │
│  - Invokes SlashCommand("/gsd:plan-phase N --auto")     │
└────────────────────────┬────────────────────────────────┘
                         │  (context resets between phases)
                         ▼
┌─────────────────────────────────────────────────────────┐
│  plan-phase (existing, auto_advance=true)               │
│  - Plans the phase                                      │
│  - Detects auto_advance → spawns execute-phase --auto   │
└────────────────────────┬────────────────────────────────┘
                         │  (within same context window)
                         ▼
┌─────────────────────────────────────────────────────────┐
│  execute-phase (existing, auto_advance=true)            │
│  - Executes all waves                                   │
│  - Verifies goal                                        │
│  - On success: runs transition.md inline                │
└────────────────────────┬────────────────────────────────┘
                         │  (within same context window)
                         ▼
┌─────────────────────────────────────────────────────────┐
│  transition.md (existing, mode=yolo)                    │
│  - Updates ROADMAP.md + STATE.md                        │
│  - If more phases: SlashCommand("/gsd:plan-phase N+1 --auto") │
│  - If last phase: SlashCommand("/gsd:complete-milestone")     │
│  - If CONTEXT.md missing: SlashCommand("/gsd:discuss-phase N+1 --auto") │
└─────────────────────────────────────────────────────────┘
```

**Critical finding:** The transition.md workflow ALREADY has this chaining logic using `SlashCommand()` and `<if mode="yolo">` blocks. The loop is partially implemented. YOLO's job is to **activate** this latent machinery, not re-implement it.

---

## Component Boundaries

### Component 1: `/gsd:yolo` Command + Workflow

| Attribute | Value |
|-----------|-------|
| Files | `commands/gsd/yolo.md`, `get-shit-done/workflows/yolo.md` |
| Responsibility | Entry point. Validate state, initialize YOLO config, hand off to plan-phase |
| Communicates with | `gsd-tools.cjs` (state read/write), `config.json` (persistence), SlashCommand (chain) |
| Does NOT | Execute plans, plan phases, verify work — delegates entirely |

**Inputs:** `$ARGUMENTS` (optional start phase override, e.g., `--from 3`)
**Outputs:** `config.json` modified (`workflow.auto_advance: true`), chain invoked

**Boundary rule:** The yolo workflow stops after writing state and invoking the first SlashCommand. It is a one-shot launcher, not a long-running orchestrator.

---

### Component 2: YOLO State in `config.json`

| Attribute | Value |
|-----------|-------|
| Location | `.planning/config.json` |
| Responsibility | Cross-context cursor: which phase YOLO is running, where to stop |
| Read by | plan-phase, execute-phase, transition.md (via `config-get workflow.auto_advance`) |
| Written by | /gsd:yolo (initialize), transition.md (clear on milestone complete) |

**State schema addition to `config.json`:**

```json
{
  "mode": "yolo",
  "workflow": {
    "auto_advance": true,
    "yolo": {
      "active": true,
      "started_at": "2026-02-17T10:00:00Z",
      "start_phase": 3,
      "stop_condition": "milestone_complete"
    }
  }
}
```

**Why config.json (not STATE.md):** `config.json` is already the source of truth for `workflow.auto_advance`. Adding `yolo` as a sub-object keeps state co-located with the flag that all existing workflows already read. STATE.md is narrative; config.json is machine-readable.

**Lifetime:** Set by `/gsd:yolo`, cleared by `transition.md` when `is_last_phase: true`.

---

### Component 3: Auto-Advance in Existing Workflows (already implemented)

These components already exist and handle the within-phase chaining:

**plan-phase.md (Step 14 — Auto-Advance Check):**
- Reads `workflow.auto_advance` from config
- If true: spawns `execute-phase --auto` as Task
- Handles PHASE COMPLETE and GAPS FOUND returns

**execute-phase.md (Step offer_next — Auto-Advance Detection):**
- Reads `workflow.auto_advance` from config
- If true and verification passed: runs `transition.md` inline
- If gaps found: stops chain, surfaces to user

**transition.md (Step offer_next_phase, mode=yolo):**
- If more phases + CONTEXT.md exists: `SlashCommand("/gsd:plan-phase [X+1] --auto")`
- If more phases + no CONTEXT.md: `SlashCommand("/gsd:discuss-phase [X+1] --auto")`
- If last phase: `SlashCommand("/gsd:complete-milestone")` + clears `auto_advance`

**Boundary rule:** These workflows must not be forked. The `--auto` flag and `workflow.auto_advance` config field are the control surface. YOLO sets these; the existing workflows respond to them.

---

### Component 4: `gsd-tools.cjs` — State Operations

| Operation | Command | Purpose |
|-----------|---------|---------|
| Set auto_advance | `config-set workflow.auto_advance true` | Activate YOLO loop |
| Set yolo active | `config-set workflow.yolo.active true` | Track YOLO session |
| Get next phase | `roadmap analyze` | Determine start phase |
| Clear yolo | `config-set workflow.auto_advance false` | Deactivate on complete |
| Validate prerequisites | `init yolo` (new) | Validate all phases have CONTEXT.md |

**New gsd-tools command needed:** `init yolo` — returns JSON with all phases remaining, their CONTEXT.md status, current position, and whether prerequisites are met.

---

### Component 5: Stop Conditions

YOLO must stop cleanly in three cases:

| Condition | Trigger | Handler |
|-----------|---------|---------|
| Phase verified with gaps | `execute-phase` returns GAPS FOUND | execute-phase already surfaces this; auto-advance skips on gaps found |
| Execution failure | execute-phase plan fails and user chooses Stop | execute-phase reports; user decides |
| Milestone complete | `transition.md` `is_last_phase: true` | transition.md clears `auto_advance`, invokes `complete-milestone` |

**On stop:** `config.json` must be written with `auto_advance: false` before the chain breaks. The existing `transition.md` already does this on milestone complete (`config-set workflow.auto_advance false`). Failure cases need the same cleanup.

---

## Data Flow

### YOLO State Across Context Resets

```
User runs /gsd:yolo
      │
      ▼
[yolo.md workflow]
  1. Read: .planning/STATE.md → current_phase
  2. Read: .planning/ROADMAP.md → remaining phases
  3. Write: config.json workflow.auto_advance=true, yolo.active=true
  4. Invoke: SlashCommand("/gsd:plan-phase {N} --auto")
      │
      │  ← CONTEXT RESET HERE (SlashCommand triggers new context)
      ▼
[plan-phase workflow — NEW context window]
  1. Read: config.json → sees auto_advance=true
  2. Run: research, plan, verify loop
  3. Detect auto_advance → Task(execute-phase --auto)
      │
      │  ← Task() is within-context (no reset)
      ▼
[execute-phase — same context window as plan-phase]
  1. Execute all waves
  2. Verify phase goal
  3. Detect auto_advance → run transition.md inline
      │
      │  ← Inline (no context reset)
      ▼
[transition.md — same context window]
  1. Mark phase complete
  2. Evolve PROJECT.md
  3. Update STATE.md (next phase, ready to plan)
  4. Check is_last_phase
  5a. If more phases: SlashCommand("/gsd:plan-phase {N+1} --auto")
  5b. If last phase: clear auto_advance, SlashCommand("/gsd:complete-milestone")
      │
      │  ← CONTEXT RESET HERE (SlashCommand triggers new context)
      ▼
[plan-phase — NEW context window, next phase]
  1. Read: config.json → still auto_advance=true
  2. ... (loop repeats)
```

**Key observation:** Context resets happen ONLY at SlashCommand boundaries (plan-phase → execute happens within-context via Task; execute → transition happens inline). There are roughly N context windows for N phases, not 3N.

### State Written at Each Boundary

| Boundary | State Written | Read By Next |
|----------|--------------|--------------|
| /gsd:yolo → plan-phase | config.json (auto_advance=true, yolo.active) | plan-phase: reads auto_advance |
| execute-phase → transition | ROADMAP.md progress, STATE.md position | transition: reads phase completion |
| transition → plan-phase | STATE.md (next phase ready), ROADMAP.md (phase marked done) | plan-phase: reads current position |
| transition → complete-milestone | config.json (auto_advance=false) | complete-milestone: no loop needed |

---

## Anti-Patterns to Avoid

### Anti-Pattern 1: YOLO as Long-Running Orchestrator

**What:** Building yolo.md as a workflow that spawns plan-phase, execute-phase, and transition as Tasks in a loop.
**Why bad:** Each phase consumes ~200k tokens. A loop of Task() calls within a single context will exhaust the context window after 1-2 phases. This is the exact problem YOLO is solving.
**Instead:** YOLO is a launcher, not a loop. It sets config and invokes one SlashCommand. The chain is self-propagating via the existing auto_advance machinery in each workflow.

### Anti-Pattern 2: Parallel Phase Execution

**What:** Running multiple phases simultaneously.
**Why bad:** Phases have sequential dependencies (Phase N+1 builds on Phase N's code). Race conditions in git commits would corrupt the repo.
**Instead:** Strictly sequential. Each transition.md invocation waits for phase N completion before invoking phase N+1.

### Anti-Pattern 3: Duplicating Workflow Logic in YOLO

**What:** Adding YOLO-specific plan/execute/verify logic to the yolo.md workflow.
**Why bad:** Creates two codepaths to maintain. When plan-phase or execute-phase evolves, YOLO won't benefit.
**Instead:** YOLO sets `auto_advance=true` and `mode=yolo` and steps back. The existing workflows already have `<if mode="yolo">` and `auto_advance` checks throughout.

### Anti-Pattern 4: STATE.md as the YOLO Cursor

**What:** Writing YOLO state (active, current phase, started_at) to STATE.md.
**Why bad:** STATE.md is human-readable narrative. Machine-readable cursor state should be in config.json where `config-get` can read it atomically. STATE.md also gets overwritten by transition.md.
**Instead:** `config.json` under `workflow.yolo` sub-object. Use existing `config-set`/`config-get` commands.

### Anti-Pattern 5: Stopping on Human-Verify Checkpoints

**What:** YOLO hard-stops whenever a `human-verify` checkpoint appears in a plan.
**Why bad:** Human-verify checkpoints are often UI checks that don't block other execution. execute-phase already has auto-approve logic for these when `auto_advance=true`.
**Instead:** Trust the existing checkpoint auto-approval logic. YOLO only stops on `human-action` checkpoints (auth gates) and `gaps_found` verification failures — both already handled by execute-phase.

---

## Scalability Considerations

| Concern | Small (3 phases) | Medium (8 phases) | Large (15+ phases) |
|---------|-----------------|-------------------|--------------------|
| Context per phase | Fresh 200k — fine | Fresh 200k — fine | Fresh 200k — fine |
| config.json state | Trivial | Trivial | Trivial |
| Failure recovery | Restart at failed phase | Restart at failed phase | Same — YOLO resumes from next unexecuted phase |
| Git history | Clean per-task commits | Same | Same |

**Failure recovery design:** When YOLO is interrupted (failure or user stop), `config.json` retains `auto_advance=false` (cleared on stop) and STATE.md retains the current phase position. The user can re-run `/gsd:yolo` to pick up from where they left off — the init step reads STATE.md to determine the start phase, not a YOLO-specific cursor.

---

## Build Order (Dependencies)

The components have clear dependencies that determine implementation sequence:

**Layer 0 (already exists — no build needed):**
- `config-get workflow.auto_advance` in plan-phase, execute-phase — existing
- `<if mode="yolo">` branching in transition.md — existing
- `config-set workflow.auto_advance false` on milestone complete — existing
- `SlashCommand()` invocation in transition.md — existing

**Layer 1 (must build first):**
- `gsd-tools.cjs init yolo` command — needed by yolo.md to validate prerequisites and get start phase
- `config-set workflow.yolo.active true/false` support — needed for session tracking
- Test: can gsd-tools atomically write and read yolo state across config-set calls?

**Layer 2 (depends on Layer 1):**
- `get-shit-done/workflows/yolo.md` — the launcher workflow
- `commands/gsd/yolo.md` — the command entry point
- These depend on `init yolo` returning valid JSON to drive the launch decision

**Layer 3 (integration, depends on Layer 2):**
- Validate the full chain: `/gsd:yolo` → plan-phase auto → execute-phase auto → transition auto → plan-phase auto
- Test with a 2-phase dummy project (fast cycle time)
- Verify config.json cleanup on milestone complete

**Layer 4 (hardening, depends on Layer 3):**
- Failure handling: what happens if execute-phase hits GAPS FOUND mid-chain
- Stop-condition cleanup: ensure auto_advance cleared on all failure paths
- `/gsd:yolo` resume behavior (re-run after failure picks up at correct phase)

---

## Existing Patterns That Directly Apply

### Pattern 1: `--auto` Flag Propagation

Already used in `new-project → discuss-phase → plan-phase` chain. The flag threads through SlashCommand invocations. Adopt the same pattern: YOLO passes `--auto` to plan-phase; plan-phase passes it to execute-phase; execute-phase passes it to transition; transition passes it to the next plan-phase.

**Confidence:** HIGH (verified in plan-phase.md step 14, execute-phase.md offer_next, discuss-phase.md auto_advance step)

### Pattern 2: `workflow.auto_advance` Config Field

Already exists in config.json template and is read by plan-phase and execute-phase. YOLO sets this field; no new field needed for basic operation. The `yolo` sub-object is additive and optional — for session metadata only.

**Confidence:** HIGH (verified in config.json, plan-phase.md, execute-phase.md, transition.md)

### Pattern 3: SlashCommand for Cross-Context Continuation

Used in transition.md to invoke the next phase plan or complete-milestone. This is the established pattern for crossing context reset boundaries. YOLO uses the same mechanism for the initial launch.

**Confidence:** HIGH (verified in transition.md lines 381, 393, 469)

### Pattern 4: Task() for Within-Context Delegation

Used by plan-phase to spawn execute-phase within the same context window. This avoids unnecessary context resets when work can fit in the current 200k window.

**Confidence:** HIGH (verified in plan-phase.md step 14)

---

## Sources

- `.planning/codebase/ARCHITECTURE.md` — Existing system architecture (HIGH confidence, direct analysis)
- `get-shit-done/workflows/plan-phase.md` — Auto-advance step 14 (HIGH confidence, direct read)
- `get-shit-done/workflows/execute-phase.md` — offer_next step, checkpoint handling (HIGH confidence, direct read)
- `get-shit-done/workflows/transition.md` — YOLO mode branching, SlashCommand pattern (HIGH confidence, direct read)
- `.planning/config.json` — Current config schema (HIGH confidence, direct read)
- `.planning/PROJECT.md` — YOLO requirements and constraints (HIGH confidence, direct read)
- `get-shit-done/bin/gsd-tools.cjs` — config-set/get, state commands (HIGH confidence, grep analysis)

---

*Architecture analysis: 2026-02-17*
