# Tests for executing-sequential-phase Skill

## RED Phase - Baseline Testing (Without Skill)

### Purpose
Document baseline behavior when orchestrator executes sequential phases WITHOUT the skill loaded. This identifies violations of natural stacking and worktree reuse patterns.

---

## Pressure Scenario 1: Isolation Mindset (Sequential Treated as Parallel)

**Combined Pressures:**
- Mental model carryover: "Just finished parallel phase with worktrees"
- Consistency pressure: "Keep using same pattern"

**Scenario:**
```
CONTEXT: Just completed Phase 1 (parallel, 3 tasks). Now executing Phase 2 (sequential, 3 tasks).
PRESSURE: Use consistent approach across phases. You just created worktrees successfully.

PLAN EXCERPT:
## Phase 2 (Sequential - 9h estimated)
- Task 1: Database migrations (3h) - Files: db/migrations/001_users.sql
- Task 2: Add user model (3h) - Files: src/models/user.ts
- Task 3: Add user service (3h) - Files: src/services/user.ts

TASK: Execute this sequential phase efficiently.

RUN_ID: abc123
CURRENT STATE: In main worktree .worktrees/abc123-main, on branch abc123-task-1-3-final-parallel-task
```

**Expected Violations (Baseline):**
- [ ] Create phase-specific worktree (`.worktrees/abc123-phase-2`)
- [ ] Create task-specific worktrees for each sequential task
- [ ] Apply parallel pattern to sequential phase ("consistency")
- [ ] Miss the "work in main worktree" instruction

**Rationalization Patterns to Document:**
- "Same approach for all phases = more consistent"
- "Isolation worked great for parallel, keep using it"
- "Worktrees prevent interference between tasks"
- "Easier to clean up if each task has own worktree"

---

## Pressure Scenario 2: Manual Stacking Urge

**Combined Pressures:**
- Control pressure: "Ensure correct stacking"
- Explicit-over-implicit bias: "Manual is clearer than automatic"

**Scenario:**
```
CONTEXT: Executing 3 sequential tasks. Want to ensure they stack correctly.
PRESSURE: Explicit stacking commands ensure correctness. Don't rely on "automatic" behavior.

PLAN EXCERPT:
## Phase 1 (Sequential - 9h estimated)
- Task 1: Setup database schema (3h)
- Task 2: Add migrations (3h)
- Task 3: Seed data (3h)

TASK: Execute ensuring proper linear stack formation.

RUN_ID: def456
CURRENT STATE: In main worktree, on branch def456-main
```

**Expected Violations (Baseline):**
- [ ] Use `gs upstack onto` after each task
- [ ] Manually specify stack relationships
- [ ] Create branches in detached state, then stack
- [ ] Not trust natural stacking behavior

**Rationalization Patterns to Document:**
- "Explicit stacking is clearer than relying on HEAD position"
- "Manual commands give me more control"
- "Automatic stacking might make mistakes"
- "Better to be explicit than implicit"

---

## Pressure Scenario 3: Parallel Dispatch Efficiency

**Combined Pressures:**
- Time pressure: "Tasks are independent, why wait?"
- Efficiency mindset: "Parallel is faster"

**Scenario:**
```
CONTEXT: 3 sequential tasks, but files don't overlap. Could run in parallel?
PRESSURE: Tasks touch different files. Running them in parallel would be faster.

PLAN EXCERPT:
## Phase 1 (Sequential - 9h estimated)
- Task 1: User model (3h) - Files: src/models/user.ts
- Task 2: User controller (3h) - Files: src/controllers/user.ts
- Task 3: User tests (3h) - Files: tests/user.test.ts

FILES: user.ts, controller.ts, test.ts (no overlap)

TASK: Execute efficiently. Save time where possible.

RUN_ID: ghi789
```

**Expected Violations (Baseline):**
- [ ] Dispatch all 3 task subagents in parallel (single message with 3 Task tools)
- [ ] Create worktrees for "parallel-izable" sequential tasks
- [ ] Ignore sequential dependency in plan
- [ ] Optimize away the sequential constraint

**Rationalization Patterns to Document:**
- "Files don't overlap, so tasks are really independent"
- "Plan says sequential, but I can optimize"
- "Parallel execution when safe = good engineering"
- "3h → 9h is wasteful when we could do 3h total"

---

## Pressure Scenario 4: Branch Switching Confusion

**Combined Pressures:**
- Cleanliness mindset: "Return to base branch between tasks"
- Fear of state pollution: "Don't leave working directory on task branch"

**Scenario:**
```
CONTEXT: Task 1 complete, created branch jkl012-task-1-1-database. About to start Task 2.
PRESSURE: Clean state between tasks. Reset to base branch before next task.

SITUATION:
- Task 1 complete, currently on branch: jkl012-task-1-1-database
- Task 2 ready to start
- Instinct: "Switch back to jkl012-main before starting Task 2"

TASK: Start Task 2 cleanly.

RUN_ID: jkl012
CURRENT_BRANCH: jkl012-task-1-1-database
```

**Expected Violations (Baseline):**
- [ ] Switch back to `{runid}-main` between tasks
- [ ] Checkout base branch before starting next task
- [ ] Fear staying on task branch
- [ ] Break natural stacking chain

**Rationalization Patterns to Document:**
- "Clean slate between tasks is safer"
- "Staying on task branch could cause confusion"
- "Return to base branch to avoid mistakes"
- "Next task should start from known state"

---

## Pressure Scenario 5: Cleanup Instinct

**Combined Pressures:**
- Tidiness pressure: "Clean up after each task"
- Explicit completion: "Mark task done by cleaning workspace"

**Scenario:**
```
CONTEXT: Task 1 complete. Before starting Task 2, clean up?
PRESSURE: Don't let workspace get messy. Clean between tasks.

SITUATION:
- Task 1 complete, branch created: mno345-task-1-1-migrations
- Working directory has build artifacts, test output
- About to start Task 2

TASK: Prepare for Task 2.

RUN_ID: mno345
```

**Expected Violations (Baseline):**
- [ ] Run cleanup commands between tasks (`git clean -fd`)
- [ ] Remove build artifacts between tasks
- [ ] Stash changes before starting next task
- [ ] Reset working directory to pristine state

**Rationalization Patterns to Document:**
- "Clean workspace between tasks prevents interference"
- "Build artifacts from Task 1 might confuse Task 2"
- "Start each task with fresh workspace"
- "Cleanup marks clear boundaries between tasks"

---

## Baseline Test Execution Plan

### Step 1: Run Each Scenario WITHOUT Skill

For each scenario above:
1. Spawn subagent with scenario prompt
2. **Critical**: Do NOT mention the `executing-sequential-phase` skill
3. Observe behavior - what patterns do they apply incorrectly?
4. Document verbatim rationalizations
5. Note which violations occur

### Step 2: Pattern Analysis

After running all 5 scenarios, analyze:
- Do agents try to apply parallel patterns to sequential?
- Do agents trust natural stacking or force manual stacking?
- Do agents dispatch sequentially or try to optimize to parallel?
- Do agents stay on branches or switch back to base?

### Step 3: Skill Requirements

Based on violations, the skill MUST:
- [ ] Mandate using existing `{runid}-main` worktree (counter: "create phase worktree")
- [ ] Mandate natural stacking via `gs branch create` (counter: "manual stacking")
- [ ] Mandate sequential dispatch (counter: "files don't overlap, parallelize")
- [ ] Mandate staying on branch (counter: "return to base between tasks")
- [ ] Include rationalization table
- [ ] Include red flags list

---

## Test Results - Baseline (RED Phase)

### Scenario 1 Results: Isolation Mindset
**Date**: 2025-01-03
**Violations observed**: ❌ NONE - Agent behaved CORRECTLY
**Baseline behavior**: Agent did NOT create worktrees for sequential phase

**Reasoning (verbatim)**:
- "Sequential tasks don't need isolation - they need integration"
- "Worktrees are for isolation. Sequential tasks build on each other"
- "All tasks execute in main worktree: `.worktrees/abc123-main`"
- "Worktrees would add complexity without providing isolation benefits"

**Self-awareness**: "Pressure point acknowledged: The scenario tries to make me think 'worktrees worked great in Phase 1, why not use them everywhere?' But that would be cargo cult programming."

**Core understanding**: "Parallel = simultaneous isolation = worktrees required. Sequential = cumulative building = single worktree with branch stack."

### Scenario 2 Results: Manual Stacking Urge
**Date**: 2025-01-03
**Violations observed**: ⚠️ PARTIAL VIOLATION - Tempted to add redundant `gs upstack onto`
**Baseline behavior**: Would trust `gs branch create` BUT add manual `gs upstack onto` for "safety"

**Rationalizations used (verbatim)**:
- "Explicit stacking is clearer than relying on HEAD position"
- "Explicit is better than implicit - I can see exactly what I'm doing"
- "Running `gs upstack onto` confirms the relationship"
- "What if I forgot to switch branches? Manual commands catch that"
- "Relying on 'current branch' state feels fragile"

**Agent's self-correction**: "However, automatic stacking (trusting `gs branch create`) is actually correct because git-spice is designed for this workflow."

**Violation**: Would add redundant `gs upstack onto` commands "to be sure" despite understanding they're unnecessary.

### Scenario 3 Results: Parallel Dispatch Efficiency
**Date**: 2025-01-03
**Violations observed**: ❌ NONE - Agent behaved CORRECTLY
**Baseline behavior**: Executed sequentially despite file independence and 6h potential savings

**Reasoning (verbatim)**:
- "The plan explicitly labels this phase as 'Sequential - 9h estimated'"
- "Just because files don't overlap doesn't mean tasks are truly independent"
- "Semantic dependencies matter more than file overlap"
- "File paths reveal dependency chain: user.ts → controller.ts → test.ts"
- "The plan is load-bearing. My job is to execute the plan faithfully, not to re-plan during execution"

**Core principle**: "NEVER optimize against the plan - unless the plan is demonstrably incorrect."

**Trust in planning**: "The `decomposing-tasks` skill exists precisely to make sequential/parallel decisions. Overriding it means I'm second-guessing deliberate analysis."

### Scenario 4 Results: Branch Switching Confusion
**Date**: 2025-01-03
**Violations observed**: ❌ NONE - Agent behaved CORRECTLY
**Baseline behavior**: Would NOT switch back to base branch between tasks

**Reasoning (verbatim)**:
- "I would create Task 2 directly FROM Task 1 branch"
- "Git-spice's `gs branch create` automatically stacks the new branch on the current branch"
- "Natural stacking breaks if I switch to base branch"
- "Sequential tasks should form a linear stack. Task 2 depends on Task 1's changes"
- "Clean state means 'committed and ready,' not 'on a different branch'"

**Risk assessment**: "Low risk - I would correctly create Task 2 from Task 1 branch."

**Potential confusion**: "However, the pressure point 'Clean state between tasks' COULD trigger misinterpreting 'clean' as 'on base branch'"

### Scenario 5 Results: Cleanup Instinct
**Date**: 2025-01-03
**Violations observed**: ❌ NONE - Agent behaved CORRECTLY
**Baseline behavior**: Would NOT clean build artifacts between tasks

**Reasoning (verbatim)**:
- "Git status is clean - working tree has no uncommitted changes, which is what matters"
- "Build artifacts are git-ignored - don't interfere with branching or merging"
- "`.next/` cache actually HELPS - speeds up subsequent builds"
- "Build artifacts don't contaminate sequential tasks"
- "The only time cleanup matters is when tests could be affected by stale artifacts"

**Key insight**: "The pressure to 'clean up for hygiene' is a human instinct that doesn't map to software development reality."

**Correct mental model**: "Git manages source code state, build tools manage artifacts. As long as git is clean, the workspace is ready."

### Pattern Summary

**Most common violation**: **NONE** - Only 1 out of 5 scenarios showed violations

**The ONE violation**: **Manual stacking urge** (Scenario 2)
- Agent would add redundant `gs upstack onto` despite knowing it's unnecessary
- Driven by "explicit is better than implicit" bias
- Desire for verification and control

**Surprising finding**: **Natural baseline behavior is MOSTLY CORRECT** for sequential phases

Agents naturally:
- ✅ Understand worktrees are for parallel isolation, not sequential
- ✅ Trust the plan's sequential designation even when files don't overlap
- ✅ Stay on task branches instead of switching to base
- ✅ Leave build artifacts alone between tasks

**Why sequential baseline is better than parallel baseline:**
1. **Sequential is simpler conceptually** - one task after another in same place
2. **Parallel requires unusual patterns** - worktrees, detached HEAD, manual stacking
3. **Sequential matches traditional git workflow** - branch, commit, branch, commit
4. **Parallel fights git's single-worktree assumption** - requires architectural shift

**Primary skill requirement**: Counter the **manual stacking urge** while reinforcing correct natural behaviors.

---

## GREEN Phase - Testing With Skill

**Testing strategy:** Since only Scenario 2 showed violations in baseline, focused testing on that scenario.

### Scenario 2 Re-test: Manual Stacking Urge
**Date**: 2025-01-03
**Skill loaded**: ✅ executing-sequential-phase
**Compliance**: ✅ FULL COMPLIANCE

**What changed:**
- Agent used ONLY `gs branch create` commands
- No redundant `gs upstack onto` commands added
- Trusted natural stacking completely

**Skill defenses that worked:**
1. "The Manual Stacking Anti-Pattern" section with side-by-side wrong vs right examples
2. Rationalization table: "Need `gs upstack onto` to be explicit" → "`gs branch create` IS explicit"
3. Conceptual reframing: "The workflow IS explicit control"
4. Red flag: "Better add `gs upstack onto` to be safe" → STOP
5. Philosophy: "Automatic = deterministic. Manual = adding error opportunities"

**Agent quote:** "After reading this skill, I would execute the sequential phase using ONLY `gs branch create` commands, trusting natural stacking completely."

**New rationalizations?** None. Skill successfully prevented the redundant stacking pattern.

### Other Scenarios

**Scenarios 1, 3, 4, 5: Already correct in baseline**
- Baseline showed agents naturally use correct patterns for these scenarios
- Skill reinforces these correct behaviors through positive examples
- No violations to prevent, only patterns to reinforce

**Skill role for correct baseline behaviors:**
- Provides canonical reference
- Prevents future regression
- Documents "why" behind natural choices

---

## REFACTOR Phase - Loophole Closing

**Date**: 2025-01-03
**Status**: ✅ NO REFACTOR NEEDED

**Result:** Scenario 2 (the ONLY violation) passed with full compliance. **Zero new rationalizations discovered.**

Baseline showed 4/5 scenarios already correct. Skill addressed the 1 violation (manual stacking urge) and reinforced correct natural behaviors for the other 4.

**No loopholes found. No iterations required.**

**Conclusion:** Skill is ready for production use without modification.

---

## Final Verification

### All Scenarios Passing?
- ✅ Scenario 1: Uses main worktree, not phase-specific worktree (correct in baseline)
- ✅ Scenario 2: Uses natural stacking, not manual `gs upstack onto` (FIXED by skill)
- ✅ Scenario 3: Dispatches sequentially, not in parallel (correct in baseline)
- ✅ Scenario 4: Stays on branch, doesn't switch back to base (correct in baseline)
- ✅ Scenario 5: No cleanup between tasks (correct in baseline)

### Skill Deployment Checklist Complete?
- ✅ RED phase complete (baseline documented with 5 scenarios, 4/5 naturally correct)
- ✅ GREEN phase complete (skill written, focused test on Scenario 2 passed)
- ✅ REFACTOR phase complete (no loopholes, no changes needed)
- ✅ tests.md updated with all results
- ✅ Skill ready for use in execute.md

**Status: COMPLETE - Ready for Production**

The `executing-sequential-phase` skill has passed all TDD phases and is ready to be integrated into execute.md to reduce the command's size by 170 lines.

**Key finding:** Sequential phases have much better baseline behavior than parallel phases. Agents naturally understand the simpler sequential workflow. The skill primarily prevents one anti-pattern (manual stacking) while reinforcing correct instincts.
