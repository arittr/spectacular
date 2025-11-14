# Installing Spectacular for Codex

Spectacular enables spec-anchored development with automatic parallel task execution in Codex CLI.

## Prerequisites

- **Codex CLI** installed and working
- **Node.js** (for running the spectacular-codex CLI tool)
- **Git** with **git-spice** installed ([installation guide](https://github.com/abhinav/git-spice#installation))
- **superpowers** plugin installed ([installation guide](https://github.com/obra/superpowers#codex-experimental))

## Installation Steps

### 1. Clone Spectacular

Clone the spectacular repository to `~/.codex/spectacular`:

```bash
git clone https://github.com/drewritter/spectacular.git ~/.codex/spectacular
```

Alternatively, if you prefer a different location:

```bash
git clone https://github.com/drewritter/spectacular.git /path/to/spectacular
```

### 2. Update AGENTS.md

Add spectacular to your `~/.codex/AGENTS.md` file:

```bash
# Create ~/.codex/AGENTS.md if it doesn't exist
mkdir -p ~/.codex
touch ~/.codex/AGENTS.md
```

Add the following to `~/.codex/AGENTS.md`:

```markdown
# Codex Agents Configuration

## Superpowers

run: `~/.codex/superpowers/.codex/superpowers-codex bootstrap`

Follow the output from that command.

## Spectacular

run: `~/.codex/spectacular/.codex/spectacular-codex bootstrap`

Follow the output from that command.
```

**If using a custom installation path**, update the path accordingly:

```markdown
## Spectacular

run: `/path/to/spectacular/.codex/spectacular-codex bootstrap`

Follow the output from that command.
```

### 3. Verify Installation

Test the installation by running the bootstrap command:

```bash
~/.codex/spectacular/.codex/spectacular-codex bootstrap
```

You should see:
- List of available commands (init, spec, plan, execute)
- List of available skills (decomposing-tasks, writing-specs, etc.)
- Auto-loaded spectacular:using-spectacular skill

### 4. Initialize Your Project

In your project directory, run:

```bash
# From Codex CLI
"Initialize spectacular for this project"
```

Codex will use the `spectacular:using-spectacular` skill to guide you through:
- Adding required CLAUDE.md sections
- Setting up git-spice
- Configuring development commands

## Using Spectacular in Codex

Once installed, you can use spectacular workflows in Codex:

```bash
# Start a Codex CLI session in your project
codex

# Generate feature specification
"I need a spec for user authentication with magic links"

# Codex will use spectacular:writing-specs skill to guide brainstorming and spec creation

# Once spec exists, decompose into plan
"Create an implementation plan from specs/abc123-magic-link/spec.md"

# Codex will use spectacular:decomposing-tasks skill to generate plan.md

# Execute the plan
"Execute the plan at specs/abc123-magic-link/plan.md"

# Codex will use spectacular:executing-parallel-phase and spectacular:executing-sequential-phase
# skills to orchestrate parallel/sequential execution
```

## How Spectacular Works in Codex

**At session start:**
1. Codex reads your `~/.codex/AGENTS.md`
2. Runs `spectacular-codex bootstrap`
3. Loads all available commands and skills
4. Auto-loads the `spectacular:using-spectacular` skill

**During workflows:**
1. You describe what you want to do
2. Codex identifies relevant spectacular skills/commands
3. Codex follows the skill instructions
4. Work happens in your project using git-spice and worktrees

**Key difference from Claude Code:**
- In Claude Code: You use `/spectacular:*` slash commands
- In Codex: You describe what you want, Codex uses spectacular skills automatically

## Available Commands

Run `~/.codex/spectacular/.codex/spectacular-codex find-commands` to see all commands:

- **init** - Initialize spectacular environment
- **spec** - Generate feature specification
- **plan** - Decompose spec into executable plan
- **execute** - Execute plan with parallel orchestration

## Available Skills

Run `~/.codex/spectacular/.codex/spectacular-codex find-skills` to see all skills:

- **using-spectacular** - Mandatory workflow for all spectacular projects
- **writing-specs** - Feature specification generation
- **decomposing-tasks** - Task breakdown and phase analysis
- **executing-parallel-phase** - Parallel task orchestration
- **executing-sequential-phase** - Sequential task execution
- **versioning-constitutions** - Constitution evolution workflow
- **using-git-spice** - Stacked branch management
- And more...

## Updating Spectacular

To get the latest version:

```bash
cd ~/.codex/spectacular
git pull
```

Codex will notify you at session start if updates are available.

## Troubleshooting

### "spectacular-codex: command not found"

Make sure the script is executable:

```bash
chmod +x ~/.codex/spectacular/.codex/spectacular-codex
```

### "Skill not found"

Run the bootstrap command to see available skills:

```bash
~/.codex/spectacular/.codex/spectacular-codex bootstrap
```

### "git-spice not found"

Install git-spice following [the official guide](https://github.com/abhinav/git-spice#installation).

### "superpowers not found"

Install superpowers first - spectacular depends on it:

```bash
git clone https://github.com/obra/superpowers.git ~/.codex/superpowers
```

Add to `~/.codex/AGENTS.md`:

```markdown
## Superpowers

run: `~/.codex/superpowers/.codex/superpowers-codex bootstrap`

Follow the output from that command.
```

## Differences from Claude Code Plugin

If you've used spectacular in Claude Code, note these differences:

| Claude Code | Codex |
|-------------|-------|
| Slash commands `/spectacular:*` | Natural language + skills |
| Plugin in `~/.claude/plugins/` | Scripts in `~/.codex/spectacular/` |
| Automatic skill loading | Manual skill activation via bootstrap |
| Subagents via Task tool | (TBD - may need MCP wrapper) |

## Next Steps

1. Read `~/.codex/spectacular/README.md` for methodology overview
2. Check your project has required CLAUDE.md sections
3. Try the spec → plan → execute workflow
4. Review generated branches with `gs log short`

## Support

- Report issues: https://github.com/drewritter/spectacular/issues
- Documentation: https://github.com/drewritter/spectacular
- superpowers: https://github.com/obra/superpowers
