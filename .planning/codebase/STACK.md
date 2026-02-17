# Technology Stack

**Analysis Date:** 2026-02-17

## Languages

**Primary:**
- JavaScript (Node.js) - All application code, CLI tools, and runtime agents
- Markdown - Configuration templates, documentation, and workflow specifications

**Secondary:**
- YAML - Frontmatter in markdown documents for structured metadata

## Runtime

**Environment:**
- Node.js 16.7.0+ (specified in `package.json` engines field)
- Cross-platform: Mac, Windows (WSL2), Linux

**Package Manager:**
- npm (version unspecified, likely 8.x+)
- Lockfile: `package-lock.json` present

## Frameworks & Tools

**Core Runtime:**
- Node.js built-in modules: `fs`, `path`, `os`, `readline`, `crypto`, `child_process`
- No external runtime dependencies (empty `dependencies` object in `package.json`)

**Build/Development:**
- esbuild ^0.24.0 - Hook bundling (though currently hooks are copied unprocessed)
- Node.js built-in test runner - Tests use `node --test` (Node 18.0+)

**CLI & Installation:**
- Custom installer script (`bin/install.js`) - Handles setup for Claude Code, OpenCode, and Gemini CLI
- Hook system - Pre-built scripts copied to runtime config directories

**Testing:**
- Node.js native test framework (`node:test`)
- Assert library - Node.js native `node:assert`

## Key Dependencies

**Production:**
- None - Pure Node.js implementation

**Development:**
- esbuild ^0.24.0 - Build tool for hook bundling

## Configuration Files

**Project Configuration:**
- `package.json` - Package metadata and scripts
- `.gitignore` - Excludes node_modules, local test installs, build artifacts

**Build Configuration:**
- `scripts/build-hooks.js` - Hook deployment script
- Hook output: `hooks/dist/` directory (published to npm)

## Publishing & Distribution

**NPM Package:**
- Package name: `get-shit-done-cc`
- Current version: 1.20.3
- Registry: npm (npmjs.com)
- Published files: `bin/`, `commands/`, `get-shit-done/`, `agents/`, `hooks/dist/`, `scripts/`

**Installation Methods:**
- Global: `npx get-shit-done-cc@latest` - Installs to user config directories
- Local: `npx get-shit-done-cc --claude --local` - Installs to `./.claude/`
- Project: `git clone && node bin/install.js --claude --local`

## Platform Requirements

**Development:**
- Node.js 16.7.0 or later
- npm 8.x or later (inferred)
- Git (for version control integration)
- POSIX shell or Windows PowerShell (for hook integration)

**Production/User Systems:**
- Node.js 16.7.0+ (as runtime)
- One of: Claude Code, OpenCode, or Gemini CLI (target runtimes)
- Git repository (required for GSD workflows)

## System Architecture

**Modular Design:**
- `bin/install.js` - Main installer, handles 3 runtime targets (Claude, OpenCode, Gemini)
- `get-shit-done/bin/gsd-tools.cjs` - CLI utility centralizing workflow operations (187KB, 5244 lines)
- `agents/` - Markdown agent definitions (11 specialized agents)
- `commands/gsd/` - 31 workflow command definitions
- `hooks/` - Two background hook scripts (update check, statusline display)

**Installation Process:**
1. Detects target runtime (Claude Code, OpenCode, or Gemini)
2. Detects scope (global user config vs. project-local)
3. Creates directory structure in target config location
4. Installs hooks into runtime's hook system
5. Copies templates and workflows

---

*Stack analysis: 2026-02-17*
