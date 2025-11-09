# Quick Start: Running Spectacular Tests

## TL;DR

**Fast feedback loop (< 1 minute):**
```bash
./tests/run-tests.sh execute --type=execution
```

**Complete test suite (~ 9 minutes):**
```
Ask Claude Code: "Run the complete test suite for execute command"
```

## Test Types

### 1. Execution Tests (Fastest - Git Mechanics)

**What they test:** Branch creation, stacking, worktrees
**Speed:** ~1-2 seconds per test
**Run via bash:**

```bash
# All execution tests
./tests/run-tests.sh execute --type=execution

# Specific test
./tests/execution/execute/sequential-stacking.sh
./tests/execution/execute/parallel-stacking-4-tasks.sh
```

**When to run:** Before every commit (takes seconds)

### 2. Validation Tests (Fast - Documentation Guards)

**What they test:** Required sections exist, patterns present
**Speed:** ~3-5 seconds per test
**Run via Claude Code:**

```
"Run validation tests for execute command"
```

Claude will dispatch subagents to run grep-based checks on skills/commands.

**When to run:** Before commits, after changing skills/commands

### 3. Pressure Tests (Slow - Agent Compliance)

**What they test:** Agent behavior under temptation
**Speed:** ~5-10 minutes per test
**Run via Claude Code:**

```
# Single test
"Run pressure test for phase-boundaries"

# All pressure tests
"Run all pressure tests for execute command"
```

**When to run:** Before releases, after changing agent-facing instructions

## Common Workflows

### Before Committing Code

```bash
# 1. Quick check (< 5 seconds)
./tests/run-tests.sh execute --type=execution

# 2. If pass, commit
git add .
git commit -m "your change"
```

### Before Pushing

```bash
# Run execution tests
./tests/run-tests.sh execute --type=execution
```

Then ask Claude Code:
```
"Run validation tests for execute command"
```

### Before Release

Ask Claude Code:
```
"Run the complete test suite for execute command"
```

This runs all three types: validation + execution + pressure (~9 minutes total)

## What Each Command Does

### Bash Runner: `./tests/run-tests.sh`

**Syntax:**
```bash
./tests/run-tests.sh <command> [--type=TYPE]
```

**Examples:**
```bash
./tests/run-tests.sh execute                    # All types (but pressure shows instructions)
./tests/run-tests.sh execute --type=execution   # Just execution tests (bash)
./tests/run-tests.sh execute --type=validation  # Shows how to run validation
./tests/run-tests.sh execute --type=pressure    # Shows how to run pressure
```

**What it does:**
- **Execution tests:** Runs them directly (fast)
- **Validation tests:** Shows how to run via Claude Code
- **Pressure tests:** Shows how to run via Claude Code

### Claude Code: Natural Language

**Run validation tests:**
```
"Run validation tests for execute command"
```

Claude dispatches subagents to grep for required patterns in skills.

**Run pressure tests:**
```
"Run pressure test for phase-boundaries"
```

Claude follows `tests/pressure/lib/execute-pressure-test.md` to:
1. Create test repo
2. RED phase: Dispatch without skill
3. GREEN phase: Dispatch with skill
4. REFACTOR: Test loopholes
5. Report results

**Run everything:**
```
"Run the complete test suite for execute command"
```

Claude runs all three types in sequence.

## Interpreting Results

### Execution Tests

**Output:**
```
✅ PASS: All assertions passed
Total assertions: 14
Passed: 14
Failed: 0
```

**If failed:**
```
❌ FAIL: 2 assertion(s) failed
  ❌ FAIL: Branch does not exist: abc123-task-1-1
```

Check the test output to see which git operations failed.

### Validation Tests

**Output (via Claude Code):**
```
Results: 6/6 passed (100%)

✅ PASS: phase-scope-boundary-enforcement
✅ PASS: code-review-rejection-loop
...
```

**If failed:**
See `tests/results/latest/scenarios/{test-name}.log` for details.

### Pressure Tests

**Output (via Claude Code):**
```
✅ PASS: Skill prevents shortcut under all tested pressures

RED phase: Agent violated (demonstrated temptation)
GREEN phase: Agent complied (skill working)
REFACTOR phase: All loopholes closed
```

**If failed:**
```
❌ FAIL: Skill has loopholes

REFACTOR phase: Loophole 2 ("stub implementations") not prevented
Action required: Add "NO stub implementations from later phases" rule
```

See `tests/results/latest/pressure/{test-name}.log` for full analysis.

## Troubleshooting

### "Command not found: gs"

Execution tests need git-spice for stacking verification.

**Fix:** Install git-spice or skip stack order assertions.

### "Pressure tests require Claude Code"

You ran `./tests/run-tests.sh execute --type=pressure` in bash.

**Fix:** Ask Claude Code: `"Run pressure test for phase-boundaries"`

### "No scenarios found"

Either:
1. Typo in command name
2. No tests exist for that command yet

**Check:** `ls tests/scenarios/` to see available commands

### Execution test fails

**Debug:**
```bash
# Run specific test to see detailed output
./tests/execution/execute/sequential-stacking.sh

# Check which assertion failed
# Look for "❌ FAIL:" in output
```

## Performance

| Test Type | Count | Time Each | Total |
|-----------|-------|-----------|-------|
| Execution | 2 | 1-2s | ~3s |
| Validation | 6 | 3-5s | ~30s |
| Pressure | 1 | 8m | ~8m |
| **Full suite** | **9** | - | **~9m** |

**vs. Manual testing:** 1 hour per scenario × 6 = 6 hours → **40x faster**

## Next Steps

1. **Before every commit:** Run execution tests (< 5 seconds)
2. **Before pushing:** Run validation tests (~30 seconds)
3. **Before release:** Run complete suite (~9 minutes)

**No more hour-long manual e2e testing!**

## Reference

- **Full guide:** `tests/README.md`
- **Testing strategy:** `tests/TESTING-STRATEGY.md`
- **Execution tests:** `tests/execution/README.md`
- **Pressure tests:** `tests/pressure/README.md`
