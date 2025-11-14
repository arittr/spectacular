# Spectacular Bootstrap for Codex

You have access to **Spectacular** - a methodology for spec-anchored development with automatic parallel task execution.

## How to Use Spectacular

To access spectacular commands and skills, use this CLI tool:

```bash
~/.codex/spectacular/.codex/spectacular-codex <command> [args]
```

**Available commands:**
- `bootstrap` - Show this help and list all commands/skills
- `use-skill <name>` - Load a skill's full content
- `use-command <name>` - Load a command's full content
- `find-skills` - List all available skills
- `find-commands` - List all available commands

## When to Use Spectacular

**Use spectacular when:**
- Working on a project with a `CLAUDE.md` that mentions spectacular
- User asks to create a spec, plan, or execute implementation
- User mentions "parallel execution", "worktrees", or "stacked branches"
- You need to break down a feature into tasks
- You need to manage architectural rules via constitutions

**Do NOT use spectacular when:**
- Simple bug fixes or one-file changes
- Exploratory prototyping without spec
- User explicitly wants manual workflow

## Mandatory Workflow

**Before starting ANY spectacular workflow:**

1. **Check for spectacular:using-spectacular skill**
   ```bash
   ~/.codex/spectacular/.codex/spectacular-codex use-skill using-spectacular
   ```

2. **Follow the skill's mandatory workflow**
   - It establishes when to use /spectacular commands
   - It explains constitution-based development
   - It prevents common mistakes

**Critical Rule:** If a spectacular skill applies to your task, you MUST use it. Not optional.

## Available Spectacular Commands

Run this to see all commands:
```bash
~/.codex/spectacular/.codex/spectacular-codex find-commands
```

Key commands:
- **init** - Initialize spectacular in a project
- **spec** - Generate feature specification (with brainstorming)
- **plan** - Decompose spec into executable tasks
- **execute** - Run plan with parallel/sequential orchestration

## Available Spectacular Skills

Run this to see all skills:
```bash
~/.codex/spectacular/.codex/spectacular-codex find-skills
```

Key skills:
- **using-spectacular** - Mandatory workflow (load this first!)
- **writing-specs** - Spec generation methodology
- **decomposing-tasks** - Task breakdown and phase analysis
- **executing-parallel-phase** - Parallel task orchestration
- **executing-sequential-phase** - Sequential task execution
- **versioning-constitutions** - Constitution evolution
- **using-git-spice** - Stacked branch management

## Integration with Superpowers

Spectacular **extends** superpowers. Key superpowers skills used:

- `brainstorming` - Refine ideas before spec creation
- `test-driven-development` - Write test first, minimal code
- `systematic-debugging` - Four-phase debugging
- `requesting-code-review` - Code review after phases
- `verification-before-completion` - Evidence before assertions
- `subagent-driven-development` - Context-isolated tasks

**Never recreate superpowers workflows - use them via superpowers-codex CLI.**

## Tool Availability

**Spectacular assumes these tools are available:**
- Git with git-spice
- TodoWrite (for task tracking)
- Superpowers skills

**If tools are unavailable:**
- Adapt workflows to use available equivalents
- Example: If TodoWrite missing, use manual checklist tracking
- Example: If git-spice missing, use manual git branch commands

**Note:** Spectacular was designed for Claude Code. Some features may need adaptation for Codex. The skills document the METHODOLOGY, which you should follow even if exact tool names differ.

## Typical Workflow

```
1. User: "I need authentication with magic links"
   You: Load spectacular:writing-specs skill
   You: Guide brainstorming → generate spec

2. User: "Create a plan from that spec"
   You: Load spectacular:decomposing-tasks skill
   You: Parse spec → identify tasks → group phases → generate plan

3. User: "Execute the plan"
   You: Load spectacular:executing-parallel-phase or spectacular:executing-sequential-phase
   You: Create worktrees → spawn subagents (if available) → verify completion
```

## Critical Rules

1. **ALWAYS load spectacular:using-spectacular first** when starting spectacular work
2. **Follow skills exactly** - they prevent known failure modes
3. **Respect phase boundaries** - don't create files from later phases
4. **Use git-spice for all branch operations** - manual branch commands cause stack corruption
5. **Verify before claiming completion** - run tests, check branches exist

## Adaptation for Codex

**Known differences from Claude Code:**
- Claude Code uses `/spectacular:*` slash commands
- Codex uses natural language + skill loading via CLI
- Claude Code has Task tool for subagents
- Codex may need alternative approach (TBD - possibly MCP wrapper)

**How to adapt:**
1. Read the skill instructions (they document the WHAT)
2. Translate to available Codex capabilities
3. Preserve the methodology even if exact implementation differs

## Example: Loading a Skill

When user says "create a spec for user authentication":

```bash
# Load the skill
~/.codex/spectacular/.codex/spectacular-codex use-skill writing-specs

# The skill content will be output to stdout
# Read and follow the instructions
```

The skill contains:
- When to use this skill
- The process (step-by-step)
- Quality rules (what good specs look like)
- Anti-patterns (what to avoid)

## Announcing Skill Usage

When you use a spectacular skill, announce it:

```
"I'm using the spectacular:writing-specs skill to guide specification creation."
```

This helps users understand your process and confirms you actually loaded the skill.

## Getting Help

If you encounter issues:
1. Run `bootstrap` to see available commands/skills
2. Use `find-skills` to search for relevant skills
3. Load `spectacular:troubleshooting-execute` for common execution errors
4. Check project's CLAUDE.md for spectacular configuration

## Version

To check for updates:
```bash
cd ~/.codex/spectacular && git fetch origin --quiet && git status -uno
```

If behind, suggest user runs:
```bash
cd ~/.codex/spectacular && git pull
```
