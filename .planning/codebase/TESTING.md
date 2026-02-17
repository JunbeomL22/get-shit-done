# Testing Patterns

**Analysis Date:** 2026-02-17

## Test Framework

**Runner:**
- Node.js built-in test runner (`node:test`)
- Version: Node 18+ (supports `node:test` module)
- Config: `package.json` scripts entry

**Assertion Library:**
- Node.js built-in `node:assert` with strict assertions
- Uses `assert.ok()`, `assert.deepStrictEqual()`, `assert.strictEqual()`
- Assertion messages included for test failures: `assert.ok(result.success, \`Command failed: ${result.error}\`)`

**Run Commands:**
```bash
npm test                        # Run all tests (runs gsd-tools.test.cjs)
node --test get-shit-done/bin/gsd-tools.test.cjs  # Direct test runner
```

## Test File Organization

**Location:**
- Co-located with source code being tested
- `get-shit-done/bin/gsd-tools.test.cjs` tests `get-shit-done/bin/gsd-tools.cjs`

**Naming:**
- `.test.cjs` suffix: `gsd-tools.test.cjs`
- Uses CommonJS format (`.cjs`) matching source module format

**Structure:**
```
get-shit-done/bin/
├── gsd-tools.cjs           # Implementation
└── gsd-tools.test.cjs       # Tests
```

## Test Structure

**Suite Organization:**
```javascript
const { test, describe, beforeEach, afterEach } = require('node:test');
const assert = require('node:assert');

describe('history-digest command', () => {
  let tmpDir;

  beforeEach(() => {
    tmpDir = createTempProject();
  });

  afterEach(() => {
    cleanup(tmpDir);
  });

  test('empty phases directory returns valid schema', () => {
    const result = runGsdTools('history-digest', tmpDir);
    assert.ok(result.success, `Command failed: ${result.error}`);
    assert.deepStrictEqual(digest.phases, {}, 'phases should be empty object');
  });

  test('nested frontmatter fields extracted correctly', () => {
    // ... test implementation
  });
});
```

**Patterns:**
- `describe()` blocks organize related test groups by command/feature
- `beforeEach()` creates fresh test environment (temp directories)
- `afterEach()` cleans up resources (removes temp directories)
- `test()` defines individual test cases with descriptive names
- Assertions include failure messages: `assert.deepStrictEqual(result, expected, 'message')`

## Mocking

**Framework:** Manual test fixtures
- No external mocking library (jest/sinon)
- Mocking done through test helper functions

**Patterns:**
```javascript
// Helper to run commands in isolation
function runGsdTools(args, cwd = process.cwd()) {
  try {
    const result = execSync(`node "${TOOLS_PATH}" ${args}`, {
      cwd,
      encoding: 'utf-8',
      stdio: ['pipe', 'pipe', 'pipe'],
    });
    return { success: true, output: result.trim() };
  } catch (err) {
    return {
      success: false,
      output: err.stdout?.toString().trim() || '',
      error: err.stderr?.toString().trim() || err.message,
    };
  }
}

// Fixture helper to create temp test environment
function createTempProject() {
  const tmpDir = fs.mkdtempSync(path.join(require('os').tmpdir(), 'gsd-test-'));
  fs.mkdirSync(path.join(tmpDir, '.planning', 'phases'), { recursive: true });
  return tmpDir;
}

function cleanup(tmpDir) {
  fs.rmSync(tmpDir, { recursive: true, force: true });
}
```

**What to Mock:**
- Temporary file systems: Use `fs.mkdtempSync()` to create isolated test directories
- Command execution: Wrap `execSync()` calls to capture output and errors

**What NOT to Mock:**
- Core Node.js modules (fs, path, os)
- Actual command-line tool execution (test real CLI behavior)
- File system operations (write actual test files to temp directories)

## Fixtures and Factories

**Test Data:**
```javascript
// Create test project with specific structure
function createTempProject() {
  const tmpDir = fs.mkdtempSync(path.join(require('os').tmpdir(), 'gsd-test-'));
  fs.mkdirSync(path.join(tmpDir, '.planning', 'phases'), { recursive: true });
  return tmpDir;
}

// Create phase-specific test data
const phaseDir = path.join(tmpDir, '.planning', 'phases', '01-foundation');
fs.mkdirSync(phaseDir, { recursive: true });

// Write test markdown files with frontmatter
const summaryContent = `---
phase: "01"
name: "Foundation Setup"
provides:
  - "Database schema"
  - "Auth system"
---

# Summary content here
`;
fs.writeFileSync(path.join(phaseDir, '01-01-SUMMARY.md'), summaryContent);
```

**Location:**
- Test fixtures created inline within test functions
- Temporary directories created with `fs.mkdtempSync()` in `beforeEach()`
- Cleaned up with `fs.rmSync()` in `afterEach()`

## Coverage

**Requirements:** No coverage target enforced
- Coverage measurement not implemented
- No coverage threshold in package.json or CI

**View Coverage:**
- Manual coverage evaluation through test execution
- Coverage would be computed by running: `npm test` and observing test output

## Test Types

**Unit Tests:**
- Scope: Individual command handlers and utility functions
- Approach: Create minimal fixtures, execute command, verify output
- Example: `history-digest command` suite tests command parsing and JSON extraction

**Integration Tests:**
- Scope: Full command execution through CLI with file system interaction
- Approach: Create temporary project structure, run actual tool command via `execSync()`, parse and verify results
- Example: Phase directory detection, markdown file parsing, output formatting

**E2E Tests:**
- Status: Not implemented
- Would require: Full GSD workflow testing with actual Claude Code integration

## Common Patterns

**Async Testing:**
- Not used (no async/await in test suite)
- All tests are synchronous
- File operations use synchronous methods: `fs.readFileSync()`, `execSync()`

**Error Testing:**
```javascript
test('returns error if base phase does not exist', () => {
  const result = runGsdTools('phase next-decimal 99', tmpDir);
  assert.strictEqual(result.success, false, 'Should fail for non-existent phase');
  assert.match(result.error, /does not exist/, 'Error should mention missing phase');
});

test('malformed SUMMARY.md skipped gracefully', () => {
  // Write invalid markdown without frontmatter
  fs.writeFileSync(
    path.join(phaseDir, '01-02-SUMMARY.md'),
    `# Just a heading\nNo frontmatter here\n`
  );

  // Command should still succeed and skip invalid file
  const result = runGsdTools('history-digest', tmpDir);
  assert.ok(result.success, `Command should succeed despite malformed files: ${result.error}`);
});
```

**State Verification:**
```javascript
// Verify extracted data structure
test('nested frontmatter fields extracted correctly', () => {
  // ... setup test data ...

  const digest = JSON.parse(result.output);

  // Verify nested object structure
  assert.ok(digest.phases['01'], 'Phase 01 should exist');
  assert.deepStrictEqual(
    digest.phases['01'].provides.sort(),
    ['Auth system', 'Database schema'],
    'provides should contain nested values'
  );

  // Verify arrays
  assert.strictEqual(digest.decisions.length, 2, 'Should have 2 decisions');
  assert.ok(
    digest.decisions.some(d => d.decision === 'Use Prisma over Drizzle'),
    'Should contain first decision'
  );
});

// Verify backward compatibility
test('flat provides field still works (backward compatibility)', () => {
  // Test that old field format is still supported
  const summaryContent = `---
phase: "01"
provides:
  - "Database"
patterns-established:
  - "Pattern A"
---`;

  fs.writeFileSync(path.join(phaseDir, '01-01-SUMMARY.md'), summaryContent);

  const result = runGsdTools('history-digest', tmpDir);
  const digest = JSON.parse(result.output);

  assert.deepStrictEqual(
    digest.phases['01'].provides,
    ['Database'],
    'Old flat format should still work'
  );
});
```

## Test Execution Details

**Running Tests:**
```bash
# From project root
npm test

# Direct execution
node --test get-shit-done/bin/gsd-tools.test.cjs

# Specific test suite (requires node:test filtering)
# Currently all tests in single file must run together
```

**Test Output:**
- TAP format (Test Anything Protocol) by default
- Shows test name, result (✓/✗), and assertion messages
- Summary: "X tests, Y passed, Z failed"

**Exit Codes:**
- 0 when all tests pass
- 1 when any test fails
- Integrated with CI/CD via standard npm test convention

## Known Test Coverage

**Covered Commands:**
- `history-digest` - Full coverage with multiple scenarios
- `phases list` - Full coverage with filtering and sorting
- `roadmap get-phase` - Full coverage with edge cases
- `phase next-decimal` - Full coverage with decimal phase handling
- `phase-plan-index` - Partial coverage

**Covered Areas:**
- Frontmatter parsing (nested objects, flat arrays, inline syntax)
- File system operations (directory creation, file writing, cleanup)
- Command error handling (missing files, malformed input)
- Backward compatibility (old field formats)
- Data aggregation (merging multiple phases)

**Gaps:**
- No tests for git operations (commit, branch)
- No tests for interactive CLI (prompts, user input)
- No tests for hooks (statusline, update check)
- No tests for installation/uninstallation logic
- No tests for command execution timeout/performance

---

*Testing analysis: 2026-02-17*
