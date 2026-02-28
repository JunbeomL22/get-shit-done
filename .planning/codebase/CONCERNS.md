# Codebase Concerns

**Analysis Date:** 2026-02-28

## Critical Bugs

**STOPPED_PHASE Off-by-One Detection:**
- Issue: When a phase completes its plans and summaries but verification finds gaps, `yolo.md` derives the stopped phase incorrectly
- Files: `get-shit-done/workflows/yolo.md` (line 238 approx), `get-shit-done/bin/gsd-tools.cjs` (roadmap analyze command)
- Impact: User sees "stopped at phase N+1" instead of phase N; wrong phase directory is checked for VERIFICATION.md; case B2 (unexpected error) fires instead of B1 (verification failure); resume skips gap closure for the actual failed phase
- Root cause: `STOPPED_PHASE = next_phase` from roadmap analyze, which skips phases with `disk_status='complete'` even if `roadmap_complete=false`. Phase N has all SUMMARYs written but never calls `phase complete`, so roadmap checkbox stays unchecked, yet disk_status='complete'
- Fix approach: Scan phases array for `disk_status='complete' AND roadmap_complete=false` — this uniquely identifies the failed phase. Requires reading full roadmap analyze output's phases array

**Commands Not Installed After Source Creation:**
- Issue: `commands/gsd/yolo.md` exists in project repo but is not deployed to `~/.claude/commands/gsd/yolo.md` after initial creation
- Files: `commands/gsd/yolo.md` (source), installer target `~/.claude/commands/gsd/yolo.md`
- Impact: `/gsd:yolo` slash command unavailable to users unless installer is re-run manually; documented in v1-MILESTONE-AUDIT.md as "deployment gap"
- Fix approach: Re-run installer or manually copy source file. Installer does not auto-detect when new workflow files are added post-initial-install

## Configuration & State Issues

**Configuration File Serialization Errors Not Caught:**
- Issue: Multiple `JSON.parse()` calls throughout `gsd-tools.cjs` lack error boundaries; corrupt `.planning/config.json` halts all operations
- Files: `get-shit-done/bin/gsd-tools.cjs` (lines 178, 667, 705, 3657)
- Impact: If config.json becomes malformed (line ending corruption, incomplete write), all state commands fail; user has no graceful recovery path
- Current pattern: `try { JSON.parse(...) } catch { return defaults }` exists in loadConfig but not in state update flows
- Risk level: High — config.json is written frequently during phase operations, vulnerable to process kills mid-write

**YOLO State Stanza Atomicity:**
- Issue: `yolo-state` writes atomic to config.json, but multi-field updates (mode, auto_advance, yolo stanza) happen in sequence, not transactional
- Files: `get-shit-done/bin/gsd-tools.cjs` (yolo-state write implementation)
- Impact: If process dies between writes, state can be partially written (e.g., active=true but mode missing); next invocation may misinterpret state
- Current mitigation: yolo.md Phase B orders writes deliberately: mode → auto_advance → yolo stanza (stanza is point-of-no-return), per STATE.md decision
- Fragility: Order is enforced by convention in yolo.md, not by API contract; easy to misuse

**Environment Variable Handling for APIs:**
- Issue: BRAVE_API_KEY checked via process.env and also via file existence (braveKeyFile), but no unified handling
- Files: `get-shit-done/bin/gsd-tools.cjs` (lines 606, 2118, 4341 — three separate checks)
- Impact: Configuration state can be inconsistent if env var set but file missing (or vice versa); websearch command behavior unclear in mixed-state scenario
- Risk: Low — feature is optional and non-blocking, but inconsistency could confuse users

## Performance Bottlenecks

**Large gsd-tools.cjs Monolith:**
- Issue: Single 5243-line CommonJS file with 100+ exported functions and 30+ phase commands
- Files: `get-shit-done/bin/gsd-tools.cjs`
- Impact: Startup latency increases with file size; context switching between unrelated concerns (state, validation, templates, roadmap) within same file
- Current mitigation: No modularization; all operations synchronous
- Scaling concern: Adding new commands (v2 phase requirements, new verification types) pushes file toward unmaintainability

**Synchronous File I/O in State Updates:**
- Issue: All state writes use `fs.writeFileSync()`, blocking on every config mutation
- Files: `get-shit-done/bin/gsd-tools.cjs` (lines 642, 687, 755, 1175, etc.)
- Impact: Phase operations waiting on disk writes; no parallelization possible when batch-updating multiple config fields
- Risk level: Low for typical use (single phases run sequentially), but noticeable on slower file systems or network shares
- Improvement path: Switch to async I/O with proper error handling

## Test Coverage Gaps

**gsd-tools.cjs Test Coverage Incomplete:**
- Issue: `gsd-tools.test.cjs` exists (2346 lines) but test file is 45% of tool size; many commands untested
- Files: `get-shit-done/bin/gsd-tools.cjs`, `get-shit-done/bin/gsd-tools.test.cjs`
- Impact: Commands like `frontmatter merge`, `template fill`, `verify artifacts`, `history digest` lack unit tests; integration bugs may hide
- Risk: Medium — tested commands are core (state, roadmap), but edge cases in lesser-used commands could break phases

**Live Claude Code Verification Pending:**
- Issue: Six phase 2 and 4 behaviors require live Claude Code session verification but have not been completed
- Files: Phases 02-launcher and 04-resume-and-visibility verification documents
- Impact: No-argument invocation, stale state prompts, YOLO RESUME banner, progress banner, completion summary behavior unverified in real Claude Code context
- Current status: Architecture tested in isolation; e2e flow not verified against actual Claude Code command evaluation

**Workflow Integration E2E Tests Missing:**
- Issue: No end-to-end test suite for yolo.md chaining across phases
- Files: `get-shit-done/workflows/yolo.md` and dependent workflows
- Impact: STOPPED_PHASE bug (above) was not caught by tests; off-by-one errors in phase tracking, resume logic, and state transitions could silently occur
- Recommendation: Create integration test harness that simulates multi-phase runs with mock verification failures

## Fragile Areas

**Roadmap Parsing Brittle to Format Changes:**
- Issue: Multiple places parse ROADMAP.md with string matching and jq filters; no schema validation
- Files: `get-shit-done/bin/gsd-tools.cjs` (roadmap analyze command), yolo.md Phase A2
- Impact: If ROADMAP.md format drifts (spacing, heading level changes), phase detection breaks silently
- Current patterns: Markdown heading detection via regex, checkbox parsing via grep, disk_status derivation from SUMMARY file counts
- Safe modification: Add explicit schema validation layer before relying on parsed output

**Phase Number Renumbering on Delete:**
- Issue: `phase remove` renumbers all subsequent phases, but running phases may be in-progress; renumbering mid-execution causes state desynchronization
- Files: `get-shit-done/bin/gsd-tools.cjs` (phase remove command)
- Impact: If phase 3 is deleted while phase 4 is being executed, phase 4's directory name changes but running plan/execute agents reference old number
- Risk level: High if triggered during active execution, low during planning phases
- Safe modification: Prevent phase removal if any phase's PLAN.md or SUMMARY.md is actively being written (check file modification time)

**Verifier and Plan-Checker Timeout Handling:**
- Issue: Plan-checker and verifier agents run asynchronously via Task() in workflows, but timeout handling is minimal
- Files: `get-shit-done/workflows/plan-phase.md`, `get-shit-done/workflows/verify-work.md`, `get-shit-done/workflows/transition.md`
- Impact: If checker/verifier times out, workflow returns partial results; state may be written anyway (phase marked complete but no verification summary)
- Current mitigation: None explicit; relies on workflow logic to detect missing SUMMARY.md files
- Fragility: Task() timeout behavior varies by Claude Code version; no explicit retry or checkpoint mechanism

**Frontmatter Validation Order-Dependent:**
- Issue: Frontmatter field validation checks for required fields but doesn't validate field types, interdependencies, or semantic consistency
- Files: `get-shit-done/bin/gsd-tools.cjs` (frontmatter validate command)
- Impact: Invalid PLAN.md or SUMMARY.md frontmatter (e.g., `status: invalid_value`) passes validation; downstream code assumes valid enum values
- Risk: Medium — affects phase detection and verification flows that depend on status field

**Model Profile Resolution Coupled to CONFIG:**
- Issue: Model resolution reads from user's global config.json, but agent context includes hardcoded agent → model mappings
- Files: `get-shit-done/bin/gsd-tools.cjs` (MODEL_PROFILES table), agent definitions
- Impact: If config.json is missing or doesn't define model_profile, agents fall back to hardcoded defaults; user's preference is silently ignored in some cases
- Safe modification: Add explicit logging when fallback occurs

## Security Considerations

**Shell Escaping in Git Commands:**
- Issue: `execGit()` function escapes arguments via regex check `if (/^[a-zA-Z0-9._\-/=:@]+$/)` and shell quoting, but edge cases exist
- Files: `get-shit-done/bin/gsd-tools.cjs` (execGit function, lines 225-244)
- Impact: If phase names or slugs contain special characters (quotes, newlines, backticks), git commit messages may inject commands
- Current mitigation: Phase names are controlled by system (generated from descriptions), but user-provided messages could be vulnerable
- Risk: Medium — requires malicious input in phase descriptions or custom commit messages

**File Path Traversal in Template Operations:**
- Issue: `template fill` and frontmatter operations use user-provided file paths without path normalization
- Files: `get-shit-done/bin/gsd-tools.cjs` (template fill command, frontmatter commands)
- Impact: Path like `../../.env` could target files outside `.planning/` if passed to frontmatter operations
- Risk: Low — paths are expected to be generated by orchestrator, not user-input, but input validation missing

**No Secret Redaction in Error Messages:**
- Issue: Error output from execSync (git, jq) may include environment variable values or API keys if command fails
- Files: `get-shit-done/bin/gsd-tools.cjs` (error handling, lines 488-489)
- Impact: If BRAVE_API_KEY or other secrets are embedded in command strings, failure messages expose them to logs/output
- Current mitigation: Most commands use env vars (not shell args), limiting exposure
- Fix approach: Redact common secret patterns (API_KEY=, sk-, Bearer) from stderr before output

## Documentation Gaps

**REQUIREMENTS.md Checkbox Updates Not Automated:**
- Issue: v1 requirements checkboxes in REQUIREMENTS.md remain `[ ]` even after verification passes
- Files: `.planning/REQUIREMENTS.md`
- Impact: Users can't quickly see which requirements are satisfied; traceability table is stale
- Current status: All 10 v1 requirements satisfied per phase VERIFICATIONs, but checkboxes not checked
- Fix approach: Add final validation step after phase completion that updates REQUIREMENTS.md checkboxes

**No Runbook for YOLO Failure Recovery:**
- Issue: When YOLO stops on verification gaps, user sees error message but has no documented recovery steps
- Files: `get-shit-done/workflows/yolo.md` (Case B1 banner), `docs/USER-GUIDE.md`
- Impact: User may not know to run `plan-phase --gaps --auto` to close gaps before resuming
- Current mitigation: Case B1 banner adds "To investigate" hint, but full recovery command not documented
- Fix approach: Link to dedicated recovery guide in stop banner

**Verifier Agent Role Definition Unclear:**
- Issue: `gsd-verifier` agent file defines verification responsibilities, but boundaries with integration-checker are fuzzy
- Files: `agents/gsd-verifier.md`, `agents/gsd-integration-checker.md`
- Impact: Overlapping concerns (requirements coverage, cross-phase wiring, phase-to-phase integration) could lead to duplicate or missed verification
- Current status: Integration checker handles cross-phase wiring; verifier handles per-phase correctness
- Safe modification: Add explicit section headers in verifier agent (In Scope / Out of Scope) to clarify phase boundary

## Dependencies at Risk

**No Version Pinning for GSD Tool Installation:**
- Issue: User runs `npx get-shit-done-cc@latest`, pinning to whatever latest is; major version upgrades may introduce breaking changes
- Files: `package.json` (version 1.20.3), `bin/install.js`
- Impact: If breaking change lands in v2, users running `@latest` auto-upgrade without migration path
- Current mitigation: Installer has version manifest, but downgrade not supported
- Risk: Low for near term (v1 stable), high if v2 introduces incompatible config format

**esbuild Dependency for Hooks Build:**
- Issue: Hooks build uses `esbuild ^0.24.0` (caret range); minor version updates could break hook compilation
- Files: `package.json` (dev dependency), `scripts/build-hooks.js`
- Impact: Hook build errors would surface at install time, blocking new installations
- Risk: Low — esbuild is mature, but semantic versioning not strictly observed in 0.x versions

## Scaling Limits

**Phase Numbering Decimal Notation Limits:**
- Issue: Phase numbering supports decimal notation (e.g., 2.1, 2.1.1) but roadmap parsing assumes specific depth
- Files: `get-shit-done/bin/gsd-tools.cjs` (normalizePhaseName function, phase comparison logic)
- Impact: If phase tree grows deeply nested (e.g., 1.2.3.4), roadmap ordering and phase detection could fail
- Current capacity: Tested to 3+ decimal levels (e.g., phases in audit are numbered 1, 2, 3, 4 flat), but no explicit limit documented
- Scaling path: Add explicit max-depth validation

**Milestone Archival Doesn't Support Large Phase Counts:**
- Issue: `milestone complete` reads all phase files and copies them sequentially; no batch operations
- Files: `get-shit-done/bin/gsd-tools.cjs` (milestone complete command)
- Impact: Archiving milestone with 50+ phases takes O(n) time; roadmap parsing becomes slow
- Risk: Low for v1 (5 phases), medium for v2+ if phases grow
- Improvement path: Use parallel file operations or stream-based copy

## Missing Critical Features

**No Rollback Mechanism for Failed Phase Execution:**
- Issue: If a phase's PLAN.md is executed but produces incorrect code, there's no undo/rollback
- Files: All phase execution workflows (`execute-phase.md`, `execute-plan.md`)
- Impact: User must manually revert git commits or code changes; integration with git is one-directional
- Current mitigation: Verification step catches errors before advancing, but user bears responsibility for reverting bad code
- Fix approach: Add `--rollback` flag to phase operations that reverts latest commit + clears phase state

**No Dry-Run Mode for State Operations:**
- Issue: `yolo-state write`, config updates, and milestone operations execute immediately; no preview of changes
- Files: `get-shit-done/bin/gsd-tools.cjs` (state commands)
- Impact: Users can't verify what will change before committing state; risky for automation
- Risk: Low for manual use, medium for scripted deployments
- Improvement path: Add `--dry-run` flag that outputs what would change without writing

**No Built-In State Backup Before Major Operations:**
- Issue: Phase deletions, milestone completions, and phase advances write state without creating backup
- Files: `get-shit-done/bin/gsd-tools.cjs` (phase remove, milestone complete, phase complete)
- Impact: Accidental deletion of phase data has no recovery path (except git history)
- Risk: Medium — user could accidentally delete wrong phase and lose work
- Fix approach: Auto-backup config.json + relevant phase files before destructive operations

## Technical Debt

**Logging Strategy Missing:**
- Issue: No centralized logging; errors go to stderr, info goes to stdout, no log levels
- Files: `get-shit-done/bin/gsd-tools.cjs`, all workflow files
- Impact: Debugging state machine issues requires manual tracing; no audit trail for automated runs
- Current pattern: `process.stderr.write()` for errors, `process.stdout.write()` for output, no structured logging
- Improvement path: Add optional `--debug` flag that writes detailed logs to `.planning/.logs/`

**Markdown Parsing Not Standardized:**
- Issue: ROADMAP.md, STATE.md, PLAN.md frontmatter parsing uses different regex patterns in different files
- Files: `get-shit-done/bin/gsd-tools.cjs` (multiple frontmatter parsing implementations)
- Impact: Changes to markdown format require updates in multiple places; inconsistency in error handling
- Risk: Medium — regex drift could cause silent parsing failures
- Improvement path: Extract markdown parsing into standalone utility module with tests

**No Input Validation Layer:**
- Issue: Commands accept free-form arguments with minimal validation; semantic errors caught late
- Files: `get-shit-done/bin/gsd-tools.cjs` (command dispatch)
- Impact: Invalid phase numbers, missing required flags, and malformed JSON arguments produce unhelpful errors
- Risk: Low impact, high user friction
- Improvement path: Add schema validation layer (zod or similar) for common argument patterns

**Hardcoded Paths to Home Directory Config:**
- Issue: References to `~/.claude/`, `~/.opencode/`, `~/.gemini/` scattered throughout installer and tools
- Files: `bin/install.js`, `get-shit-done/bin/gsd-tools.cjs`, `get-shit-done/workflows/yolo.md`
- Impact: Changes to config directory structure require updates in multiple places
- Current concern: No environment variable override for testing or alternative installations
- Improvement path: Centralize path resolution in a single config module

---

*Codebase concerns audit: 2026-02-28*
