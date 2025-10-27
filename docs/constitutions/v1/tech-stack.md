# Tech Stack

## Core Technologies

Spectacular is a **Claude Code plugin** - pure documentation with no runtime dependencies.

### Required

#### Markdown
- **Format:** CommonMark with GitHub-flavored extensions
- **Files:** All commands (`commands/*.md`) and skills (`skills/*/SKILL.md`)
- **Why:** Claude Code's native format for documentation

#### YAML Frontmatter
- **Format:** Standard YAML between `---` delimiters
- **Required fields:**
  - Commands: `description` (one-line summary)
  - Skills: `name` and `description`
- **Why:** Claude Code uses frontmatter for metadata

#### Bash
- **Usage:** Validation scripts, version management, git operations
- **Files:** Inline in skills/commands, `scripts/*.sh`
- **Why:** Standard Unix shell for automation

#### Git
- **Version:** Any modern version (2.x+)
- **Why:** Plugin development workflow, version control

### Development Dependencies

#### Node.js + npm/pnpm
- **Version:** Node 18+
- **Usage:** Version management scripts only
- **Files:** `package.json`, `scripts/sync-version.js`
- **Why:** Automated version bumping with sync to plugin.json

**Installation:**
```bash
# Using npm
npm install

# Using pnpm
pnpm install
```

#### Git-spice
- **Version:** Latest stable
- **Usage:** Stacked branch management for plugin development
- **Why:** Enables reviewable PRs when working on multiple features

**Installation:**
```bash
# macOS
brew install git-spice

# Linux
# See https://github.com/abhinav/git-spice
```

### External Dependencies (Required at Runtime)

When spectacular commands execute, they assume:

#### Superpowers Plugin
- **Source:** https://github.com/obra/superpowers
- **Why:** Provides core metaskills (writing-skills, testing-skills-with-subagents, brainstorming, TDD, etc.)
- **Validation:** `/spectacular:init` checks for superpowers

**Installation:**
```bash
# Install superpowers plugin
git clone https://github.com/obra/superpowers.git ~/.claude/plugins/cache/superpowers
```

#### Git (in target project)
- **Why:** All spectacular workflows assume git repository
- **Validation:** `/spectacular:init` checks `git rev-parse --git-dir`

#### Git-spice (in target project)
- **Why:** Stacked branch management for parallel execution
- **Validation:** `/spectacular:init` checks `git-spice --version` and repo initialization

## Approved File Formats

### Commands
- **Format:** Markdown with YAML frontmatter
- **Location:** `commands/*.md`
- **Naming:** Lowercase with hyphens (e.g., `init.md`, `execute.md`)

### Skills
- **Format:** Markdown with YAML frontmatter
- **Location:** `skills/{skill-name}/SKILL.md`
- **Naming:** Lowercase with hyphens for directory (e.g., `writing-specs/`)

### Constitutions
- **Format:** Markdown (no frontmatter needed)
- **Location:** `docs/constitutions/v{N}/*.md`
- **Files:**
  - `meta.md` - Version metadata
  - `architecture.md` - Layer boundaries
  - `patterns.md` - Mandatory patterns
  - `tech-stack.md` - This file
  - `testing.md` - Testing requirements

### Configuration
- **Plugin metadata:** JSON (`.claude-plugin/plugin.json`)
- **Package metadata:** JSON (`package.json`)
- **Version sync:** JavaScript (`scripts/sync-version.js`)

## Prohibited Technologies

### No Build Process
- ❌ No TypeScript compilation
- ❌ No bundlers (webpack, rollup, etc.)
- ❌ No transpilation

**Why:** Markdown is interpreted directly by Claude Code. Build steps add complexity without benefit.

### No Runtime Dependencies
- ❌ No npm packages imported in markdown
- ❌ No external APIs called from commands/skills

**Why:** Commands and skills are instructions for Claude, not executable code.

### No Test Frameworks
- ❌ No Jest, Mocha, pytest, etc.

**Why:** Testing is done with `testing-skills-with-subagents` metaskill (run actual subagents through scenarios)

**Exception:** Scripts in `scripts/` can have test files if needed, but currently none exist.

## Version Management

### Package Version
- **Source of truth:** `package.json`
- **Sync target:** `.claude-plugin/plugin.json`
- **Format:** Semantic versioning (major.minor.patch)

**Process:**
```bash
# Bump version (triggers sync-version.js automatically)
pnpm version patch   # 1.1.0 → 1.1.1
pnpm version minor   # 1.1.0 → 1.2.0
pnpm version major   # 1.1.0 → 2.0.0

# Bump and push to remote
pnpm release:patch
pnpm release:minor
pnpm release:major
```

**What happens:**
1. Updates `package.json` version
2. Runs `scripts/sync-version.js` (via postversion hook)
3. Syncs version to `.claude-plugin/plugin.json`
4. Creates git commit
5. Creates git tag (e.g., `v1.1.1`)
6. Pushes to remote (if using `release:*` scripts)

### Constitution Version
- **Format:** Sequential integers (v1, v2, v3)
- **Location:** `docs/constitutions/v{N}/`
- **Active version:** `docs/constitutions/current/` symlink
- **Process:** Use `versioning-constitutions` skill

**NOT semantic versioning.** Constitution versions are immutable snapshots, not API versions.

## Editor/IDE

### No Required IDE

Spectacular can be edited with any text editor:
- VS Code
- Vim/Neovam
- Emacs
- Sublime Text
- nano

**Recommended:** Editor with markdown preview and YAML syntax highlighting

### No IDE-Specific Configuration

- ❌ No `.vscode/` settings
- ❌ No `.idea/` (JetBrains) configuration
- ❌ No editor-specific plugins required

**Why:** Keep plugin accessible to all developers regardless of editor choice

## Summary

**Required to develop spectacular:**
- Markdown + YAML knowledge
- Git
- Node.js (for version management only)

**Required to use spectacular (in target project):**
- Superpowers plugin
- Git repository
- Git-spice

**Prohibited:**
- Build processes
- Runtime dependencies
- Test frameworks (use testing-skills-with-subagents instead)
