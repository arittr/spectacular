# Architecture

## Core Principle

**Spectacular is a documentation-driven Claude Code plugin with strict separation between user-facing workflows (commands) and reusable processes (skills).**

## Directory Structure

```
spectacular/
├── .claude-plugin/
│   └── plugin.json              # Plugin metadata (name, version, commands)
├── commands/                     # User-facing slash commands
│   ├── init.md
│   ├── spec.md
│   ├── plan.md
│   └── execute.md
├── skills/                       # Reusable process documentation
│   ├── decomposing-tasks/
│   ├── writing-specs/
│   ├── versioning-constitutions/
│   └── using-git-spice/
├── docs/
│   └── constitutions/           # Architectural truth
│       ├── v1/                  # Immutable version snapshots
│       └── current/             # Symlink to active version
├── specs/                       # Feature specifications
└── scripts/                     # Development tools (version sync, etc)
```

## Layer Boundaries

### Layer 1: Plugin Metadata (`.claude-plugin/`)

**Purpose:** Define plugin identity and available commands

**Rules:**
- MUST contain valid `plugin.json` with name, version, commands list
- Version MUST be synced with `package.json` via `scripts/sync-version.js`
- Command names MUST match actual files in `commands/` directory
- NO logic or workflows in this layer - metadata only

### Layer 2: Commands (`commands/`)

**Purpose:** User-facing entry points invoked with `/spectacular:*`

**Responsibilities:**
- Orchestrate workflows by delegating to skills
- Validate prerequisites (environment, dependencies)
- Provide clear user-facing error messages
- Document command parameters and expected outcomes

**Rules:**
- MUST have YAML frontmatter with `description` field
- MUST delegate actual work to skills (don't implement directly)
- MUST use TodoWrite for multi-step orchestration
- MAY invoke Bash/Read/Write tools for environment checks
- MUST NOT duplicate skill logic (reference skills instead)

**Anti-patterns:**
- ❌ Implementing full workflow logic in command markdown
- ❌ Duplicating process documentation from skills
- ❌ Skipping skill delegation "for simplicity"

### Layer 3: Skills (`skills/*/SKILL.md`)

**Purpose:** Reusable process documentation invoked programmatically

**Responsibilities:**
- Define HOW to perform specific processes
- Provide step-by-step workflows with quality rules
- Include error handling and recovery steps
- Document rationalization patterns and how to resist them

**Rules:**
- MUST follow superpowers skill format (name, description, frontmatter)
- MUST be invocable via Skill tool
- MUST include "When to Use" section with trigger conditions
- MUST include "The Process" with numbered steps
- SHOULD include rationalization table for predictable shortcuts
- SHOULD include TodoWrite checklists for sequential processes

**Anti-patterns:**
- ❌ Creating skills without clear trigger conditions
- ❌ Skills that are just lists of commands (no process/rationale)
- ❌ Duplicating superpowers skills instead of referencing them

### Layer 4: Constitutions (`docs/constitutions/`)

**Purpose:** Immutable snapshots of architectural truth

**Responsibilities:**
- Define foundational rules that if violated, break architecture
- Establish mandatory patterns and prohibited approaches
- Document tech stack and approved libraries
- Provide version history with rationale for changes

**Rules:**
- MUST use versioning (`v1/`, `v2/`, etc.) not direct edits
- MUST maintain immutability (old versions never change)
- MUST use `current/` symlink for references
- MUST document changes in `meta.md` with rationale
- Content MUST be constitutional (violating it breaks architecture)

**Test for constitutionality:**
"If we violate this rule, does the architecture break?"
- ✅ Constitutional: "Skills must be at `skills/{name}/SKILL.md`" → violating breaks Skill tool
- ❌ Not constitutional: "Use descriptive variable names" → just a style preference

## Component Interactions

### Command → Skill Delegation

Commands MUST delegate to skills for actual work:

```markdown
<!-- In commands/example.md -->
Use the `decomposing-tasks` skill to break down the specification into tasks.
```

Commands orchestrate which skills to invoke and in what order, but don't implement the process themselves.

### Skill → Skill References

Skills MAY reference other skills but MUST NOT duplicate them:

```markdown
<!-- In skills/example/SKILL.md -->
For code review, use the `requesting-code-review` skill from superpowers.
```

### Everything → Constitution References

All content MUST reference `current/` symlink, never hardcoded versions:

```markdown
✅ See @docs/constitutions/current/patterns.md
❌ See @docs/constitutions/v1/patterns.md
```

## Extension Pattern

Spectacular EXTENDS superpowers, not replaces it:

**Superpowers provides:**
- Core workflow skills (TDD, debugging, code review)
- General-purpose development patterns
- Foundation for building on top

**Spectacular adds:**
- Spec-anchored development workflow
- Parallel execution via git worktrees
- Git-spice integration patterns
- Constitution versioning

**Rule:** Before creating a new skill, check if superpowers already provides it. If so, reference it rather than duplicate.

## Subagent Architecture

Spectacular uses Claude Code subagents for parallel work:

**Orchestrator Subagent:**
- Runs in main working directory
- Dispatches implementation subagents
- Creates and cleans up worktrees
- Never runs git commands directly (delegates to subagents)

**Implementation Subagents:**
- Work in isolated worktree directories
- Create feature branches with `gs branch create`
- MUST `git switch --detach` after branch creation (makes branches accessible to parent)
- Run tests, builds, quality checks in isolation

**Code Review Subagent:**
- Reviews completed work against spec/plan
- Runs in main working directory after worktree cleanup
- Validates integration and consistency

## Immutability Guarantees

**Constitution versions are immutable:**
- v1/ NEVER changes after v2 is created
- v2/ NEVER changes after v3 is created
- Current version MAY change (typos, clarifications) until next version created

**Why:** Immutability enables:
1. Explicit version history (not just git log)
2. Safe rollback (repoint symlink)
3. Clear changepoints (when did rules change?)
4. Auditability (what were rules at time X?)

## Violation Handling

**What happens when someone violates architecture?**

1. **Commands without delegation** → Hard to maintain, logic sprawl
2. **Hardcoded version references** → Break when new version created
3. **Non-constitutional content in constitution** → Version churn, unclear boundaries
4. **Skills duplicating superpowers** → Divergence, missed improvements
5. **Editing old constitution versions** → Lost immutability, broken history

Architecture exists to prevent these failures through enforceable rules.
