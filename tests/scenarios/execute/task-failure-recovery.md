# Test Scenario: Task Failure Recovery

## Context

Testing `/spectacular:execute` error handling when a task fails mid-execution in a parallel phase.

**Setup:**
- Feature spec with Phase 2 containing 3 parallel tasks
- Task 2 will fail (simulated test failure, lint error, or implementation bug)
- Tasks 1 and 3 should succeed
- Clean git state with git-spice initialized

**Why this matters:**
- Real-world tasks fail frequently (tests, bugs, missing dependencies)
- Orchestrator must handle partial completion gracefully
- Must enable resume without losing completed work
- Must report failure clearly with actionable context

## Expected Behavior

### Initial Execution

**Phase 2 Parallel Execution:**

1. Orchestrator creates 3 worktrees:
   ```bash
   git worktree add .worktrees/{runid}-task-1 --detach {runid}-main
   git worktree add .worktrees/{runid}-task-2 --detach {runid}-main
   git worktree add .worktrees/{runid}-task-3 --detach {runid}-main
   ```

2. Spawns 3 parallel subagents

3. **Task 1 completes successfully:**
   - Creates branch `{runid}-task-2-1-{name}`
   - Commits changes
   - Detaches HEAD
   - Reports success

4. **Task 2 FAILS:**
   - Attempts implementation
   - Quality check fails (tests fail with exit code 1)
   - Reports failure with error details
   - Leaves worktree in failed state

5. **Task 3 completes successfully:**
   - Creates branch `{runid}-task-2-3-{name}`
   - Commits changes
   - Detaches HEAD
   - Reports success

### Error Detection & Reporting

**Orchestrator behavior when collecting results:**

```bash
# Collect subagent results
TASK_1_STATUS="success"
TASK_2_STATUS="failed"  # ← Failure detected
TASK_3_STATUS="success"

# Check for failures
if [[ "$TASK_2_STATUS" == "failed" ]]; then
  echo "❌ Phase 2 failed: Task 2 did not complete successfully"
  echo ""
  echo "Failed task: Task 2 - {task-name}"
  echo "Error: {error-message-from-subagent}"
  echo ""
  echo "Completed tasks:"
  echo "  ✅ Task 1 - {task-name}"
  echo "  ✅ Task 3 - {task-name}"
  echo ""
  echo "Next steps:"
  echo "1. Review error output above"
  echo "2. Fix the issue in .worktrees/{runid}-task-2"
  echo "3. Re-run /spectacular:execute to resume"
  exit 1
fi
```

**Critical: Do NOT proceed to stacking if any task failed**

### State After Failure

**Git state:**
```bash
git branch | grep {runid}
# {runid}-main
# {runid}-task-2-1-{name}  ← Task 1 succeeded
# {runid}-task-2-3-{name}  ← Task 3 succeeded
# (no branch for task-2, it failed)

git worktree list
# /.../repo/.worktrees/{runid}-main
# /.../repo/.worktrees/{runid}-task-1  (detached HEAD)
# /.../repo/.worktrees/{runid}-task-2  (detached HEAD) ← Failed state
# /.../repo/.worktrees/{runid}-task-3  (detached HEAD)
```

**Working state:**
- `.worktrees/{runid}-task-1`: Clean, branch created
- `.worktrees/{runid}-task-2`: Contains partial changes, no branch created
- `.worktrees/{runid}-task-3`: Clean, branch created

### Resume After Fix

**User fixes the issue:**

```bash
cd .worktrees/{runid}-task-2
# Fix the bug/test/lint issue manually
git add .
gs branch create {runid}-task-2-2-{name} -m "[Task 2-2] {task-name}"
git switch --detach
cd ../..
```

**Then re-run execute command:**

```bash
/spectacular:execute
```

**Resume behavior (Step 0c in execute.md):**

```bash
# Check for existing work
git branch | grep "^  {runid}-task-"

# Detect completed tasks:
# ✅ {runid}-task-2-1-{name} exists → Task 1 already done
# ✅ {runid}-task-2-2-{name} exists → Task 2 NOW done (fixed)
# ✅ {runid}-task-2-3-{name} exists → Task 3 already done

# All tasks complete, skip to stacking
echo "Resuming from partial completion..."
echo "All parallel tasks complete, proceeding to stacking"
```

Orchestrator jumps to Step 6 (stacking), skipping worktree creation and task execution.

### Stacking After Resume

Execute stacking as normal:

```bash
cd .worktrees/{runid}-main

git checkout {runid}-task-2-1-{name}
gs branch track

git checkout {runid}-task-2-2-{name}
gs branch track
gs upstack onto {runid}-task-2-1-{name}

git checkout {runid}-task-2-3-{name}
gs branch track
gs upstack onto {runid}-task-2-2-{name}

gs log short
# Should show: task-2-1 → task-2-2 → task-2-3 (linear)

cd "$REPO_ROOT"
```

## Success Criteria

### Error Detection
- [ ] Orchestrator detects task failure from subagent report
- [ ] Execution stops immediately (no stacking attempted)
- [ ] Clear error message with failed task name and reason
- [ ] Exit code is non-zero (failure)

### Partial State Preservation
- [ ] Successful task branches exist in git
- [ ] Failed task worktree preserved (not cleaned up)
- [ ] Successful task worktrees preserved
- [ ] No corruption of {runid}-main branch

### Error Reporting
- [ ] Shows which tasks succeeded
- [ ] Shows which task failed with details
- [ ] Provides actionable next steps
- [ ] Includes failed task worktree path for debugging

### Resume Capability
- [ ] Step 0c detects existing branches correctly
- [ ] Skips already-completed tasks
- [ ] Proceeds to stacking when all tasks complete
- [ ] No re-execution of successful tasks

### Worktree Cleanup After Resume
- [ ] After successful stacking, all worktrees removed
- [ ] All branches remain accessible
- [ ] No stale worktree references

## Failure Modes to Test

### Issue 1: Stacking Despite Failure

**Symptom:** Orchestrator attempts to stack even though task failed

**Root Cause:** Missing failure check between task execution and stacking

**Detection:**
```bash
# Should NOT see stacking attempt if task failed
# Should exit with error before reaching stacking step
```

### Issue 2: Lost Work on Resume

**Symptom:** Re-running execute re-executes successful tasks, losing work

**Root Cause:** Step 0c doesn't check for existing task branches

**Detection:**
```bash
git log {runid}-task-2-1-{name}
# Should show original commit, not duplicate
```

### Issue 3: Failed Task Cleanup

**Symptom:** Failed task's worktree cleaned up, can't debug

**Root Cause:** Cleanup runs even on failure

**Detection:**
```bash
ls .worktrees/
# Should still have {runid}-task-2 directory for debugging
```

### Issue 4: Unclear Error Messages

**Symptom:** Error says "Task failed" but doesn't specify which one or why

**Root Cause:** Poor error aggregation from parallel subagents

**Detection:**
```bash
# Error output should clearly identify:
# - Which task failed (Task 2)
# - What the error was (test failure, specific test name)
# - Where to find details (.worktrees/{runid}-task-2)
```

## Test Execution

**Using:** Manual execution with simulated failure

**Command:**
```bash
# In test repository with 3-task parallel plan
/spectacular:execute

# Simulate failure in task 2:
# - Let task 1 and 3 complete
# - Make task 2 fail (exit with error code)

# Verify:
# 1. Execution stops with clear error
# 2. Tasks 1 and 3 have branches
# 3. Task 2 worktree still exists
# 4. Can fix and resume
```

## Related Scenarios

- **sequential-stacking.md** - Tests error handling in sequential phases
- **quality-check-failure.md** - Tests specific quality check failures
- **resume-after-crash.md** - Tests resume after orchestrator crash (not just task failure)
