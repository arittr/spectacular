---
name: executing-parallel-phase
description: Use when orchestrating parallel phases in plan execution - creates isolated worktrees for concurrent task execution, installs dependencies, spawns parallel subagents, verifies completion, stacks branches linearly, and cleans up (mandatory for ALL parallel phases including N=1)
---

# Executing Parallel Phase

## Overview

**Parallel phases enable TRUE concurrent execution via isolated git worktrees**, not just logical independence.

**Critical distinction:** Worktrees are not an optimization to prevent file conflicts. They're the ARCHITECTURE that enables multiple subagents to work simultaneously.

## When to Use

Use this skill when `execute` command encounters a phase marked "Parallel" in plan.md:
- ✅ Always use for N≥2 tasks
- ✅ **Always use for N=1** (maintains architecture consistency)
- ✅ Even when files don't overlap
- ✅ Even under time pressure
- ✅ Even with disk space pressure

**Never skip worktrees for parallel phases.** No exceptions.

## The Iron Law

```
PARALLEL PHASE = WORKTREES + SUBAGENTS
```

**Violations of this law:**
- ❌ Execute in main worktree ("files don't overlap")
- ❌ Skip worktrees for N=1 ("basically sequential")
- ❌ Use sequential strategy ("simpler")

**All of these destroy the parallel execution architecture.**

## The Process

**Announce:** "I'm using executing-parallel-phase to orchestrate {N} concurrent tasks in Phase {phase-id}."

### Step 1: Verify Location (MANDATORY)

**Before ANY worktree creation:**

```bash
# Get main repo root
REPO_ROOT=$(git rev-parse --show-toplevel)

# CRITICAL: Verify not in a worktree
if [[ "$REPO_ROOT" =~ \.worktrees ]]; then
  echo "❌ Error: Currently in worktree, must run from main repo"
  echo "Current: $REPO_ROOT"
  exit 1
fi

# Navigate to verified location
cd "$REPO_ROOT"
pwd  # Should show main repo path
```

**Why mandatory:** Running from inside a worktree creates nested worktrees in wrong location.

**Red flag:** "Git commands work from anywhere" - TRUE, but path resolution is CWD-relative.

### Step 2: Create Worktrees (BEFORE Subagents)

**Create isolated worktree for EACH task:**

```bash
# Get base branch from main worktree
BASE_BRANCH=$(git -C .worktrees/{runid}-main branch --show-current)

# Create worktrees in DETACHED HEAD state
for TASK_ID in {task-ids}; do
  git worktree add ".worktrees/{runid}-task-${TASK_ID}" --detach "$BASE_BRANCH"
  echo "✅ Created .worktrees/{runid}-task-${TASK_ID} (detached HEAD)"
done

# Verify all worktrees created
git worktree list | grep "{runid}-task-"
```

**Verify creation succeeded:**

```bash
CREATED_COUNT=$(git worktree list | grep -c "{runid}-task-")

if [ $CREATED_COUNT -ne {expected-count} ]; then
  echo "❌ Error: Expected {expected-count} worktrees, found $CREATED_COUNT"
  exit 1
fi

echo "✅ Created $CREATED_COUNT worktrees for parallel execution"
```

**Why --detach:** Git doesn't allow same branch in multiple worktrees. Detached HEAD enables parallel worktrees.

**Red flags:**
- "Only 1 task, skip worktrees" - NO. N=1 still uses architecture.
- "Files don't overlap, skip isolation" - NO. Isolation enables parallelism, not prevents conflicts.

### Step 3: Install Dependencies Per Worktree

**Each worktree needs its own dependencies:**

```bash
for TASK_ID in {task-ids}; do
  cd .worktrees/{runid}-task-${TASK_ID}

  if [ ! -d node_modules ]; then
    {install-command}  # From CLAUDE.md
    {postinstall-command}  # Optional, from CLAUDE.md
  fi

  cd "$REPO_ROOT"
done
```

**Why per-worktree:** Isolated worktrees can't share node_modules.

**Red flag:** "Share node_modules for efficiency" - Breaks isolation and causes race conditions.

### Step 4: Spawn Parallel Subagents

**CRITICAL: Single message with multiple Task tools (true parallelism):**

For each task, dispatch with prompt:
```
ROLE: Implement Task {task-id} in ISOLATED worktree

WORKTREE: .worktrees/{run-id}-task-{task-id}

[Task details, acceptance criteria...]

CRITICAL:
1. Verify isolation (pwd must show task worktree)
2. Implement task
3. Run quality checks (exit code validation)
4. Create branch: gs branch create {branch-name}
5. Detach HEAD: git switch --detach
6. Report completion
```

**Red flags:**
- "I'll just do it myself" - NO. Subagents provide fresh context.
- "Execute sequentially in main worktree" - NO. Destroys parallelism.

### Step 5: Verify Completion (BEFORE Stacking)

**Check all task branches exist:**

```bash
FAILED_TASKS=()

for TASK_ID in {task-ids}; do
  BRANCH_NAME="{runid}-task-{phase-id}-${TASK_ID}-{short-name}"

  if ! git rev-parse --verify "$BRANCH_NAME" >/dev/null 2>&1; then
    FAILED_TASKS+=("Task ${TASK_ID}")
  fi
done

if [ ${#FAILED_TASKS[@]} -gt 0 ]; then
  echo "❌ Phase {phase-id} execution failed"
  echo "Failed tasks: ${FAILED_TASKS[*]}"
  exit 1
fi

echo "✅ All {task-count} tasks completed successfully"
```

**Why verify:** Agents can fail. Quality checks can block commits. Verify branches exist before stacking.

**Red flags:**
- "Agents said success, skip check" - NO. Agent reports ≠ branch existence.
- "Trust but don't verify" - NO. Verify preconditions.

### Step 6: Stack Branches Linearly (BEFORE Cleanup)

**Use loop-based algorithm for any N:**

```bash
cd .worktrees/{runid}-main

TASK_BRANCHES=( {array-of-branch-names} )
TASK_COUNT=${#TASK_BRANCHES[@]}

# Handle N=1 edge case
if [ $TASK_COUNT -eq 1 ]; then
  git checkout "${TASK_BRANCHES[0]}"
  gs branch track
  gs upstack onto "$BASE_BRANCH"  # Explicitly set base for first parallel task
else
  # Handle N≥2
  for i in "${!TASK_BRANCHES[@]}"; do
    BRANCH="${TASK_BRANCHES[$i]}"

    if [ $i -eq 0 ]; then
      # First task: track and explicitly set base
      git checkout "$BRANCH"
      gs branch track
      gs upstack onto "$BASE_BRANCH"  # Explicitly stack onto pre-parallel base
    else
      # Subsequent: track + upstack onto previous
      PREV_BRANCH="${TASK_BRANCHES[$((i-1))]}"
      git checkout "$BRANCH"
      gs branch track
      gs upstack onto "$PREV_BRANCH"
    fi
  done
fi

# Verify stack
gs log short

cd "$REPO_ROOT"
```

**Why before cleanup:** Need worktrees accessible for debugging if stacking fails.

**Red flag:** "Clean up first to free disk space" - NO. Stacking MUST happen first.

### Step 7: Clean Up Worktrees (AFTER Stacking)

**Remove task worktrees:**

```bash
for TASK_ID in {task-ids}; do
  git worktree remove ".worktrees/{runid}-task-${TASK_ID}"
done

# Verify cleanup
git worktree list | grep "{runid}-task-"
# Should be empty
```

**Why after stacking:** Branches must be stacked and verified before destroying evidence.

### Step 8: Code Review

**Use `requesting-code-review` skill:**

```
Skill tool: requesting-code-review
```

Phase is complete ONLY when:
- ✅ All branches created
- ✅ Linear stack verified
- ✅ Worktrees cleaned up
- ✅ Code review passes

## Rationalization Table

| Excuse | Reality |
|--------|---------|
| "Only 1 task, skip worktrees" | N=1 still uses parallel architecture. No special case. |
| "Files don't overlap, skip isolation" | Worktrees enable parallelism, not prevent conflicts. |
| "Already spent 30min on setup" | Sunk cost fallacy. Worktrees ARE the parallel execution. |
| "Simpler to execute sequentially" | Simplicity ≠ correctness. Parallel phase = worktrees. |
| "Agents said success, skip verification" | Agent reports ≠ branch existence. Verify preconditions. |
| "Disk space pressure, clean up first" | Stacking must happen before cleanup. No exceptions. |
| "Git commands work from anywhere" | TRUE, but path resolution is CWD-relative. Verify location. |
| "I'll just do it myself" | Subagents provide fresh context and true parallelism. |
| "Worktrees are overhead" | Worktrees ARE the product. Parallelism is the value. |

## Red Flags - STOP and Follow Process

If you're thinking ANY of these, you're about to violate the skill:

- "This is basically sequential with N=1"
- "Files don't conflict, isolation unnecessary"
- "Worktree creation takes too long"
- "Already behind schedule, skip setup"
- "Agents succeeded, no need to verify"
- "Disk space warning, clean up now"
- "Current directory looks right"
- "Relative paths are cleaner"

**All of these mean: STOP. Follow the process exactly.**

## Common Mistakes

### Mistake 1: Treating Parallel as "Logically Independent"

**Wrong mental model:** "Parallel means tasks are independent, so I can execute them sequentially in one worktree."

**Correct model:** "Parallel means tasks execute CONCURRENTLY via multiple subagents in isolated worktrees."

**Impact:** Destroys parallelism. Turns 3-hour calendar time into 9-hour sequential execution.

### Mistake 2: Efficiency Optimization

**Wrong mental model:** "Worktrees are overhead when files don't overlap."

**Correct model:** "Worktrees are the architecture. Without them, no concurrent execution exists."

**Impact:** Sequential execution disguised as parallel. No time savings.

### Mistake 3: Cleanup Sequencing

**Wrong mental model:** "Branches exist independently of worktrees, so cleanup order doesn't matter."

**Correct model:** "Stacking before cleanup allows debugging if stacking fails and runs integration tests on complete stack."

**Impact:** Can't debug stacking failures. Premature cleanup destroys evidence.

## Quick Reference

**Mandatory sequence (no variations):**

1. Verify location (main repo root)
2. Create worktrees (ALL tasks, including N=1)
3. Install dependencies (per worktree)
4. Spawn subagents (parallel dispatch)
5. Verify branches exist (before stacking)
6. Stack branches (before cleanup)
7. Clean up worktrees (after stacking)
8. Code review

**Never skip. Never reorder. No exceptions.**

## The Bottom Line

**Parallel phases use worktrees.** Always. Even N=1. Even when files don't overlap. Even under pressure.

If you're not creating worktrees, you're not executing parallel phases - you're executing sequential phases incorrectly labeled as parallel.

The skill is the architecture. Follow it exactly.
