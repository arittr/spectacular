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

### Step 1.5: Validate Setup Commands (REQUIRED)

**CRITICAL: Validate CLAUDE.md setup commands BEFORE creating worktrees.**

Worktrees require dependency installation before tasks can execute. Projects MUST define setup commands in CLAUDE.md.

```bash
# Get repo root
REPO_ROOT=$(git rev-parse --show-toplevel)

# Check if CLAUDE.md exists
if [ ! -f "$REPO_ROOT/CLAUDE.md" ]; then
  echo "❌ Error: CLAUDE.md not found in repository root"
  echo ""
  echo "Spectacular requires CLAUDE.md to define setup commands."
  echo "See: https://docs.claude.com/claude-code"
  exit 1
fi

# Parse CLAUDE.md for setup section
INSTALL_CMD=$(grep -A 10 "^### Setup" "$REPO_ROOT/CLAUDE.md" | grep "^- \*\*install\*\*:" | sed 's/.*: `\(.*\)`.*/\1/')

if [ -z "$INSTALL_CMD" ]; then
  echo "❌ Error: Setup commands not defined in CLAUDE.md"
  echo ""
  echo "Worktrees require dependency installation before tasks can execute."
  echo ""
  echo "Add this section to CLAUDE.md:"
  echo ""
  echo "## Development Commands"
  echo ""
  echo "### Setup"
  echo "- **install**: \`npm install\`  (or your package manager)"
  echo "- **postinstall**: \`npx prisma generate\`  (optional - any codegen)"
  echo ""
  echo "Example for different package managers:"
  echo "- Node.js: npm install, pnpm install, yarn, or bun install"
  echo "- Python: pip install -r requirements.txt"
  echo "- Rust: cargo build"
  echo "- Go: go mod download"
  echo ""
  echo "See: https://docs.claude.com/claude-code"
  echo ""
  echo "Execution stopped. Add setup commands to CLAUDE.md and retry."
  exit 1
fi

# Extract postinstall command (optional)
POSTINSTALL_CMD=$(grep -A 10 "^### Setup" "$REPO_ROOT/CLAUDE.md" | grep "^- \*\*postinstall\*\*:" | sed 's/.*: `\(.*\)`.*/\1/')

# Report detected commands
echo "✅ Setup commands found in CLAUDE.md"
echo "   install: $INSTALL_CMD"
if [ -n "$POSTINSTALL_CMD" ]; then
  echo "   postinstall: $POSTINSTALL_CMD"
fi
```

**If validation fails:**
- Execution stops immediately
- User gets clear error message with example
- No worktrees created
- No partial state left behind

**If validation succeeds:**
- Store `INSTALL_CMD` and `POSTINSTALL_CMD` for use in dependency installation steps
- Proceed to phase execution

### Step 1.6: Detect Project Commands (Optional)

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

#### Cross-Phase Stacking (How Phases Chain Together)

**CRITICAL: Phases automatically build on each other's completed work**

Understanding how phases chain together is essential for correct execution:

**Example: Sequential → Parallel → Sequential**

1. **Phase 1 (Sequential)** - Database setup
   - Works in `{runid}-main` worktree
   - Creates branch: `{runid}-task-1-1-database-schema`
   - Leaves main worktree **on this branch** ← Key state for next phase

2. **Phase 2 (Parallel)** - Three feature implementations
   - **Base detection:**
     ```bash
     BASE_BRANCH=$(git -C .worktrees/{runid}-main branch --show-current)
     # Returns: {runid}-task-1-1-database-schema ← Inherits from Phase 1
     ```
   - Creates 3 worktrees **FROM Phase 1's completed branch**
   - All parallel tasks build on Phase 1's database schema
   - After stacking, leaves main worktree **on last parallel task** ← Key state for next phase

3. **Phase 3 (Sequential)** - Integration tests
   - Works in `{runid}-main` worktree (reused from Phase 1)
   - Current branch: `{runid}-task-2-3-last-parallel-task` (from Phase 2)
   - Creates branch: `{runid}-task-3-1-integration-tests`
   - Automatically stacks on Phase 2's last task via natural stacking

**Result:** Linear chain across all phases: Phase 1 → Phase 2 tasks → Phase 3

**Verification between phases:**

```bash
# Before creating parallel worktrees (Phase 2)
BASE_BRANCH=$(git -C .worktrees/{runid}-main branch --show-current)
echo "Phase 2 starting from: $BASE_BRANCH"
# Should show Phase 1's completed branch

# Before sequential task (Phase 3)
CURRENT_BRANCH=$(git -C .worktrees/{runid}-main branch --show-current)
echo "Phase 3 starting from: $CURRENT_BRANCH"
# Should show Phase 2's last stacked branch
```

**Key Principles:**

1. **Main worktree tracks progress** - Current branch = latest completed work
2. **Parallel phases inherit** - Use `git -C .worktrees/{runid}-main branch --show-current` as base
3. **Parallel stacking preserves continuity** - Last stacked branch becomes next phase's base
4. **Sequential phases extend naturally** - `gs branch create` stacks on current HEAD
5. **No manual intervention needed** - Cross-phase chaining is automatic

**Common Mistake to Avoid:**

❌ **Wrong:** Creating parallel worktrees from `{runid}-main` branch (ignores Phase 1)
```bash
# DON'T DO THIS:
git worktree add .worktrees/{runid}-task-2-1 --detach {runid}-main
```

✅ **Correct:** Creating parallel worktrees from current branch in main worktree
```bash
# DO THIS:
BASE_BRANCH=$(git -C .worktrees/{runid}-main branch --show-current)
git worktree add .worktrees/{runid}-task-2-1 --detach "$BASE_BRANCH"
```

#### Sequential Phase Strategy

For phases where tasks must run in order:

**KEY INSIGHT: Sequential tasks work directly in `{runid}-main` worktree**

Sequential tasks build on each other and use git-spice's natural stacking behavior. Each task creates a new branch with `gs branch create`, which automatically stacks on the current HEAD. No manual stacking operations needed.

**CRITICAL - DO NOT:**
- ❌ Create phase-specific worktrees (e.g., `.worktrees/{runid}-phase-1`)
- ❌ Create task-specific worktrees for sequential tasks (e.g., `.worktrees/{runid}-task-1-1`)
- ❌ Use `gs upstack onto` for sequential tasks (natural stacking handles this)
- ❌ Create temporary branches or detach HEAD
- ❌ Run manual stacking operations after task completion

**DO:**
- ✅ Work in existing `{runid}-main` worktree for ALL sequential tasks
- ✅ Use `gs branch create` which automatically stacks on current HEAD
- ✅ Let each task build on previous task's branch naturally
- ✅ Stay on newly created branch after each task (next task stacks on it)

1. **Verify setup in main worktree:**

   Sequential tasks work in the existing `{run-id}-main` worktree (created during spec generation).

   - Verify dependencies already installed from spec phase
   - If `node_modules` missing, run setup commands from CLAUDE.md
   - No new worktree creation needed

2. **For each task in the phase, spawn subagent in sequence:**

   ```
   ROLE: Implement Task {task-id} in main worktree (sequential phase)

   WORKTREE: .worktrees/{run-id}-main
   CURRENT BRANCH: {current-branch-in-worktree}

   TASK: {task-name}

   FILES TO MODIFY:
   {extracted-files-list}

   ACCEPTANCE CRITERIA:
   {extracted-acceptance-criteria}

   DEPENDENCIES: {extracted-dependencies}

   INSTRUCTIONS:

   1. Navigate to main worktree:
      ```bash
      cd .worktrees/{run-id}-main
      ```

   2. Read constitution: docs/constitutions/current/
      - architecture.md - Project structure and boundaries
      - patterns.md - Mandatory patterns to follow
      - tech-stack.md - Approved libraries and versions

   3. Implement task following constitution patterns
      - Modify the files listed above
      - Meet all acceptance criteria
      - Follow architecture/patterns from constitution

   4. Run quality checks (check CLAUDE.md for commands)
      - Dependencies already installed from spec phase
      - Run tests/lint/build using CLAUDE.md quality check commands

      **CRITICAL: Check exit codes and stop on failure**

      ```bash
      # Read quality check commands from CLAUDE.md
      # Look for "### Quality Checks" section

      # Example check sequence (adapt based on CLAUDE.md):
      npm test
      if [ $? -ne 0 ]; then
        echo "❌ Tests failed"
        echo "Fix test failures before creating branch"
        exit 1
      fi

      npm run lint
      if [ $? -ne 0 ]; then
        echo "❌ Lint failed"
        echo "Run 'npm run lint --fix' to auto-fix, or fix manually"
        exit 1
      fi

      npm run build
      if [ $? -ne 0 ]; then
        echo "❌ Build failed"
        echo "Fix TypeScript/compilation errors before creating branch"
        exit 1
      fi
      ```

      **Do NOT create branch if quality checks fail**

   5. Create new stacked branch and commit your work:

      CRITICAL: Stage changes FIRST, then create branch (which commits automatically).

      Use `using-git-spice` skill which teaches this two-step workflow:

      a) FIRST: Stage your changes
         - Command: `git add .`

      b) THEN: Create new stacked branch (commits staged changes automatically and stacks on current HEAD)
         - Command: `gs branch create {run-id}-task-{phase-id}-{task-id}-{short-name} -m "[Task {phase-id}-{task-id}] {task-name}"`
         - This creates branch, switches to it, and commits in one operation
         - The branch automatically stacks on whatever branch you're currently on
         - Include acceptance criteria in commit body

      c) Stay on the new branch (next task builds on it automatically)

      **Natural stacking**: Because you stay on your new branch, the next task's `gs branch create` will automatically stack on your branch. No manual stacking needed.

   6. Report completion (files changed, branch created, tests passing)

   REFERENCE (if you need more context):
   - Full plan: specs/{runId}-{slug}/plan.md

   CRITICAL:
   - Work in {run-id}-main worktree (shared for all sequential tasks)
   - Stay on your branch when done (next task automatically stacks on it)
   - Do NOT create new worktrees or cleanup
   ```

3. **Verify natural stack formation:**

   After all sequential tasks complete, verify the linear stack was created naturally:

   ```bash
   cd .worktrees/{run-id}-main
   gs log short
   # Should show: task-1 → task-2 → task-3 (linear chain, automatically stacked)
   cd "$REPO_ROOT"
   ```

   **No manual stacking needed**: Each task's `gs branch create` automatically stacked on the previous task's branch.

4. **After verification:**

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

   **CRITICAL: Verify you are in main repo root FIRST, not a worktree:**

   ```bash
   # Get main repo root (not worktree!)
   REPO_ROOT=$(git rev-parse --show-toplevel)

   # Verify not currently in a worktree
   if [[ "$REPO_ROOT" =~ \.worktrees ]]; then
     echo "❌ Error: Currently in worktree, must run from main repo"
     echo "Current: $REPO_ROOT"
     exit 1
   fi

   # Navigate to main repo root
   cd "$REPO_ROOT"
   pwd  # Should show main repo path, not .worktrees/...
   ```

   **Then create worktrees from verified main repo location:**

   ```bash
   # Get base branch from main worktree
   BASE_BRANCH=$(git -C .worktrees/{runid}-main branch --show-current)

   # Create isolated worktrees in DETACHED HEAD state
   # Using --detach allows multiple worktrees without branch conflicts
   # Subagents will create their own branches with gs branch create
   for TASK_ID in {list-of-task-ids}; do
     git worktree add ".worktrees/{runid}-task-${TASK_ID}" --detach "$BASE_BRANCH"
     echo "✅ Created .worktrees/{runid}-task-${TASK_ID} (detached HEAD)"
   done

   # Verify all worktrees created
   git worktree list | grep "{runid}-task-"
   # Each should show "(detached HEAD)" status
   ```

   **Verify worktree creation succeeded:**

   ```bash
   # Count created worktrees
   CREATED_COUNT=$(git worktree list | grep -c "{runid}-task-")

   if [ $CREATED_COUNT -ne {expected-task-count} ]; then
     echo "❌ Error: Expected {expected-task-count} worktrees, found $CREATED_COUNT"
     git worktree list
     exit 1
   fi

   echo "✅ Created $CREATED_COUNT worktrees for parallel execution"

   # Verify each worktree has detached HEAD
   for TASK_ID in {task-ids}; do
     WORKTREE_PATH=".worktrees/{runid}-task-${TASK_ID}"

     if [ ! -d "$WORKTREE_PATH" ]; then
       echo "❌ Error: Worktree not found: $WORKTREE_PATH"
       exit 1
     fi

     # Check HEAD is detached
     if ! git -C "$WORKTREE_PATH" status | grep -q "HEAD detached"; then
       echo "❌ Error: Worktree not in detached HEAD state: $WORKTREE_PATH"
       git -C "$WORKTREE_PATH" status
       exit 1
     fi
   done

   echo "✅ All worktrees verified: detached HEAD, correct paths"
   ```

   **Why --detach?** Git doesn't allow the same branch to be checked out in multiple worktrees. Detached HEAD state allows parallel worktrees, and subagents will create their actual task branches with `gs branch create`.

   **If you create worktrees from wrong location (inside a worktree), you'll get nested worktrees and path errors.**

   **Announce:** "Created and verified {count} isolated worktrees for parallel execution"

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
   git status  # Should show "HEAD detached at <commit>"
   ```

   If pwd shows anything else (like {run-id}-main), STOP and report error.

   **Note**: Detached HEAD state is expected - you'll create your branch in step 5.

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

      **CRITICAL: Check exit codes and stop on failure**

      ```bash
      # Read quality check commands from CLAUDE.md
      # Look for "### Quality Checks" section

      # Example check sequence (adapt based on CLAUDE.md):
      npm test
      if [ $? -ne 0 ]; then
        echo "❌ Tests failed"
        echo "Fix test failures before creating branch"
        exit 1
      fi

      npm run lint
      if [ $? -ne 0 ]; then
        echo "❌ Lint failed"
        echo "Run 'npm run lint --fix' to auto-fix, or fix manually"
        exit 1
      fi

      npm run build
      if [ $? -ne 0 ]; then
        echo "❌ Build failed"
        echo "Fix TypeScript/compilation errors before creating branch"
        exit 1
      fi
      ```

      **Do NOT create branch if quality checks fail**

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

6. **Verify all tasks completed successfully BEFORE stacking:**

   **CRITICAL: Do NOT proceed to stacking if any task failed.**

   ```bash
   # Check all task branches exist (confirms subagents created them)
   FAILED_TASKS=()

   for TASK_ID in {task-id-1} {task-id-2} {task-id-3}; do
     BRANCH_NAME="{runid}-task-{phase-id}-${TASK_ID}-{short-name}"

     if ! git rev-parse --verify "$BRANCH_NAME" >/dev/null 2>&1; then
       FAILED_TASKS+=("Task ${TASK_ID}")
     fi
   done

   # If any tasks failed, report and exit
   if [ ${#FAILED_TASKS[@]} -gt 0 ]; then
     echo "❌ Phase {phase-id} execution failed"
     echo ""
     echo "Failed tasks: ${FAILED_TASKS[*]}"
     echo ""
     echo "Successful tasks created branches. Failed tasks did not."
     echo ""
     echo "To resume:"
     echo "1. Fix failures in task worktrees: .worktrees/{runid}-task-{id}"
     echo "2. Create branches manually for fixed tasks"
     echo "3. Re-run /spectacular:execute to complete phase"
     exit 1
   fi

   echo "✅ All {task-count} tasks completed successfully"
   ```

   **Why this matters:**
   - Failed tasks don't create branches (quality checks blocked commit)
   - Stacking would fail or create incomplete chain
   - Early detection provides clear error and recovery path

7. **Stack branches linearly FIRST (before cleanup):**

   CRITICAL: Stack branches BEFORE removing worktrees, even though HEAD is detached.

   **Create linear stack using loop-based algorithm:**

   ```bash
   # Verify starting from main repo
   REPO_ROOT=$(git rev-parse --show-toplevel)
   cd "$REPO_ROOT"

   # Navigate to main worktree for git-spice operations
   cd .worktrees/{runid}-main

   # Get base branch from main worktree (what parallel tasks branched from)
   BASE_BRANCH=$(git branch --show-current)

   # Array of task branch names (in order)
   TASK_BRANCHES=(
     "{runid}-task-{phase-id}-1-{short-name-1}"
     "{runid}-task-{phase-id}-2-{short-name-2}"
     "{runid}-task-{phase-id}-3-{short-name-3}"
     # ... add all task branches in order
   )

   # Count tasks
   TASK_COUNT=${#TASK_BRANCHES[@]}

   # Handle edge case: N=1 (single task in parallel phase)
   if [ $TASK_COUNT -eq 1 ]; then
     echo "Single task in parallel phase - tracking only"
     git checkout "${TASK_BRANCHES[0]}"
     gs branch track
     # No upstack needed for single task
   else
     # Handle N≥2: Stack tasks linearly
     echo "Stacking $TASK_COUNT tasks linearly..."

     for i in "${!TASK_BRANCHES[@]}"; do
       BRANCH="${TASK_BRANCHES[$i]}"

       if [ $i -eq 0 ]; then
         # First task: Track only (stacks on BASE_BRANCH automatically)
         echo "Task 1: $BRANCH (base of stack)"
         git checkout "$BRANCH"
         gs branch track
       else
         # Subsequent tasks: Track and upstack onto previous
         PREV_BRANCH="${TASK_BRANCHES[$((i-1))]}"
         echo "Task $((i+1)): $BRANCH (stacking onto $PREV_BRANCH)"
         git checkout "$BRANCH"
         gs branch track
         gs upstack onto "$PREV_BRANCH"
       fi
     done
   fi

   # Verify linear stack structure
   echo ""
   echo "Verifying linear stack..."
   gs log short
   # Should show: task-1 → task-2 → task-3 → ... (linear chain)

   # Run integration tests if commands available
   if [ -n "$TEST_CMD" ]; then
     echo "Running integration tests on complete stack..."
     $TEST_CMD
   fi

   # Return to main repo
   cd "$REPO_ROOT"
   ```

   **Algorithm handles all cases:**
   - **N=1**: Single task gets tracked, no upstack (0 upstack operations)
   - **N=2**: First task tracked, second upstacks onto first (1 upstack operation)
   - **N=3**: Linear chain with 2 upstack operations
   - **N≥4**: Generalizes to N-1 upstack operations

   **Why this works:**
   - First task always stacks on current HEAD in main worktree (natural stacking)
   - Each subsequent task explicitly upstacks onto previous task (manual stacking)
   - Result: Linear chain regardless of N

   **Performance Characteristics:**
   - **Time Complexity**: O(N) - Single loop processes each task exactly once
   - **Operations per task**: 2-3 git-spice commands (checkout, track, upstack)
   - **N=10 Expected Time**: ~30 seconds for stacking operations
   - **Scalability**: Linear scaling (2 tasks → 10 tasks: +275% time, not +900%)
   - **Resource Requirements**:
     - **Disk**: ~500MB per worktree (~5GB total for N=10)
     - **Memory**: ~200MB per parallel subagent (~2GB peak for N=10)
     - **File handles**: N+1 worktrees (main + N task worktrees)
   - **Performance validation**: No degradation from N=3 to N=10 scenarios

   **Reference**: See `using-git-spice` skill for command details if uncertain about git-spice operations.

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
