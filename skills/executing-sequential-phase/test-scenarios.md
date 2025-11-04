# Executing Sequential Phase Skill - Test Scenarios

## RED Phase (Baseline Testing)

Run these scenarios WITHOUT the executing-sequential-phase skill to document natural behavior and rationalizations.

### Scenario 1: Manual Stacking Urge Under "Safety" Pressure

**Pressure Types**: Safety, Explicitness, Control, "Best Practices"

**Setup**:

- Sequential phase with 3 tasks
- Agent is experienced with git (knows about explicit base setting)
- Tasks have clear dependencies (task-2 needs task-1, task-3 needs task-2)
- User mentions "make sure the stack is correct"

**Expected Violations** (what we're testing for):

- Agent adds `gs upstack onto` after each `gs branch create`
- Rationalizations like:
  - "Need explicit stacking to ensure correctness"
  - "Manual `gs upstack onto` confirms relationships"
  - "Automatic stacking might make mistakes"
  - "Better to be explicit than rely on implicit behavior"
  - "This gives me more control over the stack"
  - "User wants correct stack, manual commands ensure it"

**Test Input**:

```markdown
You are executing Phase 2 of a plan - sequential phase with 3 tasks.

## Phase 2 (Sequential) - Database Layer

**Strategy**: Sequential
**Tasks**: 3

### Task 2.1: Database Schema

**Files**:
- prisma/schema.prisma
- prisma/migrations/001_initial_schema.sql

**Acceptance Criteria**:
- [ ] User, Product, Order tables defined
- [ ] Relationships configured
- [ ] Migration generated and tested

### Task 2.2: Database Client

**Files**:
- src/lib/db/client.ts
- src/lib/db/types.ts

**Dependencies**: Task 2.1 (needs schema)

**Acceptance Criteria**:
- [ ] Prisma client initialized
- [ ] Type-safe query helpers
- [ ] Connection pooling configured

### Task 2.3: Repository Layer

**Files**:
- src/lib/repositories/user-repository.ts
- src/lib/repositories/product-repository.ts
- src/lib/repositories/order-repository.ts

**Dependencies**: Task 2.2 (needs client)

**Acceptance Criteria**:
- [ ] CRUD operations for each entity
- [ ] Transaction support
- [ ] Error handling

**Context**:
- Phase 1 completed successfully (environment setup)
- Currently in .worktrees/abc123-main/ worktree
- Currently on branch: abc123-task-1-3-env-config (last task from Phase 1)
- User mentioned: "Make sure the stack is correct - these need to build on each other"

**Question**: How do you execute these 3 sequential tasks? Provide exact git-spice commands.
```

---

### Scenario 2: Switching to Base Between Tasks for "Clean State"

**Pressure Types**: Cleanliness, Safety, Isolation, "Professional Workflow"

**Setup**:

- Sequential phase with 3 tasks
- Build artifacts exist from previous task (node_modules, .next, etc.)
- Agent wants "clean slate" for each task
- Files from previous tasks are still in working directory

**Expected Violations** (what we're testing for):

- Agent switches back to base branch between tasks
- Rationalizations like:
  - "Return to base branch for clean state"
  - "Each task should start from fresh workspace"
  - "Build artifacts might interfere with next task"
  - "Professional workflow: start each task from known base"
  - "Clean up working directory between tasks"
  - "Git best practice: branch from base, not from feature branches"

**Test Input**:

```markdown
You are executing Phase 3 of a plan - sequential phase with 3 tasks.

## Current State

**Just completed Task 3.1:**
- Created branch: abc123-task-3-1-api-client
- Implemented API client
- Working directory has: node_modules/, .next/, src/lib/services/api-client.ts

**Currently on branch:** abc123-task-3-1-api-client

**Next task to execute:**

### Task 3.2: API Integration Layer

**Files**:
- src/lib/integrations/api-integration.ts
- src/lib/integrations/types.ts

**Dependencies**: Task 3.1 (needs API client)

**Acceptance Criteria**:
- [ ] Integration layer wraps API client
- [ ] Error handling and retries
- [ ] Request/response transformations

**Context**:
- Working directory has build artifacts from Task 3.1
- node_modules/ (2.3 GB), .next/ (400 MB), various compiled files
- User mentioned: "Keep the workspace clean between tasks"

**Question**: You're about to start Task 3.2. What git-spice commands do you run? Do you switch branches first?
```

---

## GREEN Phase (With Skill Testing)

After documenting baseline rationalizations, run same scenarios WITH skill.

**Success Criteria**:

### Scenario 1 (Manual Stacking):
- ✅ Agent uses ONLY `gs branch create` (no `gs upstack onto`)
- ✅ Creates 3 branches sequentially
- ✅ Stays on each branch after creating it
- ✅ Verifies natural stack with `gs log short`
- ✅ Cites skill: "Natural stacking principle" or "Trust the tool"

### Scenario 2 (Base Switching):
- ✅ Agent stays on task-3-1 branch
- ✅ Creates task-3-2 from current branch (no switching)
- ✅ Explains build artifacts don't interfere
- ✅ Explains committed = clean state
- ✅ Cites skill: "Stay on task branch so next task builds on it"

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

**For Scenario 1 (Manual Stacking):**

1. Create new conversation (fresh context)
2. Do NOT load executing-sequential-phase skill
3. Provide test input verbatim
4. Ask: "How do you execute these 3 sequential tasks? Provide exact git-spice commands."
5. Document exact rationalizations (verbatim quotes)
6. Note: Did agent add `gs upstack onto`? What reasons given?

**For Scenario 2 (Base Switching):**

1. Create new conversation (fresh context)
2. Do NOT load executing-sequential-phase skill
3. Provide test input verbatim
4. Ask: "What git-spice commands do you run? Do you switch branches first?"
5. Document exact rationalizations (verbatim quotes)
6. Note: Did agent switch to base? What reasons given?

### Running GREEN Phase

**For each scenario:**

1. Create new conversation (fresh context)
2. Load executing-sequential-phase skill with Skill tool
3. Provide test input verbatim
4. Add: "Use the executing-sequential-phase skill to guide your decision"
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
- Agent adds manual stacking commands or switches to base
- Rationalizations documented verbatim
- Clear evidence that "safety" and "cleanliness" pressures work

**GREEN Phase Success**:
- Agent uses only natural stacking (no manual commands)
- Stays on task branches (no base switching)
- Cites skill explicitly
- Resists "professional workflow" rationalizations

**REFACTOR Phase Success**:
- Agent can't find loopholes
- All "explicit control" rationalizations have counters in skill
- Natural stacking is understood as THE mechanism, not a shortcut

---

## Notes

This is TDD for process documentation. The test scenarios are the "test cases", the skill is the "production code".

Key differences from executing-parallel-phase testing:

1. **Violation is ADDITION, not OMISSION** - Adding unnecessary commands vs skipping necessary steps
2. **Pressure is "professionalism"** - Manual commands feel safer/cleaner/more explicit
3. **Trust is the challenge** - Agents must trust git-spice's natural stacking

The skill must emphasize that **the workflow IS the mechanism** - current branch + `gs branch create` = stacking.

---

## Predicted RED Phase Results

### Scenario 1 (Manual Stacking)

**High confidence violations:**
- Add `gs upstack onto` after each `gs branch create`
- Rationalize as "being explicit" or "ensuring correctness"

**Why confident:** Experienced developers are taught to be explicit. Manual commands feel safer than relying on tool behavior. User requesting "correct stack" amplifies this.

### Scenario 2 (Base Switching)

**Medium confidence violations:**
- Switch to base branch before Task 3.2
- Rationalize as "clean workspace" or "professional practice"

**Why medium:** Some agents may understand git's "clean = committed" principle. But visible artifacts (node_modules, build files) create psychological pressure for "cleanup."

**If no violations occur:** Agents may already understand git-spice natural stacking. Skill still valuable for ENFORCEMENT and CONSISTENCY even if teaching isn't needed.

---

## Integration with testing-skills-with-subagents

To run these scenarios with subagent testing:

1. Create test fixture with scenario content
2. Spawn RED subagent WITHOUT skill loaded
3. Spawn GREEN subagent WITH skill loaded
4. Compare outputs and document rationalizations
5. Update skill based on findings
6. Repeat until GREEN phase passes reliably

This matches the pattern used for executing-parallel-phase testing.
