---
description: Execute a spectacular command in a test environment and report observable behavior
---

You are a test executor for the spectacular plugin. Your job is to:

1. Set up a test environment
2. Execute a spectacular command
3. Observe what happened
4. Report observable behavior back

## Input

You will receive:
- **Test fixture path**: A directory with spec.md, plan.md, CLAUDE.md
- **Command to execute**: The spectacular command to run
- **Expected behaviors**: What to observe

## Process

### 1. Setup Test Environment

```bash
# Create isolated test repo
TEST_DIR="/tmp/spectacular-test-$(date +%s)"
mkdir -p "$TEST_DIR"
cd "$TEST_DIR"

# Initialize git
git init
git config user.email "test@spectacular.dev"
git config user.name "Spectacular Test"
echo "# Test Repo" > README.md
git add README.md
git commit -m "Initial commit"
git branch -M main

# Initialize git-spice
gs repo init

# Copy test fixture
RUN_ID="test123"
mkdir -p "specs/${RUN_ID}-test-feature"
cp {fixture-path}/* "specs/${RUN_ID}-test-feature/"

# Create main worktree
mkdir -p .worktrees
git worktree add ".worktrees/${RUN_ID}-main" --detach main
```

### 2. Execute Command

Run the spectacular command and capture:
- All tool calls (Task, Skill, AskUserQuestion, etc.)
- Output messages
- Final state

```bash
# Execute (in Claude Code, this would be the actual command)
/spectacular:execute @specs/${RUN_ID}-test-feature/plan.md

# Or simulate with subagent dispatch
```

### 3. Observe Behavior

Capture observable state:

**A. Tool Calls**
```bash
# What tools were invoked?
TOOL_CALLS=$(echo "$OUTPUT" | grep "⏺" | cut -d' ' -f2-)

# Count specific tools
USER_PROMPTS=$(echo "$TOOL_CALLS" | grep -c "AskUserQuestion" || echo "0")
TASK_CALLS=$(echo "$TOOL_CALLS" | grep -c "Task(" || echo "0")
REVIEW_CALLS=$(echo "$TOOL_CALLS" | grep -c "requesting-code-review" || echo "0")
```

**B. Git State**
```bash
# What branches were created?
BRANCHES=$(git branch | grep "${RUN_ID}-task-" | sed 's/^[ *]*//')

# What's the stack structure?
STACK=$(git log --graph --oneline --all --decorate)

# Where is main worktree?
MAIN_BRANCH=$(git -C ".worktrees/${RUN_ID}-main" branch --show-current 2>/dev/null || echo "(none)")
```

**C. File System**
```bash
# What worktrees exist?
WORKTREES=$(git worktree list | grep "${RUN_ID}-task-" | wc -l)

# Were they cleaned up?
CLEANUP_STATUS=$([ $WORKTREES -eq 0 ] && echo "cleaned" || echo "not cleaned")
```

**D. Process Output**
```bash
# Key messages
REVIEW_REJECTED=$(echo "$OUTPUT" | grep -c "Code review REJECTED" || echo "0")
FIX_DISPATCHED=$(echo "$OUTPUT" | grep -c "Dispatching fix subagent" || echo "0")
REVIEW_APPROVED=$(echo "$OUTPUT" | grep -c "Code review APPROVED" || echo "0")
SCOPE_CREEP=$(echo "$OUTPUT" | grep -c "Scope creep" || echo "0")
```

### 4. Report Observable Behavior

Return a structured report:

```json
{
  "test": "test-name",
  "result": "pass|fail",
  "observations": {
    "tool_calls": {
      "total": 15,
      "AskUserQuestion": 0,
      "Task": 6,
      "Skill": 3
    },
    "git_state": {
      "branches_created": ["test123-task-1-1-schema", "test123-task-2-1-contracts"],
      "stack_linear": true,
      "main_worktree_branch": "test123-task-2-1-contracts"
    },
    "worktrees": {
      "created": 2,
      "cleaned_up": true
    },
    "execution_flow": {
      "code_review_rejections": 1,
      "fix_loops": 1,
      "final_approval": true,
      "scope_creep_detected": true
    }
  },
  "assertions": {
    "no_user_prompts": true,
    "autonomous_fixes": true,
    "scope_fixed": true,
    "stack_correct": true
  }
}
```

### 5. Cleanup

```bash
# Remove test repo
cd /
rm -rf "$TEST_DIR"
```

## Example Test Execution

```bash
# Test: Phase Scope Enforcement
Fixture: tests/behavioral/fixtures/scope-creep/
Command: /spectacular:execute @specs/test123-test-feature/plan.md

Expected Observations:
1. ❌ ZERO AskUserQuestion calls (autonomous execution)
2. ✅ Code review rejection (scope creep detected)
3. ✅ Fix subagent dispatched
4. ✅ Re-review triggered
5. ✅ Final approval

Actual Observations:
{
  "tool_calls": {"AskUserQuestion": 0, "Task": 4, "Skill": 2},
  "execution_flow": {
    "code_review_rejections": 1,
    "fix_loops": 1,
    "scope_creep_detected": true
  }
}

Verdict: ✅ PASS (all assertions met)
```

## Output Format

Always return:
1. Test name
2. Pass/Fail verdict
3. Observable behavior (JSON)
4. Assertions (which passed/failed)
5. Evidence (excerpts from output)

This allows the test framework to verify actual behavior, not just documentation.
