---
name: testing-spectacular
description: Use when creating or editing spectacular commands (spec, plan, execute) or updating constitution patterns - applies RED-GREEN-REFACTOR to test whether orchestrators can follow instructions correctly under realistic pressure (time constraints, cognitive load, parallel execution)
---

# Testing Spectacular Commands

## Overview

**Testing spectacular commands is TDD applied to orchestrator instructions.**

You find real execution failures (git logs, branch structure errors), create test scenarios that reproduce them, watch subagents follow ambiguous instructions incorrectly (RED), fix the instructions (GREEN), and verify subagents now execute correctly (REFACTOR).

**Core principle:** If you didn't watch an orchestrator misinterpret the instructions in a test, you don't know if your fix prevents the right failures.

**REQUIRED BACKGROUND:** You MUST understand superpowers:test-driven-development before using this skill. That skill defines the fundamental RED-GREEN-REFACTOR cycle. This skill applies TDD to spectacular workflow documentation.

## When to Use

Use when:
- Creating new spectacular commands (`/spectacular:spec`, `/spectacular:plan`, `/spectacular:execute`)
- Editing orchestrator instructions in commands/*.md
- Updating constitution patterns that affect command execution
- You observed real execution failures (wrong branches, nested worktrees, stacking failures, skipped steps)
- Instructions involve git-spice and worktrees (high complexity, easy to get wrong)
- Orchestrators work under time pressure (parallel phases waiting, multiple subagents to coordinate)

**Announce:** "I'm using testing-spectacular to verify these command instructions work correctly under pressure."

Don't test:
- Pure reference documentation (constitutions, skill reference tables)
- Single-step commands with no ambiguity
- Skills (use `testing-skills-with-subagents` instead)

## Differences From Other Testing Skills

| Skill | Tests What | Pressure Type | Goal |
|-------|-----------|---------------|------|
| **testing-skills-with-subagents** | Agent compliance with rules | Will they follow discipline? | Bulletproof against rationalization |
| **testing-workflows-with-subagents** | Generic workflow instructions | Can they understand steps? | Unambiguous step-by-step clarity |
| **testing-spectacular** | Spectacular orchestrator commands | Can they execute complex git workflows? | Correct git-spice + worktree orchestration |

**Spectacular-specific challenges:**
- Git-spice command sequences (track, stack, rebase order matters)
- Worktree context switching (main repo vs worktree vs nested paths)
- Parallel execution state management (multiple branches, detached HEAD)
- Cleanup ordering (worktrees before branches)

## TDD Mapping for Spectacular Commands

| TDD Phase | Spectacular Testing | What You Do |
|-----------|-------------------|-------------|
| **RED** | Find real failure | Check git logs for wrong branches, nested worktrees, stacking attempts |
| **Verify RED** | Create failing test | Reproduce with test repo + orchestrator pressure scenario |
| **GREEN** | Fix instructions | Replace delegation with explicit commands, add warnings, show consequences |
| **Verify GREEN** | Test with subagent | Same scenario with fixed instructions - correct execution |
| **REFACTOR** | Iterate on commands | Find remaining ambiguities, test edge cases, verify robustness |
| **Stay GREEN** | Re-verify | Test again with different pressures to ensure fix holds |

## RED Phase: Find Real Execution Failures

**Goal:** Gather evidence of how spectacular commands failed in actual execution.

**Where to look:**
- **Git branch structure**: `git branch | grep {runid}` shows wrong stacking, missing branches, temporary branches
- **Git log**: Commits on wrong branches, wrong commit messages, missing task commits
- **Worktree issues**: `git worktree list` shows nested paths, wrong base branches
- **Error messages**: "No such file or directory" in nested worktree paths
- **Execution logs**: Multiple stacking attempts, trial-and-error with git-spice commands

**Document evidence:**
```markdown
## RED Phase Evidence

**Source**: Run ID 9f92a8 git log and execution transcript

**Failure**: Orchestrator created nested worktree `.worktrees/9f92a8-main/.worktrees/9f92a8-task-1`

**Expected**: Create worktree `.worktrees/9f92a8-task-1` from main repo

**Root cause**: execute.md line 82 says "Orchestrator stays in main repo" but doesn't enforce with verification

**Evidence**: Error message "fatal: cannot change to '/path/.worktrees/9f92a8-main/.worktrees/9f92a8-main'"
```

**Critical:** Get actual run IDs, branch names, git commit hashes, error messages - not hypothetical scenarios.

### Common Spectacular Failure Patterns

From real testing (9f92a8 analysis):

| Failure Type | Symptom | Root Cause |
|--------------|---------|------------|
| **Nested worktrees** | `.worktrees/X/.worktrees/Y` paths | Orchestrator in worktree, not main repo |
| **Temporary branches** | `{runid}-task-N-tmp` in final stack | Worktree creation with `-b` flag, not cleaned up |
| **Multiple stacking attempts** | Trial and error with `gs upstack onto` | Instructions delegate to skill without showing commands |
| **Context confusion** | Commands run from wrong directory | No explicit verification of `pwd` before git operations |

## Create RED Test Scenario

**Goal:** Reproduce the failure in a controlled test environment.

### Test Repository Setup

Create minimal repo simulating spectacular execution state:

```bash
cd /tmp
mkdir spectacular-test-{failure-type} && cd spectacular-test-{failure-type}
git init
git config user.name "Test" && git config user.email "test@test.com"

# Initialize git-spice (required for stacking tests)
gs repo init

# Set up state that led to failure
# Example: Create main worktree for parallel phase test
RUN_ID="abc123"
git checkout -b ${RUN_ID}-main
git worktree add .worktrees/${RUN_ID}-main ${RUN_ID}-main

# Add dummy file for commits
echo "test" > README.md
cd .worktrees/${RUN_ID}-main
git add README.md && git commit -m "Initial commit"
cd ../..
```

### Orchestrator Pressure Scenario

Spectacular orchestrators face unique pressures:

| Pressure | Example | Effect on Orchestrator |
|----------|---------|----------------------|
| **Coordination load** | "Managing 3 parallel subagents", "Phase 2 waiting" | Skips verification, rushes commands |
| **Git complexity** | "Worktrees + git-spice + parallel branches" | Confused about context, wrong directory |
| **Time pressure** | "Parallel tasks waiting", "Already 90 minutes in" | Delegates to skills without reading them |
| **Precedent memory** | "I remember doing this before" | Uses wrong pattern from different context |
| **Instruction ambiguity** | "Use skill to..." without explicit commands | Trial-and-error, multiple attempts |

**Create pressure scenario document:**

```markdown
# RED Test: Parallel Worktree Creation (9f92a8 Reproduction)

**Role**: Orchestrator managing parallel phase execution

**Current state**:
- In directory: `.worktrees/abc123-main`
- Three parallel tasks ready to execute
- Need to create isolated worktrees for each task

**Instructions from execute.md (CURRENT VERSION)**:
```
Create isolated worktree for EACH task in parallel phase:

Use `using-git-worktrees` skill to create worktrees for:
- Task 1: prompts-module
- Task 2: logger-abstraction
- Task 3: codex-refactor

Each worktree should branch from abc123-main.
```

**Pressure**:
- Managing 3 parallel subagents (high coordination load)
- Phase execution already 90 minutes in (tired)
- Parallel tasks waiting for worktrees (time pressure)
- Need to move fast

**Options**:
A) Read using-git-worktrees skill (2-3 min delay)
B) Create worktrees directly with git worktree add -b
C) Verify in main repo first, then create worktrees
D) Just create them from current directory

Choose and execute NOW. Show exact commands.
```

### Run RED Test

```bash
# Dispatch haiku subagent with RED scenario
# Haiku simulates realistic "under pressure" orchestrator behavior
# Document exact commands used and resulting state
```

**Expected RED result**:
- Agent creates nested worktrees (`.worktrees/abc123-main/.worktrees/abc123-task-1`)
- OR creates temporary branches with `-b` flag that aren't cleaned up
- OR skips context verification and runs from wrong directory

If agent succeeds perfectly, scenario isn't realistic - add more pressure or make wrong option more tempting.

## GREEN Phase: Fix Instructions

**Goal:** Rewrite instructions to prevent the specific failure observed in RED.

### Analyze Root Cause

From RED test, identify:
- What was orchestrator's context when failure occurred?
- Which step was ambiguous?
- What did they assume about git state?
- What pattern did delegation miss?
- What verification was skipped?

**Example analysis from 9f92a8:**
```markdown
**Ambiguous**: "Use skill to create worktrees" - delegation without explicit commands
**Missing verification**: No check that orchestrator is in main repo
**Wrong assumption**: Orchestrator assumed current directory correct
**Skill mismatch**: using-git-worktrees creates feature worktrees with -b flag, not parallel task worktrees
**Pressure effect**: Skipped reading skill due to time pressure, guessed commands
```

### Fix Patterns for Spectacular Commands

**Pattern 1: Explicit Commands Over Delegation**

Orchestrators under time pressure need exact commands, not skill references.

<Before - Delegation>
```markdown
Use `using-git-spice` skill to:
- Navigate to {run-id}-main worktree
- Stack branches linearly
- Verify with gs log short
```
</Before>

<After - Explicit Commands>
```markdown
**Stack branches in linear order using this exact sequence:**

```bash
# Verify in main repo first
REPO_ROOT=$(git rev-parse --show-toplevel)
cd "$REPO_ROOT"

# Navigate to main worktree for stacking
cd .worktrees/{runid}-main

# Stack task branches linearly
git checkout {runid}-task-1-name
gs branch track

git checkout {runid}-task-2-name
gs branch track
gs upstack onto {runid}-task-1-name

git checkout {runid}-task-3-name
gs branch track
gs upstack onto {runid}-task-2-name

# Verify
gs log short

# Return to main repo
cd "$REPO_ROOT"
```

**If you don't stack in this order, branches won't form linear dependency chain.**

**Reference**: See `using-git-spice` skill for command details if uncertain.
```
</After>

**Pattern 2: Context Verification Upfront**

Add explicit verification before every critical git operation:

```markdown
**CRITICAL: Verify you are in main repo before creating worktrees.**

```bash
REPO_ROOT=$(git rev-parse --show-toplevel)
CURRENT_DIR=$(pwd)

if [ "$CURRENT_DIR" != "$REPO_ROOT" ]; then
  echo "ERROR: Must run from main repo, not worktree"
  echo "Current: $CURRENT_DIR"
  echo "Expected: $REPO_ROOT"
  exit 1
fi
```

If you run from worktree, you'll create nested worktrees that fail.
```

**Pattern 3: Show Consequences Immediately**

Don't bury warnings in skill references - state consequences inline:

```markdown
a) FIRST: Stage your changes
   - Command: `git add .`

b) THEN: Create new stacked branch (commits staged changes automatically)
   - Command: `gs branch create {branch-name} -m "commit message"`

**If you commit BEFORE creating branch, your work goes to the wrong branch.**

c) FINAL: Detach HEAD so branch is accessible in parent repo
   - Command: `git switch --detach`
```

**Pattern 4: Cleanup Order Matters**

Specify exact order for cleanup operations:

```markdown
**Cleanup order (MUST follow this sequence):**

1. FIRST: Remove worktrees
   ```bash
   git worktree remove .worktrees/{runid}-task-1
   git worktree remove .worktrees/{runid}-task-2
   ```

2. THEN: Delete temporary branches (if any)
   ```bash
   git branch -d {runid}-task-1-tmp 2>/dev/null || true
   ```

**If you delete branches before removing worktrees, cleanup fails with "worktree still exists" error.**
```

### Apply Fix to Command File

Edit the actual command file (e.g., `commands/execute.md`) with GREEN fix.

## Verify GREEN: Test Fix

**Goal:** Confirm orchestrators now execute correctly under same pressure.

### Reset Test Repository

```bash
cd /tmp/spectacular-test-{failure-type}
# Clean up RED test state
git worktree remove .worktrees/* 2>/dev/null || true
git worktree prune
git branch -D abc123-task-* 2>/dev/null || true

# Reset to pre-failure state
git checkout abc123-main
cd .worktrees/abc123-main
git reset --hard HEAD
cd ../..
```

### Create GREEN Test Scenario

Same as RED test but:
- Update to "Instructions from execute.md (NEW IMPROVED VERSION)"
- Include the fixed instructions with explicit commands
- Same pressure context (coordination, time, complexity)
- Same "execute NOW" urgency

### Run GREEN Test

```bash
# Dispatch haiku subagent with GREEN scenario
# Use same model for consistency
# Agent should now execute correctly without trial-and-error
```

**Expected GREEN result**:
- Agent uses exact commands from instructions
- No context verification errors
- Correct worktree/branch structure on first attempt
- Agent quotes reasoning showing they followed explicit commands
- Work ends up in correct state

**If agent still fails**: Instructions still ambiguous. Return to GREEN phase, add more explicit verification or consequences.

## REFACTOR Phase: Iterate on Command Clarity

**Goal:** Find and fix remaining ambiguities and edge cases.

### Test Additional Scenarios

Test variations to ensure robustness:
- Different phase types (sequential vs parallel)
- Different task counts (2 tasks vs 5 tasks)
- Different execution states (clean vs interrupted and resumed)
- Different agent models (haiku vs sonnet as orchestrator)
- Edge cases (worktree already exists, branch name conflicts)

### Common Spectacular Command Issues

| Issue | Symptom | Fix |
|-------|---------|-----|
| **Delegation without commands** | Trial-and-error with git-spice | Show exact command sequence inline |
| **Missing context checks** | Nested worktrees | Add `pwd` verification before git ops |
| **Cleanup order wrong** | "Worktree still exists" errors | Specify "FIRST remove worktrees, THEN delete branches" |
| **Temporary branch pollution** | `-tmp` branches in final stack | Add cleanup step to delete temp branches |
| **Skill pattern mismatch** | Wrong worktree creation flags | Replace delegation with orchestration-specific commands |

### Document Test Results

Create summary in project root:

```markdown
# Test Results: execute.md Parallel Worktree Creation

**Date**: 2025-11-03
**Failure analyzed**: Run ID 9f92a8 nested worktrees

**RED Phase**: Agent created `.worktrees/9f92a8-main/.worktrees/9f92a8-task-1` (reproduced)
**GREEN Phase**: Agent verified context, created correct worktree paths (fixed)
**REFACTOR**: Tested with 2, 3, 5 parallel tasks - all passed

**Fix applied**: commands/execute.md lines 380-400 (parallel worktree creation)
**Success criteria**: Worktrees created from main repo in correct paths
**Evidence**: No nested worktree errors, correct final structure verified with `git worktree list`
```

## Rationalization Table

Based on actual 9f92a8 execution and RED phase findings:

| Rationalization | Why It's Wrong | What to Do Instead |
|----------------|----------------|-------------------|
| "execute.md says stay in main repo, that's enough" | Orchestrator already in worktree when reading instruction | Add explicit context verification with exit on failure |
| "I'll delegate to using-git-worktrees skill" | That skill creates feature worktrees with `-b`, not parallel task worktrees | Show exact commands for orchestration-specific patterns inline |
| "I remember the git-spice commands from before" | Different context (sequential vs parallel) needs different approach | Read instructions, don't rely on memory of similar patterns |
| "Stacking commands seem obvious, I'll try them" | Trial-and-error wastes time, might create wrong structure | Follow explicit command sequence, verify with `gs log short` |
| "I'll read the skill to understand the workflow" | Under time pressure (parallel tasks waiting), won't actually read thoroughly | Show critical workflow inline, reference skill as backup only |
| "The instructions say to use the skill" | Delegation language ≠ explicit procedural steps | Replace "Use skill to..." with exact bash commands and ordering |

## Testing Checklist

**IMPORTANT: Use TodoWrite to track these steps.**

**RED Phase:**
- [ ] Find real execution failure from git logs or run transcripts
- [ ] Document evidence (run ID, branch names, error messages, wrong state)
- [ ] Create test repository simulating pre-failure state
- [ ] Write orchestrator pressure scenario with current ambiguous instructions
- [ ] Run haiku subagent test, document exact failure and commands used

**GREEN Phase:**
- [ ] Analyze root cause (what was ambiguous? what did pressure cause them to skip?)
- [ ] Fix instructions (explicit commands, context verification, consequences)
- [ ] Apply fix to actual command file (commands/execute.md or similar)
- [ ] Reset test repository to same starting state
- [ ] Write GREEN scenario with fixed instructions
- [ ] Run haiku subagent test, verify correct execution on first attempt

**REFACTOR Phase:**
- [ ] Test with different phase types (sequential, parallel)
- [ ] Test with different task counts and edge cases
- [ ] Test with different agent models (haiku, sonnet)
- [ ] Document all remaining ambiguities found
- [ ] Improve clarity for each issue
- [ ] Re-verify all scenarios pass

**Documentation:**
- [ ] Create test results summary document
- [ ] Document before/after instructions
- [ ] Save test scenarios for regression testing
- [ ] Note which lines in command file were changed

## When to Show Commands vs Delegate to Skills

**Show explicit commands inline when:**
- ✅ Orchestrator role (managing workflow, coordinating subagents)
- ✅ Pattern is orchestration-specific (not in referenced skill exactly)
- ✅ Under time pressure (phases waiting, parallel execution)
- ✅ High cognitive load (managing multiple agents, 2+ hours in)
- ✅ Failure consequence is high (wrong stack structure breaks feature)
- ✅ Git-spice + worktrees (complex state, easy to get wrong)

**Delegate to skill when:**
- ✅ Implementation subagent (has time to read thoroughly)
- ✅ Pattern is in skill exactly (not adapted for orchestration)
- ✅ Learning is valuable (will use skill again in similar context)
- ✅ Skill is short and focused (<50 lines)

**Hybrid approach (best for spectacular):**
- Show commands inline for orchestrator quick execution
- Reference skill as backup for edge cases and learning
- Example: "Use `using-git-spice` skill which teaches this workflow: [commands here]. Read the skill if uncertain."

## Common Mistakes

**❌ Testing without real failure evidence**
Starting with "this might be confusing" leads to fixes that don't address actual problems.
✅ **Fix:** Always start with git logs, run IDs, error messages, real execution transcripts.

**❌ Test scenario without orchestrator pressure**
Agents follow instructions carefully when not coordinating multiple subagents.
✅ **Fix:** Add coordination load (managing parallel agents), time pressure (phases waiting), cognitive load (90 min in, tired).

**❌ Improving instructions without testing**
Guessing what's clear vs actually verifying with subagents leads to still-ambiguous docs.
✅ **Fix:** Always run GREEN verification with haiku subagent before considering done.

**❌ Testing once with one scenario**
First test might not catch edge cases or different phase types.
✅ **Fix:** REFACTOR phase with sequential vs parallel, different task counts, different models.

**❌ Delegating to skills under orchestrator pressure**
Orchestrators won't actually read skills when coordinating multiple agents.
✅ **Fix:** Show exact commands inline for orchestration patterns, reference skills as backup only.

## Real-World Impact

**From testing execute.md after 9f92a8 analysis:**

**RED Phase**:
- Found nested worktree creation: `.worktrees/9f92a8-main/.worktrees/9f92a8-task-1`
- Found temporary branches not cleaned up: `9f92a8-task-N-tmp` in final stack
- Found multiple stacking attempts with trial-and-error

**GREEN Phase**:
- Added explicit context verification before worktree creation
- Replaced skill delegation with exact bash command sequences
- Added consequences immediately: "If you run from worktree, you'll create nested worktrees"
- Showed git-spice stacking commands inline instead of delegating

**REFACTOR Phase**:
- Tested with 2, 3, 5 parallel tasks - all passed
- Tested sequential phase instructions - correct branch creation
- Tested with different models - haiku and sonnet both succeeded

**Result**:
- Orchestrators execute correct git operations on first attempt
- No nested worktrees, no temporary branch pollution
- Stacking completes without trial-and-error
- Time saved: ~10-15 minutes per parallel phase execution

**Time investment**: 3 hours RED-GREEN-REFACTOR testing prevents repeated failures across all future spectacular executions.

## The Bottom Line

**Test spectacular commands the same way you test code.**

RED (find real git failures) → GREEN (fix with explicit commands) → REFACTOR (test edge cases).

Spectacular orchestrators face unique pressures: coordinating multiple agents, git-spice + worktree complexity, time constraints. Instructions must be explicit, verifiable, and show consequences immediately.

If you wouldn't deploy code without tests, don't deploy spectacular commands without verifying orchestrators can execute them correctly under realistic pressure.
