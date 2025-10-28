---
runId: 91a61e
feature: worktree-isolation
created: 2025-10-27
status: draft
---

# Feature: Worktree-Based Execution Isolation

**Status**: Draft
**Created**: 2025-10-27

## Problem Statement

**Current State:**
When Spectacular commands run (`/spectacular:spec`, `/spectacular:plan`, `/spectacular:execute`), all work happens in the main repository directory. This creates three blocking problems:

1. **Single execution limit**: Only one Spectacular execution can run at a time - running a second execution would interfere with the first's files and branch management
2. **Main repo locked**: Cannot make manual changes, experiments, or quick fixes in main repo while Spectacular is running
3. **Contamination risk**: Spectacular files (specs, plans) and branches live alongside manual work in the same directory and namespace

Currently:
- `/spectacular:spec` creates `specs/{runId}-{feature}/` in main repo (uncommitted)
- `/spectacular:plan` creates `specs/{runId}-{feature}/plan.md` in main repo (uncommitted)
- `/spectacular:execute` creates branches in main repo, spawns child worktrees for parallel tasks

**Desired State:**
Each Spectacular feature operates in complete isolation from the moment spec creation begins:

- Multiple features can be developed simultaneously (Feature A, Feature B, etc.)
- Main repo remains available for manual work throughout the entire lifecycle
- No contamination between Spectacular work and manual changes
- Clear separation: each feature has its own workspace from spec → plan → implementation

**Gap:**
Need to isolate all Spectacular work (spec, plan, execution) into a dedicated worktree per feature, so the main repo stays completely untouched.

## Requirements

> **Note**: All features must follow @docs/constitutions/current/

### Functional Requirements

**FR1: Main Worktree Creation**
- `/spectacular:spec` creates `.worktrees/main-{runId}/` after generating RUN_ID (Step 0 in command)
- Base worktree on current HEAD at time of spec creation
- Spec generation happens in main worktree, creating `specs/{runId}-{feature}/spec.md` there
- Subsequent commands (`/plan`, `/execute`) check for existing worktree and reuse it

**FR2: Sequential Task Isolation**
- Sequential task subagents work in `.worktrees/main-{runId}/`
- Create task branches in main worktree using `gs branch create`
- Stack builds linearly in main worktree namespace

**FR3: Parallel Task Isolation**
- Setup subagent (working in main worktree) creates child worktrees: `.worktrees/{runId}-task-X-Y/`
- Parallel task subagents work in their child worktrees
- Cleanup subagent removes child worktrees after parallel phase completes
- Only main worktree persists after parallel phase

**FR4: Main Worktree Persistence**
- Main worktree remains at `.worktrees/main-{runId}/` after execution completes
- User can inspect, test, or modify the stack in isolation
- Branches created in main worktree are accessible from main repo

**FR5: Cleanup Command**
- New command: `/spectacular:cleanup {runId}`
- Removes `.worktrees/main-{runId}/` when user is ready
- Safety checks: warn about uncommitted changes, unpushed branches
- List branches created during execution before cleanup

**FR6: Multiple Concurrent Executions**
- Different runIds create different main worktrees: `.worktrees/main-{runId1}/`, `.worktrees/main-{runId2}/`
- Each execution completely isolated from others
- Main repo can have manual branches without interference

**FR7: Uncommitted Changes Handling**
- `/spectacular:spec` checks for uncommitted changes before creating worktree
- If dirty state detected, use AskUserQuestion with 4 options:
  - Commit and proceed: Commit changes to main repo with message "WIP: Spectacular spec creation", create worktree from new HEAD (includes uncommitted work)
  - Stash and proceed: Stash changes with `git stash push -m "Spectacular: {feature-slug}"`, create worktree from clean HEAD (can pop stash later in main repo, output shows stash reference)
  - Proceed anyway: Create worktree from current HEAD (uncommitted changes stay in main repo only)
  - Abort: Exit so user can handle changes themselves
- Provide clear explanation of consequences for each option
- If commit fails (pre-commit hook failure): show error with hook output, offer retry or abort
- If stash fails (stash errors): show error, offer "proceed anyway" or abort
- Each failure includes recovery instructions

**FR8: Worktree State Management**
- All commands run `git worktree prune` before worktree operations (cleanup stale refs)
- Commands check if worktree exists before attempting to cd or create
- Graceful error handling if worktree missing/corrupted

**FR9: List Command**
- New command: `/spectacular:list`
- Shows all active features with: runId, feature name, age
- Phase status: spec only | spec+plan | executed (N branches)
- Staleness warning: ⚠️ if worktree base diverged from default branch (main/master/etc)
- Detect default branch dynamically:
  1. Try `git symbolic-ref refs/remotes/origin/HEAD | sed 's@^refs/remotes/origin/@@'`
  2. If fails: try `git config init.defaultBranch`
  3. If still fails: assume 'main', warn user to verify
- Staleness refresh: User can use git-spice/graphite to merge default branch into worktree branches

**FR10: Path Resolution**
- Commands accept paths in format: `@specs/{runId}-{feature}/spec.md`
- Extract runId from path using regex: `specs/([^-]+)-`
- cd into `.worktrees/main-{runId}/` based on extracted runId
- If path doesn't match format: show error with expected format
- Paths reported to user are absolute from main repo: `.worktrees/main-{runId}/specs/...`

**FR11: Dependency Installation**
- `/spectacular:execute` detects install procedure for worktree before first task
- Detection priority:
  1. Check CLAUDE.md for install instructions (look for "install", "setup", "dependencies" sections)
  2. If not in CLAUDE.md, check constitution (@docs/constitutions/current/tech-stack.md)
  3. If not specified, detect from lock files: pnpm-lock.yaml → package-lock.json → yarn.lock → bun.lockb → Cargo.lock → requirements.txt → Gemfile
  4. If no lock files: skip install (log info message)
- Run detected install command in worktree
- If install fails: fail the entire execution (exit with error)
- Ensures worktree has correct dependencies for implementation phase
- Supports non-Node.js projects (Python, Ruby, Rust, etc.)

**FR12: Orphaned Worktree Detection**
- `/spectacular:list` detects orphaned worktrees (no spec.md inside)
- Indicates failed/incomplete spec creation
- Offers cleanup via `/spectacular:cleanup {runId}` in output

### Non-Functional Requirements

**NFR1: Breaking Changes**
- NO backward compatibility with old specs/plans in main repo
- Major version bump required (v2.0.0)
- All Spectacular work MUST happen in worktrees going forward

**NFR2: Developer Experience**
- `ls .worktrees/main-*/` shows all active features
- `git branch | grep "^  {runId}-"` shows branches for specific feature
- Clear error messages if worktree creation fails
- Absolute paths in output for clarity

**NFR3: Safety**
- Never remove main worktree with uncommitted changes (without force flag)
- Warn if branches haven't been pushed/submitted before cleanup
- Verify worktree not in use by another process
- All safety-critical operations require user confirmation

**NFR4: Git-Spice Compatibility**
- Git-spice commands work correctly in worktree context
- Stacked branches created in worktrees are accessible from main repo
- `gs stack submit` works from worktree directory
- Use git-spice/graphite for refreshing stale worktrees (merge main into worktree branches)

**NFR5: Submodule Handling**
- Git worktree creation handles submodule references automatically
- User may need to run `git submodule update --init` in worktree if submodules not initialized
- Document this in error messages if submodule-related failures occur

## Architecture

> **Layer boundaries**: @docs/constitutions/current/architecture.md
> **Required patterns**: @docs/constitutions/current/patterns.md

### Components

**Modified Files:**

- `commands/spec.md` - Add Step 0.5 (Uncommitted Changes & Main Worktree Setup)
  - Check for uncommitted changes with `git status --porcelain`
  - If dirty: use AskUserQuestion with 4 options (commit/stash/proceed/abort)
  - Handle each choice with clear consequence explanation
  - Use `managing-main-worktrees` skill to create `.worktrees/main-{runId}/`
  - cd into main worktree for spec generation
  - Generate spec at `.worktrees/main-{runId}/specs/{runId}-{feature}/spec.md`
  - Report spec location as absolute path

- `commands/plan.md` - Add Step 0 (Main Worktree Setup)
  - Extract runId from spec path: `@specs/{runId}-{feature}/spec.md` → `{runId}`
  - Use `managing-main-worktrees` skill to check/create `.worktrees/main-{runId}/`
  - cd into main worktree
  - Generate plan at `.worktrees/main-{runId}/specs/{runId}-{feature}/plan.md`
  - Report plan location as absolute path

- `commands/execute.md` - Update Step 0.5 (Main Worktree Setup & Dependencies)
  - Extract runId from plan path: `@specs/{runId}-{feature}/plan.md` → `{runId}`
  - Use `managing-main-worktrees` skill to check/create `.worktrees/main-{runId}/`
  - cd into main worktree
  - **Step 0.6 (NEW)**: Detect and run install command (see FR11 for detection priority)
  - Update subagent prompts with main worktree paths
  - Sequential task prompts: `WORKING_DIR: .worktrees/main-{runId}/`
  - Parallel setup subagent: Create child worktrees from main worktree
  - Continue using `using-git-worktrees` skill for parallel task worktrees

**New Files:**

- `skills/managing-main-worktrees/SKILL.md` - Main worktree lifecycle management
  - Run `git worktree prune` to cleanup stale refs
  - Check if `.worktrees/main-{runId}/` exists via `git worktree list`
  - If exists: verify accessible, cd and confirm with `pwd`
  - If not exists: create with `git worktree add --detach .worktrees/main-{runId} HEAD`
    - Use --detach because same branch cannot be checked out in main repo and worktree
    - Allows independent branch creation via git-spice in worktree
  - After creation or when entering existing worktree: verify git-spice initialized
    - Run `gs ls 2>/dev/null` to test
    - If not initialized: run `gs repo init --continue-on-conflict`
    - Git-spice repo metadata is shared across worktrees (stored in .git/)
  - Handle errors gracefully (clear messages, recovery steps)
  - Rationalization table for skipping checks

- `commands/list.md` - List all active feature worktrees
  - Run `git worktree prune` first
  - Find all `.worktrees/main-*` directories
  - For each: extract runId, feature name, creation time
  - Detect phase: check for spec.md, plan.md, {runId}-task-* branches
  - Detect orphaned: worktree exists but no spec.md (failed creation)
  - Calculate staleness: compare worktree base to default branch (detect via `git symbolic-ref refs/remotes/origin/HEAD`)
  - Format output: runId, feature, age, phase, staleness warning
  - Example: `91a61e: worktree-isolation (2h ago) [spec+plan] ⚠️  12 commits behind`
  - For orphaned: `7f3c2a: (orphaned) (1h ago) - run /spectacular:cleanup 7f3c2a`

- `commands/cleanup.md` - Remove main worktree for a feature
  - Verify worktree exists via `git worktree list`
  - cd into `.worktrees/main-{runId}/` (skip if orphaned)
  - Check for uncommitted changes (`git status --porcelain`)
  - List all {runId}-* branches
  - For each branch: check if pushed
    - Check upstream exists: `git rev-parse @{u} 2>/dev/null`
    - If upstream: `git log @{u}.. --oneline` (unpushed commits)
    - If no upstream: mark as "never pushed"
  - Present summary with AskUserQuestion (confirm/abort)
  - Show what will be deleted (worktree) vs what remains (branches)
  - If confirmed:
    - Try `git worktree remove .worktrees/main-{runId}`
    - If fails (orphaned): `rm -rf .worktrees/main-{runId}` and `git worktree prune`
  - Report cleanup status and remaining branches
  - Reference patterns from `finishing-a-development-branch` and `verification-before-completion` skills

### Dependencies

**No new packages required.**

**Git worktree features:**
- `git worktree add` - Create main and child worktrees
- `git worktree remove` - Cleanup worktrees
- `git worktree list` - Verify worktree state
- See: https://git-scm.com/docs/git-worktree

**Git-spice:**
- `gs branch create` - Create task branches in main worktree
- `gs upstack onto` - Stack parallel branches linearly
- `gs log short` - View stack structure
- See: https://github.com/abhinav/git-spice

### Integration Points

**Spec command (`/spectacular:spec {feature-description}`)**:
- Step 0: Generate RUN_ID (unchanged)
- **Step 0.5 (NEW)**: Uncommitted changes & main worktree setup
  - Check `git status --porcelain`
  - If dirty: AskUserQuestion with 4 options
    - Option 1: Commit changes → create commit with message "WIP: Spectacular spec creation" → worktree includes changes
      - If commit fails (pre-commit hook failure): show error with hook output, offer retry or abort
    - Option 2: Stash changes → `git stash push -m "Spectacular: {feature-slug}"` → worktree from clean HEAD → can pop later (output shows stash reference)
      - If stash fails: show error, offer "proceed anyway" or abort
    - Option 3: Proceed anyway → worktree from HEAD → uncommitted stay in main repo
    - Option 4: Abort → exit, let user handle
  - Each failure includes recovery instructions
  - Use `managing-main-worktrees` skill: create `.worktrees/main-{runId}/`
  - cd into main worktree
- Step 1-3: Brainstorming phases (working from main worktree)
- Step 2: Generate specification (working from main worktree)
  - Spec written to `.worktrees/main-{runId}/specs/{runId}-{feature}/spec.md`
- Step 3: Architecture quality validation (unchanged)
- Step 4: Report completion with absolute path: `.worktrees/main-{runId}/specs/...`

**Plan command (`/spectacular:plan @specs/{runId}-{feature}/spec.md`)**:
- **Step 0 (NEW)**: Main worktree setup
  - Extract runId from spec path (regex match on `specs/([^-]+)-`)
  - Use `managing-main-worktrees` skill: check/create `.worktrees/main-{runId}/`
  - cd into main worktree
- Step 1-N: Decompose tasks (working from main worktree)
  - Plan written to `.worktrees/main-{runId}/specs/{runId}-{feature}/plan.md`
- Step N+1: Report completion with absolute path: `.worktrees/main-{runId}/specs/...`

**Execute command (`/spectacular:execute @specs/{runId}-{feature}/plan.md`)**:
- Step 0a: Extract RUN_ID from plan path (regex match on `specs/([^-]+)-`)
- Step 0b: Check for existing work (unchanged)
- **Step 0.5 (UPDATED)**: Main worktree setup
  - Use `managing-main-worktrees` skill: check/create `.worktrees/main-{runId}/`
  - cd into main worktree
- **Step 0.6 (NEW)**: Install dependencies
  - Detect install procedure (priority order):
    1. Read CLAUDE.md, look for install/setup/dependencies sections
    2. Check constitution: @docs/constitutions/current/tech-stack.md
    3. Detect from lock files: pnpm-lock.yaml, package-lock.json, yarn.lock, bun.lockb, Cargo.lock, requirements.txt, Gemfile
    4. If none found: skip install, log info message
  - Run detected install command in worktree
  - If install fails: fail entire execution with error message
  - Supports Node.js, Python, Ruby, Rust, and other ecosystems
- Step 1: Read and parse plan (path relative to main worktree)
- Step 2: Execute phases (updated subagent prompts)
  - Sequential task prompts include: `WORKING_DIR: .worktrees/main-{runId}/`
  - Parallel setup uses `using-git-worktrees` skill for child worktrees
- Step 3-5: Verification, finish stack, final report (working from main worktree)

**List command (`/spectacular:list`)**:
- Run `git worktree prune` to cleanup stale refs
- Detect default branch with fallback:
  1. Try `git symbolic-ref refs/remotes/origin/HEAD | sed 's@^refs/remotes/origin/@@'`
  2. If fails: try `git config init.defaultBranch`
  3. If still fails: assume 'main', warn user to verify
- List all `.worktrees/main-*` directories
- For each worktree:
  - Extract runId and feature name from path
  - Check creation time (mtime of directory)
  - Check if orphaned: worktree exists but no spec.md inside
  - Detect phase: `[ -f spec.md ]`, `[ -f plan.md ]`, `git branch | grep "^  {runId}-task-"`
  - Calculate staleness: compare worktree base to default branch
    - cd into worktree, run `git log --oneline {default-branch}..HEAD | wc -l`
  - Format: `{runId}: {feature} ({age}) [{phase}] {staleness-warning}`
  - For orphaned: `{runId}: (orphaned) ({age}) - run /spectacular:cleanup {runId}`
- Sort by creation time (newest first)

**Cleanup command (`/spectacular:cleanup {runId}`)**:
- Verify worktree exists: `git worktree list | grep ".worktrees/main-{runId}"`
- cd into `.worktrees/main-{runId}/` (skip if orphaned - no spec.md)
- Check uncommitted changes: `git status --porcelain` (if not orphaned)
- List branches: `git branch | grep "^  {runId}-"`
- For each branch: check if pushed
  - Check upstream: `git rev-parse @{u} 2>/dev/null`
  - If upstream: `git log @{u}.. --oneline` (shows unpushed commits)
  - If no upstream: mark as "never pushed"
- Build summary:
  - Worktree will be deleted: `.worktrees/main-{runId}/`
  - Uncommitted changes: N files (or "none")
  - Unpushed branches: N branches (list them)
  - Branches remain accessible: all {runId}-* branches
- AskUserQuestion: Confirm deletion (yes/no)
- If yes:
  - Try `git worktree remove .worktrees/main-{runId}`
  - If fails (orphaned): `rm -rf .worktrees/main-{runId}` + `git worktree prune`
- Report: "Cleaned up worktree. Branches: git branch | grep '{runId}-'"

**Subagent prompts**:
- Sequential tasks: Receive `WORKING_DIR: .worktrees/main-{runId}/` parameter
- Parallel tasks: Receive `WORKTREE: .worktrees/{runId}-task-X-Y/` parameter
- Setup/cleanup subagents: Work in main worktree context

### Workflow Changes

**Before (current)**:
```
User in main repo:
  /spectacular:spec
    → creates specs/{runId}-{feature}/spec.md (uncommitted in main repo)
  /spectacular:plan
    → creates specs/{runId}-{feature}/plan.md (uncommitted in main repo)
  /spectacular:execute
    → creates branches in main repo
    → spawns child worktrees for parallel tasks
    → stacks branches in main repo
Main repo contaminated with Spectacular files and branches
```

**After (with isolation)**:
```
User in main repo (stays clean):
  /spectacular:spec
    → creates .worktrees/main-{runId}/
    → cd into main worktree
    → creates specs/{runId}-{feature}/spec.md (in worktree)
  /spectacular:plan
    → cd into existing .worktrees/main-{runId}/
    → creates specs/{runId}-{feature}/plan.md (in worktree)
  /spectacular:execute
    → cd into existing .worktrees/main-{runId}/
    → creates branches in main worktree
    → spawns child worktrees for parallel tasks
    → stacks branches in main worktree
  /spectacular:cleanup {runId}
    → removes .worktrees/main-{runId}/
    → branches remain accessible in main repo

Main repo never touched, all Spectacular work isolated in .worktrees/main-{runId}/
```

## Acceptance Criteria

**Constitution compliance:**
- [ ] All patterns followed (@docs/constitutions/current/patterns.md)
- [ ] Architecture boundaries respected (@docs/constitutions/current/architecture.md)
- [ ] Testing requirements met (@docs/constitutions/current/testing.md)

**Feature-specific:**

**Spec command worktree behavior:**
- [ ] `/spectacular:spec` checks for uncommitted changes before worktree creation
- [ ] If dirty state: presents 4 options via AskUserQuestion (commit/stash/proceed/abort)
- [ ] Each option has clear consequence explanation
- [ ] Creates `.worktrees/main-{runId}/` using `managing-main-worktrees` skill
- [ ] Spec file created at `.worktrees/main-{runId}/specs/{runId}-{feature}/spec.md`
- [ ] Reports absolute path: `.worktrees/main-{runId}/specs/...`
- [ ] Main repo has no uncommitted spec files

**Plan command worktree behavior:**
- [ ] `/spectacular:plan` extracts runId from spec path
- [ ] Uses `managing-main-worktrees` skill to check/create worktree
- [ ] Reuses existing `.worktrees/main-{runId}/` if available
- [ ] Plan file created at `.worktrees/main-{runId}/specs/{runId}-{feature}/plan.md`
- [ ] Reports absolute path: `.worktrees/main-{runId}/specs/...`
- [ ] Main repo has no uncommitted plan files

**Execute command worktree behavior:**
- [ ] `/spectacular:execute` extracts runId from plan path
- [ ] Uses `managing-main-worktrees` skill to check/create worktree
- [ ] Detects and runs install command in worktree before first task (per FR11)
- [ ] Execution happens entirely in main worktree
- [ ] Main repo not modified during execution

**Sequential task isolation:**
- [ ] Sequential tasks create branches in main worktree
- [ ] Branches stack linearly in main worktree
- [ ] Sequential tasks do not touch main repo

**Parallel task isolation:**
- [ ] Child worktrees created from main worktree (not main repo)
- [ ] Parallel tasks work in child worktrees
- [ ] Child worktrees removed after parallel phase completes
- [ ] Only main worktree persists

**Main repo freedom:**
- [ ] Can make manual commits in main repo while execution runs
- [ ] Can switch branches in main repo during execution
- [ ] Manual branches do not interfere with Spectacular branches

**Multiple features simultaneously:**
- [ ] Can run `/spectacular:spec` for Feature A and Feature B simultaneously
- [ ] Can work on spec for Feature A while executing Feature B
- [ ] Each feature has its own main worktree (different runIds)
- [ ] Features do not interfere with each other
- [ ] `ls .worktrees/main-*/` shows all active features

**IDE accessibility:**
- [ ] Specs/plans in `.worktrees/main-{runId}/` are browsable in IDE (worktrees are subdirectories)
- [ ] Can review/edit spec/plan files in worktree using normal IDE navigation

**List command:**
- [ ] `/spectacular:list` runs `git worktree prune` first
- [ ] Detects default branch dynamically with fallback (origin/HEAD → init.defaultBranch → assume 'main' with warning)
- [ ] Shows all active features with runId, feature name, age
- [ ] Detects phase correctly: spec only | spec+plan | executed (N branches)
- [ ] Detects orphaned worktrees (no spec.md inside)
- [ ] Shows orphaned with cleanup hint: `{runId}: (orphaned) - run /spectacular:cleanup {runId}`
- [ ] Calculates staleness against detected default branch
- [ ] Shows warning if worktree base behind default branch
- [ ] Formats output consistently and sorts by creation time
- [ ] Handles empty list gracefully (no active features)

**Cleanup command:**
- [ ] `/spectacular:cleanup {runId}` verifies worktree exists first
- [ ] Handles orphaned worktrees gracefully (no spec.md inside)
- [ ] Checks for uncommitted changes in worktree (if not orphaned)
- [ ] Lists all {runId}-* branches with push status
- [ ] For each branch: checks if upstream exists before `git log @{u}..`
- [ ] Shows "never pushed" for branches without upstream
- [ ] Presents summary via AskUserQuestion with clear consequences
- [ ] Shows what will be deleted (worktree) vs what remains (branches)
- [ ] Only removes worktree after user confirmation
- [ ] Tries `git worktree remove` first, falls back to `rm -rf` for orphaned
- [ ] Runs `git worktree prune` after manual removal
- [ ] Works for exploratory specs (spec only, never executed)
- [ ] Works after full execution (spec → plan → execute)
- [ ] Branches remain accessible in main repo after cleanup
- [ ] Reports cleanup status with command to view branches

**Worktree state management:**
- [ ] All commands run `git worktree prune` before worktree operations
- [ ] Commands verify worktree exists before cd or create
- [ ] Graceful error messages if worktree missing/corrupted
- [ ] `managing-main-worktrees` skill enforces consistent patterns

**Path resolution:**
- [ ] Commands accept paths in format: `@specs/{runId}-{feature}/spec.md`
- [ ] Extract runId correctly using regex: `specs/([^-]+)-`
- [ ] If path doesn't match format: show error with expected format
- [ ] Commands report paths as absolute from main repo perspective
- [ ] User can copy-paste reported paths in IDE to view files

**Dependency management:**
- [ ] Execute command checks CLAUDE.md for install instructions first
- [ ] If not in CLAUDE.md: checks constitution (@docs/constitutions/current/tech-stack.md)
- [ ] If not specified: detects from lock files (Node.js, Python, Ruby, Rust, etc.)
- [ ] Detection priority: pnpm-lock.yaml → package-lock.json → yarn.lock → bun.lockb → Cargo.lock → requirements.txt → Gemfile
- [ ] Runs detected install command in worktree
- [ ] If no install procedure detected: skips with info message (not error)
- [ ] If install fails: fails entire execution with error
- [ ] Install runs before first task execution
- [ ] Supports non-Node.js projects (Python, Ruby, Rust)
- [ ] Tasks have access to correct dependencies

**Git-spice compatibility:**
- [ ] Git-spice commands work correctly in worktree context
- [ ] `gs branch create` works from main worktree
- [ ] `gs upstack onto` works for stacking branches
- [ ] `gs stack submit` works from worktree directory
- [ ] Branches created in worktree accessible from main repo

**Breaking changes:**
- [ ] Version bumped to v2.0.0 (major version)
- [ ] No backward compatibility with old specs in main repo
- [ ] Clear error messages for old workflow attempts
- [ ] Migration path documented (re-run /spectacular:spec)

**Uncommitted changes handling:**
- [ ] Spec command checks for uncommitted changes before worktree creation
- [ ] If dirty: presents 4 options via AskUserQuestion
- [ ] Each option has clear consequence explanation
- [ ] Commit option: creates commit with message "WIP: Spectacular spec creation", handles pre-commit hook failures with hook output
- [ ] Stash option: stashes with `git stash push -m "Spectacular: {feature-slug}"`, outputs stash reference, handles stash failures
- [ ] Proceed option: creates worktree, uncommitted stay in main repo
- [ ] Abort option: exits cleanly
- [ ] All failure cases provide recovery instructions

**Submodule support:**
- [ ] Worktree creation handles submodule references
- [ ] Error messages mention `git submodule update --init` if submodule issues occur
- [ ] Works with projects that have submodules

**Verification:**
- [ ] All tests pass after implementation
- [ ] Linting passes
- [ ] Spec → plan → execute workflow works end-to-end with isolation
- [ ] Main repo remains clean throughout entire lifecycle
- [ ] List command shows correct status for multiple features
- [ ] Cleanup workflow works correctly for all scenarios (normal and orphaned)
- [ ] Uncommitted changes handling works correctly (all 4 options + failures)
- [ ] Dependency detection works: CLAUDE.md → constitution → lock files → skip
- [ ] Install detection supports Node.js, Python, Ruby, Rust projects
- [ ] Default branch detection works for main/master/trunk repos

## Open Questions

None - design validated during brainstorming.

## References

**Constitutions:**
- Architecture: @docs/constitutions/current/architecture.md
- Patterns: @docs/constitutions/current/patterns.md
- Tech Stack: @docs/constitutions/current/tech-stack.md
- Testing: @docs/constitutions/current/testing.md

**Skills:**
- Managing main worktrees: @skills/managing-main-worktrees/SKILL.md (new)
- Using git worktrees: @skills/using-git-worktrees/SKILL.md (superpowers)
- Using git-spice: @skills/using-git-spice/SKILL.md (spectacular)
- Finishing a development branch: @skills/finishing-a-development-branch/SKILL.md (superpowers)
- Verification before completion: @skills/verification-before-completion/SKILL.md (superpowers)

**External Documentation:**
- Git worktree: https://git-scm.com/docs/git-worktree
- Git-spice: https://github.com/abhinav/git-spice
