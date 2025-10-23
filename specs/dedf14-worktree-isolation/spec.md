---
runId: dedf14
feature: worktree-isolation
created: 2025-10-23
status: draft
---

# Feature: Worktree Isolation for Spectacular Execution

**Status**: Draft
**Created**: 2025-10-23
**Run ID**: dedf14

## Problem Statement

**Current State:**
The `/spectacular:execute` workflow blocks the main repository during execution:
- Sequential tasks run directly in main repo, checking out branches after each task
- Parallel task cleanup checks out branches in main repo for restacking
- Integration tests run on checked-out branches in main repo

**Desired State:**
- Main repository completely untouched during spectacular execution
- Multiple spectacular features can run concurrently
- User can continue manual work in main repo while spectacular runs in background
- True worktree isolation for parallel tasks

**Gap:**
Main repo occupation prevents concurrent spectacular runs and interferes with manual work during execution.

## Requirements

> **Note**: All features must follow @docs/constitutions/current/

### Functional Requirements

- FR1: Create main worktree (`.worktrees/{runId}-main`) for each spectacular execution
- FR2: All sequential tasks execute within main worktree
- FR3: Parallel tasks execute in separate worktrees (`.worktrees/{runId}-task-{phase}-{task}`)
- FR4: Main repository working directory never changes during execution
- FR5: Support concurrent spectacular runs with different runIds
- FR6: Resume execution reuses existing main worktree if valid (no dirty state)
- FR7: Manual cleanup command removes all worktrees for a given runId
- FR8: Orchestrator subagent never changes directory (stays in main repo)
- FR9: Implementation subagents receive absolute paths and cd into worktrees

### Non-Functional Requirements

- NFR1: No impact on existing git-spice stacking behavior
- NFR2: Backward compatible with existing plans (generate runId on-the-fly if missing)
- NFR3: Clear error messages for worktree conflicts and dirty state
- NFR4: Integration tests validate no interference between concurrent runs

## Architecture

> **Layer boundaries**: @docs/constitutions/current/architecture.md
> **Required patterns**: @docs/constitutions/current/patterns.md

### Components

**New Skills:**
- `skills/managing-worktrees/SKILL.md` - Worktree lifecycle operations (create, validate, cleanup)
  - Pattern 1: Create main worktree with resume validation
  - Pattern 2: Create parallel task worktrees
  - Pattern 3: Cleanup parallel worktrees (with mandatory TodoWrite checklist)
  - Pattern 4: Manual cleanup command support
- `skills/orchestrating-isolated-subagents/SKILL.md` - Directory isolation patterns
  - Orchestrator stays in main repo (never cd)
  - Subagents receive absolute paths and cd into worktrees
  - Path verification and error handling

**Enhanced Skills:**
- `skills/using-git-spice/SKILL.md` - Add concurrent run safety section
  - Document safe operations during parallel runs (branch create, upstack onto, stack submit)
  - Document unsafe operations (repo restack, repo sync)

**New Commands:**
- `commands/cleanup.md` - `/spectacular:cleanup {runId}` command
  - Remove all worktrees for specified runId
  - Preserve branches (only clean working directories)

**Modified Commands:**
- `commands/execute.md` - Update workflow to use worktrees
  - Add Step 0c: Create main worktree (delegate to setup subagent)
  - Update all subagent prompts with worktree path parameters
  - Add `cd .worktrees/{runId}-main` to sequential task setup
  - Update parallel phase to create/cleanup task worktrees
  - Add skill references throughout (managing-worktrees, orchestrating-isolated-subagents)

### Dependencies

**No new packages required** - uses existing git worktree functionality

**Git worktree requirements:**
- Git version 2.30+ (supports worktree operations)
- See: https://git-scm.com/docs/git-worktree

**Git-spice patterns:**
- All branch operations remain identical
- See: `skills/using-git-spice/SKILL.md` for concurrent safety

### Integration Points

**Git worktrees:**
- Created via `git worktree add` with absolute/relative paths
- Shared `.git` directory (all worktrees use same git database)
- Cleanup via `git worktree remove` (working directory only, branches preserved)

**Git-spice:**
- Branch creation: `gs branch create` works identically in worktrees
- Branch stacking: `gs upstack onto` handles linear restacking after parallel tasks
- Stack submission: `gs stack submit` operates on current branch's stack

**Subagent orchestration:**
- Orchestrator dispatches subagents with `WORKTREE_PATH` parameter (per orchestrating-isolated-subagents skill)
- Subagents start in main repo, cd into worktree as first step
- All paths absolute to prevent confusion

**Resume logic:**
- Check for existing `.worktrees/{runId}-main` at execution start
- Validate state: no uncommitted changes, not detached HEAD
- Reuse if valid, error if invalid (dirty state requires manual intervention)

### Worktree Lifecycle

**Creation:**
1. Main worktree: Created once at execution start from current branch
2. Parallel worktrees: Created per phase, removed after restacking
3. All paths: `.worktrees/{runId}-*` (gitignored directory)

**Cleanup:**
- Parallel worktrees: Removed automatically after each parallel phase
- Main worktree: Left in place after execution (manual cleanup via `/spectacular:cleanup`)
- Branches: Never removed (preserved in `.git`)

**Resume:**
- Existing main worktree validated before reuse
- Failed validation: Error with manual fix instructions
- Clean state: Resume from incomplete tasks

## Acceptance Criteria

**Constitution compliance:**
- [ ] Skills follow superpowers format (@docs/constitutions/current/patterns.md)
- [ ] Commands delegate to skills (@docs/constitutions/current/architecture.md)
- [ ] TodoWrite used for multi-step workflows (@docs/constitutions/current/patterns.md)
- [ ] Git-spice patterns followed (@docs/constitutions/current/patterns.md)

**Feature-specific:**
- [ ] Main repo never changes directory during execution
- [ ] Sequential tasks execute in `.worktrees/{runId}-main`
- [ ] Parallel tasks execute in separate worktrees
- [ ] Concurrent spectacular runs don't interfere (different runIds)
- [ ] User can work in main repo during spectacular execution
- [ ] Resume reuses valid main worktree
- [ ] Cleanup command removes worktrees without affecting branches
- [ ] Integration tests validate concurrent run isolation

**Verification:**
- [ ] All tests pass (test with 2 concurrent spectacular runs)
- [ ] Manual work in main repo during execution causes no conflicts
- [ ] Resume after interruption works correctly
- [ ] Cleanup command removes worktrees cleanly
- [ ] Git-spice stacking behavior unchanged

## Open Questions

None - design document already reviewed and approved.

## References

- Architecture: @docs/constitutions/current/architecture.md
- Patterns: @docs/constitutions/current/patterns.md
- Schema Rules: @docs/constitutions/current/schema-rules.md
- Tech Stack: @docs/constitutions/current/tech-stack.md
- Testing: @docs/constitutions/current/testing.md
- Design Document: @docs/plans/2025-10-23-worktree-isolation-design.md
- Git worktree docs: https://git-scm.com/docs/git-worktree
- Git-spice docs: https://github.com/abhinav/git-spice
