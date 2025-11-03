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

**IMPORTANT:** This step requires dispatching multiple subagents in parallel using the Task tool. Each subagent will:

1. Receive a test fixture clone path
2. Receive a scenario file path
3. Execute the scenario using the `testing-workflows-with-subagents` skill
4. Report PASS or FAIL with evidence

**Subagent Dispatch Instructions:**

For each scenario in `SCENARIO_FILES`, create a subagent task with these instructions:

```
ROLE: Test Scenario Executor

SCENARIO: [scenario file path]
FIXTURE: tests/fixtures/simple-typescript (or simple-python based on scenario needs)

INSTRUCTIONS:

1. Navigate to spectacular repository root

2. Read scenario file at [scenario file path]
   - Understand Context, Expected Behavior, Success Criteria

3. The scenario describes what SHOULD happen when the tested command runs correctly.
   Your job is to verify the command produces this behavior.

4. Execute scenario verification:
   - If scenario involves running a spectacular command, check if command exists
   - If scenario involves git operations, verify git structure
   - If scenario involves file creation, verify files exist
   - Use Success Criteria as verification checklist

5. Report result:

   PASS Format:
   ✅ PASS: [scenario name]
   All success criteria met:
   - [criterion 1]: verified
   - [criterion 2]: verified
   Evidence: [relevant command outputs, file contents, git structure]

   FAIL Format:
   ❌ FAIL: [scenario name]
   Unmet criteria:
   - [criterion X]: FAILED - [reason]
   Evidence: [error messages, wrong outputs, missing files]

CRITICAL: You are NOT running the tested command yourself. You are verifying
that the implementation (if it exists) matches the scenario's expectations.
For meta-testing the test command itself, verify the command structure exists
and follows the expected patterns described in the scenario.
```

**Orchestrator Note:**

Since Claude Code may not support true parallel subagent dispatch via Task tool in all contexts, this step describes the INTENDED behavior. The implementation should:

1. Create isolated test fixture clones for each scenario
2. Dispatch one subagent per scenario (in parallel if possible)
3. Collect results from each subagent
4. Aggregate into summary report

**For initial implementation (GREEN phase), acknowledge this limitation:**

```bash
echo "⚠️  Note: Parallel subagent dispatch requires Task tool support"
echo "Current implementation will document the architecture for future enhancement"
echo ""
echo "Expected workflow:"
echo "  1. Clone fixture to .worktrees/test-{timestamp}-{scenario-id}/"
echo "  2. Dispatch subagent with scenario + fixture paths"
echo "  3. Subagent executes scenario verification"
echo "  4. Subagent reports PASS/FAIL"
echo "  5. Orchestrator aggregates results"
echo ""
```

### Step 6: Aggregate Results

**For initial implementation:** Document expected result aggregation:

```bash
echo "========================================="
echo "Test Results Summary"
echo "========================================="
echo ""

# This is the INTENDED implementation:
# PASSED=0
# FAILED=0
# TOTAL=${#SCENARIO_FILES[@]}
#
# for result in "${SUBAGENT_RESULTS[@]}"; do
#   if [[ "$result" == "PASS"* ]]; then
#     PASSED=$((PASSED + 1))
#     echo "✅ $result"
#   else
#     FAILED=$((FAILED + 1))
#     echo "❌ $result"
#   fi
# done
#
# echo ""
# echo "Results: $PASSED/$TOTAL passed"
#
# if [ "$FAILED" -gt 0 ]; then
#   echo ""
#   echo "❌ $FAILED scenario(s) failed"
#   exit 1
# else
#   echo ""
#   echo "✅ All scenarios passed!"
#   exit 0
# fi

# For now, document the architecture:
echo "Architecture defined for result aggregation:"
echo "  - Each subagent reports PASS or FAIL"
echo "  - Orchestrator collects all results"
echo "  - Summary shows X/Y passed"
echo "  - Exit code 0 if all pass, non-zero if any fail"
echo ""
echo "Implementation status: Architecture documented, awaiting Task tool integration"
echo ""
```

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

**Phase:** GREEN (Initial Implementation)

**What Works:**
- Command parsing and validation
- Test infrastructure checks
- Scenario discovery and listing
- Cleanup architecture

**What's Documented:**
- Parallel subagent dispatch architecture
- Result aggregation format
- PASS/FAIL reporting structure

**Next Steps (Future Enhancement):**
- Integrate with Task tool for true parallel dispatch
- Implement fixture cloning per scenario
- Implement result aggregation from subagents
- Add timing metrics (execution time per scenario)

**Usage Until Full Implementation:**

Use this command to:
1. Validate test infrastructure exists
2. List available scenarios
3. Understand testing architecture
4. Manually run scenarios using documented structure

Manual scenario execution:
```bash
# List scenarios
/spectacular:test execute

# Read scenario file
cat tests/scenarios/execute/parallel-stacking-2-tasks.md

# Manually verify against success criteria
# Use testing-workflows-with-subagents skill for structured verification
```

## Example Output

**Successful validation:**
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

⚠️  Note: Parallel subagent dispatch requires Task tool support
Current implementation will document the architecture for future enhancement

Expected workflow:
  1. Clone fixture to .worktrees/test-{timestamp}-{scenario-id}/
  2. Dispatch subagent with scenario + fixture paths
  3. Subagent executes scenario verification
  4. Subagent reports PASS/FAIL
  5. Orchestrator aggregates results

=========================================
Test Results Summary
=========================================

Architecture defined for result aggregation:
  - Each subagent reports PASS or FAIL
  - Orchestrator collects all results
  - Summary shows X/Y passed
  - Exit code 0 if all pass, non-zero if any fail

Implementation status: Architecture documented, awaiting Task tool integration

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
