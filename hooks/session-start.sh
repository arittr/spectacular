#!/bin/bash

# Spectacular session start hook
# Provides context about spec-anchored development workflows

# Check if superpowers is installed
SUPERPOWERS_MISSING=""
if [ ! -d ~/.claude/plugins/cache/superpowers ]; then
  SUPERPOWERS_MISSING="true"
fi

# Check if in a project with specs/ directory (active spectacular usage)
IN_SPECTACULAR_PROJECT=""
if [ -d "specs" ]; then
  IN_SPECTACULAR_PROJECT="true"
fi

# Build context message
CONTEXT=""

if [ -n "$SUPERPOWERS_MISSING" ]; then
  CONTEXT="⚠️  **Spectacular requires superpowers plugin**

Spectacular extends superpowers with spec-anchored development workflows.

Install superpowers:
\`\`\`bash
/plugin install superpowers@superpowers-marketplace
\`\`\`

After installing superpowers, you can use spectacular commands."
else
  # Superpowers is installed - provide workflow reminder
  if [ -n "$IN_SPECTACULAR_PROJECT" ]; then
    CONTEXT="📋 **Spectacular workflow active**

Detected \`specs/\` directory. Remember the workflow:

1. \`/spectacular:spec\` - Generate specification
2. \`/spectacular:plan\` - Decompose into tasks
3. \`/spectacular:execute\` - Run with parallel orchestration

All work follows \`@docs/constitutions/current/\` if present."
  fi
fi

# Only output if there's context to provide
if [ -n "$CONTEXT" ]; then
  cat <<EOF
{
  "event": "SessionStart",
  "context": $(echo "$CONTEXT" | jq -Rs .)
}
EOF
fi
