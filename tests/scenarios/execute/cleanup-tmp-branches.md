---
id: cleanup-tmp-branches
type: integration
severity: major
duration: 3m
tags: [cleanup, branches, worktrees, obsolete]
status: obsolete
---

# Test Scenario: Cleanup Temporary Branches

## ⚠️ SCENARIO OBSOLETE

**Status:** This scenario tests a defensive cleanup feature that was removed (2025-11-03).

**Decision:** Trust the implementation. If `git worktree add --detach` is used correctly, no `-tmp` branches are ever created. Defensive cleanup adds complexity for a bug that shouldn't exist.

**What this tested:**
- Cleanup of temporary branches created by incorrect use of `-b` flag
- Defensive programming against implementation drift

**Why removed:**
- execute.md is too long; defensive checks add bloat
- Correct implementation (`--detach` flag) prevents the issue entirely
- If subagents hallucinate wrong git commands, the failure should surface naturally

**If this becomes a problem again:** Add the cleanup back, but only after seeing real evidence of `-tmp` branch pollution in production usage.

---

## Original Context (for reference)

Isolated test of temporary branch cleanup after parallel task execution completes.

**Setup:**
- 3 parallel tasks completed successfully
- Each task created its proper branch (e.g., `{runid}-task-2-1-{name}`)
- Temporary branches exist from worktree creation (if using wrong pattern)
- Worktrees still exist but branches have been created

**Purpose:**
- Verify temporary branches are identified and removed
- Ensure proper branches remain untouched
- Test cleanup doesn't break stack structure

**Reference:** analysis-9f92a8-stacking-issues.md, Issue #2 (temporary branch pollution)

## Expected Behavior

### Scenario A: No Temporary Branches (Ideal)

**If worktrees created correctly:**
```bash
git worktree add .worktrees/{runid}-task-1 {runid}-main  # No -b flag
git worktree add .worktrees/{runid}-task-2 {runid}-main  # No -b flag
git worktree add .worktrees/{runid}-task-3 {runid}-main  # No -b flag
```

**Then:**
```bash
git branch | grep -- "-tmp$"
# Expected: Empty output (no temporary branches to clean)
```

**Action:** Skip cleanup, proceed to stacking

### Scenario B: Temporary Branches Exist (Wrong Pattern)

**If worktrees created with `-b` flag (WRONG):**
```bash
git worktree add -b {runid}-task-1-tmp .worktrees/{runid}-task-1 {runid}-main
git worktree add -b {runid}-task-2-tmp .worktrees/{runid}-task-2 {runid}-main
git worktree add -b {runid}-task-3-tmp .worktrees/{runid}-task-3 {runid}-main
```

**Then temporary branches exist:**
```bash
git branch shows:
{runid}-main
{runid}-task-1-tmp
{runid}-task-2-1-{name}      # Real branch from task 1
{runid}-task-2-2-{name}      # Real branch from task 2
{runid}-task-2-3-{name}      # Real branch from task 3
{runid}-task-2-tmp
{runid}-task-3-tmp
```

**Cleanup required:**
```bash
# Identify temporary branches (pattern: {runid}-task-*-tmp)
TMP_BRANCHES=$(git branch | grep -E "\s+${RUNID}-task-[0-9]+-tmp$" | tr -d ' ')

# Delete each temporary branch
for BRANCH in $TMP_BRANCHES; do
  git branch -D "$BRANCH"
  echo "Deleted temporary branch: $BRANCH"
done

# Verify cleanup
git branch | grep -- "-tmp$"
# Expected: Empty output
```

### Post-Cleanup Verification

```bash
# Verify real branches remain
git branch | grep "${RUNID}-task-2-1"  # Should exist
git branch | grep "${RUNID}-task-2-2"  # Should exist
git branch | grep "${RUNID}-task-2-3"  # Should exist

# Verify no temporary branches
git branch | grep -- "-tmp$"  # Should be empty

# Verify branches are accessible
git log --oneline {runid}-task-2-1-{name} -1  # Shows commit
git log --oneline {runid}-task-2-2-{name} -1  # Shows commit
git log --oneline {runid}-task-2-3-{name} -1  # Shows commit
```

## Failure Modes

### Issue 1: Temporary Branches Not Cleaned (9f92a8 Regression)

**Symptom:**
```bash
gs ls shows:
├─□ {runid}-task-2-1-{name}
├─□ {runid}-task-2-1-tmp        # Should be deleted
├─□ {runid}-task-2-2-{name}
├─□ {runid}-task-2-2-tmp        # Should be deleted
```

**Root Cause:** No cleanup step in execute.md, or cleanup pattern doesn't match

**9f92a8 Impact:** Final stack polluted with temporary branches

**Detection:**
```bash
git branch | grep -c -- "-tmp$"
# Expected: 0
# 9f92a8 actual: 3
```

**Fix:** Add explicit cleanup step after parallel execution, before stacking

### Issue 2: Wrong Branch Deleted

**Symptom:** Real branch deleted, temporary branch remains

**Root Cause:** Cleanup pattern too broad or wrong naming

**Example wrong pattern:**
```bash
# DON'T DO THIS:
git branch -D $(git branch | grep "task-1")  # Too broad!
# Would delete both task-1-tmp AND task-1-database-schema
```

**Prevention:**
```bash
# Correct pattern - match ONLY tmp suffix:
git branch | grep -E "\s+${RUNID}-task-[0-9]+-tmp$"
```

### Issue 3: Cleanup Before Stacking

**Symptom:** Cleanup runs, then stacking fails because branches gone

**Root Cause:** Cleanup happened before task branches created

**Timeline:**
1. ❌ Create worktrees with `-b tmp`
2. ❌ Clean up tmp branches
3. ❌ Start parallel tasks
4. ❌ Tasks try to create branches but worktrees in inconsistent state

**Prevention:** Cleanup must run AFTER tasks complete, BEFORE stacking

### Issue 4: Cleanup Breaks Worktrees

**Symptom:**
```
fatal: 'checkout' cannot be used with updating worktrees
```

**Root Cause:** Deleted branch that a worktree is still checked out to

**Prevention:**
```bash
# Before deleting branch:
git worktree list | grep "$BRANCH"
# If branch is checked out in worktree, skip deletion or remove worktree first
```

## Success Criteria

### Identification
- [ ] Cleanup correctly identifies temporary branches (only `-tmp` suffix)
- [ ] Cleanup does NOT identify real task branches
- [ ] Pattern works for any `{runid}` value

### Deletion
- [ ] All temporary branches deleted successfully
- [ ] No real branches deleted
- [ ] No git errors during deletion

### Verification
- [ ] `git branch | grep -- "-tmp$"` returns empty
- [ ] All real task branches still exist and accessible
- [ ] Stack structure unchanged (if stacking already done)

### Integration
- [ ] Cleanup happens at correct time in workflow (after tasks, before stacking)
- [ ] Worktrees can be removed after cleanup
- [ ] Stacking proceeds normally after cleanup

## Test Execution

### Isolated Test (Scenario B)

```bash
# Setup: Create temporary branches manually
RUNID="test"
git branch ${RUNID}-task-1-tmp
git branch ${RUNID}-task-2-1-database  # Real branch
git branch ${RUNID}-task-2-tmp
git branch ${RUNID}-task-2-2-api       # Real branch
git branch ${RUNID}-task-3-tmp
git branch ${RUNID}-task-2-3-ui        # Real branch

# Test cleanup
TMP_BRANCHES=$(git branch | grep -E "\s+${RUNID}-task-[0-9]+-tmp$" | tr -d ' ')
for BRANCH in $TMP_BRANCHES; do
  git branch -D "$BRANCH"
done

# Verify
git branch | grep -- "-tmp$"  # Should be empty
git branch | grep "${RUNID}-task-2-"  # Should show 3 real branches
```

### Integration Test

**Using:** Full parallel execution workflow (parallel-stacking-3-tasks.md)

**Inject wrong pattern:**
```bash
# Modify execute.md temporarily to use -b flag:
git worktree add -b ${RUNID}-task-1-tmp .worktrees/${RUNID}-task-1 ${RUNID}-main
```

**Verify cleanup fixes it:**
```bash
# After parallel execution completes:
# Cleanup should delete tmp branches
# Final gs ls should show only real branches in stack
```

## Correct Workflow Pattern

**To avoid needing cleanup at all:**

```bash
# ✅ Correct: No -b flag, no temporary branches
git worktree add .worktrees/{runid}-task-1 {runid}-main
git worktree add .worktrees/{runid}-task-2 {runid}-main
git worktree add .worktrees/{runid}-task-3 {runid}-main

# Each worktree starts at {runid}-main commit
# Implementation subagents create real branches when ready:
# (in each worktree)
gs branch create {runid}-task-2-{N}-{name}

# Result: Only real branches exist, no cleanup needed
```

**Why this is better:**
- No cleanup step needed
- No temporary branch pollution
- Simpler workflow
- Fewer edge cases

## Cleanup Command Reference

**Safe cleanup pattern:**
```bash
# List temporary branches first (dry run)
git branch | grep -E "\s+${RUNID}-task-[0-9]+-tmp$"

# Delete if any found
TMP_BRANCHES=$(git branch | grep -E "\s+${RUNID}-task-[0-9]+-tmp$" | tr -d ' ')
if [ -n "$TMP_BRANCHES" ]; then
  for BRANCH in $TMP_BRANCHES; do
    git branch -D "$BRANCH"
    echo "Deleted: $BRANCH"
  done
fi

# Verify
git branch | grep -- "-tmp$" || echo "No temporary branches remain"
```

**Regex breakdown:**
- `\s+` - Leading whitespace (git branch output format)
- `${RUNID}-task-` - Prefix (only this run's branches)
- `[0-9]+` - Task number (e.g., 1, 2, 3)
- `-tmp$` - Exactly "-tmp" at end (not "-tmp-something")

## Related Scenarios

- **worktree-creation.md** - Tests that temporary branches aren't created in first place
- **parallel-stacking-3-tasks.md** - Full workflow where this cleanup runs
- All parallel stacking scenarios should verify no temporary branches in final state

## Prevention vs Cleanup

**Better strategy: Prevention**

Update execute.md to NEVER create temporary branches:
- Don't use `-b` flag in `git worktree add`
- Worktrees start detached or at base branch
- Implementation subagents create real branches when ready

**Fallback: Cleanup**

If temporary branches somehow get created:
- Detect them after parallel execution
- Delete before stacking
- Log warning that prevention failed

**Long-term goal: Make cleanup unnecessary by fixing worktree creation pattern.**

---

## Verification Commands

Run these commands after parallel phase execution to verify cleanup behavior:

```bash
# 1. Check for any temporary branches with -tmp suffix
git branch | grep -- "-tmp$"
# Expected (PASS): Empty output (no temporary branches)
# Expected (FAIL): Shows branches like {runid}-task-1-tmp, {runid}-task-2-tmp

# 2. List all branches for this run to verify real branches exist
RUNID="your-run-id"  # Replace with actual run ID
git branch | grep "^  ${RUNID}-task-"
# Expected (PASS): Shows only real task branches (e.g., {runid}-task-2-1-database-schema)
# Expected (FAIL): Shows mix of real branches and -tmp branches

# 3. Count temporary branches to confirm none exist
git branch | grep -c -- "-tmp$"
# Expected (PASS): 0
# Expected (FAIL): 3 (or number of parallel tasks)

# 4. Verify all real task branches are accessible
git branch | grep "${RUNID}-task-2-" | while read -r branch; do
  branch=$(echo "$branch" | tr -d ' *')
  git log --oneline "$branch" -1 || echo "ERROR: Branch $branch not accessible"
done
# Expected (PASS): Shows commit for each real branch
# Expected (FAIL): Errors or missing commits

# 5. Check worktree list for any stale temporary branches
git worktree list | grep -- "-tmp"
# Expected (PASS): Empty output
# Expected (FAIL): Shows worktrees still checked out to temporary branches

# 6. Verify git-spice stack shows clean structure
gs ls | grep -- "-tmp"
# Expected (PASS): Empty output (no temporary branches in stack)
# Expected (FAIL): Shows temporary branches in stack structure

# 7. Confirm cleanup didn't delete wrong branches
git branch | grep "${RUNID}-task-2-[1-9]-" | wc -l
# Expected (PASS): Number matches parallel task count
# Expected (FAIL): Less than expected (cleanup deleted real branches)
```

---

## Evidence of PASS

If cleanup logic works correctly (or temporary branches never created), you'll see:

**1. No temporary branches exist:**
```bash
$ git branch | grep -- "-tmp$"
# (empty output)

$ git branch | grep -c -- "-tmp$"
0
```

**2. All real task branches present and accessible:**
```bash
$ git branch | grep "abc123-task-2-"
  abc123-task-2-1-database-schema
  abc123-task-2-2-api-endpoints
  abc123-task-2-3-ui-components

$ git log --oneline abc123-task-2-1-database-schema -1
a1b2c3d feat: implement database schema
```

**3. Clean git-spice stack:**
```bash
$ gs ls
◆ abc123-main
├─□ abc123-task-2-1-database-schema
├─□ abc123-task-2-2-api-endpoints
└─□ abc123-task-2-3-ui-components
# (no -tmp branches visible)
```

**4. No worktrees checked out to temporary branches:**
```bash
$ git worktree list | grep -- "-tmp"
# (empty output)
```

**5. Correct branch count:**
```bash
$ git branch | grep "abc123-task-2-[1-9]-" | wc -l
3
# Matches number of parallel tasks
```

**6. Clean removal of all temporary artifacts:**
```bash
$ git branch --list "*-tmp"
# (empty output)

$ git worktree list
/Users/user/project         abc123-main
# (no temporary worktrees listed)
```

---

## Evidence of FAIL

If cleanup logic fails or wasn't run, you'll see:

**1. Temporary branches still exist:**
```bash
$ git branch | grep -- "-tmp$"
  abc123-task-1-tmp
  abc123-task-2-tmp
  abc123-task-3-tmp

$ git branch | grep -c -- "-tmp$"
3
# Should be 0
```

**2. Polluted git-spice stack:**
```bash
$ gs ls
◆ abc123-main
├─□ abc123-task-2-1-database-schema
├─□ abc123-task-2-1-tmp              # ❌ Should be deleted
├─□ abc123-task-2-2-api-endpoints
├─□ abc123-task-2-2-tmp              # ❌ Should be deleted
├─□ abc123-task-2-3-ui-components
└─□ abc123-task-2-3-tmp              # ❌ Should be deleted
```

**3. Worktrees still reference temporary branches:**
```bash
$ git worktree list
/Users/user/project                    abc123-main
/Users/user/project/.worktrees/abc123-task-1  abc123-task-1-tmp  # ❌ Should be detached or removed
```

**4. Cleanup deleted wrong branches:**
```bash
$ git branch | grep "abc123-task-2-"
  abc123-task-2-tmp
  abc123-task-2-tmp
  abc123-task-2-tmp
# ❌ Real branches gone, tmp branches remain

$ git log --oneline abc123-task-2-1-database-schema -1
fatal: ambiguous argument 'abc123-task-2-1-database-schema': unknown revision
# ❌ Real branch was deleted
```

**5. Incomplete cleanup:**
```bash
$ git branch | grep -- "-tmp$"
  abc123-task-2-tmp
  abc123-task-3-tmp
# ❌ Some but not all temporary branches remain

$ git branch | grep "abc123-task-2-[1-9]-" | wc -l
2
# ❌ Expected 3, one real branch was deleted
```

**6. Stale worktree associations:**
```bash
$ git worktree list | grep -- "-tmp" | wc -l
3
# ❌ Should be 0, worktrees still checked out to temporary branches

$ git branch -d abc123-task-1-tmp
error: Cannot delete branch 'abc123-task-1-tmp' checked out at '/Users/user/project/.worktrees/abc123-task-1'
# ❌ Can't delete because worktree association not cleaned up
```
