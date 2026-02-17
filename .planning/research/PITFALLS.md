# Domain Pitfalls

**Domain:** Auto-pilot / YOLO mode for multi-phase AI coding orchestration
**Researched:** 2026-02-17
**Confidence:** HIGH — based on direct codebase analysis of the existing GSD system, CHANGELOG history, and CONCERNS.md; no unverified external claims

---

## Critical Pitfalls

Mistakes that cause runaway chains, data loss, or require a full rethink.

---

### Pitfall 1: State That Only Lives in the LLM's In-Memory Context

**What goes wrong:** YOLO writes "currently on phase 3 of 7" into a variable or response text. Then the next command (`/clear`) destroys that context. The next invocation of `/gsd:yolo` has no idea a run is in progress. It either starts from scratch (doubling work) or silently exits with "nothing to do."

**Why it happens:** The temptation is to track run state in bash variables or in the workflow's own narrative. These don't survive `/clear`. The GSD system already solved this for `auto_advance` — it writes to `config.json` on disk immediately after the flag is detected (see `discuss-phase.md` line 441, `new-project.md` line 197). YOLO must do the same.

**Consequences:**
- Infinite restart loops if the YOLO invocation command is re-issued
- Duplicate plan-phase runs if the system doesn't check what's already done
- User confusion: "I started YOLO, came back, nothing happened"

**Prevention:**
- Write a `yolo` stanza to `config.json` before the first `/clear`:
  ```json
  "yolo": {
    "active": true,
    "started_phase": 3,
    "total_phases": 7,
    "started_at": "2026-02-17T12:00:00Z"
  }
  ```
- On every subsequent invocation, read this stanza first. If `active: true`, resume from current STATE.md position. If `active: false`, start fresh.
- Clear the stanza only on successful milestone completion or explicit user-invoked stop.

**Warning signs:**
- Workflow reads phase position from bash variable rather than STATE.md + config.json
- YOLO state is described only in the human-visible output, not written to disk

**Phase to address:** Implementation phase 1 (state persistence mechanism, before any chaining logic)

---

### Pitfall 2: Treating a Runtime Bug as a Real Failure and Stopping

**What goes wrong:** Claude Code has a known bug where `classifyHandoffIfNeeded is not defined` fires in the agent completion handler after an executor agent successfully finishes all its work. The YOLO chain interprets the "failed" status as a real execution failure and stops the run, requiring manual intervention on work that actually succeeded.

**Why it happens:** The bug is context-specific — long outputs, complex JSON, and certain result structures trigger it. It's indistinguishable from a real failure at the agent API level. The existing `execute-phase.md` already has a workaround: spot-check SUMMARY.md existence and git log before accepting a failure report. YOLO must inherit this logic, not bypass it.

**Consequences:**
- YOLO stops mid-run on a false negative, requiring the user to intervene, defeating the purpose of auto-pilot
- Worse: if YOLO writes "FAILED" to its state file on a false failure, resuming becomes ambiguous (did it actually fail? which tasks ran?)

**Prevention:**
- Before propagating any agent failure upward: verify SUMMARY.md exists on disk and `git log --grep="{phase}-{plan}"` returns at least one commit
- If spot-checks pass: log the bug, treat as success, continue the chain
- Distinguish between "agent reported error" and "work actually failed"

**Warning signs:**
- YOLO fails on the first plan of a phase with no visible code error
- The failure message contains "classifyHandoffIfNeeded is not defined"
- STATE.md shows a stalled plan that has a corresponding SUMMARY.md on disk

**Phase to address:** Implementation phase 1 (failure detection logic, co-developed with state persistence)

---

### Pitfall 3: Auto-Clearing `auto_advance` Before YOLO Finishes

**What goes wrong:** The existing `transition.md` workflow (which YOLO will invoke to advance between phases) contains `config-set workflow.auto_advance false` when it detects the last phase in the milestone. YOLO needs `auto_advance` to remain `true` across all phases. If YOLO reuses the transition workflow verbatim, that line runs mid-chain and kills the subsequent plan-phase invocation.

**Why it happens:** The existing transition logic was designed to stop auto-advance at milestone boundaries — which is correct for single-milestone `--auto` usage. YOLO's multi-phase chaining has a different semantic: "auto_advance" should remain active until YOLO is done, not until any individual phase is the last.

**Consequences:**
- YOLO advances through phases 1-N-1 correctly, then silently stops at the last phase because `auto_advance` was cleared before the final plan → execute → verify loop runs
- The milestone never completes in auto mode; user returns to find the run stopped with no clear error

**Prevention:**
- YOLO must own the `auto_advance` lifecycle separately from transition.md's milestone-boundary logic
- Either: (a) detect when transition.md clears `auto_advance` and re-set it if YOLO run is still active, or (b) add a `yolo.active` guard in transition.md that skips the clear when YOLO is running
- When YOLO itself triggers `complete-milestone`, it should be the one to clear `auto_advance`, not transition.md

**Warning signs:**
- Run stops cleanly at the penultimate phase with STATE.md showing "Ready to plan [last phase]"
- `config.json` shows `workflow.auto_advance: false` during a supposedly active YOLO run

**Phase to address:** Implementation phase 1 (orchestration logic) — must be resolved before any testing

---

### Pitfall 4: No Clean Stop When Failure Is Real

**What goes wrong:** An execution failure occurs (test suite fails, build broken, required API unavailable). YOLO continues to the next phase anyway — either because the failure detection logic is too lenient, or because the "issues_review_gate" step in `execute-plan.md` just logs and continues in yolo mode (`if yolo → log and continue`). The user returns to find three subsequent phases built on top of a broken foundation.

**Why it happens:** The existing `issues_review_gate` explicitly says: "yolo → log and continue. Interactive → present issues, wait for acknowledgment." This is correct behavior for minor deviations. But YOLO must distinguish: a skipped cosmetic task is different from a task with `## Self-Check: FAILED` in its SUMMARY.

**Consequences:**
- Cascading failures: phase 3 breaks because phase 2 left a broken interface, phase 4 breaks because phase 3 assumed phase 2 worked
- State corruption: STATE.md shows phases "complete" when they contain failures
- User must untangle which of N phases to roll back

**Prevention:**
- Before advancing to the next phase, check for `## Self-Check: FAILED` in all SUMMARYs for the current phase
- If any SUMMARY contains `Self-Check: FAILED`, STOP and surface clearly:
  ```
  YOLO STOPPED: Phase {X} plan {Y} self-check failed.
  Run: /gsd:debug
  Resume after fix: /gsd:yolo (will pick up from current position)
  ```
- Treat verification failures from `verify-work` as stop conditions, not advisory warnings
- Distinguish "deviation logged" (continue) from "verification failed" (stop)

**Warning signs:**
- YOLO completes all phases but the final app doesn't work
- Multiple SUMMARYs contain "Issues Encountered" that were silently logged
- Git log shows commits from all phases but tests fail back in phase 2's changes

**Phase to address:** Implementation phase 1 (failure classification logic) — this is the most user-facing correctness requirement

---

## Moderate Pitfalls

---

### Pitfall 5: Forking Existing Workflows Instead of Orchestrating Them

**What goes wrong:** To avoid the "auto_advance cleared too early" problem (Pitfall 3), the implementer copies and modifies `transition.md`, `plan-phase.md`, and `execute-phase.md` into YOLO-specific versions. Now there are two divergent codepaths for every operation, and bug fixes in the original workflows don't propagate to YOLO.

**Why it happens:** The temptation is strong when a workflow almost-but-not-quite does what YOLO needs. Forking is faster in the short term.

**Consequences:**
- Maintenance debt: every future change to `plan-phase.md` must be mirrored in `yolo-plan-phase.md`
- Users get different behavior in YOLO vs interactive modes for identical operations
- Bugs fixed in interactive mode silently persist in YOLO mode

**Prevention:**
- YOLO should call `SlashCommand("/gsd:plan-phase {N} --auto")`, `SlashCommand("/gsd:execute-phase {N} --auto")`, etc. — not re-implement their logic
- The `--auto` flag and `config.json` mechanisms already exist for this purpose
- If a workflow needs YOLO-specific behavior (e.g., the auto_advance lifecycle), add a conditional branch (`if yolo.active`) to the existing workflow rather than forking it

**Warning signs:**
- Implementation creates any file named `yolo-plan.md`, `yolo-execute.md`, or similar
- Implementation re-implements gsd-tools commands that already exist

**Phase to address:** Implementation phase 1 (architecture decision must be made upfront)

---

### Pitfall 6: `human-action` Checkpoints Silently Blocking the Chain

**What goes wrong:** YOLO runs into a `checkpoint:human-action` (an authentication gate, email verification, or similar). Unlike `human-verify` and `decision` checkpoints which auto-approve in yolo mode, `human-action` always stops. The YOLO chain halts invisibly — the user isn't watching, they return hours later to find it blocked with no notification.

**Why it happens:** `human-action` is correctly designated as non-automatable (from `checkpoints.md`: "human-action still stops — auth gates cannot be automated"). But YOLO creates an expectation of unattended operation that conflicts with this reality.

**Consequences:**
- User sets YOLO going and steps away; returns to find it blocked on step 2 of phase 1 waiting for `vercel login`
- Wasted time; user expected unattended execution but got none
- State is correctly persisted (this isn't a data loss scenario), but the user experience breaks the core YOLO promise

**Prevention:**
- Emit a prominent warning before starting YOLO if the upcoming phase plans contain `checkpoint:human-action` tasks
- Better: scan all remaining phase plans for `human-action` gates before starting the run; surface a count: "2 plans require human authentication (service login). YOLO will pause at these points."
- Document clearly in `/gsd:yolo` output: "YOLO pauses on auth gates — these cannot be automated"
- When the chain stops on a human-action, write a clear message: `YOLO PAUSED: Auth gate in Phase {X} Plan {Y}. Complete auth, then re-run /gsd:yolo`

**Warning signs:**
- YOLO used on a project that deploys to cloud services (Vercel, Railway, AWS) for the first time
- Phase plans contain words like "login", "authenticate", "API key", "configure credentials"

**Phase to address:** Implementation phase 1 (state persistence) + documentation phase

---

### Pitfall 7: Phase Number Drift When YOLO Resume Restarts from Wrong Position

**What goes wrong:** YOLO pauses (Pitfall 6, or user Ctrl-C). User resumes with `/gsd:yolo`. The resume logic reads ROADMAP.md's "Current Phase" or STATE.md's "Current Phase" incorrectly — off by one (picks already-complete phase) or picks from the wrong anchor (reads the roadmap table's "In Progress" row rather than the first incomplete phase).

**Why it happens:** The ROADMAP.md and STATE.md have slightly different views of "current phase". STATE.md tracks current execution position; ROADMAP.md tracks milestone-level progress. If the execute-phase of phase N completed but transition.md hasn't run yet (YOLO was interrupted between them), the two sources disagree.

**Consequences:**
- YOLO re-executes a complete phase, producing duplicate commits and duplicate SUMMARY files
- Alternatively: YOLO skips a phase that only half-ran

**Prevention:**
- Use `gsd-tools roadmap analyze` as the authoritative source for "next phase to run" — it computes from disk state (PLAN.md vs SUMMARY.md counts), not from STATE.md text fields
- Resume logic: find first phase where `summaries < plans` OR `has_plans == false` — that is the phase to act on next
- Never use the "current phase" text field from STATE.md as the sole source of resume position

**Warning signs:**
- After a YOLO resume, git log shows duplicate commits for the same phase-plan
- STATE.md "Current Phase" and the result of `roadmap analyze` disagree

**Phase to address:** Implementation phase 1 (resume logic) — test explicitly with interrupted runs

---

### Pitfall 8: Context Window Contamination on Long Chains

**What goes wrong:** The YOLO orchestrator itself accumulates context across phases: plan results, execution summaries, transition outputs. By phase 6 of 10, the orchestrator's context window is 60-80% full with previous phase outputs. Subsequent plan-phase and execute-phase invocations get degraded because the orchestrator context that spawns them is already heavy.

**Why it happens:** GSD's architecture explicitly solves this for subagents (each gets a fresh 200k window). But the YOLO orchestrator is the main context. If YOLO invokes `SlashCommand("/gsd:plan-phase 6")`, that slash command runs in the current (bloated) context.

**Consequences:**
- Planning quality degrades on later phases
- Executor agents may fail to spawn if the parent context is too full
- Users report YOLO "works for 3-4 phases but gets weird after that"

**Prevention:**
- The `/clear` between phases must actually clear the YOLO orchestrator's context, not just subagent contexts
- This is the core architecture challenge documented in PROJECT.md: "no programmatic /clear API"
- Mitigation: YOLO's re-invocation mechanism must produce a fresh context (a new slash command invocation) rather than continuing in the same session
- The persistence mechanism (config.json `yolo.active`) enables this: each `/gsd:yolo` invocation is a fresh context, reads the stanza, picks up where it left off

**Warning signs:**
- YOLO outputs for phase 1-3 are detailed and correct; phase 6-7 outputs are terse or confused
- gsd-tools init calls slow down significantly mid-chain

**Phase to address:** Architecture decision phase — must resolve "how does YOLO invoke itself with a fresh context?" before any implementation

---

## Minor Pitfalls

---

### Pitfall 9: Silent JSON Parsing Failures Hiding State Corruption

**What goes wrong:** `config.json` gets corrupted (power cut mid-write, two concurrent processes writing). The YOLO state stanza (`yolo.active: true`) is lost. On resume, YOLO sees no active run and starts over from phase 1.

**Why it happens:** The CONCERNS.md already flags this: `gsd-tools.cjs` has silent JSON parse failures in multiple places that return empty objects instead of errors. A corrupted `yolo` stanza would be silently ignored.

**Prevention:**
- Before overwriting `config.json` with YOLO state, read-verify the current state first
- After writing, read back and verify the stanza exists
- If `yolo` stanza is missing on resume but STATE.md shows `In Progress`, prompt the user rather than silently restarting

**Warning signs:**
- `config.json` timestamp is newer than expected for the phase
- YOLO restarts from phase 1 despite incomplete work in later phases

**Phase to address:** Implementation phase 1 (state persistence) — inherit the pattern from how `auto_advance` is written

---

### Pitfall 10: Verify-Work Being Optional When It Should Block

**What goes wrong:** `verify-work` finds gaps (requirements not met). In the existing system, this is surfaced to the user for a decision. In YOLO mode with `config.workflow.verifier: true`, the chain must stop — not log-and-continue. The risk is that YOLO treats verifier output as advisory, the same way `issues_review_gate` treats minor deviations.

**Prevention:**
- Verifier output with `gaps: true` (or equivalent from gsd-tools) is a hard stop in YOLO mode
- The stop message must clearly state: "YOLO STOPPED: Verification found gaps in Phase {X}. Resolve before resuming."
- Distinguish: `verifier: false` in config (skip verify-work, continue) vs `verifier: true` + gaps found (stop)

**Warning signs:**
- YOLO completes but milestone-level requirements are unsatisfied
- Verify-work output shows gaps that were never surfaced to the user

**Phase to address:** Implementation phase 1 (failure classification) — paired with Pitfall 4

---

### Pitfall 11: YOLO Left Active After Unexpected Stop

**What goes wrong:** YOLO is running, user closes the terminal or Claude Code crashes. `config.json` still has `yolo.active: true`. The user's next ordinary `/gsd:plan-phase 3` command sees `auto_advance: true` in config and starts chaining unexpectedly — they didn't invoke YOLO, they just wanted to plan one phase.

**Prevention:**
- Separate YOLO state (`yolo.active`) from the `workflow.auto_advance` flag
- `workflow.auto_advance` should only be set when YOLO is actively advancing; it can be derived from `yolo.active` at each invocation rather than persisted independently
- Add a check at the start of plan-phase/execute-phase: if `yolo.active: true` but the invoker is NOT `/gsd:yolo`, warn the user that a YOLO run was interrupted and ask whether to resume or clear

**Warning signs:**
- After a crash, ordinary GSD commands start auto-advancing unexpectedly
- `config.json` shows `yolo.active: true` but user hasn't run `/gsd:yolo` recently

**Phase to address:** Implementation phase 1 (state lifecycle) — the cleanup protocol must handle abnormal exits

---

## Phase-Specific Warnings

| Phase Topic | Likely Pitfall | Mitigation |
|-------------|---------------|------------|
| State persistence mechanism | Silent JSON corruption (Pitfall 9) clears YOLO state | Read-after-write verification; fallback to STATE.md position |
| Failure detection logic | `classifyHandoffIfNeeded` false positives (Pitfall 2) stop the chain | Spot-check SUMMARY.md + git log before accepting any failure report |
| Chain orchestration | Forking workflows (Pitfall 5) creates maintenance debt | Gate decision: must use SlashCommand to existing workflows, not copies |
| Context reset between phases | Context window contamination (Pitfall 8) | Fresh invocation per phase; YOLO self-invokes via SlashCommand, not in-session loop |
| auto_advance lifecycle | Transition.md clears flag too early (Pitfall 3) | YOLO owns the auto_advance lifecycle; guard in transition.md for `yolo.active` |
| Failure stop conditions | Verification gaps log-and-continue (Pitfall 4, 10) | Distinguish deviation (continue) from self-check failure / verifier gaps (stop) |
| User intervention points | Auth gates block silently (Pitfall 6) | Pre-scan plans for `human-action`; communicate pause expectation upfront |
| Resume after interrupt | Phase position drift (Pitfall 7) | Use `roadmap analyze` as authoritative source; never trust STATE.md text alone |
| YOLO left active after crash | Unexpected auto-advance on next ordinary command (Pitfall 11) | Separate `yolo.active` from `auto_advance`; warn on stale state detection |

---

## Sources

- `/home/junbeom/Projects/get-shit-done/.planning/codebase/CONCERNS.md` — Known bugs: classifyHandoffIfNeeded (HIGH confidence, direct codebase observation)
- `/home/junbeom/Projects/get-shit-done/.planning/PROJECT.md` — YOLO requirements and constraints (HIGH confidence)
- `/home/junbeom/Projects/get-shit-done/get-shit-done/workflows/transition.md` — auto_advance lifecycle and milestone boundary behavior (HIGH confidence)
- `/home/junbeom/Projects/get-shit-done/get-shit-done/workflows/execute-plan.md` — issues_review_gate behavior in yolo vs interactive mode (HIGH confidence)
- `/home/junbeom/Projects/get-shit-done/get-shit-done/workflows/execute-phase.md` — failure handling, spot-check protocol (HIGH confidence)
- `/home/junbeom/Projects/get-shit-done/get-shit-done/references/checkpoints.md` — human-action always stops in auto mode (HIGH confidence)
- `/home/junbeom/Projects/get-shit-done/CHANGELOG.md` — history of auto_advance bugs and fixes: v1.20.1 (auto_advance survives context compaction), v1.19.1 (initial pipeline), v1.1.2 (yolo mode skipping confirmation gates) (HIGH confidence)
- `/home/junbeom/Projects/get-shit-done/.planning/codebase/ARCHITECTURE.md` — context management patterns: fresh context per subagent, lean orchestrators (HIGH confidence)
