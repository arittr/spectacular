# Multi-Repo Support Design

**Date:** 2026-01-22
**Status:** Validated

## Summary

Extend spectacular to support multi-repo workflows where features span multiple git repositories with coordinated changes and sequential dependencies.

## Goals

1. Support features spanning multiple separate git repos
2. Single spec + single plan with repo-tagged tasks
3. Per-repo worktrees, constitutions, and setup commands
4. Coordinated PR submission respecting cross-repo dependencies
5. Pure skills architecture (matching superpowers pattern)

## Non-Goals

- Cross-repo git-spice stacking (git-spice limitation)
- Configuration files (convention over configuration)
- Monorepo/package support (different problem)

---

## Architecture Changes

### Before (current)

```
spectacular/
├── commands/           # Heavy logic, orchestration
│   ├── init.md
│   ├── spec.md        # 200+ lines of logic
│   ├── plan.md
│   └── execute.md     # 300+ lines of logic
└── skills/            # Supporting skills
    ├── writing-specs/
    ├── decomposing-tasks/
    └── executing-*-phase/
```

### After (superpowers pattern)

```
spectacular/
├── commands/                    # Thin wrappers only (1-2 lines each)
│   ├── init.md                 # → invokes validating-environment skill
│   ├── spec.md                 # → invokes writing-specs skill
│   ├── plan.md                 # → invokes decomposing-tasks skill
│   └── execute.md              # → invokes executing-plan skill
└── skills/
    ├── validating-environment/ # NEW: extracted from init command
    ├── writing-specs/          # ENHANCED: multi-repo support
    ├── decomposing-tasks/      # ENHANCED: repo: field in tasks
    ├── executing-plan/         # NEW: merged from execute command
    ├── executing-sequential-phase/
    ├── executing-parallel-phase/
    └── ... (supporting skills)
```

---

## Workspace Structure

```
workspace/                      # User runs Claude from here
├── specs/                      # Specs always live here (at workspace root)
│   └── abc123-feature/
│       ├── spec.md
│       └── plan.md
├── backend/                    # Repo 1 (auto-detected via .git/)
│   ├── .git/
│   ├── .worktrees/            # Spectacular creates worktrees here
│   ├── CLAUDE.md              # Repo-specific setup/quality commands
│   └── docs/constitutions/current/
├── frontend/                   # Repo 2 (auto-detected)
│   ├── .git/
│   ├── .worktrees/
│   ├── CLAUDE.md
│   └── docs/constitutions/current/
└── shared-lib/                 # Repo 3 (auto-detected)
    ├── .git/
    └── ...
```

### Auto-Detection Logic

- Find all directories with `.git/` in workspace
- Those are the available repos
- Specs always go in `workspace/specs/`
- Each repo's `CLAUDE.md` defines its setup/quality commands
- Each repo's `docs/constitutions/current/` defines its architectural rules

No configuration file. Just convention.

---

## Plan Format

### Task Format with Repo Field

```markdown
## Phase 1: Database Foundation (sequential)
- [ ] **Task 1.1**: Add user_preferences table | repo: backend | files: prisma/schema.prisma, prisma/migrations/*
- [ ] **Task 1.2**: Add preferences types | repo: shared-lib | files: src/types/preferences.ts

## Phase 2: API + Frontend (parallel)
- [ ] **Task 2.1**: Add preferences endpoint | repo: backend | files: src/api/preferences.ts, src/api/index.ts
- [ ] **Task 2.2**: Add preferences hook | repo: frontend | files: src/hooks/usePreferences.ts
- [ ] **Task 2.3**: Add preferences UI | repo: frontend | files: src/components/Preferences.tsx

## Phase 3: Integration (sequential)
- [ ] **Task 3.1**: Wire up frontend to API | repo: frontend | files: src/App.tsx
```

### Execution Behavior

- **Sequential phases**: Tasks run in order, worktrees created in specified repo
- **Parallel phases**: Tasks with different repos run simultaneously in their respective repo worktrees
- **Setup commands**: Looked up from each repo's `CLAUDE.md`
- **Constitutions**: Each subagent reads constitution from its task's repo

---

## Per-Repo Constitutions

### Spec References Multiple Constitutions

```markdown
## Constitutions

This feature must comply with:
- **backend**: @backend/docs/constitutions/current/
- **frontend**: @frontend/docs/constitutions/current/
- **shared-lib**: @shared-lib/docs/constitutions/current/
```

### Task Execution

- Subagent working on `repo: backend` reads `backend/docs/constitutions/current/`
- Subagent working on `repo: frontend` reads `frontend/docs/constitutions/current/`
- Constitution path passed to subagent as part of task context

### Code Review

- Reviews validate against the constitution for that repo
- Multi-repo reviews check each file against its repo's constitution

---

## Git-Spice & PR Submission

### Per-Repo Stacking

Git-spice operates on one repository at a time, so each repo gets its own stack:

```
backend repo stack:          frontend repo stack:
  abc123-task-1-1-schema       abc123-task-2-2-hook
  abc123-task-2-1-endpoint     abc123-task-2-3-ui
                               abc123-task-3-1-wire-up
```

### Coordinated Submission

Spectacular tracks submission order based on phase dependencies:

```markdown
## PR Submission Order (derived from plan phases)

1. shared-lib PRs first (dependency)
2. backend PRs second
3. frontend PRs last (depends on backend API)
```

- Phase 1 PRs merge before Phase 2
- Parallel phase PRs can merge in any order within that phase
- User reviews/merges, spectacular creates PRs in correct order

### Branch Naming (unchanged)

```
{runId}-task-{phase}-{task}-{short-name}
```

Example: `abc123-task-2-1-preferences-endpoint`

No repo prefix needed since branches live in their own repos.

---

## Migration Path

### Single-Repo Backwards Compatibility

When spectacular detects it's running inside a single git repo (not a workspace with multiple repos):
- Specs stored in `specs/` at repo root (current behavior)
- No `repo:` field needed in tasks (defaults to current repo)
- Existing plans continue to work

### Detection Logic

```
If current directory contains .git/:
  → Single-repo mode (current behavior)

If current directory contains multiple subdirs with .git/:
  → Multi-repo mode (new behavior)
  → Specs go in ./specs/
  → Tasks require repo: field
```

---

## Implementation Plan

### Phase 1: Architecture Refactor
1. Convert commands to thin wrappers
2. Move command logic into skills
3. Create `validating-environment` skill
4. Create `executing-plan` skill (merge from execute command)

### Phase 2: Multi-Repo Core
1. Add workspace detection (single vs multi-repo)
2. Update `writing-specs` for multi-repo constitution references
3. Update `decomposing-tasks` for `repo:` field in tasks
4. Update spec/plan paths for workspace root

### Phase 3: Execution
1. Update worktree creation to target correct repo
2. Update setup command lookup (per-repo CLAUDE.md)
3. Update constitution lookup (per-repo)
4. Update subagent context passing

### Phase 4: PR Submission
1. Coordinate git-spice submission order across repos
2. Update finishing workflow for multi-repo

---

## Open Questions (Resolved)

| Question | Resolution |
|----------|------------|
| Where do specs live? | Workspace root `./specs/` |
| Config file needed? | No, convention over configuration |
| Repo prefix in branch names? | No, branches live in their repos |
| How handle constitutions? | Per-repo, passed to subagent with task |
| Cross-repo stacking? | Not possible (git-spice limitation), coordinate submission order instead |
