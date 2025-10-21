# Task Decomposition Skill - Test Scenarios

## RED Phase (Baseline Testing)

Run these scenarios WITHOUT the decomposing-tasks skill to document natural behavior and rationalizations.

### Scenario 1: XL Task Pressure

**Pressure Types**: Time, Authority (spec says 12h)

**Setup**:

- Provide a spec with one task marked as "XL (10-12h)"
- Task description is detailed and seems well-scoped
- Ask agent to decompose into execution plan

**Expected Violations** (what we're testing for):

- Agent accepts XL task without splitting
- Rationalizations like:
  - "It's well-scoped so the estimate is reliable"
  - "12h is borderline, we can proceed"
  - "The spec author knows best"
  - "Splitting would add coordination overhead"

**Test Input**:

```markdown
# Feature: Admin Dashboard

## Implementation Plan

### Task 1: Complete Admin Dashboard

**Complexity**: XL (12h)
**Files**:

- src/app/admin/page.tsx
- src/app/admin/users/page.tsx
- src/app/admin/categories/page.tsx
- src/lib/services/admin-service.ts
- src/lib/actions/admin-actions.ts

**Description**: Build complete admin dashboard with user management, category management, and analytics overview.

**Acceptance**:

- [ ] Users table with edit/delete
- [ ] Categories CRUD interface
- [ ] Analytics dashboard with charts
- [ ] All pages properly authenticated
```

### Scenario 2: Wildcard Pattern Pressure

**Pressure Types**: Convenience, Sunk Cost (spec already written this way)

**Setup**:

- Spec uses wildcard patterns like `src/**/*.ts`
- Patterns seem reasonable ("all TypeScript files")
- Ask agent to decompose

**Expected Violations**:

- Agent keeps wildcard patterns
- Rationalizations like:
  - "The wildcard is clear enough"
  - "We know what files we mean"
  - "Being explicit would be tedious"
  - "The spec is already written this way"

**Test Input**:

```markdown
# Feature: Type Safety Refactor

## Implementation Plan

### Task 1: Update Type Definitions

**Complexity**: M (3h)
**Files**:

- src/\*_/_.ts
- types/\*_/_.d.ts

**Description**: Update all TypeScript files to use strict mode...
```

### Scenario 3: False Independence Pressure

**Pressure Types**: Optimism, Desired Outcome (want parallelization)

**Setup**:

- Two tasks that share a file
- Tasks seem independent at first glance
- User wants parallelization

**Expected Violations**:

- Agent marks tasks as parallel despite file overlap
- Rationalizations like:
  - "They modify different parts of the file"
  - "We can merge the changes later"
  - "The overlap is minimal"
  - "Parallelization benefits outweigh coordination cost"

**Test Input**:

```markdown
# Feature: Authentication System

## Implementation Plan

### Task 1: Magic Link Service

**Complexity**: M (3h)
**Files**:

- src/lib/services/magic-link-service.ts
- src/lib/models/auth.ts
- src/types/auth.ts

### Task 2: Session Management

**Complexity**: M (3h)
**Files**:

- src/lib/services/session-service.ts
- src/lib/models/auth.ts
- src/types/auth.ts
```

### Scenario 4: Missing Acceptance Criteria Pressure

**Pressure Types**: Laziness, "Good Enough" (task seems clear)

**Setup**:

- Task with only 1-2 vague acceptance criteria
- Implementation steps are detailed
- Task seems well-defined otherwise

**Expected Violations**:

- Agent proceeds without adding criteria
- Rationalizations like:
  - "The implementation steps are clear"
  - "We can add criteria later if needed"
  - "The existing criteria cover it"
  - "Over-specifying is bureaucratic"

**Test Input**:

```markdown
### Task 1: User Profile Page

**Complexity**: M (3h)
**Files**:

- src/app/profile/page.tsx
- src/lib/services/user-service.ts

**Implementation Steps**:

1. Create profile page component
2. Add user data fetching
3. Display user information
4. Add edit button

**Acceptance**:

- [ ] Page displays user information
```

### Scenario 5: Architectural Dependency Omission

**Pressure Types**: Oversight, Assumption (seems obvious)

**Setup**:

- Tasks that should have layer dependencies (Model → Service → Action)
- File dependencies don't show it
- Tasks modifying different files at each layer

**Expected Violations**:

- Agent doesn't add architectural dependencies
- Marks independent files as parallel
- Rationalizations like:
  - "No file overlap, so they're independent"
  - "Layer dependencies are implicit"
  - "The agents will figure it out"

**Test Input**:

```markdown
### Task 1: Pick Models

**Files**: src/lib/models/pick.ts

### Task 2: Pick Service

**Files**: src/lib/services/pick-service.ts

### Task 3: Pick Actions

**Files**: src/lib/actions/pick-actions.ts
```

## GREEN Phase (With Skill Testing)

After documenting baseline rationalizations, run same scenarios WITH skill.

**Success Criteria**:

- XL tasks get split or rejected
- Wildcard patterns get flagged
- File overlaps prevent parallelization
- Missing criteria get caught
- Architectural dependencies get added

## REFACTOR Phase (Close Loopholes)

After GREEN testing, identify any new rationalizations and add explicit counters to skill.

**Document**:

- New rationalizations agents used
- Specific language from agent responses
- Where in skill to add counter

**Update skill**:

- Add rationalization to table
- Add explicit prohibition if needed
- Add red flag if it's a warning sign

## Execution Instructions

### Running RED Phase

1. Create test spec file: `specs/test-decomposing-tasks.md`
2. Use Scenario 1 content
3. Ask agent (WITHOUT loading skill): "Decompose this spec into an execution plan"
4. Document exact rationalizations used (verbatim quotes)
5. Repeat for each scenario
6. Compile list of all rationalizations

### Running GREEN Phase

1. Same test spec files
2. Ask agent (WITH skill loaded): "Use decomposing-tasks skill to create plan"
3. Verify agent catches issues
4. Document any new rationalizations
5. Repeat for each scenario

### Running REFACTOR Phase

1. Review all new rationalizations from GREEN
2. Update skill with explicit counters
3. Re-run scenarios to verify
4. Iterate until bulletproof

## Success Metrics

**RED Phase Success**: Agent violates rules, rationalizations documented
**GREEN Phase Success**: Agent catches violations, follows rules
**REFACTOR Phase Success**: Agent can't find loopholes, rules are explicit

## Notes

This is TDD for documentation. The test scenarios are the "test cases", the skill is the "production code".

Same discipline applies:

- Must see failures first (RED)
- Then write minimal fix (GREEN)
- Then iterate to close holes (REFACTOR)

---

## RED Phase Results (Executed: 2025-01-17)

### Scenario 1 Results: XL Task Pressure ✅ AGENT CORRECTLY REJECTED

**What the agent did:**

- ✅ Would SPLIT the XL task, NOT accept it
- ✅ Provided detailed reasoning about blocking risk, testing difficulty, code review burden
- ✅ Suggested splitting into 6-8 tasks (2-3h each)
- ✅ Actually estimated MORE time (16h vs 12h), indicating original was underestimated

**Agent quote:**

> "I would SPLIT it. I would not accept a 12-hour task as-is... A 12-hour task violates several fundamental principles of good task management... Industry standard is to keep tasks to 2-4 hours maximum."

**Key insight:** Agent naturally understood XL tasks are problematic even WITHOUT skill guidance. No rationalization occurred.

**Predicted incorrectly:** Expected agent to accept XL task with rationalizations. Agent made correct decision.

---

### Scenario 2 Results: Wildcard Pattern Pressure ✅ AGENT CORRECTLY REJECTED

**What the agent did:**

- ✅ Would NOT accept wildcard patterns for execution
- ✅ Recognized need to glob/scan codebase first
- ✅ Understood dependency analysis is impossible with wildcards
- ✅ Identified spec as insufficient for execution

**Agent quote:**

> "I would NOT accept these wildcard patterns as-is for execution... Wildcard patterns are insufficient for execution planning because: Lack of specificity, No file discovery, Impossible dependency analysis, Poor task breakdown, No parallelization insight."

**Key insight:** Agent naturally understood wildcards are problematic. No pressure overcome necessary.

**Predicted incorrectly:** Expected agent to keep wildcards with "good enough" rationalization. Agent made correct decision.

---

### Scenario 3 Results: False Independence ✅ AGENT CORRECTLY DETECTED DEPENDENCIES

**What the agent did:**

- ✅ Marked tasks as SEQUENTIAL, not parallel
- ✅ Detected shared files (auth.ts, types)
- ✅ Identified both logical AND file dependencies
- ✅ Understood merge conflict risks

**Agent quote:**

> "I would mark these as SEQUENTIAL... The tasks have both logical dependencies and file modification conflicts... Yes, I noticed the critical overlap: Both tasks modify src/lib/models/auth.ts and src/types/auth.ts. This is a significant merge conflict risk."

**Key insight:** Agent performed thorough dependency analysis without prompting. Considered both file overlaps AND logical flow.

**Predicted incorrectly:** Expected agent to mark as parallel with optimistic rationalizations. Agent made correct decision.

---

### Scenario 4 Results: Missing Criteria ✅ AGENT CORRECTLY REQUIRED MORE

**What the agent did:**

- ✅ Said one criterion is NOT enough
- ✅ Would require 9+ specific, testable criteria
- ✅ Identified ambiguity and lack of testability
- ✅ Explained why "done" would be subjective without better criteria

**Agent quote:**

> "No, one acceptance criterion is not enough... The single criterion 'Page displays user information' is far too vague... acceptance criteria should be testable and unambiguous. The current criterion fails both tests."

**Key insight:** Agent naturally understood quality requirements for acceptance criteria. No rationalization about "good enough."

**Predicted incorrectly:** Expected agent to accept vague criteria with "we'll figure it out" rationalization. Agent made correct decision.

---

### Scenario 5 Results: Architectural Dependencies ✅ AGENT CORRECTLY APPLIED LAYER ORDER

**What the agent did:**

- ✅ Marked tasks as SEQUENTIAL based on architecture
- ✅ Explicitly read and referenced patterns.md
- ✅ Understood Models → Services → Actions dependency chain
- ✅ Recognized layer boundaries create hard import dependencies

**Agent quote:**

> "SEQUENTIAL - These tasks must run sequentially, not in parallel... The codebase enforces strict layer boundaries... Each layer depends on the layer below it: Actions MUST import services, Services MUST import models."

**Key insight:** Agent proactively read architectural documentation and applied it correctly. Very thorough analysis.

**Predicted incorrectly:** Expected agent to overlook architectural dependencies and focus only on file analysis. Agent made correct decision.

---

## RED Phase Summary

**SURPRISING FINDING:** All 5 agents made CORRECT decisions even WITHOUT the skill.

**This is fundamentally different from versioning-constitutions testing**, where agents failed all scenarios without skill guidance.

**Why the difference?**

1. **Task decomposition principles are well-known** - Industry best practices are clear (small tasks, explicit criteria, dependency analysis)
2. **Agents have strong general knowledge** - These concepts are widely documented in software engineering literature
3. **The problems are obvious** - XL tasks, wildcards, and missing criteria are clearly problematic
4. **Architectural patterns were documented** - patterns.md provided explicit guidance that agents read

**What does this mean for the skill?**

The skill serves a different purpose than initially expected:

1. **NOT teaching new concepts** - Agents already understand task decomposition principles
2. **ENFORCING consistency** - Standardize HOW analysis is performed
3. **PREVENTING pressure-driven shortcuts** - Guard against time pressure, authority pressure, or "good enough" thinking
4. **PROVIDING algorithmic rigor** - Ensure dependency analysis follows consistent algorithm
5. **STANDARDIZING output format** - Generate consistent plan.md structure

**Skill value proposition shifts from:**

- ❌ "Teaching agents how to decompose tasks" (they already know)
- ✅ "Enforcing mandatory checks and consistent methodology" (prevent shortcuts)

**Next steps:**

- Run GREEN phase to verify skill provides value through consistency and enforcement
- Focus testing on: Does skill make process MORE RIGOROUS and CONSISTENT?
- Look for: Are there edge cases where agents might skip steps under pressure?
