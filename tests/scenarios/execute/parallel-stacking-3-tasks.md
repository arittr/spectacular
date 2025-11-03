# Test Scenario: Parallel Stacking (3 Tasks)

## Context

Testing `/spectacular:execute` with 3 independent parallel tasks - the exact scenario from the 9f92a8 regression.

**Setup:**
- Feature spec with Phase 2 containing exactly 3 parallel tasks
- Tasks have no dependencies on each other
- Clean git state with git-spice initialized

**Why 3 tasks:**
- Replicates the exact 9f92a8 regression scenario
- Tests iterative stacking logic (task-1, then task-2 onto task-1, then task-3 onto task-2)
- Common real-world parallel execution size

**Reference:** analysis-9f92a8-stacking-issues.md - full execution log analysis

## Expected Behavior

### Worktree Creation

1. Orchestrator verifies location FIRST:
   ```bash
   REPO_ROOT=$(git rev-parse --show-toplevel)
   cd "$REPO_ROOT"  # Explicit navigation to main repo
   pwd  # Verify not in .worktrees/*
   ```

2. Creates 3 isolated worktrees:
   ```bash
   git worktree add .worktrees/{runid}-task-1 {runid}-main
   git worktree add .worktrees/{runid}-task-2 {runid}-main
   git worktree add .worktrees/{runid}-task-3 {runid}-main
   ```

3. No `-b` flag (no temporary branch creation)

### Parallel Execution

1. Three implementation subagents work simultaneously
2. Each creates branch in its worktree:
   - Task 1: `gs branch create {runid}-task-2-1-{name}`
   - Task 2: `gs branch create {runid}-task-2-2-{name}`
   - Task 3: `gs branch create {runid}-task-2-3-{name}`

3. Each detaches HEAD: `git switch --detach`

### Linear Stacking (Critical Section)

**Explicit command sequence from red-phase-findings.md:**

```bash
# Step 1: Navigate to main worktree (NOT main repo)
REPO_ROOT=$(git rev-parse --show-toplevel)
cd "$REPO_ROOT/.worktrees/{runid}-main"

# Step 2: Stack first task branch
git checkout {runid}-task-2-1-{name}
gs branch track

# Step 3: Stack second task onto first
git checkout {runid}-task-2-2-{name}
gs branch track
gs upstack onto {runid}-task-2-1-{name}

# Step 4: Stack third task onto second
git checkout {runid}-task-2-3-{name}
gs branch track
gs upstack onto {runid}-task-2-2-{name}

# Step 5: Verify stack structure
gs log short

# Step 6: Return to main repo
cd "$REPO_ROOT"
```

**Key constraints:**
- Must run from `{runid}-main` worktree, NOT main repo
- Must stack in task number order (1 → 2 → 3)
- Must verify each step succeeds before continuing

### Final Stack Structure

```
gs ls output:
main
└─□ {runid}-task-1-1-{name}       [Phase 1]
   └─□ {runid}-task-2-1-{name}     [Phase 2, parallel task 1]
      └─□ {runid}-task-2-2-{name}  [Phase 2, parallel task 2]
         └─□ {runid}-task-2-3-{name}  [Phase 2, parallel task 3]
```

**No branches should exist outside this linear chain.**

## Failure Modes

### Issue 1: Multiple Stacking Attempts (9f92a8 Regression)

**Symptom:** Orchestrator tries different approaches before succeeding:
- First attempt: `gs branch track` for all branches
- Second attempt: Various `gs upstack onto` commands
- Multiple iterations before correct stack

**Root Cause:** execute.md delegated to skill without explicit command sequence

**Reference:** red-phase-findings.md, lines 19-48

**Detection:**
- Count number of `gs upstack onto` operations
- Should be exactly 2 (not 3, 4, or more attempts)

**Prevention:** execute.md must show explicit commands inline, not delegate to skill

### Issue 2: Path Confusion (9f92a8 Issue #1)

**Symptom:**
```
fatal: cannot change to '.worktrees/{runid}-main/.worktrees/{runid}-task-1'
```

**Root Cause:** Orchestrator in `.worktrees/{runid}-main` when creating worktrees

**Reference:** analysis-9f92a8-stacking-issues.md, lines 8-23

**Detection:**
```bash
# Before worktree creation:
pwd | grep -q "\.worktrees"  # Should fail (exit 1)
```

**Prevention:** Explicit `cd "$REPO_ROOT"` before worktree creation

### Issue 3: Temporary Branch Pollution (9f92a8 Issue #2)

**Symptom:**
```
gs ls shows:
├─□ {runid}-task-2-1-{name}
├─□ {runid}-task-2-1-tmp        # Should not exist
├─□ {runid}-task-2-2-{name}
├─□ {runid}-task-2-2-tmp        # Should not exist
├─□ {runid}-task-2-3-{name}
└─□ {runid}-task-2-3-tmp        # Should not exist
```

**Root Cause:** Used `git worktree add -b {name}-tmp` creating branches

**Reference:** analysis-9f92a8-stacking-issues.md, lines 25-46

**Detection:**
```bash
git branch | grep -- "-tmp$"
```

**Prevention:** Never use `-b` flag when creating parallel task worktrees

### Issue 4: Context Switching Confusion (9f92a8 Issue #4)

**Symptom:** Stacking operations fail or require multiple attempts due to wrong directory

**Root Cause:** Unclear whether stacking should run from main repo or `{runid}-main` worktree

**Reference:** analysis-9f92a8-stacking-issues.md, lines 63-75

**Detection:**
```bash
# During stacking:
pwd | grep -q "\.worktrees/{runid}-main"  # Should succeed
```

**Prevention:** Explicit `cd .worktrees/{runid}-main` before stacking operations

## Success Criteria

### Execution Efficiency
- [ ] Worktree creation completes in single bash call (no retries)
- [ ] Stacking completes with exactly 2 `gs upstack onto` calls
- [ ] No experimental/failed git-spice commands
- [ ] Total stacking time < 30 seconds

### Correctness
- [ ] Final `gs ls` shows perfect linear chain: task-2-1 → task-2-2 → task-2-3
- [ ] Zero temporary branches (`git branch | grep -c -- "-tmp$" == 0`)
- [ ] All 3 task branches exist and are accessible
- [ ] Each branch has correct commit content from its task

### Context Management
- [ ] Worktree creation ran from main repo (verify with logs)
- [ ] Stacking ran from `{runid}-main` worktree (verify with logs)
- [ ] Orchestrator returned to main repo after stacking

### Cleanup
- [ ] All worktrees removed successfully
- [ ] Branches remain accessible in main repo after worktree removal
- [ ] `git worktree list` shows only main repo

## Test Execution

**Using:** `testing-workflows-with-subagents` skill from spectacular

**Command:**
```bash
# In test repository with git-spice initialized
/spectacular:execute
# Provide feature spec with:
# - Phase 1: 1 task (sequential baseline)
# - Phase 2: 3 tasks (parallel - the critical test)
```

**Monitoring During Execution:**
```bash
# Watch for path confusion:
# When orchestrator creates worktrees, check pwd in logs

# Watch for multiple stacking attempts:
# Count gs upstack onto commands - should be exactly 2

# Watch for temporary branches:
# git branch | grep -- "-tmp$" should always be empty
```

**Validation After Completion:**
```bash
# Stack structure
gs ls  # Should show linear 4-branch chain

# No temporary branches
git branch | grep -- "-tmp$"  # Should be empty

# Worktrees cleaned up
git worktree list  # Should show only main repo

# Branches accessible
git log --oneline {runid}-task-2-3-{name}  # Should show commits
```

## Regression Verification

This scenario directly tests the 9f92a8 regression fixes:

**Fixed issues that MUST NOT reoccur:**
1. ✅ No nested worktree creation attempts
2. ✅ No temporary branches in final stack
3. ✅ No multiple experimental stacking attempts
4. ✅ No context confusion (main repo vs worktree)

**If any of these occur, the fix is incomplete.**

## Related Scenarios

- **parallel-stacking-2-tasks.md** - Simpler 2-task baseline
- **parallel-stacking-4-tasks.md** - More complex 4-task scenario
- **sequential-stacking.md** - Sequential task stacking (different pattern)
- **worktree-creation.md** - Isolated worktree creation test
- **cleanup-tmp-branches.md** - Temporary branch cleanup test
