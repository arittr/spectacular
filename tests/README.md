# Testing Spectacular

## Overview

This document describes how to test spectacular commands and skills using the built-in testing system.

**Core philosophy:** Spectacular uses Test-Driven Development (TDD) for process documentation. Just as you wouldn't deploy code without tests, you shouldn't deploy commands/skills without verifying they work under realistic pressure.

**What gets tested:**

- **Commands** (`commands/*.md`) - Orchestration workflows like `/spectacular:spec`, `/spectacular:plan`, `/spectacular:execute`
- **Skills** (`skills/*/SKILL.md`) - Process documentation that commands reference
- **Integration** - How commands + skills work together in real projects

**Why testing is critical:**

- Commands orchestrate complex git-spice and worktree operations
- Skills must resist Claude's natural tendency to rationalize away inconvenient rules
- Failures under pressure (time constraints, coordination load) are hard to predict without testing

## Running Tests

### Quick Start

Ask Claude to run the test suite:

```
# Test specific command
"Run the test suite for execute command"
"Run the test suite for init command"
"Run the test suite for spec command"
"Run the test suite for plan command"

# Test everything
"Run the full test suite"
```

Claude will automatically:

1. Discover scenarios (e.g., 19 for execute)
2. Create timestamped results directory
3. Dispatch subagents in batches of 10 (respects rate limits)
4. Track progress with TodoWrite
5. Aggregate results with `./tests/aggregate-results.sh`
6. Report pass/fail summary

### Detailed Workflow

**Step 1: Scenario Discovery**

Claude finds all matching scenario files:

```bash
# For specific command
COMMAND="execute"
SCENARIO_FILES=$(find tests/scenarios/$COMMAND -name "*.md" -type f ! -name "README.md" | sort)

# For all commands
SCENARIO_FILES=$(find tests/scenarios -name "*.md" -type f ! -name "README.md" | sort)

# Count and display
SCENARIO_COUNT=$(echo "$SCENARIO_FILES" | wc -l | tr -d ' ')
echo "Found $SCENARIO_COUNT scenarios"
```

**Step 2: Results Directory Creation**

```bash
TIMESTAMP=$(date +%Y-%m-%dT%H%M%S)
RESULTS_DIR="tests/results/$TIMESTAMP"

mkdir -p "$RESULTS_DIR/scenarios"
mkdir -p "$RESULTS_DIR/evidence/skill-excerpts"
mkdir -p "$RESULTS_DIR/evidence/verification-outputs"

# Create symlink for easy access
ln -sfn "$TIMESTAMP" tests/results/latest
```

**Step 3: Batched Subagent Dispatch**

**CRITICAL:** Max 10 concurrent subagents to respect rate limits.

```bash
BATCH_SIZE=10
BATCH_COUNT=$(( (SCENARIO_COUNT + BATCH_SIZE - 1) / BATCH_SIZE ))

# Example: 19 scenarios = 2 batches
# Batch 1: Scenarios 1-10
# Batch 2: Scenarios 11-19
```

Claude creates todos for each batch and dispatches them sequentially:

1. Mark batch 1 `in_progress`
2. Dispatch 10 subagents in SINGLE message (parallel within batch)
3. Wait for batch completion
4. Mark batch 1 `completed`
5. Repeat for batch 2

**Each subagent receives:**

```markdown
You are testing spectacular implementation against a test scenario.

**SCENARIO FILE:** {scenario_file_path}
**LOG FILE:** {RESULTS_DIR}/scenarios/{scenario-name}.log

## Your Task

1. Read the scenario file
2. Execute Verification Commands (if present)
3. Verify implementation matches expectations
4. Report PASS or FAIL with evidence
5. Save complete analysis to LOG FILE

## Evidence Requirements

**MANDATORY for every verdict:**

1. **Binary Verdict**: ✅ PASS or ❌ FAIL
2. **File Locations**: Exact paths with line numbers
3. **Verification Commands**: Show what you ran and output
4. **Rationale**: Quote scenario requirements

**Invalid verdicts:**

- "This seems fine" (no evidence)
- "Close enough" (binary required)
- "Documentation issue not functional bug" (still FAIL)
- "Mostly works except..." (passes or fails)
```

**Step 4: Results Aggregation**

After all batches complete:

```bash
./tests/aggregate-results.sh "$RESULTS_DIR"
```

This counts PASS/FAIL from logs and generates `summary.md`.

**Step 5: Reporting**

Claude shows summary with actionable next steps:

```
=========================================
Test Results
=========================================

✅ PASS: bash-pattern-consistency
❌ FAIL: orchestrator-location-discipline
✅ PASS: code-review-binary-enforcement
...

Results: 18/19 passed (94.7%)

❌ 1 scenario(s) failed:
- orchestrator-location-discipline

Review evidence:
- Log: tests/results/latest/scenarios/orchestrator-location-discipline.log
- Summary: tests/results/latest/summary.md

Fix implementation and re-run tests.
```

### Results Storage

**Git tracking policy:**

```
tests/results/
├── .gitignore              # Configured policy
├── latest/                 # Symlink (git-ignored)
└── {timestamp}/
    ├── summary.md          # Committed (trends)
    ├── scenarios/*.log     # Git-ignored (local-only)
    └── evidence/           # Git-ignored
```

**What's committed:**

- ✅ `summary.md` files - Track pass/fail trends
- ✅ `.gitignore` - Exclude detailed logs

**What's git-ignored:**

- ❌ `*.log` files - Detailed logs (local review only)
- ❌ `evidence/` - Test artifacts
- ❌ `latest/` - Local symlink

**Accessing results:**

```bash
# View most recent test run
cat tests/results/latest/summary.md

# View specific scenario log
cat tests/results/latest/scenarios/orchestrator-location-discipline.log

# Compare trends over time
ls tests/results/*/summary.md | xargs grep "Results:"
```

## Test Structure

### Test Fixtures (`tests/fixtures/`)

Minimal project templates for testing commands in isolation:

- **simple-typescript/** - Node.js/TypeScript project with Jest tests
- **simple-python/** - Python project with pytest tests

**What fixtures provide:**

- Valid git repository with git-spice initialized
- Setup commands defined in CLAUDE.md (install, postinstall)
- Quality check commands (test, lint, format, build)
- Working tests (all passing)

**Initialization required:**

```bash
# First time setup (creates .git repos + git-spice)
cd tests/fixtures
./init-fixtures.sh

# Validate fixtures are ready
./validate-fixtures.sh
```

See [tests/fixtures/README.md](tests/fixtures/README.md) for details.

### Test Scenarios (`tests/scenarios/`)

Each scenario documents:

- **Context** - Setup and preconditions
- **Expected Behavior** - What should happen when command executes correctly
- **Failure Modes** - Common mistakes and how to detect them
- **Success Criteria** - Checklist for verification

**Scenario organization:**

```
tests/scenarios/
├── execute/           # Execute command scenarios
│   ├── parallel-stacking-2-tasks.md
│   ├── parallel-stacking-3-tasks.md
│   ├── sequential-stacking.md
│   └── worktree-creation.md
├── init/              # Init command scenarios
├── plan/              # Plan command scenarios
├── spec/              # Spec command scenarios
└── test/              # Test command scenarios (meta!)
```

**Example scenario structure:**

```markdown
# Test Scenario: Parallel Stacking (2 Tasks)

## Context

Testing `/spectacular:execute` with 2 independent parallel tasks.

## Expected Behavior

1. Create isolated worktrees from main repo
2. Execute tasks in parallel
3. Stack branches linearly

## Failure Modes

- Nested worktree creation
- Temporary branch pollution
- Wrong stacking context

## Success Criteria

- [ ] Worktrees created correctly
- [ ] Branches stacked linearly
- [ ] No temporary branches
```

## Adding Test Scenarios

### When to Add a Scenario

Add test scenarios when:

- Creating new commands (before implementation)
- Finding bugs in existing commands (before fixing)
- Observing failures in real execution (document as RED phase)
- Testing edge cases not covered by existing scenarios

### Standard Scenario Structure

Create scenarios using this template:

````markdown
# Test Scenario: {Short Description}

## Context

**Testing:** `/spectacular:{command}` with {specific conditions}

**Setup:**

- {Precondition 1}
- {Precondition 2}

**Why this scenario:**

- {Reason this case is important}

## Expected Behavior

### {Phase 1 Name}

1. {Step 1 description with example commands}
   ```bash
   # Example command
   command --with flags
   ```
````

2. {Step 2 description}

### {Phase 2 Name}

{Continue with each phase...}

### Final State

```
{Show expected git structure, branch layout, or file state}
```

## Failure Modes

### Issue 1: {Failure Name}

**Symptom:**

```
{Error message or wrong behavior}
```

**Root Cause:** {Explanation of what went wrong}

**Reference:** {Link to analysis document if available}

**Detection:**

```bash
# Command to detect this failure
check-command
```

## Success Criteria

### {Category 1}

- [ ] {Specific verifiable criterion}
- [ ] {Another criterion}

### {Category 2}

- [ ] {More criteria}

## Test Execution

**Using:** `testing-spectacular` skill (for commands) or `testing-skills-with-subagents` (for skills)

**Command:**

```bash
# How to manually run this scenario
{command}
```

**Validation:**

```bash
# Commands to verify success
{validation commands}
```

## Related Scenarios

- **{scenario-name}.md** - {Brief description}

````

### Example: Adding an Execute Scenario

```bash
cd tests/scenarios/execute

# Create new scenario file
cat > resume-interrupted-execution.md << 'EOF'
# Test Scenario: Resume Interrupted Execution

## Context

Testing `/spectacular:execute` when previous execution was interrupted mid-phase.

**Setup:**
- Feature spec with 2 phases exists
- Phase 1 completed successfully
- Phase 2 started but interrupted (1 of 3 tasks done)
- Worktrees still exist from interrupted run

**Why this scenario:**
- Users need ability to resume work after interruptions
- Worktree state may be inconsistent
- Some branches may already exist

## Expected Behavior

### Verification Phase

1. Orchestrator detects existing work:
   ```bash
   git branch | grep {runid}
   git worktree list
````

2. Identifies which tasks completed:

   - Checks for branches: `{runid}-task-2-{N}-{name}`
   - Verifies commits exist on those branches

3. Asks user: "Phase 2 partially complete. Resume from task 2?"

### Resume Execution

1. Cleanup stale worktrees from interrupted run
2. Create worktrees only for remaining tasks
3. Execute remaining tasks
4. Stack ALL phase 2 branches (completed + new)

### Final State

```
gs ls output:
{runid}-task-1-1-setup
└─□ {runid}-task-2-1-completed-before-interrupt
   └─□ {runid}-task-2-2-completed-before-interrupt
      └─□ {runid}-task-2-3-completed-after-resume
```

## Failure Modes

### Issue 1: Rerunning Completed Tasks

**Symptom:** Orchestrator recreates branches that already exist

**Root Cause:** No verification of existing work before starting

**Detection:**

```bash
# Check for duplicate branches
git branch | grep {runid}-task-2-1 | wc -l  # Should be 1, not 2
```

### Issue 2: Stale Worktree Conflicts

**Symptom:** "worktree already exists" error

**Root Cause:** Didn't clean up worktrees from interrupted run

**Detection:**

```bash
git worktree list  # Should not show stale worktrees
```

## Success Criteria

### Verification

- [ ] Detects existing completed tasks
- [ ] Prompts user before proceeding
- [ ] Doesn't attempt to recreate existing work

### Cleanup

- [ ] Removes stale worktrees before resume
- [ ] Doesn't delete completed task branches

### Execution

- [ ] Only creates worktrees for remaining tasks
- [ ] Executes remaining tasks successfully

### Stacking

- [ ] Stacks ALL phase 2 branches (old + new)
- [ ] Final stack is linear and complete

## Test Execution

**Using:** `testing-spectacular` skill

**Command:**

```bash
# In test repository:
/spectacular:execute
# Wait until Phase 2 starts, then interrupt (Ctrl+C)
# Run again:
/spectacular:execute
# Verify resume behavior
```

**Validation:**

```bash
gs ls  # Verify complete stack
git worktree list  # Verify no stale worktrees
git branch | grep {runid}  # Verify no duplicate branches
```

## Related Scenarios

- **parallel-stacking-3-tasks.md** - Normal 3-task parallel execution
- **cleanup-tmp-branches.md** - Cleanup logic for temporary branches
  EOF

````

## Test Fixtures

### What Fixtures Exist

**simple-typescript/** - TypeScript/Node.js project
- Language: TypeScript + Node.js
- Test framework: Jest
- Tools: ESLint, Prettier
- Code: Simple arithmetic functions (add, subtract, multiply, divide)
- Tests: 6 passing tests
- Setup time: ~12 seconds

**simple-python/** - Python project
- Language: Python 3.x
- Test framework: pytest
- Tools: ruff (lint), black (format)
- Code: Simple arithmetic functions
- Tests: 5 passing tests
- Setup time: ~6 seconds

### When to Use Which Fixture

Use **simple-typescript** for:
- Testing Node.js/TypeScript-specific behavior
- Testing npm install + postinstall workflows
- Testing codegen patterns (if you add Prisma/GraphQL)

Use **simple-python** for:
- Testing Python-specific behavior
- Testing pip install workflows
- Testing Python-specific tooling integration

### Adding New Fixtures

**Only add fixtures for language-specific testing needs.**

Most scenarios should use existing fixtures. Add new fixtures when:
- Testing language-specific spectacular behavior
- Existing fixtures can't represent the scenario
- New tech stack needs validation

**Steps:**

1. Create minimal project:
   ```bash
   mkdir tests/fixtures/simple-{language}
   cd tests/fixtures/simple-{language}

   # Add minimal code (1-2 functions)
   # Add working tests (5-10 tests)
   # Add CLAUDE.md with setup + quality commands
   # Add .gitignore
````

2. Initialize git + git-spice:

   ```bash
   cd tests/fixtures
   ./init-fixtures.sh
   ```

3. Validate:
   ```bash
   ./validate-fixtures.sh
   ```

**Requirements:**

- Setup completes in <1 minute
- All tests pass out of the box
- CLAUDE.md defines: install, test, lint, format, build
- Minimal dependencies (<20 packages)

## Testing Workflow

### When to Run Tests

**Before releases:**

- Run all spectacular test scenarios to verify nothing broke
- Test commands manually in sample projects
- Verify version consistency with `./scripts/update-version.sh`

**After finding bugs:**

1. Document bug as test scenario (RED phase)
2. Fix the bug in command/skill (GREEN phase)
3. Run test to verify fix (REFACTOR phase)

**When editing commands:**

1. Read existing scenarios for that command
2. Make changes to command file
3. Run the testing workflow for that command to verify
4. Add new scenarios for edge cases you discover

**When creating skills:**

1. Use `testing-skills-with-subagents` skill (RED phase)
2. Create skill with `writing-skills` skill (GREEN phase)
3. Re-test with `testing-skills-with-subagents` (REFACTOR phase)
4. Iterate until bulletproof

See [.claude/skills/testing-spectacular.md](.claude/skills/testing-spectacular.md) for detailed methodology.

### RED-GREEN-REFACTOR for Commands

**Commands use TDD just like code:**

#### RED Phase: Find Real Failure

1. Look for failures in git logs or execution transcripts
2. Document evidence:

   - Run ID where failure occurred
   - Branch names, error messages, wrong state
   - What the orchestrator did wrong

3. Create test scenario documenting the failure
4. Reproduce in test fixture

**Example RED evidence:**

```
Run ID: 9f92a8
Failure: Nested worktree creation
Evidence: .worktrees/9f92a8-main/.worktrees/9f92a8-task-1
Root cause: Orchestrator in wrong directory when creating worktrees
```

#### GREEN Phase: Fix Instructions

1. Analyze root cause from RED phase
2. Update command file with:

   - Explicit commands (not just delegation)
   - Context verification upfront
   - Consequences stated immediately
   - Cleanup order specified

3. Test fix manually in fixture

**Example GREEN fix:**

````markdown
**CRITICAL: Verify you are in main repo before creating worktrees.**

```bash
REPO_ROOT=$(git rev-parse --show-toplevel)
if [ "$(pwd)" != "$REPO_ROOT" ]; then
  echo "ERROR: Must run from main repo"
  exit 1
fi
```
````

If you run from worktree, you'll create nested worktrees that fail.

````

#### REFACTOR Phase: Test Edge Cases

1. Run test scenarios covering:
   - Different phase types (sequential vs parallel)
   - Different task counts (2, 3, 5 tasks)
   - Edge cases (resume, cleanup, errors)

2. Document remaining issues
3. Improve clarity
4. Re-verify all scenarios pass

### RED-GREEN-REFACTOR for Skills

**Skills must resist rationalization under pressure.**

See [docs/constitutions/current/testing.md](docs/constitutions/current/testing.md) for complete testing requirements.

**Key differences from command testing:**
- Use `testing-skills-with-subagents` metaskill
- Create pressure scenarios (time, coordination, simple-seeming tasks)
- Observe what shortcuts Claude takes under pressure
- Add rationalization tables based on OBSERVED behavior
- Require TodoWrite for sequential steps

**Process:**

```bash
# RED: Run without skill, observe failures
Use testing-skills-with-subagents with pressure scenario (no skill)

# GREEN: Write skill targeting observed failures
Use writing-skills metaskill to create skill

# REFACTOR: Verify skill prevents shortcuts
Use testing-skills-with-subagents with same scenario (with skill)
````

## Troubleshooting

### "Test fixtures not found"

**Cause:** Fixtures not initialized with git

**Fix:**

```bash
cd tests/fixtures
./init-fixtures.sh
```

### "No scenarios found for command: X"

**Cause:** Either:

1. Typo in command name
2. No scenarios exist yet for that command

**Fix:**

```bash
# Check available commands
ls tests/scenarios/

# If no scenarios exist, create them (see "Adding Test Scenarios")
```

### "fatal: not a git repository" in fixture

**Cause:** Fixture's `.git` directory wasn't created

**Fix:**

```bash
cd tests/fixtures
./init-fixtures.sh
./validate-fixtures.sh  # Verify all checks pass
```

### "gs: command not found"

**Cause:** git-spice not installed

**Fix:**

```bash
# Install git-spice
# See: https://github.com/abhinav/git-spice

# Or run /spectacular:init to check all dependencies
/spectacular:init
```

### Scenario verification fails

**Debugging steps:**

1. Read scenario file to understand expected behavior
2. Compare actual state with Success Criteria
3. Check for Failure Modes documented in scenario
4. Look for git state inconsistencies:

   ```bash
   git branch | grep {runid}  # Check branches
   git worktree list          # Check worktrees
   gs ls                      # Check stack structure
   ```

5. If bug found, document as new RED phase scenario

### Testing takes too long

**If fixtures setup is slow (>1 minute):**

1. Check network connectivity
2. Verify package caching is working:

   ```bash
   cd tests/fixtures/simple-typescript
   time npm install  # Should be <15 seconds
   ```

3. If consistently slow, dependencies may need pruning

**If scenario execution is slow:**

Scenarios should complete in minutes, not hours. If slow:

1. Verify commands are running from correct directories
2. Check for unnecessary retries or experimentation
3. Review orchestrator instructions for clarity

## Additional Resources

**Skills:**

- [.claude/skills/testing-spectacular.md](.claude/skills/testing-spectacular.md) - Testing commands with RED-GREEN-REFACTOR
- [skills/testing-skills-with-subagents/](https://github.com/obra/superpowers) - Testing skills under pressure (from superpowers)

**Constitutions:**

- [docs/constitutions/current/testing.md](docs/constitutions/current/testing.md) - Testing philosophy and requirements
- [docs/constitutions/current/patterns.md](docs/constitutions/current/patterns.md) - Mandatory patterns including RED-GREEN-REFACTOR

**Examples:**

- [tests/scenarios/execute/](tests/scenarios/execute/) - Example scenarios for execute command
- [tests/fixtures/](tests/fixtures/) - Example fixtures (simple-typescript, simple-python)

## Summary

**Testing checklist:**

- [ ] Run all spectacular test scenarios before releases
- [ ] Add test scenarios when finding bugs (RED phase)
- [ ] Use RED-GREEN-REFACTOR for all command/skill development
- [ ] Test fixtures initialized and validated
- [ ] Scenarios cover common + edge cases
- [ ] Evidence-based testing (real failures, not hypothetical)

**The bottom line:**

Spectacular orchestrates complex git workflows (worktrees + git-spice + parallel execution). Testing isn't optional - it's how you verify instructions are clear enough for Claude to execute correctly under realistic pressure.

If you wouldn't deploy code without tests, don't deploy spectacular commands without scenarios.
