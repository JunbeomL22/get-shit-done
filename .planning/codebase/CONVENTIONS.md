# Coding Conventions

**Analysis Date:** 2026-02-28

## Naming Patterns

**Files:**
- Kebab-case for filenames: `gsd-tools.cjs`, `gsd-statusline.js`, `gsd-check-update.js`
- Test files use `.test.cjs` suffix: `gsd-tools.test.cjs`
- Commands and executables use leading `gsd-` prefix
- No file extension for some utilities or use explicit `.js`, `.cjs` for Node.js CommonJS modules

**Functions:**
- camelCase for all function declarations: `parseIncludeFlag`, `safeReadFile`, `loadConfig`, `createTempProject`, `cleanup`
- Command functions use `cmd` prefix followed by PascalCase action: `cmdGenerateSlug`, `cmdCurrentTimestamp`, `cmdListTodos`, `cmdHistoryDigest`, `cmdStateLoad`, `cmdFindPhase`
- Helper functions use descriptive verbs: `execGit`, `normalizePhaseName`, `extractFrontmatter`, `reconstructFrontmatter`, `spliceFrontmatter`, `parseMustHavesBlock`

**Variables:**
- camelCase: `tmpDir`, `selectedRuntimes`, `cacheFile`, `projectVersionFile`, `globalVersionFile`, `phaseDir`
- Plural form for arrays/collections: `HOOKS_TO_COPY`, `files`, `decisions`, `phases`, `patterns`
- Constants use UPPER_SNAKE_CASE: `TOOLS_PATH`, `HOOKS_DIR`, `DIST_DIR`, `VERSION_FILE`
- Descriptive names: `result.success`, `digest.phases`, `cache.update_available`, `config.commit_docs`

**Types:**
- No TypeScript in main codebase (pure Node.js/CommonJS)
- Object properties use snake_case in JSON structures: `success`, `error`, `update_available`, `phase_dir`, `patterns_established`, `key_decisions`, `dependency_graph`
- Nested objects flatten nested names with underscores: `tech_stack`, `patterns_established`, `key_decisions`, `dependency_graph`

## Code Style

**Formatting:**
- No automated formatter configured (Prettier/ESLint not in dependencies)
- Manual formatting conventions observed:
  - 2-space indentation (seen in all test and hook files)
  - Opening braces on same line: `function name() {`, `describe('name', () => {`
  - Semicolons used consistently throughout

**Linting:**
- No linting configuration detected (no `.eslintrc`, `eslint.config.js`, or `biome.json`)
- Manual quality checks through testing

**Command Separation:**
- Section headers use comment line separators for visual organization:
  ```javascript
  // ─── Helpers ──────────────────────────────────────────────────────────────────
  // ─── Commands ─────────────────────────────────────────────────────────────────
  // ─── State Progression Engine ────────────────────────────────────────────────
  ```

## Import Organization

**Order:**
1. Built-in Node.js modules first: `require('fs')`, `require('path')`, `require('os')`, `require('readline')`, `require('crypto')`, `require('https')`, `require('child_process')`
2. Local modules/files next: `require('../package.json')`, `require('node:test')`
3. Destructuring used: `const { test, describe, beforeEach, afterEach } = require('node:test')`

**Path Aliases:**
- Direct relative paths used: `'../package.json'`, `'../..'`
- No path alias configuration

**require() vs import:**
- CommonJS `require()` exclusively (codebase is Node.js, not ES modules)
- Example: `const fs = require('fs');`

## Error Handling

**Patterns:**

Two main error handling functions used throughout:

1. **Critical Errors (early exit):**
   ```javascript
   function error(message) {
     process.stderr.write('Error: ' + message + '\n');
     process.exit(1);
   }
   ```
   Used for validation failures, missing required args: `error('text required for slug generation')`

2. **Graceful Failures (try-catch):**
   ```javascript
   function safeReadFile(filePath) {
     try {
       return fs.readFileSync(filePath, 'utf-8');
     } catch {
       return null;
     }
   }
   ```
   Used for file I/O, JSON parsing, filesystem operations

3. **Execution Error Wrapping (process spawning):**
   ```javascript
   try {
     const result = execSync(`node "${TOOLS_PATH}" ${args}`, {...});
     return { success: true, output: result.trim() };
   } catch (err) {
     return {
       success: false,
       output: err.stdout?.toString().trim() || '',
       error: err.stderr?.toString().trim() || err.message,
     };
   }
   ```

**Patterns for CLI Commands:**
- Validation comes first: check args, check file existence, check required fields
- Return early on validation failure via `error()` function
- Large JSON payloads (>50KB) written to temp files with `@file:` prefix instead of stdout

**Patterns for Tests:**
- Silent failures in hooks (statusline, update-check) use try-catch without logging
- Test assertions use template strings for error messages: `` assert.ok(result.success, `Command failed: ${result.error}`) ``

## Logging

**Framework:** console/process.stderr/process.stdout (built-in)

**Patterns:**
- `process.stdout.write()` for output (no trailing newlines unless needed)
- `process.stderr.write()` for errors with format: `'Error: ' + message + '\n'`
- Status hooks print directly to stdout with ANSI color codes
- No log levels (debug, info, warn, error) - all output is either success or error
- JSON output via `JSON.stringify(result, null, 2)` with 2-space indentation
- Large JSON outputs (>50KB) written to temp files to avoid bash buffer overflow

**Usage Examples:**
```javascript
// Success output
process.stdout.write(json);

// Error output
process.stderr.write('Error: ' + message + '\n');

// Status output with colors
process.stdout.write(`${gsdUpdate}\x1b[2m${model}\x1b[0m │ ...`);
```

## Comments

**When to Comment:**
- Section headers use visual separator lines (dashes and spaces) for code organization
- Inline comments explain non-obvious logic, especially in calculation or parsing
- Comments above functions explain purpose when not obvious from name
- Historical/context comments included for workarounds and compatibility notes

**Examples:**
```javascript
// Large payloads exceed Claude Code's Bash tool buffer (~50KB).
// Write to tmpfile and output the path prefixed with @file: so callers can detect it.

// Create temp directory structure
function createTempProject() { ... }

// Check project directory first (local install), then global
```

**JSDoc/TSDoc:**
- Not used in this codebase
- Comments are inline, not formal doc blocks

## Function Design

**Size:**
- Range from ~5 lines (helpers) to ~200+ lines (main CLI command routers)
- Command functions (`cmdX`) typically 30-80 lines
- Complex parsing functions like `extractFrontmatter` are 60-70 lines

**Parameters:**
- Most command functions take 2-3 parameters: `(cwd, argument, raw)`
- `cwd` represents working directory (for running in test environments or subprocesses)
- `raw` boolean flag indicates raw output format (string) vs JSON
- Optional parameters passed as flags in string args, parsed by function

**Return Values:**
- Command functions call `output()` or `error()` rather than returning
- Helper functions return values: strings, objects, null, or booleans
- No null coalescing; explicit null checks with pattern: `value || default`

## Module Design

**Exports:**
- Single large file with multiple commands: `gsd-tools.cjs` (5243 lines)
- No ES6 exports - pure Node.js module pattern
- Main routing happens at end of file via CLI argument parsing

**Barrel Files:**
- Not used; single monolithic file structure
- Templates and references in separate directories but not re-exported

**Module Boundaries:**
- `/get-shit-done/bin/` - Core CLI tools (`gsd-tools.cjs`, `gsd-tools.test.cjs`)
- `/bin/` - Installation/setup (`install.js`)
- `/hooks/` - Editor integration hooks (statusline, update-check)
- `/scripts/` - Build scripts (`build-hooks.js`)
- `/agents/` - Agent templates (markdown files)
- `/commands/` - Command definitions (YAML/markdown)

## Example Code Pattern

From `gsd-tools.cjs`, showing typical patterns:

```javascript
// Input validation pattern
function cmdGenerateSlug(text, raw) {
  if (!text) {
    error('text required for slug generation');
  }

  const slug = text
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/^-+|-+$/g, '');

  const result = { slug };
  output(result, raw, slug);
}

// Config loading with defaults
function loadConfig(cwd) {
  const configPath = path.join(cwd, '.planning', 'config.json');
  const defaults = {
    model_profile: 'balanced',
    commit_docs: true,
    // ... more defaults
  };

  try {
    const raw = fs.readFileSync(configPath, 'utf-8');
    const parsed = JSON.parse(raw);
    return parsed;
  } catch {
    return defaults;
  }
}
```

---

*Convention analysis: 2026-02-28*
