# Architecture

**Analysis Date:** 2026-02-28

## Pattern Overview

**Overall:** Meta-prompting orchestration system with subagent specialization

GSD is a context-engineering framework that orchestrates specialized Claude agents through a command/workflow/agent three-layer hierarchy. Each component is a prompt-based agent that receives structured context, executes isolated work, and returns results back to the orchestrator. The system solves context rot by splitting large tasks into atomic phases with persistent state tracking.

**Key Characteristics:**
- Orchestrator-agent pattern: Commands spawn workflows which spawn specialized agents
- Prompt-based composition: Agent logic defined in markdown files, executed by Claude Code/OpenCode/Gemini
- State-driven progression: .planning/ directory tracks project position, decisions, and metrics
- Atomic execution: Each plan executes independently with committed changes
- Deviation handling: Agents auto-fix bugs/blocking issues within scope, checkpoint on architectural decisions
- Wave-based parallelization: Plans grouped by dependency waves for parallel execution
- Model cost optimization: Agent model selection based on task complexity (opus/sonnet/haiku)

## Layers

**Command Layer:**
- Location: `/home/junbeom/Projects/fork/get-shit-done/commands/gsd/`
- Purpose: User entry points (30+ commands like /gsd:new-project, /gsd:execute-phase, /gsd:map-codebase)
- Contains: Markdown files with `<objective>` and `<execution_context>` directing to workflows
- Depends on: Workflows for actual implementation
- Used by: Claude Code CLI through slash commands; each file is auto-registered as `/gsd:filename`

**Workflow Layer:**
- Location: `/home/junbeom/Projects/fork/get-shit-done/get-shit-done/workflows/`
- Purpose: Orchestrate complex processes (project initialization, phase execution, research)
- Contains: Markdown orchestrators with `<process>` steps, decision points, agent spawning logic
- Depends on: Specialized agents to execute work; references agents via role specification
- Used by: Commands; workflows call agents via `Task()` primitives with context files
- Key workflows: `new-project.md` (sets up .planning/ structure), `execute-phase.md` (runs plans), `research-phase.md` (explores unknowns), `map-codebase.md` (analyzes code)

**Agent Layer:**
- Location: `/home/junbeom/Projects/fork/get-shit-done/agents/`
- Purpose: Specialized single-responsibility agents (mapper, planner, executor, verifier, debugger)
- Contains: Role definitions with execution rules, error handling, output formats
- Depends on: Persistent state (STATE.md, .planning/), file system for reading code
- Used by: Workflows invoke agents by spawning them with context and plan files
- Agents:
  - `gsd-planner`: Creates PLAN.md from context
  - `gsd-executor`: Executes PLAN.md with atomic commits and deviation handling
  - `gsd-codebase-mapper`: Analyzes codebase → writes STACK.md, ARCHITECTURE.md, etc.
  - `gsd-verifier`: Validates execution results
  - `gsd-debugger`: Diagnoses issues during failed phases
  - `gsd-roadmapper`: Designs project roadmap from requirements
  - Others: Researchers, synthesizers, checkers for specialized tasks

## Data Flow

**Project Initialization Flow:**

1. User: `/gsd:new-project`
2. Command → Workflow `new-project.md` loads execution context
3. Workflow: Ask questions → run research (optional) → synthesize requirements → create roadmap
4. Agents spawned in sequence: `gsd-project-researcher` (if research needed) → `gsd-research-synthesizer` → `gsd-roadmapper`
5. Workflow outputs: Creates .planning/ structure with PROJECT.md, REQUIREMENTS.md, ROADMAP.md
6. Commits: `docs(init): project initialized` with all planning files
7. Result: `.planning/STATE.md` records position at Phase 01, Plan 01

**Phase Execution Flow:**

1. User: `/gsd:execute-phase 1`
2. Command → Workflow `execute-phase.md` (orchestrator)
3. Workflow initialization: `gsd-tools init execute-phase 1` returns phase context (plans, waves, dependencies)
4. Workflow analyzes plan dependencies → groups into execution waves
5. For each wave in sequence:
   - Workflow spawns `gsd-executor` agents (parallel if `parallelization=true`)
   - Each executor: reads PLAN.md → executes tasks → commits per-task → creates SUMMARY.md
   - Executor detects checkpoints: pauses if checkpoint found (awaits human decision)
   - If auto-mode: executor auto-approves non-human-action checkpoints
6. After plan completes: executor calls `gsd-tools state advance-plan`
7. After wave completes: orchestrator checks for checkpoints; if none, continues next wave
8. After phase completes: orchestrator updates STATE.md, offers next phase
9. Result: `.planning/phases/01-phase-name/01-01-SUMMARY.md`, `.planning/phases/01-phase-name/01-02-SUMMARY.md`, etc.

**Codebase Analysis Flow (map-codebase):**

1. User: `/gsd:map-codebase`
2. Command → Workflow `map-codebase.md` (orchestrator)
3. Workflow creates `.planning/codebase/` directory
4. Workflow spawns 4 parallel agents (each with independent focus):
   - Agent 1: `gsd-codebase-mapper` (tech focus) → writes STACK.md, INTEGRATIONS.md
   - Agent 2: `gsd-codebase-mapper` (arch focus) → writes ARCHITECTURE.md, STRUCTURE.md
   - Agent 3: `gsd-codebase-mapper` (quality focus) → writes CONVENTIONS.md, TESTING.md
   - Agent 4: `gsd-codebase-mapper` (concerns focus) → writes CONCERNS.md
5. Each mapper: explores codebase for their focus → writes document directly to `.planning/codebase/`
6. Orchestrator waits for all 4 agents
7. Verification: Orchestrator checks all 7 files exist, reports line counts
8. Final commit: `docs(codebase): map complete`

**State Management:**

- `.planning/STATE.md`: Current phase/plan position, performance metrics, decisions, blockers, session info
- `.planning/config.json`: User preferences (model profile, workflow mode, agent overrides)
- `.planning/PROJECT.md`: Project vision, requirements, roadmap summary
- `.planning/ROADMAP.md`: Full project phases with status, plan counts, dependencies
- `.planning/phases/XX-name/PLAN.md`: What to build in this plan (frontmatter + objectives + tasks)
- `.planning/phases/XX-name/SUMMARY.md`: What was built (commits, deviations, decisions)
- `.planning/codebase/*.md`: Static analysis of existing codebase (tech stack, architecture, conventions)

## Key Abstractions

**Phase:**
- Purpose: Logical grouping of related work (e.g., "Auth System", "API Layer", "Testing")
- Examples: `01-state-infrastructure`, `02-launcher`, `03-integration-and-failure-hardening`
- Pattern: Each phase is a directory under `.planning/phases/` containing PLAN.md + SUMMARY.md files
- Decimal numbering: Phases use decimal progression (1, 1.1, 1.2, 2, 2.1, etc.) for depth control

**Plan:**
- Purpose: Atomic unit of executable work within a phase (e.g., "Set up state persistence", "Install executor")
- Examples: `01-01-state-infrastructure.md`, `05-01-fix-stopped-phase-detection.md`
- Pattern: PLAN.md with frontmatter (phase, plan, type, autonomous, wave, depends_on) + tasks with execution types (auto, checkpoint:*)
- Output: Paired SUMMARY.md documenting what was built, deviations, decisions

**Checkpoint:**
- Purpose: Pause points in execution where human input required (decision, verification, manual action)
- Types: `checkpoint:human-verify` (visual verification), `checkpoint:decision` (choice needed), `checkpoint:human-action` (unavoidable manual step like 2FA)
- Pattern: Task with `type="checkpoint:*"` in PLAN.md; executor stops, returns checkpoint structure with options/verification steps
- Auto-mode behavior: `checkpoint:human-verify` and `checkpoint:decision` auto-approved; `checkpoint:human-action` pauses

**Wave:**
- Purpose: Group plans that can execute in parallel (no inter-wave dependencies)
- Pattern: Plan frontmatter `wave: 1`, `wave: 2` indicates execution order; plans in same wave run parallel if parallelization enabled
- Example: Wave 1 has [01-01, 01-02] (independent), Wave 2 has [01-03] (depends on Wave 1)

**Deviation:**
- Purpose: Handle discovered work outside plan scope with predefined rules
- Rules:
  - Rule 1 (Auto-fix bugs): Broken code, logic errors, type errors → fix inline
  - Rule 2 (Auto-add critical functionality): Missing error handling, validation, auth → add inline
  - Rule 3 (Auto-fix blocking issues): Missing dependency, broken import, broken env var → fix inline
  - Rule 4 (Architectural decision): New DB table, major schema change, framework swap → checkpoint
- Pattern: Executor applies rules automatically, documents in SUMMARY.md under "Deviations from Plan"
- Scope boundary: Only auto-fix issues DIRECTLY caused by current task; pre-existing issues deferred to `deferred-items.md`

## Entry Points

**Command Entry Points:**

- Location: `/home/junbeom/Projects/fork/get-shit-done/commands/gsd/`
- Mechanism: Each .md file automatically registered as `/gsd:filename` in Claude Code
- Key entry points:
  - `/gsd:new-project`: Initialize project with discovery, requirements, roadmap
  - `/gsd:plan-phase N`: Generate PLAN.md for phase N
  - `/gsd:execute-phase N`: Execute PLAN.md(s) for phase N with atomic commits
  - `/gsd:verify-work`: Validate execution quality and flag issues
  - `/gsd:map-codebase`: Analyze codebase → write ARCHITECTURE.md, STACK.md, etc.
  - `/gsd:research-phase`: Deep exploration of unknown areas
  - `/gsd:yolo`: Chain all remaining phases (plan → execute → verify → advance) in one command
  - `/gsd:help`, `/gsd:progress`, `/gsd:settings`: Information/configuration

**Installer Entry Point:**

- Location: `/home/junbeom/Projects/fork/get-shit-done/bin/install.js`
- Triggers: `npx get-shit-done-cc@latest` (global or local install)
- Responsibilities: Install GSD into ~/.claude/, ~/.opencode/, or ~/.gemini/ config directories
- Outputs: Registers all commands and workflows in the chosen runtime

**CLI Tool Entry Point:**

- Location: `/home/junbeom/Projects/fork/get-shit-done/get-shit-done/bin/gsd-tools.cjs`
- Triggers: Called by agents and workflows via `node ~/.claude/get-shit-done/bin/gsd-tools.cjs <command>`
- Responsibilities: State management, config parsing, phase/roadmap queries, git commits
- Centralizes: Repetitive bash patterns (file reading, JSON parsing, git operations) across 50+ files

## Error Handling

**Strategy:** Multi-layered with agent autonomy + orchestrator oversight

**Layer 1: Executor Autonomy (within deviation rules)**
- Executor encounters error during task execution
- Applies Rule 1/2/3: Can fix automatically if within scope (bugs, missing validation, blocking issues)
- If auto-fix succeeds: Documents as deviation, continues
- Tracks auto-fix attempts: After 3 attempts on single task, pauses to avoid infinite loop

**Layer 2: Architectural Decisions (Rule 4)**
- Executor encounters error requiring significant structural change
- Returns checkpoint with proposed change, impact, alternatives
- Orchestrator/user decides; executor resumes per decision

**Layer 3: Checkpoint Handling**
- Executor hits checkpoint in plan or authentication gate
- Returns structured checkpoint_return_format with completed tasks, current blocker, awaiting field
- In auto-mode: Auto-approves human-verify and decision checkpoints; pauses on human-action
- In standard mode: Always pauses for user decision

**Layer 4: Verification**
- After phase completes: `gsd-verifier` agent validates results
- Checks: Files exist per SUMMARY.md, commits made, SUMMARY.md well-formed
- If verification fails: `/gsd:debug` workflow spawns `gsd-debugger` agent
- Debugger: Diagnoses failures, proposes fixes, recommends next steps

**Layer 5: Orchestrator Oversight**
- Workflows validate agent outputs before proceeding
- Checks: SUMMARY.md created, STATE.md updated, git commits made
- If validation fails: Error reported to user with next steps
- Workflow can offer to recover (reconstruct STATE.md, retry, skip)

## Cross-Cutting Concerns

**Logging:**
- Pattern: Agents log via markdown output + console.log from gsd-tools
- Checkpoints return structured markdown with progress tables
- STATE.md accumulates session history + decisions
- SUMMARY.md documents what was built, deviations, decisions per plan

**Validation:**
- Pattern: gsd-tools provides validation commands (verify-summary, verify-commits, validate health)
- Phase structure: Phase directories must have .planning/phases/XX-name/ pattern
- Roadmap sync: gsd-tools checks disk state vs ROADMAP.md; auto-repair available
- Frontmatter: Plans/summaries must have valid frontmatter per schema (phase, plan, type, etc.)
- State consistency: STATE.md must match disk state (completed phases, plan counts)

**Authentication:**
- Pattern: Auth errors recognized as gates, not failures
- Indicators: "Not authenticated", "401", "403", "Please run {tool} login", "Set {ENV_VAR}"
- Executor response: Pauses with `checkpoint:human-action` type
- Documents: Auth gates logged in SUMMARY.md as normal flow, not deviations

**Model Optimization:**
- Pattern: gsd-tools resolves agent model based on profile + task complexity
- MODEL_PROFILES in gsd-tools.cjs: Each agent has quality/balanced/budget tiers
- Selection: `resolve-model <agent-type>` returns opus/sonnet/haiku per user profile
- Cost control: Budget mode uses haiku for research/mapping; standard uses sonnet; quality uses opus
- Workflows: High-stakes agents (planner, executor) get better models; research gets cheaper models

**Git Integration:**
- Pattern: Executor commits per-task with structured messages: `feat(phase-plan): [description]`
- Atomic: Each task = one commit (enables rollback, bisect, clear history)
- Planning commits: gsd-tools handles planning file commits (STATE.md, SUMMARY.md)
- Branching: Workflow can checkout feature branch per phase (config-driven)
- References: git-planning-commit.md documents commit conventions

---

*Architecture analysis: 2026-02-28*
