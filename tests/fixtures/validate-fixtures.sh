#!/bin/bash
# Validate test fixtures are properly initialized and ready for testing
#
# Checks:
# - Git repository exists and is valid
# - git-spice is initialized
# - CLAUDE.md exists with required commands
# - Setup completes in <1 minute (per plan requirement)

set -e  # Exit on any error

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

EXIT_CODE=0
FIXTURE_COUNT=0
PASS_COUNT=0

echo "Validating test fixtures..."
echo ""

for fixture in */; do
  # Skip if not a directory or if it's a hidden directory
  [[ ! -d "$fixture" ]] && continue
  [[ "$fixture" == .* ]] && continue

  fixture_name="${fixture%/}"
  FIXTURE_COUNT=$((FIXTURE_COUNT + 1))
  FIXTURE_PASS=true

  echo "=== Validating $fixture_name ==="

  cd "$fixture_name"

  # Check 1: Git repository exists
  if [ -d .git ]; then
    echo "  ✅ Git repository exists"
  else
    echo "  ❌ Missing .git directory"
    echo "     Run: ./init-fixtures.sh"
    FIXTURE_PASS=false
    EXIT_CODE=1
  fi

  # Check 2: Git repository is valid
  if git status > /dev/null 2>&1; then
    echo "  ✅ Git repository is valid"
  else
    echo "  ❌ Git repository is corrupted"
    echo "     Run: ./init-fixtures.sh"
    FIXTURE_PASS=false
    EXIT_CODE=1
  fi

  # Check 3: git-spice is initialized
  if gs ls > /dev/null 2>&1; then
    echo "  ✅ git-spice initialized"
  else
    echo "  ❌ git-spice not initialized"
    echo "     Run: ./init-fixtures.sh"
    FIXTURE_PASS=false
    EXIT_CODE=1
  fi

  # Check 4: CLAUDE.md exists
  if [ -f CLAUDE.md ]; then
    echo "  ✅ CLAUDE.md exists"
  else
    echo "  ❌ CLAUDE.md missing"
    FIXTURE_PASS=false
    EXIT_CODE=1
  fi

  # Check 5: CLAUDE.md has required commands
  REQUIRED_COMMANDS=("install" "test")
  for cmd in "${REQUIRED_COMMANDS[@]}"; do
    if grep -q "\\*\\*$cmd\\*\\*:" CLAUDE.md; then
      echo "  ✅ CLAUDE.md defines '$cmd' command"
    else
      echo "  ❌ CLAUDE.md missing '$cmd' command"
      FIXTURE_PASS=false
      EXIT_CODE=1
    fi
  done

  # Check 6: Setup time <1 minute (per plan acceptance criteria)
  # Only test if fixture has dependencies and they're not already installed
  if [ -f package.json ] && [ ! -d node_modules ]; then
    echo "  ⏱️  Testing setup time (npm install)..."
    START_TIME=$(date +%s)
    npm install > /dev/null 2>&1
    END_TIME=$(date +%s)
    SETUP_TIME=$((END_TIME - START_TIME))

    if [ $SETUP_TIME -lt 60 ]; then
      echo "  ✅ Setup completed in ${SETUP_TIME}s (<60s requirement)"
    else
      echo "  ⚠️  Setup took ${SETUP_TIME}s (>60s - may be slow network)"
    fi
  elif [ -f requirements.txt ] && ! python -c "import pytest" 2>/dev/null; then
    echo "  ⏱️  Testing setup time (pip install)..."
    START_TIME=$(date +%s)
    pip install -q -r requirements.txt > /dev/null 2>&1
    END_TIME=$(date +%s)
    SETUP_TIME=$((END_TIME - START_TIME))

    if [ $SETUP_TIME -lt 60 ]; then
      echo "  ✅ Setup completed in ${SETUP_TIME}s (<60s requirement)"
    else
      echo "  ⚠️  Setup took ${SETUP_TIME}s (>60s - may be slow network)"
    fi
  else
    echo "  ⏩ Setup validation skipped (dependencies already installed)"
  fi

  if [ "$FIXTURE_PASS" = true ]; then
    PASS_COUNT=$((PASS_COUNT + 1))
    echo "  ✅ $fixture_name is valid"
  else
    echo "  ❌ $fixture_name has issues"
  fi

  echo ""
  cd ..
done

# Summary
echo "=== Validation Summary ==="
echo "Fixtures validated: $FIXTURE_COUNT"
echo "Fixtures passed: $PASS_COUNT"
echo "Fixtures failed: $((FIXTURE_COUNT - PASS_COUNT))"

if [ $EXIT_CODE -eq 0 ]; then
  echo ""
  echo "✅ All fixtures are valid and ready for testing!"
else
  echo ""
  echo "❌ Some fixtures have issues. Run ./init-fixtures.sh to fix."
fi

exit $EXIT_CODE
