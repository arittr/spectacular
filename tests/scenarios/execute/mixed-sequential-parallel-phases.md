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
