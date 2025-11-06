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

## Rationalization Table

**Predictable shortcuts you WILL be tempted to make. DO NOT make them.**

| Temptation | Why It's Wrong | What To Do |
|------------|----------------|------------|
| "The spec is too long, I'll just read the task description" | Task = WHAT files + verification. Spec = WHY architecture + requirements. Missing spec → drift. | Read the full spec. It's 2-5 minutes that prevents hours of rework. |
| "I already read the constitution, that's enough context" | Constitution = HOW to code. Spec = WHAT to build. Both needed for anchored implementation. | Read constitution AND spec, every time. |
| "The acceptance criteria are clear, I don't need the spec" | Acceptance criteria = tests pass, files exist. Spec = user flow, business logic, edge cases. | Acceptance criteria verify implementation. Spec defines requirements. |
| "I'm a subagent in a parallel phase, other tasks probably read the spec" | Each parallel subagent has isolated context. Other tasks' spec reading doesn't transfer. | Every subagent reads spec independently. No assumptions. |
| "The spec doesn't exist / I can't find it" | If spec missing, STOP and report error. Never proceed without spec. | Check `specs/{run-id}-{feature-slug}/spec.md`. If missing, fail loudly. |
| "I'll implement first, then check spec to verify" | Spec informs design decisions. Checking after implementation means rework. | Read spec BEFORE writing any code. |

**If you find yourself thinking "I can skip the spec because..." - STOP. You're rationalizing. Read the spec.**

## The Process

**Announce:** "I'm using executing-parallel-phase to orchestrate {N} concurrent tasks in Phase {phase-id}."

### Step 1: Pre-Conditions Verification (MANDATORY)

**Before ANY worktree creation, verify the environment is correct:**

```bash
# Get main repo root
REPO_ROOT=$(git rev-parse --show-toplevel)
CURRENT=$(pwd)

# Check 1: Verify orchestrator is in main repo root
if [ "$CURRENT" != "$REPO_ROOT" ]; then
  echo "❌ Error: Orchestrator must run from main repo root"
  echo "Current: $CURRENT"
  echo "Expected: $REPO_ROOT"
  echo ""
  echo "Return to main repo: cd $REPO_ROOT"
  exit 1
fi

echo "✅ Orchestrator location verified: Main repo root"

# Check 2: Verify main worktree exists
if [ ! -d .worktrees/{runid}-main ]; then
  echo "❌ Error: Main worktree not found at .worktrees/{runid}-main"
  echo "Run /spectacular:spec first to create the workspace."
  exit 1
fi

# Check 3: Verify main branch exists
if ! git rev-parse --verify {runid}-main >/dev/null 2>&1; then
  echo "❌ Error: Branch {runid}-main does not exist"
  echo "Spec must be created before executing parallel phase."
  exit 1
fi

echo "✅ Pre-conditions verified - safe to create task worktrees"
```

**Why mandatory:**
- Prevents nested worktrees from wrong location (9f92a8 regression)
- Catches upstream drift (execute.md or other skill left orchestrator in wrong place)
- Catches missing prerequisites before wasting time on worktree creation
- Provides clear error messages for common setup issues

**Red flag:** "Skip verification to save time" - NO. 20ms verification saves hours of debugging.

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

2. Read constitution (if exists): docs/constitutions/current/

3. Read feature specification: specs/{run-id}-{feature-slug}/spec.md

   This provides:
   - WHAT to build (requirements, user flows)
   - WHY decisions were made (architecture rationale)
   - HOW features integrate (system boundaries)

   The spec is your source of truth for architectural decisions.
   Constitution tells you HOW to code. Spec tells you WHAT to build.

4. Implement task following spec + constitution

5. Run quality checks with exit code validation:

   **CRITICAL**: Use heredoc to prevent bash parsing errors:

   ```bash
   bash <<'EOF'
   npm test
   if [ $? -ne 0 ]; then
     echo "❌ Tests failed"
     exit 1
   fi

   npm run lint
   if [ $? -ne 0 ]; then
     echo "❌ Lint failed"
     exit 1
   fi

   npm run build
   if [ $? -ne 0 ]; then
     echo "❌ Build failed"
     exit 1
   fi
   EOF
   ```

   **Why heredoc**: Prevents parsing errors when commands are wrapped by orchestrator.

   Do NOT create branch if quality checks fail

6. Create branch: gs branch create {branch-name}
7. Detach HEAD: git switch --detach
8. Report completion
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

**Use loop-based algorithm for any N (orchestrator stays in main repo):**

```bash
# Stack branches in main worktree using heredoc (orchestrator doesn't cd)
bash <<'EOF'
cd .worktrees/{runid}-main

TASK_BRANCHES=( {array-of-branch-names} )
TASK_COUNT=${#TASK_BRANCHES[@]}

# Handle N=1 edge case
if [ $TASK_COUNT -eq 1 ]; then
  git checkout "${TASK_BRANCHES[0]}"
  gs branch track
  gs upstack onto "$BASE_BRANCH"  # Explicitly set base for single parallel task
else
  # Handle N≥2
  for i in "${!TASK_BRANCHES[@]}"; do
    BRANCH="${TASK_BRANCHES[$i]}"

    if [ $i -eq 0 ]; then
      # First task: only track (already at correct position from worktree creation)
      git checkout "$BRANCH"
      gs branch track
      # NO gs upstack onto - first parallel task is base for subsequent tasks
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
EOF
```

**Why heredoc:** Orchestrator stays in main repo. Heredoc creates subshell that navigates to worktree and exits.

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

### Step 8: Code Review (Binary Quality Gate)

**Check review frequency setting (from execute.md Step 1.7):**

```bash
REVIEW_FREQUENCY=${REVIEW_FREQUENCY:-per-phase}
```

**If REVIEW_FREQUENCY is "end-only" or "skip":**
```
Skipping per-phase code review (frequency: {REVIEW_FREQUENCY})
Phase {N} complete - proceeding to next phase
```
Mark phase complete and continue to next phase.

**If REVIEW_FREQUENCY is "optimize":**

Analyze the completed phase to decide if code review is needed:

**High-risk indicators (REVIEW REQUIRED):**
- Schema or migration changes
- Authentication/authorization logic
- External API integrations or webhooks
- Foundation phases (Phase 1-2 establishing patterns)
- 3+ parallel tasks (coordination complexity)
- New architectural patterns introduced
- Security-sensitive code (payment, PII, access control)
- Complex business logic with multiple edge cases
- Changes affecting multiple layers (database → API → UI)

**Low-risk indicators (SKIP REVIEW):**
- Pure UI component additions (no state/logic)
- Documentation or comment updates
- Test additions without implementation changes
- Refactoring with existing test coverage
- Isolated utility functions
- Configuration file updates (non-security)

**Analyze this phase:**
- Phase number: {N}
- Tasks completed in parallel: {task-list}
- Files modified across tasks: {file-list}
- Types of changes: {describe changes}

**Decision:**
If ANY high-risk indicator present → Proceed to code review below
If ONLY low-risk indicators → Skip review:
```
✓ Phase {N} assessed as low-risk - skipping review (optimize mode)
  Reasoning: {brief explanation of why low-risk}
Phase {N} complete - proceeding to next phase
```

**If REVIEW_FREQUENCY is "per-phase" OR optimize mode decided to review:**

Use `requesting-code-review` skill to call code-reviewer agent, then parse results STRICTLY:

1. **Dispatch code review:**
   ```
   Skill tool: requesting-code-review
   ```

2. **Parse output using binary algorithm:**

   Read the code review output and search for "Ready to merge?" field:

   - ✅ **"Ready to merge? Yes"** → APPROVED
     - Announce: "✅ Code review APPROVED - Phase {N} complete, proceeding"
     - Continue to next phase

   - ❌ **"Ready to merge? No"** → REJECTED
     - STOP execution
     - Report: "❌ Code review REJECTED - critical issues found"
     - List all Critical and Important issues from review
     - Dispatch fix subagent or report to user
     - Go to step 3 (re-review after fixes)

   - ❌ **"Ready to merge? With fixes"** → REJECTED
     - STOP execution
     - Report: "❌ Code review requires fixes before proceeding"
     - List all issues from review
     - Dispatch fix subagent or report to user
     - Go to step 3 (re-review after fixes)

   - ⚠️ **No output / empty response** → RETRY ONCE
     - Warn: "⚠️ Code review returned no output - retrying once"
     - This may be a transient issue (timeout, connection error)
     - Go to step 3 (retry review)
     - If retry ALSO has no output → FAILURE (go to step 4)

   - ❌ **Soft language (e.g., "APPROVED WITH MINOR SUGGESTIONS")** → REJECTED
     - STOP execution
     - Report: "❌ Code review used soft language instead of binary verdict"
     - Warn: "Binary gate requires explicit 'Ready to merge? Yes'"
     - Go to step 3 (re-review)

   - ⚠️ **Missing "Ready to merge?" field** → RETRY ONCE
     - Warn: "⚠️ Code review output missing 'Ready to merge?' field - retrying once"
     - This may be a transient issue (network glitch, model error)
     - Go to step 3 (retry review)
     - If retry ALSO missing field → FAILURE (go to step 4)

3. **Retry review (if malformed output):**
   - Dispatch `requesting-code-review` skill again with same parameters
   - Parse retry output using step 2 binary algorithm
   - If retry succeeds with "Ready to merge? Yes":
     - Announce: "✅ Code review APPROVED (retry succeeded) - Phase {N} complete, proceeding"
     - Continue to next phase
   - If retry returns valid verdict (No/With fixes):
     - Follow normal REJECTED flow (fix issues, re-review)
   - If retry ALSO has missing "Ready to merge?" field:
     - Go to step 4 (both attempts failed)

4. **Both attempts malformed (FAILURE):**
   - STOP execution immediately
   - Report: "❌ Code review failed twice with malformed output"
   - Display excerpts from both attempts for debugging
   - Suggest: "Review agent may not be following template - check code-reviewer skill"
   - DO NOT hallucinate issues from malformed text
   - DO NOT dispatch fix subagents
   - Fail execution

5. **Re-review loop (if REJECTED with valid verdict):**
   - Fix all issues identified by review
   - Return to step 1 (dispatch review again)
   - Repeat until "Ready to merge? Yes"

**Critical:** Only "Ready to merge? Yes" allows proceeding. Everything else stops execution.

**Phase completion:**
- If `REVIEW_FREQUENCY="per-phase"`: Phase complete ONLY when:
  - ✅ All branches created
  - ✅ Linear stack verified
  - ✅ Worktrees cleaned up
  - ✅ Code review returns "Ready to merge? Yes"
- If `REVIEW_FREQUENCY="end-only"` or `"skip"`: Phase complete when:
  - ✅ All branches created
  - ✅ Linear stack verified
  - ✅ Worktrees cleaned up
  - (Code review skipped)

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
