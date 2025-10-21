---
description: Execute implementation plan with automatic sequential/parallel orchestration using git-spice and worktrees
---

You are executing an implementation plan for BigNight.Party.

## Required Skills

Before starting, you MUST read these skills:
- `using-git-spice` - For managing stacked branches (~/.claude/skills/using-git-spice/SKILL.md)
- `using-git-worktrees` - For parallel task isolation (superpowers skill)
- `requesting-code-review` - For phase review gates (superpowers skill)
- `verification-before-completion` - For final verification (superpowers skill)
- `finishing-a-development-branch` - For completion workflow (superpowers skill)

## Input

User will provide: `/spectacular:execute {plan-path}`

Example: `/spectacular:execute @specs/a1b2c3-magic-link-auth/plan.md`

Where `a1b2c3` is the runId and `magic-link-auth` is the feature slug.

## Workflow

### Step 0a: Extract Run ID from Plan

**First action**: Read the plan and extract the RUN_ID from frontmatter.

```bash
# Extract runId from plan frontmatter
RUN_ID=$(grep "^runId:" {plan-path} | awk '{print $2}')
echo "RUN_ID: $RUN_ID"
```

**If RUN_ID not found:**
Generate one now (for backwards compatibility with old plans):
```bash
RUN_ID=$(echo "{feature-name}-$(date +%s)" | shasum -a 256 | head -c 6)
echo "Generated RUN_ID: $RUN_ID (plan missing runId)"
```

**Store RUN_ID for use in:**
- Branch naming: `{run-id}-task-X-Y-name`
- Filtering: `git branch | grep ^{run-id}-`
- Cleanup: Identify which branches belong to this run

**Announce:** "Executing with RUN_ID: {run-id}"

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
- Continue to Step 1 (Read and Parse Plan)

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

**Execute tasks sequentially with stacked branches:**

1. For each task in the phase:

   **Spawn subagent for task implementation** (use Task tool):

   ```
   ROLE: You are implementing Task {task-id} for BigNight.Party.

   TASK: {task-name}
   CURRENT BRANCH: {current-branch}

   CRITICAL - CONTEXT MANAGEMENT:
   You are a subagent with isolated context. Complete this task independently.

   IMPLEMENTATION:

   1. Verify you're on the correct branch:
   ```bash
   git branch --show-current  # Should be {current-branch}
   ```

   2. Read task details from: /Users/drewritter/projects/bignight.party/{plan-path}
      Find: "Task {task-id}: {task-name}"

   3. Implement according to:
      - Files specified in task
      - Acceptance criteria in task
      - Project constitution (see @docs/constitutions/current/)

   4. Quality checks (MUST run all):
   ```bash
   pnpm format
   pnpm lint
   ```

   5. Stage changes:
   ```bash
   git add --all
   git status  # Verify changes staged
   ```

   6. Create branch and commit with gs branch create:
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

   7. Report completion with:
      - Summary of changes
      - Files modified
      - Test results
      - Branch name created
      - Commit hash
      - Any issues encountered

   CRITICAL:
   - ✅ Stay on current branch (will move to new branch after commit)
   - ✅ Run ALL quality checks
   - ✅ Stage changes with git add
   - ✅ Use gs branch create with -m flag to commit
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

**Use git worktrees for true parallel isolation (per using-git-worktrees skill):**

1. **Verify independence** (from plan's dependency analysis):
   - Confirm no file overlaps between tasks
   - Check dependencies are satisfied

2. **Delegate worktree creation to setup subagent**:

   Spawn a setup subagent to create all worktrees for this phase:

   ```
   ROLE: Setup parallel worktrees for Phase {phase-id}

   TASK: Create worktrees for {task-count} parallel tasks

   IMPLEMENTATION:

   1. Get current branch:
   ```bash
   CURRENT_BRANCH=$(git branch --show-current)
   echo "Base branch: $CURRENT_BRANCH"
   ```

   2. Create worktrees (one per parallel task):
   ```bash
   # Create .worktrees directory if needed
   mkdir -p .worktrees

   # For each parallel task, create a worktree (namespaced by RUN_ID)
   git worktree add --detach ./.worktrees/{run-id}-task-{task-id-1} $CURRENT_BRANCH
   git worktree add --detach ./.worktrees/{run-id}-task-{task-id-2} $CURRENT_BRANCH
   # ... etc for each parallel task
   ```

   3. Verify worktrees created:
   ```bash
   git worktree list
   ```

   4. Report:
   - List of worktrees created with their paths
   - Base branch name
   - Confirmation all worktrees are ready
   ```

   Store worktree info for later cleanup:
   ```javascript
   taskWorktrees = {
     '{run-id}-task-3-1': {path: './.worktrees/{run-id}-task-3-1', baseBranch: '{run-id}-task-2-3-...'},
     '{run-id}-task-3-2': {path: './.worktrees/{run-id}-task-3-2', baseBranch: '{run-id}-task-2-3-...'}
   }
   ```

   Note: `.worktrees/` is gitignored to prevent contamination.

3. **Spawn parallel agents** (CRITICAL: Single message with multiple Task tools):

   For each task, spawn agent with this prompt:

   ```
   ROLE: You are implementing Task {task-id} for BigNight.Party.

   TASK: {task-name}
   WORKTREE: {worktree-path}
   BASE BRANCH: {base-branch}

   CRITICAL - WORKTREE ISOLATION:
   You are working in an isolated git worktree. This means:
   - You have your own working directory: {worktree-path}
   - Other parallel tasks cannot interfere with your files
   - You must cd into your worktree before starting
   - When done, report completion and do NOT clean up worktree

   SETUP:
   ```bash
   cd {worktree-path}
   git branch --show-current  # Should be {base-branch}
   pwd  # Confirm you're in worktree directory
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

   5. Stage changes (but DO NOT commit):
   ```bash
   git add --all
   git status  # Verify changes staged
   ```

   6. Create branch and commit with gs branch create:
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

   7. Detach HEAD to release branch (critical for worktree cleanup):
   ```bash
   git switch --detach
   ```

   This makes the branch accessible in the parent repo after worktree removal.

   8. Report completion with:
      - Summary of changes
      - Files modified
      - Test results
      - Branch name created
      - Confirmation that HEAD is detached

   CRITICAL:
   - ✅ cd into worktree first
   - ✅ Stay in worktree directory
   - ✅ Implement ONLY this task
   - ✅ Run ALL quality checks
   - ✅ Stage changes with git add
   - ✅ Use gs branch create with -m flag
   - ✅ MUST detach HEAD after creating branch
   - ❌ DO NOT clean up worktree (orchestrator does this)
   - ❌ DO NOT touch other task files
   ```

4. **Wait for all parallel agents to complete**
   (Agents work independently, orchestrator collects results)

5. **Delegate cleanup to cleanup subagent**:

   After all parallel agents report completion, spawn a cleanup subagent:

   ```
   ROLE: Cleanup parallel worktrees and verify branches

   TASK: Clean up worktrees for Phase {phase-id} and verify git-spice stack

   WORKTREES TO CLEAN:
   - ./.worktrees/{run-id}-task-{task-id-1} (branch: {run-id}-task-{task-id-1}-{short-name})
   - ./.worktrees/{run-id}-task-{task-id-2} (branch: {run-id}-task-{task-id-2}-{short-name})
   # ... etc

   IMPLEMENTATION:

   1. Verify all branches exist and are accessible:
   ```bash
   git branch -v | grep "{run-id}-task-{task-id-1}"
   git branch -v | grep "{run-id}-task-{task-id-2}"
   # Should see all task branches listed
   ```

   2. Verify all worktrees have detached HEAD:
   ```bash
   git worktree list
   # All worktrees should show (detached HEAD) not a branch name
   ```

   3. Remove all worktrees:
   ```bash
   git worktree remove ./.worktrees/{run-id}-task-{task-id-1}
   git worktree remove ./.worktrees/{run-id}-task-{task-id-2}
   # ... etc
   ```

   4. Verify branches are still accessible after cleanup:
   ```bash
   git branch -v | grep "^  {run-id}-task-"
   # Should still see all task branches for this run
   ```

   5. Create linear stack from parallel branches:
   ```bash
   # Stack parallel branches linearly (task order: 2.1 -> 2.2 -> 2.3 etc)
   # First task stays on base, subsequent tasks stack on previous
   git checkout {run-id}-task-{task-id-2}-{short-name}
   gs upstack onto {run-id}-task-{task-id-1}-{short-name}

   # For 3+ parallel tasks, continue stacking:
   # git checkout {run-id}-task-{task-id-3}-{short-name}
   # gs upstack onto {run-id}-task-{task-id-2}-{short-name}
   ```

   6. Verify git-spice stack structure:
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

   7. Run integration tests:
   ```bash
   # Check out the top of the stack (last parallel task)
   git checkout {run-id}-task-{task-id-2}-{short-name}

   # Run tests on the branch (includes all previous work)
   pnpm test
   pnpm lint
   ```

   8. Report:
   - Confirmation all worktrees cleaned up
   - List of branches created and verified
   - Linear stack structure (task number order)
   - Integration test results
   - Any issues encountered
   ```

6. **After cleanup and linear stacking, use `requesting-code-review` skill:**

   Dispatch code-reviewer subagent to review the entire phase:
   - All task branches in this phase
   - Check for integration issues
   - Verify patterns followed
   - Ensure no file conflicts
   - Review quality and consistency

7. **Address review feedback if needed**

8. Phase is complete when code review passes, cleanup verified, and linear stack confirmed

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

Common causes:
- Path already exists: `rm -rf {path}` and `git worktree prune`
- Uncommitted changes on current branch: `git stash`
- Working directory not clean: Commit or stash changes first

After fixing, re-run `/spectacular:execute`
```

## Important Notes

- **Orchestrator delegates, never executes** - The orchestrator NEVER runs git commands directly. All git operations are delegated to subagents (setup, implementation, cleanup)
- **Subagents own their git operations** - Implementation subagents create branches and commit their own work using `gs branch create -m`
- **Skill-driven execution** - Uses using-git-spice, using-git-worktrees, and other superpowers skills
- **Automatic orchestration** - Reads plan strategies, executes accordingly
- **Git-spice stacking** - Sequential tasks stack linearly; parallel tasks branch from same base (per using-git-spice skill)
- **No feature branch** - The stack of task branches IS the feature; never create empty branch upfront
- **Worktree isolation** - Parallel tasks run in separate worktrees (per using-git-worktrees skill)
- **Critical: HEAD detachment** - Parallel task subagents MUST detach HEAD after creating branches to make them accessible in parent repo
- **Context management** - Each task runs in isolated subagent to avoid token bloat
- **Constitution adherence** - All agents follow project constitution (@docs/constitutions/current/)
- **Quality gates** - Tests and linting after every task, code review after every phase
- **Continuous commits** - Small, focused commits with [Task X.Y] markers throughout

Now execute the plan from: {plan-path}
