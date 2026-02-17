# Roadmap: gsd:yolo — Hands-Free Milestone Execution

## Overview

YOLO ships as a one-shot launcher that activates GSD's existing auto-chain pipeline. Phase 1 lays the state persistence foundation that every other component depends on. Phase 2 builds the entry-point command and workflow. Phase 3 validates the full chain end-to-end and hardens failure handling. Phase 4 adds the resume and visibility polish that makes unattended operation trustworthy.

## Phases

**Phase Numbering:**
- Integer phases (1, 2, 3): Planned milestone work
- Decimal phases (2.1, 2.2): Urgent insertions (marked with INSERTED)

Decimal phases appear between their surrounding integers in numeric order.

- [x] **Phase 1: State Infrastructure** - YOLO session state persists to disk and survives context resets (completed 2026-02-17)
- [ ] **Phase 2: Launcher** - `/gsd:yolo` command and workflow exists and initializes the chain
- [ ] **Phase 3: Integration and Failure Hardening** - Full chain runs across phases and stops reliably on failure
- [ ] **Phase 4: Resume and Visibility** - Interrupted YOLO sessions resume correctly and progress is visible

## Phase Details

### Phase 1: State Infrastructure
**Goal**: YOLO session state is written to and read from disk reliably, surviving context resets
**Depends on**: Nothing (first phase)
**Requirements**: STATE-01, STATE-02, STATE-03
**Success Criteria** (what must be TRUE):
  1. Running `gsd-tools config-get workflow.yolo` after `/gsd:yolo` invocation returns the active flag, start phase, and timestamp
  2. The `yolo` stanza in `config.json` is present on disk after state write and survives a simulated context reset (re-read from file)
  3. The `yolo` stanza is removed from `config.json` after milestone completes or YOLO stops on failure
  4. Read-after-write verification confirms the stanza was not silently corrupted
**Plans**: 2 plans
Plans:
- [ ] 01-01-PLAN.md — Add config-delete and yolo-state commands to gsd-tools.cjs
- [ ] 01-02-PLAN.md — Tests and lifecycle verification for state commands

### Phase 2: Launcher
**Goal**: Users can invoke `/gsd:yolo` with no arguments and the command validates prerequisites, writes YOLO state, and invokes the first plan-phase
**Depends on**: Phase 1
**Requirements**: CHAIN-01, CHAIN-03
**Success Criteria** (what must be TRUE):
  1. Typing `/gsd:yolo` with no arguments starts the YOLO run without additional prompts
  2. The command checks prerequisites (roadmap exists, current phase is valid, no stale YOLO state) before doing anything
  3. The command sets `mode: "yolo"`, `workflow.auto_advance: true`, and writes the `yolo` stanza before invoking `plan-phase`
  4. The YOLO run respects config.json workflow agents (research, plan-check, verifier) without overriding them
**Plans**: TBD

### Phase 3: Integration and Failure Hardening
**Goal**: The full plan→execute→verify→advance chain runs automatically across all remaining phases and stops hard when verification finds gaps
**Depends on**: Phase 2
**Requirements**: CHAIN-02, FAIL-01, FAIL-02, MILE-01
**Success Criteria** (what must be TRUE):
  1. A YOLO run started on a milestone with two remaining phases completes both phases automatically without manual intervention
  2. When `verify-work` reports unmet requirements, YOLO stops immediately and does not advance to the next phase
  3. On stop, the user sees the phase number that failed, the specific gaps reported, and the command to resume after fixing
  4. YOLO stops after the last phase in the milestone and does not chain into the next milestone
  5. The `workflow.auto_advance` flag is not prematurely cleared by transition.md while a YOLO run is active
**Plans**: TBD

### Phase 4: Resume and Visibility
**Goal**: Interrupted YOLO sessions resume from the correct position and users see progress at each phase transition
**Depends on**: Phase 3
**Requirements**: STATE-04
**Success Criteria** (what must be TRUE):
  1. Re-invoking `/gsd:yolo` after an interruption (failure, crash, or manual stop) resumes from the next incomplete phase as determined by `roadmap analyze`, not from the original start phase
  2. Each phase transition displays a banner showing "YOLO mode active, phase N of M" so the user knows where the run stands
  3. On milestone completion, a summary shows which phases ran and what was accomplished
**Plans**: TBD

## Progress

**Execution Order:**
Phases execute in numeric order: 1 → 2 → 3 → 4

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 1. State Infrastructure | 0/2 | Complete    | 2026-02-17 |
| 2. Launcher | 0/TBD | Not started | - |
| 3. Integration and Failure Hardening | 0/TBD | Not started | - |
| 4. Resume and Visibility | 0/TBD | Not started | - |
