# Technology Stack

**Analysis Date:** 2026-02-28

## Languages

**Primary:**
- JavaScript (Node.js) - Runtime for CLI tools, build system, and hook scripts
- CommonJS/ES Modules - Entry points and utilities use both module formats

**Documentation:**
- Markdown - All user guides, workflows, and planning documents
- YAML - Configuration format for tool definitions (Claude Code, OpenCode, Gemini)

## Runtime

**Environment:**
- Node.js >= 16.7.0
- Available versions in test: v22.22.0

**Package Manager:**
- npm >= 6.x
- Lockfile: `package-lock.json` (present)

## Frameworks

**Core:**
- Node.js built-in modules - fs, path, os, readline, crypto, https, child_process
  - No external framework dependencies in main tools
  - Designed for maximum portability and minimal dependency weight

**Build/Dev:**
- esbuild ^0.24.0 - Build system for bundling hooks and tools
  - Configured in `scripts/build-hooks.js`
  - Produces CommonJS output in `hooks/dist/`

**Testing:**
- Node.js built-in test runner (`node --test`)
  - Uses `get-shit-done/bin/gsd-tools.test.cjs` for CLI tool testing

## Key Dependencies

**Production:**
- Zero runtime production dependencies (fully self-contained)
  - All standard library dependencies are Node.js builtins

**Development:**
- esbuild ^0.24.0 - Bundling for hook distribution

## Configuration

**Environment:**
- `BRAVE_API_KEY` - Optional API key for Brave Search integration
  - If not set, fallback to runtime built-in web search
  - Can also be stored in `~/.gsd/brave_api_key`
- `CLAUDE_CONFIG_DIR` - Override Claude Code config directory (default: `~/.claude`)
- `OPENCODE_CONFIG_DIR` / `OPENCODE_CONFIG` - Override OpenCode config directory
  - Respects XDG Base Directory spec: `$XDG_CONFIG_HOME/opencode` or `~/.config/opencode`
- `GEMINI_CONFIG_DIR` - Override Gemini CLI config directory (default: `~/.gemini`)

**Build:**
- `scripts/build-hooks.js` - Copies hooks from `hooks/` to `hooks/dist/` for distribution
- `package.json` - Defines `build:hooks` script run on `prepublishOnly`

**Installation Configuration:**
- `.claude/settings.json` - Per-project Claude Code tool and permission configuration
- `.config/opencode/` - OpenCode global configuration (XDG-compliant)
- `.gemini/` - Gemini CLI global configuration

## Platform Requirements

**Development:**
- Node.js >= 16.7.0
- npm >= 6.x
- Git (for version control operations)
- jq (optional, for JSON parsing in workflows - auto-installed on first use)

**Production:**
- Node.js >= 16.7.0
- Supported on: macOS, Windows, Linux
- No OS-specific dependencies; uses Node.js abstraction layer

**Installation Targets:**
- **Claude Code:** Global `~/.claude/` or local `./.claude/`
- **OpenCode:** Global `~/.config/opencode/` (XDG-compliant) or local `./.opencode/`
- **Gemini CLI:** Global `~/.gemini/` or local `./.gemini/`

## Distribution

**Package:**
- Package name: `get-shit-done-cc`
- Version: 1.20.3
- Published to npm
- Entry point: `bin/install.js` - Interactive installer with multiple runtime support
- Files included: `bin/`, `commands/`, `get-shit-done/`, `agents/`, `hooks/dist/`, `scripts/`

**Installation Methods:**
```bash
npx get-shit-done-cc@latest                    # Interactive install
npx get-shit-done-cc --claude --global         # Non-interactive: Claude, global
npx get-shit-done-cc --opencode --global       # Non-interactive: OpenCode, global
npx get-shit-done-cc --gemini --global         # Non-interactive: Gemini, global
npx get-shit-done-cc --all --global            # Non-interactive: all runtimes
```

## External Integrations

**Package Registry:**
- npm registry - For version checking via `npm view get-shit-done-cc version`

**Network Calls:**
- GitHub releases API - Download jq binary: `https://github.com/jqlang/jq/releases/download/`
- npm - Version checking for updates

**Brave Search API:**
- Optional integration at `https://api.search.brave.com/res/v1/web/search`
- Requires `BRAVE_API_KEY` environment variable
- Fallback to runtime built-in web search if not available

---

*Stack analysis: 2026-02-28*
