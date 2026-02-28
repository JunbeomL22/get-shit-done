# Codebase Structure

**Analysis Date:** 2026-02-28

## Directory Layout

```
get-shit-done/
├── bin/                              # NPM package entry point
│   └── install.js                    # Global/local installer (Claude Code, OpenCode, Gemini)
├── commands/                         # User-facing slash commands (auto-registered)
│   └── gsd/
│       ├── new-project.md           # /gsd:new-project — initialize project
│       ├── plan-phase.md            # /gsd:plan-phase — generate PLAN.md
│       ├── execute-phase.md         # /gsd:execute-phase — execute plans
│       ├── verify-work.md           # /gsd:verify-work — validate execution
│       ├── map-codebase.md          # /gsd:map-codebase — analyze codebase
│       ├── yolo.md                  # /gsd:yolo — run all remaining phases
│       ├── research-phase.md        # /gsd:research-phase — deep research
│       ├── debug.md                 # /gsd:debug — diagnose failures
│       ├── discuss-phase.md         # /gsd:discuss-phase — explore phase details
│       ├── add-phase.md             # /gsd:add-phase — insert new phase
│       ├── remove-phase.md          # /gsd:remove-phase — delete phase
│       ├── plan-milestone-gaps.md   # /gsd:plan-milestone-gaps — plan gap closure
│       ├── new-milestone.md         # /gsd:new-milestone — start new milestone
│       ├── complete-milestone.md    # /gsd:complete-milestone — archive milestone
│       ├── audit-milestone.md       # /gsd:audit-milestone — review milestone
│       ├── resume-work.md           # /gsd:resume-work — resume after break
│       ├── pause-work.md            # /gsd:pause-work — pause work session
│       ├── progress.md              # /gsd:progress — show current state
│       ├── health.md                # /gsd:health — check project health
│       ├── help.md                  # /gsd:help — show help
│       ├── quick.md                 # /gsd:quick — fast execution loop
│       ├── settings.md              # /gsd:settings — user preferences
│       ├── list-phase-assumptions.md # /gsd:list-phase-assumptions
│       ├── check-todos.md           # /gsd:check-todos — view pending todos
│       ├── add-todo.md              # /gsd:add-todo — add todo item
│       ├── insert-phase.md          # /gsd:insert-phase — insert phase after N
│       ├── cleanup.md               # /gsd:cleanup — clean build artifacts
│       ├── reapply-patches.md       # /gsd:reapply-patches — apply saved patches
│       ├── update.md                # /gsd:update — update GSD version
│       ├── set-profile.md           # /gsd:set-profile — set execution profile
│       ├── join-discord.md          # /gsd:join-discord — join community
│       └── [30+ more commands]
│
├── agents/                          # Specialized Claude agents
│   ├── gsd-executor.md             # Executes PLAN.md → creates SUMMARY.md
│   ├── gsd-planner.md              # Creates PLAN.md from context
│   ├── gsd-debugger.md             # Diagnoses and fixes failures
│   ├── gsd-codebase-mapper.md      # Analyzes codebase → writes STACK.md, ARCHITECTURE.md
│   ├── gsd-roadmapper.md           # Designs project roadmap
│   ├── gsd-phase-researcher.md     # Deep research on phase unknowns
│   ├── gsd-project-researcher.md   # Project discovery research
│   ├── gsd-research-synthesizer.md # Synthesizes research into requirements
│   ├── gsd-verifier.md             # Validates execution results
│   ├── gsd-plan-checker.md         # Validates PLAN.md quality
│   └── gsd-integration-checker.md  # Checks integration feasibility
│
├── get-shit-done/                   # NPM package contents (what gets installed)
│   ├── bin/
│   │   ├── gsd-tools.cjs           # CLI utility for state, config, git operations
│   │   └── gsd-tools.test.cjs      # Tests for gsd-tools
│   ├── workflows/                  # Orchestrator processes
│   │   ├── new-project.md          # Project initialization (questions → research → roadmap)
│   │   ├── execute-phase.md        # Phase execution orchestrator (wave-based)
│   │   ├── plan-phase.md           # Planning orchestrator
│   │   ├── map-codebase.md         # Codebase mapping orchestrator (4 parallel agents)
│   │   ├── research-phase.md       # Research orchestrator
│   │   ├── verify-phase.md         # Verification orchestrator
│   │   ├── discuss-phase.md        # Discussion/discovery orchestrator
│   │   ├── yolo.md                 # Auto-chain phases workflow
│   │   ├── diagnose-issues.md      # Failure diagnosis workflow
│   │   ├── complete-milestone.md   # Milestone completion workflow
│   │   ├── pause-work.md           # Work pause workflow
│   │   ├── resume-project.md       # Work resume workflow
│   │   ├── add-phase.md            # Phase insertion workflow
│   │   ├── plan-milestone-gaps.md  # Gap closure planning
│   │   ├── help.md                 # Help display workflow
│   │   ├── update.md               # Update workflow
│   │   ├── transition.md           # Phase-to-phase transition
│   │   ├── add-todo.md             # Todo management
│   │   ├── health.md               # Health check workflow
│   │   ├── discovery-phase.md      # Initial discovery
│   │   └── execute-plan.md         # Legacy: single plan execution
│   │
│   ├── templates/                  # Document templates for project
│   │   ├── project.md              # PROJECT.md template
│   │   ├── roadmap.md              # ROADMAP.md template
│   │   ├── requirements.md         # REQUIREMENTS.md template
│   │   ├── phase-prompt.md         # Phase-specific context template
│   │   ├── plan.md                 # PLAN.md template (planning, structure)
│   │   ├── summary.md              # SUMMARY.md template (main, complex, minimal, standard variants)
│   │   ├── summary-minimal.md      # SUMMARY.md for small tasks
│   │   ├── summary-standard.md     # SUMMARY.md default
│   │   ├── summary-complex.md      # SUMMARY.md for large plans
│   │   ├── verification-report.md  # VERIFICATION.md template
│   │   ├── UAT.md                  # User Acceptance Test template
│   │   ├── context.md              # CONTEXT.md template (user vision)
│   │   ├── discovery.md            # DISCOVERY.md template (research findings)
│   │   ├── research.md             # RESEARCH.md template (research output)
│   │   ├── state.md                # STATE.md template
│   │   ├── config.json             # config.json template
│   │   ├── milestone.md            # MILESTONE.md template
│   │   ├── milestone-archive.md    # Milestone archival template
│   │   ├── user-setup.md           # User setup instructions
│   │   ├── continue-here.md        # Continuation prompt
│   │   ├── debug-subagent-prompt.md # Debug-specific context
│   │   ├── planner-subagent-prompt.md # Planning-specific context
│   │   ├── codebase/               # Codebase analysis templates
│   │   │   ├── stack.md            # STACK.md template (tech stack)
│   │   │   ├── integrations.md     # INTEGRATIONS.md template
│   │   │   ├── architecture.md     # ARCHITECTURE.md template
│   │   │   ├── structure.md        # STRUCTURE.md template
│   │   │   ├── conventions.md      # CONVENTIONS.md template
│   │   │   ├── testing.md          # TESTING.md template
│   │   │   └── concerns.md         # CONCERNS.md template
│   │   └── research-project/       # Research-specific templates
│   │       ├── STACK.md
│   │       ├── FEATURES.md
│   │       └── PITFALLS.md
│   │
│   ├── references/                 # Shared reference documents for agents
│   │   ├── checkpoints.md          # Checkpoint protocol deep dive
│   │   ├── git-integration.md      # Git conventions and patterns
│   │   ├── git-planning-commit.md  # Planning commit conventions
│   │   ├── model-profiles.md       # Model selection guidance
│   │   ├── model-profile-resolution.md # How model profiles are resolved
│   │   ├── verification-patterns.md # How to verify execution results
│   │   ├── tdd.md                  # Test-driven development patterns
│   │   ├── questioning.md          # User questioning strategies
│   │   ├── planning-config.md      # Configuration system docs
│   │   ├── phase-argument-parsing.md # Phase number parsing
│   │   ├── continuation-format.md  # Continuation message format
│   │   ├── decimal-phase-calculation.md # Phase numbering logic
│   │   └── ui-brand.md             # UI/messaging standards
│   │
│   └── bin/
│       └── [installed copy of gsd-tools.cjs]
│
├── hooks/                           # Runtime hooks (built to dist/)
│   ├── gsd-statusline.js           # Terminal statusline renderer
│   ├── gsd-check-update.js         # Update checker
│   └── dist/                       # Built hooks (generated by build:hooks)
│
├── scripts/                         # Build and utility scripts
│   └── build-hooks.js              # Build hooks from source
│
├── docs/                           # User documentation
│   └── USER-GUIDE.md               # User guide and feature overview
│
├── assets/                         # Marketing/demo assets
│   └── terminal.svg                # Terminal demo SVG
│
├── .planning/                      # Project planning (GSD's own project)
│   ├── PROJECT.md                  # GSD's project spec
│   ├── REQUIREMENTS.md             # GSD's requirements
│   ├── ROADMAP.md                  # GSD's roadmap
│   ├── STATE.md                    # GSD's project state
│   ├── config.json                 # GSD's config
│   ├── phases/                     # GSD's phases
│   │   ├── 01-state-infrastructure/
│   │   ├── 02-launcher/
│   │   ├── 03-integration-and-failure-hardening/
│   │   ├── 04-resume-and-visibility/
│   │   └── 05-fix-stopped-phase-detection/
│   ├── codebase/                   # GSD's own codebase map (if ran map-codebase)
│   ├── research/                   # GSD's research findings
│   └── v1-MILESTONE-AUDIT.md      # v1 milestone retrospective
│
├── package.json                    # NPM package definition
├── package-lock.json               # Locked dependencies
├── CHANGELOG.md                    # Release notes
├── README.md                       # Main documentation
├── LICENSE                         # MIT license
├── SECURITY.md                     # Security policy
├── .gitignore                      # Git ignore rules
├── INSTALL-LOCAL.md               # Local installation guide
├── yolo-install.sh                # One-command installer (shell)
└── yolo-install.ps1               # One-command installer (PowerShell)
```

## Directory Purposes

**bin/:**
- Purpose: NPM package entry point
- Contains: `install.js` which orchestrates global/local GSD installation
- Behavior: When user runs `npx get-shit-done-cc`, this file executes
- Creates: Runtime-specific directories (~/.claude/, ~/.opencode/, ~/.gemini/) with symlinks/copies of get-shit-done/ contents

**commands/gsd/:**
- Purpose: User command definitions (30+ files)
- Contains: Markdown files with `<objective>`, `<execution_context>` pointing to workflows
- Pattern: Each file auto-registers as `/gsd:filename` in Claude Code
- Naming: kebab-case, e.g., `new-project.md` → `/gsd:new-project`
- Key files: `new-project.md`, `plan-phase.md`, `execute-phase.md`, `verify-work.md`, `map-codebase.md`, `yolo.md`

**agents/:**
- Purpose: Specialized agent definitions
- Contains: Markdown agent specs with `<role>`, execution rules, output protocols
- Pattern: Each agent file loaded by workflows via Task() primitives
- Key agents: executor (plans), planner (creates plans), codebase-mapper (analyzes code), debugger (fixes issues)
- Spawning: Workflows use agent name directly; gsd-tools resolves model based on profile

**get-shit-done/bin/:**
- Purpose: Core CLI utilities (installed to ~/.claude/get-shit-done/bin/)
- Key file: `gsd-tools.cjs` (187KB, centralizes ~100 repeated patterns across 50+ files)
- Functions: state management, config parsing, phase lookups, git commits, summary verification
- Used by: Every agent + workflow via `node ~/.claude/get-shit-done/bin/gsd-tools.cjs <command>`
- Test file: `gsd-tools.test.cjs` (87KB)

**get-shit-done/workflows/:**
- Purpose: Orchestrators for complex workflows
- Contains: Markdown orchestrators with `<process>` steps, agent spawning, checkpoint handling
- Key workflows:
  - `new-project.md`: Initialize project (discovery → research → roadmap)
  - `execute-phase.md`: Run phase plans (wave-based, parallel capable)
  - `plan-phase.md`: Generate PLAN.md from roadmap
  - `map-codebase.md`: Spawn 4 parallel mapper agents
  - `research-phase.md`: Research and synthesize findings
  - `verify-phase.md`: Validate execution quality
- Pattern: Orchestrator reads context, spawns agents via Task(), waits for results, validates output

**get-shit-done/templates/:**
- Purpose: Document templates for user projects
- Contains: Markdown files with frontmatter + variable placeholders
- Sub-directories:
  - Root: `project.md`, `roadmap.md`, `requirements.md`, `plan.md`, `summary.md`, `state.md`, etc.
  - `codebase/`: Templates for codebase analysis (STACK.md, ARCHITECTURE.md, etc.)
  - `research-project/`: Special templates for research phases
- Usage: Workflows use gsd-tools `template fill` to pre-populate PLAN.md, SUMMARY.md, etc.

**get-shit-done/references/:**
- Purpose: Shared knowledge base for agents
- Contains: Detailed guides on specific patterns (checkpoints, git, verification, TDD, etc.)
- Key files:
  - `checkpoints.md`: Checkpoint protocol (when to use, how to handle)
  - `git-integration.md`: Git workflow (branching, committing, pushing)
  - `verification-patterns.md`: How to verify execution
  - `tdd.md`: Test-driven development patterns
  - `model-profiles.md`: Model selection guidance
  - `planning-config.md`: Configuration system
- Usage: Agents load via `@~/.claude/get-shit-done/references/filename.md` in context

**hooks/:**
- Purpose: Runtime hooks for terminal integration
- Contains: JavaScript files for statusline rendering, update checking
- Built to: `dist/` by `npm run build:hooks` (esbuild bundled)
- Installed: Copied to runtime config directory for local use
- Not critical: Optional enhancements to UX

**scripts/:**
- Purpose: Build and utility scripts
- Contains: `build-hooks.js` (esbuild bundler for hooks)
- Run: `npm run build:hooks` before package publish

**.planning/:**
- Purpose: GSD's own project planning (GSD uses GSD to build GSD)
- Contains: PROJECT.md, ROADMAP.md, STATE.md, config.json, and 5 completed phases
- Key files:
  - `STATE.md`: GSD's current phase (Phase 5 complete as of 2026-02-28)
  - `ROADMAP.md`: GSD's 5-phase roadmap
  - `phases/`: Each phase has multiple PLAN.md + SUMMARY.md files
  - `codebase/`: GSD's own codebase analysis (if map-codebase was run)
- Demonstrates: GSD's system working on itself; real example of state, decisions, execution

## Key File Locations

**Entry Points:**
- `bin/install.js`: Global/local installer (runs on `npx get-shit-done-cc`)
- `commands/gsd/new-project.md`: Project initialization entry (runs on `/gsd:new-project`)
- `get-shit-done/bin/gsd-tools.cjs`: CLI utility entry (called by agents/workflows)

**Configuration:**
- `package.json`: NPM package definition, versions, dependencies
- `get-shit-done/templates/config.json`: Default config template
- `.planning/config.json`: GSD's own configuration

**Core Logic:**
- `agents/*.md`: Agent role definitions and execution rules (11 agents)
- `get-shit-done/workflows/*.md`: Orchestrator logic (20+ workflows)
- `commands/gsd/*.md`: User command entry points (30+ commands)
- `get-shit-done/bin/gsd-tools.cjs`: Centralized utilities (state, config, git, phases)

**Testing:**
- `get-shit-done/bin/gsd-tools.test.cjs`: Tests for gsd-tools CLI
- Run: `npm test`

**Documentation:**
- `README.md`: Main documentation, feature overview
- `docs/USER-GUIDE.md`: User guide
- `get-shit-done/references/*.md`: Agent reference guides
- `.planning/PROJECT.md`: GSD's project spec
- `CHANGELOG.md`: Release notes
- `SECURITY.md`: Security policy

## Naming Conventions

**Files:**
- Commands: `kebab-case.md` (e.g., `new-project.md`, `execute-phase.md`) → auto-registers as `/gsd:kebab-case`
- Agents: `gsd-agent-name.md` (e.g., `gsd-executor.md`, `gsd-planner.md`)
- Workflows: `kebab-case.md` (e.g., `new-project.md`, `execute-phase.md`)
- Planning docs: UPPERCASE.md (e.g., `PROJECT.md`, `ROADMAP.md`, `PLAN.md`, `SUMMARY.md`)
- Codebase analysis: UPPERCASE.md (e.g., `STACK.md`, `ARCHITECTURE.md`, `STRUCTURE.md`)
- Config: `config.json` (in `.planning/` and `get-shit-done/templates/`)
- Tests: `filename.test.cjs` or `filename.spec.cjs`

**Directories:**
- Commands: `/commands/gsd/` (flat, single level)
- Agents: `/agents/` (flat, single level)
- Workflows: `/get-shit-done/workflows/` (flat, single level)
- Templates: `/get-shit-done/templates/` (flat root + `codebase/`, `research-project/` subdirs)
- References: `/get-shit-done/references/` (flat, single level)
- Project planning: `.planning/phases/XX-phase-name/` (decimal phase numbering)
- Codebase maps: `.planning/codebase/` (7 files: STACK.md, ARCHITECTURE.md, STRUCTURE.md, CONVENTIONS.md, TESTING.md, INTEGRATIONS.md, CONCERNS.md)

**Phases:**
- Format: `{decimal}-{slug}` where decimal is phase number (1, 1.1, 2, etc.)
- Examples: `01-state-infrastructure`, `02-launcher`, `03-integration-and-failure-hardening`
- Directory structure: `.planning/phases/01-state-infrastructure/` contains `01-01-PLAN.md`, `01-01-SUMMARY.md`, etc.

**Plans:**
- Format: `{phase}-{plan}-{slug}.md`
- Frontmatter: `phase:`, `plan:`, `type:`, `autonomous:`, `wave:`, `depends_on:`
- Examples: `01-01-setup-state-persistence.md`, `03-02-install-yolo-command.md`

**Commits:**
- Format: `{type}({scope}): {description}` where scope is phase-plan
- Examples:
  - `feat(01-01): add state persistence layer`
  - `fix(03-02): handle phase gap detection`
  - `docs(init): project initialized`
  - `test(05-01): add STOPPED_PHASE detection tests`

## Where to Add New Code

**New Feature (entirely new capability):**
- Primary code: Create PLAN.md in `.planning/phases/XX-phase-name/` with phase/plan/type/task structure
- Execution: `/gsd:execute-phase XX` runs plan with atomic commits
- Tests: Write tests per TESTING.md patterns from codebase analysis
- Documentation: Update .planning/PROJECT.md, ROADMAP.md if it changes scope

**New Command (new /gsd: entry point):**
- Implementation: Create `/commands/gsd/command-name.md` with `<objective>`, `<execution_context>`, `<process>`
- Link to workflow: Point `<execution_context>` to corresponding workflow in `get-shit-done/workflows/command-name.md`
- Auto-registration: Command auto-registers as `/gsd:command-name` when installed

**New Workflow (new orchestration logic):**
- Implementation: Create `/get-shit-done/workflows/workflow-name.md` with `<process>` steps
- Pattern: Describe orchestration steps, agent spawning via Task(), checkpoint handling
- Reference: Use templates from `get-shit-done/templates/` for document generation
- Utilities: Call gsd-tools.cjs for state management, config parsing, git commits

**New Agent (new specialized role):**
- Implementation: Create `/agents/gsd-agent-name.md` with `<role>`, execution rules, output format
- Pattern: Define what the agent does, what context it needs, what it outputs
- Spawning: Workflows spawn via Task() with agent name; gsd-tools resolves model
- Model profile: Add entry to MODEL_PROFILES in gsd-tools.cjs if new agent type

**New Template (new document type):**
- For user projects: Create `/get-shit-done/templates/document-name.md` with frontmatter + placeholders
- For codebase analysis: Create `/get-shit-done/templates/codebase/DOCUMENT.md`
- Usage: Workflows use `template fill` command to pre-populate with variables

**New Reference Guide (shared knowledge):**
- Implementation: Create `/get-shit-done/references/topic-name.md` with detailed explanation
- Usage: Agents/workflows load via `@~/.claude/get-shit-done/references/topic-name.md`
- Pattern: Explain HOW to do something (checkpoints, git, verification, TDD, etc.)

**Utilities (centralized patterns):**
- Implementation: Add new command to `/get-shit-done/bin/gsd-tools.cjs`
- Pattern: Function that handles repeated bash/fs/git patterns
- Used by: Agents/workflows call via `node ~/.claude/get-shit-done/bin/gsd-tools.cjs <new-command>`

## Special Directories

**.planning/:**
- Purpose: GSD's own project planning and user projects' planning
- Generated: By `/gsd:new-project` command
- Committed: YES, all files committed to git (state is sacred)
- Subdirectories:
  - `phases/`: Numbered phases with PLAN.md + SUMMARY.md files
  - `codebase/`: Static analysis documents (if `/gsd:map-codebase` run)
  - `research/`: Research findings (if research done)
- Critical files:
  - `STATE.md`: Current position, decisions, metrics (never delete)
  - `ROADMAP.md`: Project phases and progress (never delete)
  - `config.json`: User preferences (customizable)

**.planning/codebase/:**
- Purpose: Persistent codebase analysis (architecture, stack, conventions, testing patterns, concerns)
- Generated: By `/gsd:map-codebase` command using 4 parallel mapper agents
- Committed: YES, documents committed to git
- Contains: 7 files (STACK.md, ARCHITECTURE.md, STRUCTURE.md, CONVENTIONS.md, TESTING.md, INTEGRATIONS.md, CONCERNS.md)
- Lifecycle: Can be refreshed anytime; new runs overwrite previous analysis

**node_modules/:**
- Purpose: NPM dependencies
- Generated: By `npm install`
- Committed: NO (in .gitignore)
- Cleanup: Run `npm ci` to restore from lock file

**get-shit-done/bin/dist/**
- Purpose: Built hooks (generated)
- Generated: By `npm run build:hooks`
- Committed: Depends on build settings (check .gitignore)

---

*Structure analysis: 2026-02-28*
