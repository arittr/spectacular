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
```

## Related Scenarios

- **parallel-stacking-3-tasks.md** - Tests 3-way parallel stacking
- **parallel-stacking-4-tasks.md** - Tests 4-way parallel stacking
- **worktree-creation.md** - Isolated test of worktree creation logic
- **cleanup-tmp-branches.md** - Isolated test of temporary branch cleanup
