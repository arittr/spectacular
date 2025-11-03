#!/bin/bash
# Initialize git repositories in test fixtures
#
# Test fixtures are templates that need git+git-spice initialized before use.
# This script sets up each fixture as a valid git repository with git-spice.

set -e  # Exit on any error

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "Initializing test fixtures..."

for fixture in */; do
  # Skip if not a directory or if it's a hidden directory
  [[ ! -d "$fixture" ]] && continue
  [[ "$fixture" == .* ]] && continue

  fixture_name="${fixture%/}"
  echo ""
  echo "=== Initializing $fixture_name ==="

  cd "$fixture_name"

  # Check if already initialized
  if [ -d .git ]; then
    echo "  ⚠️  Already initialized (skipping)"
    cd ..
    continue
  fi

  # Initialize git repository
  echo "  📦 Initializing git repository..."
  git init
  git add .
  git commit -m "Initial commit"

  # Initialize git-spice
  echo "  🌶️  Initializing git-spice..."
  gs repo init --trunk main

  echo "  ✅ $fixture_name initialized successfully"

  cd ..
done

echo ""
echo "✅ All fixtures initialized!"
echo ""
echo "To validate fixtures are ready:"
echo "  ./validate-fixtures.sh"
