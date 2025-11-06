# Test Scenario: Spec Injection into Subagent Context

## Context

Testing that subagents receive **complete context** from both spec and constitution, preventing architectural drift during implementation.

**Setup:**
- Feature plan at `specs/{runId}-{feature-slug}/plan.md`
- Feature spec at `specs/{runId}-{feature-slug}/spec.md`
- Constitution at `docs/constitutions/current/`
- Tasks ready for execution (sequential or parallel)

**Why critical:**
- **Constitution = HOW** (patterns, tech stack, code style)
- **Spec = WHAT + WHY** (requirements, architecture, user flows)
- **Task = WHERE** (specific files, acceptance criteria)
- Without spec, subagents make architectural decisions blindly
- Spec drift accumulates across phases → higher review failure rate
- This is **SPEC-ANCHORED DEVELOPMENT** - the spec is the source of truth

**Real failure mode:**

```
Plan says: Implement join route at /join/[gameId]?code=X
Subagent implements: /join/[code]/

Why? Subagent didn't read spec explaining:
- gameId needed for analytics tracking
- Query param pattern matches existing routes
- URL structure supports future multi-code invites

Result: Code review catches drift → rework → wasted time
```

## Expected Behavior

### Sequential Phase Subagent Dispatch

**When orchestrator dispatches subagent for task in sequential phase:**

```markdown
ROLE: Implement Task {task-id} in main worktree (sequential phase)

WORKTREE: .worktrees/{run-id}-main
CURRENT BRANCH: {current-branch}

TASK: {task-name}
FILES: {files-list}
ACCEPTANCE CRITERIA: {criteria}

INSTRUCTIONS:

1. Navigate to main worktree:
   cd .worktrees/{run-id}-main

2. Read constitution (if exists):
   docs/constitutions/current/

3. Read feature specification:
   specs/{run-id}-{feature-slug}/spec.md

   This provides:
   - WHAT to build (requirements, user flows)
   - WHY decisions were made (architecture rationale)
   - HOW features integrate (system boundaries)

4. Implement task following spec + constitution

5. Run quality checks...

6. Create branch...
```

**Critical elements:**
- ✅ Step 3 explicitly instructs reading spec
- ✅ Spec path uses run-id and feature-slug from plan
- ✅ Spec reading happens BEFORE implementation (step 4)
- ✅ Spec reading happens AFTER constitution (provides context)
- ✅ Explains WHAT spec provides (not just "read it")

### Parallel Phase Subagent Dispatch

**When orchestrator dispatches subagent for task in parallel phase:**

```markdown
ROLE: Implement Task {task-id} in ISOLATED worktree

WORKTREE: .worktrees/{run-id}-task-{task-id}

TASK: {task-name}
FILES: {files-list}
ACCEPTANCE CRITERIA: {criteria}

CRITICAL:
1. Verify isolation (pwd must show task worktree)

2. Read constitution (if exists):
   docs/constitutions/current/

3. Read feature specification:
   specs/{run-id}-{feature-slug}/spec.md

   This provides:
   - WHAT to build (requirements, user flows)
   - WHY decisions were made (architecture rationale)
   - HOW features integrate (system boundaries)

4. Implement task following spec + constitution

5. Run quality checks...

6. Create branch...

7. Detach HEAD...
```

**Same critical elements as sequential, plus:**
- ✅ Spec reading in isolated worktree (not main repo)
- ✅ Spec provides shared context across parallel tasks

### Fix Subagent Dispatch (Both Sequential and Parallel)

**When orchestrator dispatches fix subagent after code review rejection:**

```markdown
Task(Fix Phase {N} code review issues)
Prompt: Fix the following issues found in Phase {N} code review:

{List all issues from review output with severity and file locations}

CONTEXT FOR FIXES:

1. Read constitution (if exists):
   docs/constitutions/current/

2. Read feature specification:
   specs/{run-id}-{feature-slug}/spec.md

   The spec provides architectural context for fixes:
   - WHY decisions were made (rationale for current implementation)
   - HOW features should integrate (system boundaries)
   - WHAT requirements must be met (acceptance criteria)

3. Apply fixes following spec + constitution patterns

CRITICAL: Work in .worktrees/{runid}-main
CRITICAL: Amend existing branch or add new commit
CRITICAL: Run all quality checks before completion
CRITICAL: Verify all issues resolved before reporting completion
```

**Critical elements:**
- ✅ Step 1 explicitly instructs reading constitution
- ✅ Step 2 explicitly instructs reading spec
- ✅ Spec path uses run-id and feature-slug from plan
- ✅ Explains WHY spec is needed for fixes (architectural context)
- ✅ Spec reading happens BEFORE applying fixes (step 3)
- ✅ Same anchoring pattern as regular task subagents

**Why fix subagents need spec anchoring:**
- Fix subagents modify existing code, need same architectural context as original implementation
- Without spec: Fixes may violate architectural decisions or integration requirements
- Without constitution: Fixes may use patterns inconsistent with codebase standards
- Real example: Review says "missing validation" → Without spec, subagent adds generic validation → Spec actually requires multi-tenant validation with specific business rules

## Anti-Patterns to Detect

### Anti-Pattern 1: Missing Spec Instruction

**WRONG:**
```markdown
INSTRUCTIONS:

1. Navigate to worktree
2. Read constitution: docs/constitutions/current/
3. Implement task                              ← SKIPS SPEC
4. Run quality checks
```

**Symptom:** Subagents make architectural decisions without context

**Result:**
- Route structures differ from spec
- Component hierarchy doesn't match design
- API contracts deviate from requirements
- Code review catches drift → rework

### Anti-Pattern 2: Spec After Implementation

**WRONG:**
```markdown
INSTRUCTIONS:

1. Navigate to worktree
2. Read constitution
3. Implement task                              ← IMPLEMENTS FIRST
4. Read spec to verify                         ← TOO LATE
5. Run quality checks
```

**Why wrong:** Spec should inform implementation, not validate it

### Anti-Pattern 3: Vague Spec Reference

**WRONG:**
```markdown
INSTRUCTIONS:

1. Navigate to worktree
2. Review project documentation               ← TOO VAGUE
3. Implement task
```

**Why wrong:**
- Doesn't specify exact spec path
- Subagent might not find it
- No explanation of what spec provides

### Anti-Pattern 4: Plan-Only Context

**WRONG:**
```markdown
TASK: {task-name}
FILES: {files-list}
ACCEPTANCE CRITERIA: {criteria}

INSTRUCTIONS:
1. Implement based on acceptance criteria    ← ONLY HAS PLAN CONTEXT
```

**Why wrong:**
- Acceptance criteria = VERIFICATION (tests pass, files created)
- Spec = REQUIREMENTS (user flow, architecture, business logic)
- Plan tasks are chunked from spec, missing full context

**Example drift:**

```
Plan task: "Implement join route with access code validation"

Acceptance criteria:
- Route accepts access code parameter
- Validates code against database
- Redirects to game on success

Without spec, subagent might implement:
- /join?code=X (query param)

Spec actually requires:
- /join/[gameId]?code=X (gameId + code for analytics)
```

### Anti-Pattern 5: Constitution-Only Context

**WRONG:**
```markdown
INSTRUCTIONS:
1. Read constitution
2. Implement task following constitution patterns
```

**Why wrong:**
- Constitution = HOW to build (patterns, tech, style)
- Spec = WHAT to build (requirements, features)
- Both needed for anchored implementation

**Example drift:**

```
Constitution says: "Use server actions for mutations"

Task: "Implement join game mutation"

Without spec:
- Subagent implements server action (correct pattern)
- But doesn't know it should update lastAccessedAt
- Or that it should create analytics event
- Or that it needs optimistic UI update

Spec contains these requirements.
```

### Anti-Pattern 6: Fix Subagents Without Spec Anchoring

**WRONG:**
```markdown
Task(Fix Phase {N} code review issues)
Prompt: Fix the following issues found in Phase {N} code review:

{List all issues}

CRITICAL: Work in .worktrees/{runid}-main
CRITICAL: Amend existing branch
CRITICAL: Run quality checks
```

**Why wrong:**
- Fix subagents modify existing code without architectural context
- No understanding of WHY original decisions were made
- No understanding of HOW features should integrate
- Fixes may introduce new architectural drift

**Example drift:**

```
Code review says: "Missing validation on accessCode field"

Without spec, fix subagent adds:
- Basic string validation (min 6 chars, alphanumeric)

Spec actually requires:
- Case-insensitive validation
- Prevent SQL injection patterns
- Allow hyphens for readability
- Must match format from game creation flow

Result: Fix passes code review but breaks integration
```

**Real-world impact:**
- Fix loop creates new issues while fixing old ones
- Multiple review iterations required
- Architectural drift accumulates
- "Whack-a-mole" debugging pattern

## Success Criteria

### Sequential Phase Skill
- [ ] `executing-sequential-phase/SKILL.md` includes spec reading instruction
- [ ] Spec path format: `specs/{run-id}-{feature-slug}/spec.md`
- [ ] Spec reading happens before implementation step
- [ ] Spec reading happens after constitution step
- [ ] Explains what spec provides (requirements, architecture, rationale)

### Parallel Phase Skill
- [ ] `executing-parallel-phase/SKILL.md` includes spec reading instruction
- [ ] Spec path format: `specs/{run-id}-{feature-slug}/spec.md`
- [ ] Spec reading happens before implementation step
- [ ] Spec reading happens after constitution step
- [ ] Explains what spec provides (requirements, architecture, rationale)

### Fix Subagents (Both Sequential and Parallel)
- [ ] `executing-sequential-phase/SKILL.md` includes spec reading in fix subagent prompt
- [ ] `executing-parallel-phase/SKILL.md` includes spec reading in fix subagent prompt
- [ ] Spec path format: `specs/{run-id}-{feature-slug}/spec.md`
- [ ] Constitution reading included: `docs/constitutions/current/`
- [ ] Spec reading happens before applying fixes
- [ ] Explains what spec provides for fixing context
- [ ] Same anchoring pattern as regular task subagents

### All Subagent Types
- [ ] Spec reading is MANDATORY (not optional or conditional)
- [ ] Clear explanation of spec vs constitution vs plan context
- [ ] No vague "read project docs" language
- [ ] Consistent pattern across all subagent types (task + fix)

## Implementation Verification

**Check:** `skills/executing-sequential-phase/SKILL.md` at "Step 2: Spawn Sequential Subagents"

Should contain subagent prompt with:
```markdown
2. Read constitution (if exists): docs/constitutions/current/

3. Read feature specification:
   specs/{run-id}-{feature-slug}/spec.md

   This provides:
   - WHAT to build (requirements, user flows)
   - WHY decisions were made (architecture rationale)
   - HOW features integrate (system boundaries)

4. Implement task following spec + constitution
```

**Check:** `skills/executing-parallel-phase/SKILL.md` at "Step 4: Spawn Parallel Subagents"

Should contain identical spec reading instruction in subagent prompt.

**Check:** `skills/executing-sequential-phase/SKILL.md` at "Step 4: Code Review" (fix subagent)

Should contain fix subagent prompt with:
```markdown
CONTEXT FOR FIXES:

1. Read constitution (if exists): docs/constitutions/current/

2. Read feature specification: specs/{run-id}-{feature-slug}/spec.md

   The spec provides architectural context for fixes:
   - WHY decisions were made (rationale for current implementation)
   - HOW features should integrate (system boundaries)
   - WHAT requirements must be met (acceptance criteria)

3. Apply fixes following spec + constitution patterns
```

**Check:** `skills/executing-parallel-phase/SKILL.md` at "Step 8: Code Review" (fix subagent)

Should contain identical fix subagent prompt with spec anchoring.

## Testing Method

**Verification approach for regular task subagents:**

1. Read `executing-sequential-phase/SKILL.md` subagent dispatch section
2. Search for "spec" or "specification" in subagent prompt
3. Verify explicit instruction to read `specs/{run-id}-{feature-slug}/spec.md`
4. Verify instruction comes before implementation step
5. Repeat for `executing-parallel-phase/SKILL.md`

**Verification approach for fix subagents:**

1. Read `executing-sequential-phase/SKILL.md` code review section
2. Search for "Task(Fix Phase" in fix subagent prompt
3. Verify "CONTEXT FOR FIXES" section exists
4. Verify explicit instruction to read constitution and spec
5. Verify spec reading comes before "Apply fixes" step
6. Repeat for `executing-parallel-phase/SKILL.md`

**Evidence of PASS:**
- Both skills contain explicit spec reading instruction
- Spec path uses correct format with variables
- Explanation of what spec provides
- Ordering: constitution → spec → implementation

**Evidence of FAIL:**
- No mention of spec in subagent prompt
- Vague "read docs" without explicit path
- Spec reading after implementation
- Spec reading is optional/conditional

## Real-World Impact

**Without spec injection:**

```
Phase 1: Foundation
Task: Create database schema
Subagent: Implements basic schema from acceptance criteria
Review: Missing audit columns spec requires → rework

Phase 2: API Layer
Task: Create API endpoints
Subagent: Uses standard REST patterns
Review: Spec requires GraphQL subscriptions → rework

Phase 3: Service Layer
Task: Implement business logic
Subagent: Adds basic validation
Review: Spec requires complex multi-tenant rules → rework

Review failure rate: 3/3 phases (100%)
Root cause: No spec context
```

**With spec injection:**

```
Phase 1: Foundation
Task: Create database schema
Subagent: Reads spec → sees audit column requirements → implements correctly
Review: APPROVED

Phase 2: API Layer
Task: Create API endpoints
Subagent: Reads spec → sees GraphQL requirement → implements correctly
Review: APPROVED

Phase 3: Service Layer
Task: Implement business logic
Subagent: Reads spec → sees multi-tenant rules → implements correctly
Review: APPROVED

Review failure rate: 0/3 phases (0%)
Root cause: Full context from spec
```

## References

**Project philosophy (from CLAUDE.md):**

> **Spec anchoring**: Every line of code traces back to spec + constitution

**This test ensures that philosophy is enforced in execution workflow.**

## Red Flags

If you see ANY of these in subagent output, spec injection failed:

- "I'm implementing based on the task description"
- "Following the acceptance criteria from the plan"
- "This seems like the right approach"
- Architectural decisions made without spec justification
- Questions about requirements that spec would answer
- Code review finding drift from spec requirements

All indicate subagent didn't read or follow spec.
