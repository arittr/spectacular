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

for log_file in "$SCENARIOS_DIR"/*.log; do
  if [ ! -f "$log_file" ]; then
    continue
  fi
  
  SCENARIO_NAME=$(basename "$log_file" .log)
  
  if grep -q "^✅ PASS" "$log_file"; then
    PASS_COUNT=$((PASS_COUNT + 1))
    PASS_SCENARIOS+=("$SCENARIO_NAME")
  elif grep -q "^❌ FAIL" "$log_file"; then
    FAIL_COUNT=$((FAIL_COUNT + 1))
    FAIL_SCENARIOS+=("$SCENARIO_NAME")
  else
    echo -e "${YELLOW}⚠️  Warning: Ambiguous result in $SCENARIO_NAME${NC}"
    FAIL_COUNT=$((FAIL_COUNT + 1))
    FAIL_SCENARIOS+=("$SCENARIO_NAME (ambiguous)")
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
echo ""

exit $EXIT_CODE
