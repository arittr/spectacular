# Test Scenario: Worktree Creation (Isolated)

## Context

Isolated test of worktree creation logic from `/spectacular:execute`, independent of stacking or task execution.

**Setup:**
- Git repository with git-spice initialized
- Existing `{runid}-main` worktree and branch
- Clean working directory in main repo
- 3 parallel tasks ready for worktree creation

**Purpose:**
- Test ONLY the worktree creation phase
- Verify correct paths, no nesting, no temporary branches
- Isolate this concern from stacking and execution complexity

**Reference:** analysis-9f92a8-stacking-issues.md, Issue #1 (path confusion)

## Expected Behavior

### Pre-Conditions Verification

```bash
# Step 1: Verify current location
pwd
# Expected: /path/to/main/repo (NOT .worktrees/*)

# Step 2: Verify main repo is repo root
REPO_ROOT=$(git rev-parse --show-toplevel)
[ "$(pwd)" = "$REPO_ROOT" ]
# Expected: Success (exit code 0)

# Step 3: Verify main worktree exists
[ -d .worktrees/{runid}-main ]
# Expected: Directory exists

# Step 4: Verify main branch exists
git show-ref --verify refs/heads/{runid}-main
# Expected: Success (branch exists)
```

### Worktree Creation

```bash
# Navigate to repo root (defensive, even if already there)
cd "$REPO_ROOT"

# Create worktrees for 3 parallel tasks
git worktree add .worktrees/{runid}-task-1 {runid}-main
git worktree add .worktrees/{runid}-task-2 {runid}-main
git worktree add .worktrees/{runid}-task-3 {runid}-main
```

**Critical constraints:**
- NO `-b` flag (don't create temporary branches)
- All worktrees branch from `{runid}-main` branch
- All worktrees under `.worktrees/` directory in main repo

### Post-Creation Verification

```bash
# Step 1: Verify all worktrees exist
git worktree list
# Expected output:
# /path/to/repo                  <commit> [main]
# /path/to/repo/.worktrees/{runid}-main  <commit> [{runid}-main]
# /path/to/repo/.worktrees/{runid}-task-1  <commit> (detached HEAD)
# /path/to/repo/.worktrees/{runid}-task-2  <commit> (detached HEAD)
# /path/to/repo/.worktrees/{runid}-task-3  <commit> (detached HEAD)

# Step 2: Verify worktree paths are correct (NOT nested)
git worktree list | grep -c "\.worktrees/.*\.worktrees"
# Expected: 0 (no nested paths)

# Step 3: Verify no temporary branches created
git branch | grep -- "-tmp$"
# Expected: Empty output

# Step 4: Verify each worktree is at correct commit
cd .worktrees/{runid}-task-1 && git rev-parse HEAD
cd .worktrees/{runid}-task-2 && git rev-parse HEAD
cd .worktrees/{runid}-task-3 && git rev-parse HEAD
# Expected: All show same commit hash (tip of {runid}-main)

# Step 5: Verify main repo still accessible
cd "$REPO_ROOT"
git status
# Expected: Clean working directory
```

## Failure Modes

### Issue 1: Nested Worktree Creation (9f92a8 Regression)

**Symptom:**
```bash
git worktree list shows:
/path/to/repo/.worktrees/{runid}-main/.worktrees/{runid}-task-1
```

**Root Cause:** Command ran from `.worktrees/{runid}-main` instead of main repo

**9f92a8 Error:**
```
fatal: cannot change to '/path/to/repo/.worktrees/{runid}-main/.worktrees/{runid}-task-1': No such file or directory
```

**Detection:**
```bash
# Check worktree paths
git worktree list | grep "\.worktrees/.*\.worktrees"
# Should be empty
```

**Prevention:**
```bash
# Before worktree creation:
REPO_ROOT=$(git rev-parse --show-toplevel)
CURRENT_DIR=$(pwd)
if [ "$CURRENT_DIR" != "$REPO_ROOT" ]; then
  echo "❌ Must run from main repo, not worktree"
  echo "Current: $CURRENT_DIR"
  echo "Expected: $REPO_ROOT"
  exit 1
fi
```

### Issue 2: Temporary Branch Creation

**Symptom:**
```bash
git branch shows:
{runid}-main
{runid}-task-1-tmp
{runid}-task-2-tmp
{runid}-task-3-tmp
```

**Root Cause:** Used `git worktree add -b {name}-tmp` creating branches

**9f92a8 Impact:** Temporary branches appeared in final stack, polluting `gs ls` output

**Detection:**
```bash
git branch | grep -- "-tmp$"
```

**Prevention:** Never use `-b` flag when creating parallel task worktrees

### Issue 3: Wrong Base Branch

**Symptom:** Worktrees created from `main` instead of `{runid}-main`

**Root Cause:** Forgot to specify branch in `git worktree add` command

**Detection:**
```bash
# Each worktree should be at {runid}-main commit
MAIN_COMMIT=$(git rev-parse {runid}-main)
for i in 1 2 3; do
  WORKTREE_COMMIT=$(git -C .worktrees/{runid}-task-$i rev-parse HEAD)
  [ "$WORKTREE_COMMIT" = "$MAIN_COMMIT" ] || echo "Task $i wrong commit"
done
```

**Prevention:** Always specify `{runid}-main` explicitly in worktree add command

### Issue 4: Worktree Directory Collision

**Symptom:**
```
fatal: '.worktrees/{runid}-task-1' already exists
```

**Root Cause:** Previous test run didn't clean up worktrees

**Detection:**
```bash
# Before test:
ls -d .worktrees/{runid}-task-* 2>/dev/null
# Should be empty
```

**Prevention:**
```bash
# Clean up before test:
git worktree remove .worktrees/{runid}-task-1 2>/dev/null || true
git worktree remove .worktrees/{runid}-task-2 2>/dev/null || true
git worktree remove .worktrees/{runid}-task-3 2>/dev/null || true
git worktree prune
```

## Success Criteria

### Path Correctness
- [ ] All worktrees under `.worktrees/` in main repo
- [ ] No nested paths (`.worktrees/*/.worktrees/*`)
- [ ] Worktree creation command ran from main repo root

### Branch State
- [ ] No temporary branches created (`git branch | grep -c -- "-tmp$" == 0`)
- [ ] All worktrees at same commit (tip of `{runid}-main`)
- [ ] Main branch (`{runid}-main`) unchanged

### Worktree Registration
- [ ] `git worktree list` shows 4 entries (main + main worktree + 3 task worktrees)
- [ ] All paths absolute and correct
- [ ] Git recognizes all worktrees (no corruption)

### Isolation
- [ ] Each worktree has independent working directory
- [ ] Changes in one worktree don't affect others
- [ ] Main repo unaffected by worktree creation

## Test Execution

**Manual test:**
```bash
# Setup
cd /path/to/test/repo
gs repo init
git checkout -b test-main
mkdir -p .worktrees
git worktree add .worktrees/test-main test-main

# Test worktree creation
RUNID="test"
REPO_ROOT=$(git rev-parse --show-toplevel)
cd "$REPO_ROOT"

git worktree add .worktrees/${RUNID}-task-1 test-main
git worktree add .worktrees/${RUNID}-task-2 test-main
git worktree add .worktrees/${RUNID}-task-3 test-main

# Verify
git worktree list
git branch | grep -- "-tmp$"
```

**Automated test (via subagent):**
```bash
# Using testing-workflows-with-subagents skill
# Provide this scenario file
# Subagent should execute commands and verify success criteria
```

## Cleanup

```bash
# Remove worktrees
git worktree remove .worktrees/{runid}-task-1
git worktree remove .worktrees/{runid}-task-2
git worktree remove .worktrees/{runid}-task-3

# Prune stale entries
git worktree prune

# Verify cleanup
git worktree list  # Should not show task-* worktrees
ls .worktrees/  # Should not contain task-* directories
```

## Integration with Full Workflow

This isolated test feeds into:

1. **parallel-stacking-2-tasks.md** - Uses 2 worktrees
2. **parallel-stacking-3-tasks.md** - Uses 3 worktrees (9f92a8 scenario)
3. **parallel-stacking-4-tasks.md** - Uses 4 worktrees

**If this isolated test fails, all parallel stacking scenarios will fail.**

## Reference Commands

**View worktree details:**
```bash
git worktree list --porcelain
# Shows:
# - worktree path
# - HEAD commit
# - branch (if any)
```

**Check worktree health:**
```bash
git worktree list
git worktree prune --dry-run  # Show what would be pruned
```

**Debug nested paths:**
```bash
git worktree list | awk '{print $1}' | grep "\.worktrees" | grep -c "\.worktrees/.*\.worktrees"
# Should output: 0
```

## Related Scenarios

- **parallel-stacking-3-tasks.md** - Full workflow using these worktrees
- **cleanup-tmp-branches.md** - Related cleanup concern
- All parallel stacking scenarios depend on this working correctly
