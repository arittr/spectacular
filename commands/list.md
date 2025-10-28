---
description: List all active Spectacular features with status and staleness
---

You are listing all active Spectacular features to provide visibility into concurrent work.

## Purpose

This command shows all active Spectacular features with their current status:
- Detects worktrees created by `/spectacular:execute`
- Shows phase progression (spec only | spec+plan | executed)
- Identifies orphaned worktrees (no corresponding spec)
- Calculates staleness against default branch
- Helps users track concurrent features and cleanup stale work

## Workflow

### Step 1: Cleanup Stale Worktree References

First, prune any stale worktree references:

```bash
echo "Cleaning up stale worktree references..."
git worktree prune
echo ""
```

### Step 2: Detect Default Branch

Detect the repository's default branch using 3-tier fallback:

```bash
# Tier 1: Check origin's HEAD
DEFAULT_BRANCH=$(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's@^refs/remotes/origin/@@')

# Tier 2: Check git config
if [ -z "$DEFAULT_BRANCH" ]; then
  DEFAULT_BRANCH=$(git config init.defaultBranch)
fi

# Tier 3: Assume 'main' and warn
if [ -z "$DEFAULT_BRANCH" ]; then
  DEFAULT_BRANCH="main"
  echo "⚠️  Could not detect default branch - assuming 'main'"
  echo "   Set with: git config init.defaultBranch <branch-name>"
  echo "   Or point origin/HEAD: git remote set-head origin <branch-name>"
  echo ""
fi
```

### Step 3: Find All Main Worktrees

List all `.worktrees/main-*` directories created by Spectacular:

```bash
echo "Active Spectacular Features:"
echo "==========================================="
echo ""

# Check if .worktrees directory exists
if [ ! -d .worktrees ]; then
  echo "No active Spectacular features"
  echo ""
  echo "Start a new feature with:"
  echo "  /spectacular:spec \"feature description\""
  echo "  /spectacular:plan @specs/{run-id}-{feature-slug}/spec.md"
  echo "  /spectacular:execute @specs/{run-id}-{feature-slug}/plan.md"
  exit 0
fi

# Find all main-* worktrees
WORKTREES=$(find .worktrees -maxdepth 1 -type d -name "main-*" 2>/dev/null | sort)

if [ -z "$WORKTREES" ]; then
  echo "No active Spectacular features"
  echo ""
  echo "(.worktrees/ exists but contains no main-* directories)"
  exit 0
fi
```

### Step 4: Analyze Each Worktree

For each worktree, detect phase, staleness, and orphaned status:

```bash
# Process each worktree
echo "$WORKTREES" | while IFS= read -r WORKTREE_PATH; do
  # Extract runId and feature slug from directory name
  # Format: .worktrees/main-{runId}-{feature-slug}
  DIR_NAME=$(basename "$WORKTREE_PATH")

  # Parse: main-{runId}-{feature-slug}
  RUN_ID=$(echo "$DIR_NAME" | sed 's/^main-//' | cut -d'-' -f1)
  FEATURE_SLUG=$(echo "$DIR_NAME" | sed 's/^main-//' | cut -d'-' -f2-)

  # Calculate age from directory mtime
  if [[ "$OSTYPE" == "darwin"* ]]; then
    # macOS
    MTIME=$(stat -f %m "$WORKTREE_PATH")
    NOW=$(date +%s)
  else
    # Linux
    MTIME=$(stat -c %Y "$WORKTREE_PATH")
    NOW=$(date +%s)
  fi

  AGE_SECONDS=$((NOW - MTIME))

  # Format age in human-readable units
  if [ $AGE_SECONDS -lt 3600 ]; then
    AGE="$((AGE_SECONDS / 60))m ago"
  elif [ $AGE_SECONDS -lt 86400 ]; then
    AGE="$((AGE_SECONDS / 3600))h ago"
  else
    AGE="$((AGE_SECONDS / 86400))d ago"
  fi

  # Check if orphaned (no spec.md in worktree)
  SPEC_FILE=$(find "$WORKTREE_PATH/specs" -name "spec.md" -path "*/$RUN_ID-*" 2>/dev/null | head -1)

  if [ -z "$SPEC_FILE" ]; then
    # Orphaned worktree
    echo "$RUN_ID: (orphaned) ($AGE) - run /spectacular:cleanup $RUN_ID"
    continue
  fi

  # Detect phase
  PLAN_FILE=$(find "$WORKTREE_PATH/specs" -name "plan.md" -path "*/$RUN_ID-*" 2>/dev/null | head -1)

  if [ -z "$PLAN_FILE" ]; then
    PHASE="spec only"
  else
    # Check if branches were created (execution started)
    BRANCH_COUNT=$(git branch | grep "^  $RUN_ID-" | wc -l | tr -d ' ')

    if [ "$BRANCH_COUNT" -eq 0 ]; then
      PHASE="spec+plan"
    else
      PHASE="executed: $BRANCH_COUNT branches"
    fi
  fi

  # Calculate staleness (commits behind default branch)
  # cd into worktree to check its state
  cd "$WORKTREE_PATH" || continue

  # Get commits behind default branch
  COMMITS_BEHIND=$(git rev-list --count HEAD..$DEFAULT_BRANCH 2>/dev/null || echo "0")

  cd - > /dev/null || exit

  # Format output line
  OUTPUT="$RUN_ID: $FEATURE_SLUG ($AGE) [$PHASE]"

  if [ "$COMMITS_BEHIND" -gt 0 ]; then
    OUTPUT="$OUTPUT ⚠️  $COMMITS_BEHIND commits behind $DEFAULT_BRANCH"
  fi

  echo "$OUTPUT"
done

echo ""
echo "==========================================="
```

### Step 5: Document Staleness Refresh

Provide guidance on refreshing stale worktrees:

```bash
echo ""
echo "Staleness Refresh Workflow:"
echo ""
echo "If a worktree shows staleness warning (⚠️), refresh it by:"
echo ""
echo "1. cd into the worktree:"
echo "   cd .worktrees/main-{runId}-{feature-slug}"
echo ""
echo "2. Use git-spice to sync with default branch:"
echo "   gs stack restack"
echo ""
echo "   This will rebase the entire stack onto the latest $DEFAULT_BRANCH"
echo ""
echo "Alternative (if not using git-spice stacks):"
echo "   git fetch origin $DEFAULT_BRANCH"
echo "   git merge origin/$DEFAULT_BRANCH"
echo ""
echo "See the 'using-git-spice' skill for more advanced stacking workflows."
echo ""
```

## Example Output

**Successful listing with mixed states:**

```
Cleaning up stale worktree references...

Active Spectacular Features:
===========================================

91a61e: worktree-isolation (2h ago) [spec+plan]
7f3c2a: auth-system (1d ago) [executed: 5 branches] ⚠️  12 commits behind main
a1b2c3: (orphaned) (3h ago) - run /spectacular:cleanup a1b2c3

===========================================

Staleness Refresh Workflow:

If a worktree shows staleness warning (⚠️), refresh it by:

1. cd into the worktree:
   cd .worktrees/main-{runId}-{feature-slug}

2. Use git-spice to sync with default branch:
   gs stack restack

   This will rebase the entire stack onto the latest main

Alternative (if not using git-spice stacks):
   git fetch origin main
   git merge origin/main

See the 'using-git-spice' skill for more advanced stacking workflows.
```

**No active features:**

```
Cleaning up stale worktree references...

Active Spectacular Features:
===========================================

No active Spectacular features

Start a new feature with:
  /spectacular:spec "feature description"
  /spectacular:plan @specs/{run-id}-{feature-slug}/spec.md
  /spectacular:execute @specs/{run-id}-{feature-slug}/plan.md
```

## What Gets Displayed

### For Each Active Worktree
- **Run ID**: 6-character identifier
- **Feature Slug**: Human-readable feature name
- **Age**: Time since worktree creation (m/h/d ago)
- **Phase**: Current stage
  - `spec only` - Specification created, no plan yet
  - `spec+plan` - Plan created, execution not started
  - `executed: N branches` - Execution in progress or completed
- **Staleness**: Warning if worktree is behind default branch

### For Orphaned Worktrees
- **Run ID**: 6-character identifier
- **Status**: `(orphaned)` - worktree exists but no spec found
- **Age**: Time since creation
- **Cleanup hint**: Suggests `/spectacular:cleanup {runId}`

## Default Branch Detection

The command uses a **3-tier fallback** to detect the repository's default branch:

1. **Tier 1 (Preferred)**: `git symbolic-ref refs/remotes/origin/HEAD`
   - Checks what origin/HEAD points to
   - Most reliable if origin is configured

2. **Tier 2 (Fallback)**: `git config init.defaultBranch`
   - Checks git's default branch configuration
   - Used if origin/HEAD not set

3. **Tier 3 (Last Resort)**: Assume `main`
   - Falls back to 'main' if neither above works
   - Displays warning to user

Users can fix detection by:
```bash
# Set origin/HEAD
git remote set-head origin <branch-name>

# Or configure git default
git config init.defaultBranch <branch-name>
```

## Staleness Calculation

For each worktree, the command:

1. Changes into the worktree directory
2. Runs `git rev-list --count HEAD..$DEFAULT_BRANCH`
3. Shows warning if commits behind > 0

This helps users identify when their feature work has diverged from the main branch and needs refreshing.

Now run the listing workflow.
