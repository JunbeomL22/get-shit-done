# Codebase Concerns

**Analysis Date:** 2026-02-17

## Tech Debt

**Silent JSON Parsing Failures:**
- Issue: Multiple places parse JSON with silent error handling (catch blocks that return empty/default values)
  - `bin/install.js` (lines 204-207, 917, 1108): readSettings() catches parse errors, returns empty object
  - `get-shit-done/bin/gsd-tools.cjs`: manifest/meta parse failures silently return empty arrays
- Files: `bin/install.js`, `get-shit-done/bin/gsd-tools.cjs`
- Impact: Corrupted JSON files (settings.json, opencode.json, config.json) won't be reported to user; silently loses configuration. User won't know their settings were lost until they try to use them.
- Fix approach: Log errors to stderr even when recovering gracefully. Create separate silent-recover and verbose-parse modes. For critical files (settings.json), verify round-trip parse before accepting.

**Monolithic gsd-tools CLI (5243 lines):**
- Issue: Single file handles 100+ subcommands across state management, phase operations, verification, templating, and scaffolding
- Files: `get-shit-done/bin/gsd-tools.cjs`
- Impact: Hard to locate bugs, difficult to test individual commands, high cognitive load for modifications, single point of failure for entire CLI layer
- Fix approach: Split into module-based structure (phase-ops.js, state-ops.js, verify-ops.js, etc.) with exports, then orchestrate from wrapper entry point. Maintain gsd-tools.cjs as thin dispatcher.

**File System Operations Without Safety Checks:**
- Issue: 10 fs.rmSync() and fs.unlinkSync() calls (install.js lines 638, 689, 742, 847, 857, 866, 878, 896, 913, 1417)
  - Most have existence checks, but some don't have recursive safety verification
  - Paths constructed from user input (explicitConfigDir) with minimal validation
- Files: `bin/install.js` (uninstall function at line 811+)
- Impact: Risky uninstall could delete files beyond GSD-specific paths if path construction is wrong; edge case with symlinks could escape sandbox
- Fix approach: Add whitelist of allowed removal paths. Before any rmSync/unlinkSync, verify path is under expected parent AND matches GSD file patterns. Log all deletions.

**JSONC Parser Assumes Valid Input:**
- Issue: parseJsonc() function (bin/install.js lines 1030-1084) does manual parsing of comments/trailing commas
  - Falls back to JSON.parse() if manual parsing fails
  - No limits on comment nesting depth or input size
- Files: `bin/install.js` (line 1030+)
- Impact: Malformed JSONC could cause regex catastrophic backtracking or infinite loops; large files could cause memory pressure
- Fix approach: Add configurable size limit, test with adversarial inputs, consider using lightweight JSONC library instead of custom parser

**Hardcoded Hook References:**
- Issue: Hook command paths and names hardcoded across codebase (gsd-statusline.js, gsd-check-update.js)
  - List of hooks appears in multiple places: install.js line 891, cleanup functions track orphaned versions
  - Future hook additions require updates in multiple files
- Files: `bin/install.js`, `hooks/` directory references in agents and commands
- Impact: Easy to miss a hook registration when adding new ones; orphaned hook detection is fragile and will miss new hooks
- Fix approach: Create `hooks/manifest.json` with hook metadata (name, event type, description, added_version), load from there instead of hardcoding lists

**Attribute Attribution Processing Complexity:**
- Issue: Commit attribution handled with caching (attributionCache), multiple runtime branches, and state-dependent behavior
  - getCommitAttribution() checks opencode.json, gemini settings.json, claude settings.json with different logic
  - processAttribution() handles three cases: null (remove), undefined (keep), string (replace)
  - Escape logic (line 280: `replace(/\$/g, '$$$$')`) is subtle and easy to break
- Files: `bin/install.js` (lines 219-282)
- Impact: Attribution line corruption if escape logic breaks; different runtimes have different priority rules that are hard to debug
- Fix approach: Create shared AttributionManager class with testable methods, document the three-state semantics clearly

## Known Bugs

**Claude Code classifyHandoffIfNeeded False Failures:**
- Symptoms: Agents report failure when they actually completed work; workflows incorrectly think tasks failed
- Files: `agents/gsd-executor.md`, `get-shit-done/workflows/execute-phase.md`
- Trigger: Certain types of output (long text, JSON, complex structures) trigger false failure reports
- Workaround: Spot-check actual output before accepting failure report (execute-phase and quick workflows do this at lines ~131 of CHANGELOG notes)
- Root cause: Claude Code bug #13898 - classifyHandoffIfNeeded misclassifies output as failure
- Status: Mitigated with workaround, waiting on Claude Code fix

**Phase Heading Depth Variation:**
- Symptoms: Phase detection sometimes fails for phases marked with `####` (4 hashes) instead of `##` or `###`
- Files: `get-shit-done/bin/gsd-tools.cjs` (phase heading parsing)
- Trigger: Nested phase documentation or ROADMAP with inconsistent heading depths
- Workaround: Normalize all phase headings to `##` during editing
- Root cause: Phase heading regex may not account for variable depth
- Fixed in: v1.19.0 (accepts both ## and ###), but may still have issues with #### and beyond

**Plan-Phase Autocomplete Interference:**
- Symptoms: `/gsd:plan-phase` command appears in autocomplete suggestions when it shouldn't (clashes with `/gsd:execute-phase`)
- Files: Commands (TOML/markdown definitions)
- Trigger: When autocompleting /gsd commands after `plan-`
- Workaround: Type full command name explicitly
- Root cause: Word "execution" in plan-phase description caused autocomplete confusion
- Fixed in: v1.19.2 (removed "execution" from description)

**ESM vs CommonJS Module Inheritance:**
- Symptoms: "require is not defined" error when GSD scripts run in ES module contexts
- Files: Projects with `"type": "module"` in package.json
- Trigger: Running gsd-tools from within an ES module project
- Workaround: GSD now writes package.json to `.claude/package.json` with `{"type":"commonjs"}` (line 1472)
- Root cause: Node.js walks up directory tree looking for package.json; project's ES setting inherited by GSD scripts
- Fixed in: v1.19.0 (`package.json` marker file stops inheritance)

## Security Considerations

**Credential Path Traversal in install.js:**
- Risk: explicitConfigDir (from --config-dir flag) is used directly in path.join() without validation
  - Could potentially resolve to paths outside intended scope (e.g., `--config-dir ../../etc/passwd`)
  - Uninstall function (line 811+) uses this unvalidated path in destructive operations
- Files: `bin/install.js` (lines 143-165, 817-818)
- Current mitigation: Paths are validated with path.join (which normalizes), but no whitelist enforcement
- Recommendations:
  - Validate explicitConfigDir is a canonical absolute path under home directory or within allowed scope
  - For uninstall, double-check path pattern matches `{config_dir}/{runtime}/` structure before any deletions
  - Add --force flag requirement for destructive operations when custom config-dir is used

**Secrets in Debug Output:**
- Risk: Agent prompts and debugging output might inadvertently echo environment variables or file contents containing secrets (API keys, tokens, credentials)
  - gsd-tools history-digest reads all SUMMARY.md files and could expose secrets in frontmatter
  - Debug workflows (`gsd-debugger.md`) log detailed context that could contain keys
- Files: `agents/gsd-debugger.md`, `get-shit-done/bin/gsd-tools.cjs` (history-digest command)
- Current mitigation: Environment variables not explicitly sanitized before output
- Recommendations:
  - Add secret redaction filter (common patterns: API_KEY=, sk-, token=, password=) before any output
  - Document that SUMMARY.md frontmatter should never contain actual secrets (only reference env var names)
  - Test history-digest against files containing sample secrets

**JSON Parsing from Untrusted Sources:**
- Risk: parseJsonc() and manifest parsing consume user-edited files without size limits
  - Malicious JSONC could cause ReDoS (regular expression denial of service) in comment stripping
  - Large manifests could cause memory exhaustion
- Files: `bin/install.js` (lines 1030-1084, JSON parse at 1107)
- Current mitigation: None (silent error handling swallows problems)
- Recommendations:
  - Add max file size check (e.g., 1MB limit) before parsing
  - Use library JSONC parser or thoroughly test regex for ReDoS vulnerability
  - Add timeout on JSON parse operations

**Hook Command Injection:**
- Risk: Hook commands are constructed as shell commands and executed via node
  - statuslineCommand and updateCheckCommand built from user paths (lines 1513-1518)
  - Path templating could fail to escape special characters
- Files: `bin/install.js` (buildHookCommand at line 192, finishInstall at line 1570+)
- Current mitigation: Paths use forward slashes and are quoted in command string
- Recommendations:
  - Use execFile() instead of shell string interpolation where possible
  - Add validation that hook paths don't contain shell metacharacters
  - Test with paths containing spaces, $, backticks, semicolons

## Performance Bottlenecks

**History Digest O(n*m) Complexity:**
- Problem: history-digest command scans all phase directories and parses all SUMMARY.md files every invocation
- Files: `get-shit-done/bin/gsd-tools.cjs` (history-digest at ~820)
- Cause: No caching; reconstructs full history from disk every time
- Improvement path:
  - Cache digest output to .planning/.cache/history-digest.json with mtime tracking
  - Invalidate cache only when SUMMARY.md files change
  - For large projects with 100+ phases, expected 10x speedup

**Recursive Phase Directory Scanning:**
- Problem: Phase listing scans entire .planning/phases with readdir at multiple depth levels
- Files: `get-shit-done/bin/gsd-tools.cjs` (phase lookup functions)
- Cause: Finds phase by regex matching against filesystem
- Improvement path: Build in-memory phase index at startup, refresh on demand only

**Install Operation Creates Many Small Files:**
- Problem: Copying entire get-shit-done directory (templates, workflows, agents, references) on every install
  - ~200+ files copied even if only 2-3 are actually used by a given project
- Files: `bin/install.js` (copyWithPathReplacement at line 683)
- Cause: Monolithic directory structure
- Improvement path: Lazy-load referenced files, pre-select commonly-needed sets (lite install vs full install)

## Fragile Areas

**YAML Frontmatter Parsing in gsd-tools:**
- Files: `get-shit-done/bin/gsd-tools.cjs` (frontmatter extraction at ~240)
- Why fragile:
  - Manual line-by-line YAML parser, not a proper YAML library
  - Assumes specific indentation (2-space), breaks with tabs or mixed indentation
  - Array detection uses simple `startsWith('-')` check, fails with YAML block syntax or comments
  - Nested field access (e.g., dependency-graph.provides) assumes specific nesting structure
- Common failures:
  - If YAML uses 4-space indentation instead of 2, arrays won't parse
  - If frontmatter has inline comments, they'll be treated as part of values
  - If array item has comment, it breaks parsing
- Safe modification:
  - Test any changes against variety of real YAML examples from existing SUMMARY.md files
  - Consider using js-yaml library if YAML complexity grows
  - Add unit tests for each frontmatter extraction case
- Test coverage: gsd-tools.test.cjs has some tests (nested frontmatter) but not comprehensive

**Orphaned File Detection:**
- Files: `bin/install.js` (cleanupOrphanedFiles at line 733, cleanupOrphanedHooks at line 751)
- Why fragile:
  - Hardcoded list of old file names (gsd-notify.sh, statusline.js, gsd-intel-*.js)
  - If new hooks are added without removing old versions, cleanup won't find them
  - Pattern matching for hook identification uses string.includes() on full command path
- Common failures:
  - New hook version added but old version not listed in cleanup → both get installed
  - User has custom hook with similar name → might get deleted accidentally
  - Settings.json hook registration changes in format → old cleanup patterns won't match
- Safe modification:
  - Always add to orphaned lists when deprecating files
  - Use exact filename matching instead of pattern includes()
  - Write test for cleanup before/after state
- Test coverage: No dedicated tests for cleanup functions

**OpenCode Permission Configuration:**
- Files: `bin/install.js` (configureOpencodePermissions at line 1091)
- Why fragile:
  - Constructs glob path using `${opencodeConfigDir}/get-shit-done/*`
  - If path contains special characters, glob might not work
  - Assumes opencode.json is valid JSONC; if corrupt, silently skips config
  - Different logic for global vs local (isGlobal flag), easy to misconfigure one path
- Common failures:
  - Custom config-dir with spaces or special chars → permission glob wrong
  - Multiple OpenCode installations → permission scope might overlap
  - User edits opencode.json manually → JSONC parse fails, permissions not updated
- Safe modification:
  - Validate path before creating glob
  - Test with paths containing spaces, hyphens, dots
  - Add explicit error logging when opencode.json parse fails
- Test coverage: None (no tests for OpenCode-specific logic)

**Runtime-Specific Path Templating:**
- Files: `bin/install.js` (getConfigDirFromHome at line 55, getGlobalDir at line 100)
- Why fragile:
  - Three different runtimes (claude, opencode, gemini) have different config paths
  - OpenCode uses XDG Base Directory spec with environment variable overrides (OPENCODE_CONFIG_DIR, OPENCODE_CONFIG, XDG_CONFIG_HOME)
  - Gemini uses GEMINI_CONFIG_DIR or ~/.gemini
  - Claude uses CLAUDE_CONFIG_DIR or ~/.claude
  - Priority order differs per runtime
- Common failures:
  - User sets OPENCODE_CONFIG_DIR but install uses XDG_CONFIG_HOME → wrong location
  - Switching between local and global installs → path templates conflict
  - Mixed-mode (some runtimes global, some local) → settings.json paths hard to debug
- Safe modification:
  - Document priority order for each runtime clearly
  - Test with each environment variable combination
  - Add debug output showing which path was selected and why
- Test coverage: None (path resolution not tested)

## Scaling Limits

**Single Config.json File:**
- Current capacity: Config.json holds all project settings (model_profile, commit_docs, branching_strategy, research settings, parallelization, brave_search, plus per-agent overrides)
- Limit: Breaks when config.json exceeds ~100KB or has 1000+ keys (not realistic but theoretically possible with per-agent model overrides for many agents)
- Symptoms at limit: Slow load times, merge conflicts in git, hard to debug which setting caused behavior
- Scaling path: Move per-agent settings to separate file (.planning/agent-overrides.json), archive old config versions

**Phase Directory Enumeration:**
- Current capacity: Linear scan of .planning/phases directory works well up to ~500 phases
- Limit: Beyond ~500 phases, repeated scans for phase lookup become slow (especially on network filesystems)
- Symptoms at limit: `/gsd:progress` and phase listing commands noticeably slow
- Scaling path: Build .planning/.cache/phase-index.json at project load time, invalidate only when phases/ directory changes (use fs.watch)

**History Digest JSON Size:**
- Current capacity: Aggregating all SUMMARY.md frontmatter works up to ~100 phases
- Limit: Beyond 100 phases, JSON grows to 500KB+; entire digest re-parsed every time
- Symptoms at limit: Planner agent slow to load project history; context window eaten by history
- Scaling path: Implement rolling window (last 20 phases) or sampling, add compression/summarization of old decisions

## Dependencies at Risk

**Manual YAML Parsing:**
- Risk: Custom YAML parser in gsd-tools is incomplete and will break as YAML complexity grows
- Files: `get-shit-done/bin/gsd-tools.cjs` (frontmatter parsing)
- Impact: Future SUMMARY.md schema additions (comments, complex nesting, flow style) will break parsing
- Migration plan: When YAML parsing becomes issue, switch to `js-yaml` npm package (small, well-maintained); add as optional dev dependency with fallback to custom parser

**No Dependency Lock (package.json):**
- Risk: package.json has zero dependencies; makes git hook scripts brittle (rely on Node builtins only)
  - If Node builtins change (unlikely but happened in past), hooks could break
  - If new Node version changes JSON.stringify() output or fs behavior, could break
- Files: `package.json` (line 39: empty dependencies)
- Impact: Version mismatch if user upgrades Node; edge cases with JSON whitespace breaking frontmatter
- Migration plan: Consider pinning to Node 16+ in engines field; add integration tests for Node 18, 20, 22

**File Permission Model (Not Windows-Aware):**
- Risk: Hook scripts assume Unix file permissions; Windows path handling patched but inconsistent
  - Executable bits not set on .js files (Node runs them anyway, but not POSIX-compliant)
  - Path backslash handling requires normalization in multiple places
- Files: `bin/install.js` (lines 194, 1348, 1490)
- Impact: Hooks might not execute on Windows if anyone tries to run them directly; cross-platform testing needed
- Migration plan: Add Windows CI job to test full install/uninstall flow on Windows

## Missing Critical Features

**No Configuration Validation on Startup:**
- Problem: Config.json loaded but not validated against schema; invalid config silently uses defaults
- Blocks: Can't detect user misconfiguration without running each command and getting vague errors
- Workaround: `/gsd:health` command now validates, but not run automatically

**No Automatic Config Migration for Version Upgrades:**
- Problem: When GSD adds new config fields, old config.json doesn't get updated; uses hardcoded defaults
- Blocks: New features can't rely on config being present
- Workaround: Manual documentation of required config.json updates in CHANGELOG

**No Rollback Mechanism for Failed Installs:**
- Problem: If install fails mid-operation, config directory left in inconsistent state
- Blocks: Retry often fails; user must manually clean up
- Workaround: Local patch persistence saves modified files, but doesn't restore failed partial installs

**No Multi-Project Config Inheritance:**
- Problem: Each project has own .planning/config.json; no way to set sane defaults globally
- Blocks: Users must reconfigure each project (model_profile, branching_strategy, etc.)
- Fixed in: v1.19.2 (added ~/.gsd/defaults.json), but implementation might be incomplete

## Test Coverage Gaps

**Install/Uninstall Logic:**
- What's not tested:
  - Uninstall with custom config-dir paths
  - Uninstall when files are missing/corrupted
  - Full round-trip install → modify → update → reapply-patches
  - Mixed runtime installs (some global, some local)
- Files: `bin/install.js` (1816 lines, functions from line 811 onward)
- Risk: Uninstall could accidentally delete user files if safe removal isn't correct
- Priority: High (destructive operations)

**gsd-tools CLI Commands:**
- What's not tested:
  - phase add/insert/remove with edge cases (last phase, decimal boundaries)
  - roadmap update-plan-progress accuracy
  - milestone complete with empty phases
  - All state progression commands (record-metric, add-decision, record-session)
  - verify commands with malformed inputs
  - Concurrent gsd-tools invocations (race conditions on STATE.md)
- Files: `get-shit-done/bin/gsd-tools.cjs` (5243 lines)
- Risk: Data corruption in .planning/ if commands have bugs with edge cases
- Priority: High (state mutation)

**Frontmatter Round-Trip Integrity:**
- What's not tested:
  - Setting a frontmatter field and reading it back → same value?
  - Merging frontmatter with complex nested structures
  - Handling special characters and escaping in values
  - Reading old SUMMARY.md files with different schema versions
- Files: `get-shit-done/bin/gsd-tools.cjs` (frontmatter CRUD)
- Risk: Data loss when planner writes to STATE.md or when archiving milestones
- Priority: High (all workflows depend on this)

**Path Resolution Across Runtimes:**
- What's not tested:
  - Each runtime with each environment variable combination
  - Local vs global install path construction
  - Symlinks and relative path expansion
  - Windows vs Linux/Mac path handling
- Files: `bin/install.js` (getGlobalDir, getOpencodeGlobalDir, expandTilde)
- Risk: Hooks won't find scripts; install goes to wrong location
- Priority: Medium (affects all installs)

**JSONC Parsing Edge Cases:**
- What's not tested:
  - Comments before/after every JSON element
  - Trailing commas in nested structures
  - Mixed tabs and spaces (should fail gracefully)
  - Very large files (memory behavior)
  - Adversarial inputs (ReDoS via regex)
- Files: `bin/install.js` (parseJsonc, lines 1030-1084)
- Risk: Malformed config files could hang install or consume memory
- Priority: Medium (corruption risk, but user-editable files only)

---

*Concerns audit: 2026-02-17*
