# Feature Landscape

**Domain:** Auto-pilot / YOLO mode for AI coding workflow orchestration (CLI chaining)
**Researched:** 2026-02-17
**Confidence:** MEDIUM — External tools (Claude Code `--auto-accept`, Cursor agent, Aider YOLO) verified from training data (cutoff Jan 2025) and cross-referenced with GSD codebase patterns. GSD-internal patterns are HIGH confidence from direct codebase reading.

---

## Context

This research covers `/gsd:yolo` — a command that auto-chains plan → execute → verify → advance across all remaining phases in a milestone. The research question: what do auto-pilot modes in AI coding tools look like? What's table stakes vs differentiating?

**Sources consulted:**
- GSD codebase (workflows, commands, config, CHANGELOG) — HIGH confidence
- Training knowledge of Claude Code `--dangerously-skip-permissions`, Cursor Agent mode, Aider `--yes` / `--no-git` patterns — MEDIUM confidence (may be outdated)
- GSD CHANGELOG v1.19.1, v1.20.0, v1.20.1 — HIGH confidence on existing auto-advance behavior

---

## Table Stakes

Features users expect from an auto-pilot mode. Missing = mode doesn't feel like auto-pilot.

| Feature | Why Expected | Complexity | Notes |
|---------|--------------|------------|-------|
| Single invocation entry point | Auto-pilot means "one command, walk away" — any additional steps defeat the purpose | Low | `/gsd:yolo` with no required args |
| Automatic phase-to-phase chaining | Without chaining, it's just an alias for the current workflow | Medium | plan → execute → verify → advance loop |
| Persistent state across resets | `/clear` is required between phases; state must survive — if YOLO state is lost, auto-pilot breaks silently | High | State persisted in config.json or STATE.md |
| Hard stop on failure | Users trust auto-pilot only if it stops reliably when something goes wrong — runaway execution compounds errors | Medium | Stop and surface what failed; do not retry |
| Clear failure reporting | On stop, user needs to know exactly which phase failed, what the failure was, and how to recover manually | Low | Structured output at failure point |
| Progress visibility | Walking away doesn't mean invisible — users need to know what happened while they were gone | Low | Phase banners, completion summaries |
| Respect existing config | Auto-pilot that overrides user's research/plan-check/verifier settings creates unexpected behavior | Low | Read workflow.* from config.json, use as-is |
| Safe behavior at milestone end | When all phases complete, stop — no runaway into next milestone | Low | Detect is_last_phase, clear auto-advance flag |

## Differentiators

Features that set this implementation apart. Not expected, but valued.

| Feature | Value Proposition | Complexity | Notes |
|---------|-------------------|------------|-------|
| Skip discuss-phase in YOLO loop | Discuss adds human interaction time; YOLO user has already done thinking — skipping it is the smart default | Low | Jump straight to plan-phase, not discuss-phase |
| Context-window-aware chaining | Most auto-pilot tools don't /clear between steps; GSD does this correctly because each phase needs fresh 200k context | High | The defining engineering challenge of this feature |
| Phase-level granularity (not task-level) | Auto-chaining at the phase boundary is the right abstraction — tasks already auto-execute within plan-phase+execute-phase | Low | YOLO orchestrates phases, not individual tasks |
| Idempotent resume after interruption | If user returns mid-YOLO (failure, crash, curiosity), they can see state clearly and resume or bail | Medium | YOLO state in STATE.md or config.json survives interruption |
| Transparent mode indicator | User should see "YOLO mode active, phase N of M" not just silent execution | Low | Banner at each phase transition |
| Verify-before-advance gate | Auto-pilot that skips verification ships broken code silently — YOLO should run verifier (if configured) before advancing | Medium | Failure in verification = stop, not advance |

## Anti-Features

Features to explicitly NOT build for /gsd:yolo.

| Anti-Feature | Why Avoid | What to Do Instead |
|--------------|-----------|-------------------|
| Auto-retry on failure | Compounds errors — a broken phase executed again likely fails the same way or breaks more things. Aider's `--yes` retry loops are a known pain point. | Stop, surface failure, let user decide |
| Phase range selection (`/gsd:yolo 3-7`) | Adds UI complexity for a "walk away" command; if you want specific phases, use individual commands. Scope creep. | Run all remaining phases. If user is mid-milestone, that's the natural starting point. |
| Override user's configured agents | YOLO users have already configured research/plan-check/verifier in config.json for a reason | Read config and respect it — YOLO accelerates the loop, doesn't change the quality knobs |
| Discussion phase in YOLO loop | `discuss-phase` is explicitly interactive (conversation, clarification, context gathering) — incompatible with "walk away" | Skip it; plan-phase reads ROADMAP + requirements directly |
| New interactive gates | Any AskUserQuestion inside YOLO loop breaks the "walk away" contract | Only stop on genuine failure, not decisions |
| Modifying existing workflows | YOLO should orchestrate plan-phase/execute-phase/verify-work as-is — not fork or duplicate their logic | Invoke them via SlashCommand/Task |
| Auto-commit milestone on completion | Completing a milestone is a meaningful checkpoint — user should explicitly review what was built before archiving | Stop after last phase, surface completion, offer `/gsd:complete-milestone` |
| Silent gap bypass | If verification finds gaps, do NOT silently advance — gaps mean the work is not done | Stop on gaps_found, same as any other failure |
| Cost/token budget enforcement | Adds complexity without clear user value at this stage; power users run YOLO accepting it will use tokens | Defer budget awareness to a separate feature |

---

## Feature Dependencies

```
YOLO state persistence → Auto-chaining (chaining requires knowing where we are after /clear)
Auto-chaining → Skip discuss-phase (without chaining, skip is irrelevant)
Verify-before-advance gate → Hard stop on failure (gate only meaningful if failure stops chain)
Hard stop on failure → Clear failure reporting (stop is useless without surfacing what happened)
Phase-level granularity → Context-window-aware chaining (phase = the /clear boundary)
```

## MVP Recommendation

Prioritize:
1. YOLO state persistence — the hardest engineering problem; everything else depends on it
2. Single invocation entry point — the user-facing API
3. Automatic phase chaining (plan → execute → advance) — core loop
4. Hard stop on failure with clear reporting — the safety guarantee users rely on
5. Skip discuss-phase — correct default for YOLO context

Defer:
- Idempotent resume: valuable but adds complexity; implement in phase 2 after core loop works
- Transparent mode indicator: useful but polish; banners can be added once core loop is stable

---

## Behavioral Patterns from AI Coding Tools

**NOTE:** This section uses training data (cutoff Jan 2025) — MEDIUM confidence. Verify against current docs before implementation decisions.

### Claude Code auto-advance (v1.20.0+ in GSD)

GSD's own CHANGELOG documents the auto-advance pattern:
- `--auto` flag persisted to `workflow.auto_advance` in config.json (survives `/clear`)
- Checkpoints auto-approved: human-verify → "approved", decision → first option
- `human-action` type still stops (auth gates cannot be automated)
- Auto-advance clears on milestone complete
- v1.20.1: Survived context compaction by persisting to disk

**Key insight (HIGH confidence):** The persistence mechanism (`config-set workflow.auto_advance true`) is already proven in GSD. YOLO needs to extend this pattern, not reinvent it.

### Aider YOLO / `--yes` mode (MEDIUM confidence, training data)

- `--yes` flag auto-accepts all AI-proposed changes without confirmation
- `--no-git` skips git operations entirely (different use case)
- `--auto-commits` (default on) commits after each change
- No built-in chaining across multiple "phases" — Aider is single-session
- Failure behavior: stop at first error, report it, wait for user

**Key insight:** Aider's YOLO is simpler (single session, no phase concept). GSD's YOLO is harder because phases require context resets.

### Cursor Agent mode (MEDIUM confidence, training data)

- Agent mode auto-applies code edits across multiple files without confirmation
- Loops until task is "complete" according to model's judgment
- Stops when: explicit failure, user interrupts, or model returns completion signal
- No equivalent of GSD's phase boundary / context reset concept
- Verification: relies on model's self-assessment, not independent verifier agent

**Key insight:** Cursor's agent mode is within a single context window. The multi-phase, multi-context-window problem GSD faces is fundamentally harder.

### Claude Code `--dangerously-skip-permissions` (MEDIUM confidence, training data)

- Skips all tool-use permission prompts
- Allows headless / CI execution
- Does not chain commands — still one invocation per command
- Relevant for: YOLO's need to skip interactive prompts within phases

**Key insight:** GSD's YOLO is at a higher abstraction level than `--dangerously-skip-permissions`. YOLO chains commands; skip-permissions removes friction within a command.

---

## Common Patterns Across All Auto-Pilot Tools

These patterns appear consistently across tools (HIGH confidence — observed in GSD codebase directly, MEDIUM from external tools):

1. **Persistence over session boundaries** — state that survives interruptions (GSD: config.json `workflow.auto_advance`)
2. **Hard stop on failure, no silent swallowing** — all tools stop visibly on genuine failure
3. **Clear "auto mode active" signaling** — users need to know they're in auto mode (GSD: banner with `⚡ Auto-advancing`)
4. **Idempotency via skip-completed work** — re-running auto-pilot skips already-done work (GSD: execute-phase skips plans with SUMMARY.md)
5. **Natural stopping points respected** — milestone/session/phase boundaries are not crossed automatically without signal

---

## Sources

| Source | Type | Confidence |
|--------|------|------------|
| GSD workflows: `execute-phase.md`, `plan-phase.md`, `transition.md` | Direct codebase read | HIGH |
| GSD CHANGELOG v1.19.1, v1.20.0, v1.20.1 entries | Direct codebase read | HIGH |
| GSD `.planning/PROJECT.md` (yolo requirements) | Direct codebase read | HIGH |
| GSD `.planning/codebase/ARCHITECTURE.md` | Direct codebase read | HIGH |
| GSD `config.json` schema (mode, workflow.auto_advance) | Direct codebase read | HIGH |
| Aider `--yes` / YOLO mode behavior | Training data (cutoff Jan 2025) | MEDIUM |
| Cursor agent mode behavior | Training data (cutoff Jan 2025) | MEDIUM |
| Claude Code `--dangerously-skip-permissions` | Training data (cutoff Jan 2025) | MEDIUM |
