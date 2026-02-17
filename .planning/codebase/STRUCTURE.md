# Codebase Structure

**Analysis Date:** 2026-02-17

## Directory Layout

```
get-shit-done/
├── bin/                         # Installation & entry point
│   └── install.js               # Interactive/non-interactive installer for all runtimes
├── commands/                    # Public command API
│   └── gsd/                     # 20+ markdown command files (new-project, plan-phase, execute-phase, etc.)
├── get-shit-done/               # Core GSD system
│   ├── bin/
│   │   ├── gsd-tools.cjs        # Central CLI tool (state, phase, roadmap, git operations)
│   │   └── gsd-tools.test.cjs   # Node test suite for gsd-tools
│   ├── workflows/               # 30+ orchestration workflows
│   │   ├── new-project.md       # Initialize project (questioning → research → requirements → roadmap)
│   │   ├── plan-phase.md        # Create executable plans for a phase
│   │   ├── execute-phase.md     # Execute all plans in a phase (wave-parallel)
│   │   ├── map-codebase.md      # Spawn parallel mapper agents for codebase analysis
│   │   ├── execute-plan.md      # Single-plan executor entry point
│   │   ├── verify-work.md       # Verify phase execution (tests, must-haves)
│   │   └── [25+ more workflows] # plan-milestone-gaps, complete-milestone, research-phase, etc.
│   ├── templates/               # 30+ markdown templates
│   │   ├── project.md           # PROJECT.md template (what, core value, requirements, constraints, decisions)
│   │   ├── requirements.md      # REQUIREMENTS.md template (v1/v2 reqs, out of scope, traceability)
│   │   ├── roadmap.md           # ROADMAP.md template (phases, goals, success criteria, plans)
│   │   ├── state.md             # STATE.md template (position, metrics, blockers, accumulated context)
│   │   ├── milestone.md         # Milestone entry template (version, deliverables, stats, git range)
│   │   ├── phase-prompt.md      # PLAN.md template (objective, frontmatter, tasks, verification)
│   │   ├── summary.md           # SUMMARY.md template (frontmatter, subsystem, key files, patterns, metrics)
│   │   ├── context.md           # CONTEXT.md template (user design decisions, locked/deferred/discretion)
│   │   ├── discovery.md         # DISCOVERY.md template (phase discovery notes)
│   │   ├── research.md          # RESEARCH.md template (domain findings, patterns, libraries, risks)
│   │   ├── verification-report.md  # VERIFICATION.md template (test results, must-haves check)
│   │   ├── uat.md               # UAT.md template (user acceptance test checklist)
│   │   ├── codebase/            # Codebase analysis templates (7 files)
│   │   │   ├── stack.md         # STACK.md template (languages, runtimes, frameworks)
│   │   │   ├── integrations.md  # INTEGRATIONS.md template (APIs, databases, auth, monitoring)
│   │   │   ├── architecture.md  # ARCHITECTURE.md template (pattern, layers, data flow)
│   │   │   ├── structure.md     # STRUCTURE.md template (directory layout, key locations)
│   │   │   ├── conventions.md   # CONVENTIONS.md template (naming, style, imports, comments)
│   │   │   ├── testing.md       # TESTING.md template (framework, structure, patterns)
│   │   │   └── concerns.md      # CONCERNS.md template (tech debt, bugs, performance, security)
│   │   ├── research-project/    # Research phase templates (FEATURES, STACK, ARCHITECTURE, etc.)
│   │   ├── summary-*.md         # Summary variants (standard, minimal, complex)
│   │   ├── continue-here.md     # Session resumption template
│   │   ├── config.json          # Sample config.json for new projects
│   │   ├── planner-subagent-prompt.md  # Extended planner context template
│   │   └── debug-subagent-prompt.md    # Extended debugger context template
│   ├── references/              # 13 protocol/pattern reference files
│   │   ├── checkpoints.md       # Checkpoint task patterns (decision, human-verify, system-verify)
│   │   ├── verification-patterns.md  # Testing patterns (unit, integration, E2E)
│   │   ├── tdd.md               # TDD execution protocol for plan tasks
│   │   ├── git-integration.md   # Git workflow patterns (commits, branches, ranges)
│   │   ├── model-profiles.md    # Model selection guidance (quality/balanced/budget)
│   │   ├── model-profile-resolution.md  # How to resolve model profiles to Claude models
│   │   ├── planning-config.md   # .planning/config.json schema and options
│   │   ├── ui-brand.md          # UI consistency guidelines (colors, spacing, language tone)
│   │   ├── questioning.md       # Project discovery questioning protocol
│   │   ├── continuation-format.md  # Session continuation (.continue-here.md format)
│   │   ├── phase-argument-parsing.md  # How to parse phase arguments (1, 2.1, 02.1, etc.)
│   │   ├── decimal-phase-calculation.md  # Phase renumbering logic (inserting decimal phases)
│   │   └── git-planning-commit.md  # Planning commit message conventions
├── agents/                      # 11 specialized agent implementations
│   ├── gsd-planner.md           # Plan creator (decompose phase into parallel tasks)
│   ├── gsd-executor.md          # Plan executor (execute tasks, handle deviations, commit)
│   ├── gsd-verifier.md          # Verification agent (test, check must-haves)
│   ├── gsd-debugger.md          # Debug agent (investigate failures, find root cause)
│   ├── gsd-phase-researcher.md  # Phase-focused research (library selection, patterns)
│   ├── gsd-project-researcher.md  # Project discovery research (domain, user needs)
│   ├── gsd-research-synthesizer.md  # Combine research into coherent narrative
│   ├── gsd-roadmapper.md        # Create roadmap structure from requirements
│   ├── gsd-plan-checker.md      # Verify plan quality (dependencies, coverage, task structure)
│   ├── gsd-integration-checker.md  # Check external API integration patterns
│   └── gsd-codebase-mapper.md   # Analyze codebase, write ARCHITECTURE/STACK/etc. docs
├── scripts/                     # Build & utility scripts
│   └── build-hooks.js           # Build hooks installation script
├── hooks/                       # Git hook scripts (pre-commit, post-commit, etc.)
│   └── dist/                    # Compiled/built hook files
├── docs/                        # User documentation
│   └── USER-GUIDE.md            # How to use GSD (workflows, commands, best practices)
├── assets/                      # Static assets
│   └── terminal.svg             # Terminal screenshot asset
├── .planning/                   # Project planning directory (created during init)
│   ├── codebase/                # Codebase analysis documents (generated by map-codebase)
│   │   ├── STACK.md             # Tech stack analysis
│   │   ├── INTEGRATIONS.md      # External integrations
│   │   ├── ARCHITECTURE.md      # Architecture patterns
│   │   ├── STRUCTURE.md         # Directory structure guide
│   │   ├── CONVENTIONS.md       # Coding conventions
│   │   ├── TESTING.md           # Testing patterns
│   │   └── CONCERNS.md          # Technical debt & issues
│   ├── config.json              # Workflow configuration (model profile, git strategy, research enabled)
│   ├── PROJECT.md               # Project context (what, core value, requirements, constraints, decisions)
│   ├── REQUIREMENTS.md          # Requirements with traceability
│   ├── ROADMAP.md               # Phase structure with goals and plans
│   ├── STATE.md                 # Current position, metrics, blockers
│   ├── MILESTONES.md            # Completed milestone summaries (created on completion)
│   ├── phases/                  # Per-phase directories
│   │   ├── 01-phase-name/       # Phase 1 directory (padded decimal naming)
│   │   │   ├── 01-CONTEXT.md    # User design decisions for phase (from discuss-phase)
│   │   │   ├── 01-01-PLAN.md    # Plan 1 (task breakdown, verification)
│   │   │   ├── 01-01-SUMMARY.md # Plan 1 execution summary (commits, artifacts, patterns)
│   │   │   ├── 01-02-PLAN.md    # Plan 2
│   │   │   ├── 01-02-SUMMARY.md
│   │   │   ├── 01-RESEARCH.md   # Phase research (if research enabled)
│   │   │   ├── deferred-items.md  # Out-of-scope issues discovered during execution
│   │   │   └── [other plans]
│   │   ├── 02-phase-name/       # Phase 2
│   │   ├── 02.1-phase-name/     # Decimal phase (inserted mid-project)
│   │   └── [remaining phases]
│   ├── todos/                   # Idea backlog
│   │   ├── pending/             # Ideas not yet acted on
│   │   │   └── {idea-slug}.md
│   │   └── completed/           # Ideas that became phases or are dismissed
│   │       └── {idea-slug}.md
│   ├── milestones/              # Archived phase directories (on milestone completion)
│   │   └── v1.0-phases/         # vX.Y-phases/ directories with archived phase folders
│   └── research/                # Domain research files (if research enabled)
│       ├── FEATURES.md          # User-facing features
│       ├── STACK.md             # Tech recommendations
│       ├── ARCHITECTURE.md      # Architecture patterns
│       ├── PITFALLS.md          # Known issues
│       └── [other research]
├── .github/                     # GitHub configuration
│   ├── workflows/               # GitHub Actions workflows
│   └── ISSUE_TEMPLATE/          # Issue templates
├── package.json                 # Node.js package metadata
├── package-lock.json            # npm lock file
├── README.md                    # Project documentation
├── CHANGELOG.md                 # Version history
├── LICENSE                      # MIT license
└── .gitignore                   # Git ignore patterns
```

## Directory Purposes

**bin/**
- Purpose: Entry point for global/local installation
- Contains: install.js (main installer)
- Generated: Nothing (all pre-existing)

**commands/gsd/**
- Purpose: Public command specifications (like API surface)
- Contains: 20+ markdown files defining commands visible to users
- Key files: `new-project.md`, `plan-phase.md`, `execute-phase.md`, `verify-work.md`, `map-codebase.md`
- Pattern: Each file has YAML frontmatter (name, description, tools, argument-hint) + execution_context + process sections

**get-shit-done/workflows/**
- Purpose: Implementation of commands; orchestrate subagents and operations
- Contains: Step-by-step workflows with bash calls, decision logic, subagent spawning
- Execution: Referenced by commands via @-references, followed end-to-end during command execution
- State: Workflows read/write project state (STATE.md, ROADMAP.md, etc.)

**get-shit-done/templates/**
- Purpose: Scaffolding for standard markdown documents
- Contains: 30+ markdown templates with examples and guidelines
- Key templates: PROJECT.md, REQUIREMENTS.md, ROADMAP.md, STATE.md, PLAN.md, SUMMARY.md
- Codebase templates: 7 analysis templates (STACK.md, ARCHITECTURE.md, etc.) for codebase mapping
- Usage: Workflows fill templates during creation; agents reference templates for structure

**get-shit-done/references/**
- Purpose: Protocols, patterns, and decision tables shared across system
- Contains: 13 files covering checkpoints, git patterns, model profiles, TDD protocol, UI brand
- Usage: Referenced by workflows and agents via @-references; consulted during planning/execution

**agents/**
- Purpose: Specialized Claude instances for focused work
- Contains: 11 markdown agent definitions with role, execution flow, validation rules
- Agents: Planner (plan creation), Executor (plan execution), Verifier (testing), Debugger (failure analysis), Researchers (domain discovery), Roadmapper (phase structure), Checkers (quality), Mapper (codebase analysis)
- Spawning: Via Task tool from workflows; each agent runs with fresh 200k context

**.planning/** (Project Directory)
- Purpose: Persistent project state across sessions
- Initialization: Created by `/gsd:new-project`
- Structure: Mirrors phases in subdirectories; documents track decisions, execution, metrics
- Commitment: All changes committed to git (unless commit_docs: false in config)

**.planning/codebase/**
- Purpose: Structured analysis of existing codebase
- Created by: `/gsd:map-codebase` workflow spawning gsd-codebase-mapper agent
- Contains: 7 documents (STACK.md, INTEGRATIONS.md, ARCHITECTURE.md, STRUCTURE.md, CONVENTIONS.md, TESTING.md, CONCERNS.md)
- Usage: Referenced during planning (`/gsd:plan-phase`) to understand existing code patterns and tech choices

**.planning/phases/{N}-{name}/**
- Purpose: Organize all work for a single phase
- Naming: Padded decimal (01-project-setup, 02.1-critical-fix, 03-ui-implementation)
- Contents: PLAN.md files, SUMMARY.md files, optional CONTEXT.md, RESEARCH.md, deferred-items.md
- Lifecycle: Created during roadmap generation; populated during planning; completed after execution

**.planning/config.json**
- Purpose: Workflow preferences (centralized configuration)
- Usage: Loaded by workflows via gsd-tools; affects subagent model selection, git strategy, research behavior
- Schema: Defines model_profile (quality/balanced/budget), commit_docs (bool), branching_strategy (none/phase/milestone), research (bool), verifier (bool), etc.

**scripts/**
- Purpose: Build and utility operations
- Contents: build-hooks.js (compiles git hooks during npm publish)
- Execution: Triggered by npm scripts (prepublishOnly, build:hooks)

## Key File Locations

**Entry Points:**
- `/bin/install.js` — Installation script (called via `npx get-shit-done-cc@latest`)
- `/commands/gsd/*.md` — Command definitions (exposed as `/gsd:{command}` in Claude Code)

**Configuration:**
- `.planning/config.json` — Project workflow preferences (model profile, branching, research)
- `package.json` — npm package metadata, dependencies (currently none), version

**Core Logic:**
- `/get-shit-done/bin/gsd-tools.cjs` — Central CLI for state/phase/config operations (120+ commands)
- `/get-shit-done/workflows/*.md` — Implementation of user commands

**Subagents:**
- `/agents/gsd-*.md` — Agent implementations (planner, executor, verifier, debugger, researchers, roadmapper, checkers, mapper)

**Testing:**
- `/get-shit-done/bin/gsd-tools.test.cjs` — Node test suite for gsd-tools CLI

## Naming Conventions

**Files:**

- **Command files** (`commands/gsd/`): kebab-case matching command name (new-project.md, plan-phase.md)
- **Workflow files** (`workflows/`): kebab-case matching workflow purpose (new-project.md, execute-phase.md)
- **Agent files** (`agents/`): gsd-kebab-case (gsd-planner.md, gsd-executor.md)
- **Template files** (`templates/`): kebab-case for document type (project.md, requirements.md, phase-prompt.md)
- **Phase directories** (`.planning/phases/`): NN-kebab-case (01-authentication, 02-api-foundation, 02.1-security-fix)
- **Plan files** (`.planning/phases/NN-name/`): NN-MM-TYPE.md format (01-01-PLAN.md, 01-01-SUMMARY.md, 01-CONTEXT.md, 01-RESEARCH.md)

**Directories:**

- **Functional directories**: lowercase, hyphenated (commands, workflows, agents, templates, references, get-shit-done)
- **Project directories**: pattern-based (phases/{NN}-{slug}, todos/pending, milestones/v{X.Y}-phases)

**Code/Script names:**

- **CLI tools**: kebab-case (gsd-tools.cjs, build-hooks.js)
- **Variables**: camelCase (INIT_RAW, PLAN_INDEX, planStartTime)

## Where to Add New Code

**New Command:**
- Create: `/commands/gsd/{command-name}.md`
- Template: Use existing command as example (e.g., `plan-phase.md`)
- Structure: YAML frontmatter (name, description, tools, argument-hint) + execution_context + process sections
- Depends on: Reference a workflow in execution_context

**New Workflow:**
- Create: `/get-shit-done/workflows/{workflow-name}.md`
- Template: Use `new-project.md` or `execute-phase.md` as reference
- Pattern: Step-by-step procedures with bash calls to gsd-tools, subagent spawning, decision gates
- Responsibility: Orchestrate work, keep context lean, call gsd-tools for state operations

**New Subagent:**
- Create: `/agents/gsd-{agent-name}.md`
- Template: Use `gsd-executor.md` or `gsd-planner.md` as reference
- Pattern: Role definition, execution flow (steps), validation rules, decision trees
- Spawning: Called via Task tool from workflow with `subagent_type="gsd-{agent-name}"`
- Output: Write documents directly (no context transfer back); return confirmation

**New Template:**
- Create: `/get-shit-done/templates/{document-type}.md`
- Purpose: Scaffolding for standard documents created during workflows
- Includes: File template (markdown structure), guidelines, evolution/lifecycle notes, examples
- Usage: Workflows reference templates when creating project documents

**New Reference:**
- Create: `/get-shit-done/references/{pattern-name}.md`
- Purpose: Shared protocols, patterns, decision tables
- Usage: Referenced by workflows and agents via @-references

**New gsd-tools Command:**
- Location: `/get-shit-done/bin/gsd-tools.cjs`
- Pattern: Add command case to main switch statement, implement function, update usage comment
- Category: Group with related commands (state, phase, roadmap, validation, etc.)
- Test: Add test case to `/get-shit-done/bin/gsd-tools.test.cjs`

## Special Directories

**`.planning/` directory:**
- Purpose: Project state and metadata
- Generated: By workflows (never manually created)
- Committed: Yes (all .planning/ tracked in git by default)
- Cleanup: No cleanup — persists across sessions and phases
- Note: If user sets `commit_docs: false`, planning docs not committed but still created on disk

**`.planning/codebase/` directory:**
- Purpose: Structured codebase analysis (STACK.md, INTEGRATIONS.md, ARCHITECTURE.md, STRUCTURE.md, CONVENTIONS.md, TESTING.md, CONCERNS.md)
- Generated: By `/gsd:map-codebase` workflow
- Committed: Yes (standard behavior)
- Refresh: User can re-run map-codebase to update (deletes and recreates directory)
- Usage: Referenced by plan-phase workflow to understand existing code

**`hooks/` and `hooks/dist/` directories:**
- Purpose: Git hook scripts for workflow automation
- Generated: By build-hooks.js during npm publish
- Committed: `hooks/dist/` is committed (compiled output); source hooks compiled to dist
- Installation: Copied to `.git/hooks/` by installer

**`.github/` directory:**
- Purpose: GitHub configuration (workflows, issue templates)
- Generated: Committed to repo (not dynamically generated)
- Usage: GitHub Actions CI/CD, issue tracking

**`docs/` directory:**
- Purpose: User-facing documentation (USER-GUIDE.md, etc.)
- Generated: Committed to repo (manually maintained)
- Usage: Online documentation, installation guides

---

*Structure analysis: 2026-02-17*
