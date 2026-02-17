# Architecture

**Analysis Date:** 2026-02-17

## Pattern Overview

**Overall:** Spec-driven orchestration with subagent coordination

GSD is a meta-prompting and context engineering system that automates AI-assisted development. It uses a command-driven architecture where:
- **Orchestrators** coordinate workflow steps and spawn specialized subagents
- **Subagents** execute atomic tasks (research, planning, implementation, verification)
- **Shared state** (markdown documents in `.planning/`) persists context across sessions
- **Tools** (gsd-tools CLI) centralize repetitive operations (config, state, git, phase management)

**Key Characteristics:**
- Lean orchestrators (5-15% context) → subagents run with fresh context (200k tokens)
- Documents written directly (no context transfer back to orchestrator)
- Phase-based decomposition with decimal versioning for inserted work
- Checkpoint protocol for human decisions mid-execution
- Automatic deviation handling during execution (Rules 1-4)

## Layers

**Command Layer:**
- Location: `/commands/gsd/` (20+ markdown command files)
- Purpose: Public API exposed via Claude Code / OpenCode / Gemini CLI
- Contains: Command metadata (name, description, tools), execution context, workflow references
- Examples: `new-project.md`, `plan-phase.md`, `execute-phase.md`, `map-codebase.md`
- Depends on: Workflows, gsd-tools CLI
- Used by: End users, external orchestrators

**Workflow Layer:**
- Location: `/get-shit-done/workflows/` (30+ markdown workflow files)
- Purpose: Implementation details for commands; orchestrate subagents and tools
- Contains: Step-by-step procedures, bash calls to gsd-tools, subagent spawning logic, decision gates
- Key workflows: `new-project.md`, `plan-phase.md`, `execute-phase.md`, `map-codebase.md`, `plan-milestone-gaps.md`
- Depends on: Templates, references, gsd-tools
- Used by: Commands

**Subagent Layer:**
- Location: `/agents/` (11 markdown agent files)
- Purpose: Specialized Claude instances that execute focused work
- Agents: `gsd-planner`, `gsd-executor`, `gsd-verifier`, `gsd-phase-researcher`, `gsd-project-researcher`, `gsd-research-synthesizer`, `gsd-roadmapper`, `gsd-debugger`, `gsd-integration-checker`, `gsd-plan-checker`, `gsd-codebase-mapper`
- Each has: Role definition, execution flow, validation rules, decision trees
- Depends on: Templates, references, gsd-tools, project state
- Used by: Workflows (via Task tool spawning)

**Tools Layer:**
- Location: `/get-shit-done/bin/gsd-tools.cjs` (~3000 lines)
- Purpose: Centralized CLI for state management, phase operations, config, git, validation
- Functions: 120+ atomic commands grouped by category (state, phase, roadmap, milestone, config, git, validation, scaffolding, verification)
- Model profiles: Precomputed Claude model assignments (opus/sonnet/haiku) per agent per mode
- Depends on: File system, git, Node.js
- Used by: Workflows (bash calls), scripts

**State Layer:**
- Location: `.planning/` directory structure
- Purpose: Project memory spanning sessions and phases
- Core documents:
  - `PROJECT.md` — Project context, core value, requirements, constraints, decisions
  - `REQUIREMENTS.md` — Requirement definitions with traceability matrix
  - `ROADMAP.md` — Phase structure, goals, success criteria, plans inventory
  - `STATE.md` — Current position, metrics, blockers, decisions digest
  - `phases/{N}-{name}/` — Phase-specific work (CONTEXT, PLAN, SUMMARY, RESEARCH)
  - `.planning/codebase/` — Architecture/stack analysis documents
  - `.planning/config.json` — Workflow preferences (model profile, branching, research enabled)
  - `.planning/todos/` — Idea backlog
  - `.planning/milestones/` — Archived phases and milestone summaries

**Template Layer:**
- Location: `/get-shit-done/templates/` (30+ markdown template files)
- Purpose: Scaffolding for standard documents
- Key templates: `project.md`, `requirements.md`, `roadmap.md`, `state.md`, `milestone.md`, `phase-prompt.md`, `summary.md`, `discovery.md`, `research.md`, `context.md`
- Codebase templates: `architecture.md`, `structure.md`, `stack.md`, `integrations.md`, `conventions.md`, `testing.md`, `concerns.md`
- Depends on: None
- Used by: Workflows, agents

**References Layer:**
- Location: `/get-shit-done/references/` (13 markdown reference files)
- Purpose: Patterns, protocols, and decision tables
- Examples: `checkpoints.md` (checkpoint task patterns), `git-integration.md` (git workflow), `model-profiles.md` (model selection), `verification-patterns.md` (test patterns), `tdd.md` (TDD protocol), `ui-brand.md` (UI consistency guidelines)
- Depends on: None
- Used by: Workflows, agents, templates

**Installation Layer:**
- Location: `/bin/install.js` (~2000 lines)
- Purpose: Configure GSD for Claude Code, OpenCode, Gemini runtimes
- Installs: Commands, workflows, agents, templates to runtime config directories
- Depends on: Node.js, home directory access
- Used by: npm installation flow

## Data Flow

**Project Lifecycle Flow:**

1. **Initialization (`/gsd:new-project`)**
   - User describes project idea
   - Workflow prompts for: mode, depth, git strategy, research preference
   - Spawns `gsd-project-researcher` (optional research phase)
   - Spawns `gsd-research-synthesizer` (if research enabled)
   - Collects requirements via `gsd-executor` input
   - Spawns `gsd-roadmapper` (creates phase structure)
   - Creates: PROJECT.md, REQUIREMENTS.md, ROADMAP.md, STATE.md, config.json
   - Creates: Phase directories with padded naming (01-project-setup, 02-api-foundation)

2. **Phase Planning (`/gsd:plan-phase {N}`)**
   - Load STATE.md (current position) + ROADMAP.md (phase goal) + REQUIREMENTS.md (success criteria)
   - Optional: Load CONTEXT.md (user's design decisions from `/gsd:discuss-phase`)
   - Spawn `gsd-phase-researcher` (if research needed)
   - Spawn `gsd-planner` with: phase goal, requirements, context, existing codebase (if brownfield)
   - Planner produces: N × PLAN.md files (typically 2-5 per phase)
   - Each PLAN.md contains: objective, context references, tasks (2-3 per plan), verification, must-haves
   - Spawn `gsd-plan-checker` (optional, in revision loop)
   - Loop: If checker finds gaps → re-plan → re-check (max 3 iterations)
   - Commit: planning docs to git

3. **Phase Execution (`/gsd:execute-phase {N}`)**
   - Load phase plans, group by wave (parallelization)
   - Spawn `gsd-executor` per plan (wave-parallel if enabled)
   - Executor: Load PLAN.md → execute tasks → commit per-task → create SUMMARY.md
   - Executor deviation handling: Auto-fix bugs (Rule 1), auto-add missing critical functionality (Rule 2), auto-fix blockers (Rule 3), checkpoint on architectural changes (Rule 4)
   - Collect results: git commits, files modified, time spent
   - Update STATE.md: current position, metrics, blockers
   - Verification option: Spawn `gsd-verifier` if enabled

4. **Verification (`/gsd:verify-work`)**
   - Load phase's SUMMARY.md files
   - Spawn `gsd-verifier` per plan
   - Verifier: Check must-haves (truths, artifacts, key-links), run tests, spot-check code
   - If failures: Spawn `gsd-debugger` per failure
   - Option: `/gsd:plan-milestone-gaps` to create gap-closure plans

5. **Milestone Completion (`/gsd:complete-milestone`)**
   - Archive phases to `milestones/v{X.Y}-phases/`
   - Create MILESTONES.md entry with stats (files, LOC, time, accomplishments)
   - Commit milestone record

**State Transitions:**

```
PROJECT NOT INITIALIZED
           ↓
    /gsd:new-project
           ↓
PROJECT READY → PHASE 1 READY TO PLAN
           ↓
    /gsd:plan-phase 1
           ↓
PHASE 1 PLANNING (in progress) → PHASE 1 READY TO EXECUTE
           ↓
    /gsd:execute-phase 1
           ↓
PHASE 1 EXECUTING (in progress) → PHASE 1 COMPLETE
           ↓
UPDATE STATE.md → next phase ready to plan
           ↓
    LOOP: plan-phase → execute-phase
```

## Key Abstractions

**Phase:**
- Purpose: Logical unit of work (feature, subsystem, or milestone)
- Examples: "01-authentication", "02-api-foundation", "02.1-security-hardening" (decimal = inserted)
- Representation: Directory in `.planning/phases/{padded}-{slug}/` + roadmap section
- Lifecycle: Planned → Executing → Complete

**Plan:**
- Purpose: Executable unit within a phase (2-3 tasks, completes in 30-120 min)
- Naming: `{phase}-{sequence}-PLAN.md` (e.g., `01-02-PLAN.md` for Phase 1, Plan 2)
- Frontmatter: phase, plan, type (execute|tdd), wave, depends_on, requirements, must_haves (truths, artifacts, key_links)
- Contains: objective, context references, 2-3 auto tasks, verification, success criteria
- Output: Commits (per-task), SUMMARY.md, created/modified files

**Task:**
- Purpose: Atomic work unit (5-30 min execution)
- Types: `auto` (autonomous), `checkpoint:decision`, `checkpoint:human-verify`, `checkpoint:system-verify`
- Format: XML with name, files, action (what to do, how, why), verify (command), done (acceptance criteria)
- Executed by: gsd-executor in sequence or parallel (if wave-based)

**Checkpoint:**
- Purpose: Pause execution for human decision or verification
- Types: `decision` (choose option), `human-verify` (visual check), `system-verify` (automated check)
- Protocol: Executor halts, returns structured message with context, awaits resume signal
- Lifecycle: Pause → User input → Resume with fresh executor agent

**Wave:**
- Purpose: Grouping of plans that execute in parallel
- Computation: Pre-assigned during planning based on dependency graph
- Execution: Sequential per-wave (all plans in wave N complete before wave N+1 starts)
- Parallelization: Within-wave parallelism controlled by config (parallelization: true/false)

**Deviation Rule:**
- Purpose: Handle unplanned work discovered during execution
- Rules:
  - **Rule 1**: Auto-fix bugs (broken code, errors, incorrect logic)
  - **Rule 2**: Auto-add missing critical functionality (validation, auth, error handling)
  - **Rule 3**: Auto-fix blocking issues (missing dependencies, broken imports, config errors)
  - **Rule 4**: Checkpoint on architectural changes (new tables, framework switches, major schema changes)
- Tracked: All deviations logged in SUMMARY.md for post-phase analysis

**Requirement (REQ):**
- Purpose: User-facing capability mapped to phases
- Naming: `{CATEGORY}-{NN}` (AUTH-01, API-02, UI-03)
- Status: Pending → In Progress → Complete → Validated
- Traceability: Mapped to specific phases in REQUIREMENTS.md traceability table
- Verification: Tested during execution, marked complete when shipped

## Entry Points

**Command Entry Point (`/commands/gsd/`):**
- Location: `/commands/gsd/{command}.md`
- Triggers: User invokes `/gsd:{command}` in Claude Code / OpenCode / Gemini
- Responsibilities: Define name, description, tools, execution_context (template references), process (delegate to workflow)
- Example flow: `/gsd:new-project` → command loads `/workflows/new-project.md` → workflow orchestrates initialization

**Workflow Entry Point (`/get-shit-done/workflows/`):**
- Location: `/get-shit-done/workflows/{command}.md`
- Triggers: Command invokes workflow (via @reference or copy)
- Responsibilities: Implement steps, call gsd-tools, spawn subagents, handle decisions, commit docs
- Example flow: new-project workflow: questions → research → requirements → roadmap

**Subagent Entry Point (`/agents/`):**
- Location: `/agents/{agent-name}.md`
- Triggers: Workflow spawns via Task tool with `subagent_type="{agent-name}"`
- Responsibilities: Load context from init call, execute focused work, produce output (PLAN, SUMMARY, RESEARCH), return confirmation
- Example: gsd-executor spawned by execute-phase, loads PLAN.md, executes tasks, returns SUMMARY.md + git commits

**Tools Entry Point (`/get-shit-done/bin/gsd-tools.cjs`):**
- Location: `/get-shit-done/bin/gsd-tools.cjs`
- Triggers: Bash calls from workflows (`node ~/.claude/get-shit-done/bin/gsd-tools.cjs {command} {args}`)
- Responsibilities: Atomically load context (state, config, codebase map), manipulate files, execute git operations
- Example: `gsd-tools.cjs init plan-phase 1` → returns JSON with all context needed for planning

## Error Handling

**Strategy:** Graceful degradation with checkpoints for unresolved issues

**Patterns:**

1. **Validation Before Action:** All workflows call gsd-tools validation before proceeding
   - `validate consistency` — Check phase numbering, disk/roadmap sync
   - `validate health` — Check .planning/ integrity, offer repair

2. **Conditional Logic:** Workflows branch based on context state
   - Example: If CONTEXT.md missing → ask user to run `/gsd:discuss-phase` first
   - Example: If plan already executed → skip planning, go straight to execution

3. **Automatic Repair:** Some operations auto-repair when safe
   - `state update` — Can overwrite, but logs change
   - `phase complete` → gsd-tools handles renumbering of subsequent phases

4. **Checkpoint on Uncertainty:** When in doubt, pause for human input
   - Rule 4 (Executor deviation): Architectural change → checkpoint
   - Plan checker: Gaps found → checkpoint with options (revise, skip, override)

5. **Deferred Issues:** Out-of-scope failures logged for later
   - Executor creates `deferred-items.md` in phase directory
   - Pre-existing lint warnings, unrelated failures go here (not fixed in current task)

## Cross-Cutting Concerns

**Logging:**
- Approach: Markdown-based audit trail (SUMMARY.md, STATE.md, ROADMAP.md progress table, git commit messages)
- Patterns: Each task logs commit hash, duration, files modified; phase logs total stats; STATE.md aggregates
- Tools: Git for implementation history, STATE.md for session continuity

**Validation:**
- Approach: Schema-based (frontmatter validation), reference checking, execution verification
- Patterns: Frontmatter (phase, plan, requirements fields required), @-references must resolve, must-haves must be verified post-execution
- Tools: gsd-tools.cjs validators (verify plan-structure, verify references, verify commits)

**Authentication (to AI models):**
- Approach: Model profile resolution from config.json
- Patterns: Config stores `model_profile` (quality/balanced/budget), gsd-tools resolves to specific Claude models (opus/sonnet/haiku)
- Tools: gsd-tools.cjs resolve-model, MODEL_PROFILES table in tool

**Git Integration:**
- Approach: Commit after each task, plus periodic planning/milestone commits
- Patterns: Task commits use format `feat(NN-MM): task description`, planning commits use `plan(NN): phase name`, milestones use `milestone: vX.Y name`
- Tools: gsd-tools.cjs commit (with message generation, file selection), workflows handle branch creation/switching

**Context Management:**
- Approach: Fresh context per subagent, documents written directly (no context transfer)
- Patterns: Workflows keep context lean (~10-15%), pass file paths only to subagents, subagents read full context themselves
- Tools: gsd-tools.cjs init commands (plan-context, execute-context, map-codebase) load and structure context; --include flag for selective file content

---

*Architecture analysis: 2026-02-17*
