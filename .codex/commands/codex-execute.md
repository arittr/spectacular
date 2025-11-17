---
description: Execute implementation plan via Codex MCP server with automatic parallel orchestration (Codex-only)
---

<!--
DUPLICATION NOTICE:
Steps 0a-0c and 1.5-1.7 (orchestration setup) are intentionally duplicated from commands/execute.md.
This duplication enables independent evolution of Codex and Claude Code execution paths.

If you update orchestration logic (Run ID extraction, worktree verification, validation, etc.),
check BOTH files:
- commands/execute.md (Claude Code - uses Task tool)
- .codex/commands/codex-execute.md (Codex - uses MCP tool)

The ONLY difference is Step 2:
- execute.md: Uses executing-parallel-phase and executing-sequential-phase skills with Task tool
- codex-execute.md: Calls spectacular_execute MCP tool with plan_path (MCP server handles parsing)

See CLAUDE.md "Codex-Specific Commands" section for architecture rationale.
-->

You are executing an implementation plan using the Codex MCP server.

## Architecture

**Execution Flow:**

1. **Orchestrator (This Command)**: Validates worktree, setup, configures options
2. **MCP Server** (spectacular-codex): Parses plan.md, spawns Codex CLI subagents
3. **Codex Subagents**: Execute tasks in isolated worktrees (parallel or sequential)
4. **Git State**: Branches track completion, worktrees provide isolation

**Key Difference from Claude Code:**

- Claude Code: Uses Task tool to spawn Claude subagents in same session
- Codex: Calls spectacular_execute MCP tool which spawns separate Codex CLI processes with `--dangerously-bypass-approvals-and-sandbox --yolo`

## Available Skills

**Skills are referenced on-demand when you encounter the relevant step. Do not pre-read all skills upfront.**

**Support Skills** (read as needed when referenced):

- `validating-setup-commands` - Reference if CLAUDE.md setup validation needed (Step 1.1)
- `using-git-spice` - Reference for git-spice command syntax (as needed)
- `verification-before-completion` - Reference before claiming completion (Step 3)
- `finishing-a-development-branch` - Reference after all phases complete (Step 4)

## Input

User will provide: `codex-execute {plan-path}`

Example: `codex-execute specs/a1b2c3-magic-link-auth/plan.md`

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
# Extract RUN_ID and FEATURE_SLUG from plan path (replace {the-plan-path-user-provided} with actual path)
PLAN_PATH="{the-plan-path-user-provided}"
DIR_NAME=$(echo "$PLAN_PATH" | sed 's|^.*specs/||; s|/plan.md$||')
RUN_ID=$(echo "$DIR_NAME" | cut -d'-' -f1)
FEATURE_SLUG=$(echo "$DIR_NAME" | cut -d'-' -f2-)

echo "Extracted RUN_ID: $RUN_ID"
echo "Extracted FEATURE_SLUG: $FEATURE_SLUG"

# Verify RUN_ID and FEATURE_SLUG are not empty
if [ -z "$RUN_ID" ]; then
  echo "❌ Error: Could not extract RUN_ID from plan path: $PLAN_PATH"
  exit 1
fi

if [ -z "$FEATURE_SLUG" ]; then
  echo "❌ Error: Could not extract FEATURE_SLUG from plan path: $PLAN_PATH"
  exit 1
fi
```

**CRITICAL**: Execute this entire block as a single multi-line Bash tool call. The comment on the first line is REQUIRED - without it, command substitution `$(...)` causes parse errors.

**Store RUN_ID and FEATURE_SLUG for use in:**

- Branch naming: `{run-id}-task-X-Y-name`
- Filtering: `git branch | grep "^  {run-id}-"`
- Spec path: `specs/{run-id}-{feature-slug}/spec.md`
- Cleanup: Identify which branches/specs belong to this run

**Announce:** "Executing with RUN_ID: {run-id}, FEATURE_SLUG: {feature-slug}"

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

**Check if implementation work already exists:**

```bash
# Get repo root
REPO_ROOT=$(git rev-parse --show-toplevel)

# Check current branch in main worktree
CURRENT_BRANCH=$(git -C "$REPO_ROOT/.worktrees/${RUN_ID}-main" branch --show-current 2>/dev/null || echo "")

# Count existing task branches for this RUN_ID
EXISTING_TASKS=$(git branch 2>/dev/null | grep -c "^  ${RUN_ID}-task-" || echo "0")

# Report status
if [ "$EXISTING_TASKS" -gt 0 ]; then
  echo "📋 Found $EXISTING_TASKS existing task branch(es) for RUN_ID: $RUN_ID"
  echo "   Current branch: $CURRENT_BRANCH"
  echo ""
  echo "Resuming from current state. The execution will:"
  echo "- Sequential phases: Continue from current branch"
  echo "- Parallel phases: Skip completed tasks, run remaining"
  echo ""
else
  echo "✅ No existing work found - starting fresh execution"
  echo ""
fi
```

**CRITICAL**: Execute this entire block as a single multi-line Bash tool call. The comment on the first line is REQUIRED - without it, command substitution `$(...)` causes parse errors.

**Resume behavior:**
- If `EXISTING_TASKS > 0`: Execution continues from current state in main worktree
- If `EXISTING_TASKS = 0`: Execution starts from Phase 1, Task 1
- Main worktree current branch indicates progress (latest completed work)

**Note:** Orchestrator proceeds immediately to Step 1. MCP server handles resume by checking current branch and existing task branches.

### Step 1.1: Validate Setup Commands (REQUIRED)

**Use the `validating-setup-commands` skill:**

This skill validates that CLAUDE.md defines required setup commands BEFORE executing the plan. It provides clear error messages with examples if missing.

The skill will extract and return:
- `INSTALL_CMD` - Required dependency installation command
- `POSTINSTALL_CMD` - Optional post-install command (codegen, etc.)

Store these commands for reference (MCP server will handle actual installation).

### Step 1.2: Configure Code Review Frequency

**Determine when to run code reviews:**

```bash
# Check if REVIEW_FREQUENCY env var is set
echo "REVIEW_FREQUENCY=${REVIEW_FREQUENCY:-}"
```

**If not set, prompt user for preference:**

If `REVIEW_FREQUENCY` is empty, use AskUserQuestion tool to prompt:

```
Question: "How frequently should code reviews run during execution?"
Header: "Review Frequency"
Options:
  1. "After each phase"
     Description: "Run code review after every phase completes (safest - catches errors early, prevents compounding issues)"
  2. "Optimize automatically"
     Description: "Let Claude decide when to review based on phase risk/complexity (RECOMMENDED - balances speed and quality)"
  3. "Only at end"
     Description: "Skip per-phase reviews, run one review after all phases complete (faster, but errors may compound)"
  4. "Skip reviews"
     Description: "No automated code reviews (fastest, but requires manual review before merging)"
```

**Store user choice:**
- Option 1 → `REVIEW_FREQUENCY="per-phase"`
- Option 2 → `REVIEW_FREQUENCY="optimize"`
- Option 3 → `REVIEW_FREQUENCY="end-only"`
- Option 4 → `REVIEW_FREQUENCY="skip"`

**Announce decision:**
```
Code review frequency: {REVIEW_FREQUENCY}
```

**Note:** This setting will be passed to MCP server via environment variable.

### Step 2: Execute via MCP Server

**Call the `spectacular_execute` MCP tool with the plan path.**

**IMPORTANT:** The MCP server will parse the plan.md file internally. You only need to provide the path.

**Construct the plan path from extracted variables:**

Using the `RUN_ID` and `FEATURE_SLUG` you extracted in Step 0a, construct the absolute path to the plan.md file:

```bash
# Construct absolute path to plan.md in worktree
REPO_ROOT=$(git rev-parse --show-toplevel)
PLAN_PATH_FOR_MCP="${REPO_ROOT}/.worktrees/${RUN_ID}-main/specs/${RUN_ID}-${FEATURE_SLUG}/plan.md"
echo "Plan path for MCP: $PLAN_PATH_FOR_MCP"

# Verify the plan file exists before calling MCP tool
if [ ! -f "$PLAN_PATH_FOR_MCP" ]; then
  echo "❌ Error: Plan file not found at $PLAN_PATH_FOR_MCP"
  echo "Run /spectacular:plan first to create the plan."
  exit 1
fi
```

**Tool invocation:**

Call the `spectacular_execute` MCP tool with the absolute path:

```json
{
  "plan_path": "/absolute/path/to/.worktrees/{RUN_ID}-main/specs/{RUN_ID}-{FEATURE_SLUG}/plan.md",
  "base_branch": "main"
}
```

**CRITICAL:** Use the absolute path you constructed in the bash command above. Replace the placeholders with actual values.

**Example with actual values:**

If `REPO_ROOT=/Users/drewritter/projects/bignight.party`, `RUN_ID=0729be`, and `FEATURE_SLUG=mobile-optimizations`, call:

```json
{
  "plan_path": "/Users/drewritter/projects/bignight.party/.worktrees/0729be-main/specs/0729be-mobile-optimizations/plan.md",
  "base_branch": "main"
}
```

**Why absolute path?** The plan.md file lives in the worktree (`.worktrees/{runId}-main/specs/...`), not the main repo. The MCP server needs the full path to find it.

**The MCP server will:**
1. Parse plan.md to extract phases and tasks
2. Bootstrap skills (superpowers, spectacular)
3. Ensure `.worktrees/{run-id}-main` exists
4. Execute each phase according to strategy:
   - Sequential: Tasks run one-by-one in main worktree
   - Parallel: Each task gets isolated worktree, runs simultaneously
5. Spawn Codex CLI subagents with embedded skill instructions (using `codex run --dangerously-bypass-approvals-and-sandbox --yolo`)
6. Track completion via git branches
7. Run code reviews based on REVIEW_FREQUENCY environment variable
8. Stack branches linearly with git-spice

**Expected response:**

The tool will return immediately with:
- **run_id**: The run identifier (should match your runId)
- **status**: "started" (execution continues in background)

**Store the run_id** for use in Step 2.1 (status polling).

### Step 2.1: Poll Execution Status

**Poll the `subagent_status` MCP tool periodically to track progress.**

**Tool invocation:**

Call the `subagent_status` MCP tool with:

```json
{
  "run_id": "{run-id}"
}
```

**Example:**
```json
{
  "run_id": "0729be"
}
```

**Expected response:**

The tool returns execution status containing:
- **run_id**: The run identifier
- **status**: Current status ("running", "completed", or "failed")
- **phase**: Current phase number being executed
- **tasks**: Array of task statuses with:
  - **id**: Task identifier (e.g., "1-1", "2-3")
  - **status**: Task status ("pending", "running", "completed", or "failed")
  - **branch**: Git branch name (if task created a branch)
  - **started_at**: ISO timestamp when task started (if running/completed)
  - **completed_at**: ISO timestamp when task finished (if completed)
- **started_at**: ISO timestamp when execution started
- **completed_at**: ISO timestamp when execution finished (if completed/failed)
- **error**: Error message (if status is "failed")

**Display progress updates to user:**

```
Execution Status: Phase 2 of 5

✅ Task 1.1: Database schema (completed)
   Branch: abc123-task-1-1-schema

⏳ Task 2.1: API routes (running - started 5m ago)

📊 Progress: 1/8 tasks completed
```

**Poll frequency:**
- First minute: Every 10 seconds (fast startup)
- After 1 minute: Every 30 seconds
- Long-running tasks: Every 60 seconds

**Continue polling until status is "completed" or "failed".**

### Step 3: Verify Completion

After execution completes (`status: "completed"`):

**Use the `verification-before-completion` skill:**

This skill enforces verification BEFORE claiming work is done.

**Required verifications:**
```bash
# Navigate to main worktree
cd .worktrees/{run-id}-main

# Run verification commands (detected from CLAUDE.md/constitution)
# The verification-before-completion skill will guide you through this

# Return to main repo
cd ../..
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

✅ Tests passing
✅ Linting clean
✅ Build successful
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

**If MCP tool call fails:**

Check error response from spectacular_execute:
- `plan_path or plan must be provided`: Missing required argument
- `Plan file not found`: Invalid path or file doesn't exist
- `Invalid plan path`: Path doesn't match `specs/{runId}-{slug}/plan.md` format
- `runId mismatch`: plan_path runId doesn't match plan content
- Worktree errors: Verify `.worktrees/{run-id}-main` exists
- Subagent spawn errors: Check Codex CLI is installed and configured
- Git errors: Verify git-spice is installed and repo initialized

**If execution status shows "failed":**

```json
{
  "run_id": "{run-id}",
  "status": "failed",
  "error": "Task 2.3 failed: Tests did not pass",
  "phase": 2,
  "tasks": [...]
}
```

**Recovery options:**

1. **Resume from checkpoint**: Simply re-run the same execute command. MCP server auto-detects completed branches and skips them.

2. **Manual intervention**: Navigate to worktree, fix issue, commit, then resume:
   ```bash
   cd .worktrees/{run-id}-main
   # Fix the issue
   git add .
   git commit -m "Fix: {description}"
   cd ../..
   # Re-run execute command
   ```

3. **Abort and restart**: Remove failed branches, re-run from beginning:
   ```bash
   git branch | grep "{run-id}-task-" | xargs git branch -D
   # Re-run execute command
   ```

## Important Notes

- **MCP Server handles parsing** - Just pass plan_path, MCP server parses plan.md internally
- **MCP Server delegates, never executes** - This command orchestrates, MCP server spawns Codex subagents
- **Codex subagents own their operations** - Each task runs in isolated Codex CLI process with `--yolo` flag
- **Skill-driven execution** - MCP server embeds skill instructions in subagent prompts
- **Automatic orchestration** - MCP server reads plan strategies, executes accordingly
- **Git-spice stacking** - Sequential tasks stack linearly; parallel tasks branch from same base
- **No feature branch** - The stack of task branches IS the feature; never create empty branch upfront
- **Worktree isolation** - Parallel tasks run in separate worktrees
- **Git-based state** - Branches are source of truth for completion, not database
- **Context management** - Each task runs in isolated Codex CLI process to avoid token bloat
- **Constitution adherence** - All subagents follow project constitution
- **Quality gates** - Tests and linting after every task, code review based on REVIEW_FREQUENCY
- **Continuous commits** - Small, focused commits with [Task X.Y] markers throughout

Now execute the plan from: {plan-path}
