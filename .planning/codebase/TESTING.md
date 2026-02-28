# Testing Patterns

**Analysis Date:** 2026-02-28

## Test Framework

**Runner:**
- Node.js built-in `test` module (Node 18+)
- No external test framework (Jest, Vitest, Mocha not used)
- Config: No config file needed - uses Node.js native testing

**Assertion Library:**
- Node.js built-in `assert` module (CommonJS)
- Imported as: `const assert = require('node:assert');`

**Run Commands:**
```bash
npm test                    # Run all tests (from package.json scripts)
node --test gsd-tools.test.js    # Run specific test file directly
```

**From package.json:**
```json
"test": "node --test get-shit-done/bin/gsd-tools.test.js"
```

## Test File Organization

**Location:**
- Co-located with source: test file in same directory as source
- `gsd-tools.cjs` and `gsd-tools.test.cjs` both in `/get-shit-done/bin/`

**Naming:**
- `.test.cjs` suffix for test files
- Source + test files share same base name: `gsd-tools.cjs` / `gsd-tools.test.cjs`

**Structure:**
```
/home/junbeom/Projects/fork/get-shit-done/
├── get-shit-done/bin/
│   ├── gsd-tools.cjs              # Main implementation (5243 lines)
│   └── gsd-tools.test.cjs         # Tests (2346 lines)
└── [other source files untested]
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
    // assertions follow
  });

  test('nested frontmatter fields extracted correctly', () => {
    // arrange: create test files
    // act: run command
    // assert: verify output
  });
});
```

**Patterns:**

1. **Setup/Teardown:**
   - `beforeEach()` creates isolated temp project directory
   - `afterEach()` cleans up temp directory with `fs.rmSync(tmpDir, { recursive: true, force: true })`
   - Prevents test pollution and file system clutter

2. **Helper Function Pattern:**
   ```javascript
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
   ```
   - Wraps spawned process execution
   - Returns structured object with `success`, `output`, `error` fields
   - Captures both stdout and stderr

3. **Test Data Creation:**
   ```javascript
   function createTempProject() {
     const tmpDir = fs.mkdtempSync(path.join(require('os').tmpdir(), 'gsd-test-'));
     fs.mkdirSync(path.join(tmpDir, '.planning', 'phases'), { recursive: true });
     return tmpDir;
   }
   ```
   - Creates minimal project structure in system temp directory
   - Creates `.planning/phases` directory that commands expect

4. **Assertion Pattern (Arrange-Act-Assert):**
   ```javascript
   test('nested frontmatter fields extracted correctly', () => {
     // Arrange: create test files and directories
     const phaseDir = path.join(tmpDir, '.planning', 'phases', '01-foundation');
     fs.mkdirSync(phaseDir, { recursive: true });
     fs.writeFileSync(path.join(phaseDir, '01-01-SUMMARY.md'), summaryContent);

     // Act: run the command
     const result = runGsdTools('history-digest', tmpDir);

     // Assert: verify output
     assert.ok(result.success, `Command failed: ${result.error}`);
     const digest = JSON.parse(result.output);
     assert.deepStrictEqual(digest.phases['01'].provides, ['Auth system', 'Database schema']);
   });
   ```

## Mocking

**Framework:** None - tests spawn actual processes

**Patterns:**
- No mock library (no sinon, jest.mock, etc.)
- Integration-style testing: actual CLI invocation via `execSync()`
- File system operations are real (temp directories used)
- JSON parsing/validation done on actual command output

**What to Mock:**
- Nothing currently mocked; tests are integration tests
- External processes are spawned as subprocesses

**What NOT to Mock:**
- File system operations (real directories created)
- Command execution (actual CLI invoked)
- JSON parsing (real output parsed)

## Fixtures and Factories

**Test Data:**

Factory function creates base project structure:
```javascript
function createTempProject() {
  const tmpDir = fs.mkdtempSync(path.join(require('os').tmpdir(), 'gsd-test-'));
  fs.mkdirSync(path.join(tmpDir, '.planning', 'phases'), { recursive: true });
  return tmpDir;
}
```

Inline test data creation for scenarios:
```javascript
const summaryContent = `---
phase: "01"
name: "Foundation Setup"
dependency-graph:
  provides:
    - "Database schema"
    - "Auth system"
  affects:
    - "API layer"
tech-stack:
  added:
    - "prisma"
    - "jose"
patterns-established:
  - "Repository pattern"
  - "JWT auth flow"
key-decisions:
  - "Use Prisma over Drizzle"
  - "JWT in httpOnly cookies"
---

# Summary content here
`;

fs.writeFileSync(path.join(phaseDir, '01-01-SUMMARY.md'), summaryContent);
```

**Location:**
- Inline in test functions (no separate fixture directory)
- String templates used for markdown/YAML content
- Temp directories created per test suite, destroyed after

**Multi-file Test Scenarios:**
Tests create multiple related files to test complex scenarios:
```javascript
test('multiple phases merged into single digest', () => {
  // Create phase 01
  const phase01Dir = path.join(tmpDir, '.planning', 'phases', '01-foundation');
  fs.mkdirSync(phase01Dir, { recursive: true });
  fs.writeFileSync(path.join(phase01Dir, '01-01-SUMMARY.md'), phase01Content);

  // Create phase 02
  const phase02Dir = path.join(tmpDir, '.planning', 'phases', '02-api');
  fs.mkdirSync(phase02Dir, { recursive: true });
  fs.writeFileSync(path.join(phase02Dir, '02-01-SUMMARY.md'), phase02Content);

  const result = runGsdTools('history-digest', tmpDir);
  assert.ok(result.success);
  // verify both phases are in output
});
```

## Coverage

**Requirements:** None enforced - no coverage configuration

**View Coverage:**
- Not configured
- No coverage.json or lcov reporting

**Current Status:**
- Main command tool (`gsd-tools.cjs`) has tests for:
  - `history-digest` command
  - `phases list` command
  - `roadmap get-phase` command
  - `phase next-decimal` command
  - `todo complete` command
  - `scaffold` command (context, UAT, verification, phase-dir)
- Other files (hooks, install, build) do not have tests

## Test Types

**Unit Tests:**
- Scope: Individual commands in isolation
- Approach: Command spawning via subprocess + assertion on output
- Examples:
  - `cmdGenerateSlug`: generates correct slug from input
  - `cmdCurrentTimestamp`: returns timestamp in correct format
  - `cmdListTodos`: counts pending todos

**Integration Tests:**
- Scope: Multi-step workflows, file system interactions
- Approach: Create project structure, run command, verify artifacts
- Examples:
  - `history-digest` with multiple phases - tests frontmatter parsing across files
  - `scaffold context/uat/verification` - tests file creation and content
  - `phase next-decimal` - tests phase numbering logic with existing phases

**E2E Tests:**
- Framework or pattern: Not used
- Full end-to-end workflows not tested

## Common Patterns

**Async Testing:**
- Node.js test module handles promises automatically
- Not currently used in tests (all sync operations with `execSync`)
- If needed, test functions can be async:
  ```javascript
  test('async example', async () => {
    // would use async/await
  });
  ```

**Error Testing:**

Pattern for testing command failures:
```javascript
test('fails for nonexistent todo', () => {
  const result = runGsdTools('todo complete nonexistent.md', tmpDir);
  assert.ok(!result.success, 'should fail');
  assert.ok(result.error.includes('not found'), 'error mentions not found');
});
```

Pattern for testing graceful degradation:
```javascript
test('malformed SUMMARY.md skipped gracefully', () => {
  // create valid phase
  fs.writeFileSync(path.join(phase01Dir, '01-01-SUMMARY.md'), validContent);
  // create malformed phase
  fs.writeFileSync(path.join(phase02Dir, '02-01-SUMMARY.md'), malformedContent);

  const result = runGsdTools('history-digest', tmpDir);
  // Should succeed despite malformed file
  assert.ok(result.success, `Command should succeed despite malformed files: ${result.error}`);
  // Verify valid phase was processed
  const digest = JSON.parse(result.output);
  assert.ok(digest.phases['01'], 'Phase 01 should exist');
});
```

**Assertion Pattern:**

Primary assertions used:
```javascript
assert.ok(value, message)                  // truthy check
assert.strictEqual(actual, expected, msg)  // === comparison
assert.deepStrictEqual(obj1, obj2, msg)    // recursive equality
assert.ok(predicate, `message with ${variable}`)  // template string messages
```

Example from tests:
```javascript
assert.strictEqual(digest.decisions.length, 2, 'Should have 2 decisions');
assert.deepStrictEqual(
  digest.phases['01'].provides.sort(),
  ['Auth system', 'Database schema'],
  'provides should contain nested values'
);
assert.ok(
  digest.decisions.some(d => d.decision === 'Use Prisma over Drizzle'),
  'Should contain first decision'
);
```

## Test Suite Organization

**By Command Type:**

Current test suites in `gsd-tools.test.cjs`:

1. **history-digest command** - 6 tests
   - Empty directory returns valid schema
   - Nested frontmatter field extraction
   - Multiple phases merged
   - Malformed SUMMARY.md handled gracefully
   - Backward compatibility with flat provides field
   - Inline array syntax support

2. **phases list command** - 4 tests
   - Empty directory returns empty array
   - Lists phase directories sorted numerically
   - Decimal phase sorting order
   - --type filter (plans, summaries)

3. **roadmap get-phase command** - 2 tests
   - Returns phase section with correct structure
   - Handles missing phases gracefully

4. **phase next-decimal command** - 3 tests
   - Calculates correct decimal for first decimal phase
   - Handles existing phases with gaps
   - Respects phase priority field

5. **todo complete command** - 2 tests
   - Completes todo with correct move operation
   - Fails for nonexistent todo

6. **scaffold command** - 5 tests
   - Scaffolds context file with correct structure
   - Scaffolds UAT file
   - Scaffolds verification file
   - Scaffolds phase directory
   - Does not overwrite existing files

## Running Tests

**Commands:**
```bash
# Run all tests
npm test

# Run with verbose output
node --test get-shit-done/bin/gsd-tools.test.cjs

# Run and show tap output
node --test --reporter=tap get-shit-done/bin/gsd-tools.test.cjs
```

**Expected Output:**
```
✓ empty phases directory returns valid schema
✓ nested frontmatter fields extracted correctly
✓ multiple phases merged into single digest
  ...
```

## Testing Gaps

**Untested Code:**

Files without tests:
- `bin/install.js` (1994 lines) - Installation and hook setup logic
- `hooks/gsd-statusline.js` (91 lines) - Status line rendering
- `hooks/gsd-check-update.js` (62 lines) - Update checking
- `scripts/build-hooks.js` (42 lines) - Hook build script
- `agents/*.md` - Agent template files (documentation)

**Untested Commands in gsd-tools.cjs:**
- config-* commands (config-ensure-section, config-get, config-set)
- state-* commands (state-load, state-get, state-patch, state-add-decision, etc.)
- frontmatter-* commands (frontmatter-get, frontmatter-set, frontmatter-merge)
- Verification suite commands (verify-*)
- Template fill commands (template fill *)
- Roadmap update commands (roadmap update-plan-progress)
- Web search command (websearch)
- Commit command (git-commit)

**Risk:** Missing tests for:
- Configuration loading and merging
- Git operations and commit messages
- State file manipulation
- Frontmatter parsing complex cases
- Error conditions in critical paths

---

*Testing analysis: 2026-02-28*
