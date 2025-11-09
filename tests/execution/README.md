# Execution Tests

## Overview

Execution tests verify that spectacular commands produce the correct git state, branch structure, and worktree management. These tests run **actual git operations** to catch regressions in execution mechanics.

**What execution tests verify:**
- Branches created correctly with expected names
- Branch stacking order (linear chains)
- Worktree creation and cleanup
- File creation in correct locations
- No leftover temporary state

**What execution tests DON'T verify:**
- Agent compliance under pressure (see `tests/pressure/`)
- Documentation completeness (see `tests/scenarios/`)
- Code quality or patterns

## Running Execution Tests

### Run All Execution Tests

```bash
./tests/run-tests.sh execute --type=execution
```

### Run Specific Test

```bash
./tests/execution/execute/sequential-stacking.sh
```

### Expected Output

```
=========================================
Execution Test: Sequential Stacking
=========================================

Setting up test repo: /tmp/spectacular-test-sequential-stacking-12345
✅ Test repo created

Simulating sequential phase execution...
1. Creating main worktree...
  ✅ Worktree exists: .worktrees/abc123-main

2. Executing Task 1.1...
  ✅ Branch exists: abc123-task-1-1-create-schema

...

=========================================
Verifying Stack Structure
=========================================

Branch existence:
  ✅ Branch exists: abc123-task-1-1-create-schema
  ✅ Branch exists: abc123-task-1-2-add-migration
  ✅ Branch exists: abc123-task-1-3-update-types

Stack order:
  ✅ Stack order: abc123-task-1-1-create-schema → abc123-task-1-2-add-migration
  ✅ Stack order: abc123-task-1-2-add-migration → abc123-task-1-3-update-types

Worktree cleanup:
  ✅ Worktree count: 0 (expected: 0)

=========================================
Test Results: sequential-stacking
=========================================

Total assertions: 14
Passed: 14
Failed: 0

✅ PASS: All assertions passed
```

## Test Structure

### Test Harness Library

**Location:** `tests/execution/lib/test-harness.sh`

Provides reusable functions for:
- Setting up isolated test repos
- Verifying git state (branches, worktrees, commits)
- Creating mock specs and plans
- Asserting expected outcomes
- Cleanup after tests

**Key functions:**

```bash
# Setup/teardown
setup_test_repo "test-name"          # Creates isolated temp repo
cleanup_test_repo                     # Removes temp repo

# Git assertions
assert_branch_exists "branch-name"
assert_branch_not_exists "branch-name"
assert_worktree_exists ".worktrees/path"
assert_worktree_not_exists ".worktrees/path"
assert_worktree_count 0               # Verify cleanup
assert_stack_order "branch1" "branch2" "branch3"

# File assertions
assert_file_exists "path/to/file"
assert_file_contains "path/to/file" "search text"

# Mock data
create_mock_spec "$RUN_ID" "$FEATURE_SLUG"
create_mock_plan "$RUN_ID" "$FEATURE_SLUG" $NUM_PHASES

# Reporting
report_test_results "test-name"       # Shows pass/fail summary
```

### Writing Execution Tests

**Template:**

```bash
#!/bin/bash
set -euo pipefail

# Load test harness
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/test-harness.sh"

# Test configuration
RUN_ID="abc123"
FEATURE_SLUG="test-feature"

echo "========================================="
echo "Execution Test: Your Test Name"
echo "========================================="
echo ""

# 1. Setup test environment
setup_test_repo "your-test-name"
create_mock_spec "$RUN_ID" "$FEATURE_SLUG"
create_mock_plan "$RUN_ID" "$FEATURE_SLUG" 2

# 2. Simulate spectacular command execution
# (Create branches, worktrees, commits as orchestrator would)

# 3. Verify expected state
assert_branch_exists "$RUN_ID-task-1-1-name"
assert_worktree_count 0

# 4. Report results
report_test_results "your-test-name"
EXIT_CODE=$?

# 5. Cleanup
cleanup_test_repo

exit $EXIT_CODE
```

**Example:** See `tests/execution/execute/sequential-stacking.sh`

## Existing Tests

### Execute Command

**sequential-stacking.sh**
- Tests: Sequential phase execution with 3 tasks
- Verifies: Main worktree, natural stacking, cleanup
- Assertions: 14

**parallel-stacking-4-tasks.sh**
- Tests: Parallel phase execution with 4 tasks
- Verifies: Isolated worktrees, linear stacking (N-1 upstack), cleanup
- Assertions: ~16

## Adding New Tests

### When to Add Execution Tests

Add execution tests when:
- Creating new commands that manipulate git state
- Fixing bugs related to branching or worktrees
- Testing edge cases in stacking or cleanup logic

**Don't add execution tests for:**
- Agent behavior under pressure (use pressure tests)
- Documentation validation (use scenario tests)
- Code patterns or style

### Steps to Add Test

1. **Create test file:**
   ```bash
   touch tests/execution/execute/your-test.sh
   chmod +x tests/execution/execute/your-test.sh
   ```

2. **Use template** (see "Writing Execution Tests" above)

3. **Implement test logic:**
   - Setup: Create mock repo, specs, plans
   - Execute: Simulate command behavior
   - Verify: Assert expected git state
   - Cleanup: Remove temp repo

4. **Run test manually:**
   ```bash
   ./tests/execution/execute/your-test.sh
   ```

5. **Verify it passes:**
   - All assertions should pass
   - No leftover temp directories in `/tmp`
   - Output is clear and actionable

6. **Run full suite:**
   ```bash
   ./tests/run-tests.sh execute --type=execution
   ```

## Best Practices

### Test Isolation

- **Always use temp repos:** `setup_test_repo` creates isolated repos in `/tmp`
- **Clean up:** Always call `cleanup_test_repo` at end
- **No side effects:** Tests should not affect the main repo

### Meaningful Assertions

- **Test behaviors, not implementation:** Focus on observable git state
- **Use descriptive names:** Branch names should indicate what's being tested
- **Verify cleanup:** Always assert worktrees are removed

### Clear Output

- **Echo progress:** Use echo to show test phases
- **Use colors:** Test harness provides colored output
- **Report results:** Always call `report_test_results`

### Fast Execution

- **Minimal setup:** Create only necessary mock data
- **No network calls:** Tests should work offline
- **Quick cleanup:** Remove temp repos immediately

## Troubleshooting

### "Test repo already exists"

**Cause:** Previous test didn't clean up

**Fix:**
```bash
rm -rf /tmp/spectacular-test-*
```

### "Branch already exists"

**Cause:** Test repo wasn't isolated

**Fix:** Ensure test uses unique RUN_ID for each test

### "Worktree count mismatch"

**Cause:** Cleanup logic failed

**Debug:**
```bash
git worktree list  # In test repo
git worktree prune  # Clean stale entries
```

### "Stack order verification failed"

**Cause:** Branches weren't stacked correctly

**Debug:**
```bash
git log --graph --oneline --all  # View actual structure
```

## Integration with Test Runner

The unified test runner (`tests/run-tests.sh`) automatically discovers and runs all execution tests:

```bash
# Discover tests
find tests/execution/execute -name "*.sh" -type f

# Run each test
for test in $TESTS; do
  bash "$test"
done

# Aggregate results
./tests/aggregate-results.sh
```

Tests exit with:
- `0` if all assertions pass
- `1` if any assertion fails

## Performance

**Execution time per test:** ~1-2 seconds

- Setup: ~0.5s (git init, worktree creation)
- Execute: ~0.5s (branches, commits)
- Verify: ~0.1s (assertions)
- Cleanup: ~0.1s (rm -rf)

**Parallel execution:** Not currently implemented (would require process isolation)

## Related Testing

- **Validation tests** (`tests/scenarios/`) - Grep-based documentation validators
- **Pressure tests** (`tests/pressure/`) - RED-GREEN-REFACTOR agent compliance tests
- **Manual testing** - Testing commands in real projects

## Future Improvements

- [ ] Parallel test execution (run tests concurrently)
- [ ] Test fixtures for common setups
- [ ] More assertion helpers (commit messages, file contents)
- [ ] Coverage tracking (which branches/stacking patterns are tested)
- [ ] Performance benchmarks
