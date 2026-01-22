# Test Scenario: Multi-Repo Execution

## Context

**Testing:** `/spectacular:execute` handles multi-repo plans with per-repo worktrees and setup commands.

**Setup:**

- Multi-repo workspace with backend, frontend repos
- Plan has tasks tagged with `repo: backend` and `repo: frontend`
- Each repo has CLAUDE.md with different setup commands

**Why this scenario:**

- Worktrees must be created INSIDE each repo (not workspace root)
- Setup commands differ per repo (npm vs pip)
- Constitution paths are per-repo
- Git-spice stacking is per-repo

## Expected Behavior

### Worktree Creation (Multi-Repo)

For task in `repo: backend`:

```bash
cd backend
git worktree add .worktrees/{runId}-task-{N} main
```

NOT:

```bash
# WRONG - creates worktree at workspace root
git worktree add .worktrees/{runId}-task-{N} main
```

### Per-Repo Setup Commands

Setup commands read from each repo's CLAUDE.md:

```bash
# For backend task
INSTALL_CMD=$(grep -A1 "**install**:" backend/CLAUDE.md | tail -1)

# For frontend task
INSTALL_CMD=$(grep -A1 "**install**:" frontend/CLAUDE.md | tail -1)
```

### Per-Repo Stacking

Each repo maintains its own git-spice stack:

```
backend repo stack:
  {runId}-task-1-1-schema
  └─□ {runId}-task-2-1-api

frontend repo stack:
  {runId}-task-2-2-component
  └─□ {runId}-task-3-1-integration
```

## Verification Commands

```bash
# Verify multi-repo context passing in executing-plan
grep -n "WORKSPACE_MODE" skills/executing-plan/SKILL.md

# Verify per-repo worktree creation in parallel phase
grep -n "worktree.*repo\|TASK_REPO" skills/executing-parallel-phase/SKILL.md

# Verify per-repo setup command lookup
grep -n "CLAUDE.md.*repo\|repo.*CLAUDE.md" skills/executing-parallel-phase/SKILL.md

# Verify sequential phase handles repo switching
grep -n "WORKSPACE_MODE" skills/executing-sequential-phase/SKILL.md
```

## Evidence of PASS

- [ ] `executing-plan` passes WORKSPACE_MODE to phase skills
- [ ] `executing-parallel-phase` creates worktrees inside task's repo
- [ ] Setup commands read from per-repo CLAUDE.md
- [ ] `executing-sequential-phase` handles cross-repo sequential tasks
- [ ] Subagent prompts include repo-specific context (constitution path, CLAUDE.md path)

## Evidence of FAIL

- [ ] WORKSPACE_MODE not passed to phase skills
- [ ] Worktrees created at workspace root instead of repo root
- [ ] Setup commands always read from same CLAUDE.md
- [ ] No repo context in subagent prompts

## Test Execution

**Manual setup:**

```bash
# Create multi-repo workspace
mkdir -p /tmp/workspace/{backend,frontend}
cd /tmp/workspace/backend && git init && echo "## Development Commands\n\n**install**: pip install -r requirements.txt" > CLAUDE.md
cd /tmp/workspace/frontend && git init && echo "## Development Commands\n\n**install**: npm install" > CLAUDE.md

# Create spec and plan with multi-repo tasks
# Run execute
cd /tmp/workspace
/spectacular:execute @specs/{runId}-feature/plan.md
```

**Expected behavior:**

1. Detects WORKSPACE_MODE="multi-repo"
2. Creates worktrees in each repo's .worktrees/
3. Runs `pip install` for backend tasks
4. Runs `npm install` for frontend tasks
5. Stacks branches per-repo

## Related Scenarios

- **parallel-stacking-4-tasks.md** - Single-repo parallel execution
- **sequential-stacking.md** - Single-repo sequential execution
- **multi-repo-detection.md** - Multi-repo workspace detection
- **multi-repo-task-format.md** - Multi-repo plan format
