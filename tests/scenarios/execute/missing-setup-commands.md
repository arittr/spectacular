# Test Scenario: Missing Setup Commands

## Context

Testing `/spectacular:execute` error handling when CLAUDE.md doesn't define required setup commands.

**Setup:**
- Feature spec with Phase 2 containing 3 parallel tasks
- CLAUDE.md exists but **MISSING** setup section:
  ```markdown
  # CLAUDE.md

  ## Development Commands

  ### Quality Checks
  - **test**: `npm test`
  - **lint**: `npm run lint`

  <!-- Missing Setup section! -->
  ```
- Clean git state with git-spice initialized

**Why this matters:**
- CLAUDE.md might be incomplete or misconfigured
- New projects might not have setup commands defined yet
- Worktrees need dependencies to execute tasks
- Should fail fast with clear error, not mysterious failures later

## Expected Behavior

### Setup Command Detection

**execute.md documents this requirement:**

> **REQUIRED**: Spectacular creates isolated git worktrees for each feature. Each worktree needs dependencies installed and codegen run. Define these commands in your project's CLAUDE.md.

**Detection logic:**

```bash
# After creating parallel worktrees, check for setup commands

# Check if CLAUDE.md exists
if [ ! -f CLAUDE.md ]; then
  echo "❌ Error: CLAUDE.md not found in repository root"
  echo ""
  echo "Spectacular requires CLAUDE.md to define setup commands"
  echo "See: https://docs.spectacular.dev/setup-commands"
  exit 1
fi

# Parse CLAUDE.md for setup section
INSTALL_CMD=$(grep -A 10 "^### Setup" CLAUDE.md | grep "^- \*\*install\*\*:" | sed 's/.*: `\(.*\)`.*/\1/')

if [ -z "$INSTALL_CMD" ]; then
  echo "❌ Error: Setup commands not defined in CLAUDE.md"
  echo ""
  echo "Worktrees require dependency installation before tasks can execute."
  echo ""
  echo "Add this section to CLAUDE.md:"
  echo ""
  echo "## Development Commands"
  echo ""
  echo "### Setup"
  echo "- **install**: \`npm install\`  (or your package manager)"
  echo "- **postinstall**: \`npx prisma generate\`  (optional - any codegen)"
  echo ""
  echo "See: https://docs.spectacular.dev/setup-commands"
  exit 1
fi
```

**Critical: Fail BEFORE spawning subagents** (avoids confusing errors)

### Error Message

**Clear, actionable error:**

```
❌ Error: Setup commands not defined in CLAUDE.md

Worktrees require dependency installation before tasks can execute.

Add this section to CLAUDE.md:

## Development Commands

### Setup
- **install**: `npm install`  (or your package manager)
- **postinstall**: `npx prisma generate`  (optional - any codegen)

Example for different package managers:
- Node.js: `npm install` or `pnpm install` or `yarn` or `bun install`
- Python: `pip install -r requirements.txt`
- Rust: `cargo build`
- Go: `go mod download`

See: https://docs.spectacular.dev/setup-commands

Execution stopped. Add setup commands to CLAUDE.md and retry.
```

**Exit code: 1** (failure, prevents further execution)

### User Fix Flow

**User adds setup section:**

```markdown
# CLAUDE.md

## Development Commands

### Setup
- **install**: `npm install`
- **postinstall**: `npx prisma generate`

### Quality Checks
- **test**: `npm test`
- **lint**: `npm run lint`
```

**Re-run execute:**

```bash
/spectacular:execute

# Now setup commands detected:
✅ Setup commands found in CLAUDE.md
   install: npm install
   postinstall: npx prisma generate

# Proceeds to create worktrees and install dependencies
```

## Success Criteria

### Early Detection
- [ ] Missing commands detected BEFORE creating worktrees
- [ ] Detection happens in Step 2 (setup phase)
- [ ] No worktrees created if setup commands missing
- [ ] No subagents spawned if setup commands missing

### Clear Error Messaging
- [ ] Error message explains WHAT is missing (setup commands)
- [ ] Error message explains WHY they're needed (dependency installation)
- [ ] Error message shows HOW to fix (example CLAUDE.md section)
- [ ] Error message includes link to documentation

### Multi-Language Support
- [ ] Example shows npm install (Node.js)
- [ ] Example mentions alternatives (pip, cargo, go mod)
- [ ] Generic enough to work for any language/toolchain

### Graceful Failure
- [ ] Execution stops cleanly (no partial state)
- [ ] No worktrees left behind
- [ ] Clear exit code (non-zero)
- [ ] No confusing stack traces

### Resume After Fix
- [ ] User adds setup commands to CLAUDE.md
- [ ] Re-running execute succeeds
- [ ] Setup runs correctly with new commands
- [ ] Execution proceeds normally

## Failure Modes to Test

### Issue 1: Silent Failure (No Error)

**Symptom:** Execution proceeds without setup, subagents fail with "command not found"

**Root Cause:** Missing validation step before subagent spawn

**Detection:**
```bash
# Should see clear error about missing setup commands
# Should NOT see:
#   ❌ Task 1 failed: npm: command not found
#   ❌ Task 2 failed: node_modules: No such file or directory
```

### Issue 2: Confusing Error Message

**Symptom:** Error says "CLAUDE.md invalid" but doesn't explain what's missing

**Root Cause:** Generic error without specific guidance

**Bad error:**
```
❌ Error: Invalid CLAUDE.md
```

**Good error:**
```
❌ Error: Setup commands not defined in CLAUDE.md
[Shows exact section to add]
```

### Issue 3: Late Detection (After Worktrees Created)

**Symptom:** Worktrees created, then setup fails, leaving orphaned worktrees

**Root Cause:** Validation happens too late in workflow

**Detection:**
```bash
ls .worktrees/
# If setup validation fails, should NOT show:
# {runid}-task-1, {runid}-task-2, {runid}-task-3
# (worktrees created before validation)
```

### Issue 4: No Recovery Path

**Symptom:** User doesn't know how to fix the issue

**Root Cause:** Error message doesn't show example or documentation link

**Detection:**
- Error should include example CLAUDE.md section
- Error should include documentation URL
- User should be able to copy-paste example

## Edge Case Variants

### Variant A: CLAUDE.md completely missing

```bash
# No CLAUDE.md file in repository
ls CLAUDE.md
# ls: CLAUDE.md: No such file or directory

# Should error:
❌ Error: CLAUDE.md not found in repository root
```

### Variant B: CLAUDE.md exists but empty

```markdown
# CLAUDE.md
[empty file]
```

```bash
# Should error:
❌ Error: Setup commands not defined in CLAUDE.md
```

### Variant C: Setup section exists but missing install command

```markdown
## Development Commands

### Setup
- **postinstall**: `npx prisma generate`
```

```bash
# Should error:
❌ Error: 'install' command not defined in CLAUDE.md setup section
```

### Variant D: Setup section with wrong formatting

```markdown
## Development Commands

### Setup
install: npm install  <!-- Wrong format, should have **install**: -->
```

```bash
# Parser doesn't find it, should error:
❌ Error: Setup commands not defined in CLAUDE.md
```

### Variant E: Setup commands defined (success case)

```markdown
## Development Commands

### Setup
- **install**: `npm install`
- **postinstall**: `npx prisma generate`
```

```bash
✅ Setup commands found in CLAUDE.md
# Execution proceeds
```

## Test Execution

**Setup:**

1. Create test repository WITHOUT setup commands in CLAUDE.md
2. Create plan with parallel tasks

**Execute:**

```bash
/spectacular:execute

# Should fail immediately with clear error
# Should NOT create worktrees
# Should show example CLAUDE.md section
```

**Fix:**

```bash
# Add setup section to CLAUDE.md
cat >> CLAUDE.md << 'EOF'

## Development Commands

### Setup
- **install**: `npm install`
- **postinstall**: `npx prisma generate`
EOF

# Retry
/spectacular:execute

# Should succeed
```

## Validation Checklist

When testing this scenario, verify:

- [ ] Error occurs BEFORE creating any worktrees
- [ ] Error message is clear and actionable
- [ ] Example shows correct CLAUDE.md format
- [ ] Documentation link included
- [ ] User can fix and resume successfully
- [ ] No orphaned state left behind on error

## Related Scenarios

- **quality-check-failure.md** - Tests quality check commands (similar detection needed)
- **task-failure-recovery.md** - Tests recovery from different type of error
- **parallel-stacking-3-tasks.md** - Happy path with setup commands present
