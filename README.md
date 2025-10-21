# Spectacular

Spec-anchored development workflows with automatic parallel task execution for Claude Code.

## What is Spectacular?

Spectacular extends [superpowers](https://github.com/obra/superpowers) with commands and skills for spec-anchored development:

- **`/spectacular:spec`** - Generate comprehensive feature specifications from brief descriptions
- **`/spectacular:plan`** - Decompose specs into executable plans with automatic dependency analysis
- **`/spectacular:execute`** - Execute plans with automatic sequential/parallel orchestration

## Why Spectacular?

**The Problem:** Traditional feature development suffers from:

- **Spec drift**: Specs get out of sync with code, or don't exist at all
- **Massive PRs**: Large features become 5000-line diffs that nobody wants to review
- **Sequential bottlenecks**: Everything runs one-at-a-time, even independent work
- **Architectural drift**: Rules get duplicated, outdated, or ignored across the codebase

**The Spectacular Solution:**

- **Spec anchoring**: Every line of code traces back to spec + constitution - no drift, no guessing
- **Automatic parallelization**: Independent tasks run simultaneously via git worktrees - no manual orchestration
- **Reviewable PRs**: Auto-stacked branches keep changes small and focused - reviewers see bite-sized diffs
- **Constitution versioning**: Architectural rules evolve explicitly with immutable history

## Key Features

### 1. Spec Anchoring via Specifications & Constitutions

Every feature starts with a comprehensive spec that serves as the **anchor point** for all implementation work:

- **Specifications** define WHAT to build (requirements, architecture, acceptance criteria)
- **Constitutions** define foundational rules (mandatory patterns, tech stack, layer boundaries)
- Specs reference constitutions instead of duplicating rules
- All implementation traces back to the spec - no drift, no guessing

### 2. Parallel Implementation with Execute

Automatic parallelization based on file dependency analysis:

- Analyzes which tasks share files (must be sequential)
- Identifies independent tasks (can run in parallel)
- Uses git worktrees for true parallel isolation - no conflicts
- Scales time savings with feature complexity

### 3. Automatic Stacking & PR Chunking

Built-in git-spice integration for reviewable pull requests:

- Each task becomes a branch in a stack
- Sequential tasks stack linearly: `task-1 → task-2 → task-3`
- Parallel tasks branch from same base, then stack for review
- Submit entire feature as stacked PRs with `gs stack submit`
- Reviewers see small, focused changes instead of massive diffs

## Dependencies

Spectacular builds on these excellent projects:

- **[superpowers](https://github.com/obra/superpowers)** - Core skills library (TDD, debugging, code review, etc.)
- **[git-spice](https://github.com/abhinav/git-spice)** - Stacked branch management
- **Claude Code** - AI-native development environment

## Quick Start

### 1. Install Dependencies

```bash
# Install superpowers plugin
/plugin marketplace add obra/superpowers-marketplace
/plugin install superpowers@superpowers-marketplace

# Install git-spice
brew install git-spice  # macOS
```

### 2. Install Spectacular

```bash
/plugin marketplace add arittr/spectacular
/plugin install spectacular@arittr
```

_Note: If spectacular is not yet in the marketplace, clone this repo to your local plugins directory._

### 3. Initialize Your Project

```bash
/spectacular:init
```

This checks dependencies, configures .gitignore, and validates your environment.

### 4. Run Your First Workflow

```bash
# Generate a spec
/spectacular:spec "user authentication with magic links"

# Create an execution plan
/spectacular:plan @specs/a1b2c3-auth/spec.md

# Execute with automatic parallelization
/spectacular:execute @specs/a1b2c3-auth/plan.md
```

## Example Workflows

### Basic Feature Development

```bash
# 1. Initialize (first time only)
/spectacular:init

# 2. Generate spec from natural language
/spectacular:spec "admin dashboard with real-time analytics"

# 3. Review the generated spec
cat specs/d4e5f6-admin-dashboard/spec.md

# 4. Generate implementation plan with automatic phase detection
/spectacular:plan @specs/d4e5f6-admin-dashboard/spec.md

# Plan output shows:
# - Phase 1 (sequential): Database + Models
# - Phase 2 (parallel): 3 services run simultaneously
# - Phase 3 (sequential): Actions + UI
# - Estimated parallelization time savings

# 5. Execute with automatic parallel orchestration
/spectacular:execute @specs/d4e5f6-admin-dashboard/plan.md

# 6. Submit as stacked PRs for review
gs stack submit
```

### With Constitution Management

For projects with architectural rules:

```bash
# 1. Initialize with constitutions directory
/spectacular:init
mkdir -p docs/constitutions/v1
# Create architecture.md, patterns.md, tech-stack.md, etc.
ln -s v1 docs/constitutions/current

# 2. Specs reference constitution rules
/spectacular:spec "user authentication with magic links"
# Spec will reference @docs/constitutions/current/patterns.md instead of duplicating

# 3. When patterns evolve, ask Claude to version the constitution
```

Example prompt:

```
"We're adopting Zod for runtime validation across the app. Update our
 constitution to add Zod to tech-stack.md and create a pattern in
 patterns.md for validation schemas."
```

Claude will:

- Create docs/constitutions/v2/
- Copy all files from v1 to v2
- Update tech-stack.md with Zod
- Add validation pattern to patterns.md
- Update current/ symlink to point to v2
- Document the change in meta.md changelog

```bash
# 4. Execute with constitutional compliance
/spectacular:execute @specs/a1b2c3-auth/plan.md
# Subagents follow current constitution (now v2) for implementation
```

## Advanced Features

### Constitution Versioning

The `versioning-constitutions` skill helps manage your project's architectural rules (constitutions) as they evolve over time.

**What are Constitutions?**

Constitutions are immutable snapshots of architectural truth - the foundational rules that, if violated, break your architecture. They live in `docs/constitutions/` and include:

- **patterns.md** - Mandatory patterns (e.g., "use next-safe-action for all server actions")
- **tech-stack.md** - Approved libraries and versions
- **architecture.md** - Layer boundaries and project structure
- **schema-rules.md** - Database design philosophy
- **testing.md** - Testing requirements

**When to Create a New Version:**

Always create a new version when:

- Adding/removing/relaxing a mandatory pattern
- Changing tech stack (e.g., Prisma → Drizzle)
- Updating architectural boundaries
- Major library version changes with breaking patterns

**How to Update Your Constitution:**

There's no slash command for constitution versioning - instead, ask Claude to use the skill:

```
# Example prompts to trigger the versioning-constitutions skill:

"We're adopting Effect-TS for error handling. Update our constitution to
 make it a mandatory pattern."

"We're migrating from Prisma to Drizzle. Create a new constitution version
 that updates tech-stack.md and removes Prisma patterns."

"We're adding a new 'agents' layer to our architecture. Version the
 constitution to document this change in architecture.md."

"We decided next-safe-action is now optional, not mandatory. Create a new
 constitution version that relaxes this requirement."
```

**What the Skill Does:**

1. Reads `docs/constitutions/current/meta.md` to get current version
2. Creates new version directory (e.g., `v1` → `v2`)
3. Copies current version files to new directory
4. Makes ONLY the requested changes (minimal diff)
5. Updates `meta.md` with version number and changelog
6. Updates `current/` symlink to point to new version
7. Reports what changed and why

**Key Principle:** Constitution versions are immutable. Never edit old versions - always create new ones. This preserves history, enables rollback, and makes changes explicit.

**Test for Constitutionality:**

- ✅ Constitutional: "Must use next-safe-action" → violating breaks type safety
- ❌ Not constitutional: "Forms should have submit button" → just a convention

Constitution = Architectural rules. Specs = Implementation patterns.

### Git-Spice Stacked Branches

The `using-git-spice` skill provides comprehensive guidance for managing stacked branches with git-spice.

**Why Stacked Branches?**

Stacked branches (also called "stacked diffs" or "dependent PRs") allow you to:

- Break large features into reviewable chunks
- Submit dependent work before prerequisites merge
- Keep PR review scope small and focused
- Maintain velocity on dependent work

**Key Concepts:**

```
┌── feature-c     ← upstack from feature-b
├── feature-b     ← upstack from feature-a
├── feature-a     ← first branch in stack
main (trunk)
```

- **Stack**: All connected branches (upstack + downstack)
- **Upstack**: Branches built on current branch (children)
- **Downstack**: Branches below current to trunk (parents)

**Common Commands:**

```bash
# Initialize repo (once)
gs repo init

# Create stacked branches
gs branch create feature-a      # Creates branch on current
git add . && git commit -m "A"
gs branch create feature-b      # Stacks on feature-a
git add . && git commit -m "B"

# View stack
gs log short  # Quick view
gs log long   # Detailed view

# Submit entire stack as PRs
gs stack submit

# Move branch to new base
gs upstack onto main

# Sync with remote, clean up merged branches
gs repo sync
```

**Spectacular Integration:**

Spectacular uses git-spice for task branch management:

- Sequential tasks stack linearly: `task-1 → task-2 → task-3`
- Parallel tasks branch from same base, then stack: `task-2.1 → task-2.2 → task-2.3`
- Submit entire feature as stack: `gs stack submit`

The skill provides:

- Command reference with shortcuts
- Common workflow patterns
- Troubleshooting for conflicts and rebases
- Best practices for PR submission

## Project Structure

### Spectacular Plugin Structure

```
spectacular/
├── .claude-plugin/
│   └── plugin.json                  # Plugin metadata
├── commands/
│   ├── spectacular:init.md          # Dependency checking
│   ├── spectacular:spec.md          # Spec generation
│   ├── spectacular:plan.md          # Task decomposition
│   └── spectacular:execute.md       # Parallel execution
├── skills/
│   ├── decomposing-tasks/           # Plan generation logic
│   ├── writing-specs/               # Spec generation logic
│   ├── versioning-constitutions/    # Constitution management
│   └── using-git-spice/             # Git-spice workflows
└── README.md
```

### Your Project Structure (After Using Spectacular)

```
your-project/
├── docs/
│   └── constitutions/
│       ├── current -> v2/           # Symlink to current version
│       ├── v1/                      # Historical version
│       │   ├── meta.md
│       │   ├── architecture.md
│       │   ├── patterns.md
│       │   ├── tech-stack.md
│       │   ├── schema-rules.md
│       │   └── testing.md
│       └── v2/                      # Current version
│           ├── meta.md              # Version info + changelog
│           ├── architecture.md      # Layer boundaries
│           ├── patterns.md          # Mandatory patterns
│           ├── tech-stack.md        # Approved libraries
│           ├── schema-rules.md      # Database philosophy
│           └── testing.md           # Testing requirements
├── specs/
│   ├── a1b2c3-feature-name/
│   │   ├── spec.md                  # Feature specification
│   │   ├── plan.md                  # Execution plan
│   │   └── clarifications.md        # Optional: questions
│   └── d4e5f6-another-feature/
│       ├── spec.md
│       └── plan.md
├── .worktrees/                      # Temporary (gitignored)
│   ├── a1b2c3-task-2-1/             # Parallel task workspace
│   └── a1b2c3-task-2-2/             # Parallel task workspace
└── .gitignore                       # Includes .worktrees/
```

## Commands & Skills

### Commands

- **`spectacular:init`** - Environment initialization and dependency checking
- **`spectacular:spec`** - Feature specification generation
- **`spectacular:plan`** - Task decomposition with dependency analysis
- **`spectacular:execute`** - Parallel/sequential execution orchestration

### Skills

- **`decomposing-tasks`** - Analyze specs and create execution plans
- **`writing-specs`** - Generate lean, architecture-focused specifications
- **`versioning-constitutions`** - Manage evolving architectural rules (constitutions)
- **`using-git-spice`** - Stacked branch management with git-spice CLI

## Documentation

- **Full Command Reference**: [commands/README.md](commands/README.md)
- **Skills Directory**: [skills/](skills/)
- **Superpowers**: [obra/superpowers](https://github.com/obra/superpowers)
- **Git-Spice**: [abhinav/git-spice](https://github.com/abhinav/git-spice)

## Contributing

Spectacular is designed to work with [superpowers](https://github.com/obra/superpowers). Consider contributing to both projects!

## License

MIT

## Author

Drew Ritter - [@arittr](https://github.com/arittr)

Built on [superpowers](https://github.com/obra/superpowers) by Jesse Vincent
