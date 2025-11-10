---
name: parallel-phase-task
description: Use when executing a single task in a parallel phase - reads spec, implements task within phase boundaries, runs quality checks, and creates branch with HEAD detach
---

# Parallel Phase Task

## When to Use

Invoked by `executing-parallel-phase` orchestrator to implement a single task in isolated worktree.

**Announce:** "I'm implementing Task {task-id} in parallel phase."

## Phase Boundaries - CRITICAL

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

## Rationalization Table

| Temptation | Why It's Wrong |
|------------|----------------|
| "Stubs aren't implementation" | Stubs are files from later phases. Files = violation. |
| "Types without logic are OK" | Type files establish contracts. No files from later phases. |
| "Temporary code for testing" | Temporary becomes permanent. No files from later phases. |
| "The spec is too long, I'll just read task description" | Task = WHAT files. Spec = WHY architecture. Missing spec → drift. |

## The Process

1. Navigate to worktree: `cd .worktrees/{run-id}-task-{task-id}`

2. Verify isolation: `pwd` (must show task worktree path)

3. Read constitution (if exists): `docs/constitutions/current/`

4. Read spec: `specs/{run-id}-{feature-slug}/spec.md`
   - WHAT to build (requirements, user flows)
   - WHY decisions were made (architecture rationale)
   - HOW features integrate (system boundaries)

5. Verify phase scope - Read PHASE BOUNDARIES from orchestrator context

6. Implement task following spec + constitution + phase boundaries

7. Run quality checks (test, lint, build) - use heredoc for bash safety

8. Create branch with HEAD detach:
   ```
   Skill: phase-task-verification

   Parameters:
   - RUN_ID: {run-id}
   - TASK_ID: {phase}-{task}
   - TASK_NAME: {short-name}
   - COMMIT_MESSAGE: "[Task {phase}.{task}] {description}"
   - MODE: parallel
   ```

9. Report completion: Branch created, HEAD detached, files modified, acceptance met

## Quality Rules

- NO files from later phases
- Spec read before implementation
- Quality checks pass (if defined)
- Branch verified
- HEAD detached (critical for worktree cleanup)

## Error Handling

**Spec missing:** STOP and report error
**Quality checks fail:** Fix issues, re-run, only proceed when passing
**Branch creation fails:** phase-task-verification handles recovery
**Worktree isolation broken:** Verify pwd shows correct task worktree
