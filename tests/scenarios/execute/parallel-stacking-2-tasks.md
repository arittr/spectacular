---
id: parallel-stacking-2-tasks
type: integration
severity: major
duration: 3m
tags: [parallel-execution, git-stacking, git-spice, worktrees]
---

# Test Scenario: Parallel Stacking (2 Tasks)

## Context

Testing `/spectacular:execute` with the simplest parallel execution case: exactly 2 independent tasks in Phase 2.

**Setup:**
- Feature spec with Phase 1 (1 sequential task) and Phase 2 (2 parallel tasks)
- Tasks in Phase 2 have no dependencies on each other
- Clean git state with git-spice initialized

**Why 2 tasks:**
- Minimal parallel scenario - simplest case to verify stacking logic
- Tests basic worktree creation and linear stacking
- Establishes baseline before testing more complex scenarios

## Expected Behavior

### Worktree Creation

1. Orchestrator creates 2 isolated worktrees from main repo:
   ```bash
   cd /path/to/repo  # Main repo, NOT .worktrees/{runid}-main
   git worktree add .worktrees/{runid}-task-1 --detach {runid}-main
   git worktree add .worktrees/{runid}-task-2 --detach {runid}-main
   ```

2. Each worktree has detached HEAD at current commit of `{runid}-main` branch
3. No temporary branches created (`--detach` flag ensures clean worktree state)

### Parallel Execution

1. Two implementation subagents work simultaneously in isolated worktrees
2. Each creates its own branch: `gs branch create {runid}-task-2-{N}-{name}`
3. Each detaches HEAD after branch creation: `git switch --detach`

### Linear Stacking

1. Orchestrator navigates to `{runid}-main` worktree (NOT main repo):
   ```bash
   cd .worktrees/{runid}-main
   ```

2. Stacks branches in task order:
   ```bash
   git checkout {runid}-task-2-1-{name}
   gs branch track

   git checkout {runid}-task-2-2-{name}
   gs branch track
   gs upstack onto {runid}-task-2-1-{name}
   ```

3. Verifies stack: `gs log short`

4. Returns to main repo: `cd ../../..`

### Final Stack Structure

```
gs ls output:
main
└─□ {runid}-task-1-1-{name}       [Phase 1, sequential]
   └─□ {runid}-task-2-1-{name}     [Phase 2, parallel task 1]
      └─□ {runid}-task-2-2-{name}  [Phase 2, parallel task 2]
```

## Failure Modes

### Issue 1: Nested Worktree Creation

**Symptom:**
```
fatal: cannot change to '/path/to/repo/.worktrees/{runid}-main/.worktrees/{runid}-task-1': No such file or directory
```

**Root Cause:** Orchestrator ran worktree creation from within `.worktrees/{runid}-main` instead of main repo

**Reference:** analysis-9f92a8-stacking-issues.md, Issue 1

**Detection:**
```bash
# Before worktree creation, verify:
pwd  # Should be main repo, not .worktrees/*
```

### Issue 2: Temporary Branch Pollution

**Symptom:**
```
gs ls shows:
├─□ {runid}-task-2-1-{name}
├─□ {runid}-task-2-1-tmp        # Unexpected temp branch
├─□ {runid}-task-2-2-{name}
└─□ {runid}-task-2-2-tmp        # Unexpected temp branch
```

**Root Cause:** Used `git worktree add -b {name}-tmp` creating temporary branches

**Reference:** analysis-9f92a8-stacking-issues.md, Issue 2

**Detection:**
```bash
git branch | grep -- "-tmp$"  # Should return nothing
```

### Issue 3: Wrong Stacking Context

**Symptom:** Orchestrator runs stacking commands from main repo, git-spice can't find branches

**Root Cause:** Stacking operations require being in `{runid}-main` worktree where branches were created

**Reference:** red-phase-findings.md, lines 66-75

**Detection:**
```bash
# During stacking, verify:
pwd  # Should show .worktrees/{runid}-main
```

### Issue 4: Missing HEAD Detachment

**Symptom:** Worktree cleanup fails with "branch checked out" error

**Root Cause:** Implementation subagent didn't run `git switch --detach` after creating branch

**Reference:** analysis-9f92a8-stacking-issues.md (implied from worktree cleanup issues)

**Detection:**
```bash
# In each task worktree after branch creation:
git status  # Should show "HEAD detached at <commit>"
```

## Success Criteria

### Worktree Creation
- [ ] All worktrees created in single attempt (no retry needed)
- [ ] No nested worktree paths (`.worktrees/{runid}-main/.worktrees/*`)
- [ ] No temporary branches exist (`git branch | grep -c -- "-tmp$" == 0`)

### Parallel Execution
- [ ] Both subagents complete successfully
- [ ] Each creates correct branch name: `{runid}-task-2-{N}-{name}`
- [ ] Each detaches HEAD after branch creation

### Linear Stacking
- [ ] Stacking completes in single attempt (no experimentation/retries)
- [ ] Stacking runs from `{runid}-main` worktree context
- [ ] Final `gs ls` shows linear stack: task-2-1 → task-2-2
- [ ] No orphaned branches (all branches in linear chain)

### Cleanup
- [ ] Worktrees removed successfully
- [ ] Branches remain accessible in main repo
- [ ] No temporary files/branches left behind

## Verification Commands

### Check Stacking Logic Implementation

Verify the execute command uses N-1 pattern for upstack operations:

```bash
# Search for stacking logic in execute command
cd /Users/drewritter/projects/spectacular
grep -n "upstack" commands/execute.md

# Look for N-1 pattern (for N=2 tasks, should be 1 upstack operation)
grep -A5 -B5 "task 2 through N" commands/execute.md
```

**Expected:** Stacking logic should iterate from task 2 through N, calling `gs upstack onto` for each (N-1 operations total).

### Verify Stack Structure

After execution completes, verify linear stack was created:

```bash
# Check stack topology
gs ls

# Verify all task branches exist
git branch | grep "{runid}-task-2-"

# Count upstack operations in logs (should be 1 for 2 tasks)
# Implementation subagents should show gs upstack commands
```

## Evidence of PASS

### Correct Stacking Operations

For N=2 parallel tasks, orchestrator should perform exactly **1 upstack operation**:

```bash
# Orchestrator output shows:
cd .worktrees/{runid}-main

# Task 1: Track only (base of stack)
git checkout {runid}-task-2-1-{name}
gs branch track

# Task 2: Track + upstack (N-1 = 1 upstack)
git checkout {runid}-task-2-2-{name}
gs branch track
gs upstack onto {runid}-task-2-1-{name}
```

### Linear Chain Created

```bash
gs ls output shows:
main
└─□ {runid}-task-1-1-{name}       # Phase 1
   └─□ {runid}-task-2-1-{name}     # Phase 2, task 1 (base)
      └─□ {runid}-task-2-2-{name}  # Phase 2, task 2 (stacked on task 1)
```

### Clean Execution

- No retry attempts for stacking operations
- No temporary branches left behind
- Worktrees cleaned up successfully
- All branches accessible from main repo

## Evidence of FAIL

### Wrong Number of Upstack Operations

```bash
# FAIL: Zero upstack operations (both tasks tracked but not stacked)
gs ls shows:
main
└─□ {runid}-task-1-1-{name}
   ├─□ {runid}-task-2-1-{name}     # Both branch from same base
   └─□ {runid}-task-2-2-{name}     # Not stacked linearly

# FAIL: Two upstack operations (N instead of N-1)
# Error: Task 1 has no previous task to stack onto
fatal: branch '{runid}-task-2-0-{name}' not found
```

### Non-Linear Stack

```bash
# FAIL: Orphaned branches (not in stack)
gs ls shows:
main
└─□ {runid}-task-1-1-{name}
   └─□ {runid}-task-2-1-{name}

# Task 2-2 exists but not shown (orphaned):
git branch | grep task-2-2
  {runid}-task-2-2-{name}
```

### Stacking Failed with Errors

```bash
# FAIL: Context errors
fatal: cannot change to '.worktrees/{runid}-main': No such file or directory

# FAIL: Branch not found errors
error: pathspec '{runid}-task-2-1-{name}' did not match any file(s) known to git

# FAIL: Worktree cleanup blocked
fatal: '{runid}-task-2-2-{name}' is checked out at '.worktrees/{runid}-task-2'
# (Missing HEAD detachment in implementation subagent)
```

### Retry/Experimentation Detected

```bash
# FAIL: Multiple attempts at stacking (should complete in one attempt)
# Orchestrator logs show:
Attempt 1: gs upstack onto {runid}-task-2-1-{name} [FAILED]
Retrying with different approach...
Attempt 2: git rebase {runid}-task-2-1-{name} [FAILED]
```

## Test Execution

**Using:** `testing-workflows-with-subagents` skill from spectacular

**Command:**
```bash
# In test repository with git-spice initialized
/spectacular:execute
# Follow prompts for feature with Phase 2 containing 2 parallel tasks
```

**Validation:**
```bash
# After completion:
gs ls  # Verify linear stack structure
git branch | grep -c -- "-tmp$"  # Should be 0
git worktree list  # Should only show main repo
git log --oneline --graph --all  # Verify commit relationships
```

## Related Scenarios

- **parallel-stacking-3-tasks.md** - Tests 3-way parallel stacking
- **parallel-stacking-4-tasks.md** - Tests 4-way parallel stacking
- **worktree-creation.md** - Isolated test of worktree creation logic
- **cleanup-tmp-branches.md** - Isolated test of temporary branch cleanup
