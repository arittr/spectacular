# Test Scenario: Orchestrator Location Discipline

## Context

Testing that orchestrator maintains strict location discipline: always runs from main repo root, never changes directories.

**Setup:**
- Execution plan with sequential and parallel phases
- Multiple worktrees created during execution
- Operations requiring worktree access (dependency install, quality checks, git operations)

**Why critical:**
- Orchestrator creates worktrees at `.worktrees/` relative to current directory
- If orchestrator cd's into worktree, subsequent worktree creation fails (nested paths)
- Confusion about pwd causes "must run from main repo" errors mid-execution
- Burns time/context with location debugging

**Real failure from NOTES.md:**
```
⏺ I'm using executing-parallel-phase to orchestrate 3 concurrent tasks in Phase 5.

  Let me start by verifying pre-conditions:

⏺ Bash(# Get main repo root
     REPO_ROOT=$(git rev-parse --show-toplevel)…)
  ⎿  Error: Exit code 1
     Current location: /Users/drewritter/projects/bignight.party/.worktrees/26db45-main
     Repo root: /Users/drewritter/projects/bignight.party/.worktrees/26db45-main
     ❌ Error: Currently in worktree, must run from main repo
     Current: /Users/drewritter/projects/bignight.party/.worktrees/26db45-main

⏺ Good catch! I'm in the worktree. Let me navigate to the main repo root:

⏺ Bash(cd /Users/drewritter/projects/bignight.party && pwd && git worktree list)
```

**Root cause:** Orchestrator cd'd into worktree somewhere earlier in execution, didn't track location.

## Expected Behavior

### Core Principle

**Orchestrator NEVER changes directory. Subagents own their directory context.**

```
Main Repo (orchestrator stays here)
├── .worktrees/
│   ├── {runid}-main/           (sequential work - subagents navigate here)
│   ├── {runid}-task-1-1/       (parallel task 1 - subagent navigates here)
│   └── {runid}-task-1-2/       (parallel task 2 - subagent navigates here)
└── specs/

Orchestrator: Always pwd = Main Repo
Subagents: Navigate to assigned worktree, stay there
```

### Rule 1: Orchestrator Never Uses `cd`

**FORBIDDEN patterns:**
```bash
# ❌ WRONG: Orchestrator changes directory
cd .worktrees/{runid}-main
git status
npm install

# ❌ WRONG: Even with cd back
cd .worktrees/{runid}-main
npm install
cd ../..  # Easy to forget, easy to break
```

**ALLOWED patterns:**
```bash
# ✅ CORRECT: Use git -C for git operations
git -C .worktrees/{runid}-main status
git -C .worktrees/{runid}-main branch --show-current

# ✅ CORRECT: Use bash -c for non-git commands
bash -c "cd .worktrees/{runid}-main && npm install"
bash -c "cd .worktrees/{runid}-main && npm test && npm run build"

# ✅ CORRECT: Multi-line commands with heredoc
bash <<'EOF'
cd .worktrees/{runid}-main
npm install
npx prisma generate
EOF
```

**Why `bash -c` or heredoc is safe:**
- Creates subshell that exits after command
- Orchestrator's pwd unchanged
- Explicit and traceable

### Rule 2: Pre-Flight Location Assertions

**Both execution skills must verify orchestrator location BEFORE any operations:**

```bash
### Step 0: Verify Orchestrator Location (MANDATORY)

REPO_ROOT=$(git rev-parse --show-toplevel)
CURRENT=$(pwd)

if [ "$CURRENT" != "$REPO_ROOT" ]; then
  echo "❌ Error: Orchestrator must run from main repo root"
  echo "Current: $CURRENT"
  echo "Expected: $REPO_ROOT"
  echo ""
  echo "Return to main repo: cd $REPO_ROOT"
  exit 1
fi

echo "✅ Orchestrator location verified: Main repo root"
```

**Why needed:**
- Catches upstream drift (execute.md or other skill left orchestrator in wrong place)
- Fails fast with actionable error
- Defense against future edits introducing cd commands

### Rule 3: Subagents Navigate Once

**Orchestrator dispatch to task subagents:**

```markdown
ROLE: Implement Task {task-id} in main worktree (sequential phase)

WORKTREE: .worktrees/{run-id}-main
CURRENT BRANCH: {current-branch}

INSTRUCTIONS:

1. Navigate to worktree:
   cd .worktrees/{run-id}-main

2. Verify location:
   pwd  # Must show worktree path

3. [Implementation work...]

4. NEVER return to main repo
   Subagent completes work and exits from worktree
```

**Subagent owns its directory context** - orchestrator never checks "are you in the right place?" mid-execution.

### Rule 4: Code Review Receives Worktree Path

**Orchestrator uses `requesting-code-review` skill with worktree context:**

```markdown
WORKTREE: .worktrees/{run-id}-main
PHASE: {N}
TASKS: {M}-{P}
```

**Code-reviewer subagent (like task subagents):**

```markdown
1. Navigate to worktree:
   cd {worktree-path}

2. Verify location:
   pwd  # Should show worktree path

3. Review code in this context:
   - Check files exist at expected paths
   - Run quality checks (npm test, npm run build)
   - Verify git state
```

**Code-reviewer is a subagent** - follows same location rules as task subagents.

## Test Method

**Static analysis of execution skills:**

```bash
echo "=== Test 1: Check for orchestrator cd usage ==="
echo ""

# Find any cd commands in orchestrator sections (not subagent prompts)
# Look outside of "INSTRUCTIONS:" blocks and "```bash" heredocs

grep -rn "^cd " skills/executing-sequential-phase/SKILL.md skills/executing-parallel-phase/SKILL.md 2>/dev/null | grep -v "INSTRUCTIONS:" | grep -v "^\s*cd"

echo ""
echo "=== Test 2: Check for pre-flight assertions ==="
echo ""

# Both skills should have "Verify Orchestrator Location" section
grep -rn "Verify Orchestrator Location\|REPO_ROOT=\|CURRENT=\$(pwd)" skills/executing-sequential-phase/SKILL.md skills/executing-parallel-phase/SKILL.md 2>/dev/null

echo ""
echo "=== Test 3: Verify git -C usage for worktree operations ==="
echo ""

# Git commands should use -C flag when operating on worktrees
grep -rn "git.*worktree" skills/executing-sequential-phase/SKILL.md skills/executing-parallel-phase/SKILL.md 2>/dev/null | head -10

echo ""
echo "=== Test 4: Check subagent dispatch includes worktree path ==="
echo ""

# Subagent prompts should include explicit cd instruction
grep -rn "cd .worktrees" skills/executing-sequential-phase/SKILL.md skills/executing-parallel-phase/SKILL.md 2>/dev/null | grep "INSTRUCTIONS:" -A 5 | head -20
```

## Success Criteria

### Orchestrator Location Discipline
- [ ] No `cd` commands in orchestrator workflow (outside subagent prompts)
- [ ] All worktree git operations use `git -C .worktrees/path`
- [ ] All worktree non-git operations use `bash -c "cd path && cmd"`
- [ ] Pre-flight assertion at start of both execution skills

### Pre-Flight Assertions
- [ ] `executing-sequential-phase/SKILL.md` has Step 0: Verify Location
- [ ] `executing-parallel-phase/SKILL.md` has Step 0: Verify Location
- [ ] Both use identical assertion code
- [ ] Assertion checks `$(pwd) == $(git rev-parse --show-toplevel)`
- [ ] Assertion provides actionable error message

### Subagent Context
- [ ] Sequential subagent prompt includes explicit cd to worktree
- [ ] Parallel subagent prompt includes explicit cd to worktree
- [ ] Code-reviewer receives worktree path parameter
- [ ] Code-reviewer prompt includes explicit cd to worktree
- [ ] All subagent prompts include `pwd` verification step

### Pattern Consistency
- [ ] Sequential and parallel use same location verification code
- [ ] Sequential and parallel use same `git -C` patterns
- [ ] All bash -c commands use heredoc for multi-line (not `cd && cmd1 && cmd2`)

## Expected Test Results

### RED Phase (Current State)

**Run static analysis above, should find:**

1. ❌ **Sequential phase Step 1** - Orchestrator uses `cd`:
   ```bash
   cd .worktrees/{runid}-main

   # Check dependencies installed
   if [ ! -d node_modules ]; then
     npm install
   fi
   ```

2. ⚠️ **Parallel phase** - Has pre-flight check but sequential doesn't
3. ❌ **No worktree context passed to code-reviewer**
4. ❌ **Inconsistent location patterns** between skills

**Test verdict: FAIL** - Orchestrator changes directory in sequential phase

### GREEN Phase (After Fix)

**After fixing all skills:**

1. ✅ Sequential phase uses `bash -c "cd path && cmd"` instead of bare `cd`
2. ✅ Both skills have pre-flight location assertion
3. ✅ All git operations use `git -C`
4. ✅ Code-reviewer receives worktree path
5. ✅ Consistent location discipline across all skills

**Test verdict: PASS** - All location rules followed

## Real-World Impact

**Without location discipline (current):**
- Orchestrator cd's into worktree for convenience
- Forgets to cd back
- Next operation (create parallel worktree) fails with nested path
- Pre-flight check catches it, orchestrator navigates back
- Burns 30-60 seconds and 5-10k tokens debugging location

**With location discipline (after fix):**
- Orchestrator never changes directory
- All operations use `git -C` or `bash -c`
- Pre-flight assertion catches upstream drift immediately
- No location confusion, no debugging needed

## Anti-Patterns to Detect

### Anti-Pattern 1: Orchestrator cd for Convenience

**WRONG:**
```markdown
### Step 1: Verify Setup in Main Worktree

cd .worktrees/{runid}-main

# Check dependencies installed
if [ ! -d node_modules ]; then
  npm install
fi
```

**Why wrong:** Orchestrator changes directory, might forget to return

**Correct:**
```markdown
### Step 1: Verify Setup in Main Worktree

# Check dependencies from main repo
if [ ! -d .worktrees/{runid}-main/node_modules ]; then
  bash -c "cd .worktrees/{runid}-main && npm install"
fi
```

### Anti-Pattern 2: cd with Manual Return

**WRONG:**
```bash
cd .worktrees/{runid}-main
npm test
cd ../..  # Hope this gets us back
```

**Why wrong:**
- Assumes directory structure
- Easy to forget
- Breaks if called from unexpected location

**Correct:**
```bash
bash -c "cd .worktrees/{runid}-main && npm test"
# Orchestrator pwd unchanged
```

### Anti-Pattern 3: No Pre-Flight Check

**WRONG:**
```markdown
### Step 1: Create Task Worktrees

# Immediately start creating worktrees
git worktree add .worktrees/{runid}-task-1 {base-branch}
```

**Why wrong:** If orchestrator is already in worktree, path is wrong

**Correct:**
```markdown
### Step 0: Verify Location

REPO_ROOT=$(git rev-parse --show-toplevel)
if [ "$(pwd)" != "$REPO_ROOT" ]; then
  echo "❌ Must run from main repo"
  exit 1
fi

### Step 1: Create Task Worktrees

git worktree add .worktrees/{runid}-task-1 {base-branch}
```

### Anti-Pattern 4: Subagent Without Worktree Path

**WRONG:**
```markdown
ROLE: Implement Task 1 in main worktree

INSTRUCTIONS:

1. Implement feature
2. Run tests
3. Create branch
```

**Why wrong:** Subagent doesn't know WHERE to work

**Correct:**
```markdown
ROLE: Implement Task 1 in main worktree

WORKTREE: .worktrees/{run-id}-main

INSTRUCTIONS:

1. Navigate to worktree:
   cd .worktrees/{run-id}-main

2. Verify location:
   pwd

3. Implement feature
```

## Files to Check

**Primary files:**
- `skills/executing-sequential-phase/SKILL.md` - Step 1 has orchestrator cd
- `skills/executing-parallel-phase/SKILL.md` - Has pre-flight check (reference)
- `skills/requesting-code-review/SKILL.md` - Should pass worktree context

**Secondary files:**
- `commands/execute.md` - Orchestrator guidance
- `skills/troubleshooting-execute/SKILL.md` - Recovery procedures

## Implementation Notes

**When fixing:**

1. Find all `cd .worktrees/` in orchestrator sections
2. Replace with `bash -c "cd path && cmd"` or `git -C path`
3. Add Step 0 pre-flight assertion to both execution skills
4. Update requesting-code-review to accept worktree parameter
5. Ensure subagent prompts include explicit cd instruction

**Template for pre-flight check:**
```bash
### Step 0: Verify Orchestrator Location

REPO_ROOT=$(git rev-parse --show-toplevel)
CURRENT=$(pwd)

if [ "$CURRENT" != "$REPO_ROOT" ]; then
  echo "❌ Error: Orchestrator must run from main repo root"
  echo "Current: $CURRENT"
  echo "Expected: $REPO_ROOT"
  echo ""
  echo "Return to main repo: cd $REPO_ROOT"
  exit 1
fi

echo "✅ Orchestrator location verified: Main repo root"
```
