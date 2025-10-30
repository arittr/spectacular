#!/bin/bash

# Session-start hook for spectacular plugin
# Injects using-spectacular skill into every Claude Code session

set -euo pipefail

# Get the directory where this script lives
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# Path to the using-spectacular skill
SKILL_FILE="$PLUGIN_DIR/skills/using-spectacular/SKILL.md"

# Check if skill file exists
if [ ! -f "$SKILL_FILE" ]; then
  echo "{\"hookEventName\": \"SessionStart\", \"additionalContext\": \"⚠️  using-spectacular skill not found at $SKILL_FILE\"}"
  exit 0
fi

# Read the skill file and use jq to properly escape for JSON
# jq -Rs reads the entire file as a single string and escapes it properly
SKILL_CONTENT=$(cat "$SKILL_FILE" | jq -Rs .)

# Output JSON with the skill content injected as additional context
cat <<EOF
{
  "hookEventName": "SessionStart",
  "additionalContext": $SKILL_CONTENT
}
EOF
