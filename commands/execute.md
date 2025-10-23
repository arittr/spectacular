---
description: Execute implementation plan with automatic sequential/parallel orchestration using git-spice and worktrees
---

You are executing an implementation plan.

## Required Skills

Before starting, you MUST read these skills:
- `managing-worktrees` - For worktree lifecycle management (spectacular skill)
- `orchestrating-isolated-subagents` - For directory isolation patterns (spectacular skill)
- `using-git-spice` - For managing stacked branches (spectacular skill)
- `requesting-code-review` - For phase review gates (superpowers skill)
- `verification-before-completion` - For final verification (superpowers skill)
- `finishing-a-development-branch` - For completion workflow (superpowers skill)

## Input

User will provide: `/spectacular:execute {plan-path}`

Example: `/spectacular:execute @specs/a1b2c3-magic-link-auth/plan.md`

Where `a1b2c3` is the runId and `magic-link-auth` is the feature slug.

## Workflow

### Step 0a: Extract Run ID and Commit Spec Directory

**First action**: Read the plan and extract the RUN_ID from frontmatter.

```bash
# Extract runId from plan frontmatter
RUN_ID=$(grep "^runId:" {plan-path} | awk '{print $2}')
echo "RUN_ID: $RUN_ID"

# Get spec directory (e.g., specs/a1b2c3-magic-link-auth/)
SPEC_DIR=$(dirname {plan-path})
echo "SPEC_DIR: $SPEC_DIR"
```

**If RUN_ID not found:**
Generate one now (for backwards compatibility with old plans):
```bash
RUN_ID=$(echo "{feature-name}-$(date +%s)" | shasum -a 256 | head -c 6)
echo "Generated RUN_ID: $RUN_ID (plan missing runId)"
```

**Announce:** "Executing with RUN_ID: {run-id}"

**CRITICAL - Commit Spec Directory First:**

Before any implementation work, the spec directory must be committed to `{run-id}-main` branch. This creates the anchor point for all task branches.

```bash
# Check if {run-id}-main branch already exists
if git show-ref --verify --quiet refs/heads/{run-id}-main; then
  echo "Branch {run-id}-main already exists - spec already committed"
else
  echo "Creating {run-id}-main branch with spec and plan"

  # Stage entire spec directory
  git add $SPEC_DIR

  # Create branch and commit using gs branch create
  gs branch create {run-id}-main -m "Spec + Plan: {feature-name}

Specification and execution plan for this feature.

Files:
- $SPEC_DIR/spec.md
- $SPEC_DIR/plan.md

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>"

  # Verify commit
  git log -1 --oneline
  git show --stat
fi
```

**This creates:**
- Branch: `{run-id}-main`
- Commit: Contains spec.md + plan.md
- Base: All task branches will stack on this

**Why this matters:**
- Every task commit has spec/plan in shared git history
- Spec-code traceability preserved in git graph
- All implementation work references the spec anchor

**Store RUN_ID for use in:**
- Base branch: `{run-id}-main`
- Task branches: `{run-id}-task-X-Y-name`
- Filtering: `git branch | grep ^{run-id}-`
- Cleanup: Identify which branches belong to this run
- Worktree naming: `.worktrees/{run-id}-main` and `.worktrees/{run-id}-task-{phase}-{task}`

### Step 0b: Check for Existing Work

Before starting or resuming, delegate git state check to a subagent:

```
ROLE: Check for existing implementation work

TASK: Determine if work has already started and identify resume point

IMPLEMENTATION:

1. Check current state:
```bash
git branch --show-current
git log --oneline --grep="\[Task" -20
gs ls
gs branch tree
git status

# Filter branches for this RUN_ID
git branch | grep "^  {run-id}-task-"
```

2. Analyze results:
   - Look for commits with `[Task X.Y]` pattern in git log
   - Check for task branches matching `{run-id}-task-` pattern
   - Match branch names to plan tasks
   - Determine which phase and task to resume from

3. Report:
   - Current branch name
   - List of completed tasks (from commit messages)
   - List of existing task branches
   - Resume point (next incomplete task)
   - Whether working directory is clean
   - Recommendation: resume or start fresh
```

**Based on subagent report:**

**If work already exists:**
- Orchestrator uses the resume point to skip to Step 2 at the appropriate task
- Sequential phases: Resume from next incomplete task in current phase
- Parallel phases: Resume incomplete tasks only

**If no existing work:**
- Continue to Step 0c (Create Main Worktree)

### Step 0c: Create Main Worktree

**Announce:** "Using `managing-worktrees` skill to create isolated worktree for execution"

**Delegate main worktree creation to setup subagent:**

```
ROLE: Setup main worktree for spectacular execution

TASK: Create and validate main worktree for RUN_ID {run-id}

CRITICAL - SKILL REFERENCE:
Use the `managing-worktrees` skill Pattern 1 for all worktree operations.

IMPLEMENTATION:

1. Check if main worktree already exists:
```bash
git worktree list | grep "{run-id}-main"
```

2. If worktree exists, validate its state:
```bash
cd .worktrees/{run-id}-main
git status
# Check for dirty state, detached HEAD, uncommitted changes
```

**If clean:** Report worktree ready for resume
**If dirty:** Error - cannot resume with dirty worktree (user must clean manually)

3. If worktree does NOT exist, create it:
```bash
# Create main worktree from {run-id}-main branch (created in Step 0a)
echo "Creating worktree from branch: {run-id}-main"

# Create main worktree for this run
git worktree add .worktrees/{run-id}-main {run-id}-main

# Verify creation
git worktree list | grep "{run-id}-main"
ls -la .worktrees/{run-id}-main
```

4. Change into worktree and verify:
```bash
cd .worktrees/{run-id}-main
pwd  # Should show .worktrees/{run-id}-main path
git branch --show-current  # Should show {run-id}-main
git status  # Should be clean
```

5. Report completion:
   - Worktree path: `.worktrees/{run-id}-main`
   - Base branch: `{run-id}-main`
   - Status: new or resumed
   - Working directory is clean
   - Spec/plan committed and accessible

CRITICAL:
- ✅ Use `managing-worktrees` skill Pattern 1
- ✅ Validate clean state before resuming
- ✅ Error on dirty state (don't auto-clean)
- ✅ Verify worktree accessible after creation
- ✅ Stay in worktree directory after setup
```

**Store worktree path for sequential task execution:**
```javascript
mainWorktreePath = '.worktrees/{run-id}-main'
```

**If setup fails:** Abort execution, report error to user

### Step 1: Read and Parse Plan

Read the plan file and extract:
- Feature name
- All phases (with strategy: sequential or parallel)
- All tasks within each phase
- Task details (files, dependencies, acceptance criteria)

Verify plan structure:
- ✅ Has phases with clear strategies
- ✅ All tasks have files specified
- ✅ All tasks have acceptance criteria
- ✅ Dependencies make sense

### Step 2: Execute Phases

**If resuming:** Start from the incomplete phase/task identified in Step 0.

For each phase in the plan, execute based on strategy:

#### Sequential Phase Strategy

For phases where tasks must run in order:

**Announce:** "Using `orchestrating-isolated-subagents` skill for sequential task execution"

**Execute tasks sequentially with stacked branches in main worktree:**

1. For each task in the phase:

   **Spawn subagent for task implementation** (use Task tool):

   ```
   ROLE: You are implementing Task {task-id}.

   TASK: {task-name}
   WORKTREE_PATH: {mainWorktreePath}  # e.g., .worktrees/{run-id}-main
   CURRENT BRANCH: {current-branch}

   CRITICAL - WORKTREE ISOLATION:
   Use the `orchestrating-isolated-subagents` skill Pattern 2 for directory management.
   You are working in an isolated worktree. The orchestrator stays in main repo.

   CRITICAL - CONTEXT MANAGEMENT:
   You are a subagent with isolated context. Complete this task independently.

   IMPLEMENTATION:

   1. Verify WORKTREE_PATH parameter received:
   ```bash
   echo "WORKTREE_PATH: {mainWorktreePath}"
   ```

   2. Change into worktree directory:
   ```bash
   cd {mainWorktreePath}
   pwd  # Verify you're in worktree
   ```

   3. Verify you're on the correct branch:
   ```bash
   git branch --show-current  # Should be {current-branch}
   ```

   4. Read task details from: {plan-path}
      Find: "Task {task-id}: {task-name}"

   5. Implement according to:
      - Files specified in task
      - Acceptance criteria in task
      - Project constitution (see @docs/constitutions/current/)

   6. Quality checks (MUST run all):
   ```bash
   pnpm format
   pnpm lint
   ```

   7. Stage changes:
   ```bash
   git add --all
   git status  # Verify changes staged
   ```

   8. Create branch and commit with gs branch create:
   ```bash
   gs branch create {run-id}-task-{task-id}-{short-name} -m "[Task {task-id}] {task-name}

   {Brief summary of changes}

   Acceptance criteria met:
   - {criterion 1}
   - {criterion 2}

   🤖 Generated with [Claude Code](https://claude.com/claude-code)

   Co-Authored-By: Claude <noreply@anthropic.com>"
   ```

   This will:
   - Create a new branch `{run-id}-task-{task-id}-{short-name}`
   - Commit all staged changes
   - Stack the branch on current branch automatically

   9. Report completion with:
      - Summary of changes
      - Files modified
      - Test results
      - Branch name created
      - Commit hash
      - Confirmation of working in correct worktree
      - Any issues encountered

   CRITICAL:
   - ✅ Verify WORKTREE_PATH parameter first
   - ✅ cd into worktree before any work
   - ✅ Stay in worktree directory throughout
   - ✅ Run ALL quality checks
   - ✅ Stage changes with git add
   - ✅ Use gs branch create with -m flag to commit
   - ✅ Use `orchestrating-isolated-subagents` skill Pattern 2
   - ✅ Follow mandatory patterns
   ```

2. After ALL tasks in phase complete:

   **Use `requesting-code-review` skill:**

   Dispatch code-reviewer subagent to review the entire phase:
   - All task branches in this phase
   - Verify patterns followed
   - Check acceptance criteria met
   - Review quality and consistency

3. Address review feedback if needed

4. Phase is complete when code review passes

#### Parallel Phase Strategy

For phases where tasks are independent:

**Announce:** "Using `managing-worktrees` skill for parallel task isolation"

**Use git worktrees for true parallel isolation:**

1. **Verify independence** (from plan's dependency analysis):
   - Confirm no file overlaps between tasks
   - Check dependencies are satisfied

2. **Delegate parallel worktree creation to setup subagent**:

   Spawn a setup subagent to create all worktrees for this phase:

   ```
   ROLE: Setup parallel worktrees for Phase {phase-id}

   TASK: Create worktrees for {task-count} parallel tasks

   CRITICAL - SKILL REFERENCE:
   Use the `managing-worktrees` skill Pattern 2 for all parallel worktree operations.

   IMPLEMENTATION:

   1. Get current branch from main worktree:
   ```bash
   cd .worktrees/{run-id}-main
   CURRENT_BRANCH=$(git branch --show-current)
   echo "Base branch: $CURRENT_BRANCH"
   cd ../..  # Return to main repo
   ```

   The current branch will be:
   - **Phase 1**: `{run-id}-main` (initial spec/plan commit)
   - **Phase 2+**: Last task from previous phase (e.g., `{run-id}-task-1-3-schema`)

   2. Create parallel task worktrees (one per task):
   ```bash
   # Create .worktrees directory if needed
   mkdir -p .worktrees

   # For each parallel task, create isolated worktree from CURRENT branch
   # This ensures parallel work builds on previous phase completion
   git worktree add .worktrees/{run-id}-task-{phase}-{task-1} $CURRENT_BRANCH
   git worktree add .worktrees/{run-id}-task-{phase}-{task-2} $CURRENT_BRANCH
   # ... etc for each parallel task in this phase
   ```

   3. Verify worktrees created:
   ```bash
   git worktree list | grep "{run-id}-task-{phase}"
   ```

   4. Report:
   - List of worktrees created with their absolute paths
   - Base branch: `$CURRENT_BRANCH` (dynamically determined from main worktree)
   - Confirmation all worktrees are ready
   - Number of worktrees created

   CRITICAL:
   - ✅ Use `managing-worktrees` skill Pattern 2
   - ✅ Create worktrees from main worktree's current branch
   - ✅ Name worktrees: `.worktrees/{run-id}-task-{phase}-{task}`
   - ✅ Verify all worktrees accessible
   ```

   Store worktree info for later cleanup:
   ```javascript
   parallelWorktrees = {
     '{run-id}-task-{phase}-{task-1}': {path: '.worktrees/{run-id}-task-{phase}-{task-1}', baseBranch: '{current-branch}'},
     '{run-id}-task-{phase}-{task-2}': {path: '.worktrees/{run-id}-task-{phase}-{task-2}', baseBranch: '{current-branch}'}
   }
   ```

   Note: `.worktrees/` is gitignored to prevent contamination.

3. **Spawn parallel agents** (CRITICAL: Single message with multiple Task tools):

   **Announce:** "Using `orchestrating-isolated-subagents` skill for parallel task dispatch"

   For each task, spawn agent with this prompt:

   ```
   ROLE: You are implementing Task {task-id}.

   TASK: {task-name}
   WORKTREE_PATH: {worktree-path}  # e.g., .worktrees/{run-id}-task-{phase}-{task}
   BASE BRANCH: {base-branch}

   CRITICAL - WORKTREE ISOLATION:
   Use the `orchestrating-isolated-subagents` skill Pattern 2 for directory management.
   You are working in an isolated git worktree. This means:
   - You have your own working directory: {worktree-path}
   - Other parallel tasks cannot interfere with your files
   - You must verify WORKTREE_PATH and cd into worktree before starting
   - When done, report completion and do NOT clean up worktree (orchestrator does this)

   SETUP:

   1. Verify WORKTREE_PATH parameter received:
   ```bash
   echo "WORKTREE_PATH: {worktree-path}"
   ```

   2. Change into worktree directory:
   ```bash
   cd {worktree-path}
   pwd  # Verify you're in worktree directory
   git branch --show-current  # Should be {base-branch}
   ```

   IMPLEMENTATION:

   1. Read plan from: {plan-path}
      Find: "Task {task-id}: {task-name}"

   2. Implement according to:
      - Files specified in task
      - Acceptance criteria in task
      - Project constitution (see @docs/constitutions/current/)

   3. Quality checks (MUST run all):
   ```bash
   pnpm format
   pnpm lint
   pnpm test
   ```

   4. Stage changes:
   ```bash
   git add --all
   git status  # Verify changes staged
   ```

   5. Create branch and commit with gs branch create:
   ```bash
   gs branch create {run-id}-task-{task-id}-{short-name} -m "[Task {task-id}] {task-name}

   {Brief summary of changes}

   Acceptance criteria met:
   - {criterion 1}
   - {criterion 2}

   🤖 Generated with [Claude Code](https://claude.com/claude-code)

   Co-Authored-By: Claude <noreply@anthropic.com>"
   ```

   This will:
   - Create a new branch `{run-id}-task-{task-id}-{short-name}`
   - Commit all staged changes
   - Stack the branch on base branch automatically

   6. Detach HEAD to release branch (critical for worktree cleanup):
   ```bash
   git switch --detach
   ```

   This makes the branch accessible in the parent repo after worktree removal.

   7. Report completion with:
      - Summary of changes
      - Files modified
      - Test results
      - Branch name created
      - Confirmation that HEAD is detached
      - Confirmation working in correct worktree

   CRITICAL:
   - ✅ Verify WORKTREE_PATH parameter first
   - ✅ cd into worktree before any work
   - ✅ Stay in worktree directory throughout
   - ✅ Implement ONLY this task
   - ✅ Run ALL quality checks
   - ✅ Stage changes with git add
   - ✅ Use gs branch create with -m flag
   - ✅ MUST detach HEAD after creating branch
   - ✅ Use `orchestrating-isolated-subagents` skill Pattern 2
   - ❌ DO NOT clean up worktree (orchestrator does this)
   - ❌ DO NOT touch other task files
   ```

4. **Wait for all parallel agents to complete**
   (Agents work independently, orchestrator collects results)

5. **Create TodoWrite checklist for parallel worktree cleanup**:

   Before delegating cleanup, orchestrator creates TodoWrite todos:

   ```javascript
   TodoWrite({
     todos: [
       {content: "Verify all parallel task branches exist", status: "pending", activeForm: "Verifying all parallel task branches exist"},
       {content: "Verify all worktrees have detached HEAD", status: "pending", activeForm: "Verifying all worktrees have detached HEAD"},
       {content: "Remove parallel worktree: .worktrees/{run-id}-task-{phase}-{task-1}", status: "pending", activeForm: "Removing parallel worktree"},
       {content: "Remove parallel worktree: .worktrees/{run-id}-task-{phase}-{task-2}", status: "pending", activeForm: "Removing parallel worktree"},
       // ... one todo per worktree
       {content: "Verify branches still accessible after cleanup", status: "pending", activeForm: "Verifying branches still accessible"},
       {content: "Create linear stack from parallel branches", status: "pending", activeForm: "Creating linear stack from parallel branches"},
       {content: "Run integration tests on stacked branches", status: "pending", activeForm: "Running integration tests on stacked branches"}
     ]
   })
   ```

6. **Delegate cleanup to cleanup subagent**:

   **Announce:** "Using `managing-worktrees` skill Pattern 3 for parallel worktree cleanup and `orchestrating-isolated-subagents` skill Pattern 1 for main repo operations"

   After all parallel agents report completion, spawn a cleanup subagent:

   ```
   ROLE: Cleanup parallel worktrees and verify branches

   TASK: Clean up worktrees for Phase {phase-id} and create linear stack

   CRITICAL - ORCHESTRATOR PATTERN:
   Use the `orchestrating-isolated-subagents` skill Pattern 1.
   You are running in the MAIN REPO, not a worktree.
   All git-spice stacking operations must run in main repo.

   CRITICAL - SKILL REFERENCES:
   - Use `managing-worktrees` skill Pattern 3 for worktree cleanup
   - Follow TodoWrite checklist for multi-worktree cleanup

   WORKTREES TO CLEAN:
   - .worktrees/{run-id}-task-{phase}-{task-1} (branch: {run-id}-task-{phase}-{task-1}-{short-name})
   - .worktrees/{run-id}-task-{phase}-{task-2} (branch: {run-id}-task-{phase}-{task-2}-{short-name})
   # ... etc

   IMPLEMENTATION:

   1. Verify you're in main repo (NOT a worktree):
   ```bash
   pwd  # Should be main repo path, NOT .worktrees/*
   ```

   2. Verify all branches exist and are accessible:
   ```bash
   git branch -v | grep "{run-id}-task-{phase}-{task-1}"
   git branch -v | grep "{run-id}-task-{phase}-{task-2}"
   # Should see all task branches listed
   ```

   3. Verify all worktrees have detached HEAD:
   ```bash
   git worktree list | grep "{run-id}-task-{phase}"
   # All parallel worktrees should show (detached HEAD) not a branch name
   ```

   4. Remove all parallel worktrees (use managing-worktrees Pattern 3):
   ```bash
   git worktree remove .worktrees/{run-id}-task-{phase}-{task-1}
   git worktree remove .worktrees/{run-id}-task-{phase}-{task-2}
   # ... etc for each parallel worktree in this phase
   ```

   Update TodoWrite as each worktree is removed.

   5. Verify branches are still accessible after cleanup:
   ```bash
   git branch -v | grep "^  {run-id}-task-{phase}"
   # Should still see all phase task branches
   ```

   6. Create linear stack from parallel branches:
   ```bash
   # Stack parallel branches linearly (task number order: 2.1 -> 2.2 -> 2.3 etc)
   # First task stays on base, subsequent tasks stack on previous
   git checkout {run-id}-task-{phase}-{task-2}-{short-name}
   gs upstack onto {run-id}-task-{phase}-{task-1}-{short-name}

   # For 3+ parallel tasks, continue stacking:
   # git checkout {run-id}-task-{phase}-{task-3}-{short-name}
   # gs upstack onto {run-id}-task-{phase}-{task-2}-{short-name}
   ```

   7. Verify git-spice stack structure:
   ```bash
   gs log short
   ```

   Expected: Linear stack (task number order):
   ```
   ┏━□ {run-id}-task-2-2-validation-schemas (on {run-id}-task-2-1-models-layer)
       ┏━┻□ {run-id}-task-2-1-models-layer (on {run-id}-task-1-2-install-tsx)
     ┏━┻□ {run-id}-task-1-2-install-tsx
   ┏━┻□ {run-id}-task-1-1-game-schema
   main
   ```

   8. Switch back to main worktree:
   ```bash
   cd .worktrees/{run-id}-main
   git checkout {run-id}-task-{phase}-{last-task}-{short-name}  # Top of stack
   pwd  # Verify you're in main worktree
   ```

   9. Run integration tests from main worktree:
   ```bash
   # Tests run in main worktree with all changes from stacked branches
   pnpm test
   pnpm lint
   ```

   10. Report:
   - Confirmation all worktrees cleaned up
   - List of branches created and verified
   - Linear stack structure (task number order)
   - Integration test results
   - Current directory (should be main worktree)
   - Any issues encountered

   CRITICAL:
   - ✅ Run in MAIN REPO for git-spice operations
   - ✅ Use `managing-worktrees` skill Pattern 3 for cleanup
   - ✅ Use `orchestrating-isolated-subagents` skill Pattern 1
   - ✅ Follow TodoWrite checklist throughout
   - ✅ Preserve branches (only remove working directories)
   - ✅ Switch to main worktree after stacking
   - ✅ Verify integration tests pass
   ```

7. **After cleanup and linear stacking, use `requesting-code-review` skill:**

   Dispatch code-reviewer subagent to review the entire phase:
   - All task branches in this phase
   - Check for integration issues
   - Verify patterns followed
   - Ensure no file conflicts
   - Review quality and consistency

8. **Address review feedback if needed**

9. Phase is complete when code review passes, cleanup verified, and linear stack confirmed

### Step 3: Verify Completion

After all phases execute successfully:

**Use the `verification-before-completion` skill:**

This skill enforces verification BEFORE claiming work is done.

**Required verifications:**
```bash
# Run full test suite
pnpm test

# Run linting
pnpm lint

# Run production build
pnpm build

# Verify all pass
echo "All checks passed - ready to complete"
```

**Critical:** Evidence before assertions. Never claim "tests pass" without running them.

### Step 4: Finish Stack

After verification passes:

Use the `finishing-a-development-branch` skill to:
1. Review all changes
2. Choose next action:
   - Submit stack as PRs: `gs stack submit` (per using-git-spice skill)
   - Continue with dependent feature: `gs branch create`
   - Mark complete and sync: `gs repo sync`

### Step 5: Final Report

```markdown
✅ Feature Implementation Complete

**RUN_ID**: {run-id}
**Feature**: {feature-name}
**Stack**: {count} task branches

## Execution Summary

**Phases Completed**: {count}
- Sequential: {count} phases
- Parallel: {count} phases

**Tasks Completed**: {count}
**Commits**: {count}

## Parallelization Results

{For each parallel phase:}
**Phase {id}**: {task-count} tasks in parallel
- Estimated sequential time: {hours}h
- Actual parallel time: {hours}h
- Time saved: {hours}h

**Total Time Saved**: {hours}h ({percent}%)

## Quality Checks

✅ All tests passing
✅ Biome linting clean
✅ Build successful
✅ {total-commits} commits across {branch-count} task branches

## Next Steps

### Review Changes
```bash
gs log short                      # View all branches and commits in stack
gs log long                       # Detailed view with commit messages
git diff main..HEAD               # See all changes in current stack
git branch | grep "^  {run-id}-"  # List all branches for this run
```

### Submit for Review
```bash
gs stack submit  # Submits entire stack as PRs (per using-git-spice skill)
```

### Or Continue with Dependent Feature
```bash
gs branch create  # Creates new branch stacked on current
```
```

## Error Handling

### Phase Execution Failure

If a sequential phase fails:

```markdown
❌ Phase {id} Execution Failed

**Task**: {task-id}
**Error**: {error-message}

## Resolution

1. Review the error above
2. Fix the issue manually or update the plan
3. Resume execution from this phase:
   - Current branch already has completed work
   - Re-run failed task or continue from next task
```

### Parallel Phase Failure

If one agent in parallel phase fails:

```markdown
❌ Parallel Phase {id} - Agent Failure

**Failed Task**: {task-id}
**Branch**: {task-branch}
**Error**: {error-message}

**Successful Tasks**: {list}

## Resolution Options

### Option A: Fix in Branch
```bash
git checkout {task-branch}
# Debug and fix issue
pnpm test
pnpm format
pnpm lint
git add --all
git commit -m "[{task-id}] Fix: {description}"
```

### Option B: Restart Failed Agent
Reset task branch, spawn new agent for this task only:
```bash
git checkout {task-branch}
git reset --hard {base-branch}
# Spawn fresh agent for this task
```

### Option C: Continue Without Failed Task
Complete successful tasks, address failed task in follow-up.
```

### Merge Conflicts

If merging parallel branches causes conflicts:

```markdown
❌ Merge Conflict - Tasks Modified Same Files

**Conflict**: {file-path}
**Branches**: {branch-1}, {branch-2}

This should not happen if task independence was verified correctly.

## Resolution

1. Review plan's file dependencies
2. Check if tasks truly independent
3. Resolve conflict manually:
   ```bash
   git checkout {one-task-branch}
   git merge {other-task-branch}
   # Resolve conflicts in editor
   git add {conflicted-files}
   git commit
   ```

4. Update plan to mark tasks as dependent (sequential) not parallel
```

### Worktree Creation Failure

If worktree creation fails:

```markdown
❌ Worktree Creation Failed

**Error**: {error-message}
**Worktree**: {worktree-path}

Common causes:
- Path already exists: `rm -rf {path}` and `git worktree prune`
- Uncommitted changes on base branch: `git stash` or commit first
- Working directory not clean: Commit or stash changes first
- Detached HEAD in main repo: `git checkout {branch-name}`

Resolution:
1. Check worktree status: `git worktree list`
2. Clean stale worktrees: `git worktree prune`
3. Remove specific worktree: `git worktree remove {path}` (if exists)
4. Verify base branch clean: `git status`
5. Re-run `/spectacular:execute` to resume

After fixing, re-run `/spectacular:execute`
```

### Subagent Directory Isolation Failure

If subagent fails to work in correct worktree:

```markdown
❌ Subagent Directory Isolation Failed

**Error**: Subagent working in wrong directory
**Expected**: {worktree-path}
**Actual**: {actual-path}

This violates `orchestrating-isolated-subagents` skill Pattern 2.

Common causes:
- WORKTREE_PATH parameter not passed to subagent
- Subagent didn't cd into worktree
- Subagent cd command failed
- Path doesn't exist

Resolution:
1. Verify worktree exists: `git worktree list | grep {run-id}`
2. Verify path accessible: `ls -la {worktree-path}`
3. Check subagent prompt includes WORKTREE_PATH parameter
4. Ensure subagent verifies path before work
5. Re-dispatch subagent with corrected prompt

**Prevention**: Always use `orchestrating-isolated-subagents` skill patterns.
```

### Parallel Worktree Cleanup Failure

If parallel worktree cleanup fails:

```markdown
❌ Parallel Worktree Cleanup Failed

**Error**: {error-message}
**Worktree**: {worktree-path}

Common causes:
- Worktree has uncommitted changes (dirty state)
- HEAD not detached (branch still checked out)
- Files locked by process
- Permission issues

Resolution:
1. Check worktree state: `git worktree list`
2. If dirty, manual cleanup required:
   ```bash
   cd {worktree-path}
   git status
   # Either commit or discard changes
   git add --all && git commit -m "WIP: cleanup"
   # OR
   git reset --hard
   ```
3. Verify HEAD detached:
   ```bash
   cd {worktree-path}
   git switch --detach
   ```
4. Retry cleanup: `git worktree remove {worktree-path}`
5. If all else fails, force remove: `git worktree remove -f {worktree-path}`

**Prevention**: Ensure parallel task subagents always detach HEAD after branch creation.
```

## Important Notes

- **Orchestrator stays in main repo** - Uses `orchestrating-isolated-subagents` skill Pattern 1. The orchestrator NEVER changes directory. All work happens in worktrees via subagents.
- **Main worktree for sequential tasks** - Created in Step 0c using `managing-worktrees` skill Pattern 1. All sequential tasks execute in `.worktrees/{run-id}-main`.
- **Isolated worktrees for parallel tasks** - Created per-task using `managing-worktrees` skill Pattern 2. Each parallel task gets `.worktrees/{run-id}-task-{phase}-{task}`.
- **Subagents receive WORKTREE_PATH** - Uses `orchestrating-isolated-subagents` skill Pattern 2. All subagents verify parameter and cd into worktree before work.
- **Orchestrator delegates, never executes** - The orchestrator NEVER runs git commands directly. All git operations are delegated to subagents (setup, implementation, cleanup).
- **Subagents own their git operations** - Implementation subagents create branches and commit their own work using `gs branch create -m`.
- **Skill-driven execution** - Uses `managing-worktrees`, `orchestrating-isolated-subagents`, `using-git-spice`, and superpowers skills throughout.
- **Automatic orchestration** - Reads plan strategies, executes accordingly.
- **Git-spice stacking** - Sequential tasks stack linearly; parallel tasks branch from same base then stack for review (per `using-git-spice` skill).
- **No feature branch** - The stack of task branches IS the feature; never create empty branch upfront.
- **Parallel worktree cleanup** - Uses `managing-worktrees` skill Pattern 3 with TodoWrite checklist. Cleanup subagent runs in main repo to stack branches.
- **Main worktree preservation** - After execution, `.worktrees/{run-id}-main` is preserved for inspection and resume capability. User cleans with `/spectacular:cleanup {run-id}`.
- **Critical: HEAD detachment** - Parallel task subagents MUST detach HEAD after creating branches to make them accessible in parent repo for stacking.
- **Context management** - Each task runs in isolated subagent to avoid token bloat.
- **Constitution adherence** - All agents follow project constitution (@docs/constitutions/current/).
- **Quality gates** - Tests and linting after every task, code review after every phase.
- **Continuous commits** - Small, focused commits with [Task X.Y] markers throughout.

Now execute the plan from: {plan-path}
