# Worktree Isolation Design

**Date:** 2025-10-23
**Status:** Approved
**Author:** Claude Code (with drewritter)

## Problem Statement

The current `/spectacular:execute` workflow blocks the main repository during execution:

1. **Sequential tasks** run directly in main repo, checking out branches after each task
2. **Parallel task cleanup** checks out branches in main repo for restacking
3. **Integration tests** run on checked-out branches in main repo

This creates two critical problems:

- **Cannot run multiple spectacular features concurrently** - Different runIds would fight over branches in same repo
- **Cannot do manual work during execution** - User's main repo is occupied by spectacular's branch checkouts

## Solution: Main Worktree + Parallel Worktrees

### Core Architecture

**Every spectacular execution creates a "main worktree" that becomes the primary workspace for the entire feature.**

- **Path:** `.worktrees/{runId}-main`
- **Purpose:** Sequential task execution, branch restacking, integration tests, code review
- **Lifecycle:** Created at execution start, removed after entire feature complete (or left for manual cleanup)
- **Base branch:** Created from current branch in main repo (typically `main`)

**Parallel tasks get individual worktrees:**

- **Path:** `.worktrees/{runId}-task-{phase}-{task}`
- **Purpose:** Isolated execution for parallel tasks only
- **Lifecycle:** Created before parallel phase, removed after branches restacked

### Benefits

- ✅ Main repo completely untouched during execution
- ✅ Multiple spectacular runs execute concurrently (different runIds = different worktrees)
- ✅ User can work in main repo while spectacular runs in background
- ✅ Natural sequential workflow in main worktree
- ✅ True isolation for parallel tasks
- ✅ All git operations happen in worktrees, never main repo

## Orchestrator Location

**CRITICAL: The orchestrator stays in the main repo throughout execution and never changes directory** (per `orchestrating-isolated-subagents` skill).

- All subagents receive absolute paths to worktrees
- Subagents cd into worktrees as their first step
- This keeps orchestrator context clean and paths unambiguous
- Orchestrator uses `git -C` to query worktrees without changing directory

## Sequential Phase Workflow

### Setup (First Phase Only)

**Setup subagent** creates main worktree at execution start (per `managing-worktrees` skill, Pattern 1):

````
ROLE: Create main worktree for feature execution

TASK: Set up .worktrees/{runId}-main for {feature-name}

REPO_ROOT: /Users/drewritter/projects/spectacular
RUN_ID: {runId}

IMPLEMENTATION:

1. Verify in main repo:
```bash
pwd  # Should be /Users/drewritter/projects/spectacular
````

2. Check if worktree already exists (resume case):

```bash
if [ -d .worktrees/{runId}-main ]; then
  echo "Main worktree already exists, verifying state..."
  cd .worktrees/{runId}-main

  # Check for uncommitted changes
  if [ -n "$(git status --porcelain)" ]; then
    echo "ERROR: Main worktree has uncommitted changes"
    echo "Please commit or stash changes before resuming"
    exit 1
  fi

  # Check current branch
  CURRENT=$(git branch --show-current)
  echo "Main worktree exists on branch: $CURRENT"
  cd ../..
  exit 0
fi
```

3. Create main worktree:

```bash
CURRENT_BRANCH=$(git branch --show-current)
echo "Creating main worktree from branch: $CURRENT_BRANCH"

git worktree add ./.worktrees/{runId}-main $CURRENT_BRANCH
```

4. Verify creation:

```bash
git worktree list
cd .worktrees/{runId}-main
pwd
git branch --show-current
cd ../..
```

5. Report:
   - Main worktree path: ./.worktrees/{runId}-main
   - Base branch: {branch-name}
   - Status: Ready for task execution

```

### Task Execution

For each sequential task, spawn implementation subagent (per `orchestrating-isolated-subagents` skill):

```

ROLE: Implement Task {task-id}

TASK: {task-name}
WORKTREE_PATH: /Users/drewritter/projects/spectacular/.worktrees/{runId}-main
CURRENT_BRANCH: {current-branch-in-stack}

CRITICAL - DIRECTORY MANAGEMENT (per orchestrating-isolated-subagents skill):

1. You start in the main repo (orchestrator's working directory)
2. First step: cd into your worktree
3. All work happens in the worktree
4. Stay in worktree, do NOT cd back to main repo

SETUP:

```bash
# Verify starting location
pwd  # Will be in main repo

# Enter worktree
cd .worktrees/{runId}-main
pwd  # Should show: /path/to/repo/.worktrees/{runId}-main
git branch --show-current  # Should be {current-branch}
```

IMPLEMENTATION:

1. Read plan, implement task
2. Run quality checks (pnpm format, pnpm lint, pnpm test)
3. Stage changes (git add --all)
4. Create branch and commit (per `using-git-spice` skill):

   ```bash
   gs branch create {runId}-task-{phase}-{task}-{short-name} -m "[Task {task-id}] {task-name}

   {summary}

   Acceptance criteria met:
   - {criterion 1}
   - {criterion 2}

   🤖 Generated with Claude Code
   Co-Authored-By: Claude <noreply@anthropic.com>"
   ```

5. Verify branch created and checked out:

   ```bash
   git branch --show-current  # Should be new branch name
   gs log short  # Verify stack structure
   ```

6. Report completion:
   - Summary of changes
   - Files modified
   - Test results
   - Branch name created
   - Current location (still in worktree)

CRITICAL:

- ✅ cd into worktree as first step
- ✅ Stay in worktree throughout
- ✅ gs branch create automatically stacks and checks out new branch (per using-git-spice skill)
- ✅ Next task starts from this new branch
- ❌ DO NOT cd back to main repo
- ❌ NO need to detach HEAD (we continue working in this worktree)

````

### Code Review

After all tasks in phase complete:

```bash
cd .worktrees/{runId}-main
# Top of stack already checked out from last task

# Run integration tests
pnpm test
pnpm lint

# Dispatch code-reviewer subagent (works in main worktree)
````

### Changes from Current Workflow

**Only one change:** Add `cd .worktrees/{runId}-main` at the start of each task.

Everything else identical:

- git-spice stacking behavior
- Branch creation with `gs branch create`
- Sequential task flow
- Code review process

## Parallel Phase Workflow

### Setup (Parallel Phase Start)

**Setup subagent** creates worktrees for all parallel tasks (per `managing-worktrees` skill, Pattern 2):

````
ROLE: Create parallel worktrees for Phase {phase-id}

TASK: Set up worktrees for {task-count} parallel tasks

REPO_ROOT: /Users/drewritter/projects/spectacular
RUN_ID: {runId}
MAIN_WORKTREE: .worktrees/{runId}-main
PHASE_ID: {phase-id}

PARALLEL_TASKS:
- Task {task-id-1}: {task-name-1}
- Task {task-id-2}: {task-name-2}

IMPLEMENTATION:

1. Verify in main repo:
```bash
pwd  # Should be /Users/drewritter/projects/spectacular
````

2. Get base branch from main worktree (without changing directory):

```bash
CURRENT_BRANCH=$(git -C .worktrees/{runId}-main branch --show-current)
echo "Base branch for parallel tasks: $CURRENT_BRANCH"
```

3. Create parallel worktrees:

```bash
# All paths relative to main repo root
git worktree add --detach ./.worktrees/{runId}-task-{phase}-{task-1} $CURRENT_BRANCH
git worktree add --detach ./.worktrees/{runId}-task-{phase}-{task-2} $CURRENT_BRANCH
# etc for each parallel task
```

4. Verify worktrees created:

```bash
git worktree list
# Should show main repo, main worktree, and all task worktrees
```

5. Report:
   - Base branch: {branch-name}
   - Worktrees created:
     - ./.worktrees/{runId}-task-{phase}-{task-1}
     - ./.worktrees/{runId}-task-{phase}-{task-2}
   - Status: Ready for parallel execution

```

**Note:** Setup subagent works from main repo root. Uses `git -C` to query main worktree without changing directory.

### Parallel Task Execution

Spawn parallel implementation subagents (single message, multiple Task tools, per `orchestrating-isolated-subagents` skill):

```

ROLE: Implement Task {task-id}

TASK: {task-name}
WORKTREE_PATH: /Users/drewritter/projects/spectacular/.worktrees/{runId}-task-{phase}-{task}
BASE_BRANCH: {base-branch}

CRITICAL - DIRECTORY MANAGEMENT (per orchestrating-isolated-subagents skill):

1. You start in the main repo (orchestrator's working directory)
2. First step: cd into your task worktree
3. All work happens in the worktree
4. Stay in worktree, do NOT cd back to main repo
5. MUST detach HEAD after creating branch (enables cleanup in main repo, per managing-worktrees skill)

CRITICAL - WORKTREE ISOLATION:
You are working in an isolated git worktree. This means:

- You have your own working directory
- Other parallel tasks cannot interfere with your files
- Implement ONLY this task (files specified in plan)
- When done, report completion and do NOT clean up worktree (orchestrator handles cleanup)

SETUP:

```bash
# Verify starting location
pwd  # Will be in main repo

# Enter task worktree
cd .worktrees/{runId}-task-{phase}-{task}
pwd  # Should show: /path/to/repo/.worktrees/{runId}-task-{phase}-{task}
git status  # Should show detached HEAD at {base-branch}
```

IMPLEMENTATION:

1. Read plan, implement task
2. Run quality checks (pnpm format, pnpm lint, pnpm test)
3. Stage changes (git add --all)
4. Create branch and commit (per `using-git-spice` skill):

   ```bash
   gs branch create {runId}-task-{phase}-{task}-{short-name} -m "[Task {task-id}] {task-name}

   {summary}

   Acceptance criteria met:
   - {criterion 1}
   - {criterion 2}

   🤖 Generated with Claude Code
   Co-Authored-By: Claude <noreply@anthropic.com>"
   ```

5. **CRITICAL:** Detach HEAD to release branch:

   ```bash
   git switch --detach
   # This makes the branch accessible in main repo and main worktree
   ```

6. Verify branch released:

   ```bash
   git status  # Should show "HEAD detached at {commit-hash}"
   ```

7. Report completion:
   - Summary of changes
   - Files modified
   - Test results
   - Branch name created
   - Confirmation that HEAD is detached
   - Current location (still in task worktree)

CRITICAL:

- ✅ cd into task worktree as first step
- ✅ Stay in worktree throughout
- ✅ Implement ONLY this task's files
- ✅ Run ALL quality checks
- ✅ Use gs branch create with -m flag (per using-git-spice skill)
- ✅ MUST detach HEAD after creating branch
- ❌ DO NOT cd back to main repo
- ❌ DO NOT clean up worktree (orchestrator does this)
- ❌ DO NOT touch other task files

```

### Cleanup and Restacking

After all parallel tasks complete, **cleanup subagent** removes worktrees and restacks branches (per `managing-worktrees` skill Pattern 3, and `using-git-spice` skill for restacking):

```

ROLE: Cleanup parallel worktrees and restack branches

TASK: Clean up Phase {phase-id} worktrees and create linear stack

REPO_ROOT: /Users/drewritter/projects/spectacular
MAIN_WORKTREE: .worktrees/{runId}-main

COMPLETED_TASKS:

- {runId}-task-{phase}-{task-1}-{short-name} (worktree: .worktrees/{runId}-task-{phase}-{task-1})
- {runId}-task-{phase}-{task-2}-{short-name} (worktree: .worktrees/{runId}-task-{phase}-{task-2})

CRITICAL - TODWRITE REQUIRED (per managing-worktrees skill):
Before starting cleanup, create this checklist:

```markdown
Parallel worktree cleanup checklist:

- [ ] Verify in main repo: pwd shows /path/to/repo
- [ ] Verify branches exist: git branch -v | grep "{runId}-task-{phase}"
- [ ] Verify ALL worktrees have detached HEAD: git worktree list
- [ ] Remove each parallel worktree from main repo
- [ ] Verify worktrees removed: git worktree list shows only main repo + main worktree
- [ ] Verify branches still accessible: git branch -v | grep "{runId}-task-{phase}"
```

**Why required:** Under time pressure (manager waiting, demo deadline), skipping verification steps causes 15-30 min recovery. TodoWrite forces explicit tracking and prevents shortcuts.

IMPLEMENTATION:

1. Verify in main repo:

```bash
pwd  # Should be /Users/drewritter/projects/spectacular
```

2. Verify all parallel branches exist:

```bash
git branch -v | grep "{runId}-task-{phase}"
# Expected: All task branches listed with commit info
```

3. Verify all worktrees have detached HEAD:

```bash
git worktree list
# All parallel task worktrees should show "(detached HEAD)" not a branch name
# If any show a branch name, that task failed to detach HEAD
```

4. Remove parallel worktrees:

```bash
# Remove from main repo (branches are safe in .git)
git worktree remove ./.worktrees/{runId}-task-{phase}-{task-1}
git worktree remove ./.worktrees/{runId}-task-{phase}-{task-2}
# etc for all parallel task worktrees
```

5. Verify worktrees removed but branches still exist:

```bash
git worktree list  # Should only show main repo and main worktree
git branch -v | grep "{runId}-task-{phase}"  # Branches still exist
```

6. Enter main worktree for restacking:

```bash
cd .worktrees/{runId}-main
pwd  # Confirm in main worktree
```

7. Restack parallel branches linearly (per `using-git-spice` skill):

```bash
# Stack in task number order (1.1 -> 1.2 -> 1.3, etc.)
# First task stays on base, subsequent tasks stack on previous

git checkout {runId}-task-{phase}-{task-2}-{short-name}
gs upstack onto {runId}-task-{phase}-{task-1}-{short-name}

# For 3+ parallel tasks, continue stacking:
# git checkout {runId}-task-{phase}-{task-3}-{short-name}
# gs upstack onto {runId}-task-{phase}-{task-2}-{short-name}
```

8. Verify stack structure:

```bash
gs log short
# Expected: Linear stack in task number order
```

9. Run integration tests on top of stack:

```bash
# Should be on last task branch from restacking
git branch --show-current

pnpm test
pnpm lint
```

10. Report:

- Worktrees cleaned up: {count}
- Branches restacked: {list}
- Stack structure: {tree from gs log short}
- Integration test results: {pass/fail}
- Current branch: {branch-name}
- Current location: Main worktree

CRITICAL:

- ✅ Start in main repo
- ✅ Remove worktrees from main repo (not from within worktrees)
- ✅ cd into main worktree for restacking operations
- ✅ Use gs upstack onto for restacking (per using-git-spice skill)
- ✅ Stack in task number order (creates logical dependency chain)
- ✅ Run integration tests in main worktree
- ❌ DO NOT manually rebase with git rebase

```

### Integration Test Failure Handling

If integration tests fail after restacking:

```

STOP EXECUTION - DO NOT PROCEED

If tests fail, this indicates an integration issue between parallel tasks.

OPTIONS:

1. Manual debugging in main worktree:

   - User can cd .worktrees/{runId}-main
   - Debug and fix issues
   - Commit fixes to current branch
   - Resume execution

2. Spawn fix agent in new worktree:

   - Create .worktrees/{runId}-fix-integration
   - Spawn subagent to implement fixes
   - Create new branch with fixes
   - Stack on top of failed branch
   - Rerun integration tests

3. Roll back parallel phase:
   - Reset to base branch before parallel tasks
   - Fix task independence issues in plan
   - Re-execute parallel phase

DO NOT:

- ❌ Proceed to code review with failing tests
- ❌ Skip integration testing
- ❌ Commit untested changes

````

### Code Review

After integration tests pass, code review runs in main worktree (top of stack already checked out from restacking).

## Cleanup and Lifecycle

### Final Cleanup (After Entire Feature Complete)

After all phases execute, tests pass, and code review succeeds:

**Option 1: Automatic cleanup**
```bash
# Remove main worktree
git worktree remove ./.worktrees/{runId}-main

# Prune any stale entries
git worktree prune
````

**Option 2: Manual cleanup (recommended)**

- Leave worktrees in place after execution
- User can inspect `.worktrees/{runId}-main` for debugging
- User manually cleans up when ready: `git worktree remove ./.worktrees/{runId}-*`
- Worktrees don't interfere with anything

### Manual Cleanup Command

Add `/spectacular:cleanup {runId}` command for manual worktree cleanup (per `managing-worktrees` skill, Pattern 4):

````
TASK: Clean up all worktrees for {runId}

IMPLEMENTATION:

1. List worktrees for this run:
```bash
git worktree list | grep "{runId}"
````

2. Remove all worktrees:

```bash
git worktree remove ./.worktrees/{runId}-main
git worktree remove ./.worktrees/{runId}-task-*  # Any parallel task worktrees
```

3. Verify cleanup:

```bash
git worktree list  # Should not show any {runId} worktrees
ls -la .worktrees/  # Verify directories removed
```

4. Prune stale entries:

```bash
git worktree prune
```

**Note:** Branches are NOT removed (they're in .git). Only worktree directories are cleaned up.

````

### Resume Behavior

If execution interrupted and restarted:

1. Check for existing `.worktrees/{runId}-main`
2. If exists:
   - Verify state (no uncommitted changes, valid branch)
   - Reuse it (preserves partial work)
   - Resume from incomplete tasks
3. If not exists:
   - Create fresh main worktree
   - Start from beginning

**Resume validation** (performed by setup subagent):
```bash
if [ -d .worktrees/{runId}-main ]; then
  cd .worktrees/{runId}-main

  # Check for uncommitted changes
  if [ -n "$(git status --porcelain)" ]; then
    echo "ERROR: Main worktree has uncommitted changes"
    exit 1
  fi

  # Check valid branch
  CURRENT=$(git branch --show-current)
  if [ -z "$CURRENT" ]; then
    echo "ERROR: Main worktree in detached HEAD state"
    exit 1
  fi

  cd ../..
fi
````

## Error Handling

### Sequential Task Fails

**Scenario:** Task implementation subagent fails during sequential phase.

**State:** Main worktree preserved with partial work.

**Recovery options:**

1. **Manual fix in worktree:**

   ```bash
   cd .worktrees/{runId}-main
   # Fix issues
   git add .
   gs branch create {runId}-task-{phase}-{task}-{name} -m "..."
   # Resume execution
   ```

2. **Spawn new agent to fix:**

   - Orchestrator spawns fix subagent in same main worktree
   - Fix subagent starts from current branch
   - Creates fixed version on new branch
   - Execution continues

3. **Skip task and continue:**
   - Document task as incomplete
   - Continue to next task (if dependencies allow)
   - Address failed task later

**Resume:** Next execution reuses `.worktrees/{runId}-main` and continues from incomplete task.

### Parallel Task Fails

**Scenario:** One or more parallel task subagents fail during parallel phase.

**State:**

- Successful tasks: Branches created, worktrees have detached HEAD
- Failed tasks: Worktrees preserved, may have uncommitted changes or no branch

**Recovery options:**

1. **Manual fix per failed task:**

   ```bash
   cd .worktrees/{runId}-task-{phase}-{failed-task}
   # Fix issues
   git add .
   gs branch create {runId}-task-{phase}-{failed-task}-{name} -m "..."
   git switch --detach  # CRITICAL: Release branch
   cd ../..
   # Resume execution (cleanup subagent will handle this worktree)
   ```

2. **Remove failed worktree, restart task:**

   ```bash
   # From main repo
   git worktree remove --force ./.worktrees/{runId}-task-{phase}-{failed-task}
   # Spawn new subagent for just this task
   # New worktree created for retry
   ```

3. **Skip failed tasks:**
   - Cleanup subagent proceeds with successful tasks only
   - Failed worktrees left in place for debugging
   - Document incomplete tasks
   - User can fix and integrate later

**Resume:** Next execution detects completed branches vs incomplete tasks, only retries incomplete.

### Concurrent Spectacular Runs

**Isolation:**

- Each run has unique runId → unique worktree directories
- Example: `.worktrees/abc123-main` and `.worktrees/xyz789-main` don't conflict
- Branches namespaced: `abc123-task-1-1-schema` vs `xyz789-task-1-1-auth`
- No file system conflicts between concurrent runs

**Git-spice considerations:**

- `gs` tracks branches globally (stored in `.git/config` and `.git/spice/`)
- Multiple concurrent runs create branches in same git database
- **Safe:** Branch creation, stacking, log viewing (read operations)
- **Safe:** Operations scoped to specific branches (`gs upstack onto`, `gs branch create`)
- **Test carefully:** Global repo operations during concurrent runs
  - `gs repo restack` - May restack branches from other runs
  - `gs repo sync` - May affect all tracked branches
  - `gs stack submit` - Only affects current stack (safe if on correct branch)

**Best practices for concurrent runs:**

1. Each run works in its own worktrees (isolated working trees)
2. Each run uses branch namespacing (runId prefix)
3. Avoid global git-spice commands (`gs repo restack`, `gs repo sync`) during concurrent execution
4. Use scoped commands (`gs upstack onto`, `gs branch create`, `gs log short`)
5. Final `gs stack submit` is safe (operates on current branch's stack only)

**Testing requirement:** Validate concurrent execution with two features running simultaneously.

### Manual Work in Main Repo

- Main repo completely untouched during spectacular execution
- User can switch branches, make commits, run commands freely
- Worktrees are isolated directories, don't affect main repo working tree
- Only shared state: `.git` directory (safe, git handles concurrent access)

### Worktree Cleanup Failures

If worktree removal fails:

```bash
# Check what's blocking
git worktree list

# Force remove if needed
git worktree remove --force ./.worktrees/{runId}-main

# Prune stale entries
git worktree prune
```

User can always manually clean up worktrees without affecting branches (branches are in `.git`, not worktrees).

## Implementation Impact

### Files to Modify

**commands/execute.md**

Changes needed:

1. **Step 0c (new):** Add "Create Main Worktree" step after "Check for Existing Work"

   - Delegate to setup subagent to create `.worktrees/{runId}-main`
   - Check if already exists (resume case)

2. **Step 2 - Sequential Phase:**

   - Update implementation subagent prompt to include `WORKTREE` path
   - Add `cd .worktrees/{runId}-main` to SETUP section
   - Remove any references to "current working directory" (always in main worktree)

3. **Step 2 - Parallel Phase:**

   - Update setup subagent to create worktrees from `.worktrees/{runId}-main` (not main repo)
   - Update implementation subagent prompts with task worktree paths
   - Update cleanup subagent to work in `.worktrees/{runId}-main` for restacking

4. **Step 3 - Verify Completion:**

   - Run verification in `.worktrees/{runId}-main`

5. **Step 4 - Finish Stack:**

   - Run `gs stack submit` from `.worktrees/{runId}-main`

6. **Step 5 - Final Report:**

   - Add worktree cleanup instructions
   - Document concurrent run support

7. **Error Handling:**
   - Add worktree-specific error scenarios
   - Update resume logic for existing worktrees

### No Changes Needed

- Plan structure (phases, tasks, dependencies)
- Task decomposition logic
- Git-spice stacking behavior
- Code review process
- Constitution adherence

### Testing Plan

**Basic workflows:**

1. **Sequential-only feature:** Verify all tasks execute in main worktree
2. **Parallel-only feature:** Verify parallel worktrees created, restacked in main worktree
3. **Mixed feature:** Sequential → parallel → sequential phases

**Advanced scenarios:** 4. **Concurrent runs:** Start two spectacular executions simultaneously

- Verify worktree isolation (different runIds)
- Verify branch namespacing prevents conflicts
- Check git-spice operations don't interfere
- Validate both runs can complete successfully

5. **Manual work during execution:** User switches branches in main repo while spectacular runs

   - Execute spectacular in background
   - User checks out different branch in main repo
   - User makes commits in main repo
   - Verify spectacular execution unaffected

6. **Resume after failure:**

   - Kill execution mid-sequential-phase
   - Restart, verify resumes in same main worktree
   - Kill execution mid-parallel-phase
   - Restart, verify skips completed parallel tasks

7. **Integration test failures:**
   - Introduce intentional bug in parallel task
   - Verify integration tests catch it
   - Test fix options (manual, new agent, rollback)

**Error scenarios:** 8. **Task failure recovery:**

- Sequential task fails, manual fix, resume
- Parallel task fails, restart just that task
- Multiple parallel tasks fail

9. **Worktree conflicts:**

   - Main worktree exists with dirty state
   - Parallel worktree exists from previous failed run
   - Manual cleanup and retry

10. **Git-spice edge cases:**
    - Verify gs commands scoped to correct branches
    - Test stack submission doesn't affect other runs
    - Validate branch tracking across worktrees

## Migration Notes

### Backward Compatibility

- Old plans (without runId) still work - generate runId on the fly
- Existing branches not affected - this changes where NEW branches are created
- No changes to git-spice commands or stacking logic

### User Communication

After implementation, document in README:

- Worktrees created in `.worktrees/{runId}-*`
- Main repo never touched during execution
- Can run multiple features concurrently
- Manual cleanup: `git worktree remove ./.worktrees/{runId}-*`
- Add `.worktrees/` to `.gitignore` if not already present

### Rollback Plan

If issues discovered:

1. Revert `commands/execute.md` changes
2. Old workflow (direct main repo) still works
3. Clean up any existing worktrees manually

## Alternatives Considered

### Alternative 1: One Worktree Per Task

**Approach:** Every task (sequential and parallel) gets its own worktree.

**Rejected because:**

- 10+ worktrees for large features (excessive)
- Sequential tasks would need complex handoff between worktrees
- No natural "main workspace" for integration tests
- Harder to reason about workflow

### Alternative 2: One Worktree Per Phase

**Approach:** Each phase gets a worktree, sequential phases reuse, parallel tasks get individual worktrees.

**Rejected because:**

- Different logic for sequential vs parallel (confusing)
- Phase boundaries arbitrary (why separate worktrees?)
- Still need main worktree for final integration tests
- Added complexity for minimal benefit

### Selected: Main + Parallel Worktrees

**Why chosen:**

- Single persistent worktree feels natural for sequential work
- Minimal worktrees (1 + N parallel tasks currently executing)
- Clear mental model: "main workspace + temporary parallel isolation"
- Easy to explain and reason about
- Maps well to actual workflow (most work sequential, occasional parallel burst)

## Design Review and Improvements

This design was reviewed against the following criteria:

### ✅ Skills Created and Tested for Enforcement

Two new skills created and tested using `testing-skills-with-subagents` skill:

**1. `skills/managing-worktrees/SKILL.md`**

- **Purpose:** Worktree lifecycle for spectacular execution
- **Enforces:**
  - State validation (dirty check, detached HEAD)
  - Cleanup verification rules
  - Resume safety patterns
  - TodoWrite checklist requirement for Pattern 3 (cleanup)
- \*\*Why needeorchestrating-isolated-subagentsy-to-skip verifications under time pressure
- **Testing results:** Bulletproof after 1 iteration
  - 3 pressure scenarios tested (time + authority + consequences)
  - Initial: Would violate 2/3 scenarios under pressure
  - Added: Time-cost context, cost-benefit tables, TodoWrite requirement
  - Final: 100% compliance under maximum pressure
- **Key improvements:**
  - Rationalization table shows "Check: 30s / Silent failure: 30-60min"
  - Cost-benefit table: "Verification is ALWAYS cheaper than debugging"
  - TodoWrite checklist prevents shortcuts when manager is waiting
    orchestrating-isolated-subagents
    **2. `skills/orchestrator-subagent-isolation/SKILL.md`**
- **Purpose:** Directory isolation between orchestrator and subagents
- **Enforces:**
  - Orchestrator never changes directory
  - Subagent verification steps (pwd before/after cd)
  - Absolute path enforcement
- **Why needed:** Prevents path confusion bugs in distributed execution
- **Reusable:** General pattern applicable beyond spectacular (could contribute to superpowers)
- **Testing results:** Bulletproof on first iteration
  - 3 pressure scenarios tested
  - 100% compliance - no violations
  - Already had explicit CRITICAL markers, rationalization table, common mistakes, quality rules
  - No changes needed

**Testing methodology (per `testing-skills-with-subagents`):**

1. **RED:** Ran pressure scenarios, documented exact rationalizations
2. **GREEN:** Skills addressed specific failures
3. **REFACTOR:** Added time-cost context and TodoWrite enforcement to managing-worktrees
4. **VERIFY:** Re-tested, both skills now bulletproof

**References added throughout design:**

- "per `managing-worktrees` skill" for worktree operations
- "per `orchestrator-subagent-isolation` skill" for directory management
- "per `using-git-spice` skill" for git-spice operations

### ✅ Git-spice Skill Alignment

**Verification:** All git-spice operations reference the `using-git-spice` skill.

**Key operations:**

- `gs branch create -m` for branch creation and commits (line 151)
- `gs upstack onto` for restacking parallel branches (line 410)
- `gs log short` for verifying stack structure (line 168, 425)
- Never use `git rebase` directly (enforced in skill)

**References added:** "per `using-git-spice` skill" callouts throughout workflow sections.

### ✅ Worktree Path Handling

**Fixed:** Confusing relative paths in parallel phase setup/cleanup.

**Solution:**

- Setup subagent works from main repo root
- Uses `git -C .worktrees/{runId}-main` to query main worktree without cd
- Creates all parallel worktrees with absolute paths: `./.worktrees/{runId}-task-*`
- Cleanup subagent works from main repo, cd into main worktree only for restacking

**Benefit:** No more `../` relative paths that depend on current directory.

### ✅ Orchestrator Location

**Clarified:** Added explicit section documenting orchestrator behavior (line 46).

**Key principle:** Orchestrator stays in main repo throughout, never changes directory.

**Implementation:**

- All subagents receive absolute paths
- Subagents cd into worktrees as first step
- Keeps orchestrator context clean and paths unambiguous

### ✅ Subagent Directory Management

**Standardized:** All subagents follow same pattern.

**Pattern:**

1. Verify starting in main repo: `pwd`
2. Enter worktree: `cd .worktrees/{path}`
3. Do all work in worktree
4. Report from worktree (don't cd back)

**Benefits:** Consistent mental model, clear error messages, easier debugging.

### ✅ Resume Logic with State Validation

**Enhanced:** Added dirty state checks and validation (line 563).

**Validation steps:**

1. Check if worktree exists
2. Verify no uncommitted changes: `git status --porcelain`
3. Verify valid branch (not detached HEAD)
4. Only reuse if all checks pass

**Benefit:** Prevents resuming into broken state.

### ✅ Error Recovery Documentation

**Expanded:** Detailed recovery steps for all failure scenarios (line 585).

**Scenarios covered:**

- Sequential task failure (3 recovery options)
- Parallel task failure (3 recovery options)
- Integration test failure (3 recovery options with fix agent pattern)
- Worktree conflicts
- Git-spice edge cases

**Benefit:** Clear guidance for manual intervention when needed.

### ✅ Manual Cleanup Command

**Added:** `/spectacular:cleanup {runId}` command specification (line 516).

**Purpose:** Allow users to clean up abandoned runs without manual git commands.

**Scope:** Removes worktrees only, preserves branches.

### ✅ Concurrent Run Safety

**Documented:** Git-spice considerations for concurrent execution (line 662).

**Key findings:**

- Worktree isolation: ✅ Safe (different directories)
- Branch namespacing: ✅ Safe (runId prefix)
- Scoped gs commands: ✅ Safe (`gs upstack onto`, `gs branch create`)
- Global gs commands: ⚠️ Test carefully (`gs repo restack`, `gs repo sync`)

**Best practice:** Avoid global git-spice operations during concurrent runs.

### ✅ Integration Test Failure Handling

**Added:** Explicit handling when tests fail after parallel restacking (line 456).

**Options:**

1. Manual debugging in main worktree
2. Spawn fix agent in new worktree (per user requirement)
3. Rolorchestrating-isolated-subagents

**Enforced:** STOP execution if tests fail, don't proceed to code review.

### ✅ Testing Plan

**Enhanced:** Comprehensive test scenarios including concurrent runs (line 749).

**Coverage:** 10 test scenarios across basic workflows, advanced scenarios, and error cases.

**Critical tests:**

- Concurrent execution (validates no interference)
- Manual work during execution (validates isolation)
- Integration test failure handling (validates fix workflow)

## Open Questions

None - design reviewed, improved, and approved for implementation.

## Next Steps

1. ✅ **COMPLETED:** Test new skills with `testing-skills-with-subagents`
   - ✅ `managing-worktrees`: Tested with 3 pressure scenarios, bulletproof after 1 iteration
   - ✅ `orchestrator-subagent-isolation`: Tested with 3 pressure scenarios, bulletproof on first iteration
   - ✅ Improvements: Added time-cost context, cost-benefit tables, TodoWrite requirement

2. **Update `commands/execute.md` per implementation impact section:**
   - Add skill references throughout
   - Update all subagent prompts to follow new patterns
   - Add Step 0c for main worktree creation (per `managing-worktrees` Pattern 1)
   - Add TodoWrite checklist requirement for parallel cleanup (per `managing-worktrees` Pattern 3)
   - Ensure orchestrator uses `git -C` per `orchestrator-subagent-isolation` skill
   - Ensure all paths are absolute per `orchestrator-subagent-isolation` skill

3. **Create `/spectacular:cleanup` command:**
   - Use `managing-worktrees` Pattern 4
   - Accept runId parameter
   - Remove all worktrees for that run
   - Include TodoWrite checklist for verification steps

4. **Test implementation:**
   - Sequential-only feature
   - Parallel-only feature
   - Mixed feature (sequential → parallel → sequential)
   - Concurrent runs (validate git-spice isolation)
   - Manual work during execution (validate main repo untouched)
   - Resume after failure (validate dirty state detection)
   - Integration test failures (validate fix agent spawn)
   - **Pressure testing:** Simulate time pressure to verify TodoWrite enforcement

5. **Update README with worktree documentation:**
   - Explain `.worktrees/{runId}-*` structure
   - Document manual cleanup: `git worktree remove ./.worktrees/{runId}-*`
   - Add `.worktrees/` to recommended `.gitignore`
   - Document TodoWrite checklist requirement for cleanup operations
   - Explain cost-benefit of verification (30s check vs 30min debugging)
