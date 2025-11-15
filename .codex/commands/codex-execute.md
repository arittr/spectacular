---
description: Execute implementation plan via Codex MCP server with automatic parallel orchestration (Codex-only)
---

<!--
DUPLICATION NOTICE:
Steps 0a-1.7 (orchestration setup) are intentionally duplicated from commands/execute.md.
This duplication enables independent evolution of Codex and Claude Code execution paths.

If you update orchestration logic (Run ID extraction, plan parsing, validation, etc.),
check BOTH files:
- commands/execute.md (Claude Code - uses Task tool)
- .codex/commands/codex-execute.md (Codex - uses MCP tool)

The ONLY difference is Step 2:
- execute.md: Uses executing-parallel-phase and executing-sequential-phase skills with Task tool
- codex-execute.md: Calls spectacular_execute MCP tool and polls subagent_status

See CLAUDE.md "Codex-Specific Commands" section for architecture rationale.
-->

You are executing an implementation plan using the Codex MCP server.

## Architecture

**Execution Flow:**

1. **Orchestrator (This Command)**: Parses plan, validates setup, configures options
2. **MCP Server** (spectacular-codex): Receives structured plan object, spawns Codex CLI subagents
3. **Codex Subagents**: Execute tasks in isolated worktrees (parallel or sequential)
4. **Git State**: Branches track completion, worktrees provide isolation

**Key Difference from Claude Code:**

- Claude Code: Uses Task tool to spawn Claude subagents in same session
- Codex: Uses MCP tool to spawn separate Codex CLI processes with `--dangerously-bypass-approvals-and-sandbox --yolo`

## Available Skills

**Skills are referenced on-demand when you encounter the relevant step. Do not pre-read all skills upfront.**

**Support Skills** (read as needed when referenced):

- `validating-setup-commands` - Reference if CLAUDE.md setup validation needed (Step 1.5)
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

### Step 1: Read and Parse Plan

**Read the plan.md file:**

Use the Read tool to read the plan file at the path provided by the user.

**Parse the plan into a structured object using these steps:**

#### 1.1: Extract Header Information

From the plan markdown, extract:

```bash
# Extract title (first h1 heading)
# Pattern: # Implementation Plan: {title}
TITLE=$(grep -m 1 "^# " plan.md | sed 's/^# //')

# Extract runId (already have from Step 0a)
# Pattern: Run ID: {runId}

# Extract feature slug (already have from Step 0a, but verify)
# Pattern: Feature: {feature-slug}
FEATURE_SLUG=$(grep -m 1 "^Feature:" plan.md | sed 's/^Feature: *//')
```

#### 1.2: Parse Phases

Parse phases using this pattern:

**Phase header format:**
```
## Phase {N}: {Phase Name} (Parallel|Sequential)
```

**For each phase:**
1. Extract phase number (N)
2. Extract phase name
3. Extract strategy (Parallel or Sequential)
4. Extract all tasks within this phase (until next phase header or end of file)

**Example parsing logic:**

```python
import re

# Find all phase headers
phase_pattern = r'^##\s*Phase\s+(\d+)[\s:–-]+(.+?)\s*\((Parallel|Sequential)\)\s*$'
phases = []

for match in re.finditer(phase_pattern, plan_content, re.MULTILINE | re.IGNORECASE):
    phase_id = match.group(1)
    phase_name = match.group(2).strip()
    strategy = match.group(3).lower()  # "parallel" or "sequential"

    # Extract phase content (from this match to next phase or EOF)
    phase_start = match.end()
    # Parse tasks within this phase...
```

#### 1.3: Parse Tasks Within Each Phase

**Task header format:**
```
### Task {N}-{M}: {Task Name}
**Description:** {description}
**Files:**
- {file1}
- {file2}

**Acceptance Criteria:**
- {criterion1}
- {criterion2}

**Dependencies:** {task-id1}, {task-id2} | None
```

**For each task:**

1. **Extract task ID and name:**
   - Pattern: `### Task {N}-{M}: {Task Name}`
   - Task ID: `{N}-{M}` (e.g., "1-1", "2-3")
   - Task name: Everything after the colon

2. **Extract description:**
   - Pattern: `**Description:** {text}`
   - Single line after the header

3. **Extract files (list):**
   - Pattern: `**Files:**` followed by list items
   - List items start with `- ` or `* `
   - Capture until next section header (`**`)

4. **Extract acceptance criteria (list):**
   - Pattern: `**Acceptance Criteria:**` followed by list items
   - Same list parsing as files

5. **Extract dependencies:**
   - Pattern: `**Dependencies:** {text}`
   - Parse comma-separated task IDs
   - If "None", set to empty array

**Example parsing logic:**

```python
task_pattern = r'^###\s*Task\s+([\d.-]+)[\s:–-]+(.+)\s*$'

for task_match in re.finditer(task_pattern, phase_content, re.MULTILINE):
    task_id = task_match.group(1).replace('.', '-')  # Convert 1.1 to 1-1
    task_name = task_match.group(2).strip()

    # Extract task content (from this match to next task or EOF)
    task_content = get_task_content(phase_content, task_match)

    # Parse description
    desc_match = re.search(r'\*\*Description:\*\*\s*(.+)', task_content)
    description = desc_match.group(1).strip() if desc_match else ""

    # Parse files (list items after **Files:**)
    files = extract_list_items(task_content, 'Files')

    # Parse acceptance criteria
    acceptance_criteria = extract_list_items(task_content, 'Acceptance Criteria')

    # Parse dependencies
    deps_match = re.search(r'\*\*Dependencies:\*\*\s*(.+)', task_content)
    deps_raw = deps_match.group(1).strip() if deps_match else "None"
    dependencies = [] if deps_raw.lower() == 'none' else [d.strip() for d in deps_raw.split(',')]
```

**Helper function to extract list items:**

```python
def extract_list_items(content, section_name):
    items = []
    # Find section header and capture lines starting with - or *
    section_pattern = f'\\*\\*{section_name}:\\*\\*\\s*\\n([\\s\\S]*?)(?=\\n\\*\\*|$)'
    match = re.search(section_pattern, content)

    if match:
        list_content = match.group(1)
        # Extract list items
        for line in list_content.split('\n'):
            if line.strip().startswith(('-', '*')):
                item = line.strip()[1:].strip()  # Remove leading - or *
                if item:
                    items.append(item)

    return items
```

#### 1.4: Build Structured Plan Object

After parsing all phases and tasks, build this JSON structure:

```json
{
  "runId": "{run-id}",
  "featureSlug": "{feature-slug}",
  "title": "{title}",
  "phases": [
    {
      "id": 1,
      "name": "Foundation",
      "strategy": "sequential",
      "tasks": [
        {
          "id": "1-1",
          "name": "Database Schema",
          "description": "Create user and session tables with Prisma",
          "files": ["prisma/schema.prisma", "prisma/migrations/001_init.sql"],
          "acceptanceCriteria": [
            "User table with id, email, created_at",
            "Session table with id, user_id, token",
            "Migration runs successfully"
          ],
          "dependencies": []
        },
        {
          "id": "1-2",
          "name": "Authentication Service",
          "description": "Implement JWT-based authentication",
          "files": ["src/auth/service.ts", "src/auth/types.ts"],
          "acceptanceCriteria": [
            "generateToken() creates valid JWT",
            "verifyToken() validates tokens",
            "Tests pass"
          ],
          "dependencies": ["1-1"]
        }
      ]
    },
    {
      "id": 2,
      "name": "API Routes",
      "strategy": "parallel",
      "tasks": [...]
    }
  ]
}
```

**Verify plan structure:**
- ✅ Has phases with clear strategies
- ✅ All tasks have files specified
- ✅ All tasks have acceptance criteria
- ✅ Dependencies reference valid task IDs
- ✅ Parallel phases have independent tasks (no circular dependencies)

**Store this structured object** - you will pass it to the MCP tool in Step 2.

### Step 1.5: Validate Setup Commands (REQUIRED)

**Use the `validating-setup-commands` skill:**

This skill validates that CLAUDE.md defines required setup commands BEFORE creating worktrees. It provides clear error messages with examples if missing.

The skill will extract and return:
- `INSTALL_CMD` - Required dependency installation command
- `POSTINSTALL_CMD` - Optional post-install command (codegen, etc.)

Store these commands for reference (MCP server will handle actual installation).

### Step 1.6: Detect Project Commands (Optional)

**Optionally detect project-specific quality check commands.**

**This is optional - most projects define commands in CLAUDE.md that the MCP server can discover.**

If you want to provide hints, check for common patterns:
- **TypeScript/JavaScript**: `package.json` scripts
- **Python**: `pytest`, `ruff`, `black`
- **Go**: `go test`, `golangci-lint`
- **Rust**: `cargo test`, `cargo clippy`

**If detected, mention in final report:**
- `TEST_CMD` - Command to run tests
- `LINT_CMD` - Command to run linting
- `FORMAT_CMD` - Command to format code
- `BUILD_CMD` - Command to build project

**IMPORTANT: Do NOT read constitution files here. Let MCP server handle quality checks to reduce token usage.**

### Step 1.7: Configure Code Review Frequency

**Determine when to run code reviews:**

```bash
# Check if REVIEW_FREQUENCY env var is set
REVIEW_FREQUENCY=${REVIEW_FREQUENCY:-}
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

**Note:** This setting will be passed to MCP server via environment variable or plan metadata.

### Step 2: Execute via MCP Server

**Call the `spectacular_execute` MCP tool with the structured plan object you built in Step 1.**

**CRITICAL:** The MCP server does NOT parse plan.md. You must pass the fully structured plan object from Step 1.4.

**Tool invocation:**

Use the `spectacular_execute` MCP tool (configured in `~/.codex/mcp-servers.json`) with these arguments:

- **plan** (required): The structured plan object from Step 1.4 containing:
  - `runId`: The 6-character hex run ID
  - `featureSlug`: The feature slug (e.g., "magic-link-auth")
  - `title`: The plan title
  - `phases`: Array of phase objects with tasks

- **base_branch** (optional): The base branch for worktree creation (defaults to "main")

**Example invocation:**

```
Call the spectacular_execute MCP tool with:
- plan: <the structured plan object from Step 1.4>
- base_branch: "main"
```

**The MCP server will:**
1. Bootstrap skills (superpowers, spectacular)
2. Ensure `.worktrees/{run-id}-main` exists
3. Execute each phase according to strategy:
   - Sequential: Tasks run one-by-one in main worktree
   - Parallel: Each task gets isolated worktree, runs simultaneously
4. Spawn Codex CLI subagents with embedded skill instructions (using `codex run --dangerously-bypass-approvals-and-sandbox --yolo`)
5. Track completion via git branches
6. Run code reviews based on REVIEW_FREQUENCY environment variable
7. Stack branches linearly with git-spice

**Expected response:**

The tool will return immediately with:
- **run_id**: The run identifier (should match your runId)
- **status**: "started" (execution continues in background)

**Store the run_id** for use in Step 2.1 (status polling).

### Step 2.1: Poll Execution Status

**Poll the `subagent_status` MCP tool periodically to track progress.**

**Tool invocation:**

Use the `subagent_status` MCP tool with:
- **run_id**: The run_id returned from `spectacular_execute` in Step 2

**Example:**
```
Call the subagent_status MCP tool with:
- run_id: "{run-id}"
```

**Expected response:**

The tool returns execution status containing:
- **run_id**: The run identifier
- **status**: Current status ("running", "completed", or "failed")
- **phase**: Current phase number being executed
- **total_phases**: Total number of phases in the plan
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

**Required verifications (if commands detected):**
```bash
# Navigate to main worktree
cd .worktrees/{run-id}-main

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

# Return to main repo
cd ../..
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

**If MCP tool call fails:**

Check error response from spectacular_execute:
- Plan validation errors: Fix plan structure, retry
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

1. **Retry failed task**: Call `spectacular_execute` with `tasks` filter:
   ```json
   {
     "tool": "spectacular_execute",
     "plan": {...},
     "tasks": [{ "id": "2.3" }]
   }
   ```

2. **Resume from checkpoint**: MCP server auto-detects completed branches, skips them

3. **Manual intervention**: Navigate to worktree, fix issue, commit, then resume

4. **Abort and restart**: Remove failed branches, re-run from beginning

## Important Notes

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
