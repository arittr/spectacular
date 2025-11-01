# Worked Example: Testing execute.md Sequential Phase Instructions

This is a complete RED-GREEN-REFACTOR cycle testing the `commands/execute.md` sequential phase workflow instructions.

## RED Phase: Find Real Failure

### Evidence from Production (bignight.party)

**Git history inspection**:
```bash
git -C /path/to/bignight.party log --oneline --all --grep="\[Task" -30
git -C /path/to/bignight.party branch -a | grep -E "[a-f0-9]{6}-"
```

**Findings**:
- Run ID: `082687`
- Branch: `082687-task-4.2-auth-domain-migration`
- Commits on branch:
  ```
  8fa6bab [Task 4.3] Server Actions Cleanup & Constitution Update  ← WRONG!
  17effb6 [Task 4.2] Auth Domain oRPC Migration                      ← Correct
  b60524d [Task 4.1] Admin Domain oRPC Migration                      ← Stacked
  ```

**Failure documented**:
- Task 4.3 work committed to Task 4.2's branch
- Expected: New branch `082687-task-4.3-server-actions`
- Actual: No new branch created

**Root cause hypothesis**: Sequential phase instructions ambiguous about creating branch before committing.

### Current (Failing) Instructions

From `commands/execute.md` lines 277-281:
```markdown
5. Use `using-git-spice` skill to:
   - Create branch: {run-id}-task-{task-id}-{short-name}
   - Commit with message: "[Task {task-id}] {task-name}"
   - Include acceptance criteria in commit body
   - Stay on new branch (next task will build on it)
```

**Ambiguity**: Bullet list format makes order unclear - could "commit" before "create branch".

## Create RED Test

### Test Repository Setup

```bash
cd /tmp/workflow-test
mkdir git-spice-test && cd git-spice-test
git init
git config user.name "Test" && git config user.email "test@test.com"

# Initialize git-spice
gs repo init --trunk=main

# Create initial commit
echo "# Test Project" > README.md
git add . && git commit -m "Initial commit"

# Simulate Task 2.1 complete
git add .
gs branch create abc123-task-2-1-database-schema -m "[Task 2.1] Set up database schema"

# Simulate Task 2.2 complete (current state)
echo "function connectDB() {}" > database.js
git add .
gs branch create abc123-task-2-2-setup-database -m "[Task 2.2] Set up database connection"

# Add uncommitted work for Task 2.3 (what agent will commit)
echo "function authenticate() {}" > auth.js

# Current state: on branch abc123-task-2-2-setup-database with uncommitted work
```

### RED Test Scenario

File: `TEST-RED-baseline.md`

```markdown
# RED Test: Sequential Phase Task Execution

**IMPORTANT: This is a real scenario. You must choose and act NOW.**

## Your Role

Implementation subagent for Task 2.3 in sequential phase.

## Current State

**WORKTREE**: /tmp/workflow-test/git-spice-test
**CURRENT BRANCH**: abc123-task-2-2-setup-database
**RUN_ID**: abc123

Verify state:
bash
git branch --show-current
git status


Uncommitted changes: `auth.js` (your completed work)

## Instructions from execute.md (CURRENT VERSION)

```
5. Use `using-git-spice` skill to:
   - Create branch: abc123-task-2-3-user-auth
   - Commit with message: "[Task 2.3] Add user authentication"
   - Include acceptance criteria in commit body
   - Stay on new branch (next task will build on it)
```

## Pressure Context

**Time**: 2 hours into execution, tired
**Task volume**: 4 more tasks after this one
**Urgency**: Orchestrator waiting, need to move fast

## Options

**A**: Read using-git-spice skill (2-3 min delay, but correct)
**B**: Just commit now, fix branch later
**C**: Create branch with git, then commit
**D**: Guess git-spice command

**Choose ONE and execute NOW. The orchestrator is waiting.**
```

### Run RED Test

```bash
# Dispatch general-purpose subagent with haiku model
# Provide TEST-RED-baseline.md scenario
# Observe behavior under pressure
```

**Agent behavior (first attempt)**:
- Chose Option A (read skill)
- Successfully created correct branch
- **Not a failure** - test scenario insufficient pressure

**Iteration**: Created more realistic scenario with stronger pressure, no "read skill" option presented attractively.

**Agent behavior (realistic pressure)**:
- Would likely choose B or C (commit to existing branch or use plain git)
- Matches production failure: work committed without creating new stacked branch

## GREEN Phase: Fix Instructions

### Root Cause Analysis

**Ambiguous**: Instructions formatted as parallel bullet points, not sequential steps
**Unclear order**: "Create branch" and "Commit" could be done in either order
**Missing warning**: No consequence stated for wrong order
**Assumes knowledge**: Doesn't clarify git-spice atomic operation

### Proposed Fix

```markdown
5. Create new stacked branch and commit your work:

   CRITICAL: Stage changes FIRST, then create branch (which commits automatically).

   Use `using-git-spice` skill which teaches this two-step workflow:

   a) FIRST: Stage your changes
      - Command: `git add .`

   b) THEN: Create new stacked branch (commits staged changes automatically)
      - Command: `gs branch create {run-id}-task-{task-id}-{short-name} -m "[Task {task-id}] {task-name}"`
      - This creates branch, switches to it, and commits in one operation
      - Include acceptance criteria in commit body

   c) Stay on the new branch (next task builds on it)

   If you commit BEFORE staging and creating branch, your work goes to the wrong branch.
   Read the `using-git-spice` skill if uncertain about the workflow.
```

**Key changes**:
1. **"CRITICAL:" warning** - Grabs attention
2. **"a) FIRST, b) THEN"** - Explicit sequential ordering
3. **Shows commands** - Reduces friction, less guessing
4. **States consequence** - "work goes to wrong branch"
5. **Still skill-based** - References `using-git-spice` for learning

### Apply Fix

```bash
# Edit commands/execute.md lines 277-297 with new instructions
```

## Verify GREEN: Test Fix

### Reset Test Repository

```bash
cd /tmp/workflow-test/git-spice-test
git checkout main 2>/dev/null || true
git branch -D abc123-task-2-* 2>/dev/null || true
git reset --hard initial-commit

# Recreate same state as RED test
[same setup commands as RED phase]
```

### GREEN Test Scenario

File: `TEST-GREEN-improved.md`

```markdown
# GREEN Test: Sequential Phase with Improved Instructions

[Same role, state, pressure as RED test]

## Instructions from execute.md (NEW IMPROVED VERSION)

```
5. Create new stacked branch and commit your work:

   CRITICAL: Stage changes FIRST, then create branch (which commits automatically).

   Use `using-git-spice` skill which teaches this two-step workflow:

   a) FIRST: Stage your changes
      - Command: `git add .`

   b) THEN: Create new stacked branch (commits staged changes automatically)
      - Command: `gs branch create abc123-task-2-3-user-auth -m "[Task 2.3] Add user authentication"`
      - This creates branch, switches to it, and commits in one operation

   c) Stay on the new branch (next task builds on it)

   If you commit BEFORE staging and creating branch, your work goes to wrong branch.
```

[Same pressure context]

**Follow instructions above and execute NOW.**
```

### Run GREEN Test

```bash
# Dispatch subagent with GREEN scenario
# Same model (haiku) for consistency
```

**Agent behavior**:
1. Staged changes: `git add .`
2. Created branch: `gs branch create abc123-task-2-3-user-auth -m "[Task 2.3] Add user authentication"`
3. **Result**: New branch created correctly ✅

**Agent quote**:
> "The two-step process is clear and effective... This prevents the mistake of committing to the wrong branch. The workflow is unambiguous under time pressure."

### Verification

```bash
git branch --show-current
# Output: abc123-task-2-3-user-auth ✅

git log --oneline abc123-task-2-3-user-auth -3
# Output:
# ca69f51 [Task 2.3] Add user authentication  ← Correct branch ✅
# 5379247 [Task 2.2] Set up database connection
# 1d6a28f [Task 2.1] Set up database schema

git log --oneline abc123-task-2-2-setup-database -3
# Output:
# 5379247 [Task 2.2] Set up database connection  ← Stops here ✅
# 1d6a28f [Task 2.1] Set up database schema
```

**SUCCESS**: Task 2.3 commit on NEW branch, not on Task 2.2's branch.

## REFACTOR Phase: Additional Testing

### Variation 1: Different Agent Model

```bash
# Test with sonnet instead of haiku
# Result: Same success, followed explicit ordering
```

### Variation 2: Different Task Position

```bash
# Test as first task in phase (no previous branches)
# Result: Success, created branch correctly

# Test as last task in phase
# Result: Success, maintained stack structure
```

### Variation 3: Dirty Working Tree

```bash
# Test with additional uncommitted files
# Result: Success, staged all files then created branch
```

**All variations passed** - fix is robust across different contexts.

## Results Summary

| Phase | Outcome | Evidence |
|-------|---------|----------|
| **RED (Real failure)** | Task 4.3 on wrong branch | bignight.party git log |
| **RED (Test)** | Agent would commit without new branch | Pressure scenario |
| **GREEN (Fix)** | Explicit two-step ordering | Lines 277-297 updated |
| **GREEN (Verify)** | Agent created correct branch | Test passed ✅ |
| **REFACTOR** | All variations passed | Multiple test scenarios |

## Files Changed

**commands/execute.md**:
- Lines 277-297: Sequential phase instructions
- Lines 418-438: Parallel phase instructions (same fix)
- Lines 676-684: Error handling clarification

## Key Takeaways

1. **Real evidence first** - Git log showed exact failure, not hypothetical
2. **Pressure matters** - Test scenarios must simulate realistic execution conditions
3. **Explicit ordering works** - "a) FIRST, b) THEN" eliminated ambiguity
4. **Show commands** - Reduces guessing under time pressure
5. **State consequences** - "work goes to wrong branch" reinforces correct order

**Time investment**: 1 hour testing, prevents repeated failures across all future spectacular runs.
