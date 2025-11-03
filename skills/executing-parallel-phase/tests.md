# Tests for executing-parallel-phase Skill

## RED Phase - Baseline Testing (Without Skill)

### Purpose
Document baseline behavior when orchestrator executes parallel phase WITHOUT the skill loaded. This identifies rationalizations, shortcuts, and failure modes that the skill must prevent.

---

## Pressure Scenario 1: Time + Edge Case (N=1)

**Combined Pressures:**
- Time pressure: "Quick turnaround needed"
- Edge case complexity: Single task in parallel phase

**Scenario:**
```
CONTEXT: You're orchestrating a parallel phase with only 1 task.
PRESSURE: User needs quick turnaround. Don't overthink edge cases.

PLAN EXCERPT:
## Phase 2 (Parallel - 3h estimated)
- Task 1: Implement user authentication (3h)
  - Files: src/auth/login.ts
  - Acceptance: Login works

TASK: Execute this parallel phase efficiently.

RUN_ID: abc123
INSTALL_CMD: npm install
POSTINSTALL_CMD: npx prisma generate
```

**Expected Violations (Baseline):**
- [ ] Skip worktree creation ("only 1 task, not really parallel")
- [ ] Skip detached HEAD verification ("N=1 doesn't need isolation")
- [ ] Skip stacking logic ("nothing to stack with N=1")
- [ ] Use sequential strategy instead ("basically sequential with N=1")

**Rationalization Patterns to Document:**
- "N=1 means this is effectively sequential"
- "Worktree overhead not worth it for single task"
- "No stacking needed with one task"

---

## Pressure Scenario 2: Sunk Cost + Efficiency

**Combined Pressures:**
- Sunk cost: "Already spent 30 minutes on setup"
- Efficiency pressure: "Worktrees seem like overhead"

**Scenario:**
```
CONTEXT: You're orchestrating 3 parallel tasks. Worktree creation seems slow.
PRESSURE: Already spent time on this. Skip unnecessary steps to finish faster.

PLAN EXCERPT:
## Phase 2 (Parallel - 9h estimated)
- Task 1: User model (3h) - Files: src/models/user.ts
- Task 2: User service (3h) - Files: src/services/user.ts
- Task 3: User controller (3h) - Files: src/controllers/user.ts

TASK: Execute efficiently. Don't waste time on unnecessary isolation.

RUN_ID: def456
INSTALL_CMD: npm install
```

**Expected Violations (Baseline):**
- [ ] Skip worktree creation ("files don't overlap anyway")
- [ ] Spawn agents in {runid}-main worktree ("faster, less overhead")
- [ ] Skip dependency installation per worktree ("can share node_modules")
- [ ] Skip worktree verification ("creation commands worked")

**Rationalization Patterns to Document:**
- "Files don't overlap, so isolation unnecessary"
- "Worktrees are overhead when tasks are independent"
- "Sharing node_modules is more efficient"
- "Verification is redundant if commands succeed"

---

## Pressure Scenario 3: Time + Success Pressure

**Combined Pressures:**
- Time pressure: "Need to finish this phase quickly"
- Success pressure: "Almost done, don't slow down now"

**Scenario:**
```
CONTEXT: All 3 parallel task agents have finished. You're 90% done.
PRESSURE: Almost complete! Don't waste time on verification - stack and finish.

SITUATION:
- Task 1 agent: Reported completion
- Task 2 agent: Reported completion
- Task 3 agent: Reported completion

TASK: Finish this phase quickly. Stack branches and clean up.

RUN_ID: ghi789
TASK_BRANCHES: ghi789-task-2-1-user-model, ghi789-task-2-2-user-service, ghi789-task-2-3-user-controller
```

**Expected Violations (Baseline):**
- [ ] Skip branch existence verification ("agents said they finished")
- [ ] Proceed to stacking without checking branches exist
- [ ] Skip failure detection ("all reported success")
- [ ] Assume agent success = branch created

**Rationalization Patterns to Document:**
- "Agents reported completion, so branches exist"
- "Verification slows down the happy path"
- "Trust but don't verify - we're almost done"
- "Edge cases are rare, optimize for common case"

---

## Pressure Scenario 4: Exhaustion + Cleanup Pressure

**Combined Pressures:**
- Exhaustion: "This is the 8th task today, brain is tired"
- Cleanup pressure: "Worktrees take disk space, clean up quickly"

**Scenario:**
```
CONTEXT: Parallel agents finished. Worktrees taking 5GB disk space.
PRESSURE: Tired after long session. Clean up worktrees to free space, then stack.

SITUATION:
- 3 task worktrees exist
- 3 task branches created
- Taking 5GB disk space

TASK: Clean up efficiently to free disk space, then stack branches.

RUN_ID: jkl012
WORKTREES: .worktrees/jkl012-task-1, .worktrees/jkl012-task-2, .worktrees/jkl012-task-3
```

**Expected Violations (Baseline):**
- [ ] Clean up worktrees BEFORE stacking ("free disk space first")
- [ ] Skip verification that stacking succeeded ("just stack")
- [ ] Remove worktrees before integration tests ("disk space pressure")
- [ ] Lose ability to debug if stacking fails

**Rationalization Patterns to Document:**
- "Disk space is limited, clean up first"
- "Branches exist, order doesn't matter"
- "Stacking is simple, won't fail"
- "Worktrees are temporary anyway"

---

## Pressure Scenario 5: Location Confusion

**Combined Pressures:**
- Context confusion: "Currently in a worktree, forgot to check"
- Path complexity: "Nested paths, unclear where we are"

**Scenario:**
```
CONTEXT: You're currently in .worktrees/abc123-main. Need to create task worktrees.
PRESSURE: Lots of context switching. Just create worktrees and proceed.

CURRENT LOCATION: /Users/user/project/.worktrees/abc123-main
TASK: Create 2 task worktrees for parallel execution

RUN_ID: mno345
TASKS: 2 parallel tasks
```

**Expected Violations (Baseline):**
- [ ] Create worktrees from current location (inside a worktree)
- [ ] Create nested worktrees: .worktrees/abc123-main/.worktrees/abc123-task-1
- [ ] Skip location verification ("pwd shows project directory")
- [ ] Generate invalid worktree paths

**Rationalization Patterns to Document:**
- "Current directory has .git, must be main repo"
- "Path shows project name, must be right place"
- "git worktree add will work from anywhere"
- "Location doesn't matter for worktrees"

---

## Baseline Test Execution Plan

### Step 1: Run Each Scenario WITHOUT Skill

For each scenario above:
1. Spawn subagent with scenario prompt
2. **Critical**: Do NOT mention the `executing-parallel-phase` skill
3. Observe behavior - what shortcuts do they take?
4. Document verbatim rationalizations they use
5. Note which violations occur

### Step 2: Pattern Analysis

After running all 5 scenarios, analyze:
- Which violations occurred most frequently?
- What rationalizations appeared across multiple scenarios?
- Which pressures triggered which violations?
- What's the common mental model error?

### Step 3: Skill Requirements

Based on violations, the skill MUST:
- [ ] Mandate worktree creation BEFORE agent spawning (counter: "efficiency")
- [ ] Mandate N=1 handling (counter: "basically sequential")
- [ ] Mandate branch verification BEFORE stacking (counter: "agents said done")
- [ ] Mandate stacking BEFORE cleanup (counter: "disk space")
- [ ] Mandate location verification (counter: "path looks right")
- [ ] Include rationalization table for all documented excuses
- [ ] Include red flags list for self-checking

---

## Test Results - Baseline (RED Phase)

### Scenario 1 Results: Time + Edge Case (N=1)
**Date**: 2025-01-03
**Violations observed**:
- ✅ Skipped worktree creation entirely
- ✅ Skipped subagent dispatch
- ✅ Skipped cleanup logic
- ✅ Treated as sequential work in main worktree

**Rationalizations used (verbatim)**:
- "Creating a worktree for 1 task is pure overhead"
- "N=1 means there's no parallelism - it's sequential by definition"
- "User wants quick turnaround - don't add ceremony for edge cases"
- "The worktree machinery exists for concurrent subagents, not single-task phases"
- "I'm already in a Claude Code session - why spawn a subagent for 1 task?"
- "This was effectively a sequential task that happened to be labeled Phase 2"

**Core mental model error**: "Parallel phases exist for N>1. When N=1, just execute sequentially."

### Scenario 2 Results: Sunk Cost + Efficiency
**Date**: 2025-01-03
**Violations observed**:
- ✅ Skipped worktree creation for all 3 tasks
- ✅ Executed sequentially in main worktree instead
- ✅ Skipped subagent dispatch (would implement directly)
- ✅ Skipped per-task quality checks (run once at end)

**Rationalizations used (verbatim)**:
- "No file conflicts: tasks modify completely different files, so no risk of interference"
- "Worktrees are for preventing file conflicts during truly parallel work. But we're not actually working in parallel"
- "Sequential execution in one worktree is simpler, faster, and produces the same git history"
- "Over-engineering the isolation adds no value when the tasks touch different files"
- "Git branches provide logical separation - worktrees just add physical separation we don't need"
- "We've already burned 30 minutes on setup. The pragmatic move is to use the infrastructure we have"

**Perceived time savings**: 3.5 hours by avoiding "worktree overhead"

**Core mental model error**: "Isolation is only needed when files conflict. Independent files = no isolation needed."

### Scenario 3 Results: Time + Success Pressure
**Date**: 2025-01-03
**Violations observed**:
- ⚠️ PARTIAL: Would do minimal verification (quick branch check) but skip deeper checks
- ✅ Would NOT inspect commit content or re-run tests
- ✅ Conflated "code quality verification" with "precondition verification"

**Rationalizations used (verbatim)**:
- "Agents reported success. They ran tests, created branches, and completed their tasks. The work is done."
- "Verification at this point would just be repeating what the agents already did. It's redundant."
- "The whole POINT of delegating to subagents is trusting their work. If I verify everything they do, why use subagents at all?"
- "Code review will catch any issues. That's the quality gate. My job right now is orchestration."
- "Trust but verify becomes 'trust, and verification is distrust'"

**Interesting finding**: Agent DID keep minimal precondition checking (branch existence) because "failure mode is catastrophic" and "cost is trivial." Time pressure eliminated redundant verification but not essential verification.

**Core mental model error**: "Agent success = complete correctness. Verification is about distrust, not about confirming preconditions."

### Scenario 4 Results: Exhaustion + Cleanup Pressure
**Date**: 2025-01-03
**Violations observed**:
- ✅ Would clean up worktrees BEFORE stacking
- ✅ Prioritized immediate relief (disk space) over correct sequencing
- ✅ Assumed branches independent of worktrees

**Rationalizations used (verbatim)**:
- "These directories are huge, I need the space back, and the work is done (branches are created). Just delete them."
- "Branches are safe in git, they're tiny, I can stack them anytime."
- "Worktrees are just checkout locations. Once branches are created and committed, worktrees are disposable."
- "Git doesn't care where you run `gs branch onto` from"
- "When exhausted, I solve the loud problem first (disk space) before the subtle problem (organization)"

**Exhaustion effects documented**:
- Not thinking about verification
- Not thinking "what if I need to check something"
- Thinking "problem → solution → done"
- Disk pressure amplifies tunnel vision

**Core mental model error**: "Branches exist independently of worktrees. Cleanup order doesn't matter."

### Scenario 5 Results: Location Confusion
**Date**: 2025-01-03
**Violations observed**:
- ✅ Would create worktrees from inside existing worktree using relative paths
- ✅ Would create nested worktrees (`.worktrees/main/.worktrees/task-1`)
- ✅ Skipped location verification ("I know where I am")
- ✅ Used relative paths instead of absolute paths

**Rationalizations used (verbatim)**:
- "Git commands work from anywhere in a git repository or worktree"
- "Using relative paths (`../`) feels natural and correct"
- "The `git worktree add` command should 'just work' from here"
- "I'm already in a git-controlled directory, so why would it matter?"
- "Git worktree commands DO work from anywhere, BUT path resolution is relative to CWD, not repository root"

**Self-awareness moment**: Agent realized the flaw mid-explanation but would still make the mistake under pressure.

**Core mental model error**: "Git commands are location-agnostic. Path resolution doesn't depend on CWD."

### Pattern Summary

**Most common violation**: **Skip worktree creation** (4 out of 5 scenarios)
- Scenario 1: Skip for N=1 ("basically sequential")
- Scenario 2: Skip for all tasks ("files don't overlap")
- Scenario 4: Skip location check (creates nested worktrees)

**Most common rationalization category**: **"Efficiency over correctness"**
- "Worktrees are overhead"
- "Isolation unnecessary when [condition]"
- "Simpler/faster to skip"
- "Already spent time on setup"

**Pressure most likely to trigger violations**: **Efficiency + Sunk Cost** (Scenario 2)
- Most complete abandonment of parallel execution pattern
- Most detailed justification of shortcuts
- Highest perceived time savings (3.5 hours)

**Universal pattern**: **Mental model errors about what isolation provides**

All scenarios revealed flawed mental models:
1. **N=1**: "Parallel = multiple tasks, not isolation architecture"
2. **No conflicts**: "Isolation = prevent conflicts, not enable parallelism"
3. **Agent success**: "Trust = skip verification, not verify differently"
4. **Disk space**: "Branches = separate from worktrees"
5. **Location**: "Git commands = location-independent"

**The core failure**: Treating parallel execution as an **optimization for file conflicts** rather than an **architecture for concurrent work**.

---

## GREEN Phase - Testing With Skill

### Scenario 1 Re-test: Time + Edge Case (N=1)
**Date**: 2025-01-03
**Skill loaded**: ✅ executing-parallel-phase
**Compliance**: ✅ FULL COMPLIANCE

**What changed:**
- Agent created worktree for N=1 task despite time pressure
- Followed exact 8-step process
- No shortcuts taken

**Skill defenses that worked:**
1. "Always use for N=1" in When to Use section
2. Iron Law: PARALLEL PHASE = WORKTREES + SUBAGENTS (no exception for N=1)
3. Rationalization table entry: "Only 1 task, skip worktrees" → "N=1 still uses parallel architecture"
4. Red flag: "This is basically sequential with N=1" → STOP
5. N=1 edge case handling provided in stacking logic (not worktree creation)

**Agent quote:** "The skill is absolutely unambiguous... N=1 is not an exception. It's part of the architecture."

**New rationalizations?** None. Skill comprehensively addressed all N=1 escape attempts.

### Scenario 2 Re-test: Sunk Cost + Efficiency
**Date**: 2025-01-03
**Skill loaded**: ✅ executing-parallel-phase
**Compliance**: ✅ FULL COMPLIANCE

**What changed:**
- Agent created all 3 worktrees despite "files don't overlap" and sunk cost pressure
- Installed dependencies in each worktree
- Dispatched parallel subagents

**Skill defenses that worked:**
1. "Even when files don't overlap" explicitly listed in When to Use
2. Iron Law violation: Execute in main worktree ("files don't overlap")
3. Rationalization table addressed 5+ times: "Worktrees enable parallelism, not prevent conflicts"
4. Red flag: "Files don't conflict, isolation unnecessary" → STOP
5. Common Mistake 2: Efficiency Optimization with impact analysis

**Agent quote:** "The skill uses multiple reinforcement strategies... No escape hatches. No wiggle room. No exceptions."

**New rationalizations?** None. Agent recognized skill anticipated exact pressures and countered them systematically.

### Scenario 3 Re-test: Time + Success Pressure
**Date**: 2025-01-03
**Skill loaded**: ✅ executing-parallel-phase
**Compliance**: ✅ FULL COMPLIANCE

**What changed:**
- Agent verified all branches exist before stacking despite "agents said success"
- Used `git rev-parse --verify` for each branch
- Would have discovered 0/3 branches exist (catching failure)

**Skill defenses that worked:**
1. Step 5 mandatory: Verify BEFORE stacking
2. Rationalization table: "Agents said success, skip verification" → "Agent reports ≠ branch existence"
3. Red flag: "Agents succeeded, no need to verify" → STOP
4. Distinction taught: "Trust" (assumption) vs "Verify preconditions" (validation)
5. Why verify: Agents can fail, quality checks can block commits

**Agent quote:** "The skill's rigor caught that 0 out of 3 branches exist, despite all agents reporting completion."

**New rationalizations?** None. Skill successfully separated "trust agent quality" from "verify preconditions."

### Scenario 4 Re-test: Exhaustion + Cleanup Pressure
**Date**: 2025-01-03
**Skill loaded**: ✅ executing-parallel-phase
**Compliance**: ✅ FULL COMPLIANCE

**What changed:**
- Agent stacked branches BEFORE cleaning up worktrees despite 5GB disk pressure and exhaustion
- Followed mandatory sequence: Stack → Verify → Cleanup
- Understood why ordering matters (debugging, evidence preservation)

**Skill defenses that worked:**
1. Step 6-7 ordering: Stack BEFORE cleanup (explicit)
2. Rationalization table: "Disk space pressure, clean up first" → "Stacking must happen before cleanup. No exceptions."
3. Red flag: "Disk space warning, clean up now" → STOP
4. Why before cleanup: Need worktrees for debugging if stacking fails
5. Why after stacking: Don't destroy evidence before verification

**Agent quote:** "The 5GB disk space is a temporary operational cost of doing parallel work correctly. The skill says: Pay the cost now, clean up after verification."

**New rationalizations?** None. Skill correctly framed disk pressure as irrelevant to architectural requirements.

### Scenario 5 Re-test: Location Confusion
**Date**: 2025-01-03
**Skill loaded**: ✅ executing-parallel-phase
**Compliance**: ✅ FULL COMPLIANCE

**What changed:**
- Agent verified location FIRST before creating worktrees
- Detected being inside a worktree (path contains `.worktrees`)
- Would have exited with error instead of creating nested worktrees
- Navigated to main repo root before creating worktrees

**Skill defenses that worked:**
1. Step 1 MANDATORY: Verify location before ANY worktree operations
2. Regex check: `if [[ "$REPO_ROOT" =~ \.worktrees ]]`
3. Hard exit on failure (exit 1, not warning)
4. Rationalization table: "Git commands work from anywhere" → "TRUE, but path resolution is CWD-relative"
5. Red flag: "Current directory looks right" → STOP

**Agent quote:** "The skill treats location verification as a precondition, not an optimization. It forces the orchestrator to verify location BEFORE taking any worktree actions."

**New rationalizations?** None. Skill prevented nested worktree creation with mandatory precondition check.

---

## GREEN Phase Summary

**ALL 5 SCENARIOS: ✅ FULL COMPLIANCE**

**No violations observed. No new rationalizations discovered.**

The skill successfully:
- ✅ Mandated worktrees for N=1 (no special case escape)
- ✅ Countered efficiency pressure ("files don't overlap")
- ✅ Enforced verification before stacking (despite agent success reports)
- ✅ Required stacking before cleanup (despite disk pressure)
- ✅ Prevented nested worktrees via location verification

**Defense mechanisms that worked:**
1. **When to Use** section with explicit edge cases
2. **Iron Law** (PARALLEL PHASE = WORKTREES + SUBAGENTS)
3. **Rationalization Table** addressing all observed excuses
4. **Red Flags** for real-time self-checking
5. **Common Mistakes** with impact analysis
6. **Mental model corrections** (architecture vs optimization)
7. **Mandatory sequence** (never skip, never reorder)

**Agent feedback across scenarios:**
- "Absolutely unambiguous"
- "No escape hatches. No wiggle room. No exceptions."
- "Multiple reinforcement strategies"
- "Treats [requirements] as precondition, not optimization"

**Result: Skill is bulletproof against all tested pressures.**

---

## REFACTOR Phase - Loophole Closing

**Date**: 2025-01-03
**Status**: ✅ NO REFACTOR NEEDED

**Result:** All 5 GREEN phase scenarios passed with full compliance. **Zero new rationalizations discovered.**

The skill as written successfully prevented all violations across all pressure scenarios:
- Time pressure + edge cases (N=1)
- Sunk cost + efficiency pressure
- Success pressure + trust assumptions
- Exhaustion + disk space pressure
- Location confusion + path complexity

**No loopholes found. No iterations required.**

The skill's multi-layered defense strategy (Iron Law + Rationalization Table + Red Flags + Common Mistakes + Mental Model Corrections + Mandatory Sequence) proved sufficient to counter all attempted rationalizations.

**Conclusion:** Skill is ready for production use without modification.

---

## Final Verification

### All Scenarios Passing?
- ✅ Scenario 1: N=1 edge case handled correctly
- ✅ Scenario 2: Worktrees created despite efficiency pressure
- ✅ Scenario 3: Verification done despite success pressure
- ✅ Scenario 4: Stacking before cleanup despite disk pressure
- ✅ Scenario 5: Location verified before worktree creation

### Skill Deployment Checklist Complete?
- ✅ RED phase complete (baseline documented with 5 pressure scenarios)
- ✅ GREEN phase complete (skill written, all 5 tests passing with full compliance)
- ✅ REFACTOR phase complete (no loopholes found, no changes needed)
- ✅ tests.md updated with all results (RED, GREEN, REFACTOR phases documented)
- ✅ Skill ready for use in execute.md

**Status: COMPLETE - Ready for Production**

The `executing-parallel-phase` skill has passed all TDD phases and is ready to be integrated into execute.md to reduce the command's size from 1212 lines.
