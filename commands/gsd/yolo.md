---
name: gsd:yolo
description: Run all remaining phases automatically without manual intervention
argument-hint: ""
allowed-tools:
  - Read
  - Write
  - Bash
  - Task
  - AskUserQuestion
---
<objective>
Run all remaining phases to completion automatically. One command, no prompts, stops only on failure.

Validates prerequisites (roadmap exists, next phase available, no stale YOLO state), writes YOLO state, then invokes plan-phase with --auto to activate the existing auto-advance chain. The chain runs plan-phase → execute-phase → transition for each remaining phase without user intervention.
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
