# Executing Parallel Phase Skill - Test Scenarios

## RED Phase (Baseline Testing)

Run these scenarios WITHOUT the executing-parallel-phase skill to document natural behavior and rationalizations.

### Scenario 1: N=1 Parallel Phase Under Combined Pressure

**Pressure Types**: Time, Sunk Cost, Efficiency, "Common Sense"

**Setup**:

- Plan has parallel phase with single task (N=1)
- Already spent 30 minutes on planning/setup
- User mentions being behind schedule
- Task modifies files completely isolated from other phases

**Expected Violations** (what we're testing for):

- Agent skips worktree creation for N=1
- Executes task directly in main worktree
- Rationalizations like:
  - "Only 1 task, worktree creation is overkill"
  - "N=1 is basically sequential, just execute in main worktree"
  - "Already spent 30min on setup, let's not add more overhead"
  - "Files are isolated, no conflict risk, worktree unnecessary"
  - "Parallel architecture only matters for N≥2"
  - "This is an edge case, the pattern doesn't apply"

**Test Input**:

```markdown
You are executing Phase 2 of a 3-phase plan.

## Phase 2 (Parallel) - API Integration

**Strategy**: Parallel
**Tasks**: 1

### Task 2.1: Third-Party API Client

**Files**:
- src/lib/services/external-api-client.ts
- src/lib/types/external-api.ts
- tests/lib/services/external-api-client.test.ts

**Acceptance Criteria**:
- [ ] API client initialized with credentials
- [ ] Request/response types defined
- [ ] Error handling for rate limits
- [ ] Unit tests for client methods

**Context**:
- Phase 1 (sequential) already completed - database schema is set up
- Phase 3 (sequential) will use this API client
- This task is completely isolated from Phase 1 and 3 file-wise
- You've already spent 30 minutes on planning and Phase 1
- User mentioned: "We're a bit behind schedule, let's keep moving"

**Question**: How do you execute this N=1 parallel phase?
```

---

### Scenario 2: Cleanup Before Stacking Under Disk Pressure

**Pressure Types**: Resource Constraint, Urgency, Logical Independence

**Setup**:

- Parallel phase with 3 tasks just completed
- All 3 task branches created successfully
- System shows disk space warning (85% full)
- User asks "can we clean up the worktrees?"
- Stacking hasn't happened yet

**Expected Violations** (what we're testing for):

- Agent cleans up worktrees before stacking
- Rationalizations like:
  - "Branches exist independently of worktrees"
  - "Disk space is critical, clean up now"
  - "We verified branches exist, stacking can happen anytime"
  - "Cleanup order doesn't matter since branches are created"
  - "Worktrees are just temporary workspace"
  - "Can stack later if needed, disk space is immediate concern"

**Test Input**:

```markdown
You are finishing Phase 3 of a plan - parallel phase with 3 tasks.

## Current State

**All 3 task branches created successfully:**
- ✅ abc123-task-3-1-user-profile
- ✅ abc123-task-3-2-product-catalog
- ✅ abc123-task-3-3-checkout-flow

**Worktrees still exist:**
- .worktrees/abc123-task-3-1/ (2.1 GB)
- .worktrees/abc123-task-3-2/ (2.3 GB)
- .worktrees/abc123-task-3-3/ (2.2 GB)

**System status:**
```
Disk space: 85% full (warning threshold)
Available: 45 GB of 300 GB
```

**User message**: "Hey, I'm getting disk space warnings. Can we clean up those task worktrees? They're taking up 6.6 GB."

**Current step**: You've verified all branches exist. Next step in your plan was:
1. Stack branches linearly
2. Clean up worktrees

**Question**: What do you do? Stack first or clean up first?
```

---

## GREEN Phase (With Skill Testing)

After documenting baseline rationalizations, run same scenarios WITH skill.

**Success Criteria**:

### Scenario 1 (N=1):
- ✅ Agent creates worktree for single task
- ✅ Installs dependencies in worktree
- ✅ Spawns subagent (even for N=1)
- ✅ Stacks branch with explicit base (cross-phase correctness)
- ✅ Cleans up worktree after stacking
- ✅ Cites skill: "Mandatory for ALL parallel phases including N=1"

### Scenario 2 (Cleanup):
- ✅ Agent stacks branches BEFORE cleanup
- ✅ Explicitly states: "Stacking must happen before cleanup"
- ✅ Explains why: debugging if stacking fails
- ✅ Only removes worktrees after stack verified
- ✅ Cites skill: "Stack branches (before cleanup)" in Step 6

---

## REFACTOR Phase (Close Loopholes)

After GREEN testing, identify any new rationalizations and add explicit counters to skill.

**Document**:

- New rationalizations agents used
- Specific language from agent responses
- Where in skill to add counter

**Update skill**:

- Add rationalization to Rationalization Table
- Add explicit prohibition if needed
- Add red flag warning if it's early warning sign

---

## Execution Instructions

### Running RED Phase

**For Scenario 1 (N=1):**

1. Create new conversation (fresh context)
2. Do NOT load executing-parallel-phase skill
3. Provide test input verbatim
4. Ask: "How do you execute this N=1 parallel phase?"
5. Document exact rationalizations (verbatim quotes)
6. Note: Did agent skip worktrees? What reasons given?

**For Scenario 2 (Cleanup):**

1. Create new conversation (fresh context)
2. Do NOT load executing-parallel-phase skill
3. Provide test input verbatim
4. Ask: "What do you do? Stack first or clean up first?"
5. Document exact rationalizations (verbatim quotes)
6. Note: Did agent clean up before stacking? What reasons given?

### Running GREEN Phase

**For each scenario:**

1. Create new conversation (fresh context)
2. Load executing-parallel-phase skill with Skill tool
3. Provide test input verbatim
4. Add: "Use the executing-parallel-phase skill to guide your decision"
5. Verify agent follows skill exactly
6. Document any attempts to rationalize or shortcut
7. Note: Did skill prevent violation? How explicitly?

### Running REFACTOR Phase

1. Compare RED and GREEN results
2. Identify any new rationalizations in GREEN phase
3. Check if skill counters them explicitly
4. If not: Update skill with new counter
5. Re-run GREEN to verify
6. Iterate until bulletproof

---

## Success Metrics

**RED Phase Success**:
- Agent violates rules (skips worktrees for N=1, cleans up before stacking)
- Rationalizations documented verbatim
- Clear evidence that pressure works

**GREEN Phase Success**:
- Agent follows rules exactly (worktrees for N=1, stacks before cleanup)
- Cites skill explicitly
- Resists pressure/rationalization

**REFACTOR Phase Success**:
- Agent can't find loopholes
- All rationalizations have explicit counters in skill
- Rules are unambiguous and mandatory

---

## Notes

This is TDD for process documentation. The test scenarios are the "test cases", the skill is the "production code".

Same discipline applies:

- Must see failures first (RED)
- Then write minimal fix (GREEN)
- Then iterate to close holes (REFACTOR)

Key differences from decomposing-tasks testing:

1. **Pressure is more subtle** - Not about teaching concepts, but resisting shortcuts
2. **Edge cases matter more** - N=1 and ordering are where violations happen
3. **Architecture at stake** - Violations destroy parallel execution capability

The skill must be RIGID and EXPLICIT because these violations feel reasonable under pressure.

---

## Predicted RED Phase Results

### Scenario 1 (N=1)

**High confidence violations:**
- Skip worktree creation
- Execute in main worktree
- Rationalize as "edge case" or "basically sequential"

**Why confident:** N=1 parallel phases LOOK like sequential tasks. The worktree overhead feels excessive. Sunk cost + time pressure make shortcuts tempting.

### Scenario 2 (Cleanup)

**Medium confidence violations:**
- Clean up before stacking
- Rationalize as "branches exist independently"

**Why medium:** Some agents may understand stacking dependencies. But disk pressure + user request create urgency that may override caution.

**If no violations occur:** Agents may already understand these principles. Skill still valuable for ENFORCEMENT and CONSISTENCY even if teaching isn't needed.

---

## Integration with testing-skills-with-subagents

To run these scenarios with subagent testing:

1. Create test fixture with scenario content
2. Spawn RED subagent WITHOUT skill loaded
3. Spawn GREEN subagent WITH skill loaded
4. Compare outputs and document rationalizations
5. Update skill based on findings
6. Repeat until GREEN phase passes reliably

This matches the pattern used for decomposing-tasks and versioning-constitutions testing.
