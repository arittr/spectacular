# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**Spectacular** is a Claude Code plugin that enables spec-anchored development with automatic parallel task execution. It extends the [superpowers](https://github.com/obra/superpowers) plugin with commands and skills for feature specification, task decomposition, and parallel execution via git worktrees and git-spice stacked branches.

**Core Philosophy:**

- **Spec anchoring**: Every line of code traces back to spec + constitution
- **Automatic parallelization**: Independent tasks run simultaneously via git worktrees
- **Reviewable PRs**: Auto-stacked branches keep changes small and focused
- **Constitution versioning**: Architectural rules evolve explicitly with immutable history

## Architecture

### Plugin Structure

This is a Claude Code plugin with a pure skills architecture (matching superpowers pattern):

```
spectacular/
├── .claude-plugin/
│   └── plugin.json              # Plugin metadata and configuration
├── commands/                     # Thin wrappers (invoke skills)
│   ├── init.md                  # → invokes validating-environment skill
│   ├── spec.md                  # → invokes writing-specs skill
│   ├── plan.md                  # → invokes decomposing-tasks skill
│   └── execute.md               # → invokes executing-plan skill
└── skills/                       # All logic lives here
    ├── validating-environment/  # Environment validation
    ├── writing-specs/           # Complete spec workflow
    ├── decomposing-tasks/       # Complete plan workflow
    ├── executing-plan/          # Execution orchestration
    ├── executing-sequential-phase/
    ├── executing-parallel-phase/
    ├── versioning-constitutions/ # Constitution evolution workflow
    ├── using-git-spice/         # Stacked branch management patterns
    └── ... (supporting skills)
```

### Command vs Skill (Updated)

- **Commands** (`commands/*.md`): Thin wrappers that invoke skills. Each command is ~5 lines that simply calls the appropriate skill.
- **Skills** (`skills/*/SKILL.md`): Contain all orchestration logic. Self-contained workflows that define HOW to do things.

### Core Workflow

1. **`/spectacular:init`** → Validates environment (superpowers, git-spice, git repo)
2. **`/spectacular:spec`** → Generates lean specification in `specs/{runId}-{feature-slug}/spec.md`
3. **`/spectacular:plan`** → Decomposes spec into execution plan with automatic phase grouping
4. **`/spectacular:execute`** → Orchestrates parallel/sequential implementation with git worktrees

## Multi-Repo Support

Spectacular supports features spanning multiple git repositories.

### Workspace Structure

```
workspace/                      # Run Claude from here
├── specs/                      # Specs at workspace root
│   └── abc123-feature/
│       ├── spec.md
│       └── plan.md
├── backend/                    # Repo 1 (has .git/)
│   ├── .worktrees/            # Per-repo worktrees
│   ├── CLAUDE.md              # Per-repo setup commands
│   └── docs/constitutions/current/
├── frontend/                   # Repo 2
│   ├── .worktrees/
│   ├── CLAUDE.md
│   └── docs/constitutions/current/
└── shared-lib/                 # Repo 3
```

### Auto-Detection

Spectacular auto-detects multi-repo mode:
- If current directory contains multiple subdirs with `.git/` → multi-repo mode
- If current directory is a single git repo → single-repo mode (original behavior)

### Multi-Repo Plan Format

Tasks specify which repo they belong to:

```markdown
## Phase 1: Foundation
- [ ] **Task 1.1**: Add shared types | repo: shared-lib | files: src/types.ts

## Phase 2: Implementation (parallel)
- [ ] **Task 2.1**: Add API endpoint | repo: backend | files: src/api.ts
- [ ] **Task 2.2**: Add UI component | repo: frontend | files: src/App.tsx
```

### Per-Repo Requirements

Each repo should have:
- `CLAUDE.md` with setup commands (required for worktrees)
- `docs/constitutions/current/` (optional but recommended)

### Execution Behavior

- **Parallel phases**: Tasks in different repos run simultaneously
- **Sequential phases**: Tasks execute in order, switching repos as needed
- **Stacking**: Each repo has its own git-spice stack (cannot stack across repos)
- **PR submission**: Submit in phase order (foundation repos first)

### Example Workflow

```bash
# From workspace root (parent of all repos)
cd workspace

# Initialize and check all repos
/spectacular:init

# Create spec for cross-repo feature
/spectacular:spec "user preferences with shared types"

# Create plan (will show per-repo tasks)
/spectacular:plan @specs/{runId}-{feature}/spec.md

# Execute (creates per-repo worktrees and branches)
/spectacular:execute @specs/{runId}-{feature}/plan.md

# Submit PRs (in phase order)
cd shared-lib && gs stack submit && cd ..
cd backend && gs stack submit && cd ..
cd frontend && gs stack submit && cd ..
```

### Codex-Specific Commands

**IMPORTANT: Intentional Duplication for Codex Independence**

The `.codex/commands/` directory contains Codex-specific command variants that use the spectacular-codex MCP server instead of Claude Code's Task tool. These commands intentionally duplicate orchestration logic (Steps 0a-1.7) from `commands/execute.md` to enable independent evolution of Codex and Claude Code execution paths.

**Key files with duplicated orchestration:**
- `commands/execute.md` (Claude Code) - Uses Task tool to spawn Claude subagents
- `.codex/commands/codex-execute.md` (Codex) - Uses MCP tool to spawn Codex CLI subagents

**When updating orchestration logic (Run ID extraction, plan parsing, validation, etc.):**

⚠️ **YOU MUST CHECK BOTH FILES** - Do not assume changes to one file automatically apply to the other.

**What's duplicated:**
- Steps 0a-0c: Run ID extraction, worktree verification, resume detection
- Step 1: Plan parsing and validation
- Step 1.5: Setup command validation
- Step 1.6: Quality command detection
- Step 1.7: Code review frequency configuration
- Steps 3-5: Verification, finish, and reporting

**What's different:**
- Step 2 in `execute.md`: Uses `executing-parallel-phase` and `executing-sequential-phase` skills with Task tool
- Step 2 in `codex-execute.md`: Calls `spectacular_execute` MCP tool and polls `subagent_status`

**Why duplication is intentional:**
1. **Decoupling**: Codex and Claude Code can evolve independently
2. **Self-contained**: Each command is complete and standalone (easier for LLMs)
3. **Different backends**: Task tool vs MCP server require fundamentally different execution logic
4. **Manageable size**: ~200 lines duplicated, not 2000 (maintenance overhead is acceptable)

**Testing both variants:**
- When changing orchestration, test in both Claude Code and Codex
- Use spectacular test suite for Claude Code variant
- Manual testing or Codex-specific tests for Codex variant

**Rationale documented in:**
- Duplication notice comment at top of `.codex/commands/codex-execute.md`
- This section in CLAUDE.md

## Using Spectacular in Your Project

### Defining Setup Commands

**REQUIRED**: Spectacular creates isolated git worktrees for each feature. Each worktree needs dependencies installed and codegen run. Define these commands in your project's CLAUDE.md:

```markdown
## Development Commands

### Setup

- **install**: `bun install` (or `npm install`, `pnpm install`, `yarn`, `pip install -r requirements.txt`, etc.)
- **postinstall**: `npx prisma generate` (optional - any codegen needed after install)
```

**When setup runs:**
- After creating main worktree (`/spectacular:spec`)
- Before executing tasks in sequential phases
- Before executing each task in parallel phases

**Setup logic:**
- Checks if `node_modules` (or equivalent) exists in worktree
- If missing: Runs `install` command, then `postinstall` if defined
- If exists: Skips installation (handles resume scenarios)

**Why required:**
- Worktrees are separate directories with no shared `node_modules`
- Quality checks (test, lint, build) need dependencies
- Codegen (Prisma, GraphQL, etc.) must run for types

**If not defined:** Setup is skipped with error to user. Projects MUST define setup commands.

### Defining Quality Check Commands

Spectacular's `/spectacular:execute` command runs project-specific quality checks after each task. Define these commands in your project's CLAUDE.md:

```markdown
## Development Commands

### Quality Checks

- **test**: `npm test` (or `pytest`, `go test`, `cargo test`)
- **lint**: `npm run lint` (or `ruff check .`, `golangci-lint run`)
- **format**: `npm run format` (or `black .`, `go fmt`, `cargo fmt`)
- **build**: `npm run build` (or `python -m build`, `go build`, `cargo build`)
```

**Detection order:**
1. CLAUDE.md "## Development Commands" section
2. Constitution `testing.md` (if using spectacular's constitution pattern)
3. Common patterns (package.json scripts, pytest.ini, Makefile, etc.)

**If not defined:** Quality checks are skipped with warning to user.

**Why define these:**
- Ensures code quality after each task in execution flow
- Project-agnostic (works with any language/toolchain)
- Automatic verification before completion

## Development Commands

### Testing & Validation (Spectacular Plugin)

This repository has **no traditional test/build commands** - it's pure markdown documentation for Claude Code. Instead, we use **Test-Driven Development for workflow documentation**.

#### The Testing System

**Core Skill:** `tests/testing-spectacular.md`
- Enforces RED-GREEN-REFACTOR cycle for all spectacular changes
- Binary pass/fail verdicts (no "mostly works")
- Artifact storage for every test run
- Evidence requirements: file:line references, command outputs, rationale

**Test Infrastructure:**
- `tests/README.md` - Complete testing guide with step-by-step workflow
- `tests/aggregate-results.sh` - Results aggregation and summary generation

**Test Scenarios:** `tests/scenarios/{command}/*.md`
- Machine-readable YAML frontmatter (id, type, severity, duration, tags)
- Verification Commands section (executable bash commands)
- Evidence of PASS/FAIL criteria (explicit checkboxes)
- Binary verdicts only - either passes or fails

#### Running Tests

**Before committing any change to commands or skills:**

```bash
# Ask Claude Code to run the test suite
"Run the test suite for execute command"
"Run the full test suite"

# Claude will follow tests/README.md workflow to:
# 1. Create results directory
# 2. Dispatch subagents in batches (max 10 concurrent)
# 3. Aggregate results with tests/aggregate-results.sh
# 4. Report pass/fail summary with todos for failures

# View results manually
cat tests/results/{timestamp}/summary.md
cat tests/results/{timestamp}/scenarios/*.log
```

**Test workflow (RED-GREEN-REFACTOR):**

1. **RED Phase:** Create/find failing test scenario
   - Real bug: Find scenario that should catch it, verify FAIL
   - New feature: Write scenario first, verify FAIL (TDD)

2. **GREEN Phase:** Fix implementation
   - Update command/skill to meet scenario requirements
   - Re-run tests, verify PASS
   - Check for regressions (run full suite)

3. **REFACTOR Phase:** Improve without breaking tests
   - Add edge case coverage
   - Improve clarity
   - Re-run tests, verify still PASS

#### Test Scenario Format

**Example scenario structure:**

```markdown
---
id: scenario-name
type: integration              # unit, integration, e2e
severity: critical             # critical, major, minor
estimated_duration: 5m
tags: [tag1, tag2]
---

# Test Scenario: Title

## Context
Brief description and why it's critical

## Expected Behavior
Detailed correct behavior description

## Verification Commands
```bash
grep -n "expected text" skills/skill-name/SKILL.md
```

## Evidence of PASS
- [ ] Line X contains: "expected text"
- [ ] Verification command exits 0
- [ ] NO anti-pattern text found

## Evidence of FAIL
- [ ] Missing required text
- [ ] Verification command fails
```

#### Integration with Development Workflow

**When creating new command:**
1. Write test scenario FIRST (RED)
2. Run tests → scenario fails
3. Write command implementation (GREEN)
4. Run tests → scenario passes
5. Improve clarity (REFACTOR)
6. Commit with test results

**When fixing bugs:**
1. Reproduce with test scenario (RED)
2. Verify scenario fails
3. Fix implementation (GREEN)
4. Verify scenario passes
5. Run full suite (no regressions)
6. Commit with evidence

**When editing existing skills:**
1. Identify affected scenarios
2. Run tests → verify still pass
3. Make changes
4. Run tests → verify still pass
5. If tests fail → fix implementation, not tests
6. Commit with test results

**The Iron Law:** NO SPECTACULAR CHANGES WITHOUT PASSING TESTS FIRST

This applies to all commands, skills, bug fixes, and documentation updates.

### Plugin Development

**Installing locally for development:**

```bash
# Link to local plugins directory
ln -s /path/to/spectacular ~/.claude/plugins/cache/spectacular

# Or copy to plugins directory
cp -r . ~/.claude/plugins/cache/spectacular
```

**Reloading changes:**

- Claude Code reads plugin files on-demand
- Command/skill changes take effect immediately (no restart needed)
- Plugin metadata changes (plugin.json) may require restart

### Version Management

**IMPORTANT:** Always use `./scripts/update-version.sh` to bump versions. Never edit version numbers manually in `.claude-plugin/plugin.json` or `.claude-plugin/marketplace.json`.

**Bump version when creating new branches:**

```bash
./scripts/update-version.sh 2.0.0-alpha22    # Specify exact version
```

**Typical version progression:**
- Bug fixes, minor changes: `2.0.0-alpha21` → `2.0.0-alpha22`
- New features (pre-release): `2.0.0-alpha22` → `2.0.0-beta1`
- Stable releases: `2.0.0-beta1` → `2.0.0`

**What happens automatically:**

1. Updates `.claude-plugin/plugin.json` version
2. Updates `.claude-plugin/marketplace.json` version
3. Ensures consistency across both files

**Why mandatory:**
- Manual edits can cause version drift between files
- Script ensures semver format is valid
- Maintains version consistency for plugin loading

## Configuration

### Environment Variables

#### REVIEW_FREQUENCY

Controls when code reviews run during `/spectacular:execute`:

- **`optimize`** - LLM decides when to review based on phase risk/complexity (RECOMMENDED)
  - Reviews foundation phases, schema changes, auth logic, security-sensitive code
  - Skips low-risk phases like UI components, docs, isolated utilities
  - Balances speed and quality by focusing reviews where they matter most
- `per-phase` - Review after each phase completes (safest - catches errors early)
- `end-only` - Review once after all phases complete (faster, but errors may compound)
- `skip` - No automated reviews (fastest, requires manual review before merging)

**Example:**
```bash
export REVIEW_FREQUENCY=optimize
/spectacular:execute @specs/abc123-feature/plan.md
```

If not set, you'll be prompted to choose during execution.

**Impact on execution time:**
- `per-phase` on 5-phase plan: 5 reviews (~10-25 min)
- `optimize` on 5-phase plan: 2-3 reviews (~6-15 min) - skips low-risk phases
- `end-only` on 5-phase plan: 1 review (~2-5 min) - errors may compound
- `skip`: 0 reviews - manual review required before merging

## Key Concepts

### Specifications vs Plans

- **Specification** (`spec.md`): Defines WHAT to build and WHY

  - Requirements, architecture, acceptance criteria
  - References constitutions, links to external docs
  - NO implementation steps or task breakdown
  - Generated by `writing-specs` skill

- **Plan** (`plan.md`): Defines HOW and WHEN to implement
  - Task breakdown with file dependencies
  - Automatic phase grouping (sequential/parallel)
  - Time estimates and parallelization savings
  - Generated by `decomposing-tasks` skill

**Multi-repo considerations:**
- Specs stored at workspace root in multi-repo mode
- Plans include `repo:` field for each task
- Constitutions referenced per-repo

### Constitutions

**Constitutions** are immutable snapshots of architectural truth stored in `docs/constitutions/`:

- **architecture.md** - Layer boundaries and project structure
- **patterns.md** - Mandatory patterns (e.g., "use next-safe-action for all server actions")
- **tech-stack.md** - Approved libraries and versions
- **schema-rules.md** - Database design philosophy
- **testing.md** - Testing requirements

Constitutions are **versioned** (v1/, v2/, etc.) with a `current/` symlink pointing to active version. Use the `versioning-constitutions` skill to create new versions when architectural rules change.

### Task Chunking Philosophy

Tasks should be **PR-sized, thematically coherent units** - not mechanical file-by-file splits.

**Good chunking:**

- M (3-5h): Sweet spot - complete subsystem, layer, or feature slice
- L (5-7h): Complex coherent units (full UI layer, complete API surface)
- S (1-2h): Rare - only truly standalone work

**Avoid:**

- XL tasks (>8h): Always split into M/L tasks
- Too many S tasks (>30%): Bundle related work into M tasks
- Mechanical splits: Schema + migration + dependencies should be ONE task ("Database Foundation")

### Parallel Execution with Worktrees

The `execute` command uses **git worktrees** for true parallel isolation:

1. Setup subagent creates worktrees for independent tasks
2. Implementation subagents work in isolated directories simultaneously
3. Each subagent creates its own branch with `gs branch create`
4. Cleanup subagent removes worktrees and creates linear stack
5. Code review validates integration

**Critical:** Parallel task subagents MUST `git switch --detach` after creating branches to make them accessible in parent repo.

### Git-Spice Stacking

All work is organized as **stacked branches** using [git-spice](https://github.com/abhinav/git-spice):

- Sequential tasks stack linearly: `task-1 → task-2 → task-3`
- Parallel tasks branch from same base, then stack for review
- No "feature branch" - the stack of task branches IS the feature
- Submit entire feature as stacked PRs with `gs stack submit`

See `using-git-spice` skill for command reference and workflows.

### Run IDs

Every execution has a **Run ID** (6-char hash) that namespaces branches and directories:

- Spec directory: `specs/{runId}-{feature-slug}/`
- Branch naming: `{runId}-task-1-2-database-schema`
- Filtering: `git branch | grep "^  {runId}-"`
- Enables multiple features to be developed simultaneously without branch name conflicts

## Editing Commands and Skills

### Command Structure

Commands are markdown files with YAML frontmatter:

```markdown
---
description: One-line description shown to users
---

{Detailed instructions for Claude Code}
```

**Key principles:**

- Commands orchestrate workflows but delegate actual work to skills
- Use clear step-by-step instructions
- Include error handling and recovery steps
- Reference skills explicitly (e.g., "Use the `requesting-code-review` skill")

### Skill Structure

Skills are markdown files following the superpowers format:

```markdown
---
name: skill-name
description: When to use this skill
---

# Skill Title

## When to Use

{Trigger conditions}

**Announce:** "I'm using {skill-name} to {purpose}."

## The Process

{Step-by-step workflow}

## Quality Rules

{Standards and validation}

## Error Handling

{Common failures and recovery}
```

**Key principles:**

- Skills are process documentation, not code
- Follow RED-GREEN-REFACTOR: Assume Claude will rationalize away rules
- Include "Rationalization Table" for predictable shortcuts
- Add TodoWrite checklists for critical steps
- Test with `testing-skills-with-subagents` before deployment

### Maintaining Quality

When editing commands/skills:

1. **Read existing patterns**: All skills follow superpowers conventions
2. **Preserve rigor**: Don't soften rules to make them "easier" - rigor prevents bugs
3. **Test before committing**: Run the workflow in a sample project
4. **Version carefully**: Commands/skills are load-bearing - changes affect all users

## Dependencies

**Required:**

- [superpowers](https://github.com/obra/superpowers) plugin - Core skills library (TDD, debugging, code review)
- [git-spice](https://github.com/abhinav/git-spice) - Stacked branch management
- Git repository - All workflows assume git

**Validated by `/spectacular:init` command**

## Common Workflows

### Creating a New Command

1. Create `commands/{command-name}.md` with description frontmatter
2. Write orchestration steps (delegate to skills, don't implement directly)
3. Test command in a sample project
4. Update `commands/README.md` if it exists

### Creating a New Skill

1. Create `skills/{skill-name}/SKILL.md` with name/description frontmatter
2. Follow superpowers skill template (When to Use, The Process, Quality Rules, Error Handling)
3. Add rationalization table for predictable shortcuts
4. Test with `testing-skills-with-subagents` skill
5. Include TodoWrite checklists if skill has sequential steps

### Updating Constitution Workflow

If changing how constitutions work:

1. Read `skills/versioning-constitutions/SKILL.md` carefully
2. Test changes don't break immutability guarantees
3. Update documentation in README.md if user-facing

### Multi-Repo Feature Development

1. Set up workspace with repos as subdirectories
2. Run `/spectacular:init` to validate all repos
3. Run `/spectacular:spec` from workspace root
4. Review spec with per-repo constitution references
5. Run `/spectacular:plan` to get repo-tagged tasks
6. Run `/spectacular:execute` for parallel execution across repos
7. Submit PRs per-repo in phase order

## File Naming Conventions

- Commands: Lowercase with hyphens: `init.md`, `execute.md`
- Skills: Lowercase with hyphens: `decomposing-tasks/`, `writing-specs/`
- Specs: `{runId}-{feature-slug}/spec.md` where runId is 6-char hash
- Plans: `{runId}-{feature-slug}/plan.md` (same directory as spec)
- Branches: `{runId}-task-{phase}-{task}-{short-name}` (e.g., `a1b2c3-task-1-2-install-tsx`)

## Integration with Superpowers

Spectacular **extends** superpowers, not replaces it. Key superpowers skills used:

- `brainstorming` - Refines ideas before spec creation
- `test-driven-development` - Write test first, watch fail, minimal code
- `systematic-debugging` - Four-phase debugging framework
- `requesting-code-review` - Dispatch code-reviewer after each phase
- `verification-before-completion` - Evidence before assertions
- `finishing-a-development-branch` - Complete work and choose next action
- `using-git-worktrees` - Parallel task isolation
- `subagent-driven-development` - Context-isolated task execution

**Never recreate superpowers workflows - reference and use them.**

## Anti-Patterns to Avoid

### In Specs

- ❌ Duplicating constitution rules (reference them instead)
- ❌ Including code examples from libraries (link to docs)
- ❌ Creating implementation plans (use `/spectacular:plan`)
- ❌ Adding success metrics or timelines (those are product docs)

### In Plans

- ❌ XL tasks (>8h) - always split into M/L
- ❌ Too many S tasks (>30%) - bundle into thematic M tasks
- ❌ Wildcard file patterns (`src/**/*.ts`) - use explicit paths
- ❌ Circular dependencies - review task organization

### In Execution

- ❌ Orchestrator running git commands directly (delegate to subagents)
- ❌ Creating empty "feature branch" upfront (stack IS the feature)
- ❌ Parallel tasks forgetting to detach HEAD (breaks worktree cleanup)
- ❌ Skipping quality gates (tests, linting, code review)

## Troubleshooting

### Command Not Found

- Verify file is in `commands/` directory
- Check YAML frontmatter has `description` field
- Restart Claude Code if plugin.json was changed

### Skill Not Loading

- Verify file is at `skills/{name}/SKILL.md`
- Check YAML frontmatter has `name` and `description`
- Use Skill tool with exact skill name

### Worktree Creation Fails

- Check `.worktrees/` is in `.gitignore`
- Run `git worktree prune` to clean stale entries
- Verify working directory is clean

### Git-Spice Errors

- Run `gs repo init` to initialize repository
- Check `gs ls` to view current stack
- See `using-git-spice` skill for troubleshooting

## References

- Main documentation: [README.md](README.md)
- Command reference: [commands/README.md](commands/README.md)
- Superpowers: https://github.com/obra/superpowers
- Git-spice: https://github.com/abhinav/git-spice
