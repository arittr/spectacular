# Minimal MCP Subagent Wrapper for Codex

> **Status**: Design document for future implementation
> **Purpose**: Enable subagent/parallel execution in Codex CLI (task-agnostic, not spectacular-specific)

## Problem Statement

Codex CLI currently lacks built-in support for:
1. **Subagent dispatch** - Spawning isolated Codex threads with separate context
2. **Parallel execution** - Running multiple tasks concurrently in isolated environments
3. **Git worktree coordination** - Managing multiple Codex threads working in separate worktrees

These capabilities are needed for ANY workflow that requires parallel execution, not just spectacular. Examples:
- Parallel test execution across modules
- Concurrent API endpoint implementation
- Multi-service deployment orchestration
- Batch code transformations

## Non-Goals

**This MCP server is NOT:**
- ❌ Spectacular-specific orchestration (that stays in spectacular skills/commands)
- ❌ Prompt template generation (that's workflow-specific)
- ❌ Plan parsing or task decomposition (that's spectacular-specific)
- ❌ Code review loops (that's workflow-specific)

**This MCP server IS:**
- ✅ Minimal wrapper for spawning Codex threads
- ✅ Git worktree isolation for parallel execution
- ✅ Job status tracking (in-memory, ephemeral)
- ✅ Task-agnostic (works for ANY parallel workflow)

## Proposed Architecture

### Minimal MCP Server

```typescript
// codex-parallel - Task-agnostic parallel execution for Codex
// Install: npm install -g codex-parallel
// Configure: Add to ~/.codex/mcp-servers.json

// Tools:
// - spawn_thread(worktree_path, prompt) → thread_id
// - get_thread_status(thread_id) → status
// - list_threads() → thread[]
```

### Core Functionality

**1. Thread Spawning**

```typescript
interface SpawnThreadRequest {
  worktree_path: string;  // Path to git worktree
  prompt: string;         // Full prompt to execute
  thread_id?: string;     // Optional ID (generated if not provided)
}

interface SpawnThreadResponse {
  thread_id: string;
  status: 'started';
  worktree_path: string;
}
```

**2. Status Tracking**

```typescript
interface ThreadStatus {
  thread_id: string;
  status: 'running' | 'completed' | 'failed';
  worktree_path: string;
  started_at: Date;
  completed_at?: Date;
  error?: string;
}
```

**3. Git Worktree Coordination**

- **NOT** responsible for creating worktrees (caller does that)
- **NOT** responsible for cleanup (caller does that)
- **ONLY** spawns Codex thread with specified working directory
- Tracks completion via thread status, not git operations

## Implementation (100 LOC)

```typescript
#!/usr/bin/env node
/**
 * codex-parallel: Minimal MCP server for parallel Codex thread execution
 *
 * This server provides ONLY thread spawning and status tracking.
 * All workflow logic (worktree creation, prompt generation, cleanup)
 * is the caller's responsibility.
 */

import { Codex } from '@openai/codex';
import { Server } from '@modelcontextprotocol/sdk/server/index.js';
import { StdioServerTransport } from '@modelcontextprotocol/sdk/server/stdio.js';
import { CallToolRequestSchema, ListToolsRequestSchema } from '@modelcontextprotocol/sdk/types.js';

interface Thread {
  id: string;
  status: 'running' | 'completed' | 'failed';
  worktreePath: string;
  startedAt: Date;
  completedAt?: Date;
  error?: string;
}

// In-memory thread tracker
const threads = new Map<string, Thread>();

// Create MCP server
const server = new Server(
  { name: 'codex-parallel', version: '1.0.0' },
  { capabilities: { tools: {} } }
);

// Register tools
server.setRequestHandler(ListToolsRequestSchema, async () => ({
  tools: [
    {
      name: 'spawn_thread',
      description: 'Spawn a Codex thread in specified worktree with prompt',
      inputSchema: {
        type: 'object',
        properties: {
          worktree_path: { type: 'string', description: 'Path to git worktree' },
          prompt: { type: 'string', description: 'Prompt to execute' },
          thread_id: { type: 'string', description: 'Optional thread ID' }
        },
        required: ['worktree_path', 'prompt']
      }
    },
    {
      name: 'get_thread_status',
      description: 'Get status of a running or completed thread',
      inputSchema: {
        type: 'object',
        properties: {
          thread_id: { type: 'string', description: 'Thread identifier' }
        },
        required: ['thread_id']
      }
    },
    {
      name: 'list_threads',
      description: 'List all threads',
      inputSchema: { type: 'object', properties: {} }
    }
  ]
}));

// Handle tool calls
server.setRequestHandler(CallToolRequestSchema, async (request) => {
  const { name, arguments: args } = request.params;

  switch (name) {
    case 'spawn_thread':
      return await spawnThread(args);
    case 'get_thread_status':
      return await getThreadStatus(args);
    case 'list_threads':
      return await listThreads();
    default:
      throw new Error(`Unknown tool: ${name}`);
  }
});

async function spawnThread(args: any) {
  const threadId = args.thread_id || crypto.randomUUID();
  const { worktree_path, prompt } = args;

  // Create thread record
  const thread: Thread = {
    id: threadId,
    status: 'running',
    worktreePath: worktree_path,
    startedAt: new Date()
  };
  threads.set(threadId, thread);

  // Spawn Codex thread (non-blocking)
  executeThread(threadId, worktree_path, prompt).catch(err => {
    thread.status = 'failed';
    thread.error = String(err);
    thread.completedAt = new Date();
  });

  // Return immediately
  return {
    content: [{
      type: 'text',
      text: JSON.stringify({
        thread_id: threadId,
        status: 'started',
        worktree_path
      })
    }]
  };
}

async function executeThread(id: string, worktreePath: string, prompt: string) {
  const thread = threads.get(id)!;

  try {
    const codex = new Codex({ workingDirectory: worktreePath });
    const codexThread = codex.startThread();
    await codexThread.run(prompt);

    thread.status = 'completed';
    thread.completedAt = new Date();
  } catch (error) {
    thread.status = 'failed';
    thread.error = String(error);
    thread.completedAt = new Date();
  }
}

async function getThreadStatus(args: any) {
  const thread = threads.get(args.thread_id);

  if (!thread) {
    throw new Error(`Thread not found: ${args.thread_id}`);
  }

  return {
    content: [{
      type: 'text',
      text: JSON.stringify({
        thread_id: thread.id,
        status: thread.status,
        worktree_path: thread.worktreePath,
        started_at: thread.startedAt,
        completed_at: thread.completedAt,
        error: thread.error
      })
    }]
  };
}

async function listThreads() {
  const threadList = Array.from(threads.values()).map(t => ({
    thread_id: t.id,
    status: t.status,
    worktree_path: t.worktreePath,
    started_at: t.startedAt
  }));

  return {
    content: [{
      type: 'text',
      text: JSON.stringify({ threads: threadList })
    }]
  };
}

// Start server
async function main() {
  const transport = new StdioServerTransport();
  await server.connect(transport);
}

main().catch(console.error);
```

## Usage Example (From Spectacular)

### Before (Manual Worktree Management)

```markdown
# In spectacular's executing-parallel-phase skill:

1. Create worktrees manually:
   git worktree add .worktrees/abc123-task-1 main
   git worktree add .worktrees/abc123-task-2 main
   git worktree add .worktrees/abc123-task-3 main

2. Ask user to run tasks in separate terminals
3. Wait for completion
4. Stack branches manually
```

### After (With MCP Wrapper)

```markdown
# In spectacular's executing-parallel-phase skill:

1. Create worktrees (same as before)
2. Generate prompts for each task
3. Spawn threads in parallel:

   Use codex-parallel MCP tool:
   spawn_thread({
     worktree_path: '.worktrees/abc123-task-1',
     prompt: '<task 1 prompt>'
   })

   spawn_thread({
     worktree_path: '.worktrees/abc123-task-2',
     prompt: '<task 2 prompt>'
   })

4. Poll for completion:
   list_threads() → check if all completed

5. Stack branches (same as before)
```

## How This Stays Task-Agnostic

**The MCP server knows NOTHING about:**
- What a "task" is
- What a "phase" is
- What a "spec" or "plan" is
- Git-spice stacking
- Code review loops
- Spectacular workflows

**It ONLY knows:**
- Spawn Codex thread at path X with prompt Y
- Track thread status
- Return status when asked

**All workflow logic lives in spectacular skills:**
- Worktree creation → spectacular:executing-parallel-phase
- Prompt generation → spectacular:executing-parallel-phase
- Branch stacking → spectacular:executing-parallel-phase
- Code review → spectacular:requesting-code-review

## Configuration

Add to `~/.codex/mcp-servers.json`:

```json
{
  "codex-parallel": {
    "command": "npx",
    "args": ["codex-parallel"],
    "env": {}
  }
}
```

## Benefits

### For Spectacular

- **Parallel execution** in Codex (currently manual)
- **Same methodology** (skills document workflow)
- **Minimal changes** (skills already know how to do this)

### For Other Workflows

- **Parallel testing** - Spawn threads per test suite
- **Batch transformations** - Concurrent file processing
- **Multi-service deployment** - Parallel deploy tasks
- **Any parallel workflow** - Generic thread spawning

### For Maintenance

- **100 LOC** - Easy to maintain
- **No business logic** - Can't drift from workflows
- **Single responsibility** - Thread spawning only
- **No spectacular coupling** - Works for everyone

## Migration Path

### Phase 1: Spectacular with .codex/ (Done)

Current state:
- ✅ spectacular-codex CLI tool
- ✅ Skills available in Codex
- ✅ Manual worktree management
- ✅ Methodology documented

### Phase 2: Test with Real Codex

Validate:
- [ ] Skills load correctly
- [ ] Commands accessible
- [ ] Workflows make sense in natural language
- [ ] Manual execution works

### Phase 3: Build codex-parallel (If Needed)

Only if Phase 2 shows:
- Manual worktree management is too error-prone
- Users want automated parallel execution
- Codex can't do this natively

Then:
1. Create `codex-parallel` package (separate repo)
2. Implement 100-LOC MCP server
3. Update spectacular skills to USE codex-parallel MCP tools
4. Test parallel execution

### Phase 4: Publish (If Successful)

- npm publish codex-parallel
- Document in spectacular README
- Add to spectacular .codex/INSTALL.md

## Open Questions

1. **Does Codex support concurrent thread spawning?**
   - Test: Can `Promise.all([thread1.run(), thread2.run()])` work?
   - If no: Sequential execution only, no MCP needed

2. **Does Codex SDK work with git worktrees?**
   - Test: `new Codex({ workingDirectory: '.worktrees/test' })`
   - If no: Need different isolation strategy

3. **Is there a native Codex parallel execution feature?**
   - Research: Check Codex SDK docs for parallel patterns
   - If yes: Use that instead of MCP wrapper

4. **Do users actually need automation?**
   - Test: Try manual workflow first
   - If manual works fine: Skip MCP wrapper

## Alternative Approaches Considered

### Alternative 1: Spectacular-Specific MCP Server

**Rejected because:**
- Couples MCP server to spectacular workflows
- Can't be used by other parallel workflows
- Violates single responsibility
- Hard to maintain as spectacular evolves

### Alternative 2: Bash Script Wrapper

**Rejected because:**
- Can't track running threads
- No async job pattern
- No status polling
- Requires shell-specific features

### Alternative 3: Full Agents SDK Integration

**Rejected because:**
- Way over-engineered for simple thread spawning
- Adds unnecessary layer
- Agents SDK designed for different use case

### Alternative 4: No Automation (Manual Workflow)

**Valid option!** If testing shows manual workflow works fine:
- Users create worktrees manually
- Users run prompts in separate Codex sessions
- Users stack branches manually
- No MCP server needed

## Recommendation

**Start with Phase 2 (testing) before building anything.**

If manual workflow is acceptable → Stop, no MCP needed

If automation is critical → Build minimal codex-parallel wrapper

Either way, the `.codex/` integration for spectacular is done and ready to test.
