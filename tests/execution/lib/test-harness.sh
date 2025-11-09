#!/bin/bash
#
# Test Harness Library for Execution Tests
#
# Provides helper functions for:
# - Creating isolated test repositories
# - Verifying git state (branches, worktrees, commits)
# - Running spectacular commands
# - Asserting expected outcomes
#
# Usage:
#   source tests/execution/lib/test-harness.sh
#   setup_test_repo "test-name"
#   assert_branch_exists "abc123-task-1-1-schema"
#   cleanup_test_repo
#

set -euo pipefail

# Colors for test output
TEST_RED='\033[0;31m'
TEST_GREEN='\033[0;32m'
TEST_YELLOW='\033[1;33m'
TEST_BLUE='\033[0;34m'
TEST_NC='\033[0m'

# Test state
TEST_REPO=""
TEST_FAILURES=0
TEST_PASSES=0

# ===========================
# SETUP & CLEANUP
# ===========================

setup_test_repo() {
  local test_name=$1

  # Create isolated temp directory
  TEST_REPO="/tmp/spectacular-test-$test_name-$$"

  echo -e "${TEST_BLUE}Setting up test repo: $TEST_REPO${TEST_NC}"

  # Create directory
  mkdir -p "$TEST_REPO"
  cd "$TEST_REPO"

  # Initialize git
  git init
  git config user.email "test@spectacular.dev"
  git config user.name "Spectacular Test"

  # Initial commit
  echo "# Test Repository" > README.md
  git add README.md
  git commit -m "Initial commit"

  # Create main branch
  git branch -M main

  # Initialize git-spice (if installed)
  if command -v gs &> /dev/null; then
    gs repo init --submit=false 2>/dev/null || true
  fi

  echo -e "${TEST_GREEN}✅ Test repo created: $TEST_REPO${TEST_NC}"
  echo ""
}

cleanup_test_repo() {
  if [ -n "$TEST_REPO" ] && [ -d "$TEST_REPO" ]; then
    echo ""
    echo -e "${TEST_BLUE}Cleaning up test repo: $TEST_REPO${TEST_NC}"
    cd /
    rm -rf "$TEST_REPO"
    echo -e "${TEST_GREEN}✅ Cleanup complete${TEST_NC}"
  fi
}

# ===========================
# GIT STATE ASSERTIONS
# ===========================

assert_branch_exists() {
  local branch_name=$1

  if git rev-parse --verify "$branch_name" >/dev/null 2>&1; then
    echo -e "${TEST_GREEN}  ✅ Branch exists: $branch_name${TEST_NC}"
    TEST_PASSES=$((TEST_PASSES + 1))
    return 0
  else
    echo -e "${TEST_RED}  ❌ FAIL: Branch does not exist: $branch_name${TEST_NC}"
    TEST_FAILURES=$((TEST_FAILURES + 1))
    return 1
  fi
}

assert_branch_not_exists() {
  local branch_name=$1

  if git rev-parse --verify "$branch_name" >/dev/null 2>&1; then
    echo -e "${TEST_RED}  ❌ FAIL: Branch should not exist: $branch_name${TEST_NC}"
    TEST_FAILURES=$((TEST_FAILURES + 1))
    return 1
  else
    echo -e "${TEST_GREEN}  ✅ Branch does not exist: $branch_name${TEST_NC}"
    TEST_PASSES=$((TEST_PASSES + 1))
    return 0
  fi
}

assert_worktree_exists() {
  local worktree_path=$1

  if [ -d "$worktree_path" ]; then
    echo -e "${TEST_GREEN}  ✅ Worktree exists: $worktree_path${TEST_NC}"
    TEST_PASSES=$((TEST_PASSES + 1))
    return 0
  else
    echo -e "${TEST_RED}  ❌ FAIL: Worktree does not exist: $worktree_path${TEST_NC}"
    TEST_FAILURES=$((TEST_FAILURES + 1))
    return 1
  fi
}

assert_worktree_not_exists() {
  local worktree_path=$1

  if [ -d "$worktree_path" ]; then
    echo -e "${TEST_RED}  ❌ FAIL: Worktree should not exist: $worktree_path${TEST_NC}"
    TEST_FAILURES=$((TEST_FAILURES + 1))
    return 1
  else
    echo -e "${TEST_GREEN}  ✅ Worktree does not exist: $worktree_path${TEST_NC}"
    TEST_PASSES=$((TEST_PASSES + 1))
    return 0
  fi
}

assert_worktree_count() {
  local expected_count=$1
  local actual_count=$(git worktree list | tail -n +2 | wc -l | tr -d ' ')

  if [ "$actual_count" -eq "$expected_count" ]; then
    echo -e "${TEST_GREEN}  ✅ Worktree count: $actual_count (expected: $expected_count)${TEST_NC}"
    TEST_PASSES=$((TEST_PASSES + 1))
    return 0
  else
    echo -e "${TEST_RED}  ❌ FAIL: Worktree count: $actual_count (expected: $expected_count)${TEST_NC}"
    TEST_FAILURES=$((TEST_FAILURES + 1))
    return 1
  fi
}

assert_stack_order() {
  # Verify that branches stack in the given order
  # Usage: assert_stack_order branch1 branch2 branch3
  # Verifies: branch1 → branch2 → branch3

  local branches=("$@")
  local prev_branch=""

  for branch in "${branches[@]}"; do
    if [ -n "$prev_branch" ]; then
      # Check if current branch's parent is prev_branch
      local parent=$(git log --format=%H "$branch" ^"$prev_branch" | tail -1 | git branch --contains | grep "$prev_branch" || echo "")

      if [ -n "$parent" ]; then
        echo -e "${TEST_GREEN}  ✅ Stack order: $prev_branch → $branch${TEST_NC}"
        TEST_PASSES=$((TEST_PASSES + 1))
      else
        echo -e "${TEST_RED}  ❌ FAIL: Stack order broken: $prev_branch ↛ $branch${TEST_NC}"
        TEST_FAILURES=$((TEST_FAILURES + 1))
        return 1
      fi
    fi
    prev_branch="$branch"
  done

  return 0
}

assert_file_exists() {
  local file_path=$1

  if [ -f "$file_path" ]; then
    echo -e "${TEST_GREEN}  ✅ File exists: $file_path${TEST_NC}"
    TEST_PASSES=$((TEST_PASSES + 1))
    return 0
  else
    echo -e "${TEST_RED}  ❌ FAIL: File does not exist: $file_path${TEST_NC}"
    TEST_FAILURES=$((TEST_FAILURES + 1))
    return 1
  fi
}

assert_file_contains() {
  local file_path=$1
  local search_text=$2

  if grep -q "$search_text" "$file_path"; then
    echo -e "${TEST_GREEN}  ✅ File contains text: $file_path${TEST_NC}"
    TEST_PASSES=$((TEST_PASSES + 1))
    return 0
  else
    echo -e "${TEST_RED}  ❌ FAIL: File does not contain: $search_text${TEST_NC}"
    echo -e "${TEST_RED}     File: $file_path${TEST_NC}"
    TEST_FAILURES=$((TEST_FAILURES + 1))
    return 1
  fi
}

# ===========================
# BRANCH UTILITIES
# ===========================

create_mock_branch() {
  local branch_name=$1
  local base_branch=${2:-main}

  git checkout "$base_branch"
  git checkout -b "$branch_name"

  # Add a dummy commit
  echo "# Branch: $branch_name" >> README.md
  git add README.md
  git commit -m "Mock commit for $branch_name"

  # Return to base branch
  git checkout "$base_branch"
}

# ===========================
# SPEC/PLAN UTILITIES
# ===========================

create_mock_spec() {
  local run_id=$1
  local feature_slug=$2

  local spec_dir="specs/${run_id}-${feature_slug}"
  mkdir -p "$spec_dir"

  cat > "$spec_dir/spec.md" << EOF
# Feature: Mock Feature

## Overview

This is a mock feature specification for testing.

## Requirements

- Requirement 1
- Requirement 2

## Architecture

### Phase 1: Foundation
- Database schema
- Core types

### Phase 2: Service Layer
- Business logic
- Validation

### Phase 3: API Layer
- Route handlers
- Integration
EOF

  cat > "$spec_dir/CLAUDE.md" << EOF
# Mock Project Configuration

## Development Commands

### Setup

- **install**: echo "Mock install"
- **postinstall**: echo "Mock postinstall"

### Quality Checks

- **test**: echo "Mock tests passing"
- **lint**: echo "Mock lint passing"
- **build**: echo "Mock build passing"
EOF

  echo "$spec_dir"
}

create_mock_plan() {
  local run_id=$1
  local feature_slug=$2
  local num_phases=${3:-2}

  local spec_dir="specs/${run_id}-${feature_slug}"
  mkdir -p "$spec_dir"

  cat > "$spec_dir/plan.md" << EOF
# Implementation Plan: Mock Feature

**Total Phases:** $num_phases
**Parallelization:** Sequential foundation, parallel implementation

EOF

  for phase in $(seq 1 $num_phases); do
    cat >> "$spec_dir/plan.md" << EOF
## Phase $phase: Phase $phase Name (Sequential)
**Strategy:** sequential

### Task $phase.1: Task $phase.1 Name
**Files:**
- src/file-$phase-1.ts

**Acceptance Criteria:**
- Implement feature $phase.1

EOF
  done

  echo "$spec_dir"
}

# ===========================
# TEST REPORTING
# ===========================

report_test_results() {
  local test_name=$1

  echo ""
  echo -e "${TEST_BLUE}=========================================${TEST_NC}"
  echo -e "${TEST_BLUE}Test Results: $test_name${TEST_NC}"
  echo -e "${TEST_BLUE}=========================================${TEST_NC}"
  echo ""

  local total=$((TEST_PASSES + TEST_FAILURES))

  echo "Total assertions: $total"
  echo -e "${TEST_GREEN}Passed: $TEST_PASSES${TEST_NC}"
  echo -e "${TEST_RED}Failed: $TEST_FAILURES${TEST_NC}"
  echo ""

  if [ $TEST_FAILURES -eq 0 ]; then
    echo -e "${TEST_GREEN}✅ PASS: All assertions passed${TEST_NC}"
    return 0
  else
    echo -e "${TEST_RED}❌ FAIL: $TEST_FAILURES assertion(s) failed${TEST_NC}"
    return 1
  fi
}
