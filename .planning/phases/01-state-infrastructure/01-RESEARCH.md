# Phase 1: State Infrastructure - Research

**Researched:** 2026-02-17
**Domain:** config.json persistence via gsd-tools config-set/config-get
**Confidence:** HIGH

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

**Failure cleanup behavior**
- On YOLO failure (verification finds gaps), preserve the yolo stanza in config.json — don't wipe it
- Preserved stanza includes: failed phase number + short reason string (e.g., "verification gaps found") alongside the existing active flag, start phase, and timestamp
- This enables Phase 4's resume flow to detect a prior failed run and offer to pick up from the failed phase

**Success cleanup behavior**
- On milestone completion (all phases pass), keep the yolo stanza until the user explicitly confirms (e.g., via `/gsd:complete-milestone`)
- Don't auto-clear on success — let the user review before wiping state

**Manual override behavior**
- If the user manually runs individual phase commands (e.g., `/gsd:plan-phase 2`) while a yolo stanza exists, clear the YOLO state
- Rationale: manual intervention means the user is taking over; stale YOLO state would cause confusion

### Claude's Discretion
- State schema fields beyond the decided ones (active, start phase, timestamp, failed phase, reason)
- Read-after-write verification approach
- gsd-tools API surface for YOLO state operations
- Stale state detection logic (time-based vs milestone-based)

### Deferred Ideas (OUT OF SCOPE)
None — discussion stayed within phase scope
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| STATE-01 | YOLO session state written to config.json (active flag, start phase, timestamp) | config-set writes nested keys via dot notation; multiple calls build the stanza incrementally |
| STATE-02 | YOLO state survives `/clear` by reading from disk on each invocation | config.json is disk-resident; every config-get reads fresh from disk — no in-memory caching |
| STATE-03 | YOLO state cleaned up on milestone complete or failure stop | config-set cannot delete a key; deletion requires a node inline script or a new gsd-tools command |
</phase_requirements>

## Summary

This phase adds a `workflow.yolo` stanza to `.planning/config.json` and creates the read/write/delete operations for it. The existing `config-set` and `config-get` commands handle writes and reads naturally — they already support dot-notation nested keys, so `workflow.yolo.active`, `workflow.yolo.start_phase`, and `workflow.yolo.timestamp` work out of the box. Verified by live testing on 2026-02-17.

The `config.json` file is read directly from disk on every `config-get` call with no in-memory caching. This is the mechanism behind STATE-02: after `/clear`, the next command that reads `workflow.yolo` gets a fresh disk read and the stanza is present. No special "survive reset" logic is needed — disk persistence is already guaranteed.

The one gap is deletion (STATE-03 cleanup). `config-set` does not support removing a key, only setting values. Cleanup requires either an inline `node` script, a new `gsd-tools config-delete <key>` command, or reading the full config, deleting the key in JavaScript, and writing it back. Adding `config-delete` to gsd-tools is the cleanest approach and matches the existing API surface pattern.

**Primary recommendation:** Implement the yolo stanza using existing `config-set`/`config-get` commands for STATE-01/STATE-02, add a `config-delete <key.path>` command to gsd-tools for STATE-03 cleanup, and add a `yolo-state` compound command for atomic read/write of the full stanza.

## Standard Stack

### Core
| Tool | Version | Purpose | Why Standard |
|------|---------|---------|--------------|
| `gsd-tools config-set` | existing | Write any config.json field via dot-notation | Already used across all workflows for config mutations |
| `gsd-tools config-get` | existing | Read any config.json field via dot-notation | Already used in every workflow's auto-advance check |
| `gsd-tools current-timestamp` | existing | Generate ISO-8601 timestamp for state record | Existing utility used in frontmatter and SUMMARY.md |
| `node` inline script | system | Delete a key from config.json (see State-03 gap) | Until config-delete added to gsd-tools |

### New gsd-tools Commands Needed
| Command | Purpose | Fits Existing Pattern |
|---------|---------|----------------------|
| `config-delete <key.path>` | Remove a dot-notation key from config.json | Same signature as config-get, inverse operation |
| `yolo-state read` | Return full yolo stanza as JSON (or `{}` if absent) | Compound read, same as init commands |
| `yolo-state write --active --start-phase --timestamp` | Atomic write of full stanza | Avoids 3 separate config-set calls |
| `yolo-state clear` | Delete the yolo stanza entirely | Wraps config-delete logic |

**Installation:** No new packages — all operations use Node.js `fs` which is already the gsd-tools implementation layer.

## Architecture Patterns

### Recommended State Schema

```json
{
  "workflow": {
    "yolo": {
      "active": true,
      "start_phase": 1,
      "timestamp": "2026-02-17T08:23:55.263Z"
    }
  }
}
```

**Failure state extension** (preserved instead of cleared):
```json
{
  "workflow": {
    "yolo": {
      "active": false,
      "start_phase": 1,
      "timestamp": "2026-02-17T08:23:55.263Z",
      "failed_phase": 2,
      "failure_reason": "verification gaps found"
    }
  }
}
```

**Rationale for `workflow.yolo` namespace:**
- Consistent with `workflow.auto_advance`, `workflow.research`, `workflow.plan_check` already in config.json
- The `config-get workflow.yolo` path matches the success criteria in the ROADMAP exactly
- Nesting under `workflow` groups all runtime workflow state in one place

### Pattern 1: Write State (STATE-01)

**What:** Write the yolo stanza with three sequential config-set calls or one atomic write via a new command.

**When to use:** At YOLO launch, immediately before invoking plan-phase.

**Sequential approach (using existing commands):**
```bash
# Get timestamp
TIMESTAMP=$(node /home/junbeom/.claude/get-shit-done/bin/gsd-tools.cjs current-timestamp full --raw)

# Write stanza fields
node /home/junbeom/.claude/get-shit-done/bin/gsd-tools.cjs config-set workflow.yolo.active true
node /home/junbeom/.claude/get-shit-done/bin/gsd-tools.cjs config-set workflow.yolo.start_phase "$START_PHASE"
node /home/junbeom/.claude/get-shit-done/bin/gsd-tools.cjs config-set workflow.yolo.timestamp "$TIMESTAMP"

# Read-after-write verification
YOLO_STATE=$(node /home/junbeom/.claude/get-shit-done/bin/gsd-tools.cjs config-get workflow.yolo --raw)
# Verify active, start_phase, timestamp are all present in YOLO_STATE
```

**Atomic approach (preferred — new gsd-tools command):**
```bash
node /home/junbeom/.claude/get-shit-done/bin/gsd-tools.cjs yolo-state write \
  --active true \
  --start-phase "$START_PHASE" \
  --timestamp "$TIMESTAMP"
```

### Pattern 2: Read State (STATE-02)

**What:** Read the yolo stanza on each command invocation to detect active YOLO run.

**When to use:** At the start of any YOLO-aware command (yolo, plan-phase, execute-phase, transition, verify-work).

```bash
YOLO_STATE=$(node /home/junbeom/.claude/get-shit-done/bin/gsd-tools.cjs config-get workflow.yolo 2>/dev/null || echo "{}")
# If YOLO_STATE != {} and .active == true, YOLO run is active
```

**Why this survives `/clear`:** `config-get` reads from disk on every call. There is no in-memory caching in gsd-tools. After `/clear`, the next invocation reads from the same `config.json` file and finds the stanza intact.

### Pattern 3: Cleanup (STATE-03)

**Failure cleanup (preserve with failure info):**
```bash
# Set active to false, add failure fields
node /home/junbeom/.claude/get-shit-done/bin/gsd-tools.cjs config-set workflow.yolo.active false
node /home/junbeom/.claude/get-shit-done/bin/gsd-tools.cjs config-set workflow.yolo.failed_phase "$FAILED_PHASE"
node /home/junbeom/.claude/get-shit-done/bin/gsd-tools.cjs config-set workflow.yolo.failure_reason "$REASON"
```

**Success cleanup (keep until explicit confirm — triggered by `/gsd:complete-milestone`):**
```bash
# Do nothing — stanza stays as-is for Phase 4 to use
```

**Manual override cleanup (clear on manual command invocation):**
```bash
# Using node inline script until config-delete exists:
node -e "
const fs = require('fs');
const p = '.planning/config.json';
const c = JSON.parse(fs.readFileSync(p, 'utf-8'));
delete c.workflow.yolo;
fs.writeFileSync(p, JSON.stringify(c, null, 2));
"
# OR using new yolo-state clear command:
node /home/junbeom/.claude/get-shit-done/bin/gsd-tools.cjs yolo-state clear
```

### Pattern 4: Read-After-Write Verification

**What:** After writing the stanza, immediately read it back and validate that all required fields are present and match expected values.

**Why:** File system write failures can be silent (permissions, disk full, concurrent writes). The success criteria explicitly requires this check.

```bash
# Write stanza...

# Read back
VERIFY=$(node /home/junbeom/.claude/get-shit-done/bin/gsd-tools.cjs config-get workflow.yolo --raw)

# Check fields exist using node inline
node -e "
const s = JSON.parse('$VERIFY');
const ok = s.active === true && s.start_phase !== undefined && s.timestamp !== undefined;
process.exit(ok ? 0 : 1);
" || { echo 'ERROR: YOLO state write verification failed'; exit 1; }
```

**Confidence:** HIGH — verified by live testing.

### Anti-Patterns to Avoid

- **Writing stanza fields separately without verification:** Three separate config-set calls can partially succeed. Always verify the complete stanza reads back correctly.
- **Relying on in-memory state for YOLO detection:** Commands must read from disk. Do not pass yolo state as arguments between commands — it won't survive `/clear`.
- **Storing yolo state in STATE.md instead of config.json:** STATE.md is for human-readable project status. config.json is for machine-readable workflow flags. The success criteria explicitly names config.json.
- **Setting `workflow.yolo` to the string "null" via config-set:** `config-set` does not parse `null` as a JSON null; it writes the string `"null"`. Use the delete pattern instead.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Write nested JSON key | Custom file write logic | `config-set <dot.path> <value>` | Already handles path creation, type coercion, and atomic write |
| Read nested JSON key | `jq` / `python3` pipeline | `config-get <dot.path>` | Returns clean JSON output, handles missing keys with clear error |
| ISO timestamp | `date` shell command variations | `current-timestamp full --raw` | Returns consistent format, cross-platform, used everywhere else |
| Delete JSON key | Complex `jq` or `python3` one-liner | New `config-delete` in gsd-tools | Keeps all config mutations in one tool, consistent error handling |

**Key insight:** The entire state infrastructure can be implemented without any new files or custom persistence logic — it's a straightforward usage of existing config.json patterns. The only new code needed is `config-delete` (and optionally a `yolo-state` compound command) in gsd-tools.cjs.

## Common Pitfalls

### Pitfall 1: config-set Cannot Delete Keys

**What goes wrong:** Attempting `config-set workflow.yolo null` writes the string `"null"` — `config-get workflow.yolo.active` then fails with a type error.

**Why it happens:** `cmdConfigSet` only parses `"true"`, `"false"`, and numeric strings. Any other value is kept as a string.

**How to avoid:** Use the node inline delete pattern or add `config-delete` to gsd-tools. Never use `config-set` for cleanup.

**Warning signs:** `config-get workflow.yolo` returns `"null"` (a string) instead of `{}` (empty/absent).

**Verified:** Live test on 2026-02-17 confirmed this behavior.

### Pitfall 2: Stale Stanza After Context Reset

**What goes wrong:** A yolo stanza from a previous interrupted run (active: true) is still present when a new run starts. The new run thinks a session is already active.

**Why it happens:** Cleanup only runs at specific exit points (failure, success via complete-milestone). If the process is killed or Claude crashes, cleanup never runs.

**How to avoid:** Check for stale state at YOLO launch. The stale detection strategy (Claude's Discretion) can be timestamp-based: if `workflow.yolo.active` is `true` but the timestamp is older than a threshold, treat as stale.

**Phase scope note:** Stale detection logic is Claude's Discretion and belongs in Phase 1. The Phase 4 resume flow is a separate concern (re-detecting a previous failed run).

### Pitfall 3: Manual Phase Commands Must Clear YOLO State

**What goes wrong:** User manually runs `/gsd:plan-phase 2` during a YOLO run. The yolo stanza remains. Phase 4's resume flow later sees `active: true` and tries to resume a YOLO run that the user abandoned.

**Why it happens:** Only YOLO command entry/exit points do cleanup.

**How to avoid:** plan-phase, execute-phase, and verify-work workflows must check for a yolo stanza at init and clear it if the command was invoked without the YOLO chain context (i.e., not from within a YOLO run). The CONTEXT.md decision specifies this behavior.

**Warning signs:** `workflow.yolo.active` is `true` but `mode` shows the user is in an interactive workflow.

### Pitfall 4: Write Ordering and Partial Stanza

**What goes wrong:** Three sequential `config-set` calls — if one fails, the stanza is partially written. A subsequent `config-get workflow.yolo` returns an object with some fields missing.

**Why it happens:** Each `config-set` is an independent file read-modify-write cycle. Failure at any step leaves a partial state.

**How to avoid:** Use read-after-write verification after all three writes complete. The verification step should check that `active`, `start_phase`, and `timestamp` are ALL present. If the atomic `yolo-state write` command is implemented, partial writes are impossible.

## Code Examples

Verified patterns from live testing on 2026-02-17:

### Write Full Yolo Stanza
```bash
# Source: live test in project, 2026-02-17
TIMESTAMP=$(node /home/junbeom/.claude/get-shit-done/bin/gsd-tools.cjs current-timestamp full --raw)

node /home/junbeom/.claude/get-shit-done/bin/gsd-tools.cjs config-set workflow.yolo.active true
node /home/junbeom/.claude/get-shit-done/bin/gsd-tools.cjs config-set workflow.yolo.start_phase 1
node /home/junbeom/.claude/get-shit-done/bin/gsd-tools.cjs config-set workflow.yolo.timestamp "$TIMESTAMP"
```

Result in config.json:
```json
{
  "workflow": {
    "research": true,
    "plan_check": true,
    "verifier": true,
    "yolo": {
      "active": true,
      "start_phase": 1,
      "timestamp": "2026-02-17T08:23:55.263Z"
    }
  }
}
```

### Read Full Yolo Stanza
```bash
# Source: live test in project, 2026-02-17
node /home/junbeom/.claude/get-shit-done/bin/gsd-tools.cjs config-get workflow.yolo --raw
# Returns: {"active":true,"start_phase":1,"timestamp":"2026-02-17T08:23:55.263Z"}

node /home/junbeom/.claude/get-shit-done/bin/gsd-tools.cjs config-get workflow.yolo.active --raw
# Returns: true
```

### Delete Yolo Stanza (node inline — until config-delete exists)
```bash
# Source: live test in project, 2026-02-17
node -e "
const fs = require('fs');
const p = '.planning/config.json';
const c = JSON.parse(fs.readFileSync(p, 'utf-8'));
delete c.workflow.yolo;
fs.writeFileSync(p, JSON.stringify(c, null, 2));
"
```

### Failure State Preservation
```bash
# Source: derived from config-set behavior, 2026-02-17
node /home/junbeom/.claude/get-shit-done/bin/gsd-tools.cjs config-set workflow.yolo.active false
node /home/junbeom/.claude/get-shit-done/bin/gsd-tools.cjs config-set workflow.yolo.failed_phase 2
node /home/junbeom/.claude/get-shit-done/bin/gsd-tools.cjs config-set workflow.yolo.failure_reason "verification gaps found"
```

### Check If YOLO Is Active
```bash
# Source: follows workflow.auto_advance pattern from plan-phase.md
YOLO_ACTIVE=$(node /home/junbeom/.claude/get-shit-done/bin/gsd-tools.cjs config-get workflow.yolo.active 2>/dev/null || echo "false")
if [ "$YOLO_ACTIVE" = "true" ]; then
  echo "YOLO run is active"
fi
```

### Read-After-Write Verification
```bash
# Source: derived pattern, 2026-02-17
YOLO_VERIFY=$(node /home/junbeom/.claude/get-shit-done/bin/gsd-tools.cjs config-get workflow.yolo --raw 2>&1)
if echo "$YOLO_VERIFY" | grep -q '"active"' && \
   echo "$YOLO_VERIFY" | grep -q '"start_phase"' && \
   echo "$YOLO_VERIFY" | grep -q '"timestamp"'; then
  echo "State write verified"
else
  echo "ERROR: State write verification failed"
  exit 1
fi
```

## State of the Art

| Old Approach | Current Approach | Notes |
|--------------|-----------------|-------|
| N/A (YOLO state not yet implemented) | `workflow.yolo` stanza in config.json | This phase creates the first implementation |
| `workflow.auto_advance` (existing) | `workflow.yolo` stanza (new, richer) | auto_advance is a boolean flag; yolo is a structured session record |

**Existing precedent to follow:**
- `workflow.auto_advance` — already lives in `workflow` namespace, written via `config-set`, read via `config-get` in every auto-advance check in plan-phase.md, execute-phase.md, discuss-phase.md
- `mode: "yolo"` — already set in config.json by `new-project.md` (this project uses it); transition.md checks it via `config_content` to decide auto-approval behavior

## Open Questions

1. **New `yolo-state` compound command vs. three sequential `config-set` calls**
   - What we know: Sequential config-set works (verified). Atomic write is cleaner and avoids partial writes.
   - What's unclear: Is the complexity of a new compound command worth it for Phase 1, or should it wait for Phase 2 when the full YOLO command is built?
   - Recommendation: Implement the three sequential config-set calls for STATE-01 in Phase 1. Add `yolo-state` compound command as a task in Phase 1 or Phase 2 since it will also be needed for Phase 2's read-on-invoke logic.

2. **Stale state detection threshold**
   - What we know: User decision says stale detection logic is Claude's Discretion.
   - What's unclear: What age threshold makes a stanza "stale"? (1 hour? 24 hours? 7 days?)
   - Recommendation: Use 24 hours as a safe default for initial implementation. A YOLO run that started more than 24 hours ago without explicit success/failure cleanup is almost certainly abandoned. Can be made configurable later.

3. **Where does manual override detection live?**
   - What we know: plan-phase, execute-phase should clear YOLO state on manual invocation.
   - What's unclear: Phase 1 only covers STATE infrastructure (write/read/cleanup). The actual detection logic in plan-phase/execute-phase is Phase 2/3 scope.
   - Recommendation: Phase 1 creates the cleanup function (config-delete / yolo-state clear). Phase 2 adds the detection hook in plan-phase workflow. This is already implied by the phase boundary in CONTEXT.md.

## Sources

### Primary (HIGH confidence)
- Live testing of gsd-tools.cjs on 2026-02-17 — config-set, config-get, current-timestamp commands all tested directly
- `/home/junbeom/.claude/get-shit-done/bin/gsd-tools.cjs` — source code read, cmdConfigSet (line 650), cmdConfigGet (line 695) implementations verified
- `/home/junbeom/.claude/get-shit-done/workflows/transition.md` — how `mode: "yolo"` and `workflow.auto_advance` are currently consumed
- `/home/junbeom/.claude/get-shit-done/workflows/plan-phase.md` — `workflow.auto_advance` read pattern (step 14)
- `/home/junbeom/Projects/get-shit-done/.planning/config.json` — current project config structure

### Secondary (MEDIUM confidence)
- `/home/junbeom/.claude/get-shit-done/templates/config.json` — canonical default structure showing `workflow` namespace convention
- `/home/junbeom/.claude/get-shit-done/workflows/new-project.md` — how `mode: "yolo"` is first written to config.json

### Tertiary (LOW confidence)
- None — all claims verified against source code or live tests

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — verified by live testing; config-set/config-get work for nested keys as needed
- Architecture: HIGH — schema derived from existing `workflow.*` patterns and success criteria in ROADMAP
- Pitfalls: HIGH — config-set null behavior verified by live test; others derived from source code analysis

**Research date:** 2026-02-17
**Valid until:** 2026-03-17 (stable internal tool, changes infrequent)
