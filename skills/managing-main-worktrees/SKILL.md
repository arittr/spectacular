---
name: managing-main-worktrees
description: Use when creating, verifying, or cleaning up main worktrees for Spectacular features - handles lifecycle management with mandatory prune, git-spice initialization checks, uncommitted changes handling, and orphaned worktree fallback to prevent data loss and stale references
---

# Managing Main Worktrees

## Overview

Main worktrees provide isolated execution environments for Spectacular features. This skill ensures consistent lifecycle management: cleanup stale references, create or verify worktree existence, verify git-spice initialization, and handle edge cases (orphaned worktrees, uncommitted changes).

**Core principle:** Always verify state before assuming. Git worktrees can become stale, orphaned, or inaccessible in ways that aren't obvious.

**Announce:** "I'm using managing-main-worktrees to set up the worktree environment."

## When to Use

Use this skill:
- Before creating specs (spec command Step 0.5)
- Before creating plans (plan command Step 0)
- Before executing tasks (execute command Step 0.5)
- When cleaning up completed features (cleanup command)
- Anytime you need to work in a main worktree

Do NOT use for:
- Child worktrees for parallel task execution (use `using-git-worktrees` skill from superpowers)
- Main repo operations (worktrees are for isolated Spectacular work)

## The Process

**BEFORE starting, create TodoWrite todos for each step below.**

### Step 1: Cleanup Stale References

**ALWAYS run prune first**, regardless of what you think the state is:

```bash
git worktree prune
```

**Why mandatory:** Worktrees can be deleted manually without `git worktree remove`, leaving stale entries in `.git/worktrees/`. These stale entries cause `git worktree list` to show false positives.

### Step 2: Check for Worktree Existence

```bash
git worktree list | grep ".worktrees/main-{runId}"
```

**If worktree exists:**
- Extract path from output
- Proceed to Step 3 (verify accessibility)

**If worktree does NOT exist:**
- Proceed to Step 4 (create worktree)

### Step 3: Verify Worktree Accessibility

**If worktree already exists, verify it's accessible:**

```bash
cd .worktrees/main-{runId}
pwd
```

**Verify output contains** `main-{runId}` to confirm directory change succeeded.

**If verification fails:**
- Worktree is corrupted or inaccessible
- Error: "Worktree exists but is not accessible. Run /spectacular:cleanup {runId} to remove it."
- STOP - do not proceed

**If verification succeeds:**
- Proceed to Step 5 (git-spice check)

### Step 4: Create Worktree

**Only if worktree does NOT exist:**

```bash
git worktree add --detach .worktrees/main-{runId} HEAD
```

**Why `--detach`:** Main worktrees don't correspond to a single branch. They're containers for the entire feature (spec, plan, and all task branches). Detached HEAD prevents confusion.

**After creation, verify accessibility:**

```bash
cd .worktrees/main-{runId}
pwd
```

**Verify output contains** `main-{runId}`.

### Step 5: Verify Git-Spice Initialization

**After entering worktree (create or verify), check git-spice:**

```bash
gs ls 2>/dev/null
```

**If command fails** (non-zero exit code):
```bash
gs repo init --continue-on-conflict
```

**Why mandatory:** Git-spice metadata is stored in `.git/` (shared with main repo), but worktrees can be created before git-spice is initialized or after git-spice is uninstalled/reinstalled. Always verify.

### Step 6: Report Status

Output the absolute path for user reference:

```bash
pwd  # Should output: /full/path/to/repo/.worktrees/main-{runId}
```

## Cleanup Process

**For cleanup command only** - removing worktrees after work is complete.

### Safety Checks (Non-Orphaned Worktrees)

**Before cleanup, check if worktree is orphaned:**

```bash
ls .worktrees/main-{runId}/specs/{runId}-*/spec.md 2>/dev/null
```

**If spec.md exists (not orphaned):**

1. **Check uncommitted changes:**
   ```bash
   cd .worktrees/main-{runId}
   git status --porcelain
   ```

2. **List all related branches:**
   ```bash
   git branch | grep "^  {runId}-"
   ```

3. **For each branch, check push status:**
   ```bash
   # Check if upstream exists
   git rev-parse {branch}@{u} 2>/dev/null

   # If upstream exists, check unpushed commits
   if [ $? -eq 0 ]; then
     git log {branch}@{u}..{branch} --oneline
   else
     echo "Branch has no upstream (never pushed)"
   fi
   ```

4. **Build summary and require confirmation:**
   - Use AskUserQuestion with confirm/abort options
   - Show: uncommitted changes count, unpushed branches with commit counts
   - Explain: worktree will be deleted, branches remain accessible

**If spec.md does NOT exist (orphaned):**
- Skip safety checks (no data to lose)
- Proceed directly to removal

### Removal

**Try git worktree remove first:**

```bash
git worktree remove .worktrees/main-{runId}
```

**If removal fails** (orphaned or locked worktree):

```bash
rm -rf .worktrees/main-{runId}
git worktree prune
```

**Why fallback is safe:** Orphaned worktrees have no spec (feature creation failed), so no data loss. For locked worktrees, manual removal is required.

## Quality Rules

**Mandatory Steps (Never Skip):**
- ✅ Run `git worktree prune` FIRST (before checking existence)
- ✅ Verify working directory with `pwd` after `cd`
- ✅ Check git-spice initialization in worktree
- ✅ Check uncommitted changes before cleanup
- ✅ Check branch push status before cleanup
- ✅ Require user confirmation before deletion

**Path Standards:**
- ✅ `.worktrees/main-{runId}/` (6-char runId)
- ❌ `.worktrees/{feature-name}/` (no feature names, use runId)
- ❌ `worktrees/` (must be `.worktrees/` with dot prefix)

**Error Handling:**
- ✅ Detect orphaned worktrees and skip safety checks
- ✅ Fallback to `rm -rf` for corrupted worktrees
- ✅ Check upstream exists before `git log @{u}..`
- ❌ Assume git commands succeed without verification

## Rationalization Table

| Rationalization | Why It's Wrong | What to Do Instead |
|----------------|----------------|-------------------|
| "Worktree list should be accurate, skip prune" | Manual deletion leaves stale entries causing false positives | Always prune first (Scenario 1) |
| "We just created worktree, it exists" | Worktree creation can succeed but directory be inaccessible (permissions, corruption) | Verify with `pwd` after every `cd` (Scenario 8) |
| "Git-spice initialized in main repo, worktree has it" | Git-spice can be uninstalled/reinstalled, worktrees pre-date initialization | Always verify with `gs ls` in worktree (Scenario 3) |
| "User asked to cleanup, they know what they want" | Users don't always realize they have uncommitted changes or unpushed branches | Always check and require confirmation (Scenario 4) |
| "Git worktree remove should handle all cases" | Orphaned and locked worktrees fail with git worktree remove | Detect orphaned status, fallback to `rm -rf` (Scenario 5) |
| "Lock files tell us dependencies, skip CLAUDE.md" | CLAUDE.md may specify custom install (make, scripts, multi-step) | Check CLAUDE.md FIRST (Scenario 7) |
| "User provided path, they know format" | Malformed paths cause cryptic errors later | Validate with regex before extraction (Scenario 6) |
| "cd command would error if it failed" | cd can succeed to wrong directory or partial path match | Always verify with `pwd` that you're in expected location (Scenario 8) |

## Error Handling

### Worktree Creation Fails

**Symptoms:** `git worktree add` fails with permission error, disk full, or lock

**Fix:**
- Check disk space: `df -h .`
- Check permissions: `ls -la .worktrees/`
- Check for locks: `ls .git/worktrees/`
- If persistent, report error to user with diagnostics

### Worktree Exists But Inaccessible

**Symptoms:** `git worktree list` shows worktree but `cd` fails or `pwd` shows wrong location

**Fix:**
- Run cleanup: `/spectacular:cleanup {runId}`
- If cleanup fails, manual removal: `rm -rf .worktrees/main-{runId} && git worktree prune`

### Git-Spice Initialization Fails

**Symptoms:** `gs repo init` fails with conflict or error

**Fix:**
- Check if git-spice is installed: `gs --version`
- If not installed: "Git-spice is required for Spectacular. Install: https://github.com/abhinav/git-spice"
- If conflict: `--continue-on-conflict` flag handles it, but log warning

### Branches Have No Upstream

**Symptoms:** `git rev-parse @{u}` fails for branch

**Fix:**
- This is expected for branches never pushed
- Mark as "never pushed" in summary
- Don't run `git log @{u}..` (would error)
- Warn user in confirmation dialog

## Integration with Commands

**Spec Command:**
- Step 0.5: Handle uncommitted changes (commit/stash/proceed/abort)
- Step 0.5 (continued): Use this skill to create/verify main worktree
- Step 1-4: Work continues in worktree

**Plan Command:**
- Step 0: Extract runId from spec path
- Step 0 (continued): Use this skill to enter existing worktree
- Step 1-N: Work continues in worktree

**Execute Command:**
- Step 0a: Extract runId from plan path
- Step 0.5: Use this skill to enter existing worktree
- Step 0.6: Install dependencies (check CLAUDE.md first)
- Step 1-N: Setup and execution in worktree

**Cleanup Command:**
- Step 1-2: Verify worktree exists
- Step 3-6: Use this skill's cleanup process
- Step 7-8: Report status

## Real-World Impact

**Without this skill:**
- Stale worktree entries cause "already exists" errors
- Orphaned worktrees accumulate (disk space waste)
- Users lose uncommitted work during cleanup
- Git-spice commands fail mysteriously
- Main repo contaminated by Spectacular files

**With this skill:**
- Clean worktree state every time
- Safe cleanup with data loss prevention
- Predictable git-spice behavior
- True isolation (main repo always clean)
