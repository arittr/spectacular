---
name: managing-worktrees
description: Use when setting up or cleaning up worktrees for spectacular execution - enforces state validation, cleanup verification, and resume safety patterns specific to parallel task orchestration
---

# Managing Worktrees for Spectacular

## Overview

Spectacular uses worktrees to isolate execution from the main repository, enabling concurrent runs and manual work during execution. This skill enforces critical verification steps that prevent broken states and silent failures.

**Core principle:** Verify state before creation, verify isolation after cleanup, never assume clean.

**Announce at start:** "I'm using the managing-worktrees skill to set up isolated execution workspace."

## When to Use

**Use this skill when:**

- Creating main worktree for spectacular execution (`.worktrees/{runId}-main`)
- Creating parallel worktrees for parallel phases (`.worktrees/{runId}-task-*`)
- Cleaning up worktrees after phase completion
- Resuming execution with existing worktrees
- Validating worktree state before operations

**Don't use when:**

- Creating worktrees for general development work (use `using-git-worktrees` from superpowers)
- Working with single worktrees outside spectacular context

## The Process

### Pattern 1: Creating Main Worktree

**When:** At the start of `/spectacular:execute`, before any task execution.

**Steps:**

1. **Check if worktree already exists (resume case):**

```bash
if [ -d .worktrees/{runId}-main ]; then
  echo "Main worktree exists, validating state..."
  # Continue to validation
else
  echo "Creating new main worktree..."
  # Continue to creation
fi
```

2. **Validate existing worktree state (if exists):**

```bash
cd .worktrees/{runId}-main

# CRITICAL: Check for uncommitted changes
if [ -n "$(git status --porcelain)" ]; then
  echo "ERROR: Main worktree has uncommitted changes"
  echo "Please commit or stash changes before resuming"
  exit 1
fi

# CRITICAL: Verify not in detached HEAD state
CURRENT=$(git branch --show-current)
if [ -z "$CURRENT" ]; then
  echo "ERROR: Main worktree in detached HEAD state"
  echo "Please checkout a branch before resuming"
  exit 1
fi

echo "Main worktree state valid on branch: $CURRENT"
cd ../..
```

3. **Create new worktree (if doesn't exist):**

```bash
# Get current branch from main repo
CURRENT_BRANCH=$(git branch --show-current)
echo "Creating main worktree from branch: $CURRENT_BRANCH"

# Create worktree
git worktree add ./.worktrees/{runId}-main $CURRENT_BRANCH

# Verify creation
cd .worktrees/{runId}-main
pwd  # Confirm location
git branch --show-current  # Confirm branch
cd ../..
```

4. **Report:**

```
Main worktree ready:
- Path: ./.worktrees/{runId}-main
- Base branch: {branch-name}
- Status: {new|resumed}
```

### Pattern 2: Creating Parallel Worktrees

**When:** At the start of a parallel phase, after main worktree exists.

**Steps:**

1. **Verify in main repo (orchestrator location):**

```bash
pwd  # Should be /path/to/repo (NOT in a worktree)
```

2. **Get base branch from main worktree without cd:**

```bash
# CRITICAL: Use git -C to query without changing directory
CURRENT_BRANCH=$(git -C .worktrees/{runId}-main branch --show-current)
echo "Base branch for parallel tasks: $CURRENT_BRANCH"
```

3. **Create parallel worktrees:**

```bash
# CRITICAL: Create from main repo, use --detach flag
git worktree add --detach ./.worktrees/{runId}-task-{phase}-{task-1} $CURRENT_BRANCH
git worktree add --detach ./.worktrees/{runId}-task-{phase}-{task-2} $CURRENT_BRANCH
# etc for each parallel task
```

4. **Verify all worktrees created:**

```bash
git worktree list
# Should show main repo, main worktree, and all task worktrees
```

5. **Report:**

```
Parallel worktrees created:
- Base branch: {branch-name}
- Worktrees:
  * ./.worktrees/{runId}-task-{phase}-{task-1}
  * ./.worktrees/{runId}-task-{phase}-{task-2}
- Status: Ready for parallel execution
```

### Pattern 3: Cleaning Up Parallel Worktrees

**When:** After all parallel tasks complete and branches are created.

**REQUIRED: Create TodoWrite checklist before starting cleanup:**

```markdown
Parallel worktree cleanup checklist:

- [ ] Verify in main repo: pwd shows /path/to/repo
- [ ] Verify branches exist: git branch -v | grep "{runId}-task-{phase}"
- [ ] Verify ALL worktrees have detached HEAD: git worktree list
- [ ] Remove each parallel worktree from main repo
- [ ] Verify worktrees removed: git worktree list shows only main repo + main worktree
- [ ] Verify branches still accessible: git branch -v | grep "{runId}-task-{phase}"
```

**Why required:** Under time pressure, skipping verification steps causes 15-30 min recovery. TodoWrite forces explicit tracking.

**Steps:**

1. **Verify in main repo:**

```bash
pwd  # Should be /path/to/repo (NOT in a worktree)
```

2. **Verify all parallel branches exist:**

```bash
# CRITICAL: Branches must exist before removing worktrees
git branch -v | grep "{runId}-task-{phase}"
# Expected: All task branches listed with commit info
```

3. **Verify all worktrees have detached HEAD:**

```bash
# CRITICAL: If worktree still has branch checked out, removal may fail
git worktree list
# All parallel task worktrees should show "(detached HEAD)"
# NOT a branch name
```

If any worktree shows a branch name:

```
ERROR: Worktree .worktrees/{runId}-task-{phase}-{task} has branch checked out
This task failed to detach HEAD (git switch --detach)
Fix: cd into worktree, run git switch --detach, then retry cleanup
```

4. **Remove parallel worktrees:**

```bash
# CRITICAL: Remove from main repo (current directory)
git worktree remove ./.worktrees/{runId}-task-{phase}-{task-1}
git worktree remove ./.worktrees/{runId}-task-{phase}-{task-2}
# etc for all parallel task worktrees
```

5. **Verify worktrees removed but branches still exist:**

```bash
# Worktrees gone
git worktree list  # Should only show main repo and main worktree

# Branches still accessible
git branch -v | grep "{runId}-task-{phase}"  # Should still show all branches
```

6. **Report:**

```
Parallel worktrees cleaned up:
- Worktrees removed: {count}
- Branches preserved: {list}
- Branches accessible in main repo and main worktree
```

### Pattern 4: Final Cleanup (After Entire Feature)

**When:** After all phases complete, tests pass, code review done.

**Steps:**

1. **List worktrees for this run:**

```bash
git worktree list | grep "{runId}"
```

2. **Remove main worktree:**

```bash
# CRITICAL: Verify you're in main repo, not in the worktree being removed
pwd  # Should be /path/to/repo

git worktree remove ./.worktrees/{runId}-main
```

3. **Verify cleanup:**

```bash
git worktree list  # Should not show any {runId} worktrees
ls -la .worktrees/  # Verify directories removed
```

4. **Prune stale entries:**

```bash
git worktree prune
```

**Note:** Branches are NOT removed (they're in `.git`). Only worktree directories are cleaned up.

## Rationalization Table

This table lists rationalizations Claude will make to skip verification steps, with time costs and enforcement:

| Rationalization                             | Why It's Wrong                                             | Time Cost vs Benefit                              | Enforcement                                                |
| ------------------------------------------- | ---------------------------------------------------------- | ------------------------------------------------- | ---------------------------------------------------------- |
| "I'm late for standup, 30s check can wait"  | Resume into dirty state loses 30min debugging              | Check: 30s / Silent failure: 30-60min             | MUST run `git status --porcelain` EVEN under time pressure |
| "I'll cd to worktree to simplify commands"  | Orchestrator loses track of location, relative paths break | Setup: 5s to learn `git -C` / Path bugs: 15-30min | NEVER cd from orchestrator, use `git -C`                   |
| "Manager waiting, 90% sure HEAD detached"   | 10% chance = 15min recovery vs 1min check                  | Verify ALL: 1-2min / Recovery: 15-30min           | MUST verify ALL worktrees, no spot-checks                  |
| "I'll remove worktrees from inside them"    | Path confusion, removal errors, inconsistent state         | Extra cd: 2 keystrokes / Path bugs: 10-20min      | ALWAYS remove from main repo                               |
| "Branches exist, so I'll skip verification" | Silent failures if branches not accessible after cleanup   | Verify: 10s / Debugging: 10-15min                 | MUST verify with `git branch -v`                           |
| "I'll skip pwd check, I know where I am"    | Silent bugs from wrong directory                           | pwd: 1s / Wrong-dir bugs: 15-30min                | ALWAYS verify location with `pwd`                          |
| "I'll create worktrees from main worktree"  | Relative path confusion, `../` patterns break              | cd to repo: 5s / Relative path bugs: 20-40min     | ALWAYS create from main repo                               |
| "I'll skip detached HEAD on parallel tasks" | Cleanup fails, branches inaccessible                       | git switch --detach: 2s / Recovery: 10-20min      | MUST enforce `git switch --detach`                         |

## Quality Rules

**Never skip these verifications:**

1. **State validation before resume:**

   - MUST check `git status --porcelain` (empty = clean)
   - MUST verify `git branch --show-current` (not empty = valid branch)

2. **Location verification:**

   - MUST run `pwd` before every worktree operation
   - Orchestrator MUST be in main repo (not in worktree)

3. **Cleanup safety:**

   - MUST create TodoWrite checklist (Pattern 3) before cleanup
   - MUST verify HEAD detached: `git worktree list` shows "(detached HEAD)"
   - MUST verify branches exist: `git branch -v | grep "{pattern}"`
   - MUST remove from main repo: `pwd` shows main repo path
   - MUST verify branches accessible after cleanup

4. **Isolation verification:**
   - MUST use `git -C .worktrees/{path}` to query without cd
   - NEVER cd from orchestrator context

**TodoWrite requirement:**

- Pattern 3 (cleanup) REQUIRES TodoWrite checklist
- Prevents skipping verification steps under time pressure
- Each verification step must be tracked and completed

## Common Mistakes

### Mistake 1: Skipping dirty state check

```bash
# ❌ WRONG: Assume worktree is clean
if [ -d .worktrees/abc123-main ]; then
  echo "Worktree exists, reusing"
fi

# ✅ CORRECT: Verify state
if [ -d .worktrees/abc123-main ]; then
  cd .worktrees/abc123-main
  if [ -n "$(git status --porcelain)" ]; then
    echo "ERROR: Uncommitted changes"
    exit 1
  fi
  cd ../..
fi
```

**Why it matters:** Resuming into dirty state causes merge conflicts, lost work, broken tests.

### Mistake 2: Creating parallel worktrees from main worktree

```bash
# ❌ WRONG: cd into main worktree to create parallel worktrees
cd .worktrees/abc123-main
git worktree add ../task-1 HEAD  # Creates .worktrees/task-1 (confusing path)

# ✅ CORRECT: Create from main repo with git -C
pwd  # Verify in main repo
BRANCH=$(git -C .worktrees/abc123-main branch --show-current)
git worktree add ./.worktrees/abc123-task-1 $BRANCH
```

**Why it matters:** `../` relative paths break, cleanup logic gets confused, hard to debug.

### Mistake 3: Not verifying HEAD detached before cleanup

```bash
# ❌ WRONG: Remove worktree without checking
git worktree remove ./.worktrees/abc123-task-1

# ✅ CORRECT: Verify HEAD detached first
git worktree list | grep "abc123-task-1"
# Look for "(detached HEAD)" not a branch name
git worktree remove ./.worktrees/abc123-task-1
```

**Why it matters:** If HEAD not detached, branch may not be accessible after removal.

### Mistake 4: Removing worktrees from inside them

```bash
# ❌ WRONG: cd into worktree to clean up
cd .worktrees/abc123-main
git worktree remove ../abc123-task-1  # Relative path, confusing

# ✅ CORRECT: Remove from main repo
pwd  # /path/to/repo
git worktree remove ./.worktrees/abc123-task-1  # Absolute path
```

**Why it matters:** Relative paths fail, can't remove worktree you're inside of, state corruption.

## Red Flags

**STOP and calculate cost vs benefit:**

| Shortcut Temptation              | Shortcut "Saves" | Silent Failure Costs                | Verdict             |
| -------------------------------- | ---------------- | ----------------------------------- | ------------------- |
| Skip dirty state check           | 30 seconds       | 30-60 minutes debugging + lost work | ALWAYS verify       |
| Skip HEAD detached check         | 1-2 minutes      | 15-30 minutes recovery              | ALWAYS verify       |
| Skip pwd verification            | 1 second         | 15-30 minutes wrong-dir bugs        | ALWAYS verify       |
| Use relative paths               | 10 chars typing  | 20-40 minutes path bugs             | ALWAYS use absolute |
| Spot-check instead of verify all | 30 seconds       | 10-20 minutes if one fails          | ALWAYS verify all   |

**Verification is ALWAYS cheaper than debugging.**

**STOP if you're about to:**

- Create worktree without checking if it already exists
- Resume into worktree without checking `git status --porcelain`
- Use `git -C` without verifying pwd first (might already be in wrong location)
- Remove worktree without verifying branches still accessible
- cd from orchestrator context (orchestrator must stay in main repo)
- Create parallel worktrees from within main worktree
- Skip HEAD detached verification before cleanup
- Use `../` relative paths for worktree operations

**Always:**

- Run `pwd` before every worktree operation
- Check dirty state before resuming: `git status --porcelain`
- Verify detached HEAD before cleanup: `git worktree list`
- Verify branches accessible after cleanup: `git branch -v`
- Work from main repo for all orchestration operations
- Use absolute paths: `./.worktrees/{runId}-*`

## Integration

**Used by:**

- `/spectacular:execute` - Main worktree setup, parallel worktree creation/cleanup
- `/spectacular:cleanup` - Manual cleanup of abandoned runs

**Pairs with:**

- `orchestrating-isolated-subagents` - Directory management for subagents
- `using-git-spice` - Branch operations in worktrees
- `using-git-worktrees` (superpowers) - General worktree concepts

**Example usage in command:**

```markdown
## Step 0c: Create Main Worktree

Per `managing-worktrees` skill, create main worktree:

[delegate to setup subagent with Pattern 1 from skill]
```

## Testing

To test this skill with `testing-skills-with-subagents`:

**Scenario 1: Resume into dirty worktree**

- Create worktree, make uncommitted changes
- Try to resume
- Expected: Detects dirty state, refuses to continue

**Scenario 2: Cleanup without detached HEAD**

- Create parallel worktree, create branch but don't detach
- Try to clean up
- Expected: Detects branch checked out, refuses to remove

**Scenario 3: Verify branches after cleanup**

- Create parallel worktrees, create branches, detach, clean up
- Expected: Worktrees gone, branches still accessible
