# Test Scenario: Meta-Testing (Test Workflow)

## Context

Testing the spectacular testing workflow (`tests/running-spectacular-tests.md`) - the tool that runs all other test scenarios.

**Setup:**
- Test fixtures exist (simple-typescript, simple-python)
- Test scenarios exist for multiple commands (execute, init, spec, plan)
- Git repository with git-spice initialized
- All Phase 1 dependencies completed

**Why meta-test:**
- Ensures test workflow can dispatch subagents correctly
- Validates test fixture cloning and isolation
- Confirms result aggregation and reporting works
- Tests error handling for missing scenarios/fixtures

## Expected Behavior

### Command Parsing

1. Parse command argument to determine scenario scope:
   ```
   "Follow tests/running-spectacular-tests.md for the execute command"   # Run only execute scenarios
   "Follow tests/running-spectacular-tests.md for the init command"      # Run only init scenarios
   "Run all spectacular test scenarios"                                   # Run all scenarios
   ```

2. If no scenarios found for specified command, report error and exit

3. Validate test fixtures exist before starting

### Fixture Cloning

1. Create temp directory for test execution:
   ```bash
   mkdir -p .worktrees/test-{timestamp}
   ```

2. Clone appropriate fixture (based on scenario requirements):
   ```bash
   cp -r tests/fixtures/simple-typescript .worktrees/test-{timestamp}/fixture
   cd .worktrees/test-{timestamp}/fixture
   git init  # Ensure fresh git state
   gs repo init  # Initialize git-spice
   ```

3. Each test gets isolated fixture clone (no shared state)

### Parallel Subagent Dispatch

1. Identify all scenarios for specified command:
   ```bash
   ls tests/scenarios/execute/*.md  # For execute command
   ```

2. Dispatch one subagent per scenario in parallel using Task tool

3. Each subagent receives:
   - Path to test fixture clone
   - Path to scenario file
   - Instructions to execute scenario using `testing-workflows-with-subagents` skill
   - Instructions to report PASS/FAIL with evidence

### Result Aggregation

1. Collect results from all subagents:
   - PASS: Scenario executed successfully, all success criteria met
   - FAIL: Scenario failed with error or unmet criteria

2. Report summary:
   ```
   Test Results: execute command
   ============================
   ✓ parallel-stacking-2-tasks.md - PASS
   ✓ parallel-stacking-3-tasks.md - PASS
   ✗ worktree-creation.md - FAIL (nested worktree detected)

   3/3 scenarios executed
   2/3 passed (66%)
   ```

3. Exit with non-zero code if any test fails

### Cleanup

1. Remove temp test directories:
   ```bash
   rm -rf .worktrees/test-*
   ```

2. Preserve test output/logs for debugging

## Failure Modes

### Issue 1: Missing Test Fixtures

**Symptom:**
```
Error: Test fixture not found at tests/fixtures/simple-typescript
```

**Root Cause:** Fixtures not created or wrong path

**Detection:**
```bash
ls tests/fixtures/  # Should show simple-typescript, simple-python
```

**Recovery:** Run Phase 1 task-1-test-fixtures to create fixtures

### Issue 2: Scenario Not Found

**Symptom:**
```
Error: No scenarios found for command 'nonexistent'
```

**Root Cause:** Invalid command argument or missing scenario directory

**Detection:**
```bash
ls tests/scenarios/{command}/  # Should exist and contain *.md files
```

**Recovery:** Report available commands and exit gracefully

### Issue 3: Subagent Dispatch Fails

**Symptom:** One or more subagents fail to start or timeout

**Root Cause:** Task tool error, resource constraints, or invalid scenario file

**Detection:** Monitor subagent execution logs

**Recovery:** Report which scenarios failed to execute and why

### Issue 4: Fixture Clone Collision

**Symptom:** Multiple tests try to use same temp directory

**Root Cause:** Timestamp collision or insufficient isolation

**Detection:**
```bash
ls .worktrees/test-*  # Should show unique directories
```

**Recovery:** Use unique identifiers (timestamp + random hash) for temp directories

### Issue 5: Incomplete Cleanup

**Symptom:** Temp directories remain after test execution

**Root Cause:** Cleanup step skipped or failed

**Detection:**
```bash
ls .worktrees/test-*  # Should return "No such file or directory"
```

**Recovery:** Run cleanup manually: `rm -rf .worktrees/test-*`

## Success Criteria

### Command Parsing
- [ ] Running the workflow for execute command runs only execute scenarios
- [ ] Running all test scenarios runs scenarios for all commands
- [ ] Invalid command name returns error and exits gracefully
- [ ] No scenarios for command returns helpful error

### Fixture Management
- [ ] Test fixtures cloned to isolated temp directories
- [ ] Each subagent gets fresh fixture clone (no shared state)
- [ ] Fixtures initialized with git and git-spice
- [ ] Temp directories use unique identifiers (no collisions)

### Subagent Dispatch
- [ ] One subagent dispatched per scenario
- [ ] Subagents run in parallel (not sequential)
- [ ] Each subagent receives correct paths and instructions
- [ ] Subagent failures don't crash entire test run

### Result Reporting
- [ ] Results aggregated from all subagents
- [ ] Summary shows X/Y passed
- [ ] PASS/FAIL clearly indicated for each scenario
- [ ] Exit code 0 if all tests pass, non-zero if any fail

### Cleanup
- [ ] Temp directories removed after test execution
- [ ] No leftover fixture clones in .worktrees/
- [ ] Test output preserved for debugging

## Test Execution

**Using:** Manual verification (cannot use testing-workflows-with-subagents for the test command itself)

**Command:**
```
# Test with single command
"Follow tests/running-spectacular-tests.md for the execute command"

# Test with all commands
"Run all spectacular test scenarios"

# Test error handling
"Follow tests/running-spectacular-tests.md for the nonexistent command"  # Should return helpful error
```

**Validation:**
```bash
# Verify fixtures were created and cleaned up
ls .worktrees/test-*  # Should show nothing after completion

# Verify exit code on failure
# Run the workflow and check if all scenarios passed

# Verify parallel execution (not sequential)
# Check logs - subagents should start simultaneously
```

## Rationalization Prevention

**Likely shortcuts to avoid:**

| Rationalization | Why It's Wrong | What to Do Instead |
|----------------|----------------|-------------------|
| "I'll test this manually once" | Manual testing won't catch all edge cases | Follow TDD: write scenario first, implement, verify |
| "Parallel dispatch is complex, run sequentially" | Sequential loses parallelization benefit | Use Task tool for parallel subagent dispatch |
| "Cleanup is optional, users can do it" | Leftover directories create confusion | Always cleanup temp directories in finally block |
| "Exit code doesn't matter" | CI/CD needs exit code to know if tests passed | Exit non-zero if any test fails |
| "One fixture clone for all tests" | Shared state causes test interference | Clone fresh fixture for each scenario |

## Related Scenarios

This is the meta-scenario - it tests the tool that runs all other scenarios. No related scenarios (circular dependency).

## Implementation Notes

**TDD Approach:**
1. **RED**: This scenario documents expected behavior - implementation doesn't exist yet
2. **GREEN**: Implement `commands/test.md` to pass this scenario
3. **REFACTOR**: Test edge cases, improve error handling, verify cleanup

**Command Structure:**
- Parse arguments
- Validate fixtures and scenarios
- Clone fixtures to temp directories
- Dispatch subagents in parallel
- Aggregate results
- Report summary
- Cleanup
- Exit with appropriate code
