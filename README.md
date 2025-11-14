# Spectacular

[![Install](https://img.shields.io/badge/install-arittr%2Fspectacular-5B3FFF?logo=claude)](https://github.com/arittr/spectacular#installation--quick-start)
[![Version](https://img.shields.io/badge/dynamic/json?url=https://raw.githubusercontent.com/arittr/spectacular/main/.claude-plugin/plugin.json&label=version&query=$.version&color=orange)](https://github.com/arittr/spectacular/releases)
[![License](https://img.shields.io/badge/license-MIT-green)](LICENSE)

**Spec-anchored development with automatic parallel execution for Claude Code.**

Enable AI agents to implement complex features autonomously over multi-hour runs with correctness guarantees through spec anchoring and automatic quality gates.

Inspired and powered by [Superpowers](https://github.com/obra/superpowers).

> [!NOTE] >`/spectacular:execute` requires [git-spice](https://abhinav.github.io/git-spice/) for PR stacking. Support for Graphite coming soon!

## Table of Contents

- [The Problem](#the-problem)
- [The Solution](#the-solution)
- [How It Works](#how-it-works)
- [Technical Deep Dive](#technical-deep-dive)
- [Installation & Quick Start](#installation--quick-start)
- [Complete Workflow Example](#complete-workflow-example)
- [Command Reference](#command-reference)
- [Project Setup](#project-setup)
- [Best Practices](#best-practices)
- [Troubleshooting](#troubleshooting)

## The Problem

Traditional AI-assisted development hits a wall on complex features:

### 1. Context Drift Kills Correctness

```
Hour 1: "Follow the user auth pattern from auth.ts"
Hour 3: "What was that pattern again?" → makes up a new one
Hour 5: "Just getting this to work" → abandons best practices
```

Without an anchor point, long-running tasks drift from requirements and architectural patterns. The result: bugs, inconsistencies, and code that "works" but violates project standards.

### 2. Everything Runs Sequentially

```
Task 1: Update API endpoints       12 min
Task 2: Update database schema      8 min  ← Could run in parallel!
Task 3: Update UI components       15 min  ← Could run in parallel!
Task 4: Integration tests           5 min

Total: 40 minutes of serial execution
```

Even when tasks are independent (no file conflicts), they run one-at-a-time. The time to implement features scales linearly with complexity.

### 3. Massive Unmergeable PRs

```
PR #847: "Add user management feature"
  Files changed: 47
  Lines: +2,847 / -1,203

Nobody reviews this. It sits for weeks or gets rubber-stamped.
```

Large features become giant diffs that are impossible to review effectively.

### 4. Architectural Drift

Project patterns exist in documentation, code comments, and developer memory - but there's no single source of truth. AI tools either:

- Hallucinate patterns that sound plausible but don't match your codebase
- Copy whatever pattern they find first (even if it's outdated)
- Inconsistently apply patterns across different files

## The Solution

Spectacular solves these problems through **spec-anchored development** with **automatic parallelization**:

### Spec Anchoring: The Context Anchor

Every feature gets a comprehensive specification that serves as the unchanging anchor point for ALL implementation work:

```text
┌─────────────────────────────────────────────────────┐
│  Feature Specification (spec.md)                    │
│  ┌─────────────────────────────────────────────┐    │
│  │ Requirements                                │    │
│  │ Architecture decisions                      │    │
│  │ Acceptance criteria                         │    │
│  │ References to constitution rules            │    │
│  └─────────────────────────────────────────────┘    │
│                      ▼                              │
│            ┌──────────────────┐                     │
│            │ Implementation   │                     │
│            │ Plan (plan.md)   │                     │
│            └──────────────────┘                     │
│                      ▼                              │
│        ┌──────┬──────┬──────┬──────┐                │
│        │Task 1│Task 2│Task 3│Task 4│                │
│        └──────┴──────┴──────┴──────┘                │
│                                                     │
│  Every task references the SAME spec.               │
│  No context drift. No pattern hallucination.        │
└─────────────────────────────────────────────────────┘
```

**Why this enables long autonomous runs:**

1. **Agents get fresh context for each task** - Subagents start with the complete spec + constitution, not degraded context from hours of chat history
2. **Spec never changes during execution** - No moving target, no scope creep
3. **Automatic validation** - Code review agents verify implementation matches spec
4. **Quality gates prevent compounding drift** - Fix issues before proceeding to dependent tasks

### Automatic Parallelization: Time Compression

The planner analyzes your feature spec and automatically identifies which work can run in parallel:

```text
SEQUENTIAL (before):
┌─────────────────────────────────────────────────────┐
│ Task 1: API endpoints        12 min                 │
│ Task 2: Database schema       8 min                 │
│ Task 3: UI components        15 min                 │
│ Task 4: Integration tests     5 min                 │
└─────────────────────────────────────────────────────┘
Total: 40 minutes

PARALLEL (automatic):
┌─────────────────────────────────────────────────────┐
│ Phase 1 (sequential):                               │
│   Task 1: API endpoints      12 min                 │
│                                                     │
│ Phase 2 (parallel):          ┌──────────────────┐   │
│   Task 2: DB schema          │ 8min             │   │
│   Task 3: UI components      │ 15min            │   │
│                              └──────────────────┘   │
│ Phase 3 (sequential):                               │
│   Task 4: Integration         5 min                 │
└─────────────────────────────────────────────────────┘
Total: 32 minutes (20% faster)
```

**How it works:**

1. **Dependency analysis**: Planner checks which files each task modifies
2. **Conflict detection**: Tasks touching the same files run sequentially
3. **Worktree isolation**: Parallel tasks run in separate git worktrees
4. **Automatic orchestration**: No manual coordination needed

### Constitution Versioning: Immutable Architectural Truth

Constitutions are versioned snapshots of your project's architectural rules:

```
docs/constitutions/
├── current → v2/           # Symlink to active version
├── v1/                     # Original architecture
│   ├── meta.md            # "Initial patterns, Feb 2024"
│   ├── architecture.md    # "3-layer: API, domain, data"
│   ├── patterns.md        # "All API routes use tRPC"
│   └── tech-stack.md      # "React, tRPC, Prisma"
└── v2/                     # Current architecture
    ├── meta.md            # "Migrated to Next.js Server Actions, Mar 2024"
    ├── architecture.md    # "Server/client components"
    ├── patterns.md        # "Server actions, no tRPC"
    └── tech-stack.md      # "Next.js 14, Server Actions, Prisma"
```

**Why this matters:**

- **Prevents hallucination**: AI can't make up patterns - they're documented
- **Immutable history**: Old versions preserved when rules change
- **Explicit evolution**: Architecture changes are deliberate, not drift
- **Single source of truth**: Specs reference constitutions, not duplicate rules

## How It Works

### Workflow Diagram

```text
┌─────────────────────────────────────────────────────────────────┐
│                    USER DESCRIBES FEATURE                       │
│        "Add real-time notifications with WebSocket"             │
└───────────────────────────┬─────────────────────────────────────┘
                            ▼
                    ┌───────────────┐
                    │ /spec command │
                    └───────┬───────┘
                            ▼
        ┌───────────────────────────────────────┐
        │   SPECIFICATION GENERATION            │
        │                                       │
        │  1. Brainstorm (understanding,        │
        │     exploration, design)              │
        │  2. Read constitutions/current/       │
        │  3. Analyze codebase patterns         │
        │  4. Generate spec.md with:            │
        │     - Requirements                    │
        │     - Architecture decisions          │
        │     - Acceptance criteria             │
        │     - Constitution references         │
        │                                       │
        │  Output: specs/{id}-{name}/spec.md    │
        └───────────────┬───────────────────────┘
                        ▼
                ┌───────────────┐
                │ /plan command │
                └───────┬───────┘
                        ▼
        ┌───────────────────────────────────────┐
        │   TASK DECOMPOSITION                  │
        │                                       │
        │  1. Break spec into tasks             │
        │  2. Extract file dependencies         │
        │  3. Identify conflicts                │
        │  4. Group into phases:                │
        │     • Sequential (shared files)       │
        │     • Parallel (independent files)    │
        │  5. Calculate time savings            │
        │                                       │
        │  Output: specs/{id}-{name}/plan.md    │
        └───────────────┬───────────────────────┘
                        ▼
              ┌────────────────────┐
              │ /execute command   │
              └──────────┬─────────┘
                         ▼
        ┌────────────────────────────────────────┐
        │   EXECUTION ORCHESTRATION              │
        │                                        │
        │  For each phase:                       │
        │                                        │
        │  ┌──────────────────────────────────┐  │
        │  │ SEQUENTIAL PHASE                 │  │
        │  │ • Create shared worktree         │  │
        │  │ • Install dependencies           │  │
        │  │ • Run tasks in order             │  │
        │  │   Each task:                     │  │
        │  │   - Subagent with spec context   │  │
        │  │   - Implement changes            │  │
        │  │   - Run quality checks           │  │
        │  │   - Create git-spice branch      │  │
        │  │ • Stack branches                 │  │
        │  │ • Code review                    │  │
        │  └──────────────────────────────────┘  │
        │                                        │
        │  ┌──────────────────────────────────┐  │
        │  │ PARALLEL PHASE                   │  │
        │  │ • Create worktree per task       │  │
        │  │ • Install dependencies (each)    │  │
        │  │ • Spawn subagents simultaneously │  │
        │  │   Each subagent:                 │  │
        │  │   - Fresh spec context           │  │
        │  │   - Isolated worktree            │  │
        │  │   - Independent execution        │  │
        │  │   - Quality checks               │  │
        │  │   - Git-spice branch + detach    │  │
        │  │ • Stack branches linearly        │  │
        │  │ • Code review                    │  │
        │  └──────────────────────────────────┘  │
        │                                        │
        │  Quality Gates (after each phase):     │
        │  ✓ Tests pass                          │
        │  ✓ Linting passes                      │
        │  ✓ Code review approves                │
        │  ✓ Spec requirements met               │
        │  ✓ Constitution compliance             │
        └────────────────┬───────────────────────┘
                         ▼
             ┌────────────────────────┐
             │  STACKED PULL REQUESTS │
             └───────────┬────────────┘
                         ▼
        ┌────────────────────────────────────────┐
        │   GIT-SPICE STACK                      │
        │                                        │
        │   main                                 │
        │    ├─ task-1-api-endpoints             │
        │    ├─ task-2-websocket-setup           │
        │    ├─ task-3-ui-notifications          │
        │    └─ task-4-integration-tests         │
        │                                        │
        │   gs stack submit → 4 reviewable PRs   │
        └────────────────────────────────────────┘
```

## Technical Deep Dive

### Why Spec Anchoring Prevents Context Drift

Traditional approaches struggle with long-running tasks because:

**Problem: Chat-based context degrades over time**

```
Token Budget: [████████████████████░░░░░░░░] 200k tokens
               ↑ early context      ↑ recent context

Hour 1: System prompt + spec + task 1 code
Hour 2: System prompt + spec + tasks 1-2 code  ← Spec getting pushed out
Hour 3: System prompt + tasks 1-3 code          ← Spec gone, using degraded memory
Hour 4: System prompt + recent code only        ← No anchor, making things up
```

**Spectacular's solution: Fresh subagents with spec context**

```
Each Task Subagent:
┌────────────────────────────────────────┐
│ Context:                               │
│ • Full specification (always present)  │
│ • Constitution rules (always present)  │
│ • This task's requirements             │
│ • Relevant code files                  │
│                                        │
│ NOT included:                          │
│ • Previous task implementations        │
│ • Orchestrator's conversation history  │
│ • Other tasks' context                 │
└────────────────────────────────────────┘

Every task starts with the same foundation.
No degradation. No drift.
```

**Why this enables correctness:**

1. **Consistent context**: Task 1 and Task 20 see the exact same specification
2. **No accumulation**: Implementation details from previous tasks don't pollute context
3. **Validation anchor**: Code review compares against the unchanging spec
4. **Architecture compliance**: Constitution always in context, patterns always followed

### Orchestration Architecture: Cognitive Load Reduction

Spectacular uses an orchestrator-with-embedded-instructions architecture to minimize cognitive overhead for task subagents:

**Traditional monolithic approach:**

```text
┌─────────────────────────────────────────────┐
│ Single 750-line skill file                  │
│ ┌─────────────────────────────────────────┐ │
│ │ Setup logic (200 lines)                 │ │
│ │ Dispatch coordination (150 lines)       │ │
│ │ Task execution instructions (200 lines) │ │ ← Subagent needs this
│ │ Verification logic (100 lines)          │ │
│ │ Code review orchestration (100 lines)   │ │
│ └─────────────────────────────────────────┘ │
│                                             │
│ Subagent must parse all 750 lines           │
│ to find the ~200 lines of task instructions │
└─────────────────────────────────────────────┘
```

**Spectacular's layered approach:**

```text
┌─────────────────────────────────────────────┐
│ Orchestrator Skill (464-850 lines)          │
│ ┌─────────────────────────────────────────┐ │
│ │ Setup logic                             │ │
│ │ Dispatch coordination                   │ │
│ │ Code review orchestration               │ │
│ └─────────────────────────────────────────┘ │
│           ↓ Dispatches Task tool            │
│ ┌─────────────────────────────────────────┐ │
│ │ Embedded Instructions (~150 lines)      │ │ ← Subagent receives only this
│ │ • Phase boundaries                      │ │
│ │ • Spec reading                          │ │
│ │ • Implementation steps                  │ │
│ │ • Quality checks                        │ │
│ │ • Calls: Skill(phase-task-verification) │ │
│ └─────────────────────────────────────────┘ │
└─────────────────────────────────────────────┘

┌─────────────────────────────────────────────┐
│ Verification Skill (92 lines)               │
│ • Git operations (add, branch, verify)      │
│ • Shared by sequential + parallel           │
│ • Called by subagents via Skill tool        │
└─────────────────────────────────────────────┘
```

**Benefits:**

1. **80% cognitive load reduction**: Subagents parse ~150 lines instead of 750
2. **Focus**: Task instructions separated from orchestration complexity
3. **Maintainability**: Can improve orchestration without affecting task execution
4. **DRY**: Shared verification skill eliminates duplication

**How it works:**

- Orchestrators (`executing-sequential-phase`, `executing-parallel-phase`) manage workflow lifecycle
- Task tool dispatched with embedded execution instructions (~150 lines)
- Subagent receives focused context: phase boundaries, spec, implementation steps
- Subagent calls `phase-task-verification` skill for branch creation
- Orchestrator handles code review, stacking, cleanup

This architecture enables subagents to focus on implementation without drowning in orchestration logic.

### How Automatic Parallelization Works

#### File Dependency Analysis

The planner analyzes each task's file dependencies to build a conflict matrix:

```
Task Decomposition Example:

Task 1: "Add WebSocket server"
  Files: src/server/websocket.ts (new), src/server/index.ts (modify)

Task 2: "Create notification database schema"
  Files: prisma/schema.prisma (modify), src/db/types.ts (new)

Task 3: "Build notification UI component"
  Files: src/components/Notifications.tsx (new), src/components/Layout.tsx (modify)

Task 4: "Add integration tests"
  Files: src/server/index.ts (modify), tests/notifications.test.ts (new)


Conflict Matrix:
         T1    T2    T3    T4
    T1   -     ✓     ✓     ✗   (conflicts with T4: both modify server/index.ts)
    T2   ✓     -     ✓     ✓
    T3   ✓     ✓     -     ✓
    T4   ✗     ✓     ✓     -


Phase Grouping:
  Phase 1 (sequential): Task 1 (must go first)
  Phase 2 (parallel):   Tasks 2, 3 (independent, can run together)
  Phase 3 (sequential): Task 4 (depends on T1's changes)
```

#### Git Worktree Isolation

Parallel tasks run in completely isolated directories:

```
Main Repository:
/Users/you/project/
├── src/
├── .git/

During Parallel Execution:
/Users/you/project/
├── src/                    ← Main repo (untouched)
├── .git/
└── .worktrees/
    ├── abc123-main/        ← Feature worktree (setup, planning)
    ├── abc123-task-2/      ← Task 2: DB schema changes
    │   ├── src/
    │   ├── prisma/schema.prisma  ← Different from main!
    │   └── node_modules/   ← Separate installation
    └── abc123-task-3/      ← Task 3: UI component
        ├── src/
        ├── src/components/Notifications.tsx  ← Different from main!
        └── node_modules/   ← Separate installation

Each worktree is a full working directory.
Changes in task-2 don't affect task-3.
Both can run npm/bun install, tests, linting independently.
```

**Why worktrees instead of branches?**

| Approach            | Pros                          | Cons                                    |
| ------------------- | ----------------------------- | --------------------------------------- |
| **Switch branches** | Simple                        | Can't run in parallel (one working dir) |
| **Clone repo 3x**   | Parallel execution            | Slow, disk-intensive, complex           |
| **Git worktrees**   | Parallel + fast + shared .git | Perfect for this use case               |

#### The Parallel Execution Flow

```text
Orchestrator (main process):
  ┌─────────────────────────────────────────────────┐
  │ 1. Read plan                                    │
  │ 2. Identify Phase 2 has tasks 2, 3 (parallel)   │
  │ 3. Create worktrees:                            │
  │    • .worktrees/abc123-task-2                   │
  │    • .worktrees/abc123-task-3                   │
  │ 4. Install dependencies in each                 │
  │ 5. Spawn subagents IN PARALLEL:                 │
  └─────────────┬───────────────────────────────────┘
                ├──────────────┬──────────────────┐
                ▼              ▼                  ▼
       ┌─────────────┐  ┌─────────────┐  ┌─────────────┐
       │ Subagent 2  │  │ Subagent 3  │  │ (more...)   │
       ├─────────────┤  ├─────────────┤  ├─────────────┤
       │ Context:    │  │ Context:    │  │ Context:    │
       │ • Spec      │  │ • Spec      │  │ • Spec      │
       │ • Task 2    │  │ • Task 3    │  │ • Task N    │
       │ • Worktree: │  │ • Worktree: │  │ • Worktree: │
       │   task-2/   │  │   task-3/   │  │   task-N/   │
       ├─────────────┤  ├─────────────┤  ├─────────────┤
       │ Work:       │  │ Work:       │  │ Work:       │
       │ 1. Modify   │  │ 1. Modify   │  │ 1. Modify   │
       │ 2. Test     │  │ 2. Test     │  │ 2. Test     │
       │ 3. Commit   │  │ 3. Commit   │  │ 3. Commit   │
       │ 4. Detach   │  │ 4. Detach   │  │ 4. Detach   │
       └──────┬──────┘  └──────┬──────┘  └──────┬──────┘
              │                │                │
              └────────────────┴────────────────┘
                               ▼
                    Orchestrator collects results
                    Stacks branches: task-2 → task-3
                    Cleans up worktrees
```

**Time savings calculation:**

Sequential: `sum(all task times)`
Parallel: `max(task times per phase) for each phase`

Real example:

- Sequential: 12m + 8m + 15m + 5m = 40m
- Parallel: 12m + max(8m, 15m) + 5m = 32m
- **Savings: 8 minutes (20% faster)**

With 10 independent tasks, savings can exceed 50%.

### Quality Gates: Preventing Compounding Errors

After each phase, automatic code review validates:

```
Code Review Subagent:
┌─────────────────────────────────────────────────┐
│ Inputs:                                         │
│ • Feature specification                         │
│ • Constitution rules                            │
│ • This phase's git branches                     │
│                                                 │
│ Checks:                                         │
│ ✓ All acceptance criteria met                   │
│ ✓ Constitution patterns followed                │
│ ✓ No file conflicts (parallel tasks)            │
│ ✓ Tests pass                                    │
│ ✓ Code quality standards                        │
│                                                 │
│ Output:                                         │
│ • APPROVED → Continue to next phase             │
│ • ISSUES FOUND → Fix before proceeding          │
└─────────────────────────────────────────────────┘
```

**Why this matters for long runs:**

Without quality gates:

```
Task 1: Minor bug introduced          [small problem]
Task 2: Builds on Task 1              [bug persists]
Task 3: Depends on Task 2             [bug compounds]
Task 4: Integration fails             [3 hours wasted]
```

With quality gates:

```
Task 1: Minor bug introduced          [detected by review]
  → Fix immediately (5 min)           [problem solved]
Task 2: Builds on corrected Task 1    [clean foundation]
Task 3: Continues cleanly             [no issues]
Task 4: Integration succeeds          [feature complete]
```

## When to Use Spectacular

### Perfect For

- ✅ **Complex features** - Work taking >30 minutes with multiple independent pieces
- ✅ **Exploratory/prototyping work** - Spec anchoring keeps exploration focused and traceable
- ✅ **Large refactors** - Break monoliths into parallel tasks with clear acceptance criteria
- ✅ **Migrations** - REST→GraphQL, Prisma→Drizzle, etc. with automatic task orchestration
- ✅ **Projects with documented patterns** - Constitutions prevent AI from hallucinating architecture

### Skip It For

- ❌ **Quick bug fixes** - <10 minute changes don't benefit from the overhead
- ❌ **Single-file changes** - No parallelization opportunity, spec is overkill
- ❌ **Emergency hotfixes** - When speed matters more than process
- ❌ **Poorly-defined requirements** - Run `/spectacular:spec` first to clarify, then execute

**Rule of thumb:** If the work can be decomposed into 3+ independent tasks, spectacular will save significant time.

## Installation & Quick Start

### 1. Install Prerequisites

```bash
# In Claude Code, install plugins
/plugin marketplace add obra/superpowers-marketplace
/plugin install superpowers@superpowers-marketplace
/plugin marketplace add arittr/spectacular
/plugin install spectacular@spectacular

# Install git-spice (macOS)
brew install git-spice

# Or on Linux
curl -fsSL https://abhinav.github.io/git-spice/install.sh | sh
```

### 2. Initialize Your Project

```bash
# In your project directory
/spectacular:init
```

This validates dependencies and configures git-spice.

### 3. Try It Out

Generate a spec:

```bash
/spectacular:spec "user authentication with magic links and session management"
```

**What happens:**

- Brainstorms requirements and architecture
- Reads your constitutions (if they exist)
- Analyzes codebase patterns
- Generates `specs/abc123-user-auth/spec.md`
- Commits to isolated worktree branch

**Output example:**

```markdown
# User Authentication with Magic Links

## Requirements

- Passwordless authentication via email magic links
- Session management with secure cookies
- Email service integration
  ...

## Architecture

Following constitution v2 patterns:

- Next.js Server Actions for auth endpoints
- Prisma for user/session storage
- Edge-compatible session validation
  ...

## Acceptance Criteria

- [ ] User can request magic link via email
- [ ] Link expires after 10 minutes
- [ ] Session persists across browser restarts
      ...
```

Create a plan:

```bash
/spectacular:plan @specs/abc123-user-auth/spec.md
```

Execute it:

```bash
/spectacular:execute @specs/abc123-user-auth/plan.md
```

**Result:** Stack of focused, reviewable PRs ready to submit with `gs stack submit`.

### About Time Estimates

The time estimates shown throughout this README (12 min, 36 min, etc.) assume:

- ✅ Codebase with clear patterns and constitutions
- ✅ Well-defined requirements in spec
- ✅ Tasks properly scoped (M-sized, 10-15 min each)
- ✅ Minimal debugging and iteration needed

**In practice, budget 1.5-2x these estimates:**

- First features take longer (agents learning your constitution)
- Complex integrations add overhead
- Quality check failures require rework
- Exploratory work needs iteration

Real-world example: A 40-minute estimate becomes 60-80 minutes actual, but still faster than 120+ minutes sequential.

## Platform Support

Spectacular is available for both **Claude Code** and **Codex CLI**.

### Claude Code (Primary Platform)

Install via the plugin marketplace:

```bash
/plugin marketplace add arittr/spectacular
/plugin install spectacular@spectacular
```

Use slash commands:

- `/spectacular:spec` - Generate specification
- `/spectacular:plan` - Create execution plan
- `/spectacular:execute` - Run with parallel orchestration
- `/spectacular:init` - Initialize project

See [Installation & Quick Start](#installation--quick-start) for full setup.

### Codex CLI (Experimental)

Spectacular is available for Codex but requires manual setup.

**Manual Setup:**

See [.codex/INSTALL.md](.codex/INSTALL.md) for detailed instructions.

**Usage:**

In Codex, spectacular commands and skills are loaded automatically at session start. Instead of slash commands, use natural language:

```
# Generate specification
"I need a spec for user authentication with magic links"

# Create plan
"Create an implementation plan from specs/abc123-user-auth/spec.md"

# Execute plan
"Execute the plan at specs/abc123-user-auth/plan.md"
```

Codex will use spectacular skills to guide the workflow.

**Key Differences:**

| Feature         | Claude Code                       | Codex CLI                   |
| --------------- | --------------------------------- | --------------------------- |
| **Commands**    | Slash commands (`/spectacular:*`) | Natural language            |
| **Skills**      | Automatic loading                 | Via CLI tool                |
| **Subagents**   | Task tool                         | TBD (manual or MCP wrapper) |
| **Integration** | Plugin system                     | AGENTS.md + CLI script      |

**Codex Limitations:**

- **Parallel execution** may require manual worktree management or future MCP wrapper
- **Subagent dispatch** not yet automated (skills document methodology to follow manually)
- **Quality gates** work but may need manual test execution

**Full Codex documentation:** See [.codex/INSTALL.md](.codex/INSTALL.md)

### Which Should I Use?

- **Claude Code**: Full automation, parallel execution, subagent orchestration
- **Codex CLI**: Access to spectacular methodology, manual adaptation required

**Recommendation:** Use Claude Code for production workflows. Use Codex for learning the methodology or when Claude Code isn't available.

## Complete Workflow Example

### Scenario: Refactoring a Monolith API

**Problem**: You have 800 lines of API routes in one file that need to be split into domain modules.

#### Step 1: Describe the Refactor

```bash
/spectacular:spec "refactor src/api/routes.ts into domain modules: user, product, order - following clean architecture with separate route/controller/service layers"
```

Spectacular:

- Analyzes the existing `routes.ts` file
- Reads your constitution's architecture patterns
- Generates a spec with:
  - Domain boundaries (User, Product, Order)
  - Layer separation (routes → controllers → services)
  - Migration strategy (keep old routes working during refactor)

**Generated spec** (excerpt):

```markdown
# API Refactoring: Domain Modules

## Current State

- src/api/routes.ts (800 lines, mixed concerns)
- All business logic in route handlers
- No separation of concerns

## Target Architecture

Following constitution v3 clean architecture:
```

src/api/
├── user/
│ ├── routes.ts (Express routing)
│ ├── controller.ts (Request/response handling)
│ └── service.ts (Business logic)
├── product/
│ ├── routes.ts
│ ├── controller.ts
│ └── service.ts
└── order/
├── routes.ts
├── controller.ts
└── service.ts

```

## Acceptance Criteria
- [ ] All existing routes still work (no breaking changes)
- [ ] Business logic extracted to service layer
- [ ] Controllers handle only request/response transformation
- [ ] Test coverage maintained
...
```

#### Step 2: Generate the Plan

```bash
/spectacular:plan @specs/a1b2c3-api-refactor/spec.md
```

**Generated plan**:

```markdown
# Implementation Plan

## Phase 1 (Parallel) - Extract Domain Services

**Reason**: No file conflicts - creating new files

### Task 1.1: User Service Layer

Files:

- src/api/user/service.ts (new)
- src/api/user/types.ts (new)
  Acceptance: All user business logic extracted

### Task 1.2: Product Service Layer

Files:

- src/api/product/service.ts (new)
- src/api/product/types.ts (new)

### Task 1.3: Order Service Layer

Files:

- src/api/order/service.ts (new)
- src/api/order/types.ts (new)

**Time estimate**: 3 tasks × 10 min = 30 min sequential
**Parallel execution**: max(10, 10, 10) = 10 min
**Savings**: 20 minutes

## Phase 2 (Parallel) - Create Controllers

**Reason**: Independent - new files, different domains

### Task 2.1: User Controller

Files:

- src/api/user/controller.ts (new)

### Task 2.2: Product Controller

Files:

- src/api/product/controller.ts (new)

### Task 2.3: Order Controller

Files:

- src/api/order/controller.ts (new)

**Savings**: 16 minutes

## Phase 3 (Parallel) - Create Route Modules

**Reason**: Independent - new files

### Task 3.1-3.3: Route modules...

**Savings**: 16 minutes

## Phase 4 (Sequential) - Integration

**Reason**: Modifies shared index file

### Task 4.1: Update API Index

Files:

- src/api/index.ts (modify)
- src/api/routes.ts (deprecate)

### Task 4.2: Integration Tests

Files:

- tests/api/integration.test.ts

**Total estimated time**:

- Sequential: 88 minutes
- Parallel: 36 minutes
- **Savings: 52 minutes (59% faster)**
```

#### Step 3: Execute

```bash
/spectacular:execute @specs/a1b2c3-api-refactor/plan.md
```

**What actually happens**:

```
[11:00 AM] Phase 1: Extract Domain Services (parallel)
          Creating 3 worktrees...
          Installing dependencies in each...
          Spawning 3 subagents...

[11:03 AM] Subagent 1 (User Service):
          ✓ Extracted 15 user functions to service.ts
          ✓ Created UserService class
          ✓ Unit tests passing
          ✓ Branch: a1b2c3-task-1-1-user-service

[11:07 AM] Subagent 2 (Product Service):
          ✓ Extracted 12 product functions
          ✓ ProductService with inventory methods
          ✓ Unit tests passing
          ✓ Branch: a1b2c3-task-1-2-product-service

[11:10 AM] Subagent 3 (Order Service):
          ✓ Extracted 18 order functions
          ✓ OrderService with payment integration
          ✓ Unit tests passing
          ✓ Branch: a1b2c3-task-1-3-order-service

[11:10 AM] Phase 1 complete (10 min)
          Code review: ✓ APPROVED
          All services follow clean architecture
          No business logic in controllers
          Test coverage: 94%

[11:10 AM] Phase 2: Create Controllers (parallel)
          ...

[11:36 AM] ✅ Refactor complete
          Total time: 36 minutes
          Would have taken: 88 minutes sequentially
          Saved: 52 minutes

          Created 11 branches in stack
          Next step: gs stack submit
```

#### Step 4: Review and Submit

```bash
# View the stack
gs log short

# Result:
┌── a1b2c3-task-4-2-integration-tests
├── a1b2c3-task-4-1-api-index
├── a1b2c3-task-3-3-order-routes
├── a1b2c3-task-3-2-product-routes
├── a1b2c3-task-3-1-user-routes
├── a1b2c3-task-2-3-order-controller
├── a1b2c3-task-2-2-product-controller
├── a1b2c3-task-2-1-user-controller
├── a1b2c3-task-1-3-order-service
├── a1b2c3-task-1-2-product-service
├── a1b2c3-task-1-1-user-service
main

# Submit as stacked PRs
gs stack submit
```

**Result**: 11 small, reviewable PRs instead of one 800-line monster.

## Command Reference

### `/spectacular:init`

**Purpose**: Validate environment and configure project

**Usage**:

```bash
/spectacular:init
```

**What it does**:

- ✓ Checks superpowers plugin installed
- ✓ Checks git-spice installed
- ✓ Verifies git repository
- ✓ Adds `.worktrees/` to `.gitignore`
- ✓ Configures git-spice tracking
- ✓ Validates directory structure

**When to run**:

- First time using spectacular in a project
- After installing spectacular
- When setting up a new repository

---

### `/spectacular:spec`

**Purpose**: Generate feature specification from natural language

**Usage**:

```bash
/spectacular:spec "feature description"

# Examples:
/spectacular:spec "real-time chat with WebSocket and message history"
/spectacular:spec "migrate from REST to GraphQL API"
/spectacular:spec "refactor auth to use OAuth 2.0"
```

**What it does**:

1. Brainstorms requirements (understanding, exploration, design)
2. Reads `docs/constitutions/current/` if exists
3. Analyzes codebase for existing patterns
4. Generates comprehensive spec with:
   - Requirements and user stories
   - Architecture decisions
   - File locations and structure
   - Acceptance criteria
   - Constitution references (not duplication)
5. Creates isolated worktree at `.worktrees/{runId}-main/`
6. Saves spec to `specs/{runId}-{feature-slug}/spec.md`
7. Commits to `{runId}-main` branch

**Output**:

- Spec file path
- Run ID (6-char hash for namespacing)
- Next step: `/spectacular:plan`

**Options**:

- Natural language descriptions work best
- Be specific about technical requirements
- Mention existing patterns to follow

**Pro tips**:

- Front-load context: "Following our tRPC pattern, add..."
- Reference files: "Like auth.ts, but for products"
- Specify constraints: "Must work without breaking existing API"

---

### `/spectacular:plan`

**Purpose**: Decompose specification into executable plan with automatic dependency analysis

**Usage**:

```bash
/spectacular:plan @specs/{runId}-{feature}/spec.md

# Example:
/spectacular:plan @specs/a1b2c3-real-time-chat/spec.md
```

**What it does**:

1. Reads specification
2. Decomposes into concrete tasks with:
   - Exact file paths (no wildcards)
   - Acceptance criteria per task
   - Dependencies between tasks
3. Analyzes file dependencies:
   - Tasks touching same files → sequential
   - Independent files → parallel
4. Groups tasks into phases:
   - Sequential phases (shared file conflicts)
   - Parallel phases (independent work)
5. Calculates time estimates and savings
6. Generates `specs/{runId}-{feature}/plan.md`
7. Commits to worktree branch

**Output**:

```markdown
## Phase 1 (Sequential) - Foundation

### Task 1.1: Database Schema

Files: prisma/schema.prisma, src/db/types.ts
Acceptance: Message and Room models created

## Phase 2 (Parallel) - Independent Features

### Task 2.1: WebSocket Server

Files: src/server/websocket.ts, src/server/index.ts

### Task 2.2: Message UI Component

Files: src/components/Chat.tsx, src/components/MessageList.tsx

### Task 2.3: Room Management

Files: src/lib/rooms.ts, src/hooks/useRoom.ts

Time savings: 45 minutes (35% faster)
```

**Quality rules enforced**:

- No XL tasks (>8 hours) - must split
- All tasks have explicit file paths
- All tasks have acceptance criteria
- Dependencies are validated (no circular deps)

---

### `/spectacular:execute`

**Purpose**: Execute implementation plan with automatic orchestration

**Usage**:

```bash
/spectacular:execute @specs/{runId}-{feature}/plan.md

# Example:
/spectacular:execute @specs/a1b2c3-real-time-chat/plan.md

# Best practice: Run with bypass permissions for long autonomous execution
# Use --permission-mode bypassPermissions flag if available
```

**What it does**:

For each phase in the plan:

**Sequential Phase**:

1. Create shared worktree: `.worktrees/{runId}-phase-{id}`
2. Check CLAUDE.md for setup commands
3. Install dependencies + run postinstall (codegen)
4. For each task sequentially:
   - Spawn subagent with spec + constitution context
   - Subagent implements task in shared worktree
   - Run quality checks (test, lint, build from CLAUDE.md)
   - Create git-spice stacked branch
   - Stay on branch (next task builds on it)
5. Stack branches via git-spice
6. Code review validates against spec
7. Clean up worktree

**Parallel Phase**:

1. Create worktree per task: `.worktrees/{runId}-task-{id}`
2. Install dependencies in EACH worktree
3. Spawn subagents simultaneously (one per task)
   - Each gets fresh spec + constitution context
   - Each works in isolated worktree
   - No file conflicts possible
4. Each subagent:
   - Implements task
   - Runs quality checks
   - Creates git-spice branch
   - Detaches HEAD (makes branch accessible)
5. Stack branches linearly
6. Code review
7. Clean up all worktrees

**Quality gates** (after each phase):

- ✓ All tests pass
- ✓ Linting passes
- ✓ Build succeeds
- ✓ Code review approves
- ✓ Spec acceptance criteria met
- ✓ Constitution compliance verified

**Error handling**:

- Task fails → Fix in place, re-run from that task
- Review fails → Address feedback, re-review
- Quality check fails → Fix, re-run checks

**Output**:

- Progress updates per phase/task
- Branch names created
- Time saved via parallelization
- Code review results
- Next step: `gs stack submit`

**Requirements**:

- Project must define setup commands in CLAUDE.md:

  ```markdown
  ## Development Commands

  ### Setup

  - **install**: `bun install`
  - **postinstall**: `npx prisma generate`

  ### Quality Checks

  - **test**: `bun test`
  - **lint**: `bun run lint`
  - **build**: `bun run build`
  ```

**Pro tips**:

- Use `--permission-mode bypassPermissions` for uninterrupted execution
- Monitor first phase to ensure setup commands work
- Resume from any phase if interrupted
- Check `gs log short` frequently to see stack structure

See also in-repo command docs for deeper details: `commands/init.md`, `commands/spec.md`, `commands/plan.md`, `commands/execute.md`.

## Project Setup

### Required: Setup Commands

Every project using spectacular MUST define setup commands in `CLAUDE.md`:

```markdown
## Development Commands

### Setup

- **install**: `bun install`
- **postinstall**: `npx prisma generate`

### Quality Checks

- **test**: `bun test`
- **lint**: `bun run lint`
- **format**: `bun run format`
- **build**: `bun run build`
```

**Why required**:

- Each worktree is an isolated directory
- Worktrees need dependencies installed
- Codegen (Prisma, GraphQL, etc.) must run
- Quality checks need working dependencies

**Setup logic**:

- Checks if `node_modules` exists
- If missing → runs `install`, then `postinstall`
- If exists → skips (handles resume scenarios)

**When setup runs**:

- After creating main worktree (`/spectacular:spec`)
- Before tasks in sequential phases
- Before each task in parallel phases

### Examples: Minimal CLAUDE.md templates

Copy one of these minimal templates into your project's `CLAUDE.md` and adjust commands to your toolchain.

Node/TypeScript (npm):

```markdown
## Development Commands

### Setup

- **install**: `npm ci`
- **postinstall**: `true`

### Quality Checks

- **test**: `npm test --silent`
- **lint**: `npm run lint --silent || true`
- **format**: `npm run format --silent || true`
- **build**: `npm run build --silent || true`
```

Python (pytest/ruff/black):

```markdown
## Development Commands

### Setup

- **install**: `python -m pip install -r requirements.txt`
- **postinstall**: `true`

### Quality Checks

- **test**: `pytest -q`
- **lint**: `ruff check . || true`
- **format**: `black --check . || true`
- **build**: `true`
```

### Optional: Constitutions

Constitutions provide versioned architectural rules:

```bash
# Create initial constitution
mkdir -p docs/constitutions/v1

# Create rule files
touch docs/constitutions/v1/meta.md
touch docs/constitutions/v1/architecture.md
touch docs/constitutions/v1/patterns.md
touch docs/constitutions/v1/tech-stack.md
touch docs/constitutions/v1/testing.md

# Make active
ln -s v1 docs/constitutions/current
```

**Constitution files**:

`meta.md`:

```markdown
# Constitution v1

**Created**: 2024-03-15
**Status**: Active

## Changes in This Version

- Initial patterns established
- Clean architecture with 3 layers
```

`architecture.md`:

```markdown
# Architecture

## Layer Structure
```

API Layer (routes, controllers)
↓
Domain Layer (business logic, services)
↓
Data Layer (database, external APIs)

```

## Rules
- Controllers ONLY handle request/response
- Business logic ONLY in services
- Data access ONLY in repositories
```

`patterns.md`:

````markdown
# Mandatory Patterns

## Server Actions

All mutations use Next.js Server Actions with next-safe-action:

```typescript
export const createUser = action(schema.createUser, async (input) => {
  // implementation
});
```
````

## Error Handling

All errors use custom error classes from src/lib/errors.ts

````

`tech-stack.md`:
```markdown
# Approved Tech Stack

## Core
- Next.js 14 (App Router)
- TypeScript
- Prisma

## Validation
- Zod (schemas)
- next-safe-action (server actions)
````

`testing.md`:

```markdown
# Testing Requirements

## Coverage

- All server actions: Unit tests
- All API routes: Integration tests
- Critical flows: E2E tests

## Tools

- Jest for unit/integration
- Playwright for E2E
```

**When to version**:

Create a new version when:

- Adding/removing mandatory patterns
- Changing tech stack (library migrations)
- Updating layer boundaries
- Major architectural shifts

**How to version**:

```bash
# Ask Claude
"We're migrating from Prisma to Drizzle. Update the constitution."

# Claude will:
# 1. Create docs/constitutions/v2/
# 2. Copy all files from v1/
# 3. Update tech-stack.md and patterns.md
# 4. Write meta.md changelog
# 5. Update current symlink: current -> v2/
```

**Benefits**:

- AI can't hallucinate patterns - they're documented
- Immutable history when rules change
- Specs reference constitutions (no duplication)
- Evolution is explicit, not drift

## Best Practices

### Writing Good Specs

**Do**:

- ✓ Reference constitution patterns ("Following clean architecture...")
- ✓ Link to external docs instead of pasting examples
- ✓ Focus on WHAT to build, not HOW
- ✓ Include clear acceptance criteria
- ✓ Mention existing files to follow

**Don't**:

- ✗ Duplicate constitution rules in spec
- ✗ Paste library documentation
- ✗ Write implementation steps (that's the plan's job)
- ✗ Add success metrics (product concern, not spec)

**Example**:

Good:

```markdown
## Authentication Flow

Following constitution v2 auth patterns:

- Server actions for login/logout
- Session cookies via next-safe-action
- See constitution v2/patterns.md for details

External: [NextAuth.js docs](https://next-auth.js.org)
```

Bad:

```markdown
## Authentication Flow

We'll use server actions. Here's how server actions work:
[500 lines of Next.js documentation pasted]

And here's the exact code:
[200 lines of implementation code]
```

### Task Sizing

**Target**: M (3-5 hours) tasks

**Good task sizes**:

- **S (1-2h)**: Rare, only for truly standalone work
- **M (3-5h)**: Sweet spot - complete subsystem or layer
- **L (5-7h)**: Complex coherent units (full UI layer, complete API surface)

**Avoid**:

- **XL (>8h)**: Always split into M/L tasks
- **Too many S tasks**: Bundle related work

**Examples**:

Good:

```markdown
Task 2.1: API Layer (M - 4h)
Files: - src/api/user/routes.ts - src/api/user/controller.ts - src/api/user/validation.ts
Acceptance: - All CRUD endpoints working - Validation on all inputs - Error handling complete
```

Bad:

```markdown
Task 2.1: User Routes File (S - 1h)
Files: src/api/user/routes.ts

Task 2.2: User Controller File (S - 1h)
Files: src/api/user/controller.ts

Task 2.3: User Validation File (S - 1h)
Files: src/api/user/validation.ts
```

Better to bundle these into one coherent "API Layer" task.

### When to Use Spectacular

**Good use cases**:

- ✓ Complex features (>3 hours work)
- ✓ Multiple independent subsystems
- ✓ Large refactors
- ✓ Migrations (REST→GraphQL, etc.)
- ✓ Features with clear requirements

**Not ideal for**:

- ✗ Quick bug fixes (<30 min)
- ✗ Exploratory work (unclear requirements)
- ✗ Single-file changes
- ✗ Emergency hotfixes

**Rule of thumb**: If the work can be parallelized (3+ independent tasks), spectacular will save significant time.

### Resume Strategy

If execution is interrupted:

```bash
# Check current state
gs log short

# See which branches exist
git branch | grep {runId}

# Resume from next phase
/spectacular:execute @specs/{runId}-{feature}/plan.md

# Spectacular will:
# - Detect completed phases (branches exist)
# - Skip to next incomplete phase
# - Continue from there
```

## Troubleshooting

### Spec Generation Stalls After Brainstorming

**Symptom**: `/spectacular:spec` completes brainstorming (Phases 1-3) but doesn't generate the spec file.

**Cause**: Transition from brainstorming skill to spec generation doesn't happen.

**Solution**:

```bash
# Interrupt (Esc)
# Re-run with same description
/spectacular:spec "your feature description"
```

Second run typically completes. Brainstorming context from first run helps.

---

### Setup Commands Not Found

**Symptom**:

```
❌ Setup Commands Required

Worktrees need dependencies installed.
Please add to CLAUDE.md...
```

**Cause**: Project CLAUDE.md doesn't define setup commands.

**Solution**:

Add to your project's `CLAUDE.md`:

```markdown
## Development Commands

### Setup

- **install**: `bun install`
- **postinstall**: `npx prisma generate`
```

Then re-run `/spectacular:execute`.

---

### Worktree Creation Fails

**Symptom**:

```
fatal: '.worktrees/abc123-task-1' already exists
```

**Cause**: Stale worktree from previous run.

**Solution**:

```bash
# List worktrees
git worktree list

# Remove stale worktree
git worktree remove .worktrees/abc123-task-1

# Prune references
git worktree prune

# Re-run execute
/spectacular:execute @specs/abc123-feature/plan.md
```

---

### Git-Spice Stack Looks Wrong

**Symptom**: Tasks stacked on wrong branches, or "needs restack" warnings.

**Cause**: Parallel tasks or manual git operations confused the stack.

**Solution**:

```bash
# Check current stack
gs log short

# Restack everything
gs repo sync

# If that fails, rebuild stack manually
gs branch checkout {first-task-branch}
gs branch restack {next-task-branch}
```

See `skills/using-git-spice/SKILL.md` for detailed troubleshooting.

---

### Quality Checks Fail

**Symptom**: Tests/linting fail during execution, blocking progress.

**Cause**: Code doesn't meet quality standards.

**Solution**:

Spectacular stops and reports the issue. Fix in the worktree:

```bash
# Navigate to worktree
cd .worktrees/{runId}-phase-{id}

# Fix the issue
vim src/problematic-file.ts

# Re-run quality checks
bun test
bun run lint

# When passing, commit
git add .
git commit --amend --no-edit

# Return to main repo, continue execution
cd ../..
```

Execution will resume from the fixed state.

---

### Code Review Rejects Implementation

**Symptom**: Code review finds issues (missing acceptance criteria, constitution violations).

**Cause**: Implementation doesn't match spec or violates architectural rules.

**Solution**:

Review the feedback, fix in place:

```bash
# Check which branch failed review
gs log short

# Fix in worktree or main repo
cd .worktrees/{runId}-main
git checkout {failing-branch}

# Address feedback
# ... make changes ...

# Re-commit
git add .
git commit --amend -m "[Task X] Fixed review feedback"

# Re-run code review
# (execution will automatically re-review)
```

---

### Parallel Tasks Slow Despite Independence

**Symptom**: Parallel execution not faster than sequential.

**Possible causes**:

1. **Dependency installation bottleneck**:

   - Each worktree installs separately
   - Solution: Use faster package manager (bun > npm)

2. **Tasks actually conflict**:

   - Check plan for file overlaps
   - Planner might have grouped incorrectly

3. **System resource limits**:
   - Too many tasks for available CPU/memory
   - Parallel execution queues naturally

**Solution**: Review plan.md and ensure true independence.

## Local Development

### Run the test suite

- Quick git mechanics check (seconds):

```bash
./tests/run-tests.sh execute --type=execution
```

- All tests for all commands:

```bash
./tests/run-tests.sh --all
```

- Initialize fixtures (first time):

```bash
cd tests/fixtures
./init-fixtures.sh && ./validate-fixtures.sh
```

More: `tests/QUICK-START.md`, `tests/README.md`.

### Develop the plugin locally (Claude Code)

```bash
make link       # Symlink into ~/.claude for development
make test-link  # Verify linked version
make unlink     # Remove the symlink
```

Requires: `jq`, `git-spice`.

## Versioning & Releases

- Update version files directly:

```bash
./scripts/update-version.sh 1.2.3
```

- Convenience targets (create a stacked branch, tag, and optionally push):

```bash
make bump-patch      # 1.2.3 -> 1.2.4 (no push)
make release-patch   # bump + tag + push
```

Also see Make targets: `bump-minor`, `bump-major`, `release-minor`, `release-major`. Version badge reads from `.claude-plugin/plugin.json`.

## Contributing

Spectacular builds on [superpowers](https://github.com/obra/superpowers) - consider contributing to both!

**Areas for contribution**:

- Additional stacking backends (Graphite, etc.)
- Improved dependency analysis
- Better parallelization heuristics
- More example constitutions
- Documentation improvements

## License

MIT

## Author

Drew Ritter - [@arittr](https://github.com/arittr)

Built on [superpowers](https://github.com/obra/superpowers) by Jesse Vincent
