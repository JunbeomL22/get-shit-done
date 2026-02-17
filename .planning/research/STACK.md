# Technology Stack: Auto-Chaining Implementation for /gsd:yolo

**Project:** gsd:yolo — Hands-Free Milestone Execution
**Researched:** 2026-02-17
**Overall confidence:** HIGH (primary evidence from existing codebase; secondary from changelog and docs)

---

## Executive Summary

GSD already has a working auto-chaining implementation. The `workflow.auto_advance` config flag plus the `--auto` argument flag create a full pipeline from discuss-phase through execute-phase through transition. The `/gsd:yolo` command's primary job is to be the entry point that activates this existing pipeline, not to build new chaining infrastructure.

The key insight from reviewing the codebase: **context isolation is not solved with `/clear`**. It's solved with `Task()` — each spawned subagent gets a fresh 200k context window. The orchestrator stays lean (~10-15% context) and delegates to Task-spawned agents. This means `/gsd:yolo` doesn't need a programmatic `/clear` API that doesn't exist.

---

## Recommended Stack

### Core Mechanism: The Two-Layer Chaining System

GSD uses two distinct mechanisms for chaining, and `/gsd:yolo` will use both:

| Mechanism | Tool | When Used | Context Impact |
|-----------|------|-----------|----------------|
| In-workflow chaining | `Task(prompt="Run /gsd:X --auto")` | Between sub-phases within a workflow | Spawns fresh 200k context |
| Cross-workflow invocation | `SlashCommand("/gsd:X --auto")` | At end of one top-level workflow, triggering the next | Same session context |
| Config persistence | `config.json workflow.auto_advance=true` | Survives context compaction between `/clear` cycles | Disk-backed, no memory dependency |

**Source:** `/get-shit-done/workflows/plan-phase.md` lines 369-376, `transition.md` lines 369-395, `CHANGELOG.md` v1.20.1 fix.

### Implementation Approach

**Recommended:** Thin orchestrator command that activates the pipeline

The `/gsd:yolo` command should:
1. Read STATE.md to find the first pending (not-yet-planned) phase
2. Set `config.json` to `mode: "yolo"` and `workflow.auto_advance: true`
3. Invoke `SlashCommand("/gsd:plan-phase {N} --auto")` or `Task(prompt="Run /gsd:plan-phase {N} --auto")`
4. The existing plan-phase → execute-phase → transition → plan-phase+1 pipeline handles the rest

**Why:** The pipeline already works (v1.19.1 added it, v1.20.1 fixed context compaction survival). Building a new orchestration layer would duplicate existing logic. The gap is a clean entry point, not new chaining code.

### State Persistence

| What persists | How | Location | Why it works across /clear |
|---------------|-----|----------|---------------------------|
| Mode (yolo/interactive) | Written to disk in `config.json` | `.planning/config.json` | File read at workflow start, not from memory |
| Auto-advance flag | `config-set workflow.auto_advance true` | `.planning/config.json` | Same — disk-backed |
| Current phase position | STATE.md `Current Phase` field | `.planning/STATE.md` | Transition workflow updates before next invocation |
| Phase completion status | ROADMAP.md checkboxes | `.planning/ROADMAP.md` | Persisted to disk after each transition |

**Source:** `CHANGELOG.md` v1.20.1: "Auto-mode (`--auto`) now survives context compaction by persisting `workflow.auto_advance` to config.json on disk"

**Confidence:** HIGH — this fix is explicitly documented and the mechanism is clear.

### Failure Detection

| Failure type | Detection point | Stop signal |
|--------------|-----------------|-------------|
| Execution failure | execute-phase verifier returns GAPS FOUND | `plan-phase` auto-advance step already stops chain on GAPS FOUND |
| Verification failure | verify-work finds must-have failures | execute-phase already stops chain when `gaps_found=true` |
| Checkpoint hit | human-action checkpoint (auth gates, external services) | checkpoints.md: "human-action still stops (auth gates cannot be automated)" |
| Phase incomplete | summaries < plans count | transition.md's safety rail: always asks even in yolo mode |

**Source:** `execute-phase.md` lines 389-395 (`"Auto-advance stopped: Execution needs review."`), `checkpoints.md` line 11.

### YOLO State Tracking (New Work Needed)

The existing pipeline doesn't have a dedicated "YOLO session" concept — there's no way to know if you're mid-YOLO or at a natural stopping point after a `/clear`. The `/gsd:yolo` command needs a lightweight mechanism to answer: "Is YOLO active, what phase did it start on, what phases remain?"

**Recommended approach:** Extend `config.json` with a `yolo` section:

```json
{
  "yolo": {
    "active": true,
    "started_at_phase": 3,
    "started_at": "2026-02-17T14:00:00Z",
    "phases_to_run": [3, 4, 5, 6]
  }
}
```

Written when `/gsd:yolo` starts, cleared when YOLO completes or fails. Survives context compaction (disk-backed). Enables resume detection: if `yolo.active=true` on startup, YOLO was interrupted and can offer to resume.

**Why config.json:** Same disk-persistence pattern already proven for `workflow.auto_advance`. Consistent with existing state management. Zero new infrastructure.

**Confidence:** HIGH — pattern matches existing auto_advance persistence design.

### Multi-Runtime Compatibility

| Runtime | SlashCommand equivalent | Task equivalent | Status |
|---------|------------------------|-----------------|--------|
| Claude Code | `SlashCommand("/gsd:X")` | `Task(prompt="Run /gsd:X --auto")` | Primary, fully supported |
| OpenCode | `skill("/gsd:X")` | Same Task pattern | Secondary, auto-converted by install.js |
| Gemini CLI | No direct equivalent | Same Task pattern | Tertiary, Task-based chaining works |

`bin/install.js` already converts `SlashCommand` → `skill` for OpenCode. The `Task(prompt="Run /gsd:X --auto")` pattern works cross-runtime without conversion since it's just a string passed to the model.

**Source:** `.planning/codebase/INTEGRATIONS.md` lines 140-160, `bin/install.js` line 311 and 475.

**Confidence:** HIGH for Claude Code and OpenCode. MEDIUM for Gemini (less tested pattern).

---

## What NOT To Do (Anti-Patterns)

### Do NOT attempt programmatic /clear

`/clear` is a user-facing UX command in Claude Code. It has no API, no slash command invoke equivalent, no hook trigger. Attempting to call it programmatically (via Bash, via SlashCommand, via any mechanism) will fail.

**The real solution:** `Task()` calls get fresh context automatically. Each subagent already operates in a clean 200k window. The orchestrator's context doesn't matter because it's lean by design.

### Do NOT poll STATE.md for completion

Polling introduces timing bugs and is unnecessary. `Task()` calls block until the subagent completes. When `Task(prompt="Run /gsd:execute-phase 3 --auto")` returns, execute-phase is done. No polling needed.

### Do NOT build a new orchestration loop in /gsd:yolo

Building `for phase in remaining_phases: plan, execute, verify` logic directly in the yolo workflow duplicates the existing plan-phase → execute-phase → transition pipeline. That pipeline is already debugged, handles edge cases (gaps, checkpoints, partial completion), and is tested across the codebase. Yolo should activate it, not replace it.

**Evidence:** The transition workflow's yolo mode already chains to `SlashCommand("/gsd:plan-phase [X+1] --auto")` — the loop is already there.

### Do NOT use .continue-here files for YOLO session state

`.continue-here.md` files are for mid-phase interruption handoffs. They are deleted by transition.md when a phase completes. Using them for YOLO session tracking would be wrong semantically and would get cleaned up during normal operation. Use `config.json yolo` section instead.

### Do NOT skip the safety rail on incomplete plans

The transition workflow's safety rail (`always_confirm_destructive` applies even in yolo mode) exists for good reason: skipping incomplete plans in an automated loop can permanently miss required work. `/gsd:yolo` must not override this.

---

## Existing Infrastructure (Do Not Rebuild)

These pieces already exist and work. YOLO uses them, doesn't replace them:

| Component | Location | What it does for YOLO |
|-----------|----------|----------------------|
| `workflow.auto_advance` config | `config.json` | Triggers auto-chain in plan-phase and execute-phase |
| `--auto` flag propagation | plan-phase, execute-phase, discuss-phase | Disables interactive gates, propagates to next command |
| `mode: "yolo"` config | `config.json` | Switches `<if mode="yolo">` branches throughout all workflows |
| `gsd-tools config-set` | `gsd-tools.cjs` | Writes config atomically; already handles dot-notation paths |
| `gsd-tools phase complete` | `gsd-tools.cjs` | Advances STATE.md and ROADMAP.md to next phase |
| Transition workflow yolo branch | `transition.md` lines 369-395 | Already chains to next phase's plan or discuss |
| Plan-phase auto-advance | `plan-phase.md` lines 358-376 | Already chains to execute-phase via Task() |
| Failure stop logic | `execute-phase.md` lines 389-395 | Already stops chain on GAPS FOUND |

**Confidence:** HIGH — directly observed in codebase.

---

## Gap Analysis: What's Actually New

Based on the existing infrastructure, only three things are genuinely new:

| Gap | New Work | Complexity |
|-----|----------|------------|
| `/gsd:yolo` command file | `commands/gsd/yolo.md` — command registration | Low |
| `/gsd:yolo` workflow | `workflows/yolo.md` — entry-point orchestration (find first pending phase, set config, invoke chain) | Low-Medium |
| YOLO session state | `config.json yolo` section + gsd-tools commands to read/write/clear it | Low |
| Resume detection | If `yolo.active=true` on startup, detect and offer resume or restart | Low |
| Stop-on-failure display | Clear output when chain stops, showing which phase failed and why | Low |

No new chaining mechanism. No new state persistence system. No new context management. The heavy lifting is already done.

---

## Sources

- `/home/junbeom/Projects/get-shit-done/.planning/PROJECT.md` — Project requirements and constraints (HIGH confidence, authoritative)
- `/home/junbeom/Projects/get-shit-done/get-shit-done/workflows/transition.md` — Yolo branch with SlashCommand invocation (HIGH confidence, direct source)
- `/home/junbeom/Projects/get-shit-done/get-shit-done/workflows/plan-phase.md` — Task() chaining pattern to execute-phase (HIGH confidence, direct source)
- `/home/junbeom/Projects/get-shit-done/get-shit-done/workflows/execute-phase.md` — Auto-advance and failure stop logic (HIGH confidence, direct source)
- `/home/junbeom/Projects/get-shit-done/CHANGELOG.md` — v1.19.1 and v1.20.1 auto-advance pipeline history (HIGH confidence, release notes)
- `/home/junbeom/Projects/get-shit-done/.planning/codebase/INTEGRATIONS.md` — Tool mapping across runtimes (HIGH confidence, codebase analysis)
- `/home/junbeom/Projects/get-shit-done/get-shit-done/references/checkpoints.md` — Checkpoint bypass rules in auto-mode (HIGH confidence, direct source)
- `/home/junbeom/Projects/get-shit-done/get-shit-done/templates/config.json` — Config schema with auto_advance field (HIGH confidence, direct source)
