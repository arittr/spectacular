---
description: Execute implementation plan with automatic sequential/parallel orchestration using git-spice and worktrees
---

You are executing an implementation plan.

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

**User provided plan path**: The user gave you a plan path like `.worktrees/3a00a7-main/specs/3a00a7-agent-standardization-refactor/plan.md`

**Extract RUN_ID from the path:**

The RUN_ID is the first segment of the spec directory name (before the first dash).

For example:
- Path: `.worktrees/3a00a7-main/specs/3a00a7-agent-standardization-refactor/plan.md`
- Directory: `3a00a7-agent-standardization-refactor`
- RUN_ID: `3a00a7`

```bash
# Extract RUN_ID from plan path (replace {the-plan-path-user-provided} with actual path)
PLAN_PATH="{the-plan-path-user-provided}"
DIR_NAME=$(echo "$PLAN_PATH" | sed 's|^.*specs/||; s|/plan.md$||')
RUN_ID=$(echo "$DIR_NAME" | cut -d'-' -f1)

echo "Extracted RUN_ID: $RUN_ID"

# Verify RUN_ID is not empty
if [ -z "$RUN_ID" ]; then
  echo "❌ Error: Could not extract RUN_ID from plan path: $PLAN_PATH"
  exit 1
fi
```

**CRITICAL**: Execute this entire block as a single multi-line Bash tool call. The comment on the first line is REQUIRED - without it, command substitution `$(...)` causes parse errors.

**Store RUN_ID for use in:**
- Branch naming: `{run-id}-task-X-Y-name`
- Filtering: `git branch | grep "^  {run-id}-"`
- Cleanup: Identify which branches belong to this run

**Announce:** "Executing with RUN_ID: {run-id}"

### Step 0b: Verify Worktree Exists

**After extracting RUN_ID, verify the worktree exists:**

```bash
# Get absolute repo root (stay in main repo, don't cd into worktree)
REPO_ROOT=$(git rev-parse --show-toplevel)

# Verify worktree exists
if [ ! -d "$REPO_ROOT/.worktrees/${RUN_ID}-main" ]; then
  echo "❌ Error: Worktree not found at .worktrees/${RUN_ID}-main"
  echo "Run /spectacular:spec first to create the workspace."
  exit 1
fi

# Verify it's a valid worktree
git worktree list | grep "${RUN_ID}-main"
```

**IMPORTANT: Orchestrator stays in main repo. All worktree operations use `git -C .worktrees/{run-id}-main` or absolute paths.**

**This ensures task worktrees are created at the same level as {run-id}-main, not nested inside it.**

**Announce:** "Verified worktree exists: .worktrees/{run-id}-main/"

### Step 0c: Check for Existing Work

Before starting or resuming, delegate git state check to a subagent:

```
ROLE: Check for existing implementation work

TASK: Determine if work has already started and identify resume point

IMPLEMENTATION:

1. Check current state in the main worktree:
```bash
# Get repo root
REPO_ROOT=$(git rev-parse --show-toplevel)

# Check state in main worktree using git -C
git -C "$REPO_ROOT/.worktrees/{run-id}-main" branch --show-current
git -C "$REPO_ROOT/.worktrees/{run-id}-main" log --oneline --grep="\[Task" -20
git -C "$REPO_ROOT/.worktrees/{run-id}-main" status

# Check git-spice stack (from main repo)
gs ls
gs branch tree

# Filter branches for this RUN_ID
git branch | grep "^  {run-id}-task-"
```

2. Analyze results:
   - Look for commits with `[Task X.Y]` pattern in git log
   - Check for task branches matching `{run-id}-task-` pattern
   - Match branch names to plan tasks
   - Determine which phase and task to resume from

3. Report:
   - Current branch name in main worktree
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

**Note:** All git operations check state in `{runId}-main` worktree using `git -C` or absolute paths.

### Step 1: Read and Parse Plan

Read the plan file and extract:
- Feature name
- All phases (with strategy: sequential or parallel)
- All tasks within each phase

**For each task, extract and format:**
- Task ID and name
- Files to modify (explicit paths)
- Acceptance criteria (bullet points)
- Dependencies (which tasks must complete first)

**Store extracted task info for subagent prompts** (saves ~1000 tokens per subagent):

```
Task 4.2:
  Name: Integrate prompts module into generator
  Files:
    - src/generator.ts
    - src/types.ts
  Acceptance Criteria:
    - Import PromptService from prompts module
    - Replace manual prompt construction with PromptService.getCommitPrompt()
    - Update tests to mock PromptService
    - All tests pass
  Dependencies: Task 4.1 (fallback logic removed)
```

Verify plan structure:
- ✅ Has phases with clear strategies
- ✅ All tasks have files specified
- ✅ All tasks have acceptance criteria
- ✅ Dependencies make sense

### Step 1.5: Detect Project Commands (Optional)

**Optionally detect project-specific quality check commands for subagents to use.**

**This is optional - most projects define commands in CLAUDE.md that subagents can discover.**

If you want to provide hints, check for common patterns:
- **TypeScript/JavaScript**: `package.json` scripts
- **Python**: `pytest`, `ruff`, `black`
- **Go**: `go test`, `golangci-lint`
- **Rust**: `cargo test`, `cargo clippy`

**If detected, mention in subagent prompts:**
- `TEST_CMD` - Command to run tests
- `LINT_CMD` - Command to run linting
- `FORMAT_CMD` - Command to format code
- `BUILD_CMD` - Command to build project

**If not detected, subagents will check CLAUDE.md or skip quality checks with warning.**

**IMPORTANT: Do NOT read constitution files here. Let subagents read them as needed to reduce orchestrator token usage.**

### Step 2: Execute Phases

**If resuming:** Start from the incomplete phase/task identified in Step 0.

For each phase in the plan, execute based on strategy:

**IMPORTANT:** After each phase completes, MUST run code review using `requesting-code-review` skill before proceeding to next phase.

#### Sequential Phase Strategy

For phases where tasks must run in order:

**OPTIMIZATION: Use single worktree for entire phase (not per-task)**

Sequential tasks build on each other, so they can share a worktree. This saves ~2-3 minutes per task from worktree creation/destruction and dependency installs.

1. **Create phase worktree once:**

   Use `using-git-worktrees` skill to:
   - Create worktree at `.worktrees/{run-id}-phase-{phase-id}`
   - Branch from current branch in `{run-id}-main` worktree
   - Ensure worktree is created at same level as `{run-id}-main` (not nested)

2. **Run project setup once:**

   **REQUIRED**: Phase worktree needs dependencies before tasks execute.

   a) **Check CLAUDE.md for setup commands**:
      - Look for `## Development Commands` → `### Setup` section
      - Extract `install` command (e.g., `bun install`)
      - Extract `postinstall` command if defined (e.g., `npx prisma generate`)

   b) **If setup commands found, run installation**:
      ```bash
      # Navigate to phase worktree
      cd .worktrees/${RUN_ID}-phase-${PHASE_ID}

      # Check if dependencies already installed (handles resume)
      if [ ! -d node_modules ]; then
        echo "Installing dependencies in phase worktree..."
        {install-command}  # From CLAUDE.md

        # Run postinstall if defined
        if [ -n "{postinstall-command}" ]; then
          echo "Running postinstall (codegen)..."
          {postinstall-command}  # From CLAUDE.md
        fi
      else
        echo "✅ Dependencies already installed in phase worktree"
      fi
      ```

   c) **If setup commands NOT in CLAUDE.md, error**:
      - Stop execution
      - Tell user to add setup commands to CLAUDE.md
      - See "Using Spectacular in Your Project" section for format

   **Why install per phase**: Phase worktree is shared across all sequential tasks, so install ONCE saves time vs per-task installs.

3. **For each task in the phase, spawn subagent:**

   ```
   ROLE: Implement Task {task-id} in shared phase worktree

   WORKTREE: .worktrees/{run-id}-phase-{phase-id}
   CURRENT BRANCH: {current-branch-in-worktree}

   TASK: {task-name}

   FILES TO MODIFY:
   {extracted-files-list}

   ACCEPTANCE CRITERIA:
   {extracted-acceptance-criteria}

   DEPENDENCIES: {extracted-dependencies}

   INSTRUCTIONS:

   1. Navigate to phase worktree (you're working here with other phase tasks)

   2. Read constitution: docs/constitutions/current/
      - architecture.md - Project structure and boundaries
      - patterns.md - Mandatory patterns to follow
      - tech-stack.md - Approved libraries and versions

   3. Implement task following constitution patterns
      - Modify the files listed above
      - Meet all acceptance criteria
      - Follow architecture/patterns from constitution

   4. Run quality checks (check CLAUDE.md for commands)
      - Dependencies already installed by orchestrator (node_modules present)
      - Run tests/lint/build using CLAUDE.md quality check commands

   5. Create new stacked branch and commit your work:

      CRITICAL: Stage changes FIRST, then create branch (which commits automatically).

      Use `using-git-spice` skill which teaches this two-step workflow:

      a) FIRST: Stage your changes
         - Command: `git add .`

      b) THEN: Create new stacked branch (commits staged changes automatically)
         - Command: `gs branch create {run-id}-task-{task-id}-{short-name} -m "[Task {task-id}] {task-name}"`
         - This creates branch, switches to it, and commits in one operation
         - Include acceptance criteria in commit body

      c) Stay on the new branch (next task builds on it)

      If you commit BEFORE staging and creating branch, your work goes to the wrong branch.
      Read the `using-git-spice` skill if uncertain about the workflow.

   6. Report completion (files changed, branch created, tests passing)

   REFERENCE (if you need more context):
   - Full plan: specs/{runId}-{slug}/plan.md

   CRITICAL:
   - Work in phase worktree (shared with other phase tasks)
   - Stay on your branch when done (next task builds on it)
   - Do NOT clean up worktree
   ```

4. **After ALL tasks complete, stack branches FIRST (before cleanup):**

   CRITICAL: Stack branches BEFORE removing worktree, or branches become inaccessible.

   Use `using-git-spice` skill to:
   - Navigate to `{run-id}-main` worktree temporarily
   - Track and stack all phase branches linearly (task order)
   - Verify stack with `gs log short`
   - Return to main repo

5. **THEN clean up phase worktree (after stacking):**

   Use `using-git-worktrees` skill to remove `.worktrees/{run-id}-phase-{phase-id}`

   Stacking must complete first, otherwise branches created in the phase worktree may be lost.

3. After branches are stacked:

   **MANDATORY: Use `requesting-code-review` skill to dispatch code review subagent:**

   **Announce:** "Phase {phase-id} complete. Using requesting-code-review skill to validate implementation."

   Use the Skill tool to invoke the `requesting-code-review` skill:

   ```
   Skill tool: requesting-code-review
   ```

   The code-reviewer subagent will:
   - Review all task branches in this phase
   - Verify constitution patterns followed
   - Check acceptance criteria met
   - Validate code quality and consistency
   - Report issues or approve

3. Address review feedback if needed:
   - If reviewer reports issues, fix them before proceeding
   - Re-run code review after fixes
   - Do NOT proceed to next phase until review passes

4. Phase is complete ONLY when code review passes

   **Evidence required:** Code review approval message from requesting-code-review skill

#### Parallel Phase Strategy

For phases where tasks are independent:

**CRITICAL: Parallel tasks MUST use isolated worktrees. DO NOT skip worktree creation.**

1. **Verify independence** (from plan's dependency analysis):
   - Confirm no file overlaps between tasks
   - Check dependencies are satisfied

2. **MANDATORY: Create isolated worktree for EACH task BEFORE spawning agents**

   **You MUST create worktrees first. Do NOT spawn agents until all worktrees exist.**

   Use `using-git-worktrees` skill to:
   - Get base branch from `{run-id}-main` worktree
   - Create worktree for each parallel task: `.worktrees/{run-id}-task-{task-id}`
   - Branch from current branch in `{run-id}-main` worktree
   - Verify all worktrees created (one per parallel task)

   **Announce:** "Created {count} isolated worktrees for parallel execution"

3. **Install dependencies in EACH parallel worktree**

   **REQUIRED**: Each isolated worktree needs its own dependencies.

   a) **Check CLAUDE.md for setup commands** (same as sequential):
      - Look for `## Development Commands` → `### Setup` section
      - Extract `install` and `postinstall` commands

   b) **For each parallel task worktree, run installation**:
      ```bash
      # Navigate to task worktree
      cd .worktrees/${RUN_ID}-task-${TASK_ID}

      # Check if dependencies already installed (handles resume)
      if [ ! -d node_modules ]; then
        echo "Installing dependencies in task worktree..."
        {install-command}  # From CLAUDE.md

        # Run postinstall if defined
        if [ -n "{postinstall-command}" ]; then
          echo "Running postinstall (codegen)..."
          {postinstall-command}  # From CLAUDE.md
        fi
      else
        echo "✅ Dependencies already installed in task worktree"
      fi
      ```

   c) **If setup commands NOT in CLAUDE.md, error** (same as sequential)

   **Why install per task**: Parallel worktrees are isolated - they can't share node_modules.

4. **AFTER all worktrees exist AND dependencies installed, spawn parallel agents:**

   **CRITICAL: Single message with multiple Task tools**

   For each task, spawn agent with this prompt:

   ```
   ROLE: Implement Task {task-id} in ISOLATED worktree

   WORKTREE: .worktrees/{run-id}-task-{task-id} ← YOUR worktree (not {run-id}-main!)

   TASK: {task-name}

   FILES TO MODIFY:
   {extracted-files-list}

   ACCEPTANCE CRITERIA:
   {extracted-acceptance-criteria}

   DEPENDENCIES: {extracted-dependencies}

   CRITICAL FIRST STEP - VERIFY ISOLATION:
   ```bash
   REPO_ROOT=$(git rev-parse --show-toplevel)
   cd "$REPO_ROOT/.worktrees/{run-id}-task-{task-id}"
   pwd  # MUST show: .worktrees/{run-id}-task-{task-id}
   ```

   If pwd shows anything else (like {run-id}-main), STOP and report error.

   INSTRUCTIONS:

   1. You're in isolated worktree: .worktrees/{run-id}-task-{task-id}

   2. Read constitution: docs/constitutions/current/
      - architecture.md - Project structure and boundaries
      - patterns.md - Mandatory patterns to follow
      - tech-stack.md - Approved libraries and versions

   3. Implement task following constitution patterns
      - Modify the files listed above
      - Meet all acceptance criteria
      - Follow architecture/patterns from constitution

   4. Run quality checks (check CLAUDE.md for commands)
      - Dependencies already installed by orchestrator (node_modules present)
      - Run tests/lint/build using CLAUDE.md quality check commands

   5. Create new stacked branch and commit your work:

      CRITICAL: Stage changes FIRST, then create branch (which commits automatically).

      Use `using-git-spice` skill which teaches this two-step workflow:

      a) FIRST: Stage your changes
         - Command: `git add .`

      b) THEN: Create new stacked branch (commits staged changes automatically)
         - Command: `gs branch create {run-id}-task-{task-id}-{short-name} -m "[Task {task-id}] {task-name}"`
         - This creates branch, switches to it, and commits in one operation
         - Include acceptance criteria in commit body

      c) Detach HEAD when done
         - Command: `git switch --detach`
         - Makes branch accessible in parent repo after worktree cleanup

      If you commit BEFORE staging and creating branch, your work goes to the wrong branch.
      Read the `using-git-spice` skill if uncertain about the workflow.

   6. Report completion (files changed, branch created, tests passing)

   REFERENCE (if you need more context):
   - Full plan: specs/{runId}-{slug}/plan.md

   CRITICAL:
   - Work in your worktree only (other tasks running in parallel)
   - Detach HEAD before finishing
   - Do NOT clean up worktree
   - Do NOT touch files from other tasks
   ```

5. **Wait for all parallel agents to complete**
   (Agents work independently, orchestrator collects results)

6. **Stack branches linearly FIRST (before cleanup):**

   CRITICAL: Stack branches BEFORE removing worktrees, even though HEAD is detached.

   Use `using-git-spice` skill to:
   - Navigate to `{run-id}-main` worktree temporarily
   - Check out first task branch
   - Stack remaining branches linearly (task number order)
   - Verify stack structure with `gs log short`
   - Run integration tests on top of stack (if commands available)
   - Return to main repo

7. **THEN clean up parallel worktrees (after stacking):**

   Use `using-git-worktrees` skill to:
   - Verify all task branches exist and are stacked
   - Remove all task worktrees
   - Verify branches still accessible after cleanup

   Stacking must complete first for safety and to run integration tests on the complete stack.

8. **MANDATORY: Use `requesting-code-review` skill to dispatch code review subagent:**

   **Announce:** "Phase {phase-id} complete (parallel). Using requesting-code-review skill to validate implementation."

   Use the Skill tool to invoke the `requesting-code-review` skill:

   ```
   Skill tool: requesting-code-review
   ```

   The code-reviewer subagent will:
   - Review all task branches in this phase
   - Check for integration issues between parallel tasks
   - Verify constitution patterns followed
   - Ensure no file conflicts or merge issues
   - Validate code quality and consistency
   - Report issues or approve

9. **Address review feedback if needed:**
   - If reviewer reports issues, fix them before proceeding
   - Re-run code review after fixes
   - Do NOT proceed to next phase until review passes

10. Phase is complete ONLY when:
   - Code review passes (evidence from requesting-code-review skill)
   - Cleanup verified (all worktrees removed)
   - Linear stack confirmed (gs log short shows correct structure)

### Step 3: Verify Completion

After all phases execute successfully:

**Use the `verification-before-completion` skill:**

This skill enforces verification BEFORE claiming work is done.

**Required verifications (if commands detected):**
```bash
# Run full test suite
if [ -n "$TEST_CMD" ]; then
  $TEST_CMD || { echo "❌ Tests failed"; exit 1; }
fi

# Run linting
if [ -n "$LINT_CMD" ]; then
  $LINT_CMD || { echo "❌ Linting failed"; exit 1; }
fi

# Run production build
if [ -n "$BUILD_CMD" ]; then
  $BUILD_CMD || { echo "❌ Build failed"; exit 1; }
fi

# Verify all detected checks passed
echo "✅ All quality checks passed - ready to complete"
```

**If no commands detected:**
```
⚠️  No test/lint/build commands found in project.
Add to CLAUDE.md or constitution/testing.md for automated quality gates.
Proceeding without verification - manual review recommended.
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
**Worktree**: .worktrees/{run-id}-main/
**Stack**: {count} task branches (all stacked on {run-id}-main)

## Execution Summary

**Phases Completed**: {count}
- Sequential: {count} phases
- Parallel: {count} phases

**Tasks Completed**: {count}
**Commits**: {count}

**Isolation**: All work completed in worktree. Main repo unchanged.

## Parallelization Results

{For each parallel phase:}
**Phase {id}**: {task-count} tasks in parallel
- Estimated sequential time: {hours}h
- Actual parallel time: {hours}h
- Time saved: {hours}h

**Total Time Saved**: {hours}h ({percent}%)

## Quality Checks

Quality checks are project-specific (detected from CLAUDE.md, constitution, or common patterns):

✅ Tests passing (if `TEST_CMD` detected)
✅ Linting clean (if `LINT_CMD` detected)
✅ Formatting applied (if `FORMAT_CMD` detected)
✅ Build successful (if `BUILD_CMD` detected)

If no commands detected, quality gates are skipped with warning to user.
✅ {total-commits} commits across {branch-count} task branches

## Next Steps

### Review Changes (from main repo)
```bash
# All these commands work from main repo root
gs log short                      # View all branches and commits in stack
gs log long                       # Detailed view with commit messages
git branch | grep "^  {run-id}-"  # List all branches for this run

# To see changes in worktree:
cd .worktrees/{run-id}-main
git diff main..HEAD               # See all changes in current stack
cd ../..                          # Return to main repo
```

### Submit for Review (from main repo)
```bash
# git-spice commands work from main repo
gs stack submit  # Submits entire stack as PRs (per using-git-spice skill)
```

### Or Continue with Dependent Feature (from worktree)
```bash
cd .worktrees/{run-id}-main       # Navigate to worktree
gs branch create  # Creates new branch stacked on current
cd ../..                          # Return to main repo when done
```

### Cleanup Worktree (after PRs merged)
```bash
# From main repo root:
git worktree remove .worktrees/{run-id}-main

# Optional: Delete the {run-id}-main branch
git branch -d {run-id}-main
```

**Important**: Main repo remains unchanged. All work is in the worktree and task branches.
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
# Run quality checks (use project-specific commands)
if [ -n "$TEST_CMD" ]; then $TEST_CMD; fi
if [ -n "$FORMAT_CMD" ]; then $FORMAT_CMD; fi
if [ -n "$LINT_CMD" ]; then $LINT_CMD; fi

# If fixing on existing task branch (no new branch needed):
git add --all
git commit -m "[{task-id}] Fix: {description}"

# If creating new fix as stacked branch:
# gs branch create {run-id}-task-{task-id}-fix-{issue}
# git add --all
# git commit -m "[{task-id}] Fix: {description}"
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

### Worktree Not Found

If the {run-id}-main worktree doesn't exist:

```markdown
❌ Worktree Not Found

**Error**: .worktrees/{run-id}-main does not exist

This means `/spectacular:spec` was not run, or the worktree was removed.

## Resolution

Run the spec command first to create the workspace:
```bash
/spectacular:spec {feature-name}
```

This will create `.worktrees/{run-id}-main/` and the spec file.
Then run `/spectacular:plan` to generate the plan.
Finally, run `/spectacular:execute` to execute the plan.
```

### Parallel Task Worktree Creation Failure

If worktree creation for parallel tasks fails:

```markdown
❌ Parallel Task Worktree Creation Failed

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
