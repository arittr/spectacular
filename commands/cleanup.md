---
description: Remove main worktree for a completed feature with safety checks
---

You are cleaning up a main worktree after feature work is complete.

## Purpose

This command safely removes main worktrees (`.worktrees/main-{runId}/`) after work is complete or abandoned. It includes comprehensive safety checks to prevent accidental data loss and user confirmation before deletion.

**Key behaviors:**
- Checks for uncommitted changes
- Checks for unpushed branches
- Handles orphaned worktrees (no spec.md inside)
- Preserves all {runId}-* branches in main repo
- Requires user confirmation before deletion

## Workflow

### Step 1: Parse and Validate runId

Extract runId from command arguments:

```
Command format: /spectacular:cleanup {runId}

Example: /spectacular:cleanup a1b2c3
```

**Validation:**
- If runId not provided: error "Usage: /spectacular:cleanup {runId}"
- RunId should be 6 characters (but don't enforce length strictly - accept what user provides)

### Step 2: Verify Worktree Exists

Check if the worktree exists:

```bash
# List all worktrees and check for main-{runId}
git worktree list | grep ".worktrees/main-{runId}"
```

**If not found:**
```
❌ Worktree for runId {runId} not found

No worktree exists at .worktrees/main-{runId}/

To see all worktrees:
  git worktree list

To see all branches for this runId:
  git branch | grep '{runId}-'
```

Then exit - nothing to clean up.

### Step 3: Check if Orphaned

An orphaned worktree has no spec inside (execution never started or spec was removed):

```bash
# Check if spec exists inside worktree
find .worktrees/main-{runId}/specs -name "spec.md" 2>/dev/null
```

**If no spec.md found:**
- Mark worktree as **orphaned**
- Skip safety checks (Steps 4-5)
- Go directly to Step 6 with simplified summary

**Rationale:** Orphaned worktrees indicate incomplete setup or manual cleanup already done. Safety checks would fail or be meaningless.

### Step 4: Safety Checks (Non-Orphaned Worktrees Only)

Change into worktree and run safety checks:

```bash
cd .worktrees/main-{runId}/
```

#### Check 4a: Uncommitted Changes

```bash
# Count uncommitted files
UNCOMMITTED=$(git status --porcelain | wc -l | tr -d ' ')

if [ "$UNCOMMITTED" -gt 0 ]; then
  echo "⚠️  WARNING: $UNCOMMITTED uncommitted file(s)"
  echo ""
  echo "Modified files:"
  git status --porcelain
else
  echo "✅ No uncommitted changes"
fi
```

#### Check 4b: List Branches

```bash
# Find all branches for this runId
echo ""
echo "Branches for {runId}:"
git branch | grep "^  {runId}-"
```

**If no branches found:**
```
ℹ️  No branches created yet (spec-only worktree)
```

#### Check 4c: Check Branch Push Status

For each branch found, check if it has been pushed:

```bash
# For each branch
for BRANCH in $(git branch | grep "^  {runId}-" | tr -d ' '); do
  echo ""
  echo "Branch: $BRANCH"

  # Switch to branch temporarily (detached HEAD state)
  git checkout -q "$BRANCH" 2>/dev/null

  # Check if upstream exists
  if git rev-parse @{u} > /dev/null 2>&1; then
    # Upstream exists - check for unpushed commits
    UNPUSHED=$(git log @{u}.. --oneline | wc -l | tr -d ' ')

    if [ "$UNPUSHED" -gt 0 ]; then
      echo "  ⚠️  $UNPUSHED unpushed commit(s)"
      echo ""
      git log @{u}.. --oneline | sed 's/^/  /'
    else
      echo "  ✅ Fully pushed"
    fi
  else
    # No upstream - never pushed
    COMMIT_COUNT=$(git log --oneline | wc -l | tr -d ' ')
    echo "  ⚠️  Never pushed ($COMMIT_COUNT local commit(s))"
  fi
done

# Return to original state
git checkout -q --detach 2>/dev/null
```

**Critical:** Use `git rev-parse @{u}` to check if upstream exists BEFORE trying `git log @{u}..`. This prevents errors for branches that were never pushed.

### Step 5: Build Summary

Compile information for user confirmation:

```bash
cd /path/to/main/repo  # Return to main repo
```

**For non-orphaned worktrees:**

```
========================================
Cleanup Summary for runId: {runId}
========================================

Worktree to delete: .worktrees/main-{runId}/

Status:
  - Uncommitted changes: {N files | none}
  - Branches: {N branches | none}
  - Unpushed branches: {list | none}
  - Never pushed: {list | none}

After deletion:
  ✅ All {runId}-* branches remain accessible in main repo
  ✅ You can still view branches with: git branch | grep '{runId}-'
  ✅ You can still check out branches with: git checkout {runId}-...

What will be deleted:
  ❌ Working directory at .worktrees/main-{runId}/
  ❌ Any uncommitted changes in worktree

What will NOT be deleted:
  ✅ All {runId}-* branches
  ✅ All commits on those branches
  ✅ Spec at specs/{runId}-*/
```

**For orphaned worktrees:**

```
========================================
Cleanup Summary for runId: {runId}
========================================

Worktree to delete: .worktrees/main-{runId}/

Status:
  ⚠️  Orphaned worktree (no spec.md found inside)

This appears to be an incomplete or manually cleaned worktree.
Safety checks skipped.

What will be deleted:
  ❌ Working directory at .worktrees/main-{runId}/

What will NOT be deleted:
  ✅ Any {runId}-* branches in main repo
  ✅ Any specs in main repo
```

### Step 6: User Confirmation

Use AskUserQuestion to confirm deletion:

```
Question: "Proceed with cleanup of .worktrees/main-{runId}/?"

Options:
1. "Delete worktree" - Proceed with deletion (show consequences clearly)
2. "Abort" - Cancel cleanup

Context:
{Include key summary points from Step 5}
```

**If user selects "Abort":**
```
❌ Cleanup aborted - worktree preserved

Worktree location: .worktrees/main-{runId}/
To inspect: cd .worktrees/main-{runId}/
```

Then exit.

### Step 7: Execute Deletion

**If user confirms, proceed with deletion:**

```bash
# Try git worktree remove first (clean removal)
echo "Removing worktree..."

if git worktree remove .worktrees/main-{runId} 2>/dev/null; then
  echo "✅ Worktree removed cleanly"
else
  # Fallback: manual removal + prune (for orphaned/locked worktrees)
  echo "⚠️  git worktree remove failed - using fallback"
  echo "   This is normal for orphaned or locked worktrees"
  echo ""

  rm -rf .worktrees/main-{runId}
  git worktree prune

  echo "✅ Worktree removed via fallback (rm -rf + prune)"
fi
```

**Why fallback is needed:**
- `git worktree remove` fails if worktree is "locked" or has issues
- Orphaned worktrees often trigger this
- Manual removal (`rm -rf`) + `git worktree prune` handles all cases

### Step 8: Report Completion

```
========================================
✅ Cleanup Complete
========================================

Deleted: .worktrees/main-{runId}/

Branches remain accessible:
  git branch | grep '{runId}-'

To view branches:
  git branch -a | grep '{runId}'

To check out a branch:
  git checkout {runId}-task-1-1-...

Next steps:
  - Review branches: git log {runId}-... --oneline
  - Submit PRs: gs stack submit (if using git-spice)
  - Delete local branches: git branch -d {runId}-... (after merged)

========================================
```

## Safety Features

### 1. Never Delete Without Confirmation
- User MUST explicitly confirm via AskUserQuestion
- Show clear consequences before asking
- Abort should be default/easy option

### 2. Warn About Data Loss
- Count uncommitted changes
- List unpushed branches with commit counts
- Check upstream existence before `git log @{u}..`
- Mark branches without upstream as "never pushed"

### 3. Handle Edge Cases
- Orphaned worktrees (no spec.md inside)
- Worktrees with no branches (spec-only)
- Branches never pushed (no upstream)
- Locked/corrupted worktrees (fallback removal)

### 4. Preserve Branches
- All {runId}-* branches remain in main repo
- User can still check them out
- User can still view history
- User can still push to remote

## Superpowers Integration

Reference these superpowers skills for patterns:

### `finishing-a-development-branch`
Use branch status patterns:
- Checking upstream with `git rev-parse @{u}`
- Checking unpushed commits with `git log @{u}..`
- Handling branches without upstream

### `verification-before-completion`
Use verification patterns:
- Check push status before claiming "all pushed"
- Run `git status --porcelain` to verify clean state
- Evidence before assertions (show actual output)

## Example Usage

**Cleanup after successful execution:**
```
> /spectacular:cleanup a1b2c3

Verifying worktree...
✅ Worktree found: .worktrees/main-a1b2c3/

Running safety checks...
✅ No uncommitted changes

Branches for a1b2c3:
  a1b2c3-task-1-1-skill-implementation
  a1b2c3-task-2-1-setup-command

Branch: a1b2c3-task-1-1-skill-implementation
  ✅ Fully pushed

Branch: a1b2c3-task-2-1-setup-command
  ⚠️  2 unpushed commit(s)
  abc1234 Add command structure
  def5678 Fix validation logic

[User confirms deletion after reviewing]

✅ Cleanup Complete
```

**Cleanup orphaned worktree:**
```
> /spectacular:cleanup x1y2z3

Verifying worktree...
✅ Worktree found: .worktrees/main-x1y2z3/

⚠️  Orphaned worktree (no spec.md found inside)
Safety checks skipped.

[User confirms deletion]

⚠️  git worktree remove failed - using fallback
✅ Worktree removed via fallback (rm -rf + prune)
```

## Common Scenarios

### Spec-only worktree (never executed)
- No branches created
- Summary shows "No branches created yet"
- Safe to delete - no code written

### Partial execution (some tasks done)
- Some branches exist
- Check each branch push status
- Warn about unpushed work

### Fully executed and merged
- All branches pushed
- All branches merged (user verified separately)
- Safe to delete - all work preserved

### Abandoned work
- Uncommitted changes present
- Unpushed branches present
- User must decide if work is worth preserving

## Anti-Patterns to Avoid

**❌ Don't skip upstream check:**
```bash
# WRONG - fails if no upstream
git log @{u}.. --oneline
```

**✅ Do check upstream first:**
```bash
# RIGHT - check before using @{u}
if git rev-parse @{u} > /dev/null 2>&1; then
  git log @{u}.. --oneline
fi
```

**❌ Don't delete without confirmation:**
```bash
# WRONG - no user input
rm -rf .worktrees/main-{runId}
```

**✅ Do use AskUserQuestion:**
```
# RIGHT - explicit confirmation
Use AskUserQuestion to confirm deletion
Only proceed if user selects "Delete"
```

**❌ Don't assume branches are gone:**
- Worktree deletion does NOT delete branches
- Branches persist in main repo
- Document this clearly to user

## Error Handling

### Worktree not found
```
❌ Worktree for runId {runId} not found

Check existing worktrees:
  git worktree list
```

### Git worktree remove fails
```
⚠️  git worktree remove failed - using fallback

This is normal for orphaned or locked worktrees.
Using: rm -rf + git worktree prune
```

### User aborts
```
❌ Cleanup aborted

Worktree preserved at: .worktrees/main-{runId}/
```

Now execute the cleanup workflow.
