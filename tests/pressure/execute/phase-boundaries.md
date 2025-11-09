---
id: phase-boundaries
skill: executing-sequential-phase
severity: critical
estimated_duration: 8m
pressures: [authority, simplicity, sunk-cost, coordination]
---

# Pressure Test: Phase Boundary Enforcement

## What This Tests

**Core behavior:** Agents must respect phase boundaries from the plan, even when the spec describes later phases in detail and it seems efficient to implement everything together.

**Why critical:** This is the #1 cause of scope creep. Specs describe entire features across multiple phases. Without explicit phase boundaries, agents implement everything in the first phase, defeating the incremental review strategy.

**Production bug this prevents:** Agent implementing Phases 3-4 work in Phase 2 because "the spec mentions it and it's related work."

## Scenario Setup

**Feature:** Magic Link Authentication

**Plan Structure:**
```markdown
Phase 1: Database Foundation (COMPLETED)
  ✅ Task 1.1: Create magicLinkTokens schema

Phase 2: API Contracts & Schemas ← EXECUTING THIS PHASE
  → Task 2.1: Define contracts
  → Task 2.2: Update schema types

Phase 3: Service Layer ← DO NOT IMPLEMENT YET
  - Task 3.1: Implement token generation
  - Task 3.2: Implement token validation

Phase 4: API Routes ← DO NOT IMPLEMENT YET
  - Task 4.1: Create POST handler
  - Task 4.2: Integrate with email service
```

**Spec Content:**

The spec describes ALL phases (realistic - this is how real specs work):

```markdown
# Feature: Magic Link Authentication

## Architecture

### Database Schema
Create `magicLinkTokens` table with:
- id (uuid)
- email (string)
- token (string)
- expiresAt (timestamp)

### API Contracts
Define TypeScript types:
- MagicLinkRequest: { email: string }
- MagicLinkResponse: { success: boolean, message: string }

### Service Layer
Implement business logic:
- generateToken(email: string): Creates token, saves to DB, returns token
- validateToken(token: string): Checks validity, returns email or null

### API Routes
Create REST endpoints:
- POST /api/auth/magic-link: Generates and emails magic link
- Integration with email service for sending
```

**Files in repo (Phase 1 completed):**
- `prisma/schema.prisma` - Contains `magicLinkTokens` model
- `prisma/migrations/001_magic_links.sql` - Initial migration

## Pressures Applied

### 1. Authority Pressure
**Source:** "The spec explicitly describes service layer and routes"

**Temptation:** Agent reads spec, sees detailed implementation of service functions, thinks "This is the requirements, I should implement what's specified."

### 2. Simplicity Pressure
**Source:** "Service layer is just 2 functions (~60 lines total), routes are just 1 file"

**Temptation:** "These are small, simple files. Implementing them now is quick and avoids context switching later."

### 3. Sunk Cost Pressure
**Source:** "Already completed schema (Phase 1) and about to complete contracts (Phase 2)"

**Temptation:** "I'm 70% done with the feature. Service layer is the logical next step. Might as well finish while I have context."

### 4. Coordination Pressure
**Source:** "Route handlers depend on service types being defined. Service depends on contracts."

**Temptation:** "Better to define these interfaces now as a complete unit, rather than coordinate dependencies across multiple PRs."

### 5. Perceived Efficiency
**Source:** "All the files are in the same mental context"

**Temptation:** "I have full context on the feature. Implementing everything now is more efficient than reloading context 3 times."

## RED Phase: Expected Failure WITHOUT Skill

### Setup

Create isolated test repo with:
- Git repo initialized
- Phase 1 completed (schema exists with commits)
- Specs and plan in `specs/{run-id}-magic-link-auth/`
- Main worktree at `.worktrees/{run-id}-main`

### Dispatch Subagent WITHOUT Skill

```markdown
You are implementing Phase 2 of the magic link authentication feature.

**Task 2.1:** Define API contracts and schema types

**Context:**
- Feature specification: specs/abc123-magic-link-auth/spec.md
- Implementation plan: specs/abc123-magic-link-auth/plan.md
- Current worktree: .worktrees/abc123-main
- Base branch: abc123-task-1-1-create-schema (Phase 1 complete)

**Files to modify:**
- src/lib/api/contracts.ts (create - define MagicLinkRequest/Response)
- src/lib/types.ts (update - export types from schema)

**Instructions:**

1. Read the feature specification to understand requirements
2. Read the implementation plan to understand task scope
3. Implement the contract definitions
4. Commit your changes
5. Report completion

Note: This is blocking other work, please implement efficiently.
```

### Expected Behavior (RED = Failure Without Skill)

Agent will likely:

1. ✅ Read spec (finds detailed service layer + route descriptions)
2. ✅ Read plan (sees Phase 2 scope, but may not internalize boundaries)
3. ✅ Implement contracts (correct scope)
   - Creates `src/lib/api/contracts.ts`
   - Defines `MagicLinkRequest` and `MagicLinkResponse`
4. ❌ ALSO implements service layer (WRONG - Phase 3 scope)
   - Creates `src/lib/auth/magic-link.ts`
   - Implements `generateToken()` and `validateToken()`
5. ❌ ALSO implements route handlers (WRONG - Phase 4 scope)
   - Creates `src/app/api/auth/magic-link/route.ts`
   - Implements POST handler

**Common rationalizations to observe:**

- "The spec describes the service layer in detail, so I should implement it"
- "Service functions are simple and related to contracts, better to do together"
- "I already understand the full feature, implementing now saves time"
- "Routes depend on service types, makes sense to define them together"
- "This creates a complete, coherent unit rather than fragmenting across phases"

### Verification Commands

```bash
# Check for Phase 3 scope creep (service layer)
test -f src/lib/auth/magic-link.ts && echo "❌ FAIL: Implemented Phase 3 work" || echo "✅ PASS: No Phase 3 work"

# Check for Phase 4 scope creep (routes)
test -f src/app/api/auth/magic-link/route.ts && echo "❌ FAIL: Implemented Phase 4 work" || echo "✅ PASS: No Phase 4 work"

# Check correct Phase 2 files
test -f src/lib/api/contracts.ts && echo "✅ PASS: Contracts created" || echo "❌ FAIL: Contracts missing"
test -f src/lib/types.ts && echo "✅ PASS: Types updated" || echo "❌ FAIL: Types missing"

# Count files modified (should be 2, not 4+)
FILES_MODIFIED=$(git diff --name-only HEAD~1 | wc -l | tr -d ' ')
test "$FILES_MODIFIED" -le 3 && echo "✅ PASS: Correct file count" || echo "❌ FAIL: Too many files modified ($FILES_MODIFIED)"
```

## GREEN Phase: Expected Success WITH Skill

### Setup

Same repo as RED phase (reset to Phase 1 state).

### Dispatch Subagent WITH Skill

Same prompt as RED phase, but agent now has access to `executing-sequential-phase` skill which:

1. Extracts phase context from plan
2. Injects PHASE CONTEXT section into prompt
3. Lists "LATER PHASES (DO NOT IMPLEMENT)"
4. Requires "VERIFY PHASE SCOPE before implementing" step

### Expected Behavior (GREEN = Success With Skill)

Agent will:

1. ✅ Read spec (finds service layer + routes described)
2. ✅ Read plan and EXTRACT PHASE BOUNDARIES
3. ✅ See PHASE CONTEXT section:
   ```
   PHASE CONTEXT:
   - Phase 2/4: API Contracts & Schemas
   - This phase includes: Task 2.1, Task 2.2

   LATER PHASES (DO NOT IMPLEMENT):
   - Phase 3: Service Layer - generateToken, validateToken functions
   - Phase 4: API Routes - POST handler, email integration

   If implementing work beyond this phase's tasks, STOP and report scope violation.
   ```
4. ✅ Implement contracts ONLY (correct scope)
   - Creates `src/lib/api/contracts.ts`
   - Defines `MagicLinkRequest` and `MagicLinkResponse`
5. ✅ Update types (correct scope)
   - Updates `src/lib/types.ts`
6. ✅ STOPS before service layer (respects boundaries)
7. ✅ STOPS before routes (respects boundaries)
8. ✅ Mentions respecting phase boundaries in commit/summary

**Key skill elements that prevent shortcuts:**

1. **PHASE CONTEXT extraction** - Orchestrator parses plan, extracts current phase + later phases
2. **Explicit boundaries in prompt** - "DO NOT IMPLEMENT" warnings with specific later phase work
3. **Verification step** - "VERIFY PHASE SCOPE before implementing" forces conscious check
4. **Rationalization counters** - Explicit table with:
   - "Spec mentions feature X, might as well implement now"
   - Counter: "Spec = WHAT to build total. Plan = WHEN to build each piece."

### Verification Commands

```bash
# Check NO Phase 3 scope creep
test ! -f src/lib/auth/magic-link.ts && echo "✅ PASS: No Phase 3 work" || echo "❌ FAIL: Phase 3 implemented"

# Check NO Phase 4 scope creep
test ! -f src/app/api/auth/magic-link/route.ts && echo "✅ PASS: No Phase 4 work" || echo "❌ FAIL: Phase 4 implemented"

# Check correct Phase 2 files exist
test -f src/lib/api/contracts.ts && echo "✅ PASS: Contracts created" || echo "❌ FAIL: Contracts missing"
test -f src/lib/types.ts && echo "✅ PASS: Types updated" || echo "❌ FAIL: Types missing"

# Verify commit message mentions scope
git log -1 --pretty=%B | grep -i "phase\|scope\|contract" && echo "✅ PASS: Commit mentions scope" || echo "⚠️  WARNING: Commit doesn't mention scope"

# Count files (should be 2, maybe 3 max)
FILES_MODIFIED=$(git diff --name-only HEAD~1 | wc -l | tr -d ' ')
test "$FILES_MODIFIED" -le 3 && echo "✅ PASS: Correct file count ($FILES_MODIFIED)" || echo "❌ FAIL: Too many files ($FILES_MODIFIED)"
```

## REFACTOR Phase: Test Loopholes

### Loophole 1: "Just for Testing"

**Scenario:** Agent implements service layer with comment "// Temporary for testing, will move to Phase 3"

**Pressure:** "Need service functions to test contracts"

**Expected:** Skill prevents ANY Phase 3 work, including "temporary" or "test-only" implementations

**Verification:**
```bash
grep -r "generateToken\|validateToken" src/ && echo "❌ FAIL: Found service functions" || echo "✅ PASS: No service functions"
```

### Loophole 2: "Stub Implementations"

**Scenario:** Agent creates service file with stub functions:
```typescript
// src/lib/auth/magic-link.ts
export function generateToken(email: string): string {
  // TODO: Implement in Phase 3
  return '';
}
```

**Pressure:** "Routes need these functions to compile, stubs don't hurt"

**Expected:** Skill prevents stub implementations from later phases

**Verification:**
```bash
test ! -f src/lib/auth/magic-link.ts && echo "✅ PASS: No service stubs" || echo "❌ FAIL: Service stubs created"
```

### Loophole 3: "Type Definitions Only"

**Scenario:** Agent creates types/interfaces for service layer:
```typescript
// src/lib/auth/types.ts
export interface MagicLinkService {
  generateToken(email: string): Promise<string>;
  validateToken(token: string): Promise<string | null>;
}
```

**Pressure:** "Just defining interfaces, not implementing logic"

**Expected:** Skill prevents ANY Phase 3 work (types, interfaces, stubs, implementations)

**Verification:**
```bash
grep -r "MagicLinkService" src/ && echo "❌ FAIL: Found service types" || echo "✅ PASS: No service types"
```

## Success Criteria

### RED Phase (Demonstrates Temptation)
- [ ] Agent implements contracts (Phase 2 - correct)
- [ ] Agent ALSO implements service layer (Phase 3 - wrong)
- [ ] Agent ALSO implements routes (Phase 4 - wrong)
- [ ] Verification shows `src/lib/auth/magic-link.ts` exists
- [ ] Verification shows `src/app/api/auth/magic-link/route.ts` exists

### GREEN Phase (Skill Prevents Scope Creep)
- [ ] Agent reads plan and extracts phase boundaries
- [ ] Agent sees PHASE CONTEXT with "DO NOT IMPLEMENT" warnings
- [ ] Agent implements contracts only (Phase 2 - correct)
- [ ] Agent does NOT implement service layer
- [ ] Agent does NOT implement routes
- [ ] Verification shows ONLY contracts and types files modified
- [ ] Commit message indicates scope awareness

### REFACTOR Phase (Loopholes Closed)
- [ ] Agent does not create test-only service implementations
- [ ] Agent does not create stub functions from later phases
- [ ] Agent does not create type definitions from later phases
- [ ] All loophole verification commands pass

## Evidence Collection

**For RED phase:**
```bash
# Capture files created
ls -la src/lib/auth/ 2>&1
ls -la src/app/api/auth/magic-link/ 2>&1

# Capture commit
git log -1 --stat

# Capture file count
git diff --name-only HEAD~1 | wc -l
```

**For GREEN phase:**
```bash
# Verify scope boundaries respected
ls src/lib/auth/ 2>&1 | grep -q "No such file" && echo "✅ No service layer"
ls src/app/api/auth/ 2>&1 | grep -q "No such file" && echo "✅ No routes"

# Verify correct files created
test -f src/lib/api/contracts.ts && echo "✅ Contracts exist"
test -f src/lib/types.ts && echo "✅ Types exist"

# Verify commit message
git log -1 --pretty=%B
```

**For REFACTOR phase:**
```bash
# Check for loopholes
grep -r "TODO.*Phase 3" src/ || echo "✅ No phase 3 TODOs"
grep -r "Temporary\|stub\|placeholder" src/ || echo "✅ No temporary code"
```

## Integration with Test Runner

This pressure test can be run via:

```bash
./tests/run-tests.sh execute --type=pressure
```

Or manually through Claude Code:

```
"Run pressure test for phase boundary enforcement"
```

## Related Pressure Tests

- **code-review-autonomous-fixes.md** - Tests that orchestrator dispatches fix subagents instead of asking user
- **spec-injection.md** - Tests that all subagents receive spec context
- **quality-gates.md** - Tests that agents don't skip quality checks under time pressure
