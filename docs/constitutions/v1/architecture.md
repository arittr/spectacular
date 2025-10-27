# Architecture

## Project Type

**Spectacular is a Claude Code plugin** - a collection of markdown files that extend Claude's capabilities with custom commands and skills.

This is NOT a traditional codebase with runtime code, build processes, or deployment. The "architecture" is how documentation is organized to make Claude behave correctly.

## Directory Structure

```
spectacular/
├── .claude-plugin/
│   └── plugin.json              # Plugin metadata (name, version, description)
├── commands/                     # User-facing slash commands
│   ├── init.md                  # /spectacular:init
│   ├── spec.md                  # /spectacular:spec
│   ├── plan.md                  # /spectacular:plan
│   └── execute.md               # /spectacular:execute
├── skills/                       # Reusable process documentation
│   ├── decomposing-tasks/       # Planning logic
│   │   └── SKILL.md
│   ├── writing-specs/           # Spec creation patterns
│   │   └── SKILL.md
│   ├── versioning-constitutions/ # Constitution evolution
│   │   └── SKILL.md
│   └── using-git-spice/         # Stacked branch workflows
│       └── SKILL.md
├── docs/
│   └── constitutions/           # Versioned architectural rules
│       ├── v1/                  # Immutable snapshots
│       └── current -> v1/       # Symlink to active version
└── scripts/                      # Version management
    └── sync-version.js
```

## Layer Boundaries

### 1. Commands Layer (User-Facing)
**Location:** `commands/*.md`

**Purpose:** Entry points that users invoke with `/spectacular:*` slash commands.

**Rules:**
- Commands orchestrate workflows but delegate actual work to skills
- May call multiple skills in sequence
- Should include error handling and recovery guidance
- MUST have YAML frontmatter with `description` field

**Example:**
```markdown
---
description: Generate feature specification using brainstorming
---

# Spectacular Spec Command

1. Use the brainstorming skill to refine the idea
2. Use the writing-specs skill to create the spec document
...
```

**Anti-patterns:**
- ❌ Implementing logic directly in commands (delegate to skills)
- ❌ Duplicating skill content (reference and invoke instead)

### 2. Skills Layer (Reusable Processes)
**Location:** `skills/*/SKILL.md`

**Purpose:** Process documentation that Claude executes. Skills are like functions - reusable, composable, testable.

**Rules:**
- Skills follow superpowers format (name, description, When to Use, The Process, Quality Rules)
- MUST have YAML frontmatter with `name` and `description`
- MUST include "Announce:" instruction for transparency
- MUST include rationalization table if there are rules Claude might skip
- SHOULD include TodoWrite checklists for sequential steps
- MUST be tested with `testing-skills-with-subagents` before deployment

**Example Structure:**
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

## Rationalization Table
| Rationalization | Why It's Wrong | What to Do Instead |
|----------------|----------------|-------------------|
...
```

**Anti-patterns:**
- ❌ Softening rules to make them "easier" (rigor prevents bugs)
- ❌ Skipping rationalization tables (Claude will exploit gaps)
- ❌ Writing skills without testing them with subagents first

### 3. Constitution Layer (Architectural Truth)
**Location:** `docs/constitutions/v{N}/`

**Purpose:** Immutable snapshots of foundational rules. Constitutions define what MUST be true for the architecture to work.

**Rules:**
- Constitutions are **versioned** (v1/, v2/, etc.)
- `current/` symlink points to active version
- Old versions remain unchanged (immutable history)
- Changes create new version using `versioning-constitutions` skill
- All references use `current/` symlink, never hardcoded versions

**Files:**
- `meta.md` - Version number, date, changelog, rationale
- `architecture.md` - This file (layer boundaries, structure)
- `patterns.md` - Mandatory patterns (how to write skills/commands)
- `tech-stack.md` - Approved tools and formats
- `testing.md` - Testing requirements and approach

**Test for Constitutionality:**
Ask: "If we violate this rule, does the architecture break?"
- ✅ Constitutional: "Skills MUST have rationalization tables" → violating means Claude skips rules
- ❌ Not constitutional: "Use 80-char line length" → violating just looks different

**Anti-patterns:**
- ❌ Editing current version for breaking changes (create new version)
- ❌ Putting implementation details in constitution (use specs/ instead)
- ❌ Hardcoding version numbers in references (use `current/` symlink)

### 4. Scripts Layer (Automation)
**Location:** `scripts/*.js`, `package.json` scripts

**Purpose:** Automate version management and validation.

**Rules:**
- Version bumps update both `package.json` and `.claude-plugin/plugin.json`
- Use `sync-version.js` hook to keep versions in sync
- Follow semantic versioning (major.minor.patch)

**Anti-patterns:**
- ❌ Manual version edits (use npm version or pnpm version)
- ❌ Forgetting to sync plugin.json (use sync-version.js)

## Dependency Flow

```
Commands
  ↓ (invoke)
Skills
  ↓ (reference)
Constitutions
```

- Commands invoke skills using the Skill tool
- Skills reference constitutions for validation rules
- Constitutions never reference commands or skills (foundational layer)

## Integration with Superpowers

Spectacular **extends** the superpowers plugin, not replaces it.

**Key superpowers skills used:**
- `brainstorming` - Refine ideas before spec creation
- `writing-skills` - Create/edit spectacular skills
- `testing-skills-with-subagents` - Validate skills work under pressure
- `test-driven-development` - RED-GREEN-REFACTOR approach
- `systematic-debugging` - Four-phase debugging framework
- `requesting-code-review` - Dispatch code-reviewer after phases
- `verification-before-completion` - Evidence before assertions
- `using-git-worktrees` - Parallel task isolation
- `subagent-driven-development` - Context-isolated task execution

**NEVER recreate superpowers workflows** - reference and invoke them instead.

## Quality Gates

Every layer has validation:

**Commands:**
- Must have description frontmatter
- Must delegate to skills (not implement directly)
- Test by invoking in sample project

**Skills:**
- Must follow superpowers format
- Must be tested with `testing-skills-with-subagents`
- Must include rationalization tables for strict rules
- Must have TodoWrite checklists for sequential processes

**Constitutions:**
- Must pass "Test for Constitutionality" (breaks architecture if violated?)
- Must document rationale in meta.md
- Must use versioning for breaking changes
- Must use `current/` symlink for references

**Scripts:**
- Must keep package.json and plugin.json versions in sync
- Must create git tags for releases

## Validation Commands

```bash
# Verify plugin structure
ls -la .claude-plugin/plugin.json
ls -la commands/
ls -la skills/

# Verify constitution versions
ls -la docs/constitutions/
cat docs/constitutions/current/meta.md

# Verify no hardcoded version references
grep -r "constitutions/v[0-9]" .claude/  # Should return nothing
grep -r "constitutions/v[0-9]" commands/  # Should return nothing
grep -r "constitutions/v[0-9]" skills/    # Should return nothing

# Verify version sync
node -e "console.log(require('./package.json').version)"
cat .claude-plugin/plugin.json | grep '"version"'
```
