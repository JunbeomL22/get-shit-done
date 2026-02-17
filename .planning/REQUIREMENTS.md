# Requirements: gsd:yolo

**Defined:** 2026-02-17
**Core Value:** One command runs all remaining phases to completion, stopping only when something fails.

## v1 Requirements

Requirements for initial release. Each maps to roadmap phases.

### State Persistence

- [x] **STATE-01**: YOLO session state written to config.json (active flag, start phase, timestamp)
- [x] **STATE-02**: YOLO state survives `/clear` by reading from disk on each invocation
- [x] **STATE-03**: YOLO state cleaned up on milestone complete or failure stop
- [x] **STATE-04**: Re-running `/gsd:yolo` after interruption resumes from correct phase position

### Chain Orchestration

- [x] **CHAIN-01**: User can invoke `/gsd:yolo` with no args to run all remaining phases
- [x] **CHAIN-02**: Each phase runs plan → execute → verify → advance automatically
- [x] **CHAIN-03**: YOLO respects config.json workflow agents (research, plan-check, verifier)

### Failure Handling

- [x] **FAIL-01**: YOLO hard-stops when verification finds gaps (requirements not met)
- [x] **FAIL-02**: On stop, user sees which phase failed, what went wrong, and how to recover

### Milestone Boundary

- [x] **MILE-01**: YOLO stops after the last phase completes (does not chain into next milestone)

## v2 Requirements

Deferred to future release. Tracked but not in current roadmap.

### Chain Orchestration

- **CHAIN-04**: Skip discuss-phase in YOLO loop (go straight to plan)

### Failure Handling

- **FAIL-03**: False-positive detection for `classifyHandoffIfNeeded` Claude Code bug
- **FAIL-04**: Pre-scan plans for `human-action` checkpoints before starting

### Milestone Boundary

- **MILE-02**: YOLO owns auto_advance lifecycle (guard against premature clear in transition.md)

## Out of Scope

| Feature | Reason |
|---------|--------|
| Phase range selection (`/gsd:yolo 3-7`) | Simplicity — run all remaining, use individual commands for specific phases |
| Auto-retry on failure | Compounds errors — user wants to decide on failures |
| New interactive gates in YOLO loop | Breaks the "walk away" contract |
| Modifying existing plan-phase/execute-phase/verify-work workflows | YOLO orchestrates as-is, avoids forking |
| Auto-commit milestone on completion | User should review before archiving |
| Cost/token budget enforcement | Adds complexity without clear value at this stage |

## Traceability

Which phases cover which requirements. Updated during roadmap creation.

| Requirement | Phase | Status |
|-------------|-------|--------|
| STATE-01 | Phase 1 | Satisfied |
| STATE-02 | Phase 1 | Satisfied |
| STATE-03 | Phase 1 | Satisfied |
| STATE-04 | Phase 5 (gap closure) | Satisfied |
| CHAIN-01 | Phase 2 | Satisfied |
| CHAIN-02 | Phase 3 | Satisfied |
| CHAIN-03 | Phase 2 | Satisfied |
| FAIL-01 | Phase 5 (gap closure) | Satisfied |
| FAIL-02 | Phase 5 (gap closure) | Satisfied |
| MILE-01 | Phase 3 | Satisfied |

**Coverage:**
- v1 requirements: 10 total
- Satisfied: 10
- Pending: 0
- Unmapped: 0 ✓

---
*Requirements defined: 2026-02-17*
*Last updated: 2026-02-17 after gap closure phase creation*
