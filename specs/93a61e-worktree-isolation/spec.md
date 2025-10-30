---
runId: 93a61e
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

- `/spectacular:spec` creates `specs/{runId}-{feature-slug}/` in main repo (uncommitted)
- `/spectacular:plan` creates `specs/{runId}-{feature-slug}/plan.md` in main repo (uncommitted)
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
- Generate feature slug from feature description:
  - Convert to lowercase
  - Replace spaces with hyphens
  - Remove special characters (keep alphanumerics and hyphens)
  - Truncate to 50 characters max
  - Example: "Add User Authentication" → "add-user-authentication"
- Spec generation happens in main worktree, creating `specs/{runId}-{feature-slug}/spec.md` there
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

- List command runs `git worktree prune` to cleanup stale refs (only command that prunes proactively)
- `managing-main-worktrees` skill runs `git worktree prune` only as recovery if operations fail
- Commands check if worktree exists before attempting to create
- Graceful error handling if worktree missing/corrupted

**FR9: List Command**

- New command: `/spectacular:list`
- Shows all active features with: runId, feature name, age
- Phase status: spec only | spec+plan | executed (N branches)
- Staleness warning: ⚠️ if worktree base diverged from default branch
- Detect default branch reliably:
  1. Try `git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's@^refs/remotes/origin/@@'`
  2. If fails: try `git config --get init.defaultBranch 2>/dev/null`
  3. If fails: check which exists: `git rev-parse --verify main 2>/dev/null` then `git rev-parse --verify master 2>/dev/null`
  4. If none exist: skip staleness check (no baseline to compare)
- Calculate staleness (commits behind): `git log --oneline HEAD..origin/{default-branch} 2>/dev/null | wc -l`
- Show both behind and ahead if non-zero: "⚠️ 12 behind, 3 ahead" or just "⚠️ 12 behind"
- Staleness refresh: User can use git-spice/graphite to merge default branch into worktree branches

**FR10: Path Resolution**

- Commands accept paths in format: `@specs/{runId}-{feature-slug}/spec.md`
- Extract runId from path using regex: `specs/([^-]+)-`
- Use runId to determine working directory: `.worktrees/main-{runId}/`
- Commands cd to worktree (if doing work directly) or pass path to subagents
- If path doesn't match format: show error with expected format
- Paths reported to user are absolute from main repo: `.worktrees/main-{runId}/specs/...`

**FR11: Dependency Installation**

- `/spectacular:execute` detects install procedure for worktree before first task
- Detection strategy (language-agnostic, heuristic-based):
  1. Check CLAUDE.md for install instructions (look for "install", "setup", "dependencies" sections)
  2. If not in CLAUDE.md, check constitution (@docs/constitutions/current/tech-stack.md)
  3. If not specified: Use LLM inference to detect install command from codebase artifacts
     - Examine files in root directory (lock files, config files, build manifests)
     - Infer language/ecosystem from file patterns (package.json + lock → Node.js, requirements.txt/pyproject.toml → Python, Cargo.toml → Rust, go.mod → Go, etc.)
     - Select appropriate install command based on detected ecosystem and tooling
     - Prioritize faster package managers when multiple options exist (pnpm > npm, uv > pip)
  4. If no clear install procedure detected: skip install (log info message)
- Run detected install command in worktree
- If install fails: fail the entire execution (exit with error)
- Ensures worktree has correct dependencies for implementation phase
- Supports any language ecosystem with standard package management

**FR12: Orphaned Worktree Detection**

- `/spectacular:list` and `/spectacular:cleanup` detect orphaned worktrees (no spec inside)
- Check from main repo using full path: `ls .worktrees/main-{runId}/specs/{runId}-*/spec.md 2>/dev/null`
- If ls exits non-zero (file doesn't exist): worktree is orphaned (failed/incomplete spec creation)
- If ls exits 0 (file exists): worktree is valid, extract feature slug from matched path
- List command offers cleanup via `/spectacular:cleanup {runId}` in output for orphaned worktrees
- Cleanup command handles orphaned worktrees gracefully (skips cd and state checks)

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

- Never remove main worktree with uncommitted changes without explicit user confirmation
- Warn if branches haven't been pushed/submitted before cleanup
- All safety-critical operations require user confirmation via AskUserQuestion

**NFR4: Git-Spice Compatibility**

- Git-spice commands work correctly in worktree context
- Stacked branches created in worktrees are accessible from main repo
- `gs stack submit` works from worktree directory
- Use git-spice/graphite for refreshing stale worktrees (merge main into worktree branches)

**NFR5: Submodule Handling**

- Git worktree creation handles submodule references automatically
- User may need to run `git submodule update --init` in worktree if submodules not initialized
- Document this in error messages if submodule-related failures occur

**NFR6: Context Management**

- Spec command dispatches subagent for spec generation to avoid compaction in orchestrator
- Subagent prompt pre-loads constitution context (architecture, patterns, etc.) for constitution-aware brainstorming
- Brainstorming sessions can be long (many AskUserQuestion rounds) using stock superpowers:brainstorming skill
- Subagent gets fresh context for entire spec workflow, no compaction risk
- Orchestrator only handles worktree setup (minimal context usage)
- AskUserQuestion prompts from subagent still visible to user (bubble up)

## Architecture

> **Layer boundaries**: @docs/constitutions/current/architecture.md
> **Required patterns**: @docs/constitutions/current/patterns.md

### Components

**Modified Files:**

- `commands/spec.md` - Generate feature spec in isolated worktree using subagent (avoids compaction)
- `commands/plan.md` - Generate execution plan in main worktree
- `commands/execute.md` - Run implementation in main worktree with dependency detection

**New Files:**

- `commands/list.md` - List all active feature worktrees with staleness and orphaned detection
- `commands/cleanup.md` - Remove main worktree with safety checks for uncommitted/unpushed work
- `skills/managing-main-worktrees/SKILL.md` - Main worktree lifecycle (check/create/recover, detached HEAD)

### Dependencies

**No new packages required.** Uses git worktrees and existing git-spice installation.

- Git worktrees: https://git-scm.com/docs/git-worktree
- Git-spice: https://github.com/abhinav/git-spice

### Integration Points

**Spec command (`/spectacular:spec {feature-description}`)**:

- Step 0: Generate RUN_ID and feature-slug from feature description (see FR1 for slug generation rules)
- **Step 0.5 (NEW)**: Uncommitted changes & main worktree setup (orchestrator stays in main repo)
  - Check `git status --porcelain`
  - If dirty: AskUserQuestion with 4 options
    - Option 1: Commit changes → create commit with message "WIP: Spectacular spec creation" → worktree includes changes
      - If commit fails (pre-commit hook failure): show error with hook output, offer retry or abort
    - Option 2: Stash changes → `git stash push -m "Spectacular: {feature-slug}"` → worktree from clean HEAD → can pop later (output shows stash reference)
      - If stash fails: show error, offer "proceed anyway" or abort
    - Option 3: Proceed anyway → worktree from HEAD → uncommitted stay in main repo
    - Option 4: Abort → exit, let user handle
  - Each failure includes recovery instructions
  - Use `managing-main-worktrees` skill: check/create `.worktrees/main-{runId}/`
  - Orchestrator remains in main repo (does not cd)
- **Step 1 (NEW)**: Dispatch subagent for spec generation
  - Pass to subagent: feature description, working directory (`.worktrees/main-{runId}/`), runId
  - Subagent prompt pre-loads constitution context by reading:
    - @docs/constitutions/current/architecture.md (layer boundaries)
    - @docs/constitutions/current/patterns.md (mandatory patterns)
    - Other constitutions as needed (tech-stack, testing, etc.)
  - Subagent workflow (fresh context, no compaction):
    - cd to working directory first
    - Use stock `superpowers:brainstorming` skill to refine feature (constitution-aware)
    - Use `spectacular:writing-specs` skill to generate specification
    - Write spec to `specs/{runId}-{feature-slug}/spec.md` (relative path in worktree)
    - Architecture quality validation
    - Return summary to orchestrator
  - AskUserQuestion prompts bubble up to user during subagent execution
- **Step 2**: Orchestrator reports completion with absolute path: `.worktrees/main-{runId}/specs/...`

**Plan command (`/spectacular:plan @specs/{runId}-{feature-slug}/spec.md`)**:

- **Step 0 (NEW)**: Main worktree setup
  - Extract runId from spec path (regex match on `specs/([^-]+)-`)
  - Use `managing-main-worktrees` skill: check/create `.worktrees/main-{runId}/`
  - Orchestrator cd's: `cd .worktrees/main-{runId}/`
- Step 1-N: Decompose tasks (orchestrator working from main worktree)
  - Plan written to `specs/{runId}-{feature-slug}/plan.md` (relative path)
- Step N+1: Report completion with absolute path: `.worktrees/main-{runId}/specs/...`
- Note: Plan generation runs directly in orchestrator (no subagents), so orchestrator must cd

**Execute command (`/spectacular:execute @specs/{runId}-{feature-slug}/plan.md`)**:

- Step 0a: Extract RUN_ID from plan path (regex match on `specs/([^-]+)-`)
- Step 0b: Check for existing work (unchanged)
- **Step 0.5 (UPDATED)**: Main worktree setup
  - Use `managing-main-worktrees` skill: check/create `.worktrees/main-{runId}/`
  - Orchestrator cd's: `cd .worktrees/main-{runId}/`
- **Step 0.6 (NEW)**: Install dependencies (orchestrator runs in worktree)
  - Detect install procedure (priority order):
    1. Read CLAUDE.md, look for install/setup/dependencies sections
    2. Check constitution: @docs/constitutions/current/tech-stack.md
    3. Use LLM inference: examine root files, infer language/ecosystem, select appropriate install command
    4. If no clear procedure: skip install, log info message
  - Run detected install command in worktree (orchestrator executes)
  - If install fails: fail entire execution with error message
  - Language-agnostic: supports any ecosystem with standard package management
- Step 1: Read and parse plan (relative path)
- Step 2: Execute phases
  - Sequential task subagents: Receive working directory path (`.worktrees/main-{runId}/`), cd themselves
  - Parallel setup subagent: Receives working directory path, cd's to create child worktrees
  - Parallel task subagents: Receive child worktree path (`.worktrees/{runId}-task-X-Y/`), cd themselves
  - Continue using `using-git-worktrees` skill for parallel task worktrees
- Step 3-5: Verification, finish stack, final report (orchestrator working from main worktree)
- Note: Orchestrator cd's to run install and coordinate, subagents receive working directory paths explicitly

**List command (`/spectacular:list`)**:

- ALL checks start from main repo
- **Step 1**: Cleanup and setup
  - Run `git worktree prune` to cleanup stale refs
  - Detect default branch reliably:
    1. Try `git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's@^refs/remotes/origin/@@'`
    2. If fails: try `git config --get init.defaultBranch 2>/dev/null`
    3. If fails: check which exists with `git rev-parse --verify` (main then master)
    4. If none exist: skip staleness checks (no baseline)
- **Step 2**: List all main worktrees
  - Find directories: `ls -d .worktrees/main-* 2>/dev/null`
  - If none found: report "No active features" and exit
- **Step 3**: Process each worktree (from main repo)
  - Extract runId from directory name: `.worktrees/main-{runId}/` → `{runId}`
  - Check creation time: `stat -f %m .worktrees/main-{runId}/` (macOS) or `stat -c %Y` (Linux)
  - **Check if orphaned using full path from main repo**:
    - Run: `ls .worktrees/main-{runId}/specs/{runId}-*/spec.md 2>/dev/null`
    - If exits non-zero: worktree is orphaned
    - If exits 0: worktree is valid, extract feature slug from matched path
  - **If orphaned**:
    - Format: `{runId}: (orphaned) ({age}) - run /spectacular:cleanup {runId}`
    - Skip phase detection, skip staleness check
  - **If valid**:
    - Extract feature slug from spec path: `.worktrees/main-{runId}/specs/{runId}-{feature-slug}/` → `{feature-slug}`
    - Detect phase:
      - Check `ls .worktrees/main-{runId}/specs/{runId}-*/plan.md 2>/dev/null` (has plan?)
      - Check branches: `git branch | grep "^  {runId}-"` (count branches)
      - Phase: "spec only" | "spec+plan" | "executed (N branches)"
    - Calculate staleness (if default branch detected):
      - cd into `.worktrees/main-{runId}/`
      - Behind: `git log --oneline HEAD..origin/{default-branch} 2>/dev/null | wc -l`
      - Ahead: `git log --oneline origin/{default-branch}..HEAD 2>/dev/null | wc -l`
      - cd back to main repo
      - Show both if non-zero: "⚠️ 12 behind, 3 ahead" or just "⚠️ 12 behind"
    - Format: `{runId}: {feature-slug} ({age}) [{phase}] {staleness-warning}`
- **Step 4**: Output results
  - Sort by creation time (newest first)
  - Display formatted list

**Cleanup command (`/spectacular:cleanup {runId}`)**:

- ALL operations start from main repo (no cd until after orphaned check)
- **Step 1**: Verify worktree exists
  - From main repo: `git worktree list | grep ".worktrees/main-{runId}"`
  - If not found: error "Worktree .worktrees/main-{runId}/ not found"
- **Step 2**: Check if orphaned (from main repo using full path)
  - Run: `ls .worktrees/main-{runId}/specs/{runId}-*/spec.md 2>/dev/null`
  - If ls exits non-zero (file doesn't exist): worktree is orphaned
  - If ls exits 0 (file exists): worktree is valid
- **Step 3**: Branch based on orphaned check
  - If orphaned → skip to Step 5 (no cd, no state checks)
  - If valid → proceed to Step 4
- **Step 4**: Check worktree state (only for valid worktrees)
  - cd into `.worktrees/main-{runId}/`
  - Check uncommitted: `git status --porcelain`
  - List branches: `git branch | grep "^  {runId}-"`
  - For each branch: check push status
    - Check upstream: `git rev-parse @{u} 2>/dev/null`
    - If upstream exists: `git log @{u}.. --oneline` (shows unpushed commits)
    - If no upstream: mark as "never pushed"
- **Step 5**: Build summary
  - Worktree to delete: `.worktrees/main-{runId}/`
  - If orphaned:
    - Status: "Orphaned (no spec found)"
    - Branches: check from main repo after cd back: `git branch | grep "^  {runId}-"` (may be empty)
    - Uncommitted: "N/A (orphaned)"
  - If valid:
    - Uncommitted changes: "N files" or "none"
    - Unpushed branches: list with details from Step 4
  - All {runId}-\* branches remain accessible after cleanup
- **Step 6**: Present confirmation
  - AskUserQuestion with summary: "Delete worktree? (yes/no)"
  - Show what gets deleted (worktree) vs what remains (branches)
- **Step 7**: Execute cleanup (if confirmed)
  - If we cd'd in Step 4: cd back to main repo first
  - Try: `git worktree remove .worktrees/main-{runId}`
  - If fails (orphaned or corrupted): `rm -rf .worktrees/main-{runId}` then `git worktree prune`
- **Step 8**: Report status
  - From main repo: `git branch | grep "^  {runId}-"` (shows remaining branches)
  - Message: "Cleaned up worktree. Remaining branches: {count} ({runId}-\*)"

**Subagent prompts**:

- Spec generation subagent:
  - Receives working directory path (`.worktrees/main-{runId}/`)
  - Prompt pre-loads constitution context by reading constitution files
  - Uses stock `superpowers:brainstorming` skill (constitution-aware)
  - Uses `spectacular:writing-specs` skill to formalize spec
  - cd's to working directory first
- Sequential task subagents: Receive working directory path (`.worktrees/main-{runId}/`), cd's themselves
- Parallel task subagents: Receive child worktree path (`.worktrees/{runId}-task-X-Y/`), cd's themselves
- Setup/cleanup subagents: Receive working directory path (`.worktrees/main-{runId}/`), cd's themselves
- Note: Subagents do NOT inherit shell working directory - paths must be passed explicitly

### Workflow Changes

**Before:** All work in main repo (specs, plans, branches contaminate main workspace)

**After:** All work in `.worktrees/main-{runId}/` (main repo stays clean)

- Spec: Subagent works in worktree (avoids compaction)
- Plan/Execute: Orchestrator cd's to worktree, subagents receive paths explicitly
- Cleanup: Removes worktree, branches remain accessible

## Acceptance Criteria

**Constitution compliance:**

- [ ] All patterns followed (@docs/constitutions/current/patterns.md)
- [ ] Architecture boundaries respected (@docs/constitutions/current/architecture.md)
- [ ] Testing requirements met (@docs/constitutions/current/testing.md)

**Feature-specific:**

**Spec command worktree behavior:**

- [ ] `/spectacular:spec` generates feature slug from description (lowercase, hyphens, no special chars, 50 char max)
- [ ] Checks for uncommitted changes before worktree creation
- [ ] If dirty state: presents 4 options via AskUserQuestion (commit/stash/proceed/abort)
- [ ] Each option has clear consequence explanation
- [ ] Creates `.worktrees/main-{runId}/` using `managing-main-worktrees` skill
- [ ] Worktree created in detached HEAD state (intentional, allows independent branches)
- [ ] Orchestrator stays in main repo (does not cd to worktree)
- [ ] Orchestrator dispatches subagent for spec generation (avoids compaction)
- [ ] Subagent receives working directory path (`.worktrees/main-{runId}/`)
- [ ] Subagent prompt pre-loads constitution context (architecture, patterns, etc.)
- [ ] Subagent cd's to working directory before starting work
- [ ] Subagent uses stock `superpowers:brainstorming` skill (constitution-aware)
- [ ] Subagent uses `spectacular:writing-specs` skill to formalize spec
- [ ] AskUserQuestion prompts from subagent bubble up to user
- [ ] Spec file created at `.worktrees/main-{runId}/specs/{runId}-{feature-slug}/spec.md`
- [ ] Reports absolute path: `.worktrees/main-{runId}/specs/...`
- [ ] Main repo has no uncommitted spec files
- [ ] Orchestrator context does not compact during long brainstorming sessions

**Plan command worktree behavior:**

- [ ] `/spectacular:plan` extracts runId from spec path
- [ ] Uses `managing-main-worktrees` skill to check/create worktree
- [ ] Reuses existing `.worktrees/main-{runId}/` if available
- [ ] Orchestrator cd's to worktree (plan generation runs in orchestrator)
- [ ] Plan file created at `.worktrees/main-{runId}/specs/{runId}-{feature-slug}/plan.md`
- [ ] Reports absolute path: `.worktrees/main-{runId}/specs/...`
- [ ] Main repo has no uncommitted plan files

**Execute command worktree behavior:**

- [ ] `/spectacular:execute` extracts runId from plan path
- [ ] Uses `managing-main-worktrees` skill to check/create worktree
- [ ] Orchestrator cd's to worktree to run install and coordinate
- [ ] Detects and runs install command in worktree before first task (per FR11)
- [ ] Task subagents receive working directory paths explicitly
- [ ] Sequential task subagents: receive `.worktrees/main-{runId}/`, cd themselves
- [ ] Parallel task subagents: receive `.worktrees/{runId}-task-X-Y/`, cd themselves
- [ ] Execution happens entirely in worktrees (main + child)
- [ ] Main repo not modified during execution

**Sequential task isolation:**

- [ ] Sequential task subagents receive working directory path (`.worktrees/main-{runId}/`)
- [ ] Sequential task subagents cd to working directory
- [ ] Sequential tasks create branches in main worktree
- [ ] Branches stack linearly in main worktree
- [ ] Sequential tasks do not touch main repo

**Parallel task isolation:**

- [ ] Parallel setup subagent receives working directory path, cd's to create child worktrees
- [ ] Child worktrees created from main worktree (not main repo)
- [ ] Parallel task subagents receive child worktree paths (`.worktrees/{runId}-task-X-Y/`)
- [ ] Parallel task subagents cd to their assigned worktrees
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

- [ ] `/spectacular:list` runs from main repo (all checks use full paths)
- [ ] Runs `git worktree prune` first to cleanup stale refs
- [ ] Detects default branch reliably: origin/HEAD → init.defaultBranch → git rev-parse main/master → skip
- [ ] Shows all active features with runId, feature name, age
- [ ] Checks for orphaned from main repo: `ls .worktrees/main-{runId}/specs/{runId}-*/spec.md 2>/dev/null`
- [ ] If orphaned: shows `{runId}: (orphaned) ({age}) - run /spectacular:cleanup {runId}`
- [ ] If valid: extracts feature slug from spec path, shows phase and staleness
- [ ] Detects phase correctly: spec only | spec+plan | executed (N branches)
- [ ] Calculates staleness by cd'ing into worktree, checking commits, cd'ing back to main repo
- [ ] Shows both staleness metrics when non-zero: "⚠️ 12 behind, 3 ahead" or just "⚠️ 12 behind"
- [ ] Skips staleness check if no default branch detected
- [ ] Formats output consistently and sorts by creation time (newest first)
- [ ] Handles empty list gracefully: "No active features"

**Cleanup command:**

- [ ] `/spectacular:cleanup {runId}` runs from main repo (all checks use full paths)
- [ ] Step 1: Verifies worktree exists via `git worktree list`
- [ ] Step 2: Checks orphaned from main repo: `ls .worktrees/main-{runId}/specs/{runId}-*/spec.md 2>/dev/null`
- [ ] Step 3: Branches based on orphaned check result
- [ ] If orphaned: skips to Step 5 (no cd, no uncommitted/branch checks from worktree)
- [ ] If valid: proceeds to Step 4 (cd into worktree, check state)
- [ ] Step 4 (valid only): cd's into worktree, checks uncommitted, lists branches with push status
- [ ] For each branch: checks if upstream exists before `git log @{u}..`
- [ ] Shows "never pushed" for branches without upstream
- [ ] Step 5: Builds summary (different format for orphaned vs valid)
- [ ] If orphaned: shows "Orphaned (no spec found)", checks branches from main repo
- [ ] If valid: shows uncommitted count, unpushed branches list
- [ ] Step 6: Presents summary via AskUserQuestion with clear consequences
- [ ] Shows what will be deleted (worktree) vs what remains (branches)
- [ ] Step 7: Only removes worktree after user confirmation
- [ ] If cd'd in Step 4: cd's back to main repo before removal
- [ ] Tries `git worktree remove` first, falls back to `rm -rf` + `git worktree prune` if fails
- [ ] Step 8: Reports cleanup status with branches from main repo
- [ ] Works for exploratory specs (spec only, never executed)
- [ ] Works after full execution (spec → plan → execute)
- [ ] Works for orphaned worktrees (failed spec creation)
- [ ] Branches remain accessible in main repo after cleanup

**Worktree state management:**

- [ ] List command runs `git worktree prune` proactively (only command that does)
- [ ] `managing-main-worktrees` skill runs `git worktree prune` only as recovery if operations fail
- [ ] Commands verify worktree exists before creating
- [ ] Skill does not cd/pwd to verify worktree (commands cd after skill completes)
- [ ] Graceful error messages if worktree missing/corrupted
- [ ] `managing-main-worktrees` skill enforces consistent patterns

**Path resolution:**

- [ ] Commands accept paths in format: `@specs/{runId}-{feature-slug}/spec.md`
- [ ] Extract runId correctly using regex: `specs/([^-]+)-`
- [ ] If path doesn't match format: show error with expected format
- [ ] Commands report paths as absolute from main repo perspective
- [ ] User can copy-paste reported paths in IDE to view files

**Dependency management:**

- [ ] Execute command checks CLAUDE.md for install instructions first
- [ ] If not in CLAUDE.md: checks constitution (@docs/constitutions/current/tech-stack.md)
- [ ] If not specified: uses LLM inference on root directory files to detect ecosystem and install command
- [ ] LLM inference examines file patterns to identify language/ecosystem
- [ ] LLM inference selects appropriate install command for detected ecosystem
- [ ] LLM inference prioritizes faster package managers when multiple options exist
- [ ] Runs detected install command in worktree
- [ ] If no install procedure detected: skips with info message (not error)
- [ ] If install fails: fails entire execution with error
- [ ] Install runs before first task execution
- [ ] Language-agnostic: supports any ecosystem with standard package management
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
- [ ] Feature slug generation works correctly (lowercase, hyphens, no special chars, 50 char max)
- [ ] Spec → plan → execute workflow works end-to-end with isolation
- [ ] Main repo remains clean throughout entire lifecycle
- [ ] List command shows correct status for multiple features
- [ ] Cleanup workflow works correctly for all scenarios (normal and orphaned)
- [ ] Uncommitted changes handling works correctly (all 4 options + failures)
- [ ] Dependency detection works: CLAUDE.md → constitution → LLM inference → skip
- [ ] LLM inference correctly identifies ecosystems from file patterns
- [ ] LLM inference selects appropriate install commands for detected ecosystems
- [ ] Install detection supports any language with standard package management
- [ ] Default branch detection: origin/HEAD → init.defaultBranch → git rev-parse main/master → graceful skip
- [ ] Staleness calculation shows commits behind and ahead correctly
- [ ] Worktree created in detached HEAD state (allows independent branch creation)

## Open Questions

None - design validated during brainstorming.

## References

**Constitutions:**

- Architecture: @docs/constitutions/current/architecture.md
- Patterns: @docs/constitutions/current/patterns.md
- Tech Stack: @docs/constitutions/current/tech-stack.md
- Testing: @docs/constitutions/current/testing.md

**Skills:**

- Brainstorming: superpowers:brainstorming (stock - used with constitution pre-loading)
- Writing specs: @skills/writing-specs/SKILL.md (spectacular)
- Managing main worktrees: @skills/managing-main-worktrees/SKILL.md (new - spectacular)
- Using git worktrees: @skills/using-git-worktrees/SKILL.md (superpowers)
- Using git-spice: @skills/using-git-spice/SKILL.md (spectacular)
- Finishing a development branch: @skills/finishing-a-development-branch/SKILL.md (superpowers)
- Verification before completion: @skills/verification-before-completion/SKILL.md (superpowers)

**External Documentation:**

- Git worktree: https://git-scm.com/docs/git-worktree
- Git-spice: https://github.com/abhinav/git-spice
