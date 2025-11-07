---
id: sequential-stacking
type: integration
severity: critical
duration: 5m
tags:
  - sequential-execution
  - git-stacking
  - git-spice
  - natural-stacking
---

# Test Scenario: Sequential Stacking

## Context

Testing `/spectacular:execute` with multiple sequential phases where each task builds on the previous task's branch.

**Setup:**
- Feature spec with 3 sequential phases (Phase 1, Phase 2, Phase 3)
- Each phase contains 1 task
- Each task depends on previous task's completion
- Clean git state with git-spice initialized

**Why sequential:**
- Different stacking pattern than parallel tasks
- Natural stacking (each task creates branch from previous)
- No worktree orchestration needed
- Tests base case that parallel execution must build upon

## Expected Behavior

### Phase 1: Foundation Task

1. Orchestrator dispatches implementation subagent
2. Subagent works in `{runid}-main` worktree
3. Subagent creates branch:
   ```bash
   git add .
   gs branch create {runid}-task-1-1-{name} -m "[Task 1.1] {description}"
   ```

4. Branch automatically stacks on current base (whatever `{runid}-main` points to)

### Phase 2: Building on Phase 1

1. Previous task's branch becomes new base for `{runid}-main` worktree
2. Orchestrator dispatches new implementation subagent
3. Subagent works in same `{runid}-main` worktree (no new worktree needed)
4. Subagent creates branch:
   ```bash
   git add .
   gs branch create {runid}-task-2-1-{name} -m "[Task 2.1] {description}"
   ```

5. Branch automatically stacks on `{runid}-task-1-1-{name}` (current HEAD)

### Phase 3: Building on Phase 2

Same pattern:
```bash
git add .
gs branch create {runid}-task-3-1-{name} -m "[Task 3.1] {description}"
```

Stacks on `{runid}-task-2-1-{name}` automatically.

### Final Stack Structure

```
gs ls output:
main
└─□ {runid}-task-1-1-{name}       [Phase 1]
   └─□ {runid}-task-2-1-{name}     [Phase 2]
      └─□ {runid}-task-3-1-{name}  [Phase 3]
```

**No manual stacking operations needed** - `gs branch create` stacks automatically on current HEAD.

## Failure Modes

### Issue 1: Orphaned Branches

**Symptom:**
```
gs ls shows:
main
├─□ {runid}-task-1-1-{name}
├─□ {runid}-task-2-1-{name}  # Should be child of task-1-1, not main
└─□ {runid}-task-3-1-{name}  # Should be child of task-2-1, not main
```

**Root Cause:** Subagent didn't check out previous task's branch before creating new branch

**Detection:**
```bash
# Before creating new branch:
git branch --show-current  # Should be previous task's branch
```

**Prevention:** Ensure `{runid}-main` worktree HEAD is at previous task's branch before starting new task

### Issue 2: Wrong Worktree Usage

**Symptom:** Orchestrator creates new worktrees for sequential tasks

**Root Cause:** Misunderstanding - sequential tasks should reuse `{runid}-main` worktree

**Detection:** Count worktrees during execution - should always be 1 (just `{runid}-main`)

**Prevention:** execute.md should explicitly state "Sequential tasks reuse main worktree"

### Issue 3: Stacking Order Confusion

**Symptom:** Task 3 stacks on Task 1, skipping Task 2

**Root Cause:** Subagent checked out wrong branch before creating new branch

**Detection:**
```bash
# Before gs branch create:
git log --oneline -1  # Should show commit from previous task
```

**Prevention:** Subagent must verify current HEAD before creating branch

### Issue 4: Manual Stacking Attempts

**Symptom:** Orchestrator runs `gs upstack onto` commands for sequential tasks

**Root Cause:** Misunderstanding - sequential tasks auto-stack, no manual stacking needed

**Detection:** Search logs for `gs upstack onto` - should NOT appear in sequential phases

**Prevention:** execute.md should clarify automatic vs manual stacking

## Success Criteria

### Simplicity
- [ ] No worktree creation beyond initial `{runid}-main` worktree
- [ ] No manual stacking operations (no `gs upstack onto`)
- [ ] Each task just runs `gs branch create` - that's it

### Correctness
- [ ] Final `gs ls` shows perfect linear chain: task-1-1 → task-2-1 → task-3-1
- [ ] Each branch parent is previous task's branch
- [ ] No orphaned branches

### Efficiency
- [ ] Total execution time is sum of task times + overhead (no extra stacking time)
- [ ] No retry attempts or corrections

### Natural Workflow
- [ ] Pattern feels natural - each task builds on previous
- [ ] Subagents don't need to think about stacking
- [ ] `gs branch create` "just works"

## Test Execution

**Using:** `testing-workflows-with-subagents` skill from spectacular

**Command:**
```bash
# In test repository with git-spice initialized
/spectacular:execute
# Provide feature spec with:
# - Phase 1: 1 task
# - Phase 2: 1 task (depends on Phase 1)
# - Phase 3: 1 task (depends on Phase 2)
```

**Monitoring:**
```bash
# Watch for unnecessary worktrees:
git worktree list  # Should only show {runid}-main throughout

# Watch for manual stacking:
# grep logs for "gs upstack onto" - should be absent

# Watch branch creation:
# Each "gs branch create" should succeed immediately
```

**Validation:**
```bash
# Stack structure
gs ls  # Should show 3-level linear chain

# Branch relationships
git log --oneline --graph --all --decorate
# Should show clear parent-child relationships

# Verify no extra worktrees
git worktree list  # Only {runid}-main
```

## Comparison: Sequential vs Parallel

### Sequential Tasks (This Scenario)

**Stacking:** Automatic - `gs branch create` stacks on current HEAD
**Worktrees:** One - reuse `{runid}-main` for all tasks
**Orchestration:** Minimal - just dispatch subagents in order
**Timing:** Serial - task N+1 waits for task N to complete

### Parallel Tasks (Other Scenarios)

**Stacking:** Manual - orchestrator runs `gs upstack onto` after tasks complete
**Worktrees:** N - one per parallel task for isolation
**Orchestration:** Complex - create worktrees, dispatch simultaneously, stack afterward
**Timing:** Parallel - all tasks run simultaneously

## Edge Cases

### What if Phase 2 task fails?

**Expected behavior:**
- Execution stops after Phase 2 failure
- Phase 1 branch exists and is complete
- Phase 3 never starts
- `{runid}-main` worktree HEAD is at Phase 2 (potentially broken)

**Recovery:**
- Fix Phase 2 code manually in `{runid}-main` worktree
- Amend Phase 2 commit or create new commit
- Resume execution from Phase 3

### What if subagent forgets to create branch?

**Expected behavior:**
- Changes committed directly to previous task's branch (wrong!)
- Next task will stack on modified previous branch
- Stack structure intact but content wrong

**Detection:**
```bash
# After each task:
git branch | grep {runid}-task-{phase}-{task}  # Should exist
```

**Prevention:** execute.md should verify branch created before moving to next task

## Related Scenarios

- **parallel-stacking-2-tasks.md** - Contrasts with parallel execution
- **parallel-stacking-3-tasks.md** - More complex parallel case
- **worktree-creation.md** - Worktree patterns (not used here)

## Key Learnings for execute.md

This scenario reveals important distinctions:

1. **Sequential ≠ Parallel stacking logic**
   - Sequential: automatic via `gs branch create`
   - Parallel: manual via `gs upstack onto`

2. **Sequential ≠ Parallel worktree usage**
   - Sequential: reuse one worktree
   - Parallel: create N worktrees

3. **execute.md must clearly distinguish these patterns**
   - Lines 200-314 (sequential) should emphasize "natural stacking"
   - Lines 380-518 (parallel) should emphasize "manual stacking afterward"

## Verification Commands

### Check for gs branch create Usage

```bash
# Search execute.md for sequential phase branch creation pattern
grep -A 5 "gs branch create" commands/execute.md | grep -B 5 "sequential"
```

**Expected:** Sequential phase section documents `gs branch create` as the only branching command needed.

### Check for Natural Stacking Documentation

```bash
# Verify execute.md explains automatic stacking for sequential phases
grep -i "natural.*stack\|automatic.*stack" commands/execute.md
```

**Expected:** Documentation explicitly states that sequential tasks stack automatically without manual commands.

### Check Sequential Phase Logic

```bash
# Verify sequential phase section doesn't mention manual stacking
grep -A 50 "Sequential Phase Execution" commands/execute.md | grep -i "upstack onto"
```

**Expected:** No results - sequential phases should NOT use `gs upstack onto`.

### Verify Stack Structure After Execution

```bash
# Check that branches form linear chain
gs ls | grep -A 3 "{runid}-task-1-1"
```

**Expected:** Output shows task-1-1 → task-2-1 → task-3-1 linear chain.

## Evidence of PASS

- [ ] execute.md sequential phase section uses `gs branch create` for automatic stacking
- [ ] No `gs upstack onto` or other manual stacking commands in sequential phase documentation
- [ ] Sequential phase section explicitly mentions "natural stacking" or "automatic stacking"
- [ ] Branches stack naturally in linear chain (verified with `gs ls`)
- [ ] Only one worktree (`{runid}-main`) used throughout sequential execution
- [ ] Each task's branch parent is the previous task's branch
- [ ] No orphaned branches on main (all tasks properly chained)
- [ ] execute.md clearly distinguishes sequential (automatic) from parallel (manual) stacking

## Evidence of FAIL

- [ ] execute.md shows `gs upstack onto` commands in sequential phase section
- [ ] Sequential phase documentation doesn't use `gs branch create`
- [ ] No mention of automatic/natural stacking in sequential phase section
- [ ] Final `gs ls` output shows tasks branching from main instead of each other
- [ ] Branches are orphaned or non-linear
- [ ] Multiple worktrees created for sequential tasks (should only be one)
- [ ] execute.md treats sequential and parallel phases identically (missing key distinction)
- [ ] Subagent instructions require manual stacking for sequential tasks
