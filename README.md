# Spectacular

Spec-anchored, stack-driven development workflows with automatic parallel task execution for Claude Code.

> [!NOTE]
> The `/spectacular:execute` workflow is tightly coupled to git-spice for PR stacking. Support for Graphite (and other engines) coming soon!

[![Install](https://img.shields.io/badge/install-arittr%2Fspectacular-5B3FFF?logo=claude)](https://github.com/arittr/spectacular#installation)
[![Version](https://img.shields.io/badge/dynamic/json?url=https://raw.githubusercontent.com/arittr/spectacular/main/.claude-plugin/plugin.json&label=version&query=$.version&color=orange)](https://github.com/arittr/spectacular/releases)
[![License](https://img.shields.io/badge/license-MIT-green)](LICENSE)

## Overview

Spectacular extends [superpowers](https://github.com/obra/superpowers) with commands and skills for spec-anchored development and long running tasks:

- **`/spectacular:spec`** - Generate feature specifications from natural language descriptions
- **`/spectacular:plan`** - Decompose specs into executable plans with automatic dependency analysis
- **`/spectacular:execute`** - Execute plans with automatic sequential/parallel orchestration and checkpointing via git-spice stacks

### The Problem

Traditional AI-assisted feature development suffers from:

- **Context drift** - Long running tasks lose context, leading to bugs and missed requirements
- **Spec drift** - Specs get out of sync with code or don't exist at all
- **Massive PRs** - Large features become 5000-line diffs that nobody wants to review
- **Sequential bottlenecks** - Everything runs one-at-a-time, even independent work
- **Architectural drift** - Rules get duplicated, outdated, or ignored across the codebase

### The Solution

- **Context anchoring** - Tasks run in subagents with isolated context pre-loaded with the spec and constitution
- **Spec anchoring** - Every line of code traces back to spec + constitution
- **Automatic parallelization** - Independent tasks run simultaneously via git worktrees
- **Reviewable PRs** - Auto-stacked branches keep diffs small and focused
- **Constitution versioning** - Architectural rules evolve explicitly with immutable history

## How It Works

### 1. Specifications & Constitutions

Every feature starts with a comprehensive spec that serves as the anchor point for all implementation:

- **Specifications** (`specs/{id}-{name}/spec.md`) define WHAT to build - requirements, architecture, acceptance criteria
- **Constitutions** (`docs/constitutions/`) define foundational rules - mandatory patterns, tech stack, layer boundaries
- Specs reference constitutions instead of duplicating rules
- All implementation traces back to the spec

### 2. Automatic Parallelization

The planner analyzes file dependencies to identify independent work:

- Tasks sharing files must run sequentially
- Independent tasks run in parallel via git worktrees
- Time savings scale with feature complexity
- No manual orchestration required

### 3. Quality Gates

After each phase or set of tasks, automatic code review ensures adherence:

- Reviews implementation against spec requirements
- Validates compliance with constitution rules
- Catches drift before it compounds
- Corrects implementation before proceeding to next phase

### 4. Stacked PRs

Built-in git-spice integration creates reviewable pull requests:

- Each task becomes a branch in a stack
- Sequential tasks: `task-1 → task-2 → task-3`
- Parallel tasks branch from same base, then stack for review
- Submit entire feature with `gs stack submit`

## Dependencies

Spectacular builds on these excellent projects:

- **[superpowers](https://github.com/obra/superpowers)** - Core skills library (TDD, debugging, code review, etc.)
- **[git-spice](https://github.com/abhinav/git-spice)** - Stacked branch management
- **Claude Code** - AI-native development environment

## Installation

### 1. Install Dependencies

```bash
# Install superpowers plugin
# In Claude Code
/plugin marketplace add obra/superpowers-marketplace
/plugin install superpowers@superpowers-marketplace

# Install git-spice
brew install git-spice  # macOS
```

### 2. Install Spectacular

```bash
/plugin marketplace add arittr/spectacular
/plugin install spectacular@spectacular
```

### 3. Initialize Your Project

```bash
/spectacular:init
```

This validates dependencies, configures `.gitignore`, and initializes git-spice.

> [!NOTE]  
> Spectacular uses ./.worktrees/ to store temporary git worktrees for parallel execution. This directory is added to .gitignore by `/spectacular:init`.

## Usage

### Basic Workflow

```bash
# Generate a spec from concise natural language
/spectacular:spec "admin dashboard with real-time analytics"

# or be more conversational
/spectacular:spec now that weve added a bunch of features lets look and the opportunities for refactor. anything we can make more DRY? any component trees we can modularize? any bad state management? any other recommends? take a look and spec it out

# Review the generated spec from the newly created spec directory
cat specs/a1b2c3-refactor-components/spec.md

# Generate implementation plan
/spectacular:plan @specs/a1b2c3-refactor-components/spec.md

# Plan output shows:
# - Phase 1 (sequential): Extract shared utilities
# - Phase 2 (parallel): 3 component refactors run simultaneously
# - Phase 3 (sequential): Update tests
# - Estimated parallelization time savings

# Execute with automatic parallel orchestration
/spectacular:execute @specs/a1b2c3-refactor-components/plan.md

# Submit as stacked PRs
gs stack submit
```

### Working with Constitutions

Constitutions are immutable snapshots of architectural rules stored in `docs/constitutions/`:

**Setup:**

```bash
mkdir -p docs/constitutions/v1
# Create: architecture.md, patterns.md, tech-stack.md, schema-rules.md, testing.md
ln -s v1 docs/constitutions/current
```

**Updating your constitution (infrequently):**

Ask Claude to version the constitution when architectural rules change:

```
"We're adopting Zod for runtime validation. Update our constitution to
 add Zod to tech-stack.md and create a validation pattern in patterns.md."
```

Claude will create a new version directory (v2), copy all files, make the requested changes, and update the `current/` symlink.

**When to create a new version:**

- Adding/removing/relaxing a mandatory pattern
- Changing tech stack (e.g., Prisma → Drizzle)
- Updating architectural boundaries
- Major library version changes with breaking patterns

### Git-Spice Integration

Spectacular uses [git-spice](https://github.com/abhinav/git-spice) for stacked branch management:

**Key concepts:**

```
┌── task-3        ← upstack from task-2
├── task-2        ← upstack from task-1
├── task-1        ← first branch in stack
main (trunk)
```

**Common commands:**

```bash
# View your stack
gs log short

# Submit entire stack as PRs
gs stack submit

# Sync with remote, clean up merged branches
gs repo sync
```

**How Spectacular uses stacks:**

- Sequential tasks stack linearly: `task-1 → task-2 → task-3`
- Parallel tasks branch from same base, then stack for review in the main repo (e.g. outside the worktree)
- Each task = one branch = one reviewable PR

See the `using-git-spice` skill for detailed command reference and troubleshooting.

## Project Structure

After using Spectacular, your project will have:

```
your-project/
├── docs/constitutions/              # Optional: architectural rules
│   ├── current -> v2/               # Symlink to active version
│   ├── v1/                          # Historical versions
│   └── v2/                          # Current version
│       ├── meta.md                  # Version info + changelog
│       ├── architecture.md          # Layer boundaries
│       ├── patterns.md              # Mandatory patterns
│       ├── tech-stack.md            # Approved libraries
│       ├── schema-rules.md          # Database philosophy
│       └── testing.md               # Testing requirements
├── specs/
│   ├── a1b2c3-feature-name/
│   │   ├── spec.md                  # Feature specification
│   │   └── plan.md                  # Execution plan
│   └── d4e5f6-another-feature/
│       ├── spec.md
│       └── plan.md
├── .worktrees/                      # Temporary (gitignored)
│   ├── a1b2c3-task-1/               # Task workspaces for parallel execution
│   └── a1b2c3-task-2/
└── .gitignore                       # Configured by /spectacular:init
```

## Reference

### Commands

- `/spectacular:init` - Validate environment and dependencies
- `/spectacular:spec` - Generate feature specification
- `/spectacular:plan` - Create execution plan with dependency analysis
- `/spectacular:execute` - Execute plan with automatic parallelization

### Skills

- `decomposing-tasks` - Analyze specs and create execution plans
- `writing-specs` - Generate lean, architecture-focused specifications
- `versioning-constitutions` - Manage evolving architectural rules
- `using-git-spice` - Stacked branch management

### Documentation

- [Command Details](commands/README.md)
- [Skills Directory](skills/)
- [Superpowers](https://github.com/obra/superpowers)
- [Git-Spice](https://github.com/abhinav/git-spice)

## Contributing

Spectacular is designed to work with [superpowers](https://github.com/obra/superpowers). Consider contributing to both projects!

## License

MIT

## Author

Drew Ritter - [@arittr](https://github.com/arittr)

Built on [superpowers](https://github.com/obra/superpowers) by Jesse Vincent
