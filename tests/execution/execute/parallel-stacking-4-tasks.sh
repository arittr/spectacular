#!/bin/bash
#
# Execution Test: Parallel Stacking (4 Tasks)
#
# Verifies that parallel phase execution creates:
# - Isolated worktrees for each task
# - Linear stack after completion (N-1 upstack operations)
# - Proper cleanup of all worktrees
#
# Critical behaviors tested:
# - 4 isolated worktrees created from base branch
# - All tasks can execute in parallel (no conflicts)
# - Final stack is linear: task-1 → task-2 → task-3 → task-4
# - All worktrees cleaned up after stacking
#

set -euo pipefail

# Load test harness
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/test-harness.sh"

# Test configuration
RUN_ID="def456"
FEATURE_SLUG="parallel-test"

echo "========================================="
echo "Execution Test: Parallel Stacking (4 Tasks)"
echo "========================================="
echo ""

# Setup
setup_test_repo "parallel-stacking-4-tasks"

# Create mock spec and plan
echo "Creating mock spec and plan..."
SPEC_DIR=$(create_mock_spec "$RUN_ID" "$FEATURE_SLUG")
PLAN_FILE="$SPEC_DIR/plan.md"

# Override plan with parallel tasks
cat > "$PLAN_FILE" << 'EOF'
# Implementation Plan: Parallel Test

**Total Phases:** 1
**Parallelization:** Parallel execution

## Phase 1: UI Components (Parallel)
**Strategy:** parallel

### Task 1.1: Button Component
**Files:**
- src/components/Button.tsx

**Acceptance Criteria:**
- Create button component

### Task 1.2: Input Component
**Files:**
- src/components/Input.tsx

**Acceptance Criteria:**
- Create input component

### Task 1.3: Modal Component
**Files:**
- src/components/Modal.tsx

**Acceptance Criteria:**
- Create modal component

### Task 1.4: Form Component
**Files:**
- src/components/Form.tsx

**Acceptance Criteria:**
- Create form component
EOF

echo "✅ Test setup complete"
echo ""

# ===========================
# SIMULATE PARALLEL EXECUTION
# ===========================

echo "Simulating parallel phase execution..."
echo ""

# Step 1: Create isolated worktrees for each task
echo "1. Creating isolated worktrees for 4 tasks..."
mkdir -p .worktrees

BASE_BRANCH="main"

for task_num in 1 2 3 4; do
  WORKTREE_PATH=".worktrees/${RUN_ID}-task-1-${task_num}"
  git worktree add "$WORKTREE_PATH" --detach "$BASE_BRANCH"
  assert_worktree_exists "$WORKTREE_PATH"
done

echo ""

# Step 2: Execute tasks in parallel (simulate by doing them sequentially)
echo "2. Executing 4 tasks in isolated worktrees..."

# Task 1.1
cd ".worktrees/${RUN_ID}-task-1-1"
git checkout -b "${RUN_ID}-task-1-1-button"
mkdir -p src/components
echo "// Button" > src/components/Button.tsx
git add src/components
git commit -m "feat: add button component"
git switch --detach  # Critical: detach HEAD so branch is accessible in parent repo

# Task 1.2
cd "$TEST_REPO/.worktrees/${RUN_ID}-task-1-2"
git checkout -b "${RUN_ID}-task-1-2-input"
mkdir -p src/components
echo "// Input" > src/components/Input.tsx
git add src/components
git commit -m "feat: add input component"
git switch --detach

# Task 1.3
cd "$TEST_REPO/.worktrees/${RUN_ID}-task-1-3"
git checkout -b "${RUN_ID}-task-1-3-modal"
mkdir -p src/components
echo "// Modal" > src/components/Modal.tsx
git add src/components
git commit -m "feat: add modal component"
git switch --detach

# Task 1.4
cd "$TEST_REPO/.worktrees/${RUN_ID}-task-1-4"
git checkout -b "${RUN_ID}-task-1-4-form"
mkdir -p src/components
echo "// Form" > src/components/Form.tsx
git add src/components
git commit -m "feat: add form component"
git switch --detach

cd "$TEST_REPO"

# Verify all branches exist
echo ""
echo "3. Verifying all task branches exist..."
assert_branch_exists "${RUN_ID}-task-1-1-button"
assert_branch_exists "${RUN_ID}-task-1-2-input"
assert_branch_exists "${RUN_ID}-task-1-3-modal"
assert_branch_exists "${RUN_ID}-task-1-4-form"

# Step 3: Stack branches linearly (N-1 upstack operations)
echo ""
echo "4. Stacking branches linearly (N-1 = 3 upstack operations)..."

# Simulate git-spice stacking: task-1 → task-2 → task-3 → task-4
# In reality, this would be done with `gs upstack onto`, but we'll simulate with merge-base

# Stack task-2 onto task-1
git checkout "${RUN_ID}-task-1-2-input"
git rebase "${RUN_ID}-task-1-1-button"

# Stack task-3 onto task-2
git checkout "${RUN_ID}-task-1-3-modal"
git rebase "${RUN_ID}-task-1-2-input"

# Stack task-4 onto task-3
git checkout "${RUN_ID}-task-1-4-form"
git rebase "${RUN_ID}-task-1-3-modal"

# Return to main
git checkout main

echo "✅ Linear stacking complete"

# Step 4: Cleanup worktrees
echo ""
echo "5. Cleaning up worktrees..."
for task_num in 1 2 3 4; do
  WORKTREE_PATH=".worktrees/${RUN_ID}-task-1-${task_num}"
  git worktree remove "$WORKTREE_PATH" 2>/dev/null || true
  rm -rf "$WORKTREE_PATH"
done

# ===========================
# VERIFY FINAL STATE
# ===========================

echo ""
echo "========================================="
echo "Verifying Final State"
echo "========================================="
echo ""

# Verify all branches exist
echo "Branch existence:"
assert_branch_exists "${RUN_ID}-task-1-1-button"
assert_branch_exists "${RUN_ID}-task-1-2-input"
assert_branch_exists "${RUN_ID}-task-1-3-modal"
assert_branch_exists "${RUN_ID}-task-1-4-form"

# Verify linear stacking
echo ""
echo "Stack order:"
assert_stack_order \
  "${RUN_ID}-task-1-1-button" \
  "${RUN_ID}-task-1-2-input" \
  "${RUN_ID}-task-1-3-modal" \
  "${RUN_ID}-task-1-4-form"

# Verify no leftover worktrees
echo ""
echo "Worktree cleanup:"
assert_worktree_count 0

# ===========================
# FINAL REPORT
# ===========================

report_test_results "parallel-stacking-4-tasks"
EXIT_CODE=$?

# Cleanup
cleanup_test_repo

exit $EXIT_CODE
