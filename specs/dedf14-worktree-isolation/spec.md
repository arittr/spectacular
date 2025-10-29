---
runId: dedf14
feature: worktree-isolation
created: 2025-10-29
status: draft
---

# Feature: Worktree Isolation for Spectacular Runs

**Status**: Draft
**Created**: 2025-10-29

## Problem Statement

**Current State:**
Spectacular commands (`/spec`, `/plan`, `/execute`) operate directly in the main repository's working directory:
- Serial tasks execute in main repo
- Parallel tasks use isolated worktrees in `.worktrees/`
- Spec and plan files committed to main repo's `specs/` directory
- Main repo working directory is modified during execution

**Limitations:**
- Cannot perform manual work in main repo during a spectacular run
- Cannot run multiple spectacular sessions concurrently (branch/worktree conflicts)
- Main repo state changes unexpectedly during runs
- No clear isolation boundary between spectacular work and manual work

**Desired State:**
All spectacular work happens in isolated worktrees:
- Each run has dedicated `{runId}-main` worktree
- Specs, plans, and all task execution isolated from main repo
- Main repo working directory never touched by spectacular commands
- Multiple concurrent runs possible (different runIds = different worktrees)
- User can continue manual work in main repo during spectacular execution

**Gap:**
Need to shift from "main repo = workspace" to "main repo = untouched, everything in worktrees" by creating worktree upfront in `/spectacular:spec` command.

## Requirements

> **Note**: All features must follow @docs/constitutions/current/

### Functional Requirements

**FR1: Worktree Creation in Spec Command**
- `/spectacular:spec` creates `.worktrees/{runId}-main/` worktree immediately after RUN_ID generation
- Branch `{runId}-main` created using git-spice from currently checked out branch
- Worktree creation happens before brainstorming/spec generation
- Spec file written to `.worktrees/{runId}-main/specs/{runId}-{slug}/spec.md`
- Spec committed to `{runId}-main` branch in worktree

**FR2: Plan Command Worktree Integration**
- `/spectacular:plan` extracts `{runId}` from spec path
- Changes working directory to `.worktrees/{runId}-main/`
- Reads spec from worktree, generates plan in worktree
- Commits plan to `{runId}-main` branch
- No fallback to main repo (spec must be in worktree)

**FR3: Execute Command Worktree Base**
- `/spectacular:execute` extracts `{runId}` from plan path
- Uses `.worktrees/{runId}-main/` as base for all execution
- Serial tasks execute directly in `{runId}-main` worktree
- Parallel tasks create additional worktrees branching from `{runId}-main` branch
- All git-spice stacking relative to `{runId}-main` branch

**FR4: Main Repo Isolation**
- Main repo working directory never modified by spectacular commands
- Main repo branch never changed by spectacular commands
- User can work normally in main repo during spectacular runs
- Main repo state remains at whatever was checked out before `/spectacular:spec`

**FR5: Concurrent Run Support**
- Multiple `/spectacular:spec` invocations create independent worktrees
- Different runIds = different worktrees (no conflicts)
- Each run has own `{runId}-main` branch tracked in git-spice
- Worktrees can coexist simultaneously

**FR6: Error Handling**
- If `.worktrees/{runId}-main/` already exists: Clear error message
- If plan/execute can't find worktree: Error instructs to run `/spectacular:spec` first
- If worktree creation fails: Report failure with git error details

### Non-Functional Requirements

**NFR1: Backward Compatibility Breaking**
- This is a breaking change: existing specs in main repo won't work with updated commands
- Acceptable tradeoff for cleaner architecture and concurrent run support

**NFR2: Manual Cleanup**
- Worktrees and branches remain after completion (manual cleanup)
- User decides when to remove worktree: `git worktree remove .worktrees/{runId}-main`
- User decides when to delete branch: `gs branch delete {runId}-main`
- Task branches remain in stack even after removing worktree

**NFR3: Git-spice Integration**
- All branch creation uses git-spice for proper stack tracking
- Reference `using-git-spice` skill for command patterns
- Maintain stack relationships across worktree boundaries

## Architecture

> **Layer boundaries**: @docs/constitutions/current/architecture.md
> **Required patterns**: @docs/constitutions/current/patterns.md

### Components

**Modified Files:**
- `commands/spec.md` - Add worktree creation step immediately after RUN_ID generation
  - Use `using-git-spice` skill to create `{runId}-main` branch
  - Create worktree with `git worktree add`
  - Change working context to worktree for all subsequent operations
  - Commit spec to worktree branch before completion

- `commands/plan.md` - Add worktree detection and context switching
  - Extract `{runId}` from spec path argument
  - Switch to `.worktrees/{runId}-main/` working directory
  - Error if worktree doesn't exist
  - Commit plan to worktree branch

- `commands/execute.md` - Update execution base from main repo to worktree
  - Extract `{runId}` from plan path argument
  - Use `.worktrees/{runId}-main/` as base directory for all work
  - Serial tasks execute in `{runId}-main` worktree
  - Parallel tasks branch from `{runId}-main` branch
  - All stacking relative to `{runId}-main` branch

**No New Files:**
- Worktrees are git constructs (`.worktrees/` directory managed by git)
- No new skills needed (`using-git-spice` already exists)
- No new scripts needed

### Dependencies

**Existing dependencies (no changes):**
- Git worktrees (git 2.x+)
- git-spice CLI
- Superpowers plugin (`using-git-spice` skill)

See: @docs/constitutions/current/tech-stack.md

### Integration Points

**Git Worktrees:**
- Standard git worktree commands (`git worktree add`, `git worktree remove`)
- `.worktrees/` directory convention (already in `.gitignore`)
- Each worktree has own working directory, shared git history

**Git-spice:**
- Use `using-git-spice` skill for branch creation patterns
- `gs branch create {runId}-main` tracks branch in stack
- Branch created from currently checked out branch (context-aware)
- All subsequent task branches stack on `{runId}-main`

**Spectacular Commands:**
- `/spectacular:spec` creates workspace, writes spec
- `/spectacular:plan` operates in workspace, writes plan
- `/spectacular:execute` operates in workspace, creates additional worktrees
- Commands pass `{runId}` implicitly via file paths

## Acceptance Criteria

**Constitution compliance:**
- [ ] Architecture boundaries respected (@docs/constitutions/current/architecture.md)
- [ ] Git-spice patterns followed (@docs/constitutions/current/patterns.md via `using-git-spice`)
- [ ] Tech stack requirements met (@docs/constitutions/current/tech-stack.md)

**Feature-specific:**
- [ ] `/spectacular:spec` creates `.worktrees/{runId}-main/` before generating spec
- [ ] Spec file written to worktree, not main repo
- [ ] Spec committed to `{runId}-main` branch in worktree
- [ ] `/spectacular:plan` reads spec from worktree, writes plan to worktree
- [ ] Plan committed to `{runId}-main` branch in worktree
- [ ] `/spectacular:execute` uses worktree as base for all work
- [ ] Main repo working directory unchanged after any spectacular command
- [ ] Multiple concurrent `/spectacular:spec` runs don't conflict
- [ ] Error messages guide user when worktree missing

**Verification:**
- [ ] Run `/spectacular:spec {feature}` - verify worktree created before spec generation
- [ ] Check main repo: `git status` shows no changes
- [ ] Run `/spectacular:plan @specs/{runId}-{slug}/spec.md` - verify reads/writes in worktree
- [ ] Run second `/spectacular:spec {other-feature}` concurrently - verify no conflicts
- [ ] Run `/spectacular:execute` - verify serial tasks in worktree, parallel tasks in additional worktrees
- [ ] Manual work in main repo during execution completes without interference

## Open Questions

None - design validated in brainstorming Phase 3.

## References

- Architecture: @docs/constitutions/current/architecture.md
- Patterns: @docs/constitutions/current/patterns.md
- Tech Stack: @docs/constitutions/current/tech-stack.md
- Testing: @docs/constitutions/current/testing.md
- Git-spice: `skills/using-git-spice/SKILL.md`
- Git Worktrees: https://git-scm.com/docs/git-worktree
