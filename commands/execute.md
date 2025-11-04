---
description: Execute implementation plan with automatic sequential/parallel orchestration using git-spice and worktrees
---

You are executing an implementation plan.

## Available Skills

**Skills are referenced on-demand when you encounter the relevant step. Do not pre-read all skills upfront.**

**Phase Execution** (read when you encounter the phase type):

- `executing-parallel-phase` - Mandatory workflow for parallel phases (Step 2)
- `executing-sequential-phase` - Mandatory workflow for sequential phases (Step 2)

**Support Skills** (read as needed when referenced):

- `understanding-cross-phase-stacking` - Reference before starting any phase (explains base branch inheritance)
- `validating-setup-commands` - Reference if CLAUDE.md setup validation needed (Step 1.5)
- `using-git-spice` - Reference for git-spice command syntax (as needed)
- `requesting-code-review` - Reference after each phase completes (Step 2)
- `verification-before-completion` - Reference before claiming completion (Step 3)
- `finishing-a-development-branch` - Reference after all phases complete (Step 4)
- `troubleshooting-execute` - Reference if execution fails (error recovery)
- `using-git-worktrees` - Reference if worktree issues occur (diagnostics)

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

**Note:** Orchestrator proceeds immediately to Step 1. Phase execution logic in Step 2 handles resume by checking current branch and existing task branches.

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
Files: - src/generator.ts - src/types.ts
Acceptance Criteria: - Import PromptService from prompts module - Replace manual prompt construction with PromptService.getCommitPrompt() - Update tests to mock PromptService - All tests pass
Dependencies: Task 4.1 (fallback logic removed)

````

Verify plan structure:
- ✅ Has phases with clear strategies
- ✅ All tasks have files specified
- ✅ All tasks have acceptance criteria
- ✅ Dependencies make sense

### Step 1.5: Validate Setup Commands (REQUIRED)

**Use the `validating-setup-commands` skill:**

This skill validates that CLAUDE.md defines required setup commands BEFORE creating worktrees. It provides clear error messages with examples if missing.

The skill will extract and return:
- `INSTALL_CMD` - Required dependency installation command
- `POSTINSTALL_CMD` - Optional post-install command (codegen, etc.)

Store these commands for use in dependency installation steps throughout execution.

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

**Note:** This setting applies to all phases in this execution. Phase skills check `REVIEW_FREQUENCY` to determine whether to run code review step.

### Step 2: Execute Phases

**If resuming:** Start from the incomplete phase/task identified in Step 0.

For each phase in the plan, execute based on strategy:

**Code Review Gates:** Phase execution skills check `REVIEW_FREQUENCY` (set in Step 1.7) to determine when to run code reviews:
- `per-phase`: Review after each phase before proceeding
- `optimize`: LLM decides whether to review based on phase risk/complexity
- `end-only`: Skip per-phase reviews, review once after all phases
- `skip`: No automated reviews (manual review required)

#### Cross-Phase Stacking

**Use the `understanding-cross-phase-stacking` skill:**

This skill explains how sequential and parallel phases automatically chain together through base branch inheritance. Key concepts:
- Main worktree tracks progress (current branch = latest completed work)
- Parallel phases inherit from current branch (not original base)
- Natural chaining creates linear stack across all phases

Read this skill before starting any new phase to understand how phases build on each other.

#### Sequential Phase Strategy

**Use the `executing-sequential-phase` skill:**

This skill provides the complete workflow for executing sequential phases. Key concepts:
- Execute tasks one-by-one in existing `{runid}-main` worktree
- Trust natural git-spice stacking (no manual `gs upstack onto`)
- Tasks build on each other cumulatively
- Stay on task branches for automatic stacking

The skill includes detailed subagent prompts, quality check sequences, and code review integration.

#### Parallel Phase Strategy

**Use the `executing-parallel-phase` skill:**

This skill provides the complete mandatory workflow for executing parallel phases. Key requirements:
- Create isolated worktrees for EACH task (even N=1)
- Install dependencies per worktree
- Spawn parallel subagents in single message
- Verify completion before stacking
- Stack branches linearly, then cleanup worktrees
- Code review after stacking

The skill includes the 8-step mandatory sequence, verification checks, N=1 edge case handling, and stacking algorithm.

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
````

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

````markdown
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
````

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

**Use the `troubleshooting-execute` skill:**

This skill provides comprehensive diagnostic and recovery strategies for execute command failures:
- Phase execution failures (sequential and parallel)
- Parallel agent failures with 4 recovery options
- Merge conflicts during stacking
- Worktree not found errors
- Parallel task worktree creation failures

The skill includes diagnostic commands, recovery strategies, and prevention guidelines.

Consult this skill when execution fails or produces unexpected results.

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
```
