# Behavioral Tests for Spectacular

## Overview

These tests execute actual spectacular commands and verify observable behavior, not just documentation.

## Architecture

### Test Structure

```
tests/behavioral/
├── README.md                    # This file
├── fixtures/                    # Reusable test data
│   ├── simple-feature/         # Minimal plan for basic tests
│   │   ├── spec.md
│   │   ├── plan.md
│   │   └── CLAUDE.md
│   └── scope-creep/            # Plan that triggers scope violations
│       ├── spec.md
│       ├── plan.md
│       └── CLAUDE.md
├── harness/                     # Test execution framework
│   ├── setup-test-repo.sh      # Creates isolated git repo for test
│   ├── mock-subagent.sh        # Simulates subagent responses
│   └── verify-behavior.sh      # Common assertions
└── scenarios/                   # Actual behavioral tests
    ├── test-phase-scope-enforcement.sh
    ├── test-autonomous-fix-loop.sh
    └── test-parallel-execution.sh
```

### How Behavioral Tests Work

**1. Setup Phase**
```bash
# Create isolated git repo
setup-test-repo "test-scope-enforcement"

# Copy fixture plan/spec
cp fixtures/scope-creep/* $TEST_REPO/specs/abc123-test/

# Initialize git-spice
git -C $TEST_REPO gs repo init
```

**2. Execution Phase**
```bash
# Actually run the command
cd $TEST_REPO
/spectacular:execute @specs/abc123-test/plan.md
```

**3. Observation Phase**
```bash
# Capture what happened
TOOL_CALLS=$(parse-claude-output | grep "⏺")
BRANCHES=$(git branch | grep "abc123-task-")
COMMITS=$(git log --oneline)
```

**4. Assertion Phase**
```bash
# Verify behavior
assert_no_user_prompts "$TOOL_CALLS"
assert_branch_exists "abc123-task-2-1-contracts"
assert_fix_loop_executed "$TOOL_CALLS"
```

## Key Innovation: Observable Behavior

We test **what users see**, not internal implementation:

### Observable 1: Tool Calls
```bash
# Parse Claude output for tool invocations
⏺ Task(Implement task 2.1)           # ✅ Expected
⏺ AskUserQuestion(Scope Decision)   # ❌ FAIL - should never ask user
⏺ Skill(requesting-code-review)     # ✅ Expected
```

### Observable 2: Git State
```bash
# What branches exist?
git branch | grep "abc123-task-"

# What's the stack structure?
git log --graph --oneline --all

# Where is main worktree?
git -C .worktrees/abc123-main branch --show-current
```

### Observable 3: File System
```bash
# Were worktrees created?
ls -d .worktrees/abc123-task-*

# Were they cleaned up?
git worktree list | grep "task-" | wc -l  # Should be 0 after completion
```

### Observable 4: Process Output
```bash
# What did orchestrator say?
grep "Code review REJECTED" output.log
grep "Dispatching fix subagent" output.log
grep "APPROVED" output.log
```

## Test Scenarios

### 1. Phase Scope Enforcement (Your Bug!)

**Test:** `test-phase-scope-enforcement.sh`

**Setup:**
- 4-phase plan (schema → contracts → service → routing)
- Spec describes all 4 phases
- Mock subagent that implements Phase 2 + Phase 3 (scope creep)

**Execute:**
```bash
/spectacular:execute @specs/abc123-test/plan.md
```

**Observe & Assert:**
```bash
# 1. Phase 2 subagent dispatched
assert_tool_called "Task" "Implement Task 2.1"

# 2. Code review triggered
assert_tool_called "Skill" "requesting-code-review"

# 3. Review rejects with scope creep
assert_output_contains "Scope creep - implemented Phase 3 work"
assert_output_contains "Ready to merge? No"

# 4. Fix subagent dispatched (NOT user prompt)
assert_tool_called "Task" "Fix Phase 2 code review issues"
assert_tool_NOT_called "AskUserQuestion"

# 5. Fix subagent receives plan path
assert_fix_prompt_contains "Read implementation plan: specs/abc123-test/plan.md"

# 6. Re-review triggered
assert_output_contains "Re-reviewing Phase 2 after fixes"

# 7. Eventually approves
assert_output_contains "Ready to merge? Yes"

# PASS CRITERIA: Zero user prompts, scope creep fixed autonomously
```

### 2. Autonomous Fix Loop

**Test:** `test-autonomous-fix-loop.sh`

**Setup:**
- Simple plan (1 phase, 1 task)
- Mock subagent that produces code review failure
- Mock fix subagent that fixes issues

**Execute & Observe:**
```bash
# 1. Task completes
assert_branch_exists "abc123-task-1-1-schema"

# 2. Review rejects
assert_output_contains "Ready to merge? No"

# 3. Fix loop (NO user interaction)
assert_tool_NOT_called "AskUserQuestion"
assert_tool_called "Task" "Fix Phase 1 code review issues"

# 4. Re-review
assert_output_contains "Re-reviewing Phase 1"

# 5. Approval
assert_output_contains "Ready to merge? Yes"
assert_output_contains "Phase 1 complete"
```

### 3. Parallel Execution

**Test:** `test-parallel-execution.sh`

**Setup:**
- Plan with 1 parallel phase (4 tasks)
- Mock subagents that complete successfully

**Execute & Observe:**
```bash
# 1. Worktrees created
assert_dir_exists ".worktrees/abc123-task-1"
assert_dir_exists ".worktrees/abc123-task-2"
assert_dir_exists ".worktrees/abc123-task-3"
assert_dir_exists ".worktrees/abc123-task-4"

# 2. All tasks dispatched in parallel (single message with 4 Task calls)
TASK_CALLS=$(grep -c "⏺ Task(Implement Task" output.log)
assert_equals "$TASK_CALLS" "4"

# 3. All branches created
assert_branch_exists "abc123-task-1-1-ui-component"
assert_branch_exists "abc123-task-1-2-validation"
assert_branch_exists "abc123-task-1-3-styling"
assert_branch_exists "abc123-task-1-4-tests"

# 4. Linear stack (task-1 → task-2 → task-3 → task-4)
assert_stack_order "abc123-task-1-1" "abc123-task-1-2" "abc123-task-1-3" "abc123-task-1-4"

# 5. Worktrees cleaned up
assert_worktree_count 1  # Only main worktree remains
```

## Implementation Strategy

### Phase 1: Test Harness (Foundation)

**File:** `tests/behavioral/harness/setup-test-repo.sh`
```bash
#!/bin/bash
setup_test_repo() {
  TEST_NAME=$1
  TEST_DIR="/tmp/spectacular-test-$TEST_NAME-$$"

  # Create isolated repo
  mkdir -p "$TEST_DIR"
  cd "$TEST_DIR"
  git init
  git config user.email "test@spectacular.dev"
  git config user.name "Test"

  # Initial commit
  echo "# Test Repo" > README.md
  git add README.md
  git commit -m "Initial commit"

  # Create main branch
  git branch -M main

  # Initialize git-spice
  gs repo init

  echo "$TEST_DIR"
}
```

**File:** `tests/behavioral/harness/verify-behavior.sh`
```bash
#!/bin/bash

assert_tool_called() {
  TOOL=$1
  DESCRIPTION=$2
  if ! grep -q "⏺ $TOOL($DESCRIPTION)" "$OUTPUT_FILE"; then
    echo "❌ FAIL: Expected tool call: $TOOL($DESCRIPTION)"
    exit 1
  fi
}

assert_tool_NOT_called() {
  TOOL=$1
  if grep -q "⏺ $TOOL" "$OUTPUT_FILE"; then
    echo "❌ FAIL: Unexpected tool call: $TOOL"
    exit 1
  fi
}

assert_branch_exists() {
  BRANCH=$1
  if ! git rev-parse --verify "$BRANCH" >/dev/null 2>&1; then
    echo "❌ FAIL: Branch does not exist: $BRANCH"
    exit 1
  fi
}

assert_output_contains() {
  TEXT=$1
  if ! grep -q "$TEXT" "$OUTPUT_FILE"; then
    echo "❌ FAIL: Output missing: $TEXT"
    exit 1
  fi
}
```

### Phase 2: Fixtures (Test Data)

**File:** `tests/behavioral/fixtures/scope-creep/spec.md`
```markdown
# Feature: Magic Link Authentication

## Overview
Passwordless authentication via email magic links.

## Architecture

### Phase 1: Database Foundation
- Create `magicLinkTokens` table
- Migration for schema changes

### Phase 2: API Contracts
- MagicLinkRequest/Response types
- Schema definitions

### Phase 3: Service Layer
- Token generation logic
- Validation service
- Email integration

### Phase 4: API Routes
- POST /api/auth/magic-link
- Route handler integration
```

**File:** `tests/behavioral/fixtures/scope-creep/plan.md`
```markdown
# Implementation Plan: Magic Link Auth

**Total Phases:** 4
**Parallelization:** Sequential foundation, parallel UI

## Phase 1: Database Foundation (Sequential)
**Strategy:** sequential

### Task 1.1: Create schema
**Files:**
- prisma/schema.prisma
**Acceptance Criteria:**
- magicLinkTokens table exists
- Migration generated

## Phase 2: API Contracts (Sequential)
**Strategy:** sequential

### Task 2.1: Define contracts
**Files:**
- src/lib/api/contracts.ts
**Acceptance Criteria:**
- MagicLinkRequest type
- MagicLinkResponse type

## Phase 3: Service Layer (Sequential)
**Strategy:** sequential

### Task 3.1: Implement service
**Files:**
- src/lib/auth/magic-link.ts
**Acceptance Criteria:**
- generateToken function
- validateToken function

## Phase 4: API Routes (Sequential)
**Strategy:** sequential

### Task 4.1: Create routes
**Files:**
- src/app/api/auth/magic-link/route.ts
**Acceptance Criteria:**
- POST handler implemented
```

### Phase 3: Behavioral Test Runner

**File:** `tests/behavioral/run-test.sh`
```bash
#!/bin/bash
set -e

TEST_SCENARIO=$1

# Source helpers
source "$(dirname "$0")/harness/setup-test-repo.sh"
source "$(dirname "$0")/harness/verify-behavior.sh"

# Run the test scenario
bash "$(dirname "$0")/scenarios/$TEST_SCENARIO"

echo "✅ Test passed: $TEST_SCENARIO"
```

### Phase 4: First Behavioral Test

**File:** `tests/behavioral/scenarios/test-phase-scope-enforcement.sh`
```bash
#!/bin/bash

TEST_NAME="phase-scope-enforcement"
OUTPUT_FILE="/tmp/spectacular-test-output-$$.log"

# 1. Setup
TEST_REPO=$(setup_test_repo "$TEST_NAME")
cd "$TEST_REPO"

# 2. Copy fixture
RUN_ID="abc123"
mkdir -p "specs/${RUN_ID}-magic-link"
cp ../fixtures/scope-creep/* "specs/${RUN_ID}-magic-link/"

# 3. Create main worktree
mkdir -p ".worktrees"
git worktree add ".worktrees/${RUN_ID}-main" --detach main

# 4. Execute spectacular command (capture output)
# NOTE: This requires running in Claude Code environment
# We'd need to invoke Claude with the execute command
# For now, simulate with recorded output for proof of concept

# 5. Verify behavior
assert_tool_NOT_called "AskUserQuestion"
assert_output_contains "Code review REJECTED"
assert_output_contains "Scope creep"
assert_tool_called "Task" "Fix Phase 2 code review issues"
assert_output_contains "Ready to merge? Yes"

# 6. Cleanup
cd /
rm -rf "$TEST_REPO"

echo "✅ phase-scope-enforcement test passed"
```

## The Challenge: Executing in Test Context

**Problem:** How do we actually run `/spectacular:execute` from a bash script?

**Solutions:**

### Option A: Record/Replay
1. Manually execute scenarios once
2. Record full output
3. Tests verify recorded behavior
4. Re-record when implementation changes

### Option B: Claude Code API
1. Tests invoke Claude Code programmatically
2. Pass test fixtures
3. Capture actual tool calls and output
4. Assert on real behavior

### Option C: Subagent Test Harness
1. Tests dispatch specialized "test executor" subagent
2. Subagent runs spectacular command
3. Returns observable state (branches, tool calls)
4. Test asserts on returned data

## Next Steps

1. **Build harness** (setup-test-repo.sh, verify-behavior.sh)
2. **Create 1 fixture** (scope-creep scenario)
3. **Write 1 behavioral test** (phase-scope-enforcement)
4. **Solve execution challenge** (how to run spectacular in test)
5. **Expand to 6 scenarios**

This gives us **real behavioral tests** that prove the fix works, not just documentation validators.
