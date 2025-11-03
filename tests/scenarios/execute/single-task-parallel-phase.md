# Test Scenario: Single Task in Parallel Phase

## Context

Testing `/spectacular:execute` with a degenerate edge case: a "parallel" phase containing only 1 task.

**Setup:**
- Feature spec with Phase 2 marked as parallel but containing only 1 task
- Clean git state with git-spice initialized

**Why this matters:**
- Plan decomposition might create parallel phases with 1 task
- Orchestrator shouldn't break on edge case
- Should handle gracefully (no special-case bugs)
- Stacking logic must work with N=1

## Expected Behavior

### Phase Detection

**execute.md should detect this as parallel phase:**

```bash
# From plan.md:
## Phase 2 (Parallel - 0h estimated)
- Task 1: Implement user authentication (3h)

# Parallel phase detection (has "Parallel" marker)
PHASE_TYPE="parallel"
TASK_COUNT=1
```

### Worktree Creation (Degenerate Case)

**Create single worktree:**

```bash
cd "$REPO_ROOT"

BASE_BRANCH=$(git -C .worktrees/{runid}-main branch --show-current)

# Create 1 worktree (loop runs once)
git worktree add .worktrees/{runid}-task-1 --detach "$BASE_BRANCH"
echo "✅ Created .worktrees/{runid}-task-1 (detached HEAD)"

git worktree list | grep "{runid}-task-"
# Output: .../repo/.worktrees/{runid}-task-1 (detached HEAD)
```

**No errors despite N=1.**

### Single Parallel Subagent

**Spawn 1 subagent** (still uses parallel execution pattern):

```
ROLE: Implement Task 1 in isolated worktree

WORKTREE: .worktrees/{runid}-task-1
BASE_BRANCH: {base-branch}

TASK: Implement user authentication

INSTRUCTIONS:
1. Navigate to worktree
2. Implement task
3. Run quality checks
4. Create branch: gs branch create {runid}-task-2-1-user-auth -m "..."
5. Detach HEAD: git switch --detach
```

Subagent completes successfully, creating branch.

### Stacking (Degenerate N=1)

**Stacking with single task:**

```bash
cd .worktrees/{runid}-main

# Task 1: Base of stack (only task, no upstack onto needed)
git checkout {runid}-task-2-1-user-auth
gs branch track
# No upstack onto (it's the first and ONLY task)

# Verify
gs log short
# Should show: ..previous-phase.. → task-2-1-user-auth

cd "$REPO_ROOT"
```

**Critical: Stacking loop runs once, no `gs upstack onto` called**

Pattern: For N tasks, N-1 `upstack onto` calls. For N=1, that's 0 upstack calls.

### Cleanup

**Remove single worktree:**

```bash
git worktree remove .worktrees/{runid}-task-1
# Succeeds without issue
```

### Final State

```bash
gs ls
# main
# └─□ {runid}-main
#    └─□ {runid}-task-1-1-previous-phase  [Phase 1, if exists]
#       └─□ {runid}-task-2-1-user-auth     [Phase 2, single task]
```

**Perfect linear chain despite N=1.**

## Success Criteria

### Worktree Creation
- [ ] Single worktree created successfully
- [ ] No errors about "not enough tasks" or similar
- [ ] Worktree has detached HEAD
- [ ] Created from correct base branch

### Parallel Execution
- [ ] Single subagent spawned
- [ ] Uses parallel execution pattern (isolated worktree)
- [ ] Creates branch correctly
- [ ] Detaches HEAD

### Stacking Logic
- [ ] Stacking runs without error
- [ ] Task 1 gets `gs branch track` only (no upstack onto)
- [ ] No attempts to stack onto non-existent task 0
- [ ] Verification passes (gs log short)

### Cleanup
- [ ] Single worktree removed successfully
- [ ] Branch remains accessible
- [ ] No stale worktree references

### Integration with Other Phases
- [ ] Phase 1 (if exists) chains to single-task Phase 2
- [ ] Single-task Phase 2 chains to Phase 3 (if exists)
- [ ] Overall linear chain maintained

## Failure Modes to Test

### Issue 1: Off-by-One in Stacking Loop

**Symptom:** Orchestrator tries to stack task 1 onto task 0

**Root Cause:** Loop starts at task 0 instead of task 1, or uses 1-indexed logic

**Detection:**
```bash
# Should see:
git checkout {runid}-task-2-1-user-auth
gs branch track
# (end of loop)

# Should NOT see:
gs upstack onto {runid}-task-2-0-something  # doesn't exist
```

### Issue 2: Array Bounds Error

**Symptom:** Error accessing TASK_IDS[1] when array only has TASK_IDS[0]

**Root Cause:** Stacking loop assumes at least 2 tasks

**Detection:**
```bash
# Orchestrator should handle N=1 without array out-of-bounds errors
```

### Issue 3: Skip Parallel Pattern

**Symptom:** Single task treated as sequential instead of parallel

**Root Cause:** Orchestrator special-cases N=1 to use sequential strategy

**Expected:** Should still use parallel pattern (worktree isolation) even for N=1

**Detection:**
```bash
git worktree list
# Should show: .worktrees/{runid}-task-1 (task-specific worktree)
# Should NOT show: only .worktrees/{runid}-main (sequential pattern)
```

### Issue 4: Stacking Verification Fails

**Symptom:** `gs log short` shows error or unexpected structure

**Root Cause:** Verification assumes multiple tasks in phase

**Detection:**
```bash
gs log short
# Should work fine, showing single task stacked on previous phase
```

## Edge Case Variants

### Variant A: Phase 1 has 1 task, Phase 2 has 1 parallel task

```bash
gs ls
# main
# └─□ {runid}-main
#    └─□ {runid}-task-1-1-setup    [Phase 1, sequential]
#       └─□ {runid}-task-2-1-feature [Phase 2, parallel N=1]
```

### Variant B: Multiple sequential phases, one parallel N=1 phase

```bash
gs ls
# main
# └─□ {runid}-main
#    └─□ {runid}-task-1-1-database      [Phase 1, sequential]
#       └─□ {runid}-task-2-1-feature     [Phase 2, parallel N=1]
#          └─□ {runid}-task-3-1-tests    [Phase 3, sequential]
```

### Variant C: Only phase is parallel N=1

```bash
# Entire feature is single parallel task
gs ls
# main
# └─□ {runid}-main
#    └─□ {runid}-task-1-1-feature  [Phase 1, parallel N=1]
```

## Test Execution

**Setup:**

Create plan with parallel phase containing 1 task:

```markdown
## Phase 2 (Parallel - 3h estimated)
- Task 1: Implement user authentication (3h)
  - Files: src/auth/login.ts, src/auth/middleware.ts
  - Acceptance: Login endpoint works, JWT tokens issued
```

**Execute:**

```bash
/spectacular:execute

# Should complete without errors
# Verify single worktree created and cleaned up
# Verify branch created and stacked correctly
```

## Why This Matters

**Real-world occurrence:**
- Plan decomposition might start with parallel phase, then user removes tasks
- Feature might simplify during planning to single parallel task
- Edge case should work seamlessly, not require manual workaround

**Boundary testing:**
- If N=1 breaks, likely N=2 has subtle bugs too
- Tests loop initialization and termination conditions
- Validates "N-1 upstack calls" pattern holds for all N ≥ 1

## Related Scenarios

- **parallel-stacking-2-tasks.md** - Next step up (N=2)
- **parallel-stacking-3-tasks.md** - Common case (N=3)
- **sequential-stacking.md** - Alternative: sequential phase with 1 task
