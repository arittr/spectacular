# Test Scenarios: Worktree-Based Execution Isolation

**Purpose**: Test scenarios for validating the worktree-isolation feature before and during implementation.

**Approach**: Test-driven development - define expected behavior first, implement to pass tests.

---

## Scenario Categories

1. [Spec Command](#spec-command-scenarios)
2. [Plan Command](#plan-command-scenarios)
3. [Execute Command](#execute-command-scenarios)
4. [List Command](#list-command-scenarios)
5. [Cleanup Command](#cleanup-command-scenarios)
6. [Multi-Feature Concurrency](#multi-feature-concurrency-scenarios)
7. [Edge Cases](#edge-case-scenarios)
8. [Integration Points](#integration-point-scenarios)

---

## Spec Command Scenarios

### S1: Clean State - Happy Path

**Setup:**
- Clean main repo (no uncommitted changes)
- On main branch

**Execute:**
```bash
/spectacular:spec "Add user profile page with bio editor"
```

**Expected:**
- Generates runId (e.g., `a1b2c3`)
- Generates feature slug: `add-user-profile-page-with-bio-editor`
- Creates `.worktrees/main-a1b2c3/` in detached HEAD state
- No uncommitted changes prompt (clean state)
- Orchestrator remains in main repo (verify with `pwd` after)
- Dispatches subagent for spec generation
- Subagent receives working directory: `.worktrees/main-a1b2c3/`
- Subagent pre-loads constitutions (check subagent prompt for Read calls)
- Subagent uses `superpowers:brainstorming` skill
- Subagent uses `spectacular:writing-specs` skill
- Spec created at `.worktrees/main-a1b2c3/specs/a1b2c3-add-user-profile-page-with-bio-editor/spec.md`
- Main repo has no uncommitted files (`git status --porcelain` is empty)
- Reports absolute path: `.worktrees/main-a1b2c3/specs/...`

**Verify:**
```bash
# Main repo clean
git status --porcelain  # Should be empty

# Worktree exists
ls -la .worktrees/main-a1b2c3/

# Spec file exists
cat .worktrees/main-a1b2c3/specs/a1b2c3-add-user-profile-page-with-bio-editor/spec.md

# Worktree in detached HEAD state
cd .worktrees/main-a1b2c3/
git status  # Should show "HEAD detached at <commit>"
```

---

### S2: Dirty State - Commit and Proceed

**Setup:**
- Uncommitted changes in main repo (e.g., modified `README.md`)

**Execute:**
```bash
/spectacular:spec "Add dark mode toggle"
```

**Expected:**
- Detects dirty state via `git status --porcelain`
- Presents AskUserQuestion with 4 options
- User selects "Commit and proceed"
- Creates commit: `WIP: Spectacular spec creation`
- Creates worktree from new HEAD (includes committed changes)
- Worktree contains the committed changes
- Continues with spec generation
- Reports absolute path

**Verify:**
```bash
# Commit exists
git log -1 --oneline  # Should show "WIP: Spectacular spec creation"

# Worktree includes commit
cd .worktrees/main-{runId}/
git log -1 --oneline  # Should show same commit

# Main repo clean
cd ../../
git status --porcelain  # Should be empty
```

---

### S3: Dirty State - Stash and Proceed

**Setup:**
- Uncommitted changes in main repo

**Execute:**
```bash
/spectacular:spec "Add notification system"
```

**Expected:**
- User selects "Stash and proceed"
- Runs `git stash push -m "Spectacular: add-notification-system"`
- Creates worktree from clean HEAD
- Output shows stash reference (e.g., `stash@{0}`)
- Worktree does NOT include stashed changes
- Continues with spec generation

**Verify:**
```bash
# Stash exists
git stash list  # Should show "Spectacular: add-notification-system"

# Main repo clean
git status --porcelain  # Should be empty

# Worktree doesn't have changes
cd .worktrees/main-{runId}/
git status --porcelain  # Should be empty

# Can pop stash later
cd ../../
git stash pop  # Should restore changes
```

---

### S4: Dirty State - Proceed Anyway

**Setup:**
- Uncommitted changes in main repo

**Execute:**
```bash
/spectacular:spec "Add search feature"
```

**Expected:**
- User selects "Proceed anyway"
- Creates worktree from current HEAD
- Uncommitted changes stay in main repo only (NOT in worktree)
- No commit, no stash
- Continues with spec generation

**Verify:**
```bash
# Main repo still dirty
git status --porcelain  # Should show uncommitted changes

# Worktree is clean
cd .worktrees/main-{runId}/
git status --porcelain  # Should be empty
```

---

### S5: Dirty State - Abort

**Setup:**
- Uncommitted changes in main repo

**Execute:**
```bash
/spectacular:spec "Add payment integration"
```

**Expected:**
- User selects "Abort"
- Command exits cleanly
- No worktree created
- No commit, no stash
- Main repo unchanged

**Verify:**
```bash
# No worktree
ls .worktrees/main-*/  # Should not exist for this runId

# Main repo still dirty
git status --porcelain  # Should show uncommitted changes
```

---

### S6: Pre-commit Hook Failure

**Setup:**
- Uncommitted changes
- Pre-commit hook that fails (e.g., linting error)

**Execute:**
```bash
/spectacular:spec "Add admin dashboard"
```

**Expected:**
- User selects "Commit and proceed"
- Commit fails with hook output shown
- Presents retry or abort options
- If abort: no worktree created, main repo unchanged

**Verify:**
```bash
# No commit created (if aborted)
git log -1  # Should not show WIP commit

# Main repo still dirty
git status --porcelain  # Should show uncommitted changes
```

---

### S7: Feature Slug Generation

**Test various feature descriptions:**

| Input | Expected Slug |
|-------|---------------|
| "Add User Authentication" | `add-user-authentication` |
| "Fix: Memory Leak in WebSocket" | `fix-memory-leak-in-websocket` |
| "Implement OAuth2.0 Provider" | `implement-oauth20-provider` |
| "Add Support for UTF-8 Émojis!" | `add-support-for-utf-8-emojis` |
| "Very Long Feature Name That Exceeds The Fifty Character Maximum Limit" | `very-long-feature-name-that-exceeds-the-fifty-ch` (50 chars) |

**Verify:**
```bash
# Check directory name matches slug
ls .worktrees/main-{runId}/specs/
```

---

### S8: Subagent Context Isolation

**Setup:**
- Clean state, run spec command

**Execute:**
```bash
/spectacular:spec "Add analytics dashboard"
```

**Expected:**
- Orchestrator dispatches subagent (Task tool)
- Subagent prompt contains constitution pre-loading instructions
- Subagent reads constitutions (verify Read tool calls in transcript)
- Brainstorming session with many AskUserQuestion rounds (20+ messages)
- Orchestrator context does NOT compact during session
- Subagent uses fresh context throughout

**Verify:**
- Check orchestrator message count stays low (< 10 messages)
- Check subagent handles full brainstorming workflow
- AskUserQuestion prompts bubble up to user
- Spec quality reflects constitution constraints

---

## Plan Command Scenarios

### P1: Generate Plan from Existing Spec

**Setup:**
- Spec exists at `.worktrees/main-a1b2c3/specs/a1b2c3-feature-name/spec.md`

**Execute:**
```bash
/spectacular:plan @specs/a1b2c3-feature-name/spec.md
```

**Expected:**
- Extracts runId: `a1b2c3` from path
- Uses `managing-main-worktrees` skill
- Reuses existing `.worktrees/main-a1b2c3/`
- Orchestrator cd's to worktree
- Plan generated at `.worktrees/main-a1b2c3/specs/a1b2c3-feature-name/plan.md`
- Reports absolute path
- Main repo has no uncommitted files

**Verify:**
```bash
# Plan exists
cat .worktrees/main-a1b2c3/specs/a1b2c3-feature-name/plan.md

# Main repo clean
git status --porcelain  # Should be empty
```

---

### P2: Plan Without Existing Worktree

**Setup:**
- Spec file exists but worktree was cleaned up

**Execute:**
```bash
/spectacular:plan @specs/a1b2c3-feature-name/spec.md
```

**Expected:**
- Extracts runId
- Creates new `.worktrees/main-a1b2c3/`
- Reads spec from path
- Generates plan
- Reports absolute path

**Verify:**
```bash
# Worktree created
ls -la .worktrees/main-a1b2c3/

# Plan exists
cat .worktrees/main-a1b2c3/specs/a1b2c3-feature-name/plan.md
```

---

### P3: Invalid Path Format

**Execute:**
```bash
/spectacular:plan some/invalid/path.md
```

**Expected:**
- Error: "Path must be in format: @specs/{runId}-{feature-slug}/spec.md"
- Shows expected format examples
- Command exits cleanly

---

## Execute Command Scenarios

### E1: Execute Plan - Full Workflow

**Setup:**
- Plan exists at `.worktrees/main-a1b2c3/specs/a1b2c3-feature-name/plan.md`
- Plan has sequential and parallel phases

**Execute:**
```bash
/spectacular:execute @specs/a1b2c3-feature-name/plan.md
```

**Expected:**
- Extracts runId
- Uses `managing-main-worktrees` skill
- Orchestrator cd's to worktree
- Detects and runs install command (per FR11)
- Sequential tasks: subagents receive `.worktrees/main-a1b2c3/`, cd themselves
- Parallel setup: creates child worktrees `.worktrees/a1b2c3-task-X-Y/`
- Parallel tasks: subagents receive child worktree paths, cd themselves
- Cleanup: removes child worktrees
- Main worktree persists
- Main repo unchanged

**Verify:**
```bash
# Main repo clean
git status --porcelain  # Should be empty

# Branches created in main worktree
git branch | grep "^  a1b2c3-"

# Child worktrees removed
ls .worktrees/a1b2c3-task-*  # Should not exist

# Main worktree persists
ls .worktrees/main-a1b2c3/
```

---

### E2: Dependency Detection - CLAUDE.md Priority

**Setup:**
- CLAUDE.md contains: "Install: `pnpm install`"
- package.json exists (Node.js project)

**Execute:**
```bash
/spectacular:execute @specs/a1b2c3-feature-name/plan.md
```

**Expected:**
- Reads CLAUDE.md first
- Detects install command: `pnpm install`
- Runs `pnpm install` in worktree
- Does NOT use constitution or LLM inference
- If install fails: execution fails with error

**Verify:**
```bash
# Install ran
ls .worktrees/main-a1b2c3/node_modules/  # Should exist
```

---

### E3: Dependency Detection - Constitution Fallback

**Setup:**
- CLAUDE.md has no install instructions
- Constitution tech-stack.md contains: "Package manager: pnpm"

**Execute:**
```bash
/spectacular:execute @specs/a1b2c3-feature-name/plan.md
```

**Expected:**
- Checks CLAUDE.md (nothing found)
- Reads constitution
- Detects install command: `pnpm install`
- Runs install in worktree

---

### E4: Dependency Detection - LLM Inference

**Setup:**
- No CLAUDE.md install instructions
- No constitution install instructions
- Root has: package.json, pnpm-lock.yaml

**Execute:**
```bash
/spectacular:execute @specs/a1b2c3-feature-name/plan.md
```

**Expected:**
- Checks CLAUDE.md (nothing)
- Checks constitution (nothing)
- Uses LLM inference on root files
- Detects Node.js ecosystem from package.json + pnpm-lock.yaml
- Selects `pnpm install` (prioritizes faster package manager)
- Runs install

**Test Multiple Ecosystems:**

| Files | Expected Command |
|-------|-----------------|
| `package.json` + `pnpm-lock.yaml` | `pnpm install` |
| `package.json` + `package-lock.json` | `npm install` |
| `pyproject.toml` + `uv.lock` | `uv sync` |
| `requirements.txt` | `pip install -r requirements.txt` |
| `Cargo.toml` | `cargo build` |
| `go.mod` | `go mod download` |

---

### E5: Dependency Detection - Skip Gracefully

**Setup:**
- No install instructions anywhere
- No recognizable package management files

**Execute:**
```bash
/spectacular:execute @specs/a1b2c3-feature-name/plan.md
```

**Expected:**
- Skips install with info message
- Does NOT error
- Continues with execution

---

### E6: Install Failure - Fail Entire Execution

**Setup:**
- Install command detected: `pnpm install`
- Install fails (e.g., network error)

**Execute:**
```bash
/spectacular:execute @specs/a1b2c3-feature-name/plan.md
```

**Expected:**
- Install runs
- Install fails with error output
- Execution stops with clear error message
- No tasks executed
- Worktree remains for inspection

---

## List Command Scenarios

### L1: List Active Features

**Setup:**
- 3 features in various states:
  - `main-aaa111`: spec only (2 days old)
  - `main-bbb222`: spec + plan (1 day old)
  - `main-ccc333`: executed with 5 branches (3 hours old)

**Execute:**
```bash
/spectacular:list
```

**Expected:**
- Runs from main repo (no cd)
- Runs `git worktree prune` first
- Detects default branch (e.g., `main`)
- Lists all features sorted by creation time (newest first):
  ```
  ccc333: feature-c (3 hours ago) [executed (5 branches)]
  bbb222: feature-b (1 day ago) [spec+plan]
  aaa111: feature-a (2 days ago) [spec only]
  ```

**Verify:**
```bash
# Command runs from main repo
pwd  # Should be main repo root

# Output format matches expected
```

---

### L2: Staleness Detection

**Setup:**
- Feature worktree created 2 weeks ago
- Default branch has 15 new commits since then

**Execute:**
```bash
/spectacular:list
```

**Expected:**
- Calculates commits behind: `git log --oneline HEAD..origin/main | wc -l`
- Shows staleness: `aaa111: feature-a (14 days ago) [spec only] ⚠️ 15 behind`

**Verify:**
```bash
# Manually check behind count
cd .worktrees/main-aaa111/
git log --oneline HEAD..origin/main | wc -l  # Should be 15
```

---

### L3: Staleness - Behind and Ahead

**Setup:**
- Feature worktree has local commits (3 ahead)
- Default branch has new commits (8 behind)

**Execute:**
```bash
/spectacular:list
```

**Expected:**
- Shows both metrics: `aaa111: feature-a (5 days ago) [executed (3 branches)] ⚠️ 8 behind, 3 ahead`

---

### L4: Orphaned Worktree Detection

**Setup:**
- Worktree exists: `.worktrees/main-ddd444/`
- No spec file inside (failed spec creation)

**Execute:**
```bash
/spectacular:list
```

**Expected:**
- Checks from main repo: `ls .worktrees/main-ddd444/specs/ddd444-*/spec.md 2>/dev/null`
- Exits non-zero (file doesn't exist)
- Marks as orphaned
- Output: `ddd444: (orphaned) (2 hours ago) - run /spectacular:cleanup ddd444`
- Skips phase detection
- Skips staleness check

**Verify:**
```bash
# Worktree exists but no spec
ls .worktrees/main-ddd444/
ls .worktrees/main-ddd444/specs/  # Should be empty or not exist
```

---

### L5: No Default Branch - Skip Staleness

**Setup:**
- Fresh repo with no remote
- No `main` or `master` branch

**Execute:**
```bash
/spectacular:list
```

**Expected:**
- Detection attempts fail gracefully
- Lists features without staleness warnings
- Output: `aaa111: feature-a (1 day ago) [spec only]` (no ⚠️)

---

### L6: Empty List

**Setup:**
- No `.worktrees/main-*` directories

**Execute:**
```bash
/spectacular:list
```

**Expected:**
- Output: "No active features"
- Exits cleanly

---

## Cleanup Command Scenarios

### C1: Cleanup Valid Worktree - No Uncommitted Changes

**Setup:**
- Worktree: `.worktrees/main-aaa111/`
- Spec exists (valid worktree)
- 3 branches created: `aaa111-task-1-1`, `aaa111-task-1-2`, `aaa111-task-1-3`
- All branches pushed
- No uncommitted changes

**Execute:**
```bash
/spectacular:cleanup aaa111
```

**Expected:**
- Verifies worktree exists
- Checks not orphaned (spec file exists)
- cd's into worktree
- Checks uncommitted: none
- Lists branches with push status: all pushed
- Presents summary via AskUserQuestion
- User confirms
- cd's back to main repo
- Removes worktree: `git worktree remove .worktrees/main-aaa111`
- Reports: "Cleaned up worktree. Remaining branches: 3 (aaa111-*)"
- Branches remain accessible from main repo

**Verify:**
```bash
# Worktree removed
ls .worktrees/main-aaa111/  # Should not exist

# Branches still accessible
git branch | grep "^  aaa111-"  # Should show 3 branches
```

---

### C2: Cleanup with Uncommitted Changes - Confirmation Required

**Setup:**
- Valid worktree
- 2 uncommitted files in worktree

**Execute:**
```bash
/spectacular:cleanup aaa111
```

**Expected:**
- Detects uncommitted changes
- Summary shows: "2 uncommitted files"
- AskUserQuestion warning about losing uncommitted work
- User must explicitly confirm
- If confirmed: removes worktree
- If denied: exits without removal

**Verify:**
```bash
# If denied
ls .worktrees/main-aaa111/  # Should still exist
```

---

### C3: Cleanup with Unpushed Branches

**Setup:**
- Valid worktree
- 3 branches: 1 pushed, 2 never pushed

**Execute:**
```bash
/spectacular:cleanup aaa111
```

**Expected:**
- Summary shows:
  - `aaa111-task-1-1`: pushed
  - `aaa111-task-1-2`: never pushed
  - `aaa111-task-1-3`: never pushed
- Warning about unpushed branches
- User must confirm

---

### C4: Cleanup Orphaned Worktree

**Setup:**
- Worktree: `.worktrees/main-ddd444/`
- No spec file (orphaned)
- May have branches from failed spec attempt

**Execute:**
```bash
/spectacular:cleanup ddd444
```

**Expected:**
- Verifies worktree exists
- Checks orphaned from main repo: spec file doesn't exist
- Skips cd into worktree
- Skips uncommitted check (N/A)
- Checks branches from main repo
- Summary shows: "Orphaned (no spec found)"
- Lists any branches found
- User confirms
- Removes worktree (may need `rm -rf` fallback if git worktree remove fails)
- Reports cleanup

**Verify:**
```bash
# Worktree removed
ls .worktrees/main-ddd444/  # Should not exist

# Branches may remain
git branch | grep "^  ddd444-"
```

---

### C5: Cleanup Nonexistent Worktree

**Execute:**
```bash
/spectacular:cleanup xyz999
```

**Expected:**
- Checks `git worktree list | grep ".worktrees/main-xyz999"`
- Not found
- Error: "Worktree .worktrees/main-xyz999/ not found"
- Exits cleanly

---

### C6: Cleanup Corrupted Worktree

**Setup:**
- Worktree directory exists but git doesn't recognize it
- `git worktree list` doesn't show it

**Execute:**
```bash
/spectacular:cleanup aaa111
```

**Expected:**
- `git worktree remove` fails
- Falls back to: `rm -rf .worktrees/main-aaa111` then `git worktree prune`
- Reports cleanup

**Verify:**
```bash
# Worktree removed
ls .worktrees/main-aaa111/  # Should not exist

# Git refs cleaned
git worktree list  # Should not show removed worktree
```

---

## Multi-Feature Concurrency Scenarios

### M1: Two Features Simultaneously - Spec Phase

**Execute:**
```bash
# Terminal 1
/spectacular:spec "Add user profiles"

# Terminal 2 (while Terminal 1 is brainstorming)
/spectacular:spec "Add notification system"
```

**Expected:**
- Each gets unique runId (e.g., `aaa111`, `bbb222`)
- Each creates separate worktree:
  - `.worktrees/main-aaa111/`
  - `.worktrees/main-bbb222/`
- No interference between features
- Main repo remains clean throughout

**Verify:**
```bash
# Both worktrees exist
ls .worktrees/main-*/

# Main repo clean
git status --porcelain  # Should be empty
```

---

### M2: Spec Feature A While Executing Feature B

**Execute:**
```bash
# Feature B already executing (long-running)
# Start Feature A spec
/spectacular:spec "Add search functionality"
```

**Expected:**
- Feature A spec generation proceeds independently
- Feature B execution continues unaffected
- Separate worktrees: `.worktrees/main-aaa111/`, `.worktrees/main-bbb222/`
- Main repo available for manual work

**Verify:**
```bash
# Can make manual changes in main repo during both operations
echo "test" >> test.txt
git add test.txt
git commit -m "Manual commit"

# Both features unaffected
```

---

### M3: Multiple Features at Different Phases

**Setup:**
- Feature A: executed (5 branches)
- Feature B: spec+plan
- Feature C: spec only
- Feature D: executing (in progress)

**Execute:**
```bash
/spectacular:list
```

**Expected:**
- All features listed with correct phases
- No interference
- Main repo clean

**Verify:**
```bash
ls .worktrees/main-*/  # Shows 4 worktrees
```

---

## Edge Case Scenarios

### EC1: Detached HEAD State Verification

**Setup:**
- Create worktree

**Verify:**
```bash
cd .worktrees/main-aaa111/
git status
```

**Expected:**
- Output: "HEAD detached at <commit>"
- This is intentional (allows independent branch creation)

---

### EC2: Worktree Accessible from Main Repo

**Setup:**
- Create branch in worktree: `aaa111-task-1-1`

**Verify from main repo:**
```bash
cd /path/to/main/repo
git branch | grep "aaa111-task-1-1"  # Should show branch
```

**Expected:**
- Branches created in worktrees are accessible from main repo
- Can switch to them: `git checkout aaa111-task-1-1`

---

### EC3: Path Resolution with @ Prefix

**Execute:**
```bash
/spectacular:plan @specs/aaa111-feature-name/spec.md
```

**Expected:**
- `@` prefix is conventional notation
- Command extracts runId: `aaa111`
- Works correctly

---

### EC4: Long Feature Names - Truncation

**Input:**
```
"Implement comprehensive user authentication system with OAuth2.0 and SAML support including MFA"
```

**Expected slug (50 chars max):**
```
implement-comprehensive-user-authentication-syste
```

**Verify:**
```bash
ls .worktrees/main-{runId}/specs/
# Directory name should be exactly 50 characters
```

---

### EC5: Worktree Prune Behavior

**Setup:**
- List command runs

**Expected:**
- `git worktree prune` runs at start of list command
- No other commands run prune proactively
- `managing-main-worktrees` skill runs prune only for recovery

---

## Integration Point Scenarios

### I1: Git-Spice Commands in Worktree

**Setup:**
- Working in `.worktrees/main-aaa111/`

**Execute:**
```bash
cd .worktrees/main-aaa111/
gs branch create aaa111-task-1-1 -m "Add user model"
gs upstack onto aaa111-task-1-1
gs branch create aaa111-task-1-2 -m "Add user service"
```

**Expected:**
- All git-spice commands work correctly
- Branches stack properly
- Branches accessible from main repo

**Verify:**
```bash
gs ls  # Should show stack
cd ../../
git branch | grep "aaa111-"  # Should show both branches
```

---

### I2: Submodule Handling

**Setup:**
- Main repo has submodules

**Execute:**
```bash
/spectacular:spec "Add feature with submodule"
```

**Expected:**
- Worktree creation handles submodule references
- May need to run `git submodule update --init` in worktree
- Error messages mention submodule init if issues occur

---

### I3: IDE Navigation

**Verify:**
- Open IDE at main repo root
- Navigate to `.worktrees/main-aaa111/specs/aaa111-feature-name/spec.md`
- File should be browsable normally (worktrees are subdirectories)

---

### I4: Constitution Pre-loading in Subagent

**Setup:**
- Run spec command with verbose logging

**Verify:**
- Subagent prompt contains instructions to read constitutions
- Subagent makes Read tool calls for:
  - `@docs/constitutions/current/architecture.md`
  - `@docs/constitutions/current/patterns.md`
  - Others as needed
- Reads happen before brainstorming starts

---

## Test Execution Strategy

### Phase 1: Manual Testing (Pre-Implementation)

1. Create test harness script
2. Run through scenarios manually
3. Document expected vs actual behavior
4. Use for TDD implementation

### Phase 2: Automated Testing (During Implementation)

1. Convert scenarios to automated tests
2. Run continuously during implementation
3. Verify each acceptance criterion

### Phase 3: Integration Testing (Post-Implementation)

1. Full workflow tests (spec → plan → execute → cleanup)
2. Multi-feature concurrency tests
3. Long-running execution tests
4. Edge case validation

---

## Test Data Setup

### Create Test Repository

```bash
# Initialize test repo
mkdir spectacular-test
cd spectacular-test
git init
echo "# Test" > README.md
git add .
git commit -m "Initial commit"

# Add some file structure
mkdir -p src/lib
echo "export const version = '1.0.0';" > src/lib/index.ts
git add .
git commit -m "Add source structure"

# Create package.json for dependency detection tests
cat > package.json << 'EOF'
{
  "name": "test-project",
  "version": "1.0.0",
  "dependencies": {}
}
EOF
git add .
git commit -m "Add package.json"

# Ready for testing
```

---

## Coverage Checklist

Use this to track which scenarios have been tested:

**Spec Command:**
- [ ] S1: Clean state happy path
- [ ] S2: Commit and proceed
- [ ] S3: Stash and proceed
- [ ] S4: Proceed anyway
- [ ] S5: Abort
- [ ] S6: Pre-commit hook failure
- [ ] S7: Feature slug generation
- [ ] S8: Subagent context isolation

**Plan Command:**
- [ ] P1: Generate plan from existing spec
- [ ] P2: Plan without existing worktree
- [ ] P3: Invalid path format

**Execute Command:**
- [ ] E1: Full workflow
- [ ] E2: Dependency detection - CLAUDE.md
- [ ] E3: Dependency detection - Constitution
- [ ] E4: Dependency detection - LLM inference
- [ ] E5: Dependency detection - Skip gracefully
- [ ] E6: Install failure

**List Command:**
- [ ] L1: List active features
- [ ] L2: Staleness detection
- [ ] L3: Behind and ahead
- [ ] L4: Orphaned worktree
- [ ] L5: No default branch
- [ ] L6: Empty list

**Cleanup Command:**
- [ ] C1: Valid worktree, no uncommitted
- [ ] C2: Uncommitted changes
- [ ] C3: Unpushed branches
- [ ] C4: Orphaned worktree
- [ ] C5: Nonexistent worktree
- [ ] C6: Corrupted worktree

**Multi-Feature:**
- [ ] M1: Two specs simultaneously
- [ ] M2: Spec during execution
- [ ] M3: Multiple phases

**Edge Cases:**
- [ ] EC1: Detached HEAD state
- [ ] EC2: Branch accessibility
- [ ] EC3: Path resolution with @
- [ ] EC4: Long feature name truncation
- [ ] EC5: Worktree prune behavior

**Integration:**
- [ ] I1: Git-spice commands
- [ ] I2: Submodule handling
- [ ] I3: IDE navigation
- [ ] I4: Constitution pre-loading

---

## Notes

- Test scenarios are ordered from simple to complex
- Each scenario is independent and repeatable
- Verify commands can be automated with bash scripts
- Expected outputs are specific and measurable
- Coverage checklist ensures complete validation
