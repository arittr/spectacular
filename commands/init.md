---
description: Initialize spectacular environment - install dependencies, configure git, and validate setup
---

You are initializing the spectacular environment for spec-anchored development.

## Purpose

This command ensures all required dependencies and configuration are in place:
- Superpowers plugin installed
- Git-spice installed and configured
- Gitignore configured for spectacular workflows
- Project structure validated

## Workflow

### Step 1: Check Superpowers Plugin

Check if superpowers is installed:

```bash
if [ -d ~/.claude/plugins/cache/superpowers ]; then
  echo "✅ Superpowers plugin is installed"
  SUPERPOWERS_VERSION=$(cd ~/.claude/plugins/cache/superpowers && git describe --tags 2>/dev/null || echo "unknown")
  echo "   Version: $SUPERPOWERS_VERSION"
else
  echo "❌ Superpowers plugin NOT installed"
  echo ""
  echo "Spectacular requires the superpowers plugin for core skills:"
  echo "  - brainstorming"
  echo "  - subagent-driven-development"
  echo "  - requesting-code-review"
  echo "  - verification-before-completion"
  echo "  - finishing-a-development-branch"
  echo ""
  echo "Install with:"
  echo "  /plugin install superpowers@superpowers-marketplace"
  echo ""
  SUPERPOWERS_MISSING=true
fi
```

### Step 2: Check Git-Spice

Verify git-spice is installed and accessible:

```bash
if command -v gs &> /dev/null; then
  echo "✅ Git-spice is installed"
  GS_VERSION=$(gs --version 2>&1 | head -1)
  echo "   $GS_VERSION"

  # Check if we're in a git repo
  if git rev-parse --git-dir > /dev/null 2>&1; then
    # Check if git-spice is initialized
    if gs ls &> /dev/null; then
      echo "✅ Git-spice is initialized for this repo"
    else
      echo "⚠️  Git-spice not initialized for this repo"
      echo ""
      echo "Initialize with:"
      echo "  gs repo init"
      echo ""
      GS_NOT_INITIALIZED=true
    fi
  fi
else
  echo "❌ Git-spice NOT installed"
  echo ""
  echo "Spectacular uses git-spice for stacked branch management."
  echo ""
  echo "Install instructions:"
  echo "  macOS: brew install git-spice"
  echo "  Linux: See https://github.com/abhinav/git-spice"
  echo ""
  GS_MISSING=true
fi
```

### Step 3: Configure Gitignore

Ensure .gitignore has spectacular-specific entries:

```bash
if [ -f .gitignore ]; then
  echo "✅ .gitignore exists"

  # Check for .worktrees/ entry
  if grep -q "^\.worktrees/" .gitignore 2>/dev/null; then
    echo "   ✅ .worktrees/ already in .gitignore"
  else
    echo "   ⚠️  Adding .worktrees/ to .gitignore"
    echo "" >> .gitignore
    echo "# Spectacular parallel execution worktrees" >> .gitignore
    echo ".worktrees/" >> .gitignore
    echo "   ✅ Added .worktrees/ to .gitignore"
  fi

  # Check for specs/ is NOT ignored (we want specs tracked)
  if grep -q "^specs/" .gitignore 2>/dev/null; then
    echo "   ⚠️  WARNING: specs/ is gitignored - you probably want to track specs"
    echo "   Remove 'specs/' from .gitignore to track your specifications"
  else
    echo "   ✅ specs/ will be tracked (not in .gitignore)"
  fi
else
  echo "⚠️  No .gitignore found - creating one"
  cat > .gitignore << 'EOF'
# Spectacular parallel execution worktrees
.worktrees/

# Common patterns
node_modules/
.DS_Store
*.log
EOF
  echo "   ✅ Created .gitignore with spectacular patterns"
fi
```

### Step 4: Check Git Repository

Validate git setup:

```bash
if git rev-parse --git-dir > /dev/null 2>&1; then
  echo "✅ Git repository detected"

  # Check current branch
  CURRENT_BRANCH=$(git branch --show-current)
  echo "   Current branch: $CURRENT_BRANCH"

  # Check if there's a remote
  if git remote -v | grep -q .; then
    echo "   ✅ Remote configured"
    git remote -v | head -2 | sed 's/^/   /'
  else
    echo "   ⚠️  No remote configured"
    echo "   You may want to add a remote for PR submission"
  fi

  # Check working directory status
  if git diff --quiet && git diff --cached --quiet; then
    echo "   ✅ Working directory clean"
  else
    echo "   ℹ️  Uncommitted changes present"
  fi
else
  echo "❌ NOT a git repository"
  echo ""
  echo "Initialize git with:"
  echo "  git init"
  echo "  git add ."
  echo "  git commit -m 'Initial commit'"
  echo ""
  NOT_GIT_REPO=true
fi
```

### Step 5: Validate Project Structure

Check for expected directories:

```bash
echo ""
echo "Checking project structure..."

# Check/create specs directory
if [ -d specs ]; then
  echo "✅ specs/ directory exists"
  SPEC_COUNT=$(find specs -name "spec.md" 2>/dev/null | wc -l | tr -d ' ')
  echo "   Found $SPEC_COUNT specification(s)"
else
  echo "ℹ️  Creating specs/ directory"
  mkdir -p specs
  echo "   ✅ Created specs/ directory"
fi

# Check for .worktrees (should NOT exist yet, just checking)
if [ -d .worktrees ]; then
  echo "⚠️  .worktrees/ directory exists"
  WORKTREE_COUNT=$(ls -1 .worktrees 2>/dev/null | wc -l | tr -d ' ')
  if [ "$WORKTREE_COUNT" -gt 0 ]; then
    echo "   ⚠️  Contains $WORKTREE_COUNT worktree(s) - may be leftover from previous execution"
    echo "   Clean up with: git worktree list && git worktree remove <path>"
  fi
else
  echo "✅ No .worktrees/ directory (will be created during parallel execution)"
fi
```

### Step 6: Report Summary

Generate final status report:

```bash
echo ""
echo "========================================="
echo "Spectacular Initialization Summary"
echo "========================================="
echo ""

# Check if all critical dependencies are met
if [ -z "$SUPERPOWERS_MISSING" ] && [ -z "$GS_MISSING" ] && [ -z "$NOT_GIT_REPO" ]; then
  echo "✅ Environment ready for spectacular workflows!"
  echo ""
  echo "Next steps:"
  echo "  1. Generate a spec: /spectacular:spec \"your feature description\""
  echo "  2. Create a plan: /spectacular:plan @specs/{run-id}-{feature-slug}/spec.md"
  echo "  3. Execute: /spectacular:execute @specs/{run-id}-{feature-slug}/plan.md"
  echo ""

  if [ -n "$GS_NOT_INITIALIZED" ]; then
    echo "⚠️  Optional: Initialize git-spice with 'gs repo init'"
    echo ""
  fi
else
  echo "❌ Setup incomplete - resolve issues above before using spectacular"
  echo ""

  if [ -n "$SUPERPOWERS_MISSING" ]; then
    echo "REQUIRED: Install superpowers plugin"
    echo "  /plugin install superpowers@superpowers-marketplace"
    echo ""
  fi

  if [ -n "$GS_MISSING" ]; then
    echo "REQUIRED: Install git-spice"
    echo "  macOS: brew install git-spice"
    echo "  Linux: https://github.com/abhinav/git-spice"
    echo ""
  fi

  if [ -n "$NOT_GIT_REPO" ]; then
    echo "REQUIRED: Initialize git repository"
    echo "  git init"
    echo ""
  fi

  echo "Run /spectacular:init again after resolving issues"
fi

echo "========================================="
```

## What Gets Checked

### Required Dependencies
- ✅ Superpowers plugin (for core skills)
- ✅ Git-spice (for stacked branch management)
- ✅ Git repository (for version control)

### Configuration
- ✅ .gitignore configured (.worktrees/, specs/ handling)
- ✅ Git remote configured (optional but recommended)
- ✅ Git-spice initialized (optional but recommended)

### Project Structure
- ✅ specs/ directory created
- ✅ .worktrees/ directory status checked
- ✅ Working directory status

## Example Output

**Successful initialization:**
```
✅ Superpowers plugin is installed
   Version: v3.2.1
✅ Git-spice is installed
   git-spice version 0.5.0
✅ Git-spice is initialized for this repo
✅ .gitignore exists
   ✅ .worktrees/ already in .gitignore
   ✅ specs/ will be tracked (not in .gitignore)
✅ Git repository detected
   Current branch: main
   ✅ Remote configured
   origin  git@github.com:user/repo.git (fetch)
   origin  git@github.com:user/repo.git (push)
   ✅ Working directory clean
✅ specs/ directory exists
   Found 3 specification(s)
✅ No .worktrees/ directory (will be created during parallel execution)

=========================================
Spectacular Initialization Summary
=========================================

✅ Environment ready for spectacular workflows!

Next steps:
  1. Generate a spec: /spectacular:spec "your feature description"
  2. Create a plan: /spectacular:plan @specs/{run-id}-{feature-slug}/spec.md
  3. Execute: /spectacular:execute @specs/{run-id}-{feature-slug}/plan.md

=========================================
```

**Missing dependencies:**
```
❌ Superpowers plugin NOT installed

Spectacular requires the superpowers plugin for core skills:
  - brainstorming
  - subagent-driven-development
  - requesting-code-review
  - verification-before-completion
  - finishing-a-development-branch

Install with:
  /plugin install superpowers@superpowers-marketplace

❌ Git-spice NOT installed

Spectacular uses git-spice for stacked branch management.

Install instructions:
  macOS: brew install git-spice
  Linux: See https://github.com/abhinav/git-spice

=========================================
Spectacular Initialization Summary
=========================================

❌ Setup incomplete - resolve issues above before using spectacular

REQUIRED: Install superpowers plugin
  /plugin install superpowers@superpowers-marketplace

REQUIRED: Install git-spice
  macOS: brew install git-spice
  Linux: https://github.com/abhinav/git-spice

Run /spectacular:init again after resolving issues
=========================================
```

Now run the initialization check.
