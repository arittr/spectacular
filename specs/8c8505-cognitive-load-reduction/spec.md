---
runId: 8c8505
feature: cognitive-load-reduction
created: 2025-11-10
status: draft
---

# Feature: Three-Skill Split for Cognitive Load Reduction

**Status**: Draft
**Created**: 2025-11-10

## Problem Statement

**Current State:**
- `executing-sequential-phase` and `executing-parallel-phase` skills are 750+ lines each
- Subagents receive 100% of content (orchestration + verification + task execution)
- Subagents need only ~20% (task execution instructions)
- Cognitive overload causes production failures:
  - Phase boundary violations (agents implement work from later phases)
  - Spec-anchoring weakness (agents skim past "read spec" buried in noise)
  - Multiple code review fix iterations (1-3 per phase)

**Evidence:**
- Pressure test phase-boundaries: FAILED - all 3 loopholes exploited (stubs, types, temporary code)
- Production execution (bignight.party): Phase 3 implemented Phase 4+5 work
- Validation test mixed-sequential-parallel-phases: FAILED - missing cross-phase documentation

**Desired State:**
- Subagent-facing instructions ≤100 lines (80% reduction)
- Phase boundary violations: Zero
- Pressure test phase-boundaries: All 3 loopholes closed
- Code review iterations: <1 per phase
- Maintainable: Add orchestrator features without affecting subagents

**Gap:**
Current monolithic skills mix orchestrator concerns (verification, code review, cleanup) with task execution concerns (spec reading, implementation, branch creation), causing cognitive overload that leads to production failures.

## Requirements

> **Note**: All features must follow @docs/constitutions/current/

### Functional Requirements

**FR1: Separate orchestrator and task execution concerns**
- Orchestrator skills contain ONLY: setup, dispatch, verification, code review
- Task skills contain ONLY: phase boundaries, spec reading, implementation, branch creation
- No duplication between orchestrator and task concerns

**FR2: Share verification logic across sequential and parallel**
- Single `phase-task-verification` skill used by both task types
- Handles MODE: sequential (stay on branch) vs parallel (detach HEAD)
- Eliminates duplication of branch verification logic

**FR3: Fix phase boundary language to close loopholes**
- Replace ambiguous "DO NOT IMPLEMENT" with explicit "DO NOT CREATE ANY FILES"
- Add explicit counters for all 3 loopholes: stubs, types, temporary code
- Visual emphasis (separators, bullet points, repetition)
- Rationalization table entries based on OBSERVED pressure test failures

**FR4: Preserve existing functionality**
- All 6 validation tests pass (currently 5/6)
- All 2 execution tests pass (currently 2/2)
- All 2 pressure tests pass (currently 1/2)
- Natural stacking works (sequential + parallel)
- Cross-phase stacking works (sequential → parallel → sequential)
- Code review autonomous fix loops work

**FR5: Context passing from orchestrator to task**
- Orchestrator extracts phase context ONCE from plan.md
- Passes to task subagent via Skill tool prompt
- Task receives: phase boundaries, task details, context references
- No context duplication or re-parsing

### Non-Functional Requirements

**NFR1: Maintainability**
- Can add orchestrator features (e.g., resume support, enhanced error recovery) without modifying task skills
- Can improve verification logic in one place (shared skill)
- Clear separation of concerns enables independent evolution

**NFR2: Testability**
- Each skill pressure-testable independently
- Verification skill: Test branch creation failure scenarios
- Task skills: Test phase boundary compliance under pressure
- Orchestrator skills: Test dispatch, verification, code review orchestration

**NFR3: Performance**
- No measurable performance regression from skill dispatch overhead
- Subagent dispatch: <500ms additional latency per task
- Acceptable: Cognitive load reduction >> dispatch overhead

**NFR4: Backward compatibility**
- Existing worktrees and branches continue to work
- No breaking changes to execute.md command interface
- Rollback possible via git revert

## Architecture

> **Layer boundaries**: @docs/constitutions/current/architecture.md
> **Required patterns**: @docs/constitutions/current/patterns.md

### Component Structure

```
Command Layer
  execute.md (unchanged)
    ↓
Orchestrator Layer (NEW split)
  executing-sequential-phase (300 lines)
  executing-parallel-phase (300 lines)
    ↓
Task Execution Layer (NEW)
  sequential-phase-task (100 lines) ←─┐
  parallel-phase-task (100 lines) ←──┤
    ↓                                 │
Verification Layer (NEW)              │
  phase-task-verification (50 lines) ─┘
```

### New Files

**skills/phase-task-verification/SKILL.md** (50 lines)
- Purpose: Shared branch creation and verification logic
- Used by: Both sequential-phase-task and parallel-phase-task
- Responsibilities:
  - Execute `git add .`
  - Execute `gs branch create {branch-name}` with commit message
  - Self-verify HEAD matches expected branch
  - Handle MODE: sequential (stay on branch) vs parallel (detach)

**skills/sequential-phase-task/SKILL.md** (100 lines)
- Purpose: Task execution for sequential phases
- Dispatched by: executing-sequential-phase orchestrator
- Responsibilities:
  - Read phase boundaries (from orchestrator context)
  - Read spec + constitution
  - Implement task following boundaries
  - Run quality checks (test, lint, build)
  - Create branch using `Skill: phase-task-verification`
  - Report completion

**skills/parallel-phase-task/SKILL.md** (100 lines)
- Purpose: Task execution for parallel phases
- Dispatched by: executing-parallel-phase orchestrator
- Responsibilities:
  - Same as sequential-phase-task
  - Difference: MODE: parallel passed to verification skill

### Modified Files

**skills/executing-sequential-phase/SKILL.md** (750 → 300 lines)
- Remove: Task execution instructions (Step 3 subagent prompt)
- Remove: Branch creation self-verification (Step 3, item 7c)
- Replace Step 3 with: Dispatch `sequential-phase-task` skill with context
- Keep: All orchestration logic (Steps 0, 1, 2, 3.5, 4, 5)

**skills/executing-parallel-phase/SKILL.md** (750 → 300 lines)
- Remove: Task execution instructions (Step 6 subagent prompt)
- Remove: Branch creation self-verification (Step 6, item 9)
- Replace Step 6 with: Dispatch `parallel-phase-task` skill with context
- Keep: All orchestration logic (Steps 0-5, 7-8)

**commands/execute.md** (documentation update)
- Update: Document new skill architecture
- No functional changes to command behavior

### Phase Boundary Language (FR3)

**Location:** sequential-phase-task and parallel-phase-task skills

**Fixed format:**
```markdown
===== PHASE BOUNDARIES - CRITICAL =====

Phase {N}/{total}: {name}
This phase includes ONLY: Task {current-tasks}

DO NOT CREATE ANY FILES from later phases.

Later phases (DO NOT CREATE):
- Phase {N+1}: {name}
  ❌ NO implementation files
  ❌ NO stub functions (even with TODOs)
  ❌ NO type definitions or interfaces
  ❌ NO test scaffolding or temporary code

If tempted to create ANY file from later phases, STOP.
"Not fully implemented" = violation.
"Just types/stubs/tests" = violation.
"Temporary/for testing" = violation.

==========================================
```

**Rationalization table additions:**
```markdown
| "Stubs aren't implementation" | Stubs are files from later phases. Files = violation. |
| "Types without logic are OK" | Type files establish contracts. No files from later phases. |
| "Temporary code for testing" | Temporary becomes permanent. No files from later phases. |
```

### Context Interface (FR5)

**Orchestrator → Task skill:**
```markdown
ROLE: Implement Task {task-id}

PHASE BOUNDARIES:
{Fixed language from above}

TASK DETAILS:
- Name: {task-name}
- Files: {explicit-file-paths}
- Acceptance: {criteria}

CONTEXT REFERENCES:
- Spec: specs/{run-id}-{feature-slug}/spec.md
- Constitution: docs/constitutions/current/
- Worktree: .worktrees/{run-id}-main (or {task-worktree} for parallel)
```

**Task → Verification skill:**
```markdown
Parameters:
- RUN_ID: {run-id}
- TASK_ID: {phase}-{task}
- TASK_NAME: {short-name}
- COMMIT_MESSAGE: "[Task {phase}.{task}] {description}"
- MODE: sequential | parallel
```

### Integration Points

**Skill composition:**
- Orchestrators use `Skill: sequential-phase-task` or `Skill: parallel-phase-task`
- Task skills use `Skill: phase-task-verification`
- Follows @docs/constitutions/current/architecture.md (skills layer invokes other skills)

**Git-spice:**
- Verification skill executes `gs branch create` per current pattern
- No changes to git-spice integration
- See: @skills/using-git-spice/SKILL.md

**Code review:**
- Orchestrators still dispatch `requesting-code-review` from superpowers
- No changes to autonomous fix loop logic
- Remains in orchestrator layer (not moved to task skills)

## Acceptance Criteria

**Constitution compliance:**
- [ ] All patterns followed (@docs/constitutions/current/patterns.md)
  - Skills invoke other skills using Skill tool
  - RED-GREEN-REFACTOR testing for all new/modified skills
  - Rationalization tables based on OBSERVED behavior
  - TodoWrite for sequential steps
- [ ] Architecture boundaries respected (@docs/constitutions/current/architecture.md)
  - Skills layer properly separated (orchestrator vs task vs verification)
  - No duplication of concerns
- [ ] Testing requirements met (@docs/constitutions/current/testing.md)
  - Pressure tests for all skills (verification, task, orchestrator)
  - Validation tests re-run (6/6 passing)
  - Execution tests re-run (2/2 passing)

**Feature-specific:**
- [ ] Subagent-facing instructions ≤100 lines (FR1 - measured: line count of task skill)
- [ ] Verification skill shared (FR2 - verified: both task skills use same verification skill)
- [ ] Phase boundary loopholes closed (FR3 - verified: pressure test phase-boundaries passes)
- [ ] No regressions (FR4 - verified: all test suites pass)
- [ ] Context passing works (FR5 - verified: task receives all required context)
- [ ] Code review iterations reduced (NFR3 - measured: <1 per phase in production execution)

**Verification:**
- [ ] All validation tests pass (6/6)
- [ ] All execution tests pass (2/2)
- [ ] All pressure tests pass (2/2)
  - phase-boundaries: All 3 loopholes closed
  - missing-branch-detection: Verification catches failures
- [ ] Full execution run completes (sequential + parallel phases)
- [ ] No worktree or branch creation issues

## Migration Strategy

**Order of implementation:**

1. **Phase 1: Create verification skill (foundation)**
   - Create `phase-task-verification` skill
   - Pressure test: Branch creation failure scenarios
   - Must be rock-solid before task skills depend on it

2. **Phase 2: Refactor sequential skills**
   - Split `executing-sequential-phase` into orchestrator + task
   - Update orchestrator to dispatch task skill
   - Pressure test: phase-boundaries (must close all 3 loopholes)
   - Pressure test: missing-branch-detection (verify verification works)

3. **Phase 3: Refactor parallel skills**
   - Split `executing-parallel-phase` into orchestrator + task
   - Reuse `phase-task-verification` (MODE: parallel)
   - Pressure test: parallel-stacking-4-tasks
   - Pressure test: New parallel phase boundaries test

4. **Phase 4: Integration and documentation**
   - Update execute.md documentation
   - Run full validation suite (all 3 types)
   - Integration test: Full execution with sequential + parallel phases

## Risk Mitigation

**Risk: Breaking existing functionality**
- Mitigation: Run full validation suite after each phase
- Mitigation: Pressure tests validate before/after
- Rollback: Git revert to previous skill versions (forward fix preferred)

**Risk: Verification skill has bugs**
- Mitigation: Build and pressure-test verification skill FIRST (Phase 1)
- Mitigation: Used by both sequential/parallel (double validation in production)

**Risk: Context passing fails (orchestrator → task)**
- Mitigation: Test with sample execution in Phase 2
- Mitigation: Validate all required context present in task skill

**Risk: Pressure tests reveal new loopholes**
- Mitigation: REFACTOR phase mandatory per constitution
- Mitigation: Iterate until bulletproof
- Expected: 2-3 iterations per skill

## Open Questions

None - design validated through brainstorming phases 1-3.

## References

- Architecture: @docs/constitutions/current/architecture.md
- Patterns: @docs/constitutions/current/patterns.md
- Testing: @docs/constitutions/current/testing.md
- Superpowers: https://github.com/obra/superpowers
- Git-spice: @skills/using-git-spice/SKILL.md
- Pressure test framework: @tests/pressure/README.md
- Validation test framework: @tests/scenarios/README.md
