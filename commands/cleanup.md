---
description: Remove all worktrees for a spectacular run
---

# /spectacular:cleanup

Remove all worktrees for a specific spectacular run, preserving branches.

## Command Syntax

```
/spectacular:cleanup {runId}
```

**Parameters:**

- `runId` - The 6-character run identifier (e.g., `dedf14`)

**Example:**

```
/spectacular:cleanup dedf14
```

## What This Does

Removes all worktrees associated with a specific spectacular run:

- Main worktree: `.worktrees/{runId}-main`
- Task worktrees: `.worktrees/{runId}-task-*`

**Important:** This only removes working directories. Branches are preserved in `.git` and remain accessible.

## When to Use

**Use this command when:**

- Execution completed and you want to free disk space
- Resuming failed and you want clean start
- Multiple runs finished and you're cleaning up old worktrees
- You want to inspect branches without worktree directories

**Don't use when:**

- Execution is still in progress (parallel tasks may be using worktrees)
- You want to resume from where you left off (keeps main worktree for resume)
- You want to delete branches (this only removes worktrees, use `git branch -D` for branches)

## The Process

### Step 1: Validate runId format

**Verify runId is 6-character hash:**

```bash
echo "{runId}" | grep -E '^[a-f0-9]{6}$'
```

If invalid:

```
ERROR: Invalid runId format: {runId}
Expected: 6-character hexadecimal (e.g., dedf14)
```

### Step 2: Announce skill usage

"I'm using the managing-worktrees skill to clean up worktrees for run {runId}."

### Step 3: List worktrees to remove

**Find all worktrees for this run:**

```bash
git worktree list | grep "{runId}"
```

**Expected output:**

```
/path/to/repo/.worktrees/dedf14-main  abc123 [branch-name]
/path/to/repo/.worktrees/dedf14-task-1-1  def456 (detached HEAD)
/path/to/repo/.worktrees/dedf14-task-2-1  ghi789 (detached HEAD)
```

If no worktrees found:

```
No worktrees found for runId: {runId}

Possible reasons:
- Run hasn't been executed yet
- Worktrees already cleaned up
- Wrong runId specified

Check available worktrees:
git worktree list
```

### Step 4: Create TodoWrite checklist

**REQUIRED for multi-worktree cleanup:**

```markdown
Cleanup worktrees for {runId}:

- [ ] Verify in main repo: pwd shows /path/to/repo
- [ ] List worktrees to remove: git worktree list | grep "{runId}"
- [ ] Count: {count} worktrees to remove
- [ ] Verify task worktrees have detached HEAD (not branch names)
- [ ] Remove each worktree from main repo
- [ ] Verify worktrees removed: git worktree list | grep "{runId}" shows nothing
- [ ] Verify branches still exist: git branch -v | grep "{runId}" shows all branches
- [ ] Prune stale entries: git worktree prune
```

**Why required:** Per `managing-worktrees` skill Pattern 3, TodoWrite prevents skipping verification steps under time pressure.

### Step 5: Delegate to skill Pattern 4

**Use `managing-worktrees` skill Pattern 4 for cleanup:**

**Critical verification before removal:**

1. **Verify in main repo:**

```bash
pwd  # Should be /path/to/repo (NOT in a worktree)
```

2. **Verify task worktrees have detached HEAD:**

```bash
git worktree list | grep "{runId}-task"
# Each should show "(detached HEAD)" not a branch name
```

If any worktree shows a branch name:

```
ERROR: Worktree {path} has branch checked out
Task subagent failed to detach HEAD (git switch --detach)

Fix:
cd {path}
git switch --detach
cd /path/to/repo

Then retry cleanup.
```

3. **List branches before removal (for verification after):**

```bash
git branch -v | grep "{runId}"
# Save this list to verify branches still accessible after cleanup
```

**Remove worktrees:**

```bash
# Remove task worktrees first
git worktree remove ./.worktrees/{runId}-task-1-1
git worktree remove ./.worktrees/{runId}-task-2-1
# etc for all task worktrees

# Remove main worktree last
git worktree remove ./.worktrees/{runId}-main
```

**Verify removal:**

```bash
# Worktrees gone
git worktree list | grep "{runId}"
# Should return nothing

# Directories removed
ls -la .worktrees/ | grep "{runId}"
# Should return nothing

# Branches still accessible
git branch -v | grep "{runId}"
# Should still show all branches
```

**Prune stale entries:**

```bash
git worktree prune
```

### Step 6: Report completion

**Success report:**

```
Cleanup complete for runId: {runId}

Worktrees removed:
- .worktrees/{runId}-main
- .worktrees/{runId}-task-1-1
- .worktrees/{runId}-task-2-1

Branches preserved (still accessible):
- {runId}-task-1-1-description
- {runId}-task-2-1-description

Total worktrees removed: {count}
Disk space freed: ~{estimate}MB

Next steps:
- View branches: git branch -v | grep "{runId}"
- Delete branches: git branch -D {branch-name}
- Submit stack: gs stack submit (from any branch in the stack)
```

## Error Handling

### Error: Invalid runId format

**Cause:** runId is not 6-character hexadecimal

**Recovery:**

1. Check runId in spec directory: `ls specs/`
2. runId is first part before hyphen: `{runId}-{feature-slug}`
3. Retry with correct runId

### Error: No worktrees found

**Cause:** No worktrees exist for this runId

**Recovery:**

1. List all worktrees: `git worktree list`
2. Verify runId is correct
3. If worktrees already cleaned, no action needed
4. If run never executed, no worktrees to clean

### Error: Worktree has uncommitted changes

**Cause:** Worktree is dirty (uncommitted changes)

**Recovery:**

1. `cd .worktrees/{runId}-main`
2. `git status` to see changes
3. Choose:
   - Commit changes: `git add . && git commit -m "message"`
   - Stash changes: `git stash`
   - Discard changes: `git reset --hard` (destructive)
4. Return to main repo: `cd ../..`
5. Retry cleanup

### Error: Worktree has branch checked out

**Cause:** Task worktree didn't detach HEAD (subagent forgot `git switch --detach`)

**Recovery:**

1. `cd .worktrees/{runId}-task-{phase}-{task}`
2. `git switch --detach`
3. `cd /path/to/repo`
4. Retry cleanup

### Error: Branch not accessible after cleanup

**Cause:** Branch was deleted or not properly created before worktree removal

**Recovery:**

1. Check if branch exists: `git branch -v | grep "{branch-name}"`
2. If missing, check reflog: `git reflog | grep "{branch-name}"`
3. If in reflog, recover: `git branch {branch-name} {commit-hash}`
4. If not in reflog, branch was never created (implementation failed)

### Error: Permission denied removing worktree

**Cause:** Process has files open in worktree, or permission issue

**Recovery:**

1. Close any editors/terminals in that worktree
2. Kill processes: `lsof +D .worktrees/{runId}-* | grep -v COMMAND | awk '{print $2}' | xargs kill`
3. Check permissions: `ls -ld .worktrees/{runId}-*`
4. Retry cleanup
5. If still fails, force remove: `git worktree remove --force ./.worktrees/{runId}-*`

## Common Mistakes

### Mistake 1: Running cleanup during execution

```bash
# ❌ WRONG: Cleanup while parallel tasks running
/spectacular:cleanup dedf14
# ERROR: Worktree in use

# ✅ CORRECT: Wait for execution to complete
# Let /spectacular:execute finish or cancel it first
```

**Why it matters:** Active tasks lose their working directories, execution fails.

### Mistake 2: Expecting branches to be deleted

```bash
# ❌ WRONG EXPECTATION: Cleanup deletes branches
/spectacular:cleanup dedf14
git branch | grep "dedf14"
# Branches still exist (this is correct!)

# ✅ CORRECT: Cleanup removes worktrees, not branches
/spectacular:cleanup dedf14  # Removes working directories
git branch -D dedf14-task-1-1  # Separate command to delete branch if desired
```

**Why it matters:** Cleanup is non-destructive. Use `git branch -D` to delete branches.

### Mistake 3: Trying to clean worktree you're inside of

```bash
# ❌ WRONG: cd into worktree, try to clean it
cd .worktrees/dedf14-main
/spectacular:cleanup dedf14
# ERROR: Can't remove worktree you're inside

# ✅ CORRECT: Run from main repo
cd /path/to/repo
/spectacular:cleanup dedf14
```

**Why it matters:** Can't remove directory you're currently in.

### Mistake 4: Not verifying branches before removing worktrees

```bash
# ❌ WRONG: Remove without checking branches exist
git worktree remove ./.worktrees/dedf14-main
# Branches might not be accessible

# ✅ CORRECT: Verify branches first
git branch -v | grep "dedf14"  # Confirm all branches exist
git worktree remove ./.worktrees/dedf14-main
git branch -v | grep "dedf14"  # Confirm still accessible
```

**Why it matters:** Ensures work isn't lost if branches weren't created properly.

## Integration

**Used after:**

- `/spectacular:execute` - After feature complete, to clean up workspace
- Failed runs - To reset and start fresh

**References:**

- `managing-worktrees` skill - All worktree operations follow patterns from this skill
- Pattern 4 specifically - Final cleanup workflow

**Example workflow:**

```bash
# 1. Execute feature
/spectacular:execute

# 2. Feature complete, tests pass, code review done
# Main worktree still exists at .worktrees/dedf14-main

# 3. Clean up worktrees
/spectacular:cleanup dedf14

# 4. Branches still exist for submission
git branch | grep "dedf14"
gs stack submit
```

## Testing

To test this command:

**Test 1: Clean up after execution**

```bash
# Setup
cd /tmp/test-repo
git init
git commit --allow-empty -m "Initial"
git worktree add .worktrees/test01-main main
git worktree add .worktrees/test01-task-1-1 main

# Test cleanup
/spectacular:cleanup test01

# Verify
git worktree list | grep "test01"  # Should be empty
ls .worktrees/ | grep "test01"  # Should be empty
```

**Test 2: Error handling for dirty worktree**

```bash
# Setup
cd /tmp/test-repo
git worktree add .worktrees/test02-main main
cd .worktrees/test02-main
echo "test" > file.txt
cd ../..

# Test cleanup (should fail)
/spectacular:cleanup test02
# Expected: ERROR about uncommitted changes

# Fix and retry
cd .worktrees/test02-main
git add . && git commit -m "test"
cd ../..
/spectacular:cleanup test02
# Expected: Success
```

**Test 3: Verify branches preserved**

```bash
# Setup
cd /tmp/test-repo
git worktree add .worktrees/test03-main main
cd .worktrees/test03-main
git checkout -b test03-task-1-1
git switch --detach
cd ../..

# Test cleanup
git branch | grep "test03"  # Branch exists
/spectacular:cleanup test03
git branch | grep "test03"  # Branch still exists

# Verify
git worktree list | grep "test03"  # Worktree gone
git branch | grep "test03"  # Branch still there
```
