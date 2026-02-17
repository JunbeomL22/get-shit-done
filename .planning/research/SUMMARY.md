# Project Research Summary

**Project:** gsd:yolo — Hands-Free Milestone Execution
**Domain:** Auto-pilot CLI workflow orchestration (multi-phase, multi-context-window chaining)
**Researched:** 2026-02-17
**Confidence:** HIGH (primary evidence from direct codebase analysis; external tool comparisons MEDIUM)

## Executive Summary

The `/gsd:yolo` command is fundamentally a thin launcher that activates latent machinery already built into GSD. The auto-chaining pipeline (plan-phase → execute-phase → transition → plan-phase+1) exists and is operational — it was introduced in v1.19.1 and hardened in v1.20.1. The core problem that makes YOLO non-trivial is not workflow orchestration but **state persistence across mandatory context resets**: each SlashCommand invocation in Claude Code produces a fresh context window, so any state held only in-memory is destroyed between phases. The existing `workflow.auto_advance` config field, persisted to `config.json` on disk, solves exactly this problem and serves as the pattern YOLO must extend.

The recommended approach is a one-shot launcher: `/gsd:yolo` validates prerequisites, writes a `yolo` state stanza to `config.json`, sets `workflow.auto_advance: true` and `mode: "yolo"`, then invokes `SlashCommand("/gsd:plan-phase N --auto")`. The existing workflows handle all subsequent chaining — plan-phase chains to execute-phase via Task(), execute-phase runs transition.md inline, and transition.md invokes the next plan-phase via SlashCommand. YOLO does not need to build a new orchestration loop; it needs to be the reliable entry point and state initializer for a loop that already self-propagates.

The key risk is subtle state management failures: the `auto_advance` flag being prematurely cleared by transition.md's milestone-boundary logic, stale YOLO state persisting after abnormal exit and contaminating subsequent ordinary commands, and false-positive failure signals from a known Claude Code bug (`classifyHandoffIfNeeded`) causing premature stops. All of these have documented mitigations: guard the auto_advance clear behind a `yolo.active` check, separate YOLO session state from the auto_advance flag, and spot-check SUMMARY.md + git log before accepting any agent failure report.

## Key Findings

### Recommended Stack

GSD's existing infrastructure handles all heavy lifting. The only genuinely new components are a command file (`commands/gsd/yolo.md`), a launcher workflow (`get-shit-done/workflows/yolo.md`), and a `yolo` sub-object in `config.json` for session state. Everything else — chaining, context management, failure stops, state persistence — already exists in the plan-phase, execute-phase, and transition.md workflows.

**Core technologies:**
- `config.json workflow.yolo` stanza: session state persistence — survives context resets because it is disk-backed, not in-memory
- `SlashCommand("/gsd:plan-phase N --auto")`: cross-context continuation — the only mechanism that crosses context reset boundaries cleanly
- `Task(prompt="Run /gsd:execute-phase N --auto")`: within-context delegation — used by plan-phase to chain to execute-phase without a context reset
- `gsd-tools.cjs config-set/config-get`: atomic config writes — already proven for `workflow.auto_advance`, used verbatim for YOLO state
- `gsd-tools roadmap analyze`: authoritative phase position — the only correct way to determine which phase to act on next (never trust STATE.md text alone)

### Expected Features

**Must have (table stakes):**
- Single invocation entry point — `/gsd:yolo` with no required args; any additional steps defeat the purpose
- Automatic phase-to-phase chaining — the core loop that runs all remaining phases
- Persistent state across context resets — without this, the chain breaks silently after the first `/clear`
- Hard stop on failure — users trust auto-pilot only when it stops reliably on real failures
- Clear failure reporting — which phase, which plan, what failed, how to resume
- Progress visibility — phase banners and completion summaries so users know what happened
- Respect existing config — do not override user's configured agents, verifiers, or research flags
- Safe stop at milestone end — no runaway into the next milestone

**Should have (differentiators):**
- Skip discuss-phase in YOLO loop — discuss is explicitly interactive; YOLO should jump straight to plan-phase
- Context-window-aware chaining — the defining engineering challenge; each phase gets a fresh 200k context via SlashCommand boundary
- Idempotent resume after interruption — re-running `/gsd:yolo` after failure picks up from the correct position
- Transparent mode indicator — "YOLO mode active, phase N of M" banner at each phase transition
- Verify-before-advance gate — verifier gaps are a hard stop, not a log-and-continue

**Defer (v2+):**
- Phase range selection (`/gsd:yolo 3-7`) — scope creep; run all remaining phases
- Cost/token budget enforcement — adds complexity without clear value at this stage
- Auto-retry on failure — compounds errors; stop and surface instead
- Auto-commit milestone on completion — meaningful checkpoint; user should review before archiving

### Architecture Approach

YOLO is a **state-machine-over-files orchestrator** implemented as a one-shot launcher. It writes cursor state to `config.json`, invokes one SlashCommand, and exits. The self-propagating chain in the existing workflows handles the rest. Context resets happen only at SlashCommand boundaries (one fresh context per phase, not three per phase); within a phase, plan→execute→transition run in the same context window. YOLO never holds phase outputs in its own context — it is stateless between invocations by design.

**Major components:**
1. `/gsd:yolo` command + workflow — entry point: validate, initialize state, invoke first plan-phase
2. `config.json workflow.yolo` stanza — cross-context cursor: active flag, start phase, timestamp
3. Auto-advance in existing workflows (Layer 0) — plan-phase, execute-phase, transition.md chaining logic already implemented
4. `gsd-tools.cjs init yolo` (new) — prerequisite validation and phase position analysis
5. Stop condition handlers — GAPS FOUND, Self-Check FAILED, human-action checkpoints, milestone complete

**Build order:** gsd-tools additions first (Layer 1), then yolo.md workflow (Layer 2), then integration validation (Layer 3), then failure hardening (Layer 4).

### Critical Pitfalls

1. **In-memory state loss across context resets** — any YOLO state not written to `config.json` before the SlashCommand boundary is destroyed. Write the full `yolo` stanza atomically before invoking the first plan-phase; read it back to verify.

2. **`classifyHandoffIfNeeded` false-positive failures** — a known Claude Code bug causes successful agent completions to report as failures. Before propagating any agent failure: spot-check SUMMARY.md exists on disk and `git log --grep="{phase}-{plan}"` returns at least one commit. If both pass, treat as success and continue.

3. **`auto_advance` cleared too early by transition.md** — transition.md's milestone-boundary logic clears `workflow.auto_advance` before the final phase executes. Add a `yolo.active` guard in transition.md that skips the clear when a YOLO run is active; YOLO itself clears the flag at true completion.

4. **Cascading failures from silent gap bypass** — YOLO continuing past a `Self-Check: FAILED` SUMMARY or a `verify-work` gap causes phases N+2, N+3 to build on broken foundations. Treat verification failures as hard stops; distinguish minor deviations (continue) from self-check failures and verifier gaps (stop).

5. **Stale `yolo.active` contaminating ordinary commands** — if YOLO crashes, `yolo.active: true` remains in config.json. Subsequent plain `/gsd:plan-phase` invocations see `auto_advance: true` and chain unexpectedly. Separate `yolo.active` from `workflow.auto_advance`; plan-phase and execute-phase should warn when they detect a stale YOLO state from a non-YOLO invocation.

## Implications for Roadmap

Based on research, the dependency graph is clear: state persistence is the foundation for everything else. Without it, chaining, resume, and failure handling cannot work. The build order from ARCHITECTURE.md maps directly to phases.

### Phase 1: Foundation — State Infrastructure and gsd-tools Extensions

**Rationale:** Every subsequent component depends on reliable state persistence and the `gsd-tools init yolo` command. This must land first. No chaining logic is testable without it.
**Delivers:** `config.json` YOLO stanza schema, `gsd-tools init yolo` command (returns phase list, CONTEXT.md status, prerequisites), `config-set workflow.yolo.*` support, read-after-write verification for the stanza.
**Addresses:** Single invocation entry point (prerequisite), persistent state (table stakes), idempotent resume (differentiator groundwork).
**Avoids:** Pitfall 1 (in-memory state loss), Pitfall 9 (silent JSON corruption), Pitfall 11 (stale state contamination).
**Research flag:** Standard patterns — `gsd-tools` extension follows established `config-set`/`config-get` pattern. No deeper research needed.

### Phase 2: Core Launcher — yolo.md Workflow and Command

**Rationale:** With gsd-tools foundation in place, the launcher workflow can be built and tested in isolation (mock the chain, verify state is written correctly).
**Delivers:** `commands/gsd/yolo.md` command registration, `get-shit-done/workflows/yolo.md` launcher workflow (validate, write state, invoke first plan-phase), mode and auto_advance config writes.
**Addresses:** Single invocation entry point, skip discuss-phase, transparent mode indicator.
**Avoids:** Pitfall 5 (forking workflows — this phase draws the hard line that YOLO orchestrates, never re-implements).
**Research flag:** Standard patterns — SlashCommand invocation pattern is directly observed in transition.md. No research needed.

### Phase 3: Integration — Full Chain Validation and Failure Hardening

**Rationale:** The chain (yolo → plan-phase auto → execute-phase auto → transition auto → plan-phase+1 auto) must be validated end-to-end before hardening. Pitfalls 2, 3, and 4 are integration-time failures that only appear when the full loop runs.
**Delivers:** End-to-end YOLO loop working across 2+ phases, `auto_advance` lifecycle guarded by `yolo.active` check in transition.md, false-positive failure detection (SUMMARY.md + git log spot-check), hard stop on Self-Check FAILED and verifier gaps, clear YOLO STOPPED output.
**Addresses:** Hard stop on failure, clear failure reporting, verify-before-advance gate.
**Avoids:** Pitfall 2 (false-positive failures), Pitfall 3 (premature auto_advance clear), Pitfall 4 (cascading failures).
**Research flag:** May need phase-specific research on the `classifyHandoffIfNeeded` bug workaround pattern — check CONCERNS.md and execute-phase.md spot-check logic before implementing.

### Phase 4: Polish — Resume, Human-Action Handling, and Progress Visibility

**Rationale:** Core loop works after Phase 3. Phase 4 adds the UX that makes YOLO feel trustworthy for unattended operation.
**Delivers:** Idempotent resume (re-run `/gsd:yolo` after interruption picks up from `roadmap analyze` position), pre-run scan for human-action checkpoints with upfront warning, YOLO PAUSED output on auth gate stops, phase banner at each transition ("YOLO mode active, phase N of M"), completion summary on milestone end.
**Addresses:** Idempotent resume, transparent mode indicator, human-action checkpoint communication.
**Avoids:** Pitfall 6 (silent human-action blocks), Pitfall 7 (phase position drift on resume), Pitfall 8 (context window contamination — verified by resume architecture).
**Research flag:** Standard patterns — resume logic follows `roadmap analyze` pattern already documented. No research needed.

### Phase Ordering Rationale

- State infrastructure must precede the launcher (you cannot test the launcher without reliable state reads)
- The launcher must precede integration validation (nothing to validate until the entry point exists)
- Full chain validation must precede polish (polish requires a working loop to polish)
- Failure hardening and integration are in the same phase because failure cases only appear during integration testing — they cannot be hardened in isolation
- Resume and human-action handling are polish because they handle exceptional paths; the happy path must be solid first

### Research Flags

Phases likely needing deeper research during planning:
- **Phase 3:** The `classifyHandoffIfNeeded` false-positive failure detection requires reading CONCERNS.md and the execute-phase spot-check protocol carefully before implementing. The boundary between "agent error" and "work actually failed" is subtle and the mitigation pattern must be inherited exactly, not reimplemented.

Phases with standard patterns (skip research-phase):
- **Phase 1:** `gsd-tools` extension follows the established `config-set`/`config-get` pattern; config.json schema extension follows the `workflow.auto_advance` precedent exactly.
- **Phase 2:** SlashCommand launcher pattern is directly verified in transition.md; no unknowns.
- **Phase 4:** Resume via `roadmap analyze` and human-action scan follow documented patterns.

## Confidence Assessment

| Area | Confidence | Notes |
|------|------------|-------|
| Stack | HIGH | All core mechanisms verified directly in codebase: SlashCommand in transition.md, Task() in plan-phase.md, config-set in discuss-phase.md and new-project.md, auto_advance in config.json template |
| Features | HIGH (internal) / MEDIUM (external) | GSD-internal features verified from CHANGELOG and workflows. External tool comparisons (Aider, Cursor, Claude Code `--dangerously-skip-permissions`) from training data; not needed for implementation decisions |
| Architecture | HIGH | Component boundaries, data flow, and build order all directly verified from codebase. The one-shot launcher pattern is observable in transition.md's existing SlashCommand invocations |
| Pitfalls | HIGH | Critical pitfalls sourced from CONCERNS.md (known bugs), CHANGELOG (v1.20.1 auto_advance fix), and direct workflow analysis. Not inferred — observed |

**Overall confidence:** HIGH

### Gaps to Address

- **Gemini CLI compatibility:** MEDIUM confidence. The Task(prompt="Run /gsd:X --auto") pattern is expected to work but less tested for YOLO chains. Validate during Phase 3 integration testing if Gemini support is in scope.
- **`init yolo` command design:** The exact JSON schema for the prerequisite validation output is not pre-defined. Design during Phase 1 planning to ensure yolo.md can consume it cleanly.
- **transition.md modification scope:** The `yolo.active` guard addition needs careful implementation to avoid breaking existing `--auto` behavior for non-YOLO invocations. Needs explicit test cases for both paths during Phase 3.

## Sources

### Primary (HIGH confidence)
- `/home/junbeom/Projects/get-shit-done/get-shit-done/workflows/transition.md` — YOLO mode branching, SlashCommand invocation pattern, auto_advance lifecycle
- `/home/junbeom/Projects/get-shit-done/get-shit-done/workflows/plan-phase.md` — auto-advance step 14, Task() chaining to execute-phase
- `/home/junbeom/Projects/get-shit-done/get-shit-done/workflows/execute-phase.md` — failure stop logic, auto-advance detection, spot-check protocol
- `/home/junbeom/Projects/get-shit-done/CHANGELOG.md` — v1.19.1 (initial pipeline), v1.20.1 (context compaction survival), v1.1.2 (yolo mode gate skipping)
- `/home/junbeom/Projects/get-shit-done/.planning/PROJECT.md` — YOLO requirements and constraints
- `/home/junbeom/Projects/get-shit-done/.planning/codebase/CONCERNS.md` — classifyHandoffIfNeeded bug, silent JSON parse failures
- `/home/junbeom/Projects/get-shit-done/.planning/codebase/ARCHITECTURE.md` — context management patterns, component boundaries
- `/home/junbeom/Projects/get-shit-done/get-shit-done/references/checkpoints.md` — human-action always stops, auto-approve rules
- `/home/junbeom/Projects/get-shit-done/get-shit-done/templates/config.json` — config schema with auto_advance field

### Secondary (MEDIUM confidence)
- Training data: Aider `--yes` / YOLO mode behavior — confirms hard-stop-on-failure pattern
- Training data: Cursor Agent mode — confirms multi-context-window problem is unique to GSD's architecture
- Training data: Claude Code `--dangerously-skip-permissions` — confirms YOLO operates at a higher abstraction level

---
*Research completed: 2026-02-17*
*Ready for roadmap: yes*
