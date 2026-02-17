# Coding Conventions

**Analysis Date:** 2026-02-17

## Naming Patterns

**Files:**
- Kebab-case for CLI scripts and tools: `gsd-statusline.js`, `gsd-check-update.js`, `gsd-tools.cjs`
- Camel case for hook scripts: `build-hooks.js`
- Test files use `.test.cjs` or `.spec.cjs` suffix: `gsd-tools.test.cjs`

**Functions:**
- camelCase for function names: `getGlobalDir()`, `parseIncludeFlag()`, `safeReadFile()`
- camelCase for arrow functions assigned to constants: `const expanded = expandTilde(path)`
- Prefix helper functions with `cmd` for CLI commands: `cmdGenerateSlug()`, `cmdStateLoad()`, `cmdHistoryDigest()`
- Prefix validation functions with `verify` or `validate`: `verifyInstalled()`, `verifyPathExists()`, `validateConsistency()`

**Constants:**
- SCREAMING_SNAKE_CASE for config constants: `TOOLS_PATH`, `DIST_DIR`, `HOOKS_TO_COPY`, `MODEL_PROFILES`, `PATCHES_DIR_NAME`, `MANIFEST_NAME`
- camelCase for runtime/option flags: `hasGlobal`, `hasLocal`, `hasClaude`, `selectedRuntimes`, `explicitConfigDir`
- camelCase for color/style constants: `cyan`, `green`, `yellow`, `dim`, `reset`
- camelCase for object constants with metadata: `colorNameToHex`, `claudeToOpencodeTools`, `claudeToGeminiTools`

**Variables:**
- camelCase for all variables: `tmpDir`, `phaseDir`, `settingsPath`, `configDir`
- Prefix boolean checks with `has`, `is`, or `should`: `hasExisting`, `isOpencode`, `isGlobal`, `shouldInstallStatusline`
- Plural names for collections: `args`, `results`, `entries`, `orphanedFiles`, `allowedTools`, `tools`

**Types/Objects:**
- Object keys use kebab-case in config/metadata: `"model_profile"`, `"commit_docs"`, `"search_gitignored"`, `"phase-number"`, `"key-decisions"`
- Object keys use camelCase in runtime objects: `modelProfile`, `commitDocs`, `searchGitignored`

## Code Style

**Formatting:**
- No automated formatter (no .prettierrc or eslint config detected)
- 2-space indentation standard
- Lines use natural length (no fixed line limit observed, though most lines stay under 100 chars)
- Curly braces on same line: `function name() {`
- Ternary operators aligned horizontally for readability: `const value = condition ? trueValue : falseValue`

**Linting:**
- No ESLint or Prettier configuration file present
- Code style enforced by convention and manual review
- Node.js built-in modules preferred: `require('node:test')`, `require('node:assert')`

## Import Organization

**Order:**
1. Node.js built-in modules: `require('fs')`, `require('path')`, `require('os')`, `require('child_process')`
2. Local modules relative imports: `const TOOLS_PATH = path.join(__dirname, 'gsd-tools.cjs')`
3. Constants and metadata: Color codes, mappings, configuration tables
4. Helper function definitions
5. Main logic

**Path Aliases:**
- No path aliases used
- Relative paths with `path.join(__dirname, ...)` for module discovery
- Environment variable expansion: `process.cwd()`, `os.homedir()`, `process.env.CLAUDE_CONFIG_DIR`

**Examples:**
```javascript
const fs = require('fs');
const path = require('path');
const os = require('os');
const { execSync } = require('child_process');

const TOOLS_PATH = path.join(__dirname, 'gsd-tools.cjs');
```

## Error Handling

**Patterns:**
- Try-catch blocks with silent failure for non-critical operations:
  ```javascript
  try {
    return JSON.parse(fs.readFileSync(settingsPath, 'utf8'));
  } catch {
    return {};
  }
  ```
- Graceful degradation: Missing files return empty objects, missing directories are created on demand
- Process exit on critical failures: `process.exit(1)` for unrecoverable errors like conflicting CLI flags
- Error message prefixes with context: `${yellow}⚠${reset}`, `${yellow}✗${reset}`, `${green}✓${reset}`
- Comprehensive error checking in file operations: `fs.existsSync()` checks before reading, creating directories recursively with `{ recursive: true }`

**Error Messages:**
```javascript
// User-facing errors with color codes
console.error(`  ${yellow}Cannot specify both --global and --local${reset}`);
// Silent failures for convenience
try { const config = JSON.parse(content); } catch {}
// Command validation with helpful context
if (!nextArg || nextArg.startsWith('-')) {
  console.error(`  ${yellow}--config-dir requires a path argument${reset}`);
  process.exit(1);
}
```

## Logging

**Framework:** Native `console` object
- `console.log()` for output and user feedback
- `console.error()` for error messages
- No external logging libraries

**Patterns:**
- Status updates prefixed with symbol + color: `console.log(\`  ${green}✓${reset} Installed agents\`)`
- Progress indicators: `${yellow}⚠${reset}` for warnings, `${green}✓${reset}` for success, `${cyan}►${reset}` for info
- Colored text for emphasis: cyan for commands/paths, green for success, yellow for warnings
- Dim text for secondary information: `${dim}example${reset}` for optional values or examples
- Multi-line messages with consistent indentation (2 spaces after status symbol)
- Silent failures in utility functions to prevent output pollution: catch blocks without logging

**Output in statusline hook** (gsd-statusline.js):
```javascript
// Silent failures to avoid breaking statusline rendering
try {
  const data = JSON.parse(input);
  // ... process data ...
} catch (e) {
  // Silent fail - don't break statusline on parse errors
}
```

## Comments

**When to Comment:**
- Complex logic that needs explanation: mapping between tool name formats (Claude → OpenCode → Gemini)
- Non-obvious design decisions: "// Shell doesn't expand ~ in env vars passed to node"
- Critical sections with multiple steps: file modification detection, JSONC parsing
- Algorithm explanations: manifest generation, frontmatter extraction

**JSDoc/TSDoc:**
- Used for public functions and command handlers
- Parameter types documented: `@param {string} runtime`, `@param {boolean} isGlobal`
- Return types documented: `@returns {string}`, `@returns {null|undefined|string}`
- Purpose and usage documented for complex utility functions

**Examples:**
```javascript
/**
 * Get the config directory path relative to home directory for a runtime
 * Used for templating hooks that use path.join(homeDir, '<configDir>', ...)
 * @param {string} runtime - 'claude', 'opencode', or 'gemini'
 * @param {boolean} isGlobal - Whether this is a global install
 */
function getConfigDirFromHome(runtime, isGlobal) {
  // ...
}

/**
 * Process Co-Authored-By lines based on attribution setting
 * @param {string} content - File content to process
 * @param {null|undefined|string} attribution - null=remove, undefined=keep, string=replace
 * @returns {string} Processed content
 */
function processAttribution(content, attribution) {
  // ...
}
```

## Function Design

**Size:**
- Small focused functions preferred (most helpers are 5-20 lines)
- Utility functions extracted for reuse across multiple command handlers
- Complex operations broken into helpers with clear names

**Parameters:**
- Minimal parameters (1-3 typical, max 4-5 for complex operations)
- Related parameters grouped logically: `install(isGlobal, runtime)`
- Optional parameters positioned last with default values: `function safeReadFile(filePath, defaultValue = null)`
- Destructuring for config objects: `{ recursive: true }` for fs options
- Rest parameters for variable-length collections: `const escapeShell = args.map(...)`

**Return Values:**
- Consistent return types: functions return objects/arrays for data, undefined for side effects
- Explicit null for missing values: `return null` rather than implicit undefined
- Error objects included in success/error tuples: `{ success: true/false, output, error }`
- Chainable returns where appropriate: File operations return modified content for piping

**Examples:**
```javascript
// Concise utility with clear purpose
function parseIncludeFlag(args) {
  const includeIndex = args.indexOf('--include');
  if (includeIndex === -1) return new Set();
  const includeValue = args[includeIndex + 1];
  if (!includeValue) return new Set();
  return new Set(includeValue.split(',').map(s => s.trim()));
}

// Returns object tuple for error handling
function runGsdTools(args, cwd = process.cwd()) {
  try {
    const result = execSync(`node "${TOOLS_PATH}" ${args}`, { cwd, encoding: 'utf-8' });
    return { success: true, output: result.trim() };
  } catch (err) {
    return { success: false, output: err.stdout?.toString().trim() || '', error: err.message };
  }
}
```

## Module Design

**Exports:**
- No explicit module.exports pattern (CommonJS implicit)
- Script files execute main logic at module level
- Utility functions defined before first use
- Test files import helpers at top: `const { test, describe, beforeEach, afterEach } = require('node:test')`

**Barrel Files:**
- Not used in this codebase
- Each command file is standalone (gsd-tools.cjs is the single command aggregator)

**Organization Pattern:**
- Single-responsibility files: `gsd-statusline.js` only handles statusline rendering
- Command-specific files contain all related logic: `install.js` handles all install variants
- Centralized utilities in `gsd-tools.cjs`: ~5200 lines containing all workflow commands

---

*Convention analysis: 2026-02-17*
