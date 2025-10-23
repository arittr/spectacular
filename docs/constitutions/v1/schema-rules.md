# Schema Rules

## Core Principle

**File names, directory structures, and naming conventions are load-bearing: tools depend on them.**

These aren't style preferences - they're contracts with Claude Code's plugin system and git-spice.

## File Naming

### Commands: `commands/{name}.md`

**Format:** Lowercase with hyphens, `.md` extension

**Examples:**
- ✅ `commands/init.md`
- ✅ `commands/execute.md`
- ✅ `commands/write-spec.md`
- ❌ `commands/Init.md` (wrong case)
- ❌ `commands/execute_plan.md` (underscores not hyphens)
- ❌ `commands/plan` (missing .md)

**Why constitutional:** Claude Code plugin system expects markdown files. Command names in `plugin.json` must match file names exactly (minus `.md` extension).

### Skills: `skills/{name}/SKILL.md`

**Format:** Lowercase directory with hyphens, `SKILL.md` file (uppercase)

**Examples:**
- ✅ `skills/decomposing-tasks/SKILL.md`
- ✅ `skills/versioning-constitutions/SKILL.md`
- ❌ `skills/decomposing-tasks.md` (missing directory)
- ❌ `skills/decomposing-tasks/skill.md` (lowercase skill.md)
- ❌ `skills/DecomposingTasks/SKILL.md` (wrong case for directory)

**Why constitutional:** Skill tool expects `{name}/SKILL.md` pattern. Superpowers format requires uppercase `SKILL.md`.

**Additional files allowed:**
- `skills/{name}/test-scenarios.md` - Test cases for skill
- `skills/{name}/examples/` - Example usage
- `skills/{name}/README.md` - Additional documentation

### Specifications: `specs/{runId}-{feature-slug}/spec.md`

**Format:** 6-char hex runId, hyphen, kebab-case feature slug, `/spec.md`

**Examples:**
- ✅ `specs/a1b2c3-user-authentication/spec.md`
- ✅ `specs/f4e5d6-payment-integration/spec.md`
- ❌ `specs/user-authentication/spec.md` (missing runId)
- ❌ `specs/a1b2c3/spec.md` (missing feature slug)
- ❌ `specs/a1b2c3-user_authentication/spec.md` (underscores not hyphens)

**Why constitutional:** RunId enables multiple features developed simultaneously. Feature slug provides human readability. Tools filter by runId prefix.

**RunId generation:**
```bash
# 6-char hex hash from feature name + timestamp
echo -n "feature-name-$(date +%s)" | shasum | cut -c1-6
```

### Plans: `specs/{runId}-{feature-slug}/plan.md`

**Format:** Same directory as spec, `plan.md` filename

**Examples:**
- ✅ `specs/a1b2c3-user-authentication/plan.md`
- ❌ `plans/a1b2c3-user-authentication.md` (wrong directory)

**Why constitutional:** Keeps spec and plan together. Plan references spec, should be colocated.

### Constitutions: `docs/constitutions/v{N}/{file}.md`

**Format:** `v` prefix, integer version number, descriptive filename

**Examples:**
- ✅ `docs/constitutions/v1/meta.md`
- ✅ `docs/constitutions/v2/patterns.md`
- ❌ `docs/constitutions/1/meta.md` (missing v prefix)
- ❌ `docs/constitutions/v1.2/meta.md` (semantic versioning not allowed)
- ❌ `docs/constitutions/latest/meta.md` (use symlink, not "latest" directory)

**Required files in each version:**
- `meta.md` - Version metadata and changelog
- `architecture.md` - Layer boundaries and structure
- `patterns.md` - Mandatory patterns
- `tech-stack.md` - Dependencies and tools
- `schema-rules.md` - Naming and structure
- `testing.md` - Validation approach

**Why constitutional:** Versioning enables immutability. Missing required files = incomplete constitution.

### Scripts: `scripts/{name}.{sh|js}`

**Format:** Lowercase with hyphens, appropriate extension

**Examples:**
- ✅ `scripts/sync-version.js`
- ✅ `scripts/bump-version.sh`
- ❌ `scripts/syncVersion.js` (camelCase not allowed)

**Why constitutional:** Scripts are invoked from package.json and Makefile. Naming must be consistent.

## Directory Structure

### Plugin Root

```
spectacular/
├── .claude-plugin/          # Plugin metadata (required)
├── commands/                # Slash commands (required)
├── skills/                  # Process documentation (required)
├── docs/                    # Constitutions and other docs
├── specs/                   # Feature specifications (created during use)
├── scripts/                 # Development tools
├── hooks/                   # Git hooks and session hooks
├── CLAUDE.md                # Project instructions for Claude Code
├── README.md                # User-facing documentation
├── LICENSE                  # License file
├── package.json             # Version and scripts
└── Makefile                 # Release shortcuts
```

**Required directories:** `.claude-plugin/`, `commands/`, `skills/`, `docs/constitutions/`

**Optional directories:** `specs/`, `scripts/`, `hooks/`

**Why constitutional:** Claude Code expects `.claude-plugin/plugin.json`. Skills/commands must be discoverable in standard locations.

### Worktrees: `.worktrees/{runId}-task-{phase}-{task}-{name}/`

**Format:** Hidden directory, runId prefix, task identifiers, descriptive name

**Examples:**
- ✅ `.worktrees/a1b2c3-task-1-2-install-tsx/`
- ✅ `.worktrees/a1b2c3-task-2-1-setup-database/`
- ❌ `worktrees/` (not hidden, pollutes git status)
- ❌ `.worktrees/task-1-2/` (missing runId)

**Why constitutional:** Worktrees must be gitignored (hidden). RunId prevents collisions across features. Task numbering matches plan structure.

**MUST be in .gitignore:**
```
.worktrees/
```

## Branch Naming

### Task Branches: `{runId}-task-{phase}-{task}-{short-name}`

**Format:** 6-char runId, "task" literal, phase number, task number, kebab-case description

**Examples:**
- ✅ `a1b2c3-task-1-2-install-tsx`
- ✅ `f4e5d6-task-2-1-setup-database`
- ❌ `task-1-2-install-tsx` (missing runId)
- ❌ `a1b2c3-install-tsx` (missing task- prefix and phase/task numbers)
- ❌ `a1b2c3-task-install-tsx` (missing phase/task numbers)

**Phase/Task numbering:**
- Phase 1, Task 2 → `task-1-2`
- Phase 2, Task 1 → `task-2-1`

**Why constitutional:** RunId enables filtering (`git branch | grep "^  {runId}-"`). Phase/task numbering maps to plan. Git-spice uses branch names for stack visualization.

### Branch Filtering

```bash
# List all branches for a feature
git branch | grep "^  {runId}-"

# Cleanup branches for a feature
git branch | grep "^  {runId}-" | xargs git branch -D
```

**Why constitutional:** Multiple features can be developed simultaneously. RunId filtering prevents accidental operations on wrong feature.

## Symlink Patterns

### Constitution Current Version: `docs/constitutions/current → v{N}`

**Format:** Relative symlink named `current` pointing to version directory

**Creation:**
```bash
cd docs/constitutions
ln -s v1 current
```

**Verification:**
```bash
ls -la docs/constitutions/current
# Should show: current -> v1
```

**Why constitutional:** All references use `current/` symlink. When new version created, update symlink - all references automatically point to new version.

**NEVER hardcode version in references:**
```markdown
✅ See @docs/constitutions/current/patterns.md
❌ See @docs/constitutions/v1/patterns.md
```

## Plugin Metadata

### .claude-plugin/plugin.json

**Required fields:**
- `name` - Plugin identifier (e.g., "spectacular")
- `version` - Semver version (synced with package.json)
- `description` - One-line description
- `commands` - Array of command objects with name/description

**Example:**
```json
{
  "name": "spectacular",
  "version": "1.2.0",
  "description": "Spec-anchored development with parallel execution",
  "commands": [
    {
      "name": "spectacular:init",
      "description": "Initialize spectacular environment"
    }
  ]
}
```

**Why constitutional:** Claude Code requires valid JSON with these fields. Invalid JSON = plugin won't load.

**Version sync:** MUST match `package.json` version field. Use `scripts/sync-version.js` after bumping version.

## Frontmatter Schema

### Command Frontmatter

```yaml
---
description: One-line description shown to users
---
```

**Required:** `description` field

**Optional:** None currently

**Why constitutional:** Plugin system reads `description` for command list. Missing = command not shown.

### Skill Frontmatter

```yaml
---
name: skill-name
description: When to use this skill - trigger conditions and scenarios
---
```

**Required:** `name` and `description` fields

**Optional:** None currently

**Why constitutional:** Skill tool uses `name` for invocation. Missing = skill not invocable.

## File Extensions

**Allowed:**
- `.md` - Documentation (commands, skills, specs, etc.)
- `.json` - Configuration (plugin.json, package.json)
- `.js` - Scripts (version sync, release tools)
- `.sh` - Shell scripts (hooks, utilities)

**Prohibited:**
- `.ts`, `.tsx` - No TypeScript (no build step)
- `.jsx`, `.js` in src/ - No source code (documentation only)
- `.css`, `.scss` - No styles (not a web app)
- `.html` - No HTML (markdown only)

**Why constitutional:** Spectacular is documentation-only. Code files indicate architectural violation.

## Capitalization Rules

### Filenames

**Commands:** Lowercase with hyphens (`init.md`, `execute.md`)

**Skills:** Lowercase directory, uppercase `SKILL.md` file

**Specs/Plans:** Lowercase with hyphens

**Why constitutional:** Unix filesystems are case-sensitive. Consistent casing prevents "works on my Mac, breaks on Linux" issues.

### Directory Names

**All lowercase except:**
- `SKILL.md` (required by superpowers format)
- `CLAUDE.md` (convention for Claude Code instructions)
- `README.md` (convention)
- `LICENSE` (convention)

**Why constitutional:** Consistency prevents confusion and case-sensitivity bugs.

## Validation

### Schema Validation Script (Future)

Could add `scripts/validate-schema.sh`:
```bash
#!/bin/bash
# Verify all commands have description in frontmatter
# Verify all skills have name/description in frontmatter
# Verify all constitutions have required 6 files
# Verify current symlink exists and points to valid version
```

**Not currently implemented** but constitutional rules enable automated validation.

## Violation Consequences

| Violation | Consequence |
|-----------|-------------|
| Command wrong case | Plugin system can't find it |
| Skill not in {name}/SKILL.md | Skill tool can't invoke it |
| Missing runId in branch | Can't filter branches, name collisions |
| Hardcoded version reference | Breaks when new constitution created |
| Wrong frontmatter | Plugin/Skill tool can't parse it |
| Missing constitution files | Incomplete architectural documentation |
| Worktrees not hidden | Pollutes git status, confuses users |

These aren't preferences - they're contracts with tools that will break if violated.
