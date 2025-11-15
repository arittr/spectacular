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
git clone https://github.com/arittr/spectacular.git ~/.codex/spectacular
```

Alternatively, if you prefer a different location:

```bash
git clone https://github.com/arittr/spectacular.git /path/to/spectacular
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

### 3. Install spectacular-codex MCP Server

**CRITICAL:** The `codex-execute` command requires the spectacular-codex MCP server to be installed and configured. Without this, execution will fail.

#### Install the MCP Server

```bash
# Clone the spectacular-codex repository
git clone https://github.com/arittr/spectacular-codex.git ~/.codex/spectacular-codex

# Navigate to the directory
cd ~/.codex/spectacular-codex

# Install dependencies
pnpm install  # or npm install

# Build the MCP server
pnpm build    # or npm run build
```

#### Configure Codex to Use the MCP Server

Create or edit `~/.codex/mcp-servers.json`:

```json
{
  "spectacular-codex": {
    "command": "node",
    "args": ["/Users/YOUR_USERNAME/.codex/spectacular-codex/dist/index.js"],
    "env": {}
  }
}
```

**Important:** Replace `/Users/YOUR_USERNAME` with your actual home directory path. You can find it with:

```bash
echo ~/.codex/spectacular-codex/dist/index.js
```

#### Verify MCP Server is Configured

Start a Codex session and check if the MCP tools are available:

```bash
codex

# In Codex, ask:
"List available MCP tools"

# You should see:
# - spectacular_execute
# - subagent_execute
# - subagent_status
```

If you don't see these tools, check:
- MCP server is built: `ls ~/.codex/spectacular-codex/dist/index.js`
- Path in `mcp-servers.json` is absolute and correct
- Restart Codex CLI after updating `mcp-servers.json`

### 4. Verify Spectacular Installation

Test the spectacular installation by running the bootstrap command:

```bash
~/.codex/spectacular/.codex/spectacular-codex bootstrap
```

You should see:

- **Codex-Specific Commands**: codex-execute
- **Claude Code Commands** (reference): init, spec, plan, execute
- List of available skills (decomposing-tasks, writing-specs, etc.)
- Auto-loaded spectacular:using-spectacular skill

### 5. Initialize Your Project

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

# Execute the plan via MCP server
"Execute the plan at specs/abc123-magic-link/plan.md using codex-execute"

# Codex will:
# 1. Parse the plan and extract structured data
# 2. Call spectacular_execute MCP tool with plan object
# 3. Poll subagent_status for progress updates
# 4. Display phase/task completion in real-time
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

**Codex-Specific Commands** (use these in Codex):
- **codex-execute** - Execute plan via spectacular-codex MCP server with parallel orchestration

**Claude Code Commands** (reference only):
- **init** - Initialize spectacular environment
- **spec** - Generate feature specification
- **plan** - Decompose spec into executable plan
- **execute** - Execute plan with parallel orchestration (Claude Code only - uses Task tool)

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

## Testing the Integration

After installation, test that the full Spectacular + MCP flow works:

### Create a Test Project

```bash
# Create a simple test project
mkdir ~/test-spectacular && cd ~/test-spectacular
git init
gs repo init  # Initialize git-spice

# Create minimal CLAUDE.md
cat > CLAUDE.md <<'EOF'
# Test Project

## Development Commands

### Setup
- **install**: `echo "No dependencies"`
- **postinstall**: N/A

### Quality Checks
- **test**: `echo "Tests pass"`
- **lint**: `echo "Linting pass"`
- **build**: `echo "Build pass"`
EOF

git add CLAUDE.md
git commit -m "Initial commit"
```

### Create a Test Plan

```bash
# Create a minimal test plan
mkdir -p specs/abc123-test-feature
cat > specs/abc123-test-feature/plan.md <<'EOF'
# Implementation Plan: Test Feature
Run ID: abc123
Feature: test-feature

## Phase 1: Foundation (Sequential)

### Task 1-1: Create Hello File
**Description:** Create a simple hello.txt file
**Files:**
- hello.txt

**Acceptance Criteria:**
- File contains "Hello, Spectacular!"
- File is committed to git

**Dependencies:** None
EOF
```

### Test with Codex

```bash
# Start Codex session
codex

# In the Codex prompt, try:
"Execute the plan at specs/abc123-test-feature/plan.md using codex-execute"

# Codex should:
# 1. Parse the plan
# 2. Call spectacular_execute MCP tool
# 3. Poll subagent_status for updates
# 4. Display task progress
```

### Expected Output

You should see:

1. **Plan parsing:** Codex extracts runId, phases, tasks
2. **MCP tool call:** `spectacular_execute` is invoked
3. **Status polling:** Progress updates appear every 10-30 seconds
4. **Task completion:** Branch `abc123-task-1-1-create-hello-file` created
5. **Final report:** Summary of execution with branch names

### Verify Results

```bash
# Check branches were created
git branch | grep abc123

# Should see:
# abc123-main
# abc123-task-1-1-create-hello-file

# Check worktree exists
ls .worktrees/abc123-main

# View stack
gs log short
```

### Troubleshooting Test Failures

**If Codex says "MCP tool not found":**
- Check `~/.codex/mcp-servers.json` has `spectacular-codex` configured
- Verify MCP server is built: `ls ~/.codex/spectacular-codex/dist/index.js`
- Restart Codex CLI

**If parsing fails:**
- Check plan.md format matches template above
- Verify runId is 6 hex characters
- Ensure phases have `(Sequential)` or `(Parallel)` markers

**If execution hangs:**
- Check MCP server logs (if available)
- Verify git-spice is installed: `gs --version`
- Check worktree creation succeeded: `git worktree list`

**If subagent fails to spawn:**
- Verify Codex SDK is installed in spectacular-codex: `ls ~/.codex/spectacular-codex/node_modules/@openai/codex-sdk`
- Check MCP server is using SDK (not execa) for subagent execution

### Cleanup Test Project

```bash
cd ~
rm -rf ~/test-spectacular
```

## Updating Spectacular

To get the latest version:

```bash
cd ~/.codex/spectacular
git pull

cd ~/.codex/spectacular-codex
git pull && pnpm install && pnpm build
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
| Slash commands `/spectacular:*` | Natural language + `codex-execute` command |
| Plugin in `~/.claude/plugins/` | Scripts in `~/.codex/spectacular/` + MCP server |
| Automatic skill loading | Manual skill activation via bootstrap |
| Subagents via Task tool | Subagents via MCP server + Codex SDK |
| `commands/execute.md` | `.codex/commands/codex-execute.md` (orchestration duplicated) |
| Inline skill execution | Skills embedded in subagent prompts |

## Next Steps

1. Read `~/.codex/spectacular/README.md` for methodology overview
2. Check your project has required CLAUDE.md sections
3. Try the spec → plan → execute workflow
4. Review generated branches with `gs log short`

## Support

- Report issues: <https://github.com/arittr/spectacular/issues>
- Documentation: <https://github.com/arittr/spectacular>
- superpowers: <https://github.com/obra/superpowers>
