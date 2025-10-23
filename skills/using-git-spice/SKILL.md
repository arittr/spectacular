---
name: using-git-spice
description: Use when working with stacked branches, managing dependent PRs/CRs, or uncertain about git-spice commands (stack vs upstack vs downstack) - provides command reference, workflow patterns, and common pitfalls for the git-spice CLI tool
---

# Using git-spice

## Overview

**git-spice (`gs`) is a CLI tool for managing stacked Git branches and their Change Requests.**

Core principle: git-spice tracks branch relationships (stacks) and automates rebasing/submitting dependent branches.

## Key Concepts

**Stack terminology:**
- **Stack**: All branches connected to current branch (both upstack and downstack)
- **Upstack**: Branches built on top of current branch (children and descendants)
- **Downstack**: Branches below current branch down to trunk (parents and ancestors)
- **Trunk**: Main integration branch (typically `main` or `master`)

**Example stack:**
```
┌── feature-c     ← upstack from feature-b
├── feature-b     ← upstack from feature-a, downstack from feature-c
├── feature-a     ← downstack from feature-b
main (trunk)
```

When on `feature-b`:
- **Upstack**: feature-c
- **Downstack**: feature-a, main
- **Stack**: feature-a, feature-b, feature-c

## Quick Reference

| Task | Command | Notes |
|------|---------|-------|
| **Initialize repo** | `gs repo init` | Required once per repo. Sets trunk branch. |
| **Create stacked branch** | `gs branch create <name>` | Creates branch on top of current. Use `gs bc` shorthand. |
| **View stack** | `gs log short` | Shows current stack. Use `gs ls` or `gs log long` (`gs ll`) for details. |
| **Submit stack as PRs** | `gs stack submit` | Submits entire stack. Use `gs ss` shorthand. |
| **Submit upstack only** | `gs upstack submit` | Current branch + children. Use `gs us s` shorthand. |
| **Submit downstack only** | `gs downstack submit` | Current branch + parents to trunk. Use `gs ds s` shorthand. |
| **Rebase entire stack** | `gs repo restack` | Rebases all tracked branches on their bases. |
| **Rebase current stack** | `gs stack restack` | Rebases current branch's stack. Use `gs sr` shorthand. |
| **Rebase upstack** | `gs upstack restack` | Current branch + children. Use `gs us r` shorthand. |
| **Move branch to new base** | `gs upstack onto <base>` | Moves current + upstack to new base. |
| **Sync with remote** | `gs repo sync` | Pulls latest, deletes merged branches. |
| **Track existing branch** | `gs branch track [branch]` | Adds branch to git-spice tracking. |
| **Delete branch** | `gs branch delete [branch]` | Deletes branch, restacks children. Use `gs bd` shorthand. |

**Command shortcuts:** Most commands have short aliases. Use `gs --help` to see all aliases.

## Common Workflows

### Workflow 1: Create and Submit Stack

```bash
# One-time setup
gs repo init
# Prompt asks for trunk branch (usually 'main')

# Create stacked branches
gs branch create feature-a
# Make changes, commit with git
git add . && git commit -m "Implement A"

gs branch create feature-b  # Stacks on feature-a
# Make changes, commit
git add . && git commit -m "Implement B"

gs branch create feature-c  # Stacks on feature-b
# Make changes, commit
git add . && git commit -m "Implement C"

# View the stack
gs log short

# Submit entire stack as PRs
gs stack submit
# Creates/updates PRs for all branches in stack
```

### Workflow 2: Update Branch After Review

```bash
# You have feature-a → feature-b → feature-c
# Reviewer requested changes on feature-b

git checkout feature-b
# Make changes, commit
git add . && git commit -m "Address review feedback"

# Rebase upstack (feature-c) on updated feature-b
gs upstack restack

# Submit changes to update PRs
gs upstack submit
# Note: restack only rebases locally, submit pushes and updates PRs
```

**CRITICAL: Don't manually rebase feature-c!** Use `gs upstack restack` to maintain stack relationships.

### Workflow 3: Sync After Upstream Merge

```bash
# feature-a was merged to main
# Need to update feature-b and feature-c

# Sync with remote (pulls main, deletes merged branches)
gs repo sync

# Restack everything on new main
gs repo restack

# Verify stack looks correct
gs log short

# Push updated branches
gs stack submit
```

**CRITICAL: Don't rebase feature-c onto main!** After feature-a merges:
- feature-b rebases onto main (its new base)
- feature-c rebases onto feature-b (maintains dependency)

## When to Use Git vs git-spice

**Use git-spice for:**
- Creating branches in a stack: `gs branch create`
- Rebasing stacks: `gs upstack restack`, `gs repo restack`
- Submitting PRs: `gs stack submit`, `gs upstack submit`
- Viewing stack structure: `gs log short`
- Deleting branches: `gs branch delete` (restacks children)

**Use git for:**
- Making changes: `git add`, `git commit`
- Checking status: `git status`, `git diff`
- Viewing commit history: `git log`
- Individual branch operations: `git checkout`, `git switch`

**Never use `git rebase` directly on stacked branches** - use git-spice restack commands to maintain relationships.

## Common Mistakes

| Mistake | Why It's Wrong | Correct Approach |
|---------|---------------|------------------|
| Rebasing child onto trunk after parent merges | Breaks stack relationships, creates conflicts | Use `gs repo sync && gs repo restack` |
| Using `git push --force` after changes | Bypasses git-spice tracking | Use `gs upstack submit` or `gs stack submit` |
| Manually rebasing with `git rebase` | git-spice doesn't track the rebase | Use `gs upstack restack` or `gs stack restack` |
| Running `gs stack submit` on wrong branch | Might submit unintended branches | Check `gs log short` first to see what's in stack |
| Forgetting `gs repo init` | Commands fail with unclear errors | Run `gs repo init` once per repository |
| Using `stack` when you mean `upstack` | Submits downstack branches too (parents) | Use `upstack` to submit only current + children |
| Assuming `restack` runs automatically | After commits, stack can drift | Explicitly run `gs upstack restack` after changes |

## Red Flags - Check Documentation

- Confused about stack/upstack/downstack scope
- About to run `git rebase` on a tracked branch
- Unsure which submit command to use
- Getting "not tracked" errors

**When uncertain, run `gs <command> --help` for detailed usage.**

## Authentication and Setup

**First time setup:**
```bash
# Authenticate with GitHub/GitLab
gs auth login
# Follow prompts for OAuth or token auth

# Initialize repository
gs repo init
# Sets trunk branch and remote

# Verify setup
gs auth status
```

## Handling Conflicts

If `gs upstack restack` or `gs repo restack` encounters conflicts:
1. Resolve conflicts using standard git workflow (`git status`, edit files, `git add`)
2. Continue with `git rebase --continue`
3. git-spice will resume restacking remaining branches
4. After resolution, run `gs upstack submit` to push changes

If you need to abort a restack, check `gs --help` for recovery options.

## Additional Resources

- Full CLI reference: `gs --help`
- Command-specific help: `gs <command> --help`
- Configuration: `gs config --help`
- Official docs: https://abhinav.github.io/git-spice/

## Concurrent Run Safety

When running multiple spectacular executions simultaneously (different runIds), git-spice operations have different safety levels. Understanding which operations are safe during parallel runs prevents conflicts and data corruption.

### Safe Operations

These operations are safe during parallel spectacular runs because they operate on the current worktree's branch or branch-specific stack:

**`gs branch create <name>`**
- Safe: Creates branch in current worktree
- Each worktree has independent HEAD
- Branches created in worktrees are visible in all worktrees (shared `.git` database)
- **Critical**: After creating a branch in a parallel task worktree, MUST run `git switch --detach` to make the branch accessible from parent repo
  - Without detach: Branch creation succeeds, but branch remains checked out in worktree
  - Parent repo cannot switch to the branch (worktree lock)
  - Cleanup subagent cannot access the branch for stacking
  - **Pattern**: `gs branch create {name} && git switch --detach`

**`gs upstack onto <base>`**
- Safe: Operates only on current branch and its upstack
- Does not affect branches in other stacks
- Each worktree can independently move its stack

**`gs stack submit`**
- Safe: Submits current branch's entire stack
- Only pushes/updates PRs for branches in current stack
- Multiple runs can submit different stacks simultaneously

**`gs branch checkout <name>`**
- Safe within worktree: Switches current worktree's HEAD
- Does not affect other worktrees
- Note: Cannot checkout branches currently checked out in another worktree (git protection)

### Unsafe Operations Requiring Coordination

These operations affect the entire repository and should only be run when no spectacular runs are active:

**`gs repo restack`**
- Unsafe: Rebases ALL tracked branches in repository
- Affects branches across all concurrent runs
- Can cause conflicts if runs are simultaneously modifying stacks
- **Recommendation**: Only run in main repo when `.worktrees/` is empty (no active runs)

**`gs repo sync`**
- Unsafe: Pulls latest changes and deletes merged branches across entire repo
- Can delete branches that concurrent runs are using
- Can modify trunk that runs are based on
- **Recommendation**: Only run between spectacular executions, not during

### Worktree-Specific Patterns

git-spice works with git worktrees with some important caveats:

**Shared Git Database**
- All worktrees share the same `.git` database
- Branches created in any worktree are visible in all worktrees
- Branch deletions in one worktree affect all worktrees
- Tags and refs are shared across all worktrees

**Independent HEAD per Worktree**
- Each worktree has its own checked-out branch (HEAD)
- `gs log short` shows different output depending on current worktree's branch
- Stack operations (`gs upstack`, `gs downstack`, `gs stack`) are relative to current HEAD

**Worktree Creation and Management**
- Use the `managing-worktrees` skill for creating/removing worktrees
- Pattern: Create worktree, create branch, detach HEAD, work, cleanup
- See `managing-worktrees` skill for complete lifecycle

**Parallel Task Pattern**
```bash
# In orchestrator (main repo)
# 1. Create worktree using managing-worktrees skill
git worktree add .worktrees/{runId}-task-{phase}-{task}

# In subagent (inside worktree)
cd .worktrees/{runId}-task-{phase}-{task}
gs branch create {runId}-task-{phase}-{task}-{name}
# ... make changes, commit ...
git switch --detach  # CRITICAL: Makes branch accessible in parent repo
# Subagent completes, exits worktree

# In cleanup subagent (main repo, NOT worktree)
# Now can access the branch for stacking
git checkout {runId}-task-{phase}-{task}-{name}
gs upstack onto {base-branch}
```

### Error Handling for Concurrent Conflicts

**Branch Already Exists**
```bash
# Error: "branch '{name}' already exists"
# Cause: Another run created the same branch name

# Recovery:
# 1. Check if branch belongs to your runId
git branch --list "*{runId}*"
# 2. If not your runId, branch naming collision (rare with 6-char runId)
# 3. Use more specific branch name or wait for other run to complete
```

**Restack in Progress**
```bash
# Error: "rebase in progress" or lock file errors
# Cause: Another operation is modifying branch relationships

# Recovery:
# 1. Wait for operation to complete (check other terminals/processes)
# 2. If stale lock, check git status
git status
# 3. If safe, remove stale lock (only if certain no rebase running)
rm .git/rebase-merge -rf  # DANGER: Only if no active rebase
```

**Cannot Checkout Branch (Worktree Lock)**
```bash
# Error: "branch '{name}' is checked out at '.worktrees/...'"
# Cause: Branch is currently checked out in another worktree

# Recovery:
# 1. This is expected during parallel execution
# 2. If need to access branch, either:
#    a. Work in the worktree where it's checked out
#    b. Detach the branch in that worktree: cd to worktree && git switch --detach
#    c. Wait for worktree cleanup to complete
```

### Rationalization Table

| Shortcut | Why It's Tempting | Why It's Wrong | Correct Approach |
|----------|-------------------|----------------|------------------|
| "Repo restack is fine during parallel runs" | Want to keep everything up to date | Affects all tracked branches, causes conflicts between runs | Only run when no spectacular runs active |
| "Don't need to detach after branch create" | Extra step, seems unnecessary | Branch remains locked in worktree, inaccessible from parent repo | Always `git switch --detach` after branch create in parallel tasks |
| "Can skip detach in sequential tasks" | Sequential tasks don't have cleanup | Sequential tasks might need branch access later for stacking | Detach is only required for parallel tasks that will be stacked later |
| "Repo sync during runs is okay" | Want latest changes from remote | Can delete branches concurrent runs are using | Only sync between spectacular executions |

**Remember:** When in doubt about concurrent safety, run the operation in the main repo (not a worktree) and only when all worktrees are cleaned up.
