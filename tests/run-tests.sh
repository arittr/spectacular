#!/bin/bash
#
# Unified Test Runner for Spectacular
#
# Runs three types of tests:
# 1. Validation tests - Fast grep-based guards (catch obvious regressions)
# 2. Execution tests - Actual git operations (verify mechanics work)
# 3. Pressure tests - Subagent dispatch (verify compliance under temptation)
#
# Usage:
#   ./tests/run-tests.sh [command] [--type=TYPE]
#
# Examples:
#   ./tests/run-tests.sh execute                    # All test types for execute
#   ./tests/run-tests.sh execute --type=validation  # Only validation tests
#   ./tests/run-tests.sh execute --type=execution   # Only execution tests
#   ./tests/run-tests.sh execute --type=pressure    # Only pressure tests
#   ./tests/run-tests.sh --all                      # All tests for all commands
#

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Configuration
COMMAND="${1:-}"
TEST_TYPE="all"  # Default: run all test types

# Parse arguments
for arg in "$@"; do
  case $arg in
    --type=*)
      TEST_TYPE="${arg#*=}"
      shift
      ;;
    --all)
      COMMAND="all"
      shift
      ;;
  esac
done

# Validate test type
if [[ ! "$TEST_TYPE" =~ ^(all|validation|execution|pressure)$ ]]; then
  echo -e "${RED}❌ Invalid test type: $TEST_TYPE${NC}"
  echo ""
  echo "Valid types: all, validation, execution, pressure"
  exit 1
fi

# Validate command
if [ -z "$COMMAND" ]; then
  echo -e "${RED}❌ Usage: $0 <command> [--type=TYPE]${NC}"
  echo ""
  echo "Examples:"
  echo "  $0 execute"
  echo "  $0 execute --type=validation"
  echo "  $0 --all"
  exit 1
fi

# Create timestamped results directory
TIMESTAMP=$(date +%Y-%m-%dT%H%M%S)
RESULTS_DIR="tests/results/$TIMESTAMP"

mkdir -p "$RESULTS_DIR/scenarios"
mkdir -p "$RESULTS_DIR/execution"
mkdir -p "$RESULTS_DIR/pressure"

# Create symlink to latest results
ln -sfn "$TIMESTAMP" tests/results/latest

echo -e "${BLUE}=========================================${NC}"
echo -e "${BLUE}Spectacular Test Runner${NC}"
echo -e "${BLUE}=========================================${NC}"
echo ""
echo "Command: $COMMAND"
echo "Test types: $TEST_TYPE"
echo "Results: $RESULTS_DIR"
echo ""

# ===========================
# 1. VALIDATION TESTS
# ===========================

run_validation_tests() {
  local cmd=$1

  echo -e "${CYAN}----------------------------------------${NC}"
  echo -e "${CYAN}Running Validation Tests${NC}"
  echo -e "${CYAN}----------------------------------------${NC}"
  echo ""

  # Find validation scenarios
  VALIDATION_SCENARIOS=$(find "tests/scenarios/$cmd" -name "*.md" -type f ! -name "README.md" | sort)
  VALIDATION_COUNT=$(echo "$VALIDATION_SCENARIOS" | grep -c "." || echo "0")

  if [ "$VALIDATION_COUNT" -eq 0 ]; then
    echo -e "${YELLOW}⚠️  No validation scenarios found for $cmd${NC}"
    return 0
  fi

  echo "Found $VALIDATION_COUNT validation scenarios"
  echo ""

  # These are grep-based validators that check documentation
  # They run fast and catch obvious regressions like deleted sections

  for scenario_file in $VALIDATION_SCENARIOS; do
    SCENARIO_NAME=$(basename "$scenario_file" .md)
    LOG_FILE="$RESULTS_DIR/scenarios/$SCENARIO_NAME.log"

    echo -e "${BLUE}Testing: $SCENARIO_NAME${NC}"

    # Read scenario and run verification commands
    # (This would normally dispatch a subagent, but for now we'll skip implementation)
    # TODO: Implement validation test execution

    echo "  ⏭  Skipped (validation tests require subagent dispatch)" >> "$LOG_FILE"
    echo ""
  done
}

# ===========================
# 2. EXECUTION TESTS
# ===========================

run_execution_tests() {
  local cmd=$1

  echo -e "${CYAN}----------------------------------------${NC}"
  echo -e "${CYAN}Running Execution Tests${NC}"
  echo -e "${CYAN}----------------------------------------${NC}"
  echo ""

  # Find execution test scenarios
  EXECUTION_SCENARIOS=$(find "tests/execution/$cmd" -name "*.sh" -type f 2>/dev/null | sort)
  EXECUTION_COUNT=$(echo "$EXECUTION_SCENARIOS" | grep -c "." || echo "0")

  if [ "$EXECUTION_COUNT" -eq 0 ]; then
    echo -e "${YELLOW}⚠️  No execution tests found for $cmd${NC}"
    echo -e "${YELLOW}   Create tests in: tests/execution/$cmd/${NC}"
    return 0
  fi

  echo "Found $EXECUTION_COUNT execution tests"
  echo ""

  # Run each execution test
  for test_script in $EXECUTION_SCENARIOS; do
    TEST_NAME=$(basename "$test_script" .sh)
    LOG_FILE="$RESULTS_DIR/execution/$TEST_NAME.log"

    echo -e "${BLUE}Testing: $TEST_NAME${NC}"

    # Execute test script and capture output
    if bash "$test_script" > "$LOG_FILE" 2>&1; then
      echo -e "${GREEN}  ✅ PASS${NC}"
    else
      echo -e "${RED}  ❌ FAIL${NC}"
      echo "  See: $LOG_FILE"
    fi
    echo ""
  done
}

# ===========================
# 3. PRESSURE TESTS
# ===========================

run_pressure_tests() {
  local cmd=$1

  echo -e "${CYAN}----------------------------------------${NC}"
  echo -e "${CYAN}Running Pressure Tests${NC}"
  echo -e "${CYAN}----------------------------------------${NC}"
  echo ""

  # Find pressure test scenarios
  PRESSURE_SCENARIOS=$(find "tests/pressure/$cmd" -name "*.md" -type f 2>/dev/null | sort)
  PRESSURE_COUNT=$(echo "$PRESSURE_SCENARIOS" | grep -c "." || echo "0")

  if [ "$PRESSURE_COUNT" -eq 0 ]; then
    echo -e "${YELLOW}⚠️  No pressure tests found for $cmd${NC}"
    echo -e "${YELLOW}   Create tests in: tests/pressure/$cmd/${NC}"
    return 0
  fi

  echo "Found $PRESSURE_COUNT pressure tests"
  echo ""

  # Pressure tests require Claude Code to dispatch subagents
  # They cannot run as standalone bash scripts

  echo -e "${YELLOW}⚠️  Pressure tests require Claude Code to dispatch subagents${NC}"
  echo ""
  echo "To run pressure tests, ask Claude Code:"
  echo ""

  for scenario_file in $PRESSURE_SCENARIOS; do
    SCENARIO_NAME=$(basename "$scenario_file" .md)
    echo -e "  ${CYAN}\"Run pressure test for $SCENARIO_NAME\"${NC}"
  done

  echo ""
  echo "Or run all pressure tests for $cmd:"
  echo -e "  ${CYAN}\"Run all pressure tests for $cmd command\"${NC}"
  echo ""

  # Create placeholder logs
  for scenario_file in $PRESSURE_SCENARIOS; do
    SCENARIO_NAME=$(basename "$scenario_file" .md)
    LOG_FILE="$RESULTS_DIR/pressure/$SCENARIO_NAME.log"

    cat > "$LOG_FILE" << PLACEHOLDER
# Pressure Test: $SCENARIO_NAME

**Status:** Not executed (requires Claude Code)

To run this test, ask Claude Code:
"Run pressure test for $SCENARIO_NAME"

See: tests/pressure/lib/execute-pressure-test.md for execution process.
PLACEHOLDER
  done
}

# ===========================
# MAIN EXECUTION
# ===========================

if [ "$COMMAND" = "all" ]; then
  # Run tests for all commands
  COMMANDS=$(ls tests/scenarios)

  for cmd in $COMMANDS; do
    if [ "$TEST_TYPE" = "all" ] || [ "$TEST_TYPE" = "validation" ]; then
      run_validation_tests "$cmd"
    fi

    if [ "$TEST_TYPE" = "all" ] || [ "$TEST_TYPE" = "execution" ]; then
      run_execution_tests "$cmd"
    fi

    if [ "$TEST_TYPE" = "all" ] || [ "$TEST_TYPE" = "pressure" ]; then
      run_pressure_tests "$cmd"
    fi
  done
else
  # Run tests for specific command
  if [ "$TEST_TYPE" = "all" ] || [ "$TEST_TYPE" = "validation" ]; then
    run_validation_tests "$COMMAND"
  fi

  if [ "$TEST_TYPE" = "all" ] || [ "$TEST_TYPE" = "execution" ]; then
    run_execution_tests "$COMMAND"
  fi

  if [ "$TEST_TYPE" = "all" ] || [ "$TEST_TYPE" = "pressure" ]; then
    run_pressure_tests "$COMMAND"
  fi
fi

# ===========================
# AGGREGATE RESULTS
# ===========================

echo -e "${BLUE}=========================================${NC}"
echo -e "${BLUE}Aggregating Results${NC}"
echo -e "${BLUE}=========================================${NC}"
echo ""

# Run aggregation script
if [ -x "tests/aggregate-results.sh" ]; then
  ./tests/aggregate-results.sh "$RESULTS_DIR"
else
  echo -e "${YELLOW}⚠️  Aggregation script not found${NC}"
  echo ""
  echo "Results saved to: $RESULTS_DIR"
fi
