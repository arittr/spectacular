# Test Scenario: Parallel Stacking (4 Tasks)

## Context

Testing `/spectacular:execute` with 4 independent parallel tasks - the upper edge of common parallel execution scenarios.

**Setup:**
- Feature spec with Phase 2 containing exactly 4 parallel tasks
- Tasks have no dependencies on each other
- Clean git state with git-spice initialized

**Why 4 tasks:**
- Tests scalability of stacking logic beyond 9f92a8 regression (which had 3 tasks)
- Verifies iterative stacking pattern holds for larger sets
- Upper bound of typical parallel execution (>4 usually split into phases)

## Expected Behavior

### Worktree Creation

1. Orchestrator verifies main repo location:
   ```bash
   REPO_ROOT=$(git rev-parse --show-toplevel)
   cd "$REPO_ROOT"
   ```

2. Creates 4 isolated worktrees:
   ```bash
   git worktree add .worktrees/{runid}-task-1 {runid}-main
   git worktree add .worktrees/{runid}-task-2 {runid}-main
   git worktree add .worktrees/{runid}-task-3 {runid}-main
   git worktree add .worktrees/{runid}-task-4 {runid}-main
   ```

3. All branch from current commit of `{runid}-main`

### Parallel Execution

1. Four implementation subagents work simultaneously
2. Each creates its branch:
   - Task 1: `{runid}-task-2-1-{name}`
   - Task 2: `{runid}-task-2-2-{name}`
   - Task 3: `{runid}-task-2-3-{name}`
   - Task 4: `{runid}-task-2-4-{name}`

3. Each detaches HEAD after branch creation

### Linear Stacking (Extended Sequence)

```bash
# Navigate to main worktree
cd "$REPO_ROOT/.worktrees/{runid}-main"

# Stack first branch
git checkout {runid}-task-2-1-{name}
gs branch track

# Stack second onto first
git checkout {runid}-task-2-2-{name}
gs branch track
gs upstack onto {runid}-task-2-1-{name}

# Stack third onto second
git checkout {runid}-task-2-3-{name}
gs branch track
gs upstack onto {runid}-task-2-2-{name}

# Stack fourth onto third
git checkout {runid}-task-2-4-{name}
gs branch track
gs upstack onto {runid}-task-2-3-{name}

# Verify
gs log short

# Return
cd "$REPO_ROOT"
```

**Stacking operations:** 3 `gs upstack onto` calls (N-1 for N tasks)

### Final Stack Structure

```
gs ls output:
main
└─□ {runid}-task-1-1-{name}       [Phase 1]
   └─□ {runid}-task-2-1-{name}     [Phase 2, task 1]
      └─□ {runid}-task-2-2-{name}  [Phase 2, task 2]
         └─□ {runid}-task-2-3-{name}  [Phase 2, task 3]
            └─□ {runid}-task-2-4-{name}  [Phase 2, task 4]
```

## Failure Modes

### Issue 1: Stacking Complexity Scaling

**Symptom:** Number of `gs upstack onto` calls exceeds N-1 (e.g., 4+ calls for 4 tasks)

**Root Cause:** Orchestrator retrying failed stacking attempts or using wrong approach

**Detection:**
```bash
# Count gs upstack onto operations in logs
# Should be exactly 3 for 4 tasks
```

**Impact:** Indicates stacking logic doesn't scale properly - will be worse with 5+ tasks

### Issue 2: Intermediate Stack Corruption

**Symptom:** After stacking task 3, `gs ls` shows tasks 1-2 no longer properly stacked

**Root Cause:** `gs upstack onto` applied to wrong base or wrong branch

**Detection:**
```bash
# After each stacking operation:
gs log short  # Verify chain remains intact
```

**Prevention:** Verify stack after each `gs upstack onto` before proceeding

### Issue 3: Performance Degradation

**Symptom:** Stacking 4 tasks takes significantly longer than 3 tasks (non-linear time increase)

**Root Cause:** Inefficient stacking approach (e.g., re-stacking earlier branches)

**Detection:** Time the stacking phase - should be linear in number of tasks

**Expected timing:**
- 2 tasks: ~10-15 seconds
- 3 tasks: ~15-20 seconds
- 4 tasks: ~20-25 seconds (NOT 40+ seconds)

### Issue 4: Worktree Creation Resource Issues

**Symptom:** Creating 4 worktrees fails or causes disk space warnings

**Root Cause:** Worktrees not cleaned up from previous runs, or dependencies installed in each

**Detection:**
```bash
# Before test:
git worktree list | wc -l  # Should be 1 (main repo only)

# During test:
du -sh .worktrees/*  # Should be small if dependencies not installed
```

**Prevention:** Clean worktrees before test, ensure dependencies not redundantly installed

## Success Criteria

### Scalability
- [ ] Stacking completes with exactly 3 `gs upstack onto` calls (N-1 pattern)
- [ ] Total stacking time < 30 seconds (linear scaling maintained)
- [ ] No retry attempts or experimental commands

### Correctness
- [ ] Final `gs ls` shows 5-branch linear chain (Phase 1 + 4 Phase 2 tasks)
- [ ] Each branch contains correct commit content from its task
- [ ] No branches outside the linear chain
- [ ] Zero temporary branches

### Resource Management
- [ ] All 4 worktrees created successfully
- [ ] Disk space usage reasonable (<500MB total if no dependencies)
- [ ] All 4 worktrees cleaned up successfully

### Reliability
- [ ] Test passes consistently (not flaky)
- [ ] Same command sequence works on re-run
- [ ] No manual intervention required

## Test Execution

**Using:** `testing-workflows-with-subagents` skill from spectacular

**Command:**
```bash
# In test repository with git-spice initialized
/spectacular:execute
# Provide feature spec with:
# - Phase 1: 1 task (sequential baseline)
# - Phase 2: 4 tasks (parallel - stress test)
```

**Monitoring:**
```bash
# Watch stacking efficiency:
# Count gs upstack onto commands - should be exactly 3

# Watch timing:
time /spectacular:execute
# Stacking phase should be ~20-25 seconds

# Watch intermediate state:
# After each task completes, verify gs ls shows expected structure
```

**Validation:**
```bash
# Final structure
gs ls  # 5-branch linear chain

# All branches accessible
for i in 1 2 3 4; do
  git log --oneline {runid}-task-2-$i-{name} | head -1
done

# No temporary artifacts
git branch | grep -- "-tmp$"  # Empty
git worktree list | wc -l  # Should be 1
```

## Edge Cases

### What if a task fails?

**Expected behavior:**
- Orchestrator should stop parallel execution
- Report which task failed
- Leave worktrees intact for debugging
- Do NOT attempt to stack incomplete branches

**Test:** Introduce failing test in task 3
**Result:** Execution stops, tasks 1-2 complete but not stacked, task 4 not started

### What if stacking fails mid-way?

**Expected behavior:**
- Orchestrator reports exact failure (which `gs upstack onto` failed)
- Leaves partially-stacked branches for inspection
- Provides recovery instructions

**Test:** Make task 2 branch have conflicts with task 1
**Result:** Second `gs upstack onto` fails, clear error message, recovery path shown

## Related Scenarios

- **parallel-stacking-2-tasks.md** - Minimal parallel case
- **parallel-stacking-3-tasks.md** - Standard parallel case (9f92a8 regression)
- **sequential-stacking.md** - Different stacking pattern
- **worktree-creation.md** - Worktree creation isolation test

## Performance Benchmarks

**Target timings for 4-task parallel execution:**

| Phase | Target Time | Notes |
|-------|------------|-------|
| Worktree creation | <5s | Should be instant (git operation) |
| Parallel execution | Variable | Depends on task complexity |
| Stacking | 20-25s | 3 `gs upstack onto` + verification |
| Cleanup | <5s | Worktree removal |

**If stacking exceeds 30s, investigate efficiency regression.**
