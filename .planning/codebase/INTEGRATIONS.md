# External Integrations

**Analysis Date:** 2026-02-28

## APIs & External Services

**Web Search:**
- Brave Search API - Optional web search integration for research phase
  - SDK/Client: Native fetch using Node.js https module
  - Auth: Environment variable `BRAVE_API_KEY` or file `~/.gsd/brave_api_key`
  - Endpoint: `https://api.search.brave.com/res/v1/web/search`
  - Response: Web search results with title, URL, description, and age
  - Fallback: If not configured, agents use runtime built-in WebSearch tool (Claude Code, Gemini, OpenCode)
  - Location: `get-shit-done/bin/gsd-tools.cjs` - `cmdWebsearch()` function

**Version Management:**
- npm registry - Check installed vs latest version
  - Command: `npm view get-shit-done-cc version`
  - Async background check run by SessionStart hook
  - Cache file: `~/.claude/cache/gsd-update-check.json` (or equivalent for other runtimes)
  - Location: `hooks/gsd-check-update.js` - Background version check hook

**Download/Package Distribution:**
- GitHub Releases - jq binary distribution
  - Endpoint: `https://github.com/jqlang/jq/releases/download/jq-1.7.1`
  - Used for: Optional JSON parsing tool (auto-installed if missing)
  - Platform-aware: Downloads appropriate binary for OS

## Data Storage

**Databases:**
- None - Pure file-based workflow system

**File Storage:**
- Local filesystem only - All state stored in project directories
  - `.planning/` - Project planning files (config, state, roadmap, phases)
  - `~/.claude/`, `~/.config/opencode/`, `~/.gemini/` - Runtime-specific config
  - `~/.gsd/` - Global GSD state directory (brave_api_key, defaults.json, update cache)

**Caching:**
- None - No persistent cache databases
- Transient caches: Update check cache, statusline cache (in-memory or temporary files)

## Authentication & Identity

**Auth Provider:**
- None - No user authentication system
- API-based:
  - Brave Search: API key (bearer token) via `X-Subscription-Token` header
  - No OAuth, no login, no user sessions

**Configuration:**
- Per-user directories: `~/.claude/`, `~/.config/opencode/`, `~/.gemini/`
- Per-project override: `./.claude/`, `./.opencode/`, `./.gemini/`
- Settings stored in `settings.json` (runtime-native format)

## Monitoring & Observability

**Error Tracking:**
- None - No external error tracking service

**Logs:**
- Console output only - STDOUT for normal operation, STDERR for errors
- Color-coded terminal output using ANSI escape sequences
- No log aggregation or remote logging

**Status/Health:**
- Hook-based: `gsd-statusline.js` - Optional statusline display in supported editors
- Configuration: Via runtime `settings.json` for hook customization

## CI/CD & Deployment

**Hosting:**
- npm public registry - Package hosting
- GitHub - Source code repository and releases

**CI Pipeline:**
- GitHub Actions - Workflow files in `.github/workflows/` (detected but not analyzed)
- No automated testing in default package.json - Manual testing via `npm test`

**Distribution:**
- Published as npm package: `get-shit-done-cc`
- Installation: `npx get-shit-done-cc` or `npm install -g get-shit-done-cc`

## Environment Configuration

**Required env vars:**
- None - Everything is optional or has sensible defaults

**Optional env vars:**
- `BRAVE_API_KEY` - Brave Search API key for enhanced web search
- `CLAUDE_CONFIG_DIR` - Override Claude Code config directory
- `OPENCODE_CONFIG_DIR` / `OPENCODE_CONFIG` - Override OpenCode config directory
- `GEMINI_CONFIG_DIR` - Override Gemini CLI config directory
- `XDG_CONFIG_HOME` - XDG Base Directory for OpenCode (respects standard)
- `HOME` - User home directory (for path resolution in workflows)

**Secrets location:**
- `.env` - Not used; API keys stored as:
  - Environment variables (preferred for sensitive data)
  - `~/.gsd/brave_api_key` - File-based fallback for Brave API key
  - Runtime-specific config dirs with restricted permissions

## Webhooks & Callbacks

**Incoming:**
- None - Pure CLI-based system, no webhook endpoints

**Outgoing:**
- git commit hooks - Installed by GSD to:
  - Auto-commit planning documents during workflows
  - Hook scripts: `hooks/gsd-statusline.js`, `hooks/gsd-check-update.js`
  - Location: Installed into runtime's hook directory

## System Integration

**Version Control:**
- Git integration via Node.js `child_process.execSync()`
  - Commands: `git commit`, `git status`, `git log`, `git diff`, `git add`, `git tag`
  - Location: `get-shit-done/bin/gsd-tools.cjs` - `cmdCommit()`, phase operations
  - No git library dependency; uses native CLI

**Terminal/Editor:**
- Claude Code - Native terminal integration
- OpenCode - Via XDG-compliant config
- Gemini CLI - Via CLI integration
- Hook system for statusline display (editor-specific)

**Process Management:**
- Child process spawning for:
  - jq installation checks and execution
  - npm version checks (background process)
  - git operations
- Process detachment on Windows for background hooks

---

*Integration audit: 2026-02-28*
