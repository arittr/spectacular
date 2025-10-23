---
name: orchestrating-isolated-subagents
description: Use when orchestrator dispatches subagents to work in different directories - enforces clean separation where orchestrator never moves and subagents verify location before work
---

# Orchestrator-Subagent Directory Isolation

## Overview

When an orchestrator dispatches multiple subagents to work in different directories (worktrees, build outputs, temp directories), mixing up "who's where" causes path bugs, file corruption, and silent failures. This skill enforces clean separation.

**Core principle:** Orchestrator stays put, subagents move and verify.

**Announce at start:** "I'm using the orchestrating-isolated-subagents skill to manage directory isolation."

## When to Use

**Use this skill when:**

- Orchestrator dispatches subagents to different directories (worktrees, build directories, temp folders)
- Multiple subagents work in parallel in different locations
- Context must stay clean in orchestrator (no directory changes)
- Subagents need to verify they're in the right place before operating

**Don't use when:**

- Single agent working in single location
- All work happens in orchestrator's directory
- Simple scripts with no subagent dispatch

## The Pattern

### Orchestrator Responsibilities

**CRITICAL: The orchestrator NEVER changes directory.**

1. **Stays in original directory throughout:**

```bash
# At start of orchestrator session
pwd  # /path/to/repo

# ... dispatch subagent 1 to /path/to/repo/.worktrees/feature-a
# ... dispatch subagent 2 to /path/to/repo/.worktrees/feature-b
# ... dispatch subagent 3 to /path/to/repo/.worktrees/feature-c

pwd  # Still /path/to/repo (NEVER changed)
```

2. **Passes absolute paths to subagents:**

```markdown
ROLE: Implement Task 1

WORKTREE_PATH: /path/to/repo/.worktrees/feature-a
REPO_ROOT: /path/to/repo

# NOT relative paths like: ./.worktrees/feature-a

# Subagent inherits orchestrator's PWD, absolute paths are unambiguous
```

3. **Uses git -C for querying without cd:**

```bash
# Query another directory without cd
BRANCH=$(git -C .worktrees/feature-a branch --show-current)
STATUS=$(git -C .worktrees/feature-a status --porcelain)

# Orchestrator still in original directory
pwd  # /path/to/repo (unchanged)
```

4. **Trusts subagent reports:**

```
Orchestrator doesn't need to cd to verify work.
Subagent reports: "Task complete, branch created"
Orchestrator accepts report without changing directory.
```

### Subagent Responsibilities

**CRITICAL: Subagent verifies location at every step.**

1. **Verify starting location (inherited from orchestrator):**

```bash
# Subagent starts in orchestrator's PWD
pwd  # /path/to/repo (inherited)
```

2. **Move to target directory:**

```bash
# Use path provided by orchestrator
cd .worktrees/feature-a  # or use absolute path

# CRITICAL: Verify new location
pwd  # /path/to/repo/.worktrees/feature-a
# If doesn't match expected path, ERROR and exit
```

3. **All work happens in target directory:**

```bash
# Read files
cat plan.md

# Run commands
pnpm test
pnpm lint

# Git operations
git status
git add .
gs branch create feature-a-task-1 -m "Implement task 1"
```

4. **Report from target directory (don't cd back):**

```markdown
Task complete:

- Summary: Implemented authentication flow
- Files modified: src/auth.ts, src/login.ts
- Tests: 12 passing
- Branch: feature-a-task-1
- Current location: /path/to/repo/.worktrees/feature-a
```

**Why not cd back:**

- Unnecessary (orchestrator doesn't care where subagent ends)
- Adds complexity (extra cd, extra verification)
- Risk of error (cd back to wrong place)

## Orchestrator Prompt Template

````markdown
ROLE: [Orchestrator role]

TASK: [Dispatch N subagents to different locations]

CRITICAL - DIRECTORY MANAGEMENT:
You are the orchestrator. You stay in the main repository throughout.
NEVER cd to other directories. Use git -C or pass paths to subagents.

SUBAGENTS:

1. Subagent 1: Works in .worktrees/feature-a
2. Subagent 2: Works in .worktrees/feature-b

For each subagent, dispatch with:

- WORKTREE_PATH: /absolute/path/to/worktree
- REPO_ROOT: /absolute/path/to/repo
- Let subagent handle cd

IMPLEMENTATION:

1. Verify you're in main repo:

```bash
pwd  # Should be /path/to/repo
```
````

2. Spawn subagent 1 (per orchestrating-isolated-subagents skill):
   [Include subagent prompt with WORKTREE_PATH]

3. Spawn subagent 2 (per orchestrating-isolated-subagents skill):
   [Include subagent prompt with WORKTREE_PATH]

4. Wait for subagent reports (stay in main repo)

5. Verify still in main repo:

```bash
pwd  # Should still be /path/to/repo
```

CRITICAL:

- ✅ Stay in main repo throughout
- ✅ Pass absolute paths to subagents
- ✅ Use git -C for queries
- ❌ NEVER cd from orchestrator

````

## Subagent Prompt Template

```markdown
ROLE: [Task to implement]

TASK: [Specific work]
WORKTREE_PATH: /absolute/path/to/target/directory
REPO_ROOT: /absolute/path/to/repo

CRITICAL - DIRECTORY MANAGEMENT:
1. You start in the orchestrator's directory (main repo)
2. First step: cd into your target directory
3. All work happens in target directory
4. Stay in target directory, do NOT cd back

SETUP:

1. Verify starting location:
```bash
pwd  # Will show: /path/to/repo (orchestrator's location)
````

2. Enter target directory:

```bash
cd .worktrees/feature-a  # or use absolute WORKTREE_PATH
```

3. Verify you're in the right place:

```bash
pwd  # Should show: /path/to/repo/.worktrees/feature-a

# If doesn't match expected path:
echo "ERROR: Wrong directory"
exit 1
```

IMPLEMENTATION:

[Task implementation steps - all run in target directory]

REPORTING:

Report from target directory (current location):

- Summary: [what you did]
- Files modified: [list]
- Current location: $(pwd)

CRITICAL:

- ✅ Verify location with pwd before AND after cd
- ✅ Stay in target directory throughout
- ✅ Report from target directory
- ❌ DO NOT cd back to orchestrator's directory

````

## Rationalization Table

| Rationalization | Why It's Wrong | Enforcement |
|-----------------|----------------|-------------|
| "I'll cd to simplify orchestrator logic" | Context pollution, path confusion, breaks isolation | Orchestrator NEVER cd |
| "I'll use relative paths, less verbose" | Breaks when PWD changes, ambiguous | ALWAYS absolute paths |
| "I'll skip pwd verification, I know where I am" | Silent bugs from wrong directory | ALWAYS verify with pwd |
| "I'll cd back for clean reporting" | Unnecessary complexity, risk of error | Report from work directory |
| "I can track directory state in orchestrator" | Inevitably breaks, context bloat | Orchestrator stateless about location |
| "Subagent doesn't need to verify location" | File operations in wrong place, silent corruption | MUST verify pwd after cd |

## Quality Rules

**Orchestrator MUST:**

1. **Never change directory:**
   - Run `pwd` at start, verify at end (should be same)
   - Use `git -C` to query other directories
   - Pass absolute paths to subagents

2. **Provide absolute paths:**
   - Full path to target directory: `/path/to/repo/.worktrees/feature-a`
   - Full path to repo root: `/path/to/repo`
   - NOT relative paths: `./.worktrees/feature-a`

3. **Stay stateless about subagent location:**
   - Don't track where subagents are
   - Don't cd to verify their work
   - Trust subagent reports

**Subagent MUST:**

1. **Verify location before and after cd:**
   ```bash
   pwd  # Before cd
   cd .worktrees/feature-a
   pwd  # After cd - verify matches expected
````

2. **Work only in target directory:**

   - All file operations in target
   - All git operations in target
   - All commands run in target

3. **Report from target directory:**
   - Include current location in report: `$(pwd)`
   - Do NOT cd back to orchestrator location
   - Let orchestrator handle coordination

## Common Mistakes

### Mistake 1: Orchestrator changes directory

```bash
# ❌ WRONG: Orchestrator cd to check something
cd .worktrees/feature-a
git status
cd ../..

# ✅ CORRECT: Use git -C
git -C .worktrees/feature-a status
```

**Why it matters:** Orchestrator loses track of location, relative paths break, subagent coordination fails.

### Mistake 2: Using relative paths in subagent prompts

```markdown
# ❌ WRONG: Relative path (ambiguous)

WORKTREE_PATH: ./.worktrees/feature-a

# ✅ CORRECT: Absolute path (unambiguous)

WORKTREE_PATH: /Users/username/project/.worktrees/feature-a
```

**Why it matters:** Subagent inherits orchestrator's PWD. Relative paths depend on that. If orchestrator accidentally cd'd, paths break.

### Mistake 3: Subagent skips location verification

```bash
# ❌ WRONG: cd without verification
cd .worktrees/feature-a
git status  # Might be in wrong place!

# ✅ CORRECT: Verify after cd
cd .worktrees/feature-a
pwd  # /path/to/repo/.worktrees/feature-a
if [ "$(pwd)" != "/expected/path" ]; then
  echo "ERROR: Wrong directory"
  exit 1
fi
git status  # Now safe
```

**Why it matters:** Silent failures. Files created in wrong place, git operations on wrong repo.

### Mistake 4: Subagent cd's back for reporting

```bash
# ❌ WRONG: cd back to report
cd .worktrees/feature-a
[do work]
cd ../..
echo "Task complete"

# ✅ CORRECT: Report from work directory
cd .worktrees/feature-a
[do work]
echo "Task complete in $(pwd)"
```

**Why it matters:** Unnecessary complexity, risk of cd to wrong place, orchestrator doesn't care.

## Red Flags

**STOP if you're about to:**

- cd from orchestrator context (orchestrator NEVER moves)
- Use relative paths in orchestrator→subagent communication
- Skip `pwd` verification in subagent after cd
- cd back to orchestrator location from subagent
- Track subagent directory state in orchestrator
- Query other directories without `git -C` from orchestrator

**Always:**

- Verify orchestrator location: `pwd` at start and end (should be unchanged)
- Pass absolute paths to subagents
- Verify subagent location: `pwd` before and after cd
- Report from work directory (don't cd back)
- Use `git -C` from orchestrator to query other directories

## Integration

**Used by:**

- `/spectacular:execute` - Orchestrator dispatches task subagents
- `/spectacular:cleanup` - Orchestrator coordinates cleanup subagents
- Any command with orchestrator/subagent pattern

**Pairs with:**

- `managing-worktrees` - Specific worktree management patterns
- `dispatching-parallel-agents` (superpowers) - Parallel subagent dispatch
- `subagent-driven-development` (superpowers) - Subagent-based implementation

## Benefits

1. **Clean orchestrator context:**

   - PWD never changes
   - No relative path confusion
   - Easy to reason about

2. **Explicit subagent isolation:**

   - Clear boundary: cd into workspace
   - Verification: pwd before/after
   - No ambiguity about location

3. **Prevents path bugs:**

   - Absolute paths are unambiguous
   - pwd verification catches errors early
   - git -C prevents accidental orchestrator cd

4. **Easier debugging:**
   - Orchestrator always in known location
   - Subagent reports include pwd
   - No state tracking needed

## Example: Spectacular Execution

**Orchestrator** (`/spectacular:execute`):

```markdown
pwd # /Users/username/project

Spawn subagent 1:
WORKTREE_PATH: /Users/username/project/.worktrees/abc123-main
TASK: Implement Task 1.1

Spawn subagent 2:
WORKTREE_PATH: /Users/username/project/.worktrees/abc123-main
TASK: Implement Task 1.2

pwd # Still /Users/username/project (never changed)
```

**Subagent 1**:

```bash
pwd  # /Users/username/project (inherited from orchestrator)
cd .worktrees/abc123-main
pwd  # /Users/username/project/.worktrees/abc123-main (verified)

# Implement task
git add .
gs branch create abc123-task-1-1-schema -m "Add schema"

# Report
echo "Task 1.1 complete in $(pwd)"
# Don't cd back
```

**Result:** Clean separation, no directory confusion, predictable behavior.
