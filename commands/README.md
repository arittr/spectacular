# BigNight.Party Commands

Spec-driven development workflow with automatic sequential/parallel orchestration using superpowers skills and git-spice.

## Workflow

### Specify → Plan → Execute

```bash
# 1. Generate comprehensive spec from requirements (generates runId: a1b2c3)
/spectacular:spec "magic link authentication with Auth.js"

# 2. Decompose into execution plan with automatic phase analysis
/spectacular:plan @specs/a1b2c3-magic-link-auth/spec.md

# 3. Execute with automatic sequential/parallel orchestration
/spectacular:execute @specs/a1b2c3-magic-link-auth/plan.md
```

**Key Innovation**: Automatic parallelization based on file dependency analysis. You don't choose - Claude analyzes and orchestrates.

---

## Commands

### `/spectacular:spec {description}`

**Purpose**: Generate a complete feature specification from a brief description.

**Uses**:

- `brainstorming` skill to refine requirements
- Task tool to analyze codebase context
- Outputs comprehensive spec with task breakdown

**Output**: `specs/{runid}-{feature-slug}/spec.md`

**Example**:

```bash
/spectacular:spec "user picks wizard with category navigation"
# Generates: specs/d4e5f6-user-picks-wizard/spec.md
```

**What it generates**:

- Requirements (functional + non-functional)
- Architecture (models, services, actions, UI)
- Implementation tasks with file paths
- Acceptance criteria per task
- Mandatory pattern reminders (next-safe-action, ts-pattern)

---

### `/spectacular:plan {spec-path}`

**Purpose**: Decompose spec into executable plan with automatic phase analysis.

**Uses**:

- `task-decomposition` skill (custom BigNight.Party skill)
- Analyzes file dependencies between tasks
- Groups into sequential/parallel phases
- Validates task quality (no XL, explicit files, criteria)

**Output**: `{spec-directory}/plan.md`

**Example**:

```bash
/spectacular:plan @specs/a1b2c3-magic-link-auth/spec.md
```

**What it generates**:

- Phase grouping with strategies (sequential/parallel)
- Task dependencies based on file analysis
- Execution time estimates with parallelization savings
- Complete implementation details per task

**Automatic decisions**:

- **Sequential phase**: Tasks share files or have dependencies
- **Parallel phase**: Tasks are independent, can run simultaneously

**Quality validation**:

- ❌ XL tasks (>8h) → Must split
- ❌ Missing files → Must specify
- ❌ Missing criteria → Must add 3-5
- ❌ Wildcard patterns → Must be explicit

---

### `/spectacular:execute {plan-path}`

**Purpose**: Execute plan with automatic sequential/parallel orchestration.

**Uses**:

- `subagent-driven-development` skill for task execution
- Fresh subagent per task with code review gates
- Git worktrees for parallel execution
- `finishing-a-development-branch` skill for completion
- Git-spice for branch management

**Flow**:

1. Create feature branch with `gs branch create`
2. For each phase:
   - **Sequential**: Use `subagent-driven-development` in feature branch
   - **Parallel**: Create worktrees, spawn agents in parallel, merge branches
3. Complete with `finishing-a-development-branch` skill

**Example**:

```bash
/spectacular:execute @specs/a1b2c3-magic-link-auth/plan.md
```

**Sequential phase execution**:

```
Phase 1 (sequential):
  Task 1 → fresh subagent → code review → commit
  Task 2 → fresh subagent → code review → commit
  Task 3 → fresh subagent → code review → commit
```

**Parallel phase execution**:

```
Phase 2 (parallel):
  Worktree A: Task 4 → fresh subagent → code review → commit
  Worktree B: Task 5 → fresh subagent → code review → commit
  Worktree C: Task 6 → fresh subagent → code review → commit
  ↓
  Merge all → feature branch → cleanup worktrees
```

**Quality Gates** (every task):

- Code review after each task
- Biome linting
- Tests pass
- Frequent commits

**Time Savings**:

```
Without parallelization: 10h (sequential)
With parallelization: 6h (longest parallel phase)
Savings: 4h (40% faster)
```

---

## Mandatory Patterns

All commands enforce these patterns from the constitution (see `@docs/constitutions/current/patterns.md`):

### 1. next-safe-action for ALL server actions

```typescript
// ✅ REQUIRED
export const submitPickAction = authenticatedAction
  .schema(pickSchema)
  .action(async ({ parsedInput, ctx }) => {
    return pickService.submitPick(ctx.userId, parsedInput);
  });

// ❌ FORBIDDEN
export async function submitPick(data: unknown) {
  // Raw server action
}
```

### 2. ts-pattern for ALL discriminated unions

```typescript
// ✅ REQUIRED
return match(event.status)
  .with("SETUP", () => false)
  .with("OPEN", () => true)
  .with("LIVE", () => false)
  .with("COMPLETED", () => false)
  .exhaustive(); // Compiler enforces completeness!

// ❌ FORBIDDEN
switch (event.status) {
  case "SETUP":
    return false;
  case "OPEN":
    return true;
  // Missing cases - no error!
}
```

### 3. Layer Boundaries

```
UI Components (src/components/)
    ↓ calls
Server Actions (src/lib/actions/) - next-safe-action only
    ↓ calls
Services (src/lib/services/) - business logic, no Prisma
    ↓ calls
Models (src/lib/models/) - Prisma only, no business logic
```

**Rules**:

- ✅ Actions call services
- ✅ Services call models
- ✅ Models use Prisma
- ❌ Services cannot import Prisma
- ❌ Actions cannot call models directly

---

## Tech Stack Reference

- **Framework**: Next.js 15 (App Router + Turbopack)
- **Language**: TypeScript (strict mode)
- **Database**: Prisma + PostgreSQL
- **Auth**: Auth.js v5 (magic links)
- **Real-time**: Socket.io
- **Validation**: Zod + next-safe-action
- **Pattern Matching**: ts-pattern
- **Linting**: Biome
- **VCS**: Git + git-spice

---

## Superpowers Skills Used

These commands integrate the following superpowers skills:

- **`brainstorming`** - Refine requirements before spec generation
- **`task-decomposition`** - Analyze dependencies and group into phases (custom skill)
- **`subagent-driven-development`** - Task-level autonomous execution with code review gates
- **`finishing-a-development-branch`** - Verify completion and submit
- **`using-git-worktrees`** (concepts) - Worktree creation and isolation
- **`dispatching-parallel-agents`** (concepts) - Parallel execution coordination

**Added Value**: Automatic dependency analysis, sequential/parallel phase detection, git-spice orchestration, worktree lifecycle management.

---

## Examples

### Example 1: Single Feature (Sequential)

```bash
# Generate spec
/spectacular:spec "leaderboard with real-time updates via Socket.io"

# Review: specs/a1b2c3-leaderboard/spec.md

# Generate plan with phase analysis
/spectacular:plan @specs/a1b2c3-leaderboard/spec.md

# Review: specs/a1b2c3-leaderboard/plan.md
# Plan shows: 3 phases, all sequential (tasks share files)

# Execute
/spectacular:execute @specs/a1b2c3-leaderboard/plan.md

# Result: Sequential execution, no parallelization
# Time: 12h
```

### Example 2: Feature with Parallel Opportunities

```bash
# Generate spec
/spectacular:spec "user authentication with magic links"

# Generate plan
/spectacular:plan @specs/a1b2c3-auth/spec.md

# Review plan:
# - Phase 1 (sequential): Database + Models (share files)
# - Phase 2 (parallel): Magic link service + Email service (independent)
# - Phase 3 (sequential): Actions + UI (depend on Phase 2)

# Execute
/spectacular:execute @specs/a1b2c3-auth/plan.md

# Result:
# - Phase 1: 4h (sequential)
# - Phase 2: 2h (parallel, was 5h sequential - 3h saved!)
# - Phase 3: 3h (sequential)
# Total: 9h (vs 12h sequential = 25% faster)
```

### Example 3: Large Feature Auto-Decomposed

```bash
# Generate spec for complex feature
/spectacular:spec "admin category management with drag-reorder and live preview"

# Generate plan
/spectacular:plan @specs/a1b2c3-admin-categories/spec.md

# Plan auto-detects:
# - Phase 1 (sequential): 3 tasks - Database schema + models
# - Phase 2 (parallel): 4 tasks - Services (independent domains)
# - Phase 3 (sequential): 2 tasks - Admin actions
# - Phase 4 (parallel): 3 tasks - UI components (independent pages)
# - Phase 5 (sequential): 1 task - Integration + E2E tests
#
# Time: 15h parallel vs 24h sequential (9h = 38% saved)

# Execute automatically orchestrates all phases
/spectacular:execute @specs/a1b2c3-admin-categories/plan.md
```

---

## Troubleshooting

### "Plan validation failed"

**Cause**: Spec has quality issues (XL tasks, missing files, missing criteria).

**Fix**:

1. Review validation errors
2. Update spec at the indicated locations
3. Re-run `/spectacular:plan @spec-path`

### "Parallel phase failed - one agent blocked"

**Cause**: One task in parallel phase hit an issue.

**Fix**:

1. Other tasks already completed and merged
2. Fix failing task in its worktree: `cd {worktree-path}`
3. Debug and commit fix
4. Merge manually: `git merge {task-branch}`
5. Cleanup worktree: `git worktree remove {path}`

### "Merge conflict in parallel phase"

**Cause**: Tasks marked as independent actually modified same files.

**Fix**:

1. This indicates incorrect dependency analysis
2. Resolve conflict manually
3. Update plan to mark tasks as sequential
4. Report issue so task-decomposition skill can be improved

### "Tests failing after execution"

**Cause**: Implementation has bugs.

**Fix**: subagent-driven-development includes code review after each task, but bugs can slip through.

1. Review test failures
2. Use `systematic-debugging` skill to investigate
3. Fix issues
4. Commit fixes

---

## Design Philosophy

**Spec-Driven Development**:

1. Comprehensive specs eliminate questions during implementation
2. Mandatory patterns ensure consistency
3. Layer boundaries prevent architectural drift
4. Quality gates catch issues early

**Automatic Orchestration**:

1. Dependency analysis determines sequential vs parallel
2. No manual decision needed - Claude optimizes
3. Worktrees provide true isolation for parallel work
4. Git-spice manages branch stacking

**Task-Level Autonomy**:

1. Fresh subagent per task (no context pollution)
2. Code review after each task (catch issues early)
3. Continuous commits (small, focused changes)
4. Quality gates every step

**Time Optimization**:

1. Automatic parallelization where safe
2. 20-40% time savings typical for large features
3. No coordination overhead (worktrees isolate)
4. Transparent - see exactly what's parallel vs sequential

---

## Performance Benefits

**Without this workflow**:

- Manual dependency tracking
- Conservative sequential execution
- No automatic parallelization
- Example: 20h for large feature

**With this workflow**:

- Automatic dependency analysis
- Optimal parallel/sequential orchestration
- Worktree isolation (no conflicts)
- Example: 12h for same feature (40% faster)

**Real savings**:

- Small features (1-5 tasks): 0-10% savings (mostly sequential)
- Medium features (6-15 tasks): 15-30% savings (some parallel phases)
- Large features (15+ tasks): 30-50% savings (multiple parallel phases)
