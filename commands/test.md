---
description: Execute test scenarios for spectacular commands using parallel subagent dispatch
---

You are running test scenarios for the spectacular testing system.

## Purpose

This command orchestrates automated testing of spectacular commands by:
- Cloning test fixtures to isolated environments
- Dispatching subagents in parallel to run test scenarios
- Aggregating results and reporting pass/fail status
- Enabling RED-GREEN-REFACTOR workflow for command development

## Usage

```bash
/spectacular:test <command>    # Run scenarios for specific command (execute, init, spec, plan)
/spectacular:test all          # Run all test scenarios across all commands
```

## Workflow

### Step 1: Parse Command Argument

Determine which scenarios to run based on the command argument:

```bash
COMMAND_ARG="$1"

if [ -z "$COMMAND_ARG" ]; then
  echo "❌ Usage: /spectacular:test <command|all>"
  echo ""
  echo "Available commands:"
  echo "  execute - Test execute command scenarios"
  echo "  init    - Test init command scenarios"
  echo "  spec    - Test spec command scenarios"
  echo "  plan    - Test plan command scenarios"
  echo "  all     - Test all scenarios"
  echo ""
  exit 1
fi

echo "Running test scenarios for: $COMMAND_ARG"
echo ""
```

### Step 2: Validate Test Infrastructure

Check that required test files exist:

```bash
# Validate test fixtures exist
if [ ! -d tests/fixtures ]; then
  echo "❌ Test fixtures not found at tests/fixtures/"
  echo ""
  echo "Run Phase 1 task-1-test-fixtures to create fixtures first."
  exit 1
fi

echo "✅ Test fixtures found"

# Validate test scenarios exist
if [ ! -d tests/scenarios ]; then
  echo "❌ Test scenarios not found at tests/scenarios/"
  echo ""
  echo "Run Phase 1 task-2-test-scenarios to create scenarios first."
  exit 1
fi

echo "✅ Test scenarios found"
echo ""
```

### Step 3: Identify Scenarios to Run

Find all matching scenario files:

```bash
SCENARIO_FILES=()

if [ "$COMMAND_ARG" = "all" ]; then
  echo "Collecting scenarios from all commands..."

  # Find all scenario files across all command directories
  while IFS= read -r scenario_file; do
    SCENARIO_FILES+=("$scenario_file")
  done < <(find tests/scenarios -name "*.md" -type f ! -name "README.md" | sort)

  SCENARIO_COUNT=${#SCENARIO_FILES[@]}
  echo "Found $SCENARIO_COUNT total scenarios"
  echo ""
else
  # Find scenarios for specific command
  SCENARIO_DIR="tests/scenarios/$COMMAND_ARG"

  if [ ! -d "$SCENARIO_DIR" ]; then
    echo "❌ No scenarios found for command: $COMMAND_ARG"
    echo ""
    echo "Available commands:"
    ls -1 tests/scenarios/ | grep -v "README.md"
    echo ""
    exit 1
  fi

  echo "Collecting scenarios from $COMMAND_ARG command..."

  while IFS= read -r scenario_file; do
    SCENARIO_FILES+=("$scenario_file")
  done < <(find "$SCENARIO_DIR" -name "*.md" -type f ! -name "README.md" | sort)

  SCENARIO_COUNT=${#SCENARIO_FILES[@]}

  if [ "$SCENARIO_COUNT" -eq 0 ]; then
    echo "❌ No scenario files found in $SCENARIO_DIR"
    echo ""
    echo "Create .md files in $SCENARIO_DIR to add test scenarios"
    exit 1
  fi

  echo "Found $SCENARIO_COUNT scenarios for $COMMAND_ARG"
  echo ""
fi
```

### Step 4: Display Scenarios

Show what will be tested:

```bash
echo "Scenarios to run:"
echo "================="

for scenario_file in "${SCENARIO_FILES[@]}"; do
  # Extract relative path for display
  SCENARIO_NAME=$(basename "$scenario_file" .md)
  SCENARIO_COMMAND=$(basename "$(dirname "$scenario_file")")
  echo "  [$SCENARIO_COMMAND] $SCENARIO_NAME"
done

echo ""
echo "========================================="
echo ""
```

### Step 5: Dispatch Subagents in Parallel

Now dispatch one subagent per scenario using the Task tool. Each subagent will verify the scenario's success criteria.

For each scenario file found in Step 3, dispatch a subagent with these instructions:

**Subagent Prompt Template:**

```
You are testing spectacular command implementation against a test scenario.

SCENARIO FILE: {scenario_file_path}
REPOSITORY ROOT: /Users/drewritter/projects/spectacular

## Your Task

1. Read the scenario file at the path above
2. Understand the Context, Expected Behavior, and Success Criteria sections
3. Verify whether the implementation matches the scenario expectations
4. Report PASS or FAIL in the required format

## Verification Approach

The scenario describes what SHOULD happen when the command works correctly. Your job is to verify:

- If scenario mentions command structure → Check command file exists and has described sections
- If scenario mentions git operations → Check that commands/skills document the git workflow
- If scenario mentions file creation → Check that instructions describe creating those files
- If scenario has Success Criteria → Use as verification checklist

## Reporting Format

**PASS Format:**
```
✅ PASS: {scenario_name}

All success criteria met:
- [criterion 1]: ✓ verified
- [criterion 2]: ✓ verified

Evidence:
[Show relevant file excerpts, command structure, or git workflow documentation]
```

**FAIL Format:**
```
❌ FAIL: {scenario_name}

Unmet criteria:
- [criterion X]: ✗ FAILED - [reason]
- [criterion Y]: ✗ FAILED - [reason]

Evidence:
[Show what's missing or incorrect]
```

## Critical Notes

- You are verifying DOCUMENTATION/IMPLEMENTATION, not running the command
- For execute command scenarios: Check that commands/execute.md documents the workflow
- For meta-testing (test command): Verify command structure matches scenario expectations
- Be precise: Only mark criteria as met if you have clear evidence

Now begin verification.
```

Dispatch all subagents in parallel by calling Task tool multiple times in a single message.

### Step 6: Aggregate Results

After all subagents complete, collect their results and display a summary.

For each subagent result:

1. Parse the result to determine if it's PASS or FAIL
   - Look for `✅ PASS:` or `❌ FAIL:` in the subagent output
   - Extract scenario name and status

2. Display each result as received

3. Calculate totals:
   - Count PASS results
   - Count FAIL results
   - Total scenarios

4. Display summary:

```
=========================================
Test Results Summary
=========================================

✅ PASS: scenario-1
❌ FAIL: scenario-2
✅ PASS: scenario-3

Results: 2/3 passed

❌ 1 scenario(s) failed
```

5. Communicate final status to user:
   - If all scenarios passed: Success message
   - If any scenarios failed: List which ones failed and suggest reviewing the evidence

### Step 7: Cleanup

Remove temporary test directories:

```bash
echo "Cleaning up test artifacts..."

# Remove test worktrees if they exist
if [ -d .worktrees ]; then
  TEST_DIRS=$(find .worktrees -maxdepth 1 -type d -name "test-*" 2>/dev/null || true)

  if [ -n "$TEST_DIRS" ]; then
    echo "$TEST_DIRS" | while read -r test_dir; do
      if [ -d "$test_dir" ]; then
        rm -rf "$test_dir"
        echo "  Removed: $test_dir"
      fi
    done
  fi
fi

echo "✅ Cleanup complete"
echo ""
```

## Architecture

This command implements the testing workflow described in `skills/testing-spectacular/SKILL.md`:

**RED Phase:** Test scenarios document expected behavior (tests exist before implementation)

**GREEN Phase:** Implement commands/skills to pass the tests

**REFACTOR Phase:** Re-run tests to verify edge cases and improvements

**Key Design Principles:**

1. **Isolation:** Each scenario gets fresh fixture clone (no shared state)
2. **Parallelism:** Subagents run concurrently (when Task tool supports it)
3. **Clarity:** Results clearly show PASS/FAIL with evidence
4. **Automation:** Exit codes enable CI/CD integration

## Current Implementation Status

**Phase:** GREEN (Fully Functional)

**What Works:**
- Command parsing and validation
- Test infrastructure checks
- Scenario discovery and listing
- Parallel subagent dispatch using Task tool
- Result aggregation and reporting
- PASS/FAIL status with evidence
- Cleanup of test artifacts

**Usage:**

Run all scenarios for a specific command:
```bash
/spectacular:test execute    # Test execute command scenarios
/spectacular:test init       # Test init command scenarios
/spectacular:test spec       # Test spec command scenarios
/spectacular:test plan       # Test plan command scenarios
```

Run all scenarios across all commands:
```bash
/spectacular:test all
```

**Expected Output:**

The command will:
1. Discover all matching scenarios
2. Dispatch parallel subagents to verify each scenario
3. Aggregate and display results
4. Report overall PASS/FAIL status

**Next Steps (Future Enhancement):**
- Add timing metrics (execution time per scenario)
- Support filtering scenarios by tags
- Generate HTML test reports

## Example Output

**All scenarios passing:**
```
Running test scenarios for: execute

✅ Test fixtures found
✅ Test scenarios found

Collecting scenarios from execute command...
Found 6 scenarios for execute

Scenarios to run:
=================
  [execute] parallel-stacking-2-tasks
  [execute] parallel-stacking-3-tasks
  [execute] parallel-stacking-4-tasks
  [execute] sequential-stacking
  [execute] worktree-creation
  [execute] cleanup-tmp-branches

=========================================

Dispatching 6 subagents to verify scenarios...

[Subagent outputs appear here as they complete]

=========================================
Test Results Summary
=========================================

✅ PASS: parallel-stacking-2-tasks
✅ PASS: parallel-stacking-3-tasks
✅ PASS: parallel-stacking-4-tasks
✅ PASS: sequential-stacking
✅ PASS: worktree-creation
✅ PASS: cleanup-tmp-branches

Results: 6/6 passed

✅ All scenarios passed!

Cleaning up test artifacts...
✅ Cleanup complete
```

**Some scenarios failing:**
```
Running test scenarios for: execute

✅ Test fixtures found
✅ Test scenarios found

Collecting scenarios from execute command...
Found 6 scenarios for execute

Scenarios to run:
=================
  [execute] parallel-stacking-2-tasks
  [execute] parallel-stacking-3-tasks
  [execute] parallel-stacking-4-tasks
  [execute] sequential-stacking
  [execute] worktree-creation
  [execute] cleanup-tmp-branches

=========================================

Dispatching 6 subagents to verify scenarios...

[Subagent outputs appear here as they complete]

=========================================
Test Results Summary
=========================================

✅ PASS: parallel-stacking-2-tasks
❌ FAIL: parallel-stacking-3-tasks
❌ FAIL: parallel-stacking-4-tasks
✅ PASS: sequential-stacking
✅ PASS: worktree-creation
✅ PASS: cleanup-tmp-branches

Results: 4/6 passed

❌ 2 scenario(s) failed:
- parallel-stacking-3-tasks
- parallel-stacking-4-tasks

Review the subagent evidence above to understand what's missing.

Cleaning up test artifacts...
✅ Cleanup complete
```

**Missing scenarios:**
```
Running test scenarios for: nonexistent

✅ Test fixtures found
✅ Test scenarios found

Collecting scenarios from nonexistent command...

❌ No scenarios found for command: nonexistent

Available commands:
execute
init
plan
spec
test
```

Now run the test command validation.
