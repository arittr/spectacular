---
name: executing-sequential-phase
description: Use when orchestrating sequential phases in plan execution - executes tasks one-by-one in main worktree using git-spice natural stacking (NO manual upstack commands, NO worktree creation, tasks build on each other)
---

# Executing Sequential Phase

## Overview

**Sequential phases use natural git-spice stacking in the main worktree.**

Each task creates a branch with `gs branch create`, which automatically stacks on the current HEAD. No manual stacking operations needed.

**Critical distinction:** Sequential tasks BUILD ON each other. They need integration, not isolation.

## When to Use

Use this skill when `execute` command encounters a phase marked "Sequential" in plan.md:
- ✅ Tasks must run in order (dependencies)
- ✅ Execute in existing `{runid}-main` worktree
- ✅ Trust natural stacking (no manual `gs upstack onto`)
- ✅ Stay on task branches (don't switch to base between tasks)

**Sequential phases never use worktrees.** They share one workspace where tasks build cumulatively.

## The Natural Stacking Principle

```
SEQUENTIAL PHASE = MAIN WORKTREE + NATURAL STACKING
```

**What natural stacking means:**
1. Start on base branch (or previous task's branch)
2. Create new branch with `gs branch create` → automatically stacks on current
3. Stay on that branch when done
4. Next task creates from there → automatically stacks on previous

**No manual commands needed.** The workflow IS the stacking.

## The Process

**Announce:** "I'm using executing-sequential-phase to execute {N} tasks sequentially in Phase {phase-id}."

### Step 0: Verify Orchestrator Location

**MANDATORY: Verify orchestrator is in main repo root before any operations:**

```bash
REPO_ROOT=$(git rev-parse --show-toplevel)
CURRENT=$(pwd)

if [ "$CURRENT" != "$REPO_ROOT" ]; then
  echo "❌ Error: Orchestrator must run from main repo root"
  echo "Current: $CURRENT"
  echo "Expected: $REPO_ROOT"
  echo ""
  echo "Return to main repo: cd $REPO_ROOT"
  exit 1
fi

echo "✅ Orchestrator location verified: Main repo root"
```

**Why critical:**
- Orchestrator delegates work but never changes directory
- All operations use `git -C .worktrees/path` or `bash -c "cd path && cmd"`
- This assertion catches upstream drift immediately

### Step 1: Verify Setup in Main Worktree

**Check and install dependencies from main repo (orchestrator never cd's):**

```bash
# Check if dependencies installed in main worktree
if [ ! -d .worktrees/{runid}-main/node_modules ]; then
  echo "Installing dependencies in main worktree..."
  bash <<'EOF'
  cd .worktrees/{runid}-main
  {install-command}
  {postinstall-command}
  EOF
fi
```

**Why heredoc:** Orchestrator stays in main repo. Heredoc creates subshell that exits after commands.

**Why main worktree:** Sequential tasks were created during spec generation. All sequential phases share this worktree.

**Red flag:** "Create phase-specific worktree" - NO. Sequential = shared worktree.

### Step 2: Execute Tasks Sequentially

**For each task in order, dispatch sequential-phase-task skill:**

```
Skill: sequential-phase-task

Context:

ROLE: Implement Task {task-id} in main worktree (sequential phase)

WORKTREE: .worktrees/{run-id}-main
CURRENT BRANCH: {current-branch}

TASK: {task-name}
FILES: {files-list}
ACCEPTANCE CRITERIA: {criteria}

PHASE BOUNDARIES:
===== PHASE BOUNDARIES - CRITICAL =====

Phase {current-phase-id}/{total-phases}: {phase-name}
This phase includes ONLY: Task {task-ids-in-this-phase}

DO NOT CREATE ANY FILES from later phases.

Later phases (DO NOT CREATE):
- Phase {next-phase}: {phase-name} - {task-summary}
  ❌ NO implementation files
  ❌ NO stub functions (even with TODOs)
  ❌ NO type definitions or interfaces
  ❌ NO test scaffolding or temporary code

If tempted to create ANY file from later phases, STOP.
"Not fully implemented" = violation.
"Just types/stubs/tests" = violation.
"Temporary/for testing" = violation.

==========================================

CONTEXT REFERENCES:
- Spec: specs/{run-id}-{feature-slug}/spec.md
- Constitution: docs/constitutions/current/
- Plan: specs/{run-id}-{feature-slug}/plan.md
- Worktree: .worktrees/{run-id}-main
```

**Sequential dispatch:** Wait for each task to complete before starting next.

**Red flags:**
- "Dispatch all tasks in parallel" - NO. Sequential = one at a time.
- "Create task-specific worktrees" - NO. Sequential = shared worktree.
- "Spec mentions feature X, I'll implement it now" - NO. Check phase boundaries first.

### Step 3: Verify Natural Stack Formation

**After all tasks complete (verify from main repo):**

```bash
# Verify stack using bash subshell (orchestrator stays in main repo)
bash -c "cd .worktrees/{runid}-main && gs log short"
# Should show: task-1 → task-2 → task-3 (linear chain)
```

**Each `gs branch create` automatically stacked on the previous task's branch.**

**Red flag:** "Run `gs upstack onto` to ensure stacking" - NO. Already stacked naturally.

### Step 4: Code Review (Binary Quality Gate)

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
- Tasks completed: {task-list}
- Files modified: {file-list}
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

Use `requesting-code-review` skill, then parse results STRICTLY.

**AUTONOMOUS EXECUTION:** Code review rejections trigger automatic fix loops, NOT user prompts. Never ask user what to do.

1. **Dispatch code review:**
   ```
   Skill: requesting-code-review
   Context: WORKTREE, PHASE, TASKS, BASE_BRANCH, SPEC, PLAN
   ```

2. **Parse "Ready to merge?" field:**
   - **"Yes"** → APPROVED, continue to next phase
   - **"No"** or **"With fixes"** → REJECTED, dispatch fix subagent, go to step 3
   - **No output / missing field** → RETRY ONCE, if retry fails → STOP
   - **Soft language** → REJECTED, re-review required

3. **Re-review loop (if REJECTED):**
   - Track rejections (REJECTION_COUNT)
   - If count > 3: Escalate to user (architectural issues beyond subagent scope)
   - Dispatch fix subagent with:
     * Issues list (severity + file locations)
     * Context: constitution, spec, plan
     * Scope enforcement: If scope creep, implement LESS (roll back to phase scope)
     * Quality checks required
   - Re-review after fixes (return to step 1)
   - On approval: Announce completion with iteration count

**Critical:** Only "Ready to merge? Yes" allows proceeding. Everything else stops execution.

**Phase completion:**
- If `REVIEW_FREQUENCY="per-phase"`: Phase complete ONLY when code review returns "Ready to merge? Yes"
- If `REVIEW_FREQUENCY="end-only"` or `"skip"`: Phase complete after all tasks finish (code review skipped)

## Rationalization Table

| Excuse | Reality |
|--------|---------|
| "Need manual stacking commands" | `gs branch create` stacks automatically on current HEAD |
| "Files don't overlap, could parallelize" | Plan says sequential for semantic dependencies |
| "Create phase-specific worktree" | Sequential phases share main worktree |
| "Review rejected, ask user" | Autonomous execution means automatic fixes |
| "Scope creep but quality passes" | Plan violation = failure. Auto-fix to plan |

