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

## Rationalization Table

**Predictable shortcuts you WILL be tempted to make. DO NOT make them.**

| Temptation | Why It's Wrong | What To Do |
|------------|----------------|------------|
| "The spec is too long, I'll just read the task description" | Task = WHAT files + verification. Spec = WHY architecture + requirements. Missing spec → drift. | Read the full spec. It's 2-5 minutes that prevents hours of rework. |
| "I already read the constitution, that's enough context" | Constitution = HOW to code. Spec = WHAT to build. Both needed for anchored implementation. | Read constitution AND spec, every time. |
| "The acceptance criteria are clear, I don't need the spec" | Acceptance criteria = tests pass, files exist. Spec = user flow, business logic, edge cases. | Acceptance criteria verify implementation. Spec defines requirements. |
| "I'm a subagent in a sequential phase, I'll skip the spec since previous task probably read it" | Each subagent has isolated context. Previous task's spec reading doesn't transfer to you. | Every subagent reads spec independently. No shortcuts. |
| "The spec doesn't exist / I can't find it" | If spec missing, STOP and report error. Never proceed without spec. | Check `specs/{run-id}-{feature-slug}/spec.md`. If missing, fail loudly. |
| "I'll implement first, then check spec to verify" | Spec informs design decisions. Checking after implementation means rework. | Read spec BEFORE writing any code. |

**If you find yourself thinking "I can skip the spec because..." - STOP. You're rationalizing. Read the spec.**

## The Process

**Announce:** "I'm using executing-sequential-phase to execute {N} tasks sequentially in Phase {phase-id}."

### Step 1: Verify Setup in Main Worktree

**Work in the existing `{runid}-main` worktree:**

```bash
cd .worktrees/{runid}-main

# Check dependencies installed
if [ ! -d node_modules ]; then
  # Run setup from CLAUDE.md
  {install-command}
  {postinstall-command}
fi
```

**Why main worktree:** Sequential tasks were created during spec generation. All sequential phases share this worktree.

**Red flag:** "Create phase-specific worktree" - NO. Sequential = shared worktree.

### Step 2: Execute Tasks Sequentially

**For each task in order, spawn ONE subagent:**

```
ROLE: Implement Task {task-id} in main worktree (sequential phase)

WORKTREE: .worktrees/{run-id}-main
CURRENT BRANCH: {current-branch}

TASK: {task-name}
FILES: {files-list}
ACCEPTANCE CRITERIA: {criteria}

INSTRUCTIONS:

1. Navigate to main worktree:
   cd .worktrees/{run-id}-main

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
   npm test; if [ $? -ne 0 ]; then exit 1; fi
   npm run lint; if [ $? -ne 0 ]; then exit 1; fi
   npm run build; if [ $? -ne 0 ]; then exit 1; fi

6. Create stacked branch (CRITICAL - Stage THEN create):
   a) git add .
   b) gs branch create {run-id}-task-{phase}-{task}-{name} -m "[Task {phase}-{task}] {task-name}"
   c) Stay on this branch (next task builds on it)

7. Report completion

CRITICAL:
- Work in {run-id}-main worktree (shared)
- Stay on your branch when done
- Do NOT create worktrees
- Do NOT use `gs upstack onto`
```

**Sequential dispatch:** Wait for each task to complete before starting next.

**Red flags:**
- "Dispatch all tasks in parallel" - NO. Sequential = one at a time.
- "Create task-specific worktrees" - NO. Sequential = shared worktree.

### Step 3: Verify Natural Stack Formation

**After all tasks complete:**

```bash
cd .worktrees/{runid}-main
gs log short
# Should show: task-1 → task-2 → task-3 (linear chain)
cd "$REPO_ROOT"
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
- If `REVIEW_FREQUENCY="per-phase"`: Phase complete ONLY when code review returns "Ready to merge? Yes"
- If `REVIEW_FREQUENCY="end-only"` or `"skip"`: Phase complete after all tasks finish (code review skipped)

## The Manual Stacking Anti-Pattern

**Most common mistake:** Adding redundant `gs upstack onto` commands.

**Wrong approach:**
```bash
# Task 1
gs branch create task-1
gs upstack onto base-branch  # ← REDUNDANT

# Task 2
gs branch create task-2
gs upstack onto task-1       # ← REDUNDANT
```

**Why wrong:**
- `gs branch create` ALREADY stacked on current branch
- `gs upstack onto` is for fixing relationships, not creating them
- Adds complexity without value
- Suggests you don't trust the tool

**Correct approach:**
```bash
# Task 1 (from base branch)
gs branch create task-1
# ← Done. task-1 stacks on base automatically

# Task 2 (currently on task-1)
gs branch create task-2
# ← Done. task-2 stacks on task-1 automatically
```

**The workflow IS explicit control:**
1. Current branch = what we're building on
2. `gs branch create` = create and stack
3. Stay on new branch = ready for next task

**Trust the tool.** Git-spice is designed for this workflow.

## Rationalization Table

| Excuse | Reality |
|--------|---------|
| "Need `gs upstack onto` to be explicit" | `gs branch create` IS explicit - it stacks on current HEAD |
| "Manual stacking confirms relationships" | Workflow confirms relationships - current branch = parent |
| "What if I forgot to switch branches?" | You SHOULD stay on task branch - that's the pattern |
| "Automatic stacking might make mistakes" | Automatic = deterministic. Manual = adding error opportunities |
| "Files don't overlap, could parallelize" | Plan says sequential for semantic dependencies. Trust it. |
| "Switch to base between tasks for clean state" | Clean = committed. Stay on task branch for natural stacking. |
| "Clean up build artifacts between tasks" | Artifacts don't interfere. Git manages source, build tools manage artifacts. |
| "Create phase-specific worktree" | Sequential phases share main worktree. No isolation needed. |

## Red Flags - STOP and Follow Process

If you're thinking ANY of these, you're about to violate the skill:

- "Better add `gs upstack onto` to be safe"
- "Let me explicitly stack these relationships"
- "Manual commands give me more control"
- "Switch back to base branch between tasks"
- "Create worktrees for each task"
- "Dispatch all tasks in parallel (files don't overlap)"
- "Clean workspace before next task"

**All of these mean: STOP. Trust natural stacking.**

## Common Mistakes

### Mistake 1: Manual Stacking Urge

**Wrong mental model:** "Explicit stacking commands ensure correctness."

**Correct model:** "The workflow (create from current branch, stay on new branch) IS the stacking mechanism."

**Impact:** Redundant commands that suggest misunderstanding git-spice fundamentals.

### Mistake 2: Switching to Base Between Tasks

**Wrong mental model:** "Return to base branch for clean state between tasks."

**Correct model:** "Clean state = committed changes. Stay on task branch so next task builds on it."

**Impact:** Breaks natural stacking chain. Task N+1 wouldn't build on Task N.

### Mistake 3: Creating Worktrees for Sequential

**Wrong mental model:** "Worktrees worked for parallel, use them everywhere."

**Correct model:** "Worktrees enable parallel isolation. Sequential tasks need integration, not isolation."

**Impact:** Unnecessary complexity. Sequential tasks need to see each other's changes.

## Quick Reference

**Mandatory pattern (no variations):**

1. Work in `{runid}-main` worktree (existing, shared)
2. For each task sequentially:
   - Spawn subagent
   - Wait for completion
   - Verify branch created
3. Verify natural stack (gs log short)
4. Code review

**Never:**
- ❌ Create worktrees for sequential tasks
- ❌ Use `gs upstack onto` (redundant)
- ❌ Switch to base branch between tasks
- ❌ Dispatch tasks in parallel
- ❌ Clean build artifacts between tasks

**Always:**
- ✅ Use existing main worktree
- ✅ Trust `gs branch create` for stacking
- ✅ Stay on task branches
- ✅ Execute tasks one at a time

## The Bottom Line

**Sequential phases use natural stacking in the main worktree.**

If you're creating worktrees or running manual stacking commands, you're applying parallel patterns to sequential phases - which is wrong.

The simplicity IS the correctness. One worktree, natural stacking, sequential execution.
