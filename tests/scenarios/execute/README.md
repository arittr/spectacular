# Execute Command Test Scenarios

## Overview

This directory contains **6 critical behavior tests** for the `/spectacular:execute` command. These tests validate core workflows that enable spec-anchored development with parallel execution.

**Philosophy:** Test critical behaviors, not implementation details. Each test validates an end-to-end workflow that would cause user-facing failures if broken.

## Test Suite (6 Scenarios)

### 1. phase-scope-boundary-enforcement

**What it tests:** Subagents respect phase boundaries and don't implement work from later phases.

**Why critical:**
- Prevents scope creep (implementing Phases 3-4 in Phase 2)
- Validates autonomous fix loops (no user prompts)
- Tests spec + plan anchoring working together
- **This is the exact production bug reported (2025-11-08)**

**What breaks if this fails:**
- Phases lose isolation → defeats incremental review strategy
- Scope creep compounds across phases
- User gets prompted instead of autonomous fixes

---

### 2. code-review-rejection-loop

**What it tests:** Autonomous fix loops after code review rejection.

**Why critical:**
- Core value prop: autonomous execution from spec to stack
- Tests that orchestrator NEVER asks user what to do
- Validates fix → re-review → repeat until clean loop
- Iteration tracking and escalation (prevents infinite loops)

**What breaks if this fails:**
- User intervention breaks flow
- Autonomous execution becomes manual execution
- Quality gates don't work end-to-end

---

### 3. spec-injection-subagents

**What it tests:** All subagents receive spec context for architectural anchoring.

**Why critical:**
- Prevents architectural drift (subagents making blind decisions)
- Validates spec-anchored development philosophy
- Tests that constitution (HOW) + spec (WHAT) both reach subagents

**What breaks if this fails:**
- Subagents implement features without understanding requirements
- Code review catches drift → wasted rework cycles
- Features drift from product spec

---

### 4. parallel-stacking-4-tasks

**What it tests:** Parallel phase execution with worktrees and linear stacking.

**Why critical:**
- Core parallelization architecture (N=4 is realistic size)
- Tests worktree isolation, dependency installation, branch stacking
- Validates N-1 stacking formula (4 tasks = 3 upstack operations)
- Resume support (skip completed tasks)

**What breaks if this fails:**
- Parallel execution produces incorrect branch structure
- PRs can't be submitted as linear stack
- Resume doesn't work (re-executes completed work)

---

### 5. sequential-stacking

**What it tests:** Natural git-spice stacking in shared worktree.

**Why critical:**
- Validates sequential phase architecture (shared worktree, no manual stacking)
- Tests that `gs branch create` produces linear chain automatically
- Prevents manual stacking anti-pattern (`gs upstack onto`)

**What breaks if this fails:**
- Sequential phases create nested/parallel worktrees (wrong architecture)
- Branches don't stack linearly
- Manual stacking commands add complexity

---

### 6. mixed-sequential-parallel-phases

**What it tests:** Cross-phase transitions (sequential → parallel → sequential).

**Why critical:**
- Most real plans have mixed phase types
- Tests base branch inheritance across phase boundaries
- Validates main worktree positioning for next phase
- Tests end-to-end stack continuity

**What breaks if this fails:**
- Phase transitions break branch chain
- Parallel phase doesn't inherit sequential work
- Sequential phase after parallel starts from wrong base

---

## What We Removed (13 Scenarios)

**Edge cases (removed):**
- `single-task-parallel-phase` (N=1) - Covered by N=4 test
- `parallel-stacking-2-tasks` (N=2) - Covered by N=4 test
- `parallel-stacking-3-tasks` (N=3) - Covered by N=4 test
- `large-parallel-phase` (N=10) - Scalability, not correctness

**Implementation details (removed):**
- `bash-pattern-consistency` - Grep for specific bash patterns
- `code-review-binary-enforcement` - Implementation detail
- `code-review-malformed-retry` - Edge case handling
- `code-review-optimize-mode` - Feature flag behavior
- `orchestrator-location-discipline` - Implementation detail
- `worktree-creation` - Covered by parallel stacking test

**Recovery workflows (removed):**
- `task-failure-recovery` - Error handling, not happy path
- `quality-check-failure` - Error handling, not happy path
- `missing-setup-commands` - Input validation, not core behavior

**Why we removed them:**
- Tests HOW (implementation) not WHAT (behavior)
- Brittle to refactoring (grep for exact strings)
- Edge cases that rarely fail in practice
- Maintenance burden > value

---

## Test Coverage Strategy

**What we test:**
- ✅ Critical user-facing behaviors (6 tests)
- ✅ End-to-end workflows (spec → plan → execute → stack)
- ✅ Core architectural patterns (sequential, parallel, mixed)

**What we don't test:**
- ❌ Implementation details (specific error messages, line numbers)
- ❌ Edge cases that don't affect user workflows
- ❌ Error recovery paths (unless they break core functionality)

**Philosophy:** If a test breaks every time we improve clarity in documentation, it's testing the wrong thing.

---

## Running Tests

```bash
# Run all 6 critical tests
"Run the test suite for execute command"

# Expected: 6/6 pass (100%)
```

**If tests fail:**
1. Check if behavior actually broke (not just wording changed)
2. Fix implementation if behavior regressed
3. Update test if requirements changed intentionally

---

## Adding New Tests

**Only add tests that validate:**
1. New critical behaviors (not implementation details)
2. Production bugs that caused user-facing failures
3. End-to-end workflows that would break autonomous execution

**Don't add tests for:**
- Edge cases unless they cause real production issues
- Implementation details that might change during refactoring
- Error messages or specific wording
- Code patterns or style

---

## Maintenance

**When to update tests:**
- Feature requirements change (rare)
- Production bug discovered (add test first)
- Test becomes obsolete (mark and remove)

**When NOT to update tests:**
- Rewording for clarity
- Refactoring implementation
- Adding new features (unless test validates them)

**Test lifecycle:**
1. Write test for new critical behavior
2. Validate test passes with correct implementation
3. Keep test until feature is removed
4. Mark obsolete and remove when feature is intentionally removed

---

## Test Results Location

All test results are saved with timestamps:

```
tests/results/
├── latest/                    # Symlink to most recent run
└── {timestamp}/
    ├── summary.md            # Pass/fail summary
    ├── junit.xml             # CI/CD integration
    └── scenarios/            # Individual test logs
        ├── phase-scope-boundary-enforcement.log
        ├── code-review-rejection-loop.log
        ├── spec-injection-subagents.log
        ├── parallel-stacking-4-tasks.log
        ├── sequential-stacking.log
        └── mixed-sequential-parallel-phases.log
```

**Git tracking:**
- ✅ `summary.md` - Committed (trends over time)
- ❌ `junit.xml` - Ignored (CI regenerates)
- ❌ Scenario logs - Ignored (verbose, regenerated)
- ❌ `latest/` symlink - Ignored (local pointer)
