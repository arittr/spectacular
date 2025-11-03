# Test Scenario: Task Decomposition

## Context

Testing `/spectacular:plan` command's ability to decompose a feature spec into executable task plan with proper phase grouping.

**Setup:**
- Existing spec file: `specs/{runid}-{feature-slug}/spec.md`
- Spec includes requirements, architecture, acceptance criteria
- Repository may have codebase context

**Purpose:**
- Verify task decomposition follows quality rules
- Test automatic phase grouping (sequential/parallel)
- Validate task sizing (no XL tasks, not too many S tasks)
- Ensure file dependencies are explicit

**Reference:** CLAUDE.md Anti-Patterns in Plans section, decomposing-tasks skill

## Expected Behavior

### Input: Feature Spec

**Example spec:** Authentication system with:
- Database schema (users table, sessions table)
- API endpoints (signup, login, logout, reset password)
- UI components (login form, signup form, reset form)
- Email integration (welcome email, reset email)

### Step 1: Plan Generation

**Using decomposing-tasks skill to create execution plan...**

**File created:** `specs/{runid}-{feature-slug}/plan.md`

### Step 2: Plan Structure (Expected)

```markdown
# Execution Plan: Authentication System

Run ID: a1b2c3

## Phase 1: Foundation (Sequential)

These tasks must complete in order - each depends on previous task's output.

### Task 1.1: Database Schema and Models (M - 4h)

**Description:**
Create users and sessions tables with proper indexes. Define Prisma models with validation.

**Files to modify:**
- prisma/schema.prisma
- src/db/models/user.ts
- src/db/models/session.ts
- prisma/migrations/YYYYMMDD_create_auth_tables.sql

**Dependencies:**
- None (foundation task)

**Acceptance criteria:**
- [ ] Users table with email, password_hash, role columns
- [ ] Sessions table with token, user_id, expires_at columns
- [ ] Prisma models match schema
- [ ] Migration runs successfully
- [ ] All tests pass

---

### Task 1.2: Authentication Service (L - 6h)

**Description:**
Implement core auth logic: password hashing, JWT generation, token validation, session management.

**Files to modify:**
- src/services/auth.ts
- src/services/jwt.ts
- src/services/session.ts
- src/utils/crypto.ts

**Dependencies:**
- Task 1.1 (needs database models)

**Acceptance criteria:**
- [ ] Password hashing with bcrypt (12 rounds)
- [ ] JWT generation and validation
- [ ] Session creation and cleanup
- [ ] All service tests pass

---

## Phase 2: Feature Implementation (Parallel)

These tasks are independent and can execute simultaneously.

### Task 2.1: API Endpoints (M - 4h)

**Description:**
Create API routes for signup, login, logout, password reset. Integrate with auth service.

**Files to modify:**
- src/app/api/auth/signup/route.ts
- src/app/api/auth/login/route.ts
- src/app/api/auth/logout/route.ts
- src/app/api/auth/reset-password/route.ts

**Dependencies:**
- Task 1.2 (needs auth service)

**Parallel group:** Can run alongside Task 2.2, 2.3, 2.4

**Acceptance criteria:**
- [ ] All endpoints follow next-safe-action pattern
- [ ] Input validation with zod
- [ ] Error handling per constitution api-patterns.md
- [ ] Integration tests pass

---

### Task 2.2: UI Components (M - 5h)

**Description:**
Build login, signup, and password reset forms with validation and error display.

**Files to modify:**
- src/components/auth/LoginForm.tsx
- src/components/auth/SignupForm.tsx
- src/components/auth/ResetPasswordForm.tsx
- src/components/auth/AuthLayout.tsx

**Dependencies:**
- Task 1.2 (needs auth service types)

**Parallel group:** Can run alongside Task 2.1, 2.3, 2.4

**Acceptance criteria:**
- [ ] Forms use shadcn/ui components
- [ ] Client-side validation
- [ ] Loading and error states
- [ ] Accessibility requirements met
- [ ] Component tests pass

---

### Task 2.3: Email Integration (M - 3h)

**Description:**
Implement email sending for welcome and password reset using SendGrid.

**Files to modify:**
- src/services/email.ts
- src/templates/email/welcome.tsx
- src/templates/email/reset-password.tsx

**Dependencies:**
- Task 1.2 (needs user model types)

**Parallel group:** Can run alongside Task 2.1, 2.2, 2.4

**Acceptance criteria:**
- [ ] SendGrid integration configured
- [ ] Welcome email sent on signup
- [ ] Reset email sent on request
- [ ] Email templates follow brand guidelines
- [ ] Mock tests for email sending

---

### Task 2.4: OAuth Integration (M - 4h)

**Description:**
Add Google and GitHub OAuth providers using next-auth.

**Files to modify:**
- src/lib/auth.ts
- src/app/api/auth/[...nextauth]/route.ts
- src/components/auth/OAuthButtons.tsx

**Dependencies:**
- Task 1.1 (needs user model for OAuth linking)

**Parallel group:** Can run alongside Task 2.1, 2.2, 2.3

**Acceptance criteria:**
- [ ] Google OAuth working
- [ ] GitHub OAuth working
- [ ] User accounts linked correctly
- [ ] OAuth button UI integrated

---

## Execution Summary

**Total Tasks:** 6
**Estimated Time (Sequential):** 26 hours
**Estimated Time (Parallel):** 16 hours
**Time Savings:** 10 hours (38% reduction)

**Phase Breakdown:**
- Phase 1 (Sequential): 2 tasks, 10 hours
- Phase 2 (Parallel): 4 tasks, 6 hours (longest task)

**Task Sizing:**
- M (Medium): 5 tasks
- L (Large): 1 task
- No XL tasks ✅
- S tasks: 0% (good - tasks are coherent units) ✅
```

## Quality Rules from decomposing-tasks Skill

### Task Sizing

✅ **Good distribution:**
- 60-80% M tasks (3-5h)
- 10-30% L tasks (5-7h)
- <10% S tasks (1-2h)
- 0% XL tasks (>8h)

❌ **Bad distribution:**
- 50% XL tasks → Tasks too large, split them
- 60% S tasks → Tasks too granular, bundle them

### File Dependencies

✅ **Explicit paths:**
```markdown
**Files to modify:**
- src/services/auth.ts
- src/utils/crypto.ts
```

❌ **Vague wildcards:**
```markdown
**Files to modify:**
- All files in src/services/
- All auth-related files
```

### Task Dependencies

✅ **Clear dependency chain:**
```markdown
**Dependencies:**
- Task 1.1 (needs database models)
- Task 1.2 (needs auth service)
```

❌ **Vague dependencies:**
```markdown
**Dependencies:**
- Previous tasks
- Database stuff
```

### Thematic Coherence

✅ **Good chunking:**
- "Database Schema and Models" (schema + migration + models = ONE task)
- "API Endpoints" (all endpoints together, not split)

❌ **Mechanical splitting:**
- Task 1: Create schema.prisma
- Task 2: Create migration
- Task 3: Create models
→ Should be ONE task

## Failure Modes

### Issue 1: Too Many XL Tasks

**Symptom:** Plan has 3+ tasks estimated at 8+ hours

**Root Cause:** Didn't break down complex tasks

**Example:**
```markdown
### Task 1.1: Complete Authentication System (XL - 20h)
Implement everything: database, API, UI, emails, OAuth
```

**Prevention:** decomposing-tasks skill MUST enforce "no XL tasks" rule

### Issue 2: Too Many S Tasks

**Symptom:** 50%+ of tasks are S (1-2h)

**Root Cause:** Over-splitting - tasks too granular

**Example:**
```markdown
Task 2.1: Create users table (S - 1h)
Task 2.2: Create sessions table (S - 1h)
Task 2.3: Write migration (S - 1h)
Task 2.4: Create user model (S - 1h)
Task 2.5: Create session model (S - 1h)
```

**Better:** Bundle into "Database Schema and Models" (M - 4h)

**Prevention:** decomposing-tasks skill enforces <30% S tasks

### Issue 3: Wrong Parallel Grouping

**Symptom:** Tasks marked parallel but have dependencies on each other

**Example:**
```markdown
## Phase 2: Parallel

Task 2.1: API Endpoints (depends on auth service)
Task 2.2: Auth Service Implementation
```

**Problem:** Task 2.1 can't start until 2.2 done - NOT parallel!

**Detection:** Check dependencies - if task A depends on task B, they can't be in same parallel phase

### Issue 4: Wildcard File Patterns

**Symptom:** Files to modify uses `**/*.ts` or `src/auth/`

**Example:**
```markdown
**Files to modify:**
- src/**/*.ts
- All authentication files
```

**Prevention:** decomposing-tasks skill requires explicit file paths

## Success Criteria

### Task Quality
- [ ] No XL tasks (all tasks ≤7h)
- [ ] <30% S tasks (not over-split)
- [ ] 60-80% M tasks (sweet spot)
- [ ] All tasks thematically coherent

### File Dependencies
- [ ] All file paths explicit (no wildcards)
- [ ] File paths exist or are new files with clear location
- [ ] No vague "all files in..." patterns

### Phase Grouping
- [ ] Sequential tasks have clear dependency chain
- [ ] Parallel tasks have no inter-dependencies
- [ ] Parallelization time savings calculated correctly

### Plan Structure
- [ ] Execution summary shows task count and timing
- [ ] Each task has description, files, dependencies, acceptance criteria
- [ ] Clear phase boundaries
- [ ] Run ID matches spec

## Test Execution

### Test Case 1: Simple Feature (Sequential Only)

**Input spec:** Add contact form (simple, no parallelization needed)

**Expected plan:**
```markdown
## Phase 1: Implementation (Sequential)

Task 1.1: Contact Form Component (M - 3h)
Task 1.2: API Endpoint (M - 2h)
Task 1.3: Email Integration (M - 2h)

Total: 7 hours (sequential)
```

### Test Case 2: Complex Feature (Parallel Phases)

**Input spec:** Authentication system (as shown in example above)

**Expected plan:**
- Phase 1: Foundation (sequential, 2 tasks)
- Phase 2: Features (parallel, 4 tasks)
- Time savings from parallelization shown

### Test Case 3: No Constitution Context

**Setup:** Repository without constitutions

**Expected plan:**
- Still valid task breakdown
- May lack specific file path details
- Acceptance criteria more generic
- Warning about missing constitution context

### Validation After Generation

```bash
# Check plan exists
ls specs/*/plan.md

# Verify structure
grep -q "## Phase" specs/*/plan.md
grep -q "## Execution Summary" specs/*/plan.md

# Check for XL tasks (should not exist)
grep -E "(XL|8h|9h|10h)" specs/*/plan.md && echo "FAIL: XL tasks found"

# Check file dependencies are explicit
grep -E "\*\*/.+\.(ts|tsx|md)" specs/*/plan.md && echo "FAIL: Wildcard patterns found"

# Verify timing calculations
grep -q "Time Savings:" specs/*/plan.md
```

## Phase Grouping Logic

### When Tasks Should Be Sequential

1. Task B needs output of Task A
2. Database schema before API that uses it
3. Service layer before UI that calls it
4. Foundation before features

### When Tasks Should Be Parallel

1. No dependencies between tasks
2. Work on different parts of codebase
3. Different layers (API + UI + Email if all depend on same foundation)
4. Time savings justifies parallelization

### Automatic Detection

**decomposing-tasks skill should:**
1. Analyze task dependencies
2. Group tasks with no inter-dependencies into parallel phases
3. Keep dependent tasks in sequential order
4. Calculate time savings from parallelization

## Related Scenarios

- **lean-spec-generation.md** - Tests spec that feeds into this plan
- **parallel-stacking-*.md** - Tests execution of parallel phases from plan
- **sequential-stacking.md** - Tests execution of sequential phases from plan

## Edge Cases

### All Tasks Independent

**Scenario:** 5 tasks, all independent

**Expected plan:**
- Phase 1: Parallel (5 tasks)
- Timing: Sequential 20h, Parallel 5h (longest task), Savings 75%

### All Tasks Dependent

**Scenario:** 5 tasks in strict sequence

**Expected plan:**
- Phase 1: Sequential (5 tasks)
- Timing: 20h (no parallelization possible)

### Mixed Dependencies

**Scenario:**
- Task 1 (foundation)
- Tasks 2, 3, 4 depend on 1, independent of each other
- Task 5 depends on 2

**Expected plan:**
- Phase 1: Task 1 (sequential)
- Phase 2: Tasks 2, 3, 4 (parallel)
- Phase 3: Task 5 (sequential)
