---
name: validating-environment
description: Use to validate spectacular environment - checks superpowers plugin, git-spice, git repo, and project structure before running spectacular workflows
---

# Validating Environment

## Overview

This skill validates that all required dependencies and configuration are in place for spectacular workflows. It checks for the superpowers plugin, git-spice installation, git repository status, and project structure. It also detects whether the workspace is single-repo or multi-repo.

## When to Use

Use this skill when:
- Starting a new spectacular session
- Running `/spectacular:init` command
- Before beginning any spectacular workflow to ensure prerequisites are met
- Troubleshooting spectacular setup issues

**Announce:** "I'm using validating-environment to check the spectacular setup."

## The Process

### Step 1: Check Superpowers Plugin

Check if superpowers is installed:

```bash
if [ -d ~/.claude/plugins/cache/superpowers ]; then
  echo "Superpowers plugin is installed"
  SUPERPOWERS_VERSION=$(cd ~/.claude/plugins/cache/superpowers && git describe --tags 2>/dev/null || echo "unknown")
  echo "   Version: $SUPERPOWERS_VERSION"
else
  echo "Superpowers plugin NOT installed"
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
  echo "Git-spice is installed"
  GS_VERSION=$(gs --version 2>&1 | head -1)
  echo "   $GS_VERSION"

  # Check if we're in a git repo
  if git rev-parse --git-dir > /dev/null 2>&1; then
    # Check if git-spice is initialized
    if gs ls &> /dev/null; then
      echo "Git-spice is initialized for this repo"
    else
      echo "Git-spice not initialized for this repo"
      echo ""
      echo "Initialize with:"
      echo "  gs repo init"
      echo ""
      GS_NOT_INITIALIZED=true
    fi
  fi
else
  echo "Git-spice NOT installed"
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
  echo ".gitignore exists"

  # Check for .worktrees/ entry
  if grep -q "^\.worktrees/" .gitignore 2>/dev/null; then
    echo "   .worktrees/ already in .gitignore"
  else
    echo "   Adding .worktrees/ to .gitignore"
    echo "" >> .gitignore
    echo "# Spectacular parallel execution worktrees" >> .gitignore
    echo ".worktrees/" >> .gitignore
    echo "   Added .worktrees/ to .gitignore"
  fi

  # Check for specs/ is NOT ignored (we want specs tracked)
  if grep -q "^specs/" .gitignore 2>/dev/null; then
    echo "   WARNING: specs/ is gitignored - you probably want to track specs"
    echo "   Remove 'specs/' from .gitignore to track your specifications"
  else
    echo "   specs/ will be tracked (not in .gitignore)"
  fi
else
  echo "No .gitignore found - creating one"
  cat > .gitignore << 'EOF'
# Spectacular parallel execution worktrees
.worktrees/

# Common patterns
node_modules/
.DS_Store
*.log
EOF
  echo "   Created .gitignore with spectacular patterns"
fi
```

### Step 4: Check Git Repository

Validate git setup:

```bash
if git rev-parse --git-dir > /dev/null 2>&1; then
  echo "Git repository detected"

  # Check current branch
  CURRENT_BRANCH=$(git branch --show-current)
  echo "   Current branch: $CURRENT_BRANCH"

  # Check if there's a remote
  if git remote -v | grep -q .; then
    echo "   Remote configured"
    git remote -v | head -2 | sed 's/^/   /'
  else
    echo "   No remote configured"
    echo "   You may want to add a remote for PR submission"
  fi

  # Check working directory status
  if git diff --quiet && git diff --cached --quiet; then
    echo "   Working directory clean"
  else
    echo "   Uncommitted changes present"
  fi
else
  echo "NOT a git repository"
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
  echo "specs/ directory exists"
  SPEC_COUNT=$(find specs -name "spec.md" 2>/dev/null | wc -l | tr -d ' ')
  echo "   Found $SPEC_COUNT specification(s)"
else
  echo "Creating specs/ directory"
  mkdir -p specs
  echo "   Created specs/ directory"
fi

# Check for .worktrees (should NOT exist yet, just checking)
if [ -d .worktrees ]; then
  echo ".worktrees/ directory exists"
  WORKTREE_COUNT=$(ls -1 .worktrees 2>/dev/null | wc -l | tr -d ' ')
  if [ "$WORKTREE_COUNT" -gt 0 ]; then
    echo "   Contains $WORKTREE_COUNT worktree(s) - may be leftover from previous execution"
    echo "   Clean up with: git worktree list && git worktree remove <path>"
  fi
else
  echo "No .worktrees/ directory (will be created during parallel execution)"
fi
```

### Step 6: Multi-Repo Detection

Detect whether the workspace is single-repo or multi-repo:

```bash
echo ""
echo "Detecting workspace mode..."

# Detect workspace mode by looking for multiple .git directories
# In multi-repo setups, there are typically multiple repos in the parent directory
REPO_COUNT=$(find . -maxdepth 2 -name ".git" -type d 2>/dev/null | wc -l | tr -d ' ')
if [ "$REPO_COUNT" -gt 1 ]; then
  echo "Multi-repo workspace detected ($REPO_COUNT repos)"
  WORKSPACE_MODE="multi-repo"

  # List detected repos
  echo "   Detected repositories:"
  find . -maxdepth 2 -name ".git" -type d 2>/dev/null | while read gitdir; do
    repo_path=$(dirname "$gitdir")
    echo "   - $repo_path"
  done
else
  echo "Single-repo mode"
  WORKSPACE_MODE="single-repo"
fi
```

### Step 7: Report Summary

Generate final status report:

```bash
echo ""
echo "========================================="
echo "Spectacular Initialization Summary"
echo "========================================="
echo ""

# Report workspace mode
if [ "$WORKSPACE_MODE" = "multi-repo" ]; then
  echo "Workspace Mode: Multi-repo"
else
  echo "Workspace Mode: Single-repo"
fi
echo ""

# Check if all critical dependencies are met
if [ -z "$SUPERPOWERS_MISSING" ] && [ -z "$GS_MISSING" ] && [ -z "$NOT_GIT_REPO" ]; then
  echo "Environment ready for spectacular workflows!"
  echo ""
  echo "Next steps:"
  echo "  1. Generate a spec: /spectacular:spec \"your feature description\""
  echo "  2. Create a plan: /spectacular:plan @specs/{run-id}-{feature-slug}/spec.md"
  echo "  3. Execute: /spectacular:execute @specs/{run-id}-{feature-slug}/plan.md"
  echo ""

  if [ -n "$GS_NOT_INITIALIZED" ]; then
    echo "Optional: Initialize git-spice with 'gs repo init'"
    echo ""
  fi
else
  echo "Setup incomplete - resolve issues above before using spectacular"
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

## Quality Rules

1. **All checks must complete** - Do not skip any validation step
2. **Clear status indicators** - Use consistent status messages for pass/fail/warning
3. **Actionable guidance** - Every failure must include instructions for resolution
4. **Non-destructive** - Only create directories and modify .gitignore; never delete or overwrite existing content
5. **Idempotent** - Running multiple times should produce the same result

## Error Handling

### Superpowers Plugin Missing

If superpowers is not installed:
1. Report the missing dependency clearly
2. Explain why it's required (list the dependent skills)
3. Provide exact installation command
4. Mark initialization as incomplete

### Git-Spice Missing

If git-spice is not installed:
1. Report the missing dependency
2. Explain its purpose (stacked branch management)
3. Provide installation instructions for multiple platforms
4. Mark initialization as incomplete

### Git-Spice Not Initialized

If git-spice is installed but not initialized for this repo:
1. Report as a warning (not a blocker)
2. Provide the initialization command
3. Continue with remaining checks

### Not a Git Repository

If the current directory is not a git repository:
1. Report as a critical failure
2. Provide git initialization commands
3. Mark initialization as incomplete

### Stale Worktrees

If .worktrees/ exists with content:
1. Report as a warning
2. Explain these may be from a previous incomplete execution
3. Provide cleanup commands
4. Continue with remaining checks

### Multi-Repo Workspace

If multiple repositories are detected:
1. Report the workspace mode
2. List detected repositories
3. Continue with single-repo validation for the current directory
4. Note: Full multi-repo support is planned for future versions
