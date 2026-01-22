# Test Scenario: Multi-Repo Task Format

## Context

**Testing:** `/spectacular:plan` generates tasks with `**Repo**:` field in multi-repo mode.

**Setup:**

- Multi-repo workspace detected
- Spec references multiple repos (backend, frontend, etc.)
- Plan decomposition should generate per-repo tasks

**Why this scenario:**

- Execution depends on knowing which repo each task belongs to
- Worktrees must be created in the correct repo
- Setup commands differ per repo (npm vs pip, etc.)

## Expected Behavior

### Task Format in Multi-Repo Mode

Each task MUST include the `**Repo**:` field:

```markdown
### Task 1.1: Add user_preferences table

**Repo**: backend
**Files**:
- prisma/schema.prisma
- prisma/migrations/*

**Constitution**: @backend/docs/constitutions/current/
```

### Cross-Repo Dependency Analysis

Tasks in DIFFERENT repos are automatically parallelizable:

```markdown
## Phase 2: Implementation (parallel)

- [ ] **Task 2.1**: Add API endpoint | repo: backend | files: src/api.ts
- [ ] **Task 2.2**: Add UI component | repo: frontend | files: src/App.tsx
```

Tasks in SAME repo touching same files must be sequential.

## Verification Commands

```bash
# Verify multi-repo task format exists in decomposing-tasks skill
grep -n "**Repo**:" skills/decomposing-tasks/SKILL.md

# Verify multi-repo detection in plan skill
grep -n "WORKSPACE_MODE" skills/decomposing-tasks/SKILL.md

# Verify cross-repo parallelization documented
grep -n "different repos" skills/decomposing-tasks/SKILL.md

# Verify constitution reference includes repo prefix
grep -n "Constitution.*repo" skills/decomposing-tasks/SKILL.md
```

## Evidence of PASS

- [ ] `skills/decomposing-tasks/SKILL.md` shows `**Repo**:` field in task template
- [ ] Multi-repo detection (WORKSPACE_MODE) is performed
- [ ] Cross-repo tasks can be parallelized (different repos = independent)
- [ ] Constitution paths include repo prefix in multi-repo mode

## Evidence of FAIL

- [ ] No `**Repo**:` field in task template for multi-repo
- [ ] WORKSPACE_MODE not checked in decomposing-tasks skill
- [ ] Cross-repo dependency analysis missing
- [ ] Constitution paths don't reference repo prefix

## Test Execution

**Example spec for multi-repo:**

```markdown
# User Preferences Feature

## Overview
Add user preferences with shared types, backend API, and frontend UI.

## Repos Involved
- shared-lib: Type definitions
- backend: API and database
- frontend: UI components

## Constitutions
- @backend/docs/constitutions/current/
- @frontend/docs/constitutions/current/
```

**Expected plan output:**

```markdown
## Phase 1: Foundation (sequential)
- [ ] **Task 1.1**: Add preference types | repo: shared-lib | files: src/types.ts

## Phase 2: Implementation (parallel)
- [ ] **Task 2.1**: Add API endpoint | repo: backend | files: src/api.ts
- [ ] **Task 2.2**: Add UI component | repo: frontend | files: src/App.tsx
```

## Related Scenarios

- **multi-repo-detection.md** - Detects multi-repo workspace
- **task-decomposition.md** - General task decomposition validation
