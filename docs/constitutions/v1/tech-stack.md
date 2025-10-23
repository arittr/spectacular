# Tech Stack

## Core Principle

**Spectacular is a pure markdown documentation plugin with minimal dependencies.**

All dependencies must be justified: if removed, core functionality breaks.

## Required Dependencies

### Claude Code

**What:** Anthropic's official CLI for Claude
**Version:** Any version supporting plugins
**Why constitutional:** Spectacular IS a Claude Code plugin. Cannot function without it.

**Installation:** https://claude.com/code

### Superpowers Plugin

**What:** Core skills library for TDD, debugging, code review, git worktrees
**Repository:** https://github.com/obra/superpowers
**Why constitutional:** Spectacular extends superpowers, doesn't replace it. Core workflows (TDD, code review, worktree management) come from superpowers.

**Required skills used:**

- `brainstorming` - Idea refinement before spec creation
- `test-driven-development` - Write test first workflow
- `systematic-debugging` - Four-phase debugging framework
- `requesting-code-review` - Dispatch code-reviewer subagent
- `verification-before-completion` - Evidence before assertions
- `using-git-worktrees` - Parallel task isolation
- `subagent-driven-development` - Context-isolated execution
- `testing-skills-with-subagents` - Skill validation
- `writing-skills` - Skill writing workflow

**Installation:**

```bash
# Via Claude Code plugin manager
# Or manual install to ~/.claude/plugins/
```

### Git

**What:** Version control system
**Version:** Any modern version (2.30+)
**Why constitutional:** All workflows assume git repository. Branching, stacking, worktrees require git.

**Validation:**

```bash
git --version
git rev-parse --git-dir  # Verify repo exists
```

### Git-spice

**What:** Stacked branch management tool
**Repository:** https://github.com/abhinav/git-spice
**Version:** Latest stable
**Why constitutional:** Spectacular's parallel execution relies on stacked PRs. Git-spice provides stack tracking and submission.

**Required commands:**

- `gs repo init` - Initialize repository for stacking
- `gs branch create` - Create tracked branch
- `gs ls` - List stack
- `gs stack submit` - Submit stacked PRs
- `gs restack` - Rebase stack after changes

**Installation:**

```bash
# macOS
brew install git-spice

# Linux
# See https://github.com/abhinav/git-spice
```

**Validation:**

```bash
gs --version
gs ls  # After repo init
```

## Development Dependencies

### Node.js & pnpm

**What:** JavaScript runtime and package manager
**Version:** Node 18+, pnpm 8+
**Why constitutional:** Version sync script (`scripts/sync-version.js`) requires Node. Release workflow uses pnpm scripts.

**Not required for plugin usage** - only for plugin development.

**Installation:**

```bash
# Via package managers or https://nodejs.org/
# pnpm via npm
npm install -g pnpm
```

### Bash/Shell

**What:** Unix shell for scripts
**Why constitutional:** Version bump, linking, and release scripts use bash.

**Required for:** Plugin development workflows

## Prohibited Dependencies

### Build Tools (webpack, rollup, esbuild, etc.)

**Prohibited because:** Spectacular is pure markdown. No compilation step. Adding build tools contradicts "documentation-only" architecture.

**If you need a build step, you're doing it wrong.**

### Testing Frameworks (jest, vitest, etc.)

**Prohibited because:** Skills are tested via `testing-skills-with-subagents` (running actual subagents). Commands are tested via manual invocation in test repos.

Traditional unit tests don't apply to documentation.

### Linters/Formatters for Markdown

**Allowed but not required:** Prettier for markdown is optional.

**Prohibited:** Making linting a requirement. Markdown is for humans, not machines. Consistency matters less than clarity.

### Runtime Libraries

**Prohibited because:** No code runs. All functionality is markdown documentation interpreted by Claude Code.

Libraries like lodash, axios, etc. have no meaning in a documentation-only plugin.

## External Tools (Referenced, Not Bundled)

### GitHub CLI (`gh`)

**Used for:** PR creation in git-spice workflows
**Why not bundled:** Users may/may not use GitHub. Git-spice supports multiple forges.

**Optional:** Only needed if using GitHub for PR hosting.

### Make

**Used for:** Release workflow shortcuts
**Why not bundled:** Standard Unix tool, likely already installed.

**Installation:**

```bash
# Usually pre-installed on macOS/Linux
# Or via package managers
```

## Version Management

### package.json

**Purpose:** Single source of truth for version number

**Why constitutional:** NPM ecosystem expects `package.json`. Plugin version must sync with it.

### .claude-plugin/plugin.json

**Purpose:** Plugin metadata for Claude Code

**Why constitutional:** Claude Code requires valid `plugin.json` to load plugin.

**Version sync:** MUST run `scripts/sync-version.js` after bumping `package.json` version.

## Dependency Decision Matrix

Before adding a new dependency, ask:

1. **Is it required for core functionality?**

   - Yes → Evaluate further
   - No → Don't add

2. **Can functionality be achieved with existing deps?**

   - Yes → Use existing, don't add new
   - No → Evaluate further

3. **Is it documentation or code?**

   - Documentation → No deps needed
   - Code → Shouldn't be adding code to documentation plugin

4. **Is it for development only?**

   - Yes → Add to devDependencies section (package.json)
   - No → Add to Required Dependencies section (this doc)

5. **What breaks if we remove it in 6 months?**
   - Nothing → Don't add it
   - Core functionality → Justify in this doc

## Upgrade Policy

### Superpowers

**When to upgrade:** When new skills are added that spectacular should reference

**Breaking changes:** If superpowers changes skill format, update patterns.md and create constitution v2

### Git-spice

**When to upgrade:** When new features needed (e.g., better stack visualization)

**Breaking changes:** If commands change significantly, update `using-git-spice` skill

### Claude Code

**When to upgrade:** Follow Claude Code release cycle

**Breaking changes:** If plugin API changes, update plugin.json and potentially create constitution v2

## Rationale for Minimal Dependencies

**Why so few dependencies?**

1. **Reliability:** Fewer deps = less breakage
2. **Longevity:** Markdown ages better than code
3. **Portability:** Works anywhere Claude Code works
4. **Simplicity:** No build step = easier to contribute
5. **Focus:** Force solutions via documentation, not code

The moment we add a build step or runtime libraries, we stop being a documentation plugin and become a software project. That defeats the purpose.
