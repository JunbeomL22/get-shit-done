# gsd:yolo — Hands-Free Milestone Execution

## What This Is

A new GSD command (`/gsd:yolo`) that auto-chains all remaining phases in a milestone — plan, execute, verify, advance — without manual intervention. It eliminates the repetitive `/clear` → `/gsd:plan-phase X` → `/clear` → `/gsd:execute-phase X` → `/gsd:verify-work` cycle by automating the entire loop. Built for users who've already done the thinking (discussion, requirements, roadmap) and want to let GSD run.

## Core Value

One command runs all remaining phases to completion, stopping only when something fails.

## Requirements

### Validated

- ✓ Phase planning via `/gsd:plan-phase` — existing
- ✓ Phase execution via `/gsd:execute-phase` — existing
- ✓ Work verification via `/gsd:verify-work` — existing
- ✓ State tracking via STATE.md — existing
- ✓ Config system via config.json — existing
- ✓ Auto-advance concept (config.json `workflow.auto_advance`) — existing
- ✓ Skill/command registration system — existing
- ✓ gsd-tools CLI for state management — existing

### Active

- [ ] `/gsd:yolo` command that runs all remaining phases from current position
- [ ] Auto `/clear` and re-invocation between phases
- [ ] Per-phase loop: plan → execute → verify → advance
- [ ] Skip discuss-phase (go straight to plan)
- [ ] Respect config.json workflow agents (research, plan-check, verifier)
- [ ] Stop on failure — surface what failed, let user decide
- [ ] State persistence so YOLO can resume after `/clear`

### Out of Scope

- Phase range selection (`/gsd:yolo 3-7`) — simplicity, run all remaining
- Auto-retry on failure — user wants to decide on failures
- Discussion phase in YOLO loop — user explicitly excluded it
- Modifying existing plan-phase/execute-phase/verify-work workflows — YOLO orchestrates them as-is

## Context

GSD already has the building blocks: plan-phase, execute-phase, verify-work all work independently. The `--auto` flag on `new-project` already demonstrates auto-advancing (it chains into `discuss-phase 1 --auto`). The `config.json` already has a `workflow.auto_advance` field. The key engineering challenge is the `/clear` between phases — Claude Code doesn't have a programmatic "clear and re-invoke" API. The solution needs a persistence mechanism so YOLO state survives context resets.

Existing patterns to leverage:
- `gsd:resume-work` / `gsd:pause-work` for context handoff across sessions
- `--auto` flag pattern for skipping interactive gates
- STATE.md as cross-session memory
- gsd-tools CLI for atomic state operations

## Constraints

- **Context window**: Each phase needs fresh context (~200k tokens). Must `/clear` between phases.
- **No programmatic /clear**: Claude Code doesn't expose `/clear` as an API. Solution must work within current CLI capabilities.
- **Existing workflows**: YOLO orchestrates existing commands — must not fork or duplicate plan-phase/execute-phase/verify-work logic.
- **Multi-runtime**: Must work on Claude Code (primary). OpenCode/Gemini support is secondary.

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| Skip discuss-phase in YOLO loop | User has already done discussion before YOLO; phases have enough context from roadmap | — Pending |
| Stop on failure, don't auto-retry | User wants control over failure resolution; avoids compounding errors | — Pending |
| No phase range — always run remaining | Simplicity; if you want to run specific phases, use individual commands | — Pending |
| Respect config agents, don't override | Consistency with existing workflow; user already configured their preferences | — Pending |

---
*Last updated: 2026-02-17 after initialization*
