#!/bin/bash
#
# Execution Test: Sequential Stacking
#
# Verifies that sequential phase execution creates properly stacked branches
# without manual upstack commands or nested worktrees.
#
# Critical behaviors tested:
# - Main worktree created correctly
# - Sequential tasks use shared worktree
# - Branches stack naturally via git-spice
# - No manual stacking commands needed
# - Worktree cleanup after completion
#

set -euo pipefail

# Load test harness
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/test-harness.sh"

# Test configuration
RUN_ID="abc123"
FEATURE_SLUG="sequential-test"

echo "========================================="
echo "Execution Test: Sequential Stacking"
echo "========================================="
echo ""

# Setup
setup_test_repo "sequential-stacking"

# Create mock spec and plan
echo "Creating mock spec and plan..."
SPEC_DIR=$(create_mock_spec "$RUN_ID" "$FEATURE_SLUG")
PLAN_FILE="$SPEC_DIR/plan.md"

# Override plan with sequential tasks
cat > "$PLAN_FILE" << 'EOF'
# Implementation Plan: Sequential Test

**Total Phases:** 1
**Parallelization:** Sequential

## Phase 1: Sequential Tasks (Sequential)
**Strategy:** sequential

### Task 1.1: Create Schema
**Files:**
- src/schema.ts

**Acceptance Criteria:**
- Define database schema

### Task 1.2: Add Migration
**Files:**
- prisma/migrations/001_init.sql

**Acceptance Criteria:**
- Create migration file

### Task 1.3: Update Types
**Files:**
- src/types.ts

**Acceptance Criteria:**
- Export types from schema
EOF

echo "✅ Test setup complete"
echo ""

# ===========================
# SIMULATE SEQUENTIAL EXECUTION
# ===========================

echo "Simulating sequential phase execution..."
echo ""

# Step 1: Create main worktree
echo "1. Creating main worktree..."
mkdir -p .worktrees
git worktree add ".worktrees/${RUN_ID}-main" --detach main

# Verify main worktree created
assert_worktree_exists ".worktrees/${RUN_ID}-main"

# Step 2: Execute tasks in sequence (simulating subagent work)
cd ".worktrees/${RUN_ID}-main"

# Task 1.1
echo ""
echo "2. Executing Task 1.1 in main worktree..."
git checkout -b "${RUN_ID}-task-1-1-create-schema"
mkdir -p src
echo "// Schema" > src/schema.ts
git add src/schema.ts
git commit -m "feat: create schema"

# Verify task 1.1 branch
cd "$TEST_REPO"
assert_branch_exists "${RUN_ID}-task-1-1-create-schema"

# Task 1.2 (stacks on task 1.1)
cd ".worktrees/${RUN_ID}-main"
echo ""
echo "3. Executing Task 1.2 in main worktree (stacks naturally)..."
git checkout -b "${RUN_ID}-task-1-2-add-migration"
mkdir -p prisma/migrations
echo "-- Migration" > prisma/migrations/001_init.sql
git add prisma/migrations
git commit -m "feat: add migration"

# Verify task 1.2 branch
cd "$TEST_REPO"
assert_branch_exists "${RUN_ID}-task-1-2-add-migration"

# Task 1.3 (stacks on task 1.2)
cd ".worktrees/${RUN_ID}-main"
echo ""
echo "4. Executing Task 1.3 in main worktree (stacks naturally)..."
git checkout -b "${RUN_ID}-task-1-3-update-types"
mkdir -p src
echo "// Types" > src/types.ts
git add src/types.ts
git commit -m "feat: update types"

# Verify task 1.3 branch
cd "$TEST_REPO"
assert_branch_exists "${RUN_ID}-task-1-3-update-types"

echo ""
echo "5. Simulating orchestrator cleanup..."

# Step 3: Cleanup worktrees (orchestrator does this)
git worktree remove ".worktrees/${RUN_ID}-main" 2>/dev/null || true
rm -rf ".worktrees/${RUN_ID}-main"

# Verify cleanup
assert_worktree_not_exists ".worktrees/${RUN_ID}-main"

# ===========================
# VERIFY STACK STRUCTURE
# ===========================

echo ""
echo "========================================="
echo "Verifying Stack Structure"
echo "========================================="
echo ""

# Verify all branches exist
echo "Branch existence:"
assert_branch_exists "${RUN_ID}-task-1-1-create-schema"
assert_branch_exists "${RUN_ID}-task-1-2-add-migration"
assert_branch_exists "${RUN_ID}-task-1-3-update-types"

# Verify linear stacking order
echo ""
echo "Stack order:"
assert_stack_order \
  "${RUN_ID}-task-1-1-create-schema" \
  "${RUN_ID}-task-1-2-add-migration" \
  "${RUN_ID}-task-1-3-update-types"

# Verify no leftover worktrees
echo ""
echo "Worktree cleanup:"
assert_worktree_count 0

# Verify commits exist on each branch
echo ""
echo "Commit existence:"
assert_file_exists ".git/refs/heads/${RUN_ID}-task-1-1-create-schema"
assert_file_exists ".git/refs/heads/${RUN_ID}-task-1-2-add-migration"
assert_file_exists ".git/refs/heads/${RUN_ID}-task-1-3-update-types"

# ===========================
# FINAL REPORT
# ===========================

report_test_results "sequential-stacking"
EXIT_CODE=$?

# Cleanup
cleanup_test_repo

exit $EXIT_CODE
