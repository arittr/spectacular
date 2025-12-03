# Spectacular

[![Install](https://img.shields.io/badge/install-arittr%2Fspectacular-5B3FFF?logo=claude)](https://github.com/arittr/spectacular#installation)
[![Version](https://img.shields.io/badge/dynamic/json?url=https://raw.githubusercontent.com/arittr/spectacular/main/.claude-plugin/plugin.json&label=version&query=$.version&color=orange)](https://github.com/arittr/spectacular/releases)
[![License](https://img.shields.io/badge/license-MIT-green)](LICENSE)

Spec-anchored development with automatic parallel execution for Claude Code.

Write a spec → generate a plan → execute tasks in parallel → get stacked PRs.

>[!NOTE]
>`/spectacular:execute` requires [git-spice](https://abhinav.github.io/git-spice/) for PR stacking. Support for Graphite coming soon!

Inspired and powered by [Superpowers](https://github.com/obra/superpowers).

## Why Spectacular

| Problem | Without | With Spectacular |
|---------|---------|------------------|
| **Context drift** | "What was that pattern?" → makes something up | Every task gets a fresh subagent with anchored context |
| **Sequential execution** | 40 min of serial tasks (even independent ones) | Parallel tasks in isolated worktrees |
| **Unmergeable PRs** | 47 files, +2,847 lines—nobody reviews this | Stacked PRs, one per task |
| **Pattern hallucination** | AI invents plausible-sounding patterns | Constitutions define the rules |

## Installation

**Prerequisites:**

```bash
# Install git-spice (macOS)
brew install git-spice
```

See [git-spice installation instructions](https://abhinav.github.io/git-spice/start/install/) for other platforms.

**Install plugins:**

```bash
# In Claude Code, install marketplaces and plugins
/plugin marketplace add obra/superpowers-marketplace
/plugin install superpowers@superpowers-marketplace
/plugin marketplace add arittr/spectacular
/plugin install spectacular@spectacular
```

**Initialize your project:**

```bash
/spectacular:init
```

## Quick Start

Real example from developing spectacular itself:

### 1. Generate a spec

```
/spectacular:spec I can't use my main repo while spectacular is running, it locks everything up. I want each run isolated in its own worktree so I can keep working manually and run multiple features concurrently.
```

<details>
<summary>Output: <a href="specs/dedf14-worktree-isolation/spec.md">specs/dedf14-worktree-isolation/spec.md</a></summary>

```markdown
# Feature: Worktree Isolation for Spectacular Runs

## Problem Statement
Spectacular commands operate directly in the main repository:
- Cannot perform manual work during a spectacular run
- Cannot run multiple sessions concurrently
- No isolation between spectacular work and manual work

## Requirements
- FR1: Worktree creation in spec command
- FR2: Plan command operates in worktree
- FR3: Execute command uses worktree as base
...

## Acceptance Criteria
- [ ] Worktree created immediately after RUN_ID generation
- [ ] Spec committed to worktree branch
- [ ] Main repo working directory unchanged
...
```

</details>

### 2. Create a plan

```
/spectacular:plan @specs/dedf14-worktree-isolation/spec.md
```

<details>
<summary>Output: <a href="specs/dedf14-worktree-isolation/plan.md">specs/dedf14-worktree-isolation/plan.md</a></summary>

```markdown
## Execution Summary

- **Total Tasks**: 3
- **Total Phases**: 1
- **Sequential Time**: 12h
- **Parallel Time**: 5h
- **Time Savings**: 7h (58%)

## Phase 1: Command Worktree Integration

**Strategy**: parallel
**Reason**: All tasks modify different command files

### Task 1: Spec Command Worktree Integration
Files: commands/spec.md
Complexity: M (4h)

### Task 2: Plan Command Worktree Integration
Files: commands/plan.md
Complexity: M (3h)

### Task 3: Execute Command Worktree Integration
Files: commands/execute.md
Complexity: L (5h)
```

</details>

### 3. Execute

```
/spectacular:execute @specs/dedf14-worktree-isolation/plan.md
```

**Time savings:** 58% faster—parallel execution runs tasks simultaneously instead of sequentially.

#### The Parallel Execution Flow

```
Orchestrator
|
|-- 1. Read plan, identify 3 parallel tasks
|-- 2. Create worktrees
|       dedf14-task-1/
|       dedf14-task-2/
|       dedf14-task-3/
|
|-- 3. Spawn subagents IN PARALLEL
|       |
|       +-- Subagent 1 (spec.md)      +-- Subagent 2 (plan.md)     +-- Subagent 3 (execute.md)
|       |   * Fresh spec context      |   * Fresh spec context     |   * Fresh spec context
|       |   * Implement, test         |   * Implement, test        |   * Implement, test
|       |   * Commit to branch        |   * Commit to branch       |   * Commit to branch
|       |                             |                            |
|       +-----------------------------+----------------------------+
|                                     |
|-- 4. Collect results, stack branches: task-1 -> task-2 -> task-3
|-- 5. Code review, cleanup worktrees
```

### 4. Submit

```
gs stack submit
```

**Result:** 3 focused PRs instead of one large diff.

```
┌── dedf14-task-3-execute-command
├── dedf14-task-2-plan-command
├── dedf14-task-1-spec-command
main
```

## Commands

### `/spectacular:init`

Validates environment and configures project:

- Checks superpowers and git-spice installed
- Verifies git repository
- Adds `.worktrees/` to `.gitignore`

### `/spectacular:spec <description>`

Generates feature specification from natural language.

```bash
/spectacular:spec "real-time chat with WebSocket and message history"
```

- Brainstorms requirements and architecture
- Asks clarifying questions and proposes solutions
- Reads constitutions (if they exist)
- Creates `specs/{runId}-{feature-slug}/spec.md`

### `/spectacular:plan @specs/{runId}-{feature}/spec.md`

Decomposes specification into executable plan.

- Breaks spec into concrete tasks with file paths
- Analyzes dependencies to find parallelization opportunities
- Groups tasks into sequential/parallel phases
- Creates `specs/{runId}-{feature}/plan.md`

### `/spectacular:execute @specs/{runId}-{feature}/plan.md`

Executes plan with automatic orchestration.

**Sequential phases:**

- Tasks run in shared worktree
- Each task creates a git-spice branch
- Branches stack linearly

**Parallel phases:**

- Each task gets isolated worktree
- Subagents run simultaneously
- Branches stacked after completion

**Quality gates after each phase:**

- Tests pass
- Linting passes
- Code review approves

## Project Setup

### Required: Setup Commands

Define in your project's `CLAUDE.md`:

```markdown
## Development Commands

### Setup

- **install**: `npm ci`
- **postinstall**: `npx prisma generate`

### Quality Checks

- **test**: `npm test`
- **lint**: `npm run lint`
- **build**: `npm run build`
```

Each worktree needs dependencies installed. Spectacular reads these commands and runs them automatically.

### Constitutions

Constitutions are immutable snapshots of your project's architectural rules. Specs reference them instead of duplicating rules—this prevents AI from hallucinating patterns.

```
docs/constitutions/
├── current → v2/           # Symlink to active version
├── v1/                     # Original architecture
│   ├── meta.md            # "Initial patterns, Feb 2024"
│   ├── architecture.md    # "3-layer: API, domain, data"
│   ├── patterns.md        # "All API routes use tRPC"
│   └── tech-stack.md      # "React, tRPC, Prisma"
└── v2/                     # Current architecture
    ├── meta.md            # "Migrated to Server Actions, Mar 2024"
    ├── architecture.md    # "Server/client components"
    ├── patterns.md        # "Server actions, no tRPC"
    └── tech-stack.md      # "Next.js 14, Server Actions, Prisma"
```

**Creating and versioning:**

Ask Claude to create or update your constitution—spectacular uses the `versioning-constitutions` skill:

```
"Create a constitution for this project based on the existing patterns"
"We're migrating from tRPC to server actions, update the constitution"
```

**Why constitutions matter:**

- **Prevents hallucination**: AI can't make up patterns—they're documented
- **Immutable history**: Old versions preserved when rules change
- **Explicit evolution**: Architecture changes are deliberate, not drift
- **Single source of truth**: Specs reference constitutions, not duplicate rules

## Troubleshooting

### Setup Commands Not Found

```
❌ Setup Commands Required
```

Add setup commands to your `CLAUDE.md`. See [Project Setup](#required-setup-commands).

### Worktree Creation Fails

```bash
# List and clean stale worktrees
git worktree list
git worktree prune

# Remove specific worktree
git worktree remove .worktrees/{runId}-task-1
```

### Git-Spice Stack Issues

```bash
# Check current stack
gs log short

# Restack if needed
gs repo sync
```

### Quality Checks Fail

Spectacular stops and reports the issue. Fix in the worktree:

```bash
cd .worktrees/{runId}-phase-{id}
# Fix the issue
git add . && git commit --amend --no-edit
```

### Resuming Interrupted Execution

If execution is interrupted, re-run the same command:

```bash
# Check current state
gs log short
git branch | grep {runId}

# Resume - spectacular detects completed phases and continues
/spectacular:execute @specs/{runId}-{feature}/plan.md
```

## When to Use

**Good for:**

- Complex features (>30 min, multiple independent pieces)
- Large refactors
- Migrations (REST→GraphQL, etc.)
- Projects with documented patterns

**Skip for:**

- Quick bug fixes (<10 min)
- Single-file changes
- Emergency hotfixes

**Rule of thumb:** If work can be split into 3+ independent tasks, spectacular saves time.

---

## Technical Deep Dive

<details>
<summary>Why spec anchoring prevents context drift</summary>

Traditional AI-assisted development degrades over long sessions:

```
Hour 1: System prompt + spec + task 1 code
Hour 2: System prompt + spec + tasks 1-2 code  ← Spec getting pushed out
Hour 3: System prompt + tasks 1-3 code          ← Spec gone
Hour 4: System prompt + recent code only        ← Making things up
```

Spectacular's solution: Fresh subagents with spec context.

Each task subagent starts with:

- Full specification (always present)
- Constitution rules (always present)
- This task's requirements
- Relevant code files

Every task starts with the same foundation. No degradation. No drift.

</details>

<details>
<summary>How automatic parallelization works</summary>

The planner analyzes file dependencies:

```
Task 1: "Add WebSocket server"
  Files: src/server/websocket.ts, src/server/index.ts

Task 2: "Create notification schema"
  Files: prisma/schema.prisma, src/db/types.ts

Task 3: "Build notification UI"
  Files: src/components/Notifications.tsx
```

Conflict matrix:

```
       T1    T2    T3
  T1   -     ✓     ✓
  T2   ✓     -     ✓
  T3   ✓     ✓     -
```

No conflicts → all parallel.

If Task 4 also modified `src/server/index.ts`, it would conflict with Task 1 and run sequentially after it.

</details>

<details>
<summary>Git worktree isolation</summary>

Parallel tasks run in completely isolated directories:

```
/project/
├── src/                    ← Main repo (untouched)
├── .git/
└── .worktrees/
    ├── abc123-task-1/      ← Task 1 worktree
    │   └── node_modules/   ← Separate dependencies
    ├── abc123-task-2/      ← Task 2 worktree
    │   └── node_modules/
    └── abc123-task-3/
        └── node_modules/
```

Each worktree is a full working directory. Changes in task-1 don't affect task-2. Tests and linting run independently.

</details>

<details>
<summary>Quality gates</summary>

After each phase, code review validates:

- All acceptance criteria met
- Constitution patterns followed
- No file conflicts
- Tests pass

Without quality gates:

```
Task 1: Bug introduced
Task 2: Builds on Task 1      ← bug persists
Task 3: Depends on Task 2     ← bug compounds
Task 4: Integration fails     ← hours wasted
```

With quality gates:

```
Task 1: Bug introduced        ← detected by review
  → Fix immediately
Task 2: Builds on fix         ← clean foundation
```

</details>

---

## Development

### Run tests

```bash
./tests/run-tests.sh --all
```

### Link for local development

```bash
make link       # Symlink into ~/.claude
make unlink     # Remove symlink
```

### Version bump

```bash
./scripts/update-version.sh 1.2.3
```

## Codex CLI

Codex support is in beta. See [.codex/INSTALL.md](.codex/INSTALL.md).

## Contributing

Built on [superpowers](https://github.com/obra/superpowers) - consider contributing to both.

## License

MIT

## Author

Drew Ritter - [@arittr](https://github.com/arittr)
