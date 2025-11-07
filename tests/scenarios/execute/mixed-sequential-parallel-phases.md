---
id: mixed-sequential-parallel-phases
type: integration
severity: critical
estimated_duration: 7m
requires_git_repo: true
tags: [sequential, parallel, cross-phase, stacking, phase-transitions]
---

# Test Scenario: Mixed Sequential + Parallel Phases

## Context

Testing `/spectacular:execute` with a realistic feature implementation: sequential foundation → parallel feature work → sequential integration.

**Setup:**
- Feature spec with 3 phases:
  - **Phase 1 (Sequential):** Database schema setup (1 task)
  - **Phase 2 (Parallel):** Three independent features (3 tasks)
  - **Phase 3 (Sequential):** Integration and testing (1 task)
- Clean git state with git-spice initialized

**Why this matters:**
- Real-world features often follow this pattern
- Tests stacking continuity across phase boundaries
- Verifies orchestrator switches correctly between sequential/parallel strategies
- Ensures branches form proper linear chain across all phases

## Expected Behavior

### Phase 1: Sequential Foundation (Database Schema)

**Execution:**

1. Subagent works in `{runid}-main` worktree
2. Implements database schema
3. Runs quality checks
4. Creates branch with natural stacking:
   ```bash
   cd .worktrees/{runid}-main
   git add .
   gs branch create {runid}-task-1-1-database-schema -m "[Task 1-1] Database schema"
   # Branch automatically stacks on {runid}-main
   # Subagent stays on this branch
   ```

**State after Phase 1:**
```bash
git branch | grep {runid}
# {runid}-main
# {runid}-task-1-1-database-schema  ← Current branch in {runid}-main worktree

gs ls
# main
# └─□ {runid}-main
#    └─□ {runid}-task-1-1-database-schema  ← New base for Phase 2
```

### Phase 2: Parallel Feature Work

**Execution:**

1. **Create parallel worktrees** from current state:
   ```bash
   cd "$REPO_ROOT"  # Main repo, not worktree

   # Get current branch from main worktree (should be task-1-1-database-schema)
   BASE_BRANCH=$(git -C .worktrees/{runid}-main branch --show-current)
   # BASE_BRANCH = "{runid}-task-1-1-database-schema"

   # Create 3 worktrees, all starting from Phase 1's completed work
   git worktree add .worktrees/{runid}-task-2-1 --detach "$BASE_BRANCH"
   git worktree add .worktrees/{runid}-task-2-2 --detach "$BASE_BRANCH"
   git worktree add .worktrees/{runid}-task-2-3 --detach "$BASE_BRANCH"
   ```

2. **Spawn 3 parallel subagents** (simultaneous execution)

3. Each subagent:
   - Works in isolated worktree
   - Starts from Phase 1's database schema
   - Implements independent feature
   - Creates branch: `{runid}-task-2-{N}-{name}`
   - Detaches HEAD

**State after Phase 2 (before stacking):**
```bash
git branch | grep {runid}
# {runid}-main
# {runid}-task-1-1-database-schema
# {runid}-task-2-1-user-auth
# {runid}-task-2-2-api-endpoints
# {runid}-task-2-3-frontend-ui
```

4. **Stack Phase 2 branches linearly:**
   ```bash
   cd .worktrees/{runid}-main

   # Task 2-1: Stack on Phase 1's branch
   git checkout {runid}-task-2-1-user-auth
   gs branch track
   gs upstack onto {runid}-task-1-1-database-schema

   # Task 2-2: Stack on task 2-1
   git checkout {runid}-task-2-2-api-endpoints
   gs branch track
   gs upstack onto {runid}-task-2-1-user-auth

   # Task 2-3: Stack on task 2-2
   git checkout {runid}-task-2-3-frontend-ui
   gs branch track
   gs upstack onto {runid}-task-2-2-api-endpoints

   # Leave main worktree on latest branch for Phase 3
   # (Already on {runid}-task-2-3-frontend-ui after last checkout)

   cd "$REPO_ROOT"
   ```

**State after Phase 2 stacking:**
```bash
gs ls
# main
# └─□ {runid}-main
#    └─□ {runid}-task-1-1-database-schema
#       └─□ {runid}-task-2-1-user-auth
#          └─□ {runid}-task-2-2-api-endpoints
#             └─□ {runid}-task-2-3-frontend-ui  ← Current in {runid}-main worktree
```

5. **Clean up Phase 2 worktrees:**
   ```bash
   git worktree remove .worktrees/{runid}-task-2-1
   git worktree remove .worktrees/{runid}-task-2-2
   git worktree remove .worktrees/{runid}-task-2-3
   ```

### Phase 3: Sequential Integration

**Execution:**

1. Subagent works in `{runid}-main` worktree (same as Phase 1)
2. **Current branch is `{runid}-task-2-3-frontend-ui`** (from Phase 2)
3. Implements integration tests
4. Creates branch with natural stacking:
   ```bash
   cd .worktrees/{runid}-main
   # Already on {runid}-task-2-3-frontend-ui

   git add .
   gs branch create {runid}-task-3-1-integration-tests -m "[Task 3-1] Integration tests"
   # Automatically stacks on current branch (task-2-3-frontend-ui)
   ```

**Final State:**
```bash
gs ls
# main
# └─□ {runid}-main
#    └─□ {runid}-task-1-1-database-schema      [Phase 1]
#       └─□ {runid}-task-2-1-user-auth         [Phase 2, parallel]
#          └─□ {runid}-task-2-2-api-endpoints   [Phase 2, parallel]
#             └─□ {runid}-task-2-3-frontend-ui  [Phase 2, parallel]
#                └─□ {runid}-task-3-1-integration-tests  [Phase 3]
```

Perfect linear chain across all phases! 🎉

## Verification Commands

```bash
# Verify phase transition logic from sequential → parallel
echo "=== Phase 1 → Phase 2 Transition Logic ==="
grep -n "Get current branch from main worktree" commands/execute.md skills/executing-parallel-phase/SKILL.md -A 5

# Check base branch inheritance for parallel phases
echo ""
echo "=== Base Branch Inheritance Pattern ==="
grep -n "BASE_BRANCH=" commands/execute.md skills/executing-parallel-phase/SKILL.md -A 3

# Verify cross-phase stacking (parallel branches stack linearly after completion)
echo ""
echo "=== Cross-Phase Stacking Implementation ==="
grep -n "gs upstack onto" skills/executing-parallel-phase/SKILL.md -B 2 -A 3

# Verify main worktree left on correct branch after parallel phase
echo ""
echo "=== Main Worktree State After Parallel Phase ==="
grep -n "Leave main worktree on latest branch" skills/executing-parallel-phase/SKILL.md -B 3 -A 3

# Check phase transition from parallel → sequential
echo ""
echo "=== Phase 2 → Phase 3 Transition (Natural Stacking Resumes) ==="
grep -n "gs branch create" skills/executing-sequential-phase/SKILL.md -B 2 -A 2
```

## Success Criteria

### Cross-Phase Stacking
- [ ] Phase 2 worktrees created from Phase 1's completed branch
- [ ] Phase 2 tasks build on Phase 1's code (database schema)
- [ ] Phase 3 tasks build on Phase 2's completed features
- [ ] Final stack is linear: Phase 1 → Phase 2 tasks → Phase 3

### Phase Boundary Management
- [ ] Orchestrator correctly identifies Phase 1 is sequential (no worktree creation)
- [ ] Orchestrator correctly identifies Phase 2 is parallel (creates 3 worktrees)
- [ ] Orchestrator correctly identifies Phase 3 is sequential (reuses main worktree)
- [ ] Base branch for Phase 2 is Phase 1's completed branch
- [ ] Base branch for Phase 3 is Phase 2's last stacked branch

### Worktree State Tracking
- [ ] After Phase 1: main worktree exists, on Phase 1 branch
- [ ] After Phase 2 execution: 3 parallel worktrees + main worktree
- [ ] After Phase 2 stacking: main worktree on Phase 2's last branch
- [ ] After Phase 2 cleanup: only main worktree remains
- [ ] After Phase 3: main worktree on Phase 3 branch

### Natural Stacking Preservation
- [ ] Phase 1 uses natural stacking (gs branch create on current HEAD)
- [ ] Phase 2 uses manual stacking (gs upstack onto)
- [ ] Phase 3 uses natural stacking (gs branch create on current HEAD)
- [ ] No stacking operations interfere with each other

### Final Verification
- [ ] `gs ls` shows single linear chain (no branches)
- [ ] `gs log short` shows 5 commits in order
- [ ] All branches accessible from main repo
- [ ] No orphaned branches or worktrees

## Evidence of PASS

### Phase Transitions Execute Correctly
- [ ] Phase 1 (sequential) completes, leaving main worktree on `{runid}-task-1-1-database-schema`
- [ ] Phase 2 (parallel) base branch detection: `BASE_BRANCH={runid}-task-1-1-database-schema`
- [ ] Phase 2 worktrees created from Phase 1's branch (verified with `git log` in worktree)
- [ ] Phase 2 stacking completes, leaving main worktree on `{runid}-task-2-3-frontend-ui`
- [ ] Phase 3 (sequential) creates branch from Phase 2's last branch automatically

### Branches Inherit Properly Across Phase Types
- [ ] `git log {runid}-task-2-1-user-auth` shows Phase 1 database commit in history
- [ ] `git log {runid}-task-2-2-api-endpoints` shows Phase 1 database + Phase 2 task-1 commits
- [ ] `git log {runid}-task-2-3-frontend-ui` shows Phase 1 database + Phase 2 task-1 + task-2 commits
- [ ] `git log {runid}-task-3-1-integration-tests` shows all Phase 1 + Phase 2 commits in history

### Linear Stack Maintained Across Phase Types
- [ ] `gs ls` output shows perfect linear chain (no branches):
  ```
  main
  └─□ {runid}-main
     └─□ {runid}-task-1-1-database-schema      [Phase 1 sequential]
        └─□ {runid}-task-2-1-user-auth         [Phase 2 parallel]
           └─□ {runid}-task-2-2-api-endpoints   [Phase 2 parallel]
              └─□ {runid}-task-2-3-frontend-ui  [Phase 2 parallel]
                 └─□ {runid}-task-3-1-integration-tests  [Phase 3 sequential]
  ```
- [ ] No branching structure (all tasks in single chain)
- [ ] Each branch parent is previous task's branch
- [ ] Sequential tasks naturally stack on current HEAD
- [ ] Parallel tasks manually stacked linearly after execution

### Worktree State Consistent
- [ ] After Phase 1: Only `{runid}-main` worktree exists, on Phase 1 branch
- [ ] During Phase 2: 4 worktrees total (main + 3 parallel task worktrees)
- [ ] After Phase 2 cleanup: Only `{runid}-main` worktree exists, on Phase 2 last branch
- [ ] After Phase 3: Only `{runid}-main` worktree exists, on Phase 3 branch
- [ ] Main worktree never removed during execution

### Verification Commands Succeed
- [ ] `git branch | grep {runid}` shows all 5 task branches + main branch
- [ ] `git worktree list` shows only `{runid}-main` after completion
- [ ] `gs log short` shows 5 commits in linear order
- [ ] `git log --oneline --graph --all` shows no branching structure

## Evidence of FAIL

### Phase Transitions Broken
- [ ] Phase 2 worktrees created from `{runid}-main` instead of Phase 1's branch
- [ ] Phase 2 tasks missing Phase 1's database commit in history
- [ ] Phase 3 branch stacks on Phase 1, skipping Phase 2 entirely
- [ ] Base branch detection returns wrong branch (e.g., `main` instead of task branch)

### Branches Don't Inherit Properly
- [ ] `git log {runid}-task-2-1-user-auth` missing Phase 1 database commit
- [ ] Phase 2 tasks have different base commits (not all from same Phase 1 branch)
- [ ] Phase 3 task missing Phase 2 feature commits in history
- [ ] Commit counts differ between parallel branches (should be identical base + 1)

### Stack Becomes Non-Linear
- [ ] `gs ls` shows branching structure:
  ```
  └─□ {runid}-task-1-1-database-schema
     ├─□ {runid}-task-2-1-user-auth        ← All branch from Phase 1
     ├─□ {runid}-task-2-2-api-endpoints
     └─□ {runid}-task-2-3-frontend-ui
  ```
- [ ] Phase 2 tasks not stacked linearly (all branch directly from Phase 1)
- [ ] Phase 3 branch orphaned or on wrong base
- [ ] `gs log short` shows non-linear history

### Worktree State Inconsistent
- [ ] Main worktree removed during Phase 2 cleanup
- [ ] Main worktree left on wrong branch after Phase 2 (e.g., Phase 1 branch)
- [ ] Parallel worktrees not cleaned up (4 worktrees after completion)
- [ ] Orphaned worktrees in `.worktrees/` directory

### Verification Commands Fail
- [ ] `git worktree list` shows missing or extra worktrees
- [ ] `gs ls` shows branching or orphaned branches
- [ ] Branch count mismatch (missing or extra branches)
- [ ] Commits not in linear order

## Failure Modes to Test

### Issue 1: Phase 2 Doesn't Build on Phase 1

**Symptom:** Phase 2 worktrees created from `{runid}-main` instead of Phase 1's branch

**Root Cause:** Orchestrator doesn't track current branch in main worktree

**Detection:**
```bash
# After Phase 2 execution:
cd .worktrees/{runid}-task-2-1
git log --oneline -5
# Should show Phase 1's database schema commit at HEAD~N
# If wrong, only shows {runid}-main base without Phase 1 work
```

### Issue 2: Phase 3 Doesn't Build on Phase 2

**Symptom:** Phase 3 branch stacks on Phase 1, skipping Phase 2

**Root Cause:** Main worktree not left on Phase 2's last branch after stacking

**Detection:**
```bash
# After Phase 2 stacking:
cd .worktrees/{runid}-main
git branch --show-current
# Should be: {runid}-task-2-3-frontend-ui
# NOT: {runid}-task-1-1-database-schema
```

### Issue 3: Branched Stack (Not Linear)

**Symptom:** Final stack shows Phase 2 tasks branching from Phase 1, not linear

**Root Cause:** Phase 2 stacking doesn't use `gs upstack onto` to force linear chain

**Detection:**
```bash
gs ls
# Wrong (branched):
# └─□ {runid}-task-1-1-database-schema
#    ├─□ {runid}-task-2-1-user-auth        ← All branch from Phase 1
#    ├─□ {runid}-task-2-2-api-endpoints
#    └─□ {runid}-task-2-3-frontend-ui
#
# Correct (linear):
# └─□ {runid}-task-1-1-database-schema
#    └─□ {runid}-task-2-1-user-auth
#       └─□ {runid}-task-2-2-api-endpoints
#          └─□ {runid}-task-2-3-frontend-ui
```

### Issue 4: Worktree Cleanup Before Next Phase

**Symptom:** Phase 3 can't execute because main worktree was cleaned up

**Root Cause:** Cleanup step removes all worktrees including main

**Detection:**
```bash
# After Phase 2 cleanup:
ls .worktrees/
# Should show: {runid}-main
# Should NOT be empty
```

## Test Execution

**Using:** Manual execution with 3-phase plan

**Command:**
```bash
# Create plan with:
# - Phase 1: 1 sequential task (database)
# - Phase 2: 3 parallel tasks (features)
# - Phase 3: 1 sequential task (integration)

/spectacular:execute

# Verify after each phase:
# - Phase 1: Check branch created, worktree state
# - Phase 2: Check 3 branches, linear stack, cleanup
# - Phase 3: Check final linear chain
```

## Related Scenarios

- **sequential-stacking.md** - Tests pure sequential phases
- **parallel-stacking-3-tasks.md** - Tests pure parallel phase
- **task-failure-recovery.md** - Tests error handling in mixed phases
