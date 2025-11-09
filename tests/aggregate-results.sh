#!/bin/bash
#
# Aggregate Test Results
#
# Usage: ./tests/aggregate-results.sh <results_dir>
#
# Scans scenario logs, counts pass/fail, generates summary report
#

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

RESULTS_DIR="${1:-}"

if [ -z "$RESULTS_DIR" ]; then
  echo -e "${RED}❌ Usage: $0 <results_dir>${NC}"
  echo ""
  echo "Example: $0 tests/results/2025-01-15T143027"
  exit 1
fi

if [ ! -d "$RESULTS_DIR" ]; then
  echo -e "${RED}❌ Results directory not found: $RESULTS_DIR${NC}"
  exit 1
fi

SCENARIOS_DIR="$RESULTS_DIR/scenarios"

if [ ! -d "$SCENARIOS_DIR" ]; then
  echo -e "${RED}❌ Scenarios directory not found: $SCENARIOS_DIR${NC}"
  exit 1
fi

echo -e "${BLUE}=========================================${NC}"
echo -e "${BLUE}Aggregating Test Results${NC}"
echo -e "${BLUE}=========================================${NC}"
echo ""
echo "Results directory: $RESULTS_DIR"
echo ""

# Count results
PASS_COUNT=0
FAIL_COUNT=0
PASS_SCENARIOS=()
FAIL_SCENARIOS=()
TEST_CASES=()  # For JUnit XML

for log_file in "$SCENARIOS_DIR"/*.log; do
  if [ ! -f "$log_file" ]; then
    continue
  fi

  SCENARIO_NAME=$(basename "$log_file" .log)

  # Extract failure message if present (key points from Summary section)
  FAILURE_MSG=""
  if grep -q "^❌ FAIL" "$log_file"; then
    # Extract "What's Missing" bullet points for concise CI summary
    if grep -q "### What's Missing" "$log_file"; then
      FAILURE_MSG=$(sed -n '/### What'"'"'s Missing/,/^### /p' "$log_file" | grep "^[0-9]" | head -10)
    elif grep -q "### What Fails" "$log_file"; then
      FAILURE_MSG=$(sed -n '/### What Fails/,/^### /p' "$log_file" | grep "^[0-9]" | head -10)
    else
      # Fall back to first line after ## Evidence
      FAILURE_MSG=$(sed -n '/^## Evidence/,/^$/p' "$log_file" | grep -v "^## " | head -5)
    fi
  fi

  if grep -q "^✅ PASS" "$log_file"; then
    PASS_COUNT=$((PASS_COUNT + 1))
    PASS_SCENARIOS+=("$SCENARIO_NAME")
    TEST_CASES+=("$SCENARIO_NAME|pass|")
  elif grep -q "^❌ FAIL" "$log_file"; then
    FAIL_COUNT=$((FAIL_COUNT + 1))
    FAIL_SCENARIOS+=("$SCENARIO_NAME")
    TEST_CASES+=("$SCENARIO_NAME|fail|$FAILURE_MSG")
  else
    echo -e "${YELLOW}⚠️  Warning: Ambiguous result in $SCENARIO_NAME${NC}"
    FAIL_COUNT=$((FAIL_COUNT + 1))
    FAIL_SCENARIOS+=("$SCENARIO_NAME (ambiguous)")
    TEST_CASES+=("$SCENARIO_NAME|fail|Ambiguous test result - no clear PASS/FAIL verdict found")
  fi
done

TOTAL_COUNT=$((PASS_COUNT + FAIL_COUNT))

# Generate summary report
SUMMARY_FILE="$RESULTS_DIR/summary.md"

cat > "$SUMMARY_FILE" << SUMMARY_EOF
# Test Results Summary

**Run:** $(basename "$RESULTS_DIR")
**Date:** $(date)
**Results:** $PASS_COUNT/$TOTAL_COUNT passed ($(awk "BEGIN {printf \"%.1f\", ($PASS_COUNT/$TOTAL_COUNT)*100}")%)

## Overview

- ✅ **Passed:** $PASS_COUNT scenarios
- ❌ **Failed:** $FAIL_COUNT scenarios
- 📊 **Total:** $TOTAL_COUNT scenarios

## Detailed Results

### Passed Scenarios

SUMMARY_EOF

if [ ${#PASS_SCENARIOS[@]} -eq 0 ]; then
  echo "None" >> "$SUMMARY_FILE"
else
  for scenario in "${PASS_SCENARIOS[@]}"; do
    echo "- ✅ $scenario" >> "$SUMMARY_FILE"
  done
fi

cat >> "$SUMMARY_FILE" << SUMMARY_EOF

### Failed Scenarios

SUMMARY_EOF

if [ ${#FAIL_SCENARIOS[@]} -eq 0 ]; then
  echo "None" >> "$SUMMARY_FILE"
else
  for scenario in "${FAIL_SCENARIOS[@]}"; do
    echo "- ❌ $scenario" >> "$SUMMARY_FILE"
  done
fi

cat >> "$SUMMARY_FILE" << SUMMARY_EOF

## Next Steps

SUMMARY_EOF

if [ $FAIL_COUNT -eq 0 ]; then
  cat >> "$SUMMARY_FILE" << SUMMARY_EOF
All tests passed! Implementation meets requirements.

**Ready to:**
- Commit changes with test evidence
- Release new version
- Deploy to production
SUMMARY_EOF
else
  cat >> "$SUMMARY_FILE" << SUMMARY_EOF
$FAIL_COUNT scenario(s) failed. Review individual logs for details:

SUMMARY_EOF
  
  for scenario in "${FAIL_SCENARIOS[@]}"; do
    echo "- \`$SCENARIOS_DIR/$scenario.log\`" >> "$SUMMARY_FILE"
  done
  
  cat >> "$SUMMARY_FILE" << SUMMARY_EOF

**Action required:**
1. Review failure evidence in scenario logs
2. Fix implementation to meet requirements
3. Re-run failed scenarios: \`./tests/run-tests.sh <command>\`
4. Verify all tests pass before committing
SUMMARY_EOF
fi

# Display summary
echo -e "${BLUE}=========================================${NC}"
echo -e "${BLUE}Test Results${NC}"
echo -e "${BLUE}=========================================${NC}"
echo ""

if [ ${#PASS_SCENARIOS[@]} -gt 0 ]; then
  for scenario in "${PASS_SCENARIOS[@]}"; do
    echo -e "${GREEN}✅ PASS: $scenario${NC}"
  done
fi

if [ ${#FAIL_SCENARIOS[@]} -gt 0 ]; then
  for scenario in "${FAIL_SCENARIOS[@]}"; do
    echo -e "${RED}❌ FAIL: $scenario${NC}"
  done
fi

echo ""
echo -e "${BLUE}Results: $PASS_COUNT/$TOTAL_COUNT passed${NC}"
echo ""

if [ $FAIL_COUNT -eq 0 ]; then
  echo -e "${GREEN}✅ All scenarios passed!${NC}"
  EXIT_CODE=0
else
  echo -e "${RED}❌ $FAIL_COUNT scenario(s) failed${NC}"
  echo ""
  echo "Review the failure logs:"
  for scenario in "${FAIL_SCENARIOS[@]}"; do
    echo "  - $SCENARIOS_DIR/$scenario.log"
  done
  EXIT_CODE=1
fi

echo ""
echo "Summary saved to: $SUMMARY_FILE"

# Generate JUnit XML
JUNIT_FILE="$RESULTS_DIR/junit.xml"

cat > "$JUNIT_FILE" << JUNIT_HEADER
<?xml version="1.0" encoding="UTF-8"?>
<testsuites name="spectacular" tests="$TOTAL_COUNT" failures="$FAIL_COUNT" time="0">
  <testsuite name="execute" tests="$TOTAL_COUNT" failures="$FAIL_COUNT" time="0">
JUNIT_HEADER

# Add test cases
for test_case in "${TEST_CASES[@]}"; do
  IFS='|' read -r name status failure_msg <<< "$test_case"

  # XML-escape the failure message
  failure_msg_escaped=$(echo "$failure_msg" | sed 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g; s/"/\&quot;/g')

  if [ "$status" = "pass" ]; then
    cat >> "$JUNIT_FILE" << TESTCASE_PASS
    <testcase name="$name" classname="spectacular.execute" time="0"/>
TESTCASE_PASS
  else
    cat >> "$JUNIT_FILE" << TESTCASE_FAIL
    <testcase name="$name" classname="spectacular.execute" time="0">
      <failure message="Test scenario failed">$failure_msg_escaped

See detailed evidence: tests/results/$(basename "$RESULTS_DIR")/scenarios/$name.log</failure>
    </testcase>
TESTCASE_FAIL
  fi
done

cat >> "$JUNIT_FILE" << JUNIT_FOOTER
  </testsuite>
</testsuites>
JUNIT_FOOTER

echo "JUnit XML saved to: $JUNIT_FILE"
echo ""

exit $EXIT_CODE
