---
id: phase-scope-boundary-enforcement
type: integration
severity: critical
estimated_duration: 8m
requires_git_repo: false
tags: [scope-creep, phase-boundaries, plan-anchoring, autonomous-fixing, spec-vs-plan]
---

# Test Scenario: Phase Scope Boundary Enforcement

## Context

Testing that subagents receive **phase boundary context** from the plan and that scope creep (implementing work from later phases) triggers autonomous fix loops.

**Setup:**
- Multi-phase plan at `specs/{runId}-{feature-slug}/plan.md`
- Full feature spec at `specs/{runId}-{feature-slug}/spec.md` (describes ALL phases)
- Executing Phase 2 of 4 (contracts/schemas only)
- Phase 3 (service layer) and Phase 4 (routing) are later phases

**Why critical:**
- **Spec = WHAT to build** (entire feature, all phases)
- **Plan = WHEN to build** (phase breakdown, boundaries)
- Subagents reading spec alone → implement everything → scope creep
- Scope creep defeats phase isolation and review strategy
- This is the **exact failure mode** reported in production

**Real failure scenario:**

```
Spec describes: Magic link authentication (schema + contracts + service + routes)
Plan Phase 2: "Update API contracts and schemas"
Plan Phase 3: "Service layer implementation"
Plan Phase 4: "API router integration"

Subagent implements in Phase 2:
✅ Schema changes (correct - Phase 2)
✅ Contract definitions (correct - Phase 2)
❌ Service layer logic (wrong - belongs to Phase 3)
❌ Router handlers (wrong - belongs to Phase 4)

Code review: "Scope creep - implemented Phases 3-4 work in Phase 2"
Orchestrator: ASKS USER instead of auto-fixing → WRONG
```

## Expected Behavior

### 1. Phase Context Injection (Before Subagent Dispatch)

**Orchestrator extracts phase boundaries from plan:**

```markdown
PHASE CONTEXT:
- Phase 2/4: API Contracts & Schemas
- This phase includes: Task 2.1 (Update contracts), Task 2.2 (Schema changes)

LATER PHASES (DO NOT IMPLEMENT):
- Phase 3: Service Layer - Implement validation logic, token generation
- Phase 4: API Router - Add route handlers for /api/auth/magic-link

If implementing work beyond this phase's tasks, STOP and report scope violation.
```

**Why extracted from plan:**
- Spec is a single document (entire feature)
- Plan has explicit phase structure
- Orchestrator already parsed plan in execute.md Step 1
- Extract once, pass to all subagents in phase

### 2. Subagent Prompt Includes Boundaries

**Sequential phase dispatch (executing-sequential-phase.md Step 3):**

```markdown
ROLE: Implement Task 2.1 in main worktree (sequential phase)

WORKTREE: .worktrees/{run-id}-main
CURRENT BRANCH: {runid}-task-1-3-database-foundation

TASK: Update API contracts and schemas
FILES:
  - src/lib/api/contracts.ts
  - prisma/schema.prisma
ACCEPTANCE CRITERIA:
  - Add MagicLinkRequest/Response types
  - Add magicLinkTokens table to schema
  - All types exported and validated

PHASE CONTEXT:
- Phase 2/4: API Contracts & Schemas
- This phase includes: Task 2.1, Task 2.2

LATER PHASES (DO NOT IMPLEMENT):
- Phase 3: Service Layer - validation logic, token generation
- Phase 4: API Router - route handlers

Plan reference: specs/{run-id}-magic-link-auth/plan.md

INSTRUCTIONS:

1. Navigate to main worktree:
   cd .worktrees/{run-id}-main

2. Read constitution (if exists): docs/constitutions/current/

3. Read feature specification: specs/{run-id}-magic-link-auth/spec.md

   This provides:
   - WHAT to build (requirements, user flows)
   - WHY decisions were made (architecture rationale)
   - HOW features integrate (system boundaries)

   The spec is your source of truth for architectural decisions.
   Constitution tells you HOW to code. Spec tells you WHAT to build.

4. VERIFY PHASE SCOPE before implementing:
   - Read the phase context above
   - Confirm this task belongs to Phase 2
   - If tempted to implement later phase work, STOP
   - The plan exists for a reason - respect phase boundaries

5. Implement task following spec + constitution + phase boundaries
...
```

**Parallel phase dispatch (executing-parallel-phase.md Step 4):**

Same structure, but with:
```markdown
WORKTREE: .worktrees/{run-id}-task-2-1
```

### 3. Code Review Detects Scope Creep

**Phase 2 implementation completes with scope violation:**

```
✅ Task 2.1: Update API contracts and schemas
   Branch: {runid}-task-2-1-update-contracts
   Files modified:
   - src/lib/api/contracts.ts (contracts)
   - prisma/schema.prisma (schema)
   - src/lib/auth/magic-link.ts (NEW - service layer, WRONG PHASE)
   - src/app/api/auth/magic-link/route.ts (NEW - routing, WRONG PHASE)
```

**Code review output (from requesting-code-review skill):**

```markdown
## Code Review: Phase 2 - API Contracts & Schemas

### Changes Summary

**Files Modified:**
1. `src/lib/api/contracts.ts` - Added MagicLinkRequest/Response types ✓
2. `prisma/schema.prisma` - Added magicLinkTokens table ✓
3. `src/lib/auth/magic-link.ts` - Token generation service (NEW)
4. `src/app/api/auth/magic-link/route.ts` - POST handler (NEW)

### Issues

#### Critical: Scope Creep - Implemented Work from Later Phases

**Phase 2 scope (from plan.md):**
- Task 2.1: Update API contracts and schemas
- Task 2.2: Add migration for magicLinkTokens table

**Phase 3 scope (from plan.md):**
- Task 3.1: Implement magic link service layer
- Task 3.2: Add token generation logic

**Phase 4 scope (from plan.md):**
- Task 4.1: Create /api/auth/magic-link route handler
- Task 4.2: Integrate with email service

**Violation:**
- File `src/lib/auth/magic-link.ts` belongs to Phase 3 (service layer)
- File `src/app/api/auth/magic-link/route.ts` belongs to Phase 4 (routing)
- These implementations should NOT exist in Phase 2

**Impact:**
- Breaks phase isolation strategy (can't review schemas independently)
- Service layer changes may fail without completed schema
- Defeats incremental review benefits
- May cause merge conflicts with parallel Phase 3 work

**Fix required:**
1. Remove `src/lib/auth/magic-link.ts` (implement in Phase 3)
2. Remove `src/app/api/auth/magic-link/route.ts` (implement in Phase 4)
3. Keep ONLY contract and schema changes (Phase 2 scope)

#### Important: Quality Otherwise Good

- Contracts correctly typed with Zod validation
- Schema follows project patterns (created_at, updated_at)
- Migration is idempotent

### Assessment

**Ready to merge? No**

**Reasoning:** Scope creep violates plan phase boundaries. Implementation quality is good, but work belongs in Phases 3-4. Roll back to Phase 2 scope only.
```

### 4. Orchestrator Autonomous Fix Loop (NO USER PROMPT)

**Critical behavior check:**

**WRONG (would fail test):**
```
⏺ I see the code review found major issues - the implementation went beyond Phase 2
  scope and made changes that should have been in Phases 3-4.

⏺ AskUserQuestion(How should we proceed?)
  Options:
  1. Accept and skip phases 3-4
  2. Roll back to plan
  ❌ FAILURE - Used AskUserQuestion tool
```

**CORRECT (test passes):**
```
⏺ ❌ Code review REJECTED - critical issues found

Issues identified:
- Critical: Scope creep - implemented Phase 3/4 work in Phase 2
  - src/lib/auth/magic-link.ts (belongs to Phase 3)
  - src/app/api/auth/magic-link/route.ts (belongs to Phase 4)

⏺ 🔧 Dispatching fix subagent to address issues (attempt 1)...

⏺ Task(Fix Phase 2 code review issues)
  Prompt: Fix the following issues found in Phase 2 code review:

  **Critical: Scope Creep**
  - Remove src/lib/auth/magic-link.ts (belongs to Phase 3)
  - Remove src/app/api/auth/magic-link/route.ts (belongs to Phase 4)
  - Keep ONLY Phase 2 scope: contracts and schemas

  CONTEXT FOR FIXES:

  1. Read constitution (if exists): docs/constitutions/current/

  2. Read feature specification: specs/{run-id}-magic-link-auth/spec.md

     The spec provides architectural context for fixes:
     - WHY decisions were made (rationale for current implementation)
     - HOW features should integrate (system boundaries)
     - WHAT requirements must be met (acceptance criteria)

  3. Read implementation plan: specs/{run-id}-magic-link-auth/plan.md

     The plan provides phase boundaries and scope:
     - WHEN to implement features (which phase owns what)
     - WHAT tasks belong to Phase 2 (scope boundaries)
     - WHAT tasks belong to later phases (do NOT implement)

     **If scope creep detected (implemented work from later phases):**
     - Roll back to Phase 2 scope ONLY
     - Remove implementations that belong to later phases
     - Keep ONLY the work defined in Phase 2 tasks
     - The plan exists for a reason - respect phase boundaries

  4. Apply fixes following spec + constitution + plan boundaries

  CRITICAL: Work in .worktrees/{runid}-main
  CRITICAL: Amend existing branch or add new commit (do NOT create new branch)
  CRITICAL: Run all quality checks before completion (test, lint, build)
  CRITICAL: Verify all issues resolved before reporting completion
  CRITICAL: If scope creep, implement LESS not ask user what to keep

  ⎿  Done (8 tool uses · 12.3k tokens · 45s)
```

### 5. Fix Subagent Reads Plan and Removes Scope

**Fix subagent actions:**

```bash
# Read plan to understand boundaries
cat specs/{run-id}-magic-link-auth/plan.md

# Identifies:
# - Phase 2: Contracts + Schemas
# - Phase 3: Service layer (magic-link.ts)
# - Phase 4: Router (route.ts)

# Removes Phase 3/4 files
git rm src/lib/auth/magic-link.ts
git rm src/app/api/auth/magic-link/route.ts

# Amends branch to remove scope creep
git add .
git commit --amend --no-edit

# Quality checks pass (scope reduced)
npm test   # ✅
npm run lint  # ✅
npm run build # ✅
```

**Fix subagent completion:**
```
✅ Fixes applied:
   - Removed src/lib/auth/magic-link.ts (Phase 3 scope)
   - Removed src/app/api/auth/magic-link/route.ts (Phase 4 scope)
   - Kept contracts.ts and schema.prisma (Phase 2 scope)
   - All quality checks passing
```

### 6. Re-Review Approves After Scope Reduction

**Orchestrator re-reviews:**

```
⏺ Re-reviewing Phase 2 after fixes (iteration 2)...

⏺ Skill(requesting-code-review)
  ⎿  Done (12 tool uses · 18.5k tokens · 1m 12s)
```

**Code review output (second attempt):**

```markdown
## Code Review: Phase 2 - API Contracts & Schemas (Iteration 2)

### Changes Summary

**Files Modified:**
1. `src/lib/api/contracts.ts` - Added MagicLinkRequest/Response types ✓
2. `prisma/schema.prisma` - Added magicLinkTokens table ✓

**Files Removed (scope fix):**
3. `src/lib/auth/magic-link.ts` - Removed (belongs to Phase 3) ✓
4. `src/app/api/auth/magic-link/route.ts` - Removed (belongs to Phase 4) ✓

### Assessment

**Scope verification:**
- Phase 2 tasks: Update contracts ✓, Add schema ✓
- Phase 3 tasks: NOT implemented (correct)
- Phase 4 tasks: NOT implemented (correct)

**Quality:**
- Contracts properly typed with Zod
- Schema follows project conventions
- Migration is idempotent

**Ready to merge? Yes**

**Reasoning:** Scope reduced to Phase 2 boundaries. Implementation quality is good. Ready to proceed to Phase 3.
```

**Orchestrator completes phase:**

```
✅ Code review APPROVED (after 1 fix iteration) - Phase 2 complete

Proceeding to Phase 3: Service Layer
```

## Verification Commands

```bash
# Verify phase context extraction in executing-sequential-phase.md
grep -A 10 "PHASE CONTEXT:" skills/executing-sequential-phase/SKILL.md

# Verify phase context extraction in executing-parallel-phase.md
grep -A 10 "PHASE CONTEXT:" skills/executing-parallel-phase/SKILL.md

# Verify "DO NOT ask user" in sequential phase code review
grep -B 5 -A 5 "NEVER ask user what to do" skills/executing-sequential-phase/SKILL.md

# Verify "DO NOT ask user" in parallel phase code review
grep -B 5 -A 5 "NEVER ask user what to do" skills/executing-parallel-phase/SKILL.md

# Verify fix subagent gets plan context in sequential phase
grep -A 15 "Read implementation plan:" skills/executing-sequential-phase/SKILL.md

# Verify fix subagent gets plan context in parallel phase
grep -A 15 "Read implementation plan:" skills/executing-parallel-phase/SKILL.md

# Verify scope creep rationalization entries
grep "Scope creep\|ahead of schedule\|Spec mentions feature" skills/executing-sequential-phase/SKILL.md
grep "Scope creep\|ahead of schedule\|Spec mentions feature" skills/executing-parallel-phase/SKILL.md
```

## Evidence of PASS

**Sequential Phase:**
- [ ] Subagent prompt includes `PHASE CONTEXT:` section with current phase
- [ ] Subagent prompt includes `LATER PHASES (DO NOT IMPLEMENT):` with Phase 3+ summaries
- [ ] Subagent prompt includes `Plan reference: specs/{run-id}-{feature-slug}/plan.md`
- [ ] Subagent prompt includes `VERIFY PHASE SCOPE before implementing` step
- [ ] Code review section has `CRITICAL - AUTONOMOUS EXECUTION (NO USER PROMPTS):` header
- [ ] Code review section lists 5 scenarios where user prompts are forbidden
- [ ] Code review rejection uses `Dispatch fix subagent IMMEDIATELY (no user prompt, no questions)`
- [ ] Fix subagent prompt includes `Read implementation plan:` step (step 3)
- [ ] Fix subagent prompt includes scope creep handling instructions
- [ ] Fix subagent prompt includes `CRITICAL: If scope creep, implement LESS not ask user what to keep`
- [ ] Rationalization table includes "Scope creep but quality passes, ask user to choose"
- [ ] Rationalization table includes "Work is done correctly, just ahead of schedule"
- [ ] Rationalization table includes "Spec mentions feature X, might as well implement now"

**Parallel Phase:**
- [ ] Same 13 checks as sequential phase (parallel skill has identical changes)

**Integration Test (run with subagent):**
- [ ] Orchestrator extracts phase boundaries before dispatching
- [ ] Subagent receives phase context in prompt
- [ ] Code review detects scope creep (implemented Phase 3/4 in Phase 2)
- [ ] Code review returns "Ready to merge? No" with scope violation details
- [ ] Orchestrator does NOT call AskUserQuestion tool
- [ ] Orchestrator dispatches fix subagent immediately
- [ ] Fix subagent reads plan at specs/{run-id}-{feature-slug}/plan.md
- [ ] Fix subagent removes Phase 3/4 files
- [ ] Fix subagent keeps Phase 2 files only
- [ ] Re-review returns "Ready to merge? Yes"
- [ ] Phase 2 complete, proceeds to Phase 3

## Evidence of FAIL

**Missing phase context:**
```bash
# ❌ Subagent prompt does NOT include PHASE CONTEXT section
grep "PHASE CONTEXT:" skills/executing-sequential-phase/SKILL.md
# No matches found
```

**User prompting (critical failure):**
```bash
# ❌ Orchestrator asks user instead of auto-fixing
⏺ AskUserQuestion(Scope Decision)
  Options:
  1. Accept and skip phases 3-4
  2. Roll back to plan
```

**Missing plan context in fix subagent:**
```bash
# ❌ Fix subagent doesn't read plan
grep "Read implementation plan:" skills/executing-sequential-phase/SKILL.md
# No matches found
```

**Scope creep not in rationalization table:**
```bash
# ❌ Scope creep scenarios missing
grep "Scope creep" skills/executing-sequential-phase/SKILL.md
# No matches found
```

## Notes

**Test complexity:**
- This is a **critical integration test** (not unit test)
- Requires real subagent dispatch to validate behavior
- Tests the exact production failure mode
- Validates 3 skills working together: executing-sequential-phase, requesting-code-review, superpowers:code-reviewer

**Why this test matters:**
- Phase boundary violations are the #1 cause of spec drift
- User prompting breaks autonomous execution value prop
- Fix loop with plan context proves spec-anchored development works end-to-end
- Prevents regression of the fix we just implemented

**Alternative verification:**
If integration test is too heavy, verify with unit checks (Evidence of PASS section). All 26 checks can be validated with grep commands without spawning subagents.
