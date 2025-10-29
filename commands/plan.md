---
description: Decompose feature spec into executable plan with automatic phase analysis and sequential/parallel strategy
---

You are creating an execution plan from a feature specification.

## Input

User will provide: `/spectacular:plan {spec-path}`

Example: `/spectacular:plan @specs/a1b2c3-magic-link-auth/spec.md`

Where `a1b2c3` is the runId and `magic-link-auth` is the feature slug.

## Workflow

### Step 0: Extract Run ID and Feature Slug from Spec

**First action**: Read the spec and extract the RUN_ID from frontmatter and determine the spec directory.

```bash
# Extract runId from spec frontmatter
RUN_ID=$(grep "^runId:" {spec-path} | awk '{print $2}')
echo "RUN_ID: $RUN_ID"

# Get spec directory (e.g., specs/bdc63b-wikipedia-import/)
SPEC_DIR=$(dirname {spec-path})

# Extract feature slug from directory name pattern: {run-id}-{feature-slug}
FEATURE_SLUG=$(basename $SPEC_DIR | sed "s/^${RUN_ID}-//")
echo "FEATURE_SLUG: $FEATURE_SLUG"
```

**If RUN_ID not found:**
Generate one now (for backwards compatibility with old specs):

```bash
RUN_ID=$(echo "{feature-name}-$(date +%s)" | shasum -a 256 | head -c 6)
echo "Generated RUN_ID: $RUN_ID (spec missing runId)"
```

**Spec Directory Pattern:**
Specs follow the pattern: `specs/{run-id}-{feature-slug}/spec.md`
Plans are generated at: `specs/{run-id}-{feature-slug}/plan.md`

**Announce:** "Using RUN_ID: {run-id} for {feature-slug} implementation"

### Step 0.5: Switch to Worktree Context

**Second action**: After extracting RUN_ID, switch to the worktree created by `/spectacular:spec`.

```bash
# Get absolute repo root to avoid recursive paths
REPO_ROOT=$(git rev-parse --show-toplevel)

# Check if already in correct worktree (avoid double cd)
CURRENT_DIR=$(pwd)
if [[ "$CURRENT_DIR" == "${REPO_ROOT}/.worktrees/${RUN_ID}-main" ]] || [[ "$CURRENT_DIR" == *"/.worktrees/${RUN_ID}-main" ]]; then
  echo "Already in worktree ${RUN_ID}-main"
else
  # Switch to worktree using absolute path
  cd "${REPO_ROOT}/.worktrees/${RUN_ID}-main"
fi
```

**If worktree doesn't exist:**
Error immediately with clear message:

```markdown
❌ Worktree Not Found

The worktree for RUN_ID {run-id} doesn't exist.

Run `/spectacular:spec {feature}` first to create the workspace.

Expected worktree: .worktrees/{run-id}-main/
```

**IMPORTANT**: All subsequent operations happen in the worktree context.

- Spec is read from: `.worktrees/{run-id}-main/specs/{run-id}-{feature-slug}/spec.md`
- Plan will be written to: `.worktrees/{run-id}-main/specs/{run-id}-{feature-slug}/plan.md`
- No fallback to main repo (worktree is required)

### Step 1: Invoke Task Decomposition Skill

Announce: "I'm using the Task Decomposition skill to create an execution plan."

Use the `decomposing-tasks` skill to analyze the spec and create a plan.

**What the skill does:**

1. Reads the spec and extracts tasks from "Implementation Plan" section
2. Validates task quality (no XL tasks, explicit files, acceptance criteria, proper chunking)
3. Analyzes file dependencies between tasks
4. Groups tasks into phases (sequential or parallel)
5. Calculates execution time estimates with parallelization savings
6. Generates plan.md in the spec directory

**Critical validations:**

- ❌ XL tasks (>8h) → Must split before planning
- ❌ Missing files → Must specify exact paths
- ❌ Missing acceptance criteria → Must add 3-5 criteria
- ❌ Wildcard patterns (`src/**/*.ts`) → Must be explicit
- ❌ Too many S tasks (>30%) → Bundle into thematic M/L tasks

**Chunking Philosophy:**
Tasks should be PR-sized, thematically coherent units - not mechanical file splits.

- M (3-5h): Sweet spot - complete subsystem/layer/slice
- L (5-7h): Major units - full UI layer, complete API surface
- S (1-2h): Rare - only truly standalone work

**If validation fails:**
The skill will report issues and STOP. User must fix spec and re-run `/spectacular:plan`.

**If validation passes:**
The skill generates `specs/{run-id}-{feature-slug}/plan.md` with:

- RUN_ID in frontmatter (from Step 0)
- Feature slug in frontmatter
- Phase grouping (sequential/parallel strategies)
- Task dependencies and file analysis
- Execution time estimates
- Complete implementation details

**Plan frontmatter must include:**

```yaml
---
runId: { run-id }
feature: { feature-slug }
created: { YYYY-MM-DD }
status: ready
---
```

The runId and feature slug are extracted from the spec directory path: `specs/{run-id}-{feature-slug}/`

### Step 2: Review Plan Output

After skill completes, review the generated plan:

```bash
cat specs/{run-id}-{feature-slug}/plan.md
```

Verify:

- ✅ Phase strategies make sense (parallel for independent tasks)
- ✅ Dependencies are correct (based on file overlaps)
- ✅ No XL tasks (all split into M or smaller)
- ✅ Time savings calculation looks reasonable

### Step 2.5: Commit Plan to Worktree

After plan generation and review, commit the plan to the `{run-id}-main` branch in the worktree:

```bash
cd .worktrees/${RUN_ID}-main
git add specs/
git commit -m "plan: add ${FEATURE_SLUG} implementation plan [${RUN_ID}]"
```

This ensures the plan is tracked in the worktree branch and doesn't affect the main repo.

### Step 3: Report to User

**IMPORTANT**: After reporting completion, **STOP HERE**. Do not proceed to execution automatically. The user must review the plan and explicitly run `/spectacular:execute` when ready.

Provide comprehensive summary:

````markdown
✅ Execution Plan Generated & Committed

**RUN_ID**: {run-id}
**Feature**: {feature-slug}
**Location**: .worktrees/{run-id}-main/specs/{run-id}-{feature-slug}/plan.md
**Branch**: {run-id}-main (committed in worktree)

## Plan Summary

**Phases**: {count}

- Sequential: {count} phases ({tasks} tasks)
- Parallel: {count} phases ({tasks} tasks)

**Tasks**: {total-count}

- L (4-8h): {count}
- M (2-4h): {count}
- S (1-2h): {count}

## Time Estimates

**Sequential Execution**: {hours}h
**With Parallelization**: {hours}h
**Time Savings**: {hours}h ({percent}% faster)

## Parallelization Opportunities

{For each parallel phase:}

- **Phase {id}**: {task-count} tasks can run simultaneously
  - Tasks: {task-names}
  - Time: {sequential}h → {parallel}h
  - Savings: {hours}h

## Next Steps (User Actions - DO NOT AUTO-EXECUTE)

**The plan command is complete. The following are suggestions for the user, not instructions to execute automatically.**

### 1. Review the Plan

```bash
cat .worktrees/{run-id}-main/specs/{run-id}-{feature-slug}/plan.md
```

Verify task breakdown, dependencies, and estimates are correct.

### 2. Execute the Plan (when ready)

```bash
/spectacular:execute @.worktrees/{run-id}-main/specs/{run-id}-{feature-slug}/plan.md
```

This is a separate command. Only run after reviewing the plan.

### 3. Modify Plan (if needed)

```bash
# Edit the plan file directly
vim .worktrees/{run-id}-main/specs/{run-id}-{feature-slug}/plan.md

# Commit changes
cd .worktrees/{run-id}-main
git add specs/
git commit -m "plan: adjust task breakdown [${RUN_ID}]"

# Then execute
/spectacular:execute @.worktrees/{run-id}-main/specs/{run-id}-{feature-slug}/plan.md
```

````

## Error Handling

### Missing Worktree

If the worktree doesn't exist when trying to switch context:

```markdown
❌ Worktree Not Found

The worktree for RUN_ID {run-id} doesn't exist at .worktrees/{run-id}-main/

This means `/spectacular:spec` hasn't been run yet for this feature.

## Resolution

1. Run `/spectacular:spec {feature-description}` first to create the worktree
2. Then run `/spectacular:plan @.worktrees/{run-id}-main/specs/{run-id}-{feature-slug}/spec.md`

Or if you have an existing spec in the main repo, it needs to be migrated to a worktree first.
```

### Validation Failures

If the skill finds quality issues:

```markdown
❌ Plan Generation Failed - Spec Quality Issues

The spec has issues that prevent task decomposition:

**CRITICAL Issues** (must fix):
- Task 3: XL complexity (12h estimated) - split into M/L tasks
- Task 5: No files specified - add explicit file paths
- Task 7: No acceptance criteria - add 3-5 testable criteria
- Too many S tasks (5 of 8 = 63%) - bundle into thematic M/L tasks

**HIGH Issues** (strongly recommend):
- Task 2 (S - 1h): "Add routes" - bundle with UI components task
- Task 4 (S - 2h): "Create schemas" - bundle with agent or service task
- Task 6: Wildcard pattern `src/**/*.ts` - specify exact files

## Fix These Issues

1. Edit the spec at {spec-path}
2. Address all CRITICAL issues (required)
3. Consider fixing HIGH issues (recommended)
4. Bundle S tasks into thematic M/L tasks for better PR structure
5. Re-run: `/spectacular:plan @{spec-path}`
````

### No Tasks Found

If spec has no "Implementation Plan" section:

````markdown
❌ Cannot Generate Plan - No Tasks Found

The spec at {spec-path} doesn't have an "Implementation Plan" section with tasks.

Use `/spectacular:spec` to generate a complete spec with task breakdown first:

```bash
/spectacular:spec "your feature description"
```
````

Then run `/spectacular:plan` on the generated spec.

````

### Circular Dependencies

If tasks have circular dependencies:

```markdown
❌ Circular Dependencies Detected

The task dependency graph has cycles:
- Task A depends on Task B
- Task B depends on Task C
- Task C depends on Task A

This makes execution impossible.

## Resolution

Review the task file dependencies in the spec:
1. Check which files each task modifies
2. Ensure dependencies flow in one direction
3. Consider splitting tasks to break cycles
4. Re-run `/spectacular:plan` after fixing
````

## Important Notes

- **Automatic strategy selection** - Skill analyzes dependencies and chooses sequential vs parallel
- **File-based dependencies** - Tasks sharing files must run sequentially
- **Quality gates** - Validates before generating (prevents bad plans)
- **Architecture adherence** - All tasks must follow project constitution at @docs/constitutions/current/

Now generate the plan from: {spec-path}
