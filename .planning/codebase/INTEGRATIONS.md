# External Integrations

**Analysis Date:** 2026-02-17

## External AI Runtimes & APIs

**Claude Code (Anthropic):**
- Purpose: Primary development runtime target
- Integration: Command installation into `~/.claude/` config directory
- Authentication: Handled by Claude Code session (no API keys required in GSD)
- Hooks: Installs statusline hook and update-check hook
- Tools available: Read, Write, Edit, Bash, Glob, Grep, WebFetch, WebSearch, AskUserQuestion, SlashCommand, TodoWrite
- Configuration: `~/.claude/settings.json` (permissions, attribution, statusline)

**OpenCode (Open Source):**
- Purpose: Alternative open-source runtime target
- Integration: Command installation into `~/.config/opencode/` (XDG Base Directory spec)
- Authentication: Handled by OpenCode session
- Config precedence: `OPENCODE_CONFIG_DIR` > `OPENCODE_CONFIG` > `XDG_CONFIG_HOME/opencode` > `~/.config/opencode`
- Tools mapping: Claude tool names converted to lowercase (e.g., AskUserQuestion → question)
- Configuration: `opencode.json` with tool permissions and attribution settings

**Gemini CLI (Google):**
- Purpose: Alternative AI runtime target
- Integration: Command installation into `~/.gemini/` config directory
- Authentication: Handled by Gemini CLI session
- Tools mapping: Claude tool names converted to snake_case (e.g., Read → read_file, Bash → run_shell_command)
- Features: Experimental agents enabled with flag `-e` for custom sub-agents
- Configuration: `settings.json` with tool permissions and attribution settings

## Package Registry

**NPM Registry:**
- Service: NPM public registry (npmjs.com)
- Purpose: Package distribution and version checking
- Integration: `npm view get-shit-done-cc version` command
  - Used in: `hooks/gsd-check-update.js` (background update checker)
  - Timeout: 10 seconds
  - Caching: Results stored in `~/.claude/cache/gsd-update-check.json`
  - Display: Update notification shown in statusline if newer version available

## Web Search

**Brave Search API:**
- Service: Brave Search (https://api.search.brave.com/res/v1/web/search)
- Purpose: Enhanced web search capabilities for research workflows
- Authentication: `BRAVE_API_KEY` environment variable
- Key storage location: `~/.config/brave-search-api-key` (checked if env var not set)
- Integration point: `get-shit-done/bin/gsd-tools.cjs` → `cmdWebsearch()` function
- Parameters:
  - Query limit: Default 10 results (configurable via `--limit N`)
  - Freshness: Optional filter for result recency (day|week|month)
  - Country: Fixed to 'us'
  - Language: Fixed to 'en'
  - Text decorations: Disabled
- Response format: JSON with web results (title, url, description, age)
- Fallback: If API key not configured, silently skips (agent falls back to built-in WebSearch)

## Git Integration

**Git Repository Hosting:**
- Repository: https://github.com/glittercowboy/get-shit-done
- Integration: Project version tracking, issue tracking
- Workflow integration: GSD workflows create git commits automatically
  - Uses: `git commit` with structured messages
  - Attribution: Configurable Co-Authored-By lines
  - Validation: Checks `.planning/` gitignore status

**Git Operations in GSD:**
- Location: `get-shit-done/bin/gsd-tools.cjs` - centralized git handling
- Operations: Commit messages, branch management, phase tracking
- Configuration: `branching_strategy`, `phase_branch_template`, `milestone_branch_template` (in config.json)
- Check commands: `git check-ignore`, `git log`, `git branch`

## File System Integration

**User Configuration Directories:**
- Claude Code: `~/.claude/` (with subdirectories: `get-shit-done/`, `hooks/`, `cache/`, `todos/`)
- OpenCode: `~/.config/opencode/` (XDG Base Directory spec)
- Gemini CLI: `~/.gemini/`

**Local Installation:**
- Project-scoped: `./.claude/`, `./.opencode/`, `./.gemini/` (same hierarchy as global)
- Advantage: Per-project GSD configuration without global installation

**Cache Locations:**
- Update check cache: `~/.claude/cache/gsd-update-check.json`
- Todo tracking: `~/.claude/todos/` (session-based JSON files)

## Webhooks & System Hooks

**SessionStart Hook (Claude Code/OpenCode/Gemini):**
- Trigger: When development session starts
- Script: `hooks/gsd-check-update.js`
- Function: Background check for newer GSD versions
- Process: Spawns detached background process to avoid blocking session
- Output: Writes to cache file (`~/.claude/cache/gsd-update-check.json`)

**Statusline Hook (Claude Code/OpenCode/Gemini):**
- Trigger: Session statusline rendering
- Script: `hooks/gsd-statusline.js`
- Input: JSON stdin from runtime (model, workspace, session_id, context_window)
- Function: Displays model, current task, directory, context usage, update notification
- Output: Formatted ANSI text for statusline display
- Data sources:
  - Session metadata from runtime
  - Current task from todo files (`~/.claude/todos/`)
  - Update cache from `gsd-check-update.json`
  - Context window remaining percentage

## Data Formats & Synchronization

**Markdown Frontmatter:**
- Format: YAML frontmatter in markdown documents (between `---` delimiters)
- Purpose: Structured metadata for phases, plans, summaries
- Fields: phase, name, tech-stack, decisions, metrics, etc.
- Parsing: Custom frontmatter extractor in `gsd-tools.cjs`

**JSON Configuration:**
- `.planning/config.json` - Project-level GSD configuration
- Tool availability tracking: Stores Brave API availability, feature flags
- State storage: Serialized project state for workflow continuity

## Environment Variables

**Required (for optional features):**
- `BRAVE_API_KEY` - Brave Search API key (optional, feature degrades gracefully if not set)

**Optional (runtime selection):**
- `CLAUDE_CONFIG_DIR` - Override Claude Code config location
- `GEMINI_CONFIG_DIR` - Override Gemini CLI config location
- `OPENCODE_CONFIG_DIR` - Override OpenCode config location
- `OPENCODE_CONFIG` - Specific OpenCode config file path
- `XDG_CONFIG_HOME` - XDG Base Directory (used by OpenCode)
- `HOME` - User home directory (used for path resolution)

## External Tool Integration

**Runtime Tool Mapping:**
GSD adapts Claude Code tools for target runtimes:

Claude Code → OpenCode:
- AskUserQuestion → question
- SlashCommand → skill
- TodoWrite → todowrite
- WebFetch → webfetch
- WebSearch → websearch (plugin/MCP)
- All others: Convert to lowercase

Claude Code → Gemini CLI:
- Read → read_file
- Write → write_file
- Edit → replace
- Bash → run_shell_command
- Glob → glob
- Grep → search_file_content
- WebSearch → google_web_search
- WebFetch → web_fetch
- TodoWrite → write_todos
- AskUserQuestion → ask_user

## No Direct Database Integration

**Note:** GSD itself does not integrate with databases. It operates as a meta-prompting system and command orchestrator. User projects that GSD manages may use databases (documented in generated INTEGRATIONS.md for those projects).

---

*Integration audit: 2026-02-17*
