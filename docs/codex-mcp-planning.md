# Spectacular MCP Server for Codex - Architecture & Implementation Plan

> **Status:** Planning phase
> **Goal:** Enable Spectacular workflows (spec → plan → parallel execute) within Codex CLI via MCP server
> **Key Constraint:** User stays in Codex CLI, all orchestration happens via MCP + Codex SDK

## Table of Contents

1. [Architecture Overview](#architecture-overview)
2. [Design Principles](#design-principles)
3. [Component 1: MCP Server](#component-1-mcp-server)
4. [Component 2: Slash Commands](#component-2-slash-commands)
5. [Component 3: Prompt Templates](#component-3-prompt-templates)
6. [Component 4: Skills Mapping](#component-4-skills-mapping)
7. [Workflows](#workflows)
8. [Implementation Plan](#implementation-plan)
9. [Technical Challenges](#technical-challenges)
10. [Testing Strategy](#testing-strategy)

---

## Architecture Overview

### High-Level Flow

```
┌─────────────────────────────────────┐
│      User in Codex CLI              │
│  /prompts:spectacular-execute       │
└──────────────┬──────────────────────┘
               │ (slash command calls MCP tool)
               ▼
┌─────────────────────────────────────┐
│   Spectacular MCP Server (Node.js)  │
│   Tools:                            │
│   - spectacular_execute             │
│   - spectacular_status              │
│   - spectacular_spec                │
│   - spectacular_plan                │
└──────────────┬──────────────────────┘
               │ (spawns via Codex SDK)
               ▼
┌─────────────────────────────────────┐
│   Codex SDK: Multiple Threads       │
│   ├─ Thread 1 → worktree-1          │
│   ├─ Thread 2 → worktree-2          │
│   └─ Thread 3 → worktree-3          │
└──────────────┬──────────────────────┘
               │ (work happens in git)
               ▼
┌─────────────────────────────────────┐
│   Git Worktrees + Branches          │
│   - .worktrees/{runid}-task-1       │
│   - .worktrees/{runid}-task-2       │
│   - Branches: {runid}-task-*        │
└─────────────────────────────────────┘
```

### Key Architectural Decisions

**1. User stays in Codex CLI**

- All commands invoked via `/prompts:spectacular-*` slash commands
- Slash commands call MCP tools
- Status updates visible in CLI session
- No external tool invocation required

**2. MCP server handles orchestration only**

- Parses plans, manages phases
- Spawns Codex threads via SDK (`@openai/codex`)
- Tracks job status (not output streaming)
- Coordinates parallel execution

**3. Codex threads do actual work**

- Each thread = isolated worktree
- Threads run in parallel via `Promise.all()`
- Work happens in git (branches, commits)
- MCP tracks completion via branch existence

**4. Skills become embedded prompts**

- NOT separate Agent instances
- Skills are instructions within prompts sent to Codex threads
- Codex interprets skill references ("Use phase-task-verification skill...")
- Same methodology, different runtime

**5. State lives in git + MCP job tracker**

- Git branches = source of truth for completion
- MCP tracks: running/completed/failed status
- Resume logic checks git branches, not MCP state
- Job tracker only for real-time status queries

---

## Design Principles

### From Spectacular → Codex MCP

| Spectacular                  | Codex MCP Equivalent         | Implementation                               |
| ---------------------------- | ---------------------------- | -------------------------------------------- |
| Task tool subagents          | Codex SDK threads            | `new Codex().startThread()` per task         |
| Skills (process docs)        | Embedded prompt instructions | "Follow TDD skill..." in prompt              |
| TodoWrite                    | Structured output schemas    | Codex SDK `outputSchema` parameter           |
| execute.md orchestrator      | MCP server logic             | TypeScript orchestration                     |
| Subagent dispatch (parallel) | `Promise.all()` threads      | Concurrent Codex instances                   |
| Git worktrees                | Same                         | Each thread in separate worktree             |
| Git-spice stacking           | Same                         | MCP calls `gs` commands after tasks complete |
| Code review subagent         | Codex thread for review      | Separate thread with review prompt           |

### Non-Goals

**What we're NOT building:**

- ❌ Agents SDK integration (adds unnecessary layer)
- ❌ Output streaming from threads (git branches are state)
- ❌ Porting skills to "Codex-capable" versions (they're prompts now)
- ❌ Interactive approval gates (autonomous execution with review loops)
- ❌ Separate CLI tool (everything in Codex CLI)

**Why these are non-goals:**

- Agents SDK is for building agents that delegate to tools; we need direct Codex thread orchestration
- Streaming output doesn't add value when git state is truth
- Skills work as embedded instructions without modification
- Spectacular already has autonomous execution via code review loops
- User experience must be native Codex CLI

---

## Component 1: MCP Server

### Technology Stack

- **Language:** TypeScript/Node.js
- **SDK:** `@openai/codex` (for thread spawning)
- **MCP SDK:** `@modelcontextprotocol/sdk`
- **Transport:** stdio (standard for Codex MCP servers)

### Project Structure

```
spectacular-mcp/
├── src/
│   ├── index.ts                 # MCP server entry point
│   ├── handlers/
│   │   ├── execute.ts          # spectacular_execute tool
│   │   ├── status.ts           # spectacular_status tool
│   │   ├── spec.ts             # spectacular_spec tool
│   │   └── plan.ts             # spectacular_plan tool
│   ├── orchestrator/
│   │   ├── parallel-phase.ts   # Parallel phase execution
│   │   ├── sequential-phase.ts # Sequential phase execution
│   │   └── code-review.ts      # Code review loops
│   ├── prompts/
│   │   ├── task-executor.ts    # Task execution prompt template
│   │   ├── code-reviewer.ts    # Code review prompt template
│   │   ├── fixer.ts            # Fix issues prompt template
│   │   └── spec-generator.ts   # Spec generation prompt template
│   ├── utils/
│   │   ├── git.ts              # Git/worktree operations
│   │   ├── plan-parser.ts      # Plan.md parsing
│   │   └── branch-tracker.ts   # Branch verification
│   └── types.ts                # TypeScript interfaces
├── package.json
├── tsconfig.json
└── README.md
```

### Core Interfaces

```typescript
// src/types.ts

export interface ExecutionJob {
  runId: string;
  status: "running" | "completed" | "failed";
  phase: number;
  totalPhases: number;
  tasks: TaskStatus[];
  startedAt: Date;
  completedAt?: Date;
  error?: string;
}

export interface TaskStatus {
  id: string;
  phase: number;
  name: string;
  status: "pending" | "running" | "completed" | "failed";
  branch?: string;
  commit?: string;
  startedAt?: Date;
  completedAt?: Date;
  error?: string;
}

export interface Plan {
  runId: string;
  featureSlug: string;
  phases: Phase[];
}

export interface Phase {
  id: number;
  name: string;
  strategy: "sequential" | "parallel";
  tasks: Task[];
}

export interface Task {
  id: string;
  phase: number;
  name: string;
  files: string[];
  acceptance_criteria: string[];
  dependencies: string[];
  complexity: "S" | "M" | "L";
  estimated_hours: number;
}

export interface CodexThreadResult {
  success: boolean;
  task?: string;
  branch?: string;
  commit?: string;
  error?: string;
  output: string;
}
```

### MCP Server Implementation

```typescript
// src/index.ts

import { Codex } from "@openai/codex";
import { Server } from "@modelcontextprotocol/sdk/server/index.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import {
  CallToolRequestSchema,
  ListToolsRequestSchema,
} from "@modelcontextprotocol/sdk/types.js";
import { ExecutionJob, Plan, TaskStatus } from "./types.js";
import { executeParallelPhase } from "./orchestrator/parallel-phase.js";
import { executeSequentialPhase } from "./orchestrator/sequential-phase.js";
import { parsePlan } from "./utils/plan-parser.js";

export class SpectacularMCP {
  private jobs = new Map<string, ExecutionJob>();
  private server: Server;

  constructor() {
    this.server = new Server(
      {
        name: "spectacular-mcp",
        version: "1.0.0",
      },
      {
        capabilities: {
          tools: {},
        },
      }
    );

    this.setupHandlers();
  }

  private setupHandlers() {
    // List available tools
    this.server.setRequestHandler(ListToolsRequestSchema, async () => ({
      tools: [
        {
          name: "spectacular_execute",
          description:
            "Execute implementation plan with parallel orchestration",
          inputSchema: {
            type: "object",
            properties: {
              plan_path: {
                type: "string",
                description: "Path to plan.md file",
              },
              review_frequency: {
                type: "string",
                enum: ["per-phase", "optimize", "end-only", "skip"],
                description: "When to run code reviews",
              },
            },
            required: ["plan_path"],
          },
        },
        {
          name: "spectacular_status",
          description: "Get execution status for a run",
          inputSchema: {
            type: "object",
            properties: {
              run_id: {
                type: "string",
                description: "Run ID returned from spectacular_execute",
              },
            },
            required: ["run_id"],
          },
        },
        {
          name: "spectacular_spec",
          description: "Generate feature specification",
          inputSchema: {
            type: "object",
            properties: {
              feature_description: {
                type: "string",
                description: "Feature to specify",
              },
            },
            required: ["feature_description"],
          },
        },
        {
          name: "spectacular_plan",
          description: "Decompose spec into execution plan",
          inputSchema: {
            type: "object",
            properties: {
              spec_path: {
                type: "string",
                description: "Path to spec.md file",
              },
            },
            required: ["spec_path"],
          },
        },
      ],
    }));

    // Handle tool calls
    this.server.setRequestHandler(CallToolRequestSchema, async (request) => {
      switch (request.params.name) {
        case "spectacular_execute":
          return this.handleExecute(request.params.arguments);
        case "spectacular_status":
          return this.handleStatus(request.params.arguments);
        case "spectacular_spec":
          return this.handleSpec(request.params.arguments);
        case "spectacular_plan":
          return this.handlePlan(request.params.arguments);
        default:
          throw new Error(`Unknown tool: ${request.params.name}`);
      }
    });
  }

  private async handleExecute(args: any) {
    const planPath = args.plan_path as string;
    const reviewFrequency =
      args.review_frequency || process.env.REVIEW_FREQUENCY || "per-phase";

    // Parse plan
    const plan = await parsePlan(planPath);
    const { runId, featureSlug } = plan;

    // Create job tracker
    const job: ExecutionJob = {
      runId,
      status: "running",
      phase: 1,
      totalPhases: plan.phases.length,
      tasks: [],
      startedAt: new Date(),
    };
    this.jobs.set(runId, job);

    // Execute phases (non-blocking - runs in background)
    this.executePhases(plan, job, reviewFrequency).catch((err) => {
      job.status = "failed";
      job.error = String(err);
      console.error("Execution failed:", err);
    });

    // Return immediately with job info
    return {
      content: [
        {
          type: "text",
          text: JSON.stringify(
            {
              run_id: runId,
              feature: featureSlug,
              status: "started",
              total_phases: plan.phases.length,
              total_tasks: plan.phases.flatMap((p) => p.tasks).length,
              message: `Executing ${plan.phases.length} phases with parallel orchestration`,
              poll_with: `spectacular_status({"run_id": "${runId}"})`,
            },
            null,
            2
          ),
        },
      ],
    };
  }

  private async executePhases(
    plan: Plan,
    job: ExecutionJob,
    reviewFrequency: string
  ) {
    for (const phase of plan.phases) {
      job.phase = phase.id;

      try {
        if (phase.strategy === "parallel") {
          await executeParallelPhase(phase, plan, job, reviewFrequency);
        } else {
          await executeSequentialPhase(phase, plan, job, reviewFrequency);
        }
      } catch (error) {
        job.status = "failed";
        job.error = `Phase ${phase.id} failed: ${error}`;
        throw error;
      }
    }

    job.status = "completed";
    job.completedAt = new Date();
  }

  private async handleStatus(args: any) {
    const runId = args.run_id as string;
    const job = this.jobs.get(runId);

    if (!job) {
      return {
        content: [
          {
            type: "text",
            text: JSON.stringify({
              error: `Job not found: ${runId}`,
              available_jobs: Array.from(this.jobs.keys()),
            }),
          },
        ],
      };
    }

    const elapsed = Date.now() - job.startedAt.getTime();
    const completedTasks = job.tasks.filter(
      (t) => t.status === "completed"
    ).length;
    const runningTasks = job.tasks.filter((t) => t.status === "running").length;
    const failedTasks = job.tasks.filter((t) => t.status === "failed").length;

    return {
      content: [
        {
          type: "text",
          text: JSON.stringify(
            {
              run_id: job.runId,
              status: job.status,
              phase: `${job.phase}/${job.totalPhases}`,
              tasks: {
                completed: completedTasks,
                running: runningTasks,
                failed: failedTasks,
                total: job.tasks.length,
              },
              task_details: job.tasks.map((t) => ({
                id: t.id,
                name: t.name,
                status: t.status,
                branch: t.branch,
                error: t.error,
              })),
              elapsed_ms: elapsed,
              elapsed_human: this.formatDuration(elapsed),
              error: job.error,
            },
            null,
            2
          ),
        },
      ],
    };
  }

  private formatDuration(ms: number): string {
    const seconds = Math.floor(ms / 1000);
    const minutes = Math.floor(seconds / 60);
    const hours = Math.floor(minutes / 60);

    if (hours > 0) {
      return `${hours}h ${minutes % 60}m`;
    } else if (minutes > 0) {
      return `${minutes}m ${seconds % 60}s`;
    } else {
      return `${seconds}s`;
    }
  }

  async run() {
    const transport = new StdioServerTransport();
    await this.server.connect(transport);
    console.error("Spectacular MCP Server running on stdio");
  }
}

// Start server
const server = new SpectacularMCP();
server.run().catch(console.error);
```

### Parallel Phase Orchestrator

```typescript
// src/orchestrator/parallel-phase.ts

import { Codex } from "@openai/codex";
import {
  Phase,
  Plan,
  ExecutionJob,
  TaskStatus,
  CodexThreadResult,
} from "../types.js";
import { generateTaskPrompt } from "../prompts/task-executor.js";
import {
  createWorktrees,
  stackBranches,
  cleanupWorktrees,
} from "../utils/git.js";
import { runCodeReview } from "./code-review.js";

export async function executeParallelPhase(
  phase: Phase,
  plan: Plan,
  job: ExecutionJob,
  reviewFrequency: string
): Promise<void> {
  console.error(
    `\n🔀 Executing Phase ${phase.id} (parallel): ${phase.tasks.length} tasks`
  );

  // Step 1: Pre-conditions verification
  await verifyPreconditions(plan.runId, phase);

  // Step 2: Check for existing work (resume support)
  const { completedTasks, pendingTasks } = await checkExistingWork(
    phase,
    plan.runId
  );

  if (pendingTasks.length === 0) {
    console.error(`✅ All tasks already complete, skipping to stacking`);
    await stackBranches(
      completedTasks.map((t) => t.branch!),
      plan.runId
    );
    return;
  }

  console.error(
    `📋 Resuming: ${completedTasks.length} complete, ${pendingTasks.length} pending`
  );

  // Step 3: Create worktrees for pending tasks
  await createWorktrees(pendingTasks, plan.runId);

  // Step 4: Install dependencies per worktree
  await installDependencies(pendingTasks, plan.runId);

  // Step 5: Spawn parallel Codex threads
  const results = await spawnParallelTasks(pendingTasks, plan, job);

  // Step 6: Verify all succeeded
  const failed = results.filter((r) => !r.success);
  if (failed.length > 0) {
    throw new Error(
      `${failed.length} tasks failed:\n` +
        failed.map((f) => `  - Task ${f.task}: ${f.error}`).join("\n")
    );
  }

  // Step 7: Stack branches
  const allBranches = [
    ...completedTasks.map((t) => t.branch!),
    ...results.map((r) => r.branch!),
  ];
  await stackBranches(allBranches, plan.runId);

  // Step 8: Cleanup worktrees
  await cleanupWorktrees(pendingTasks, plan.runId);

  // Step 9: Code review (if needed)
  if (shouldRunReview(reviewFrequency, phase)) {
    await runCodeReview(phase, plan, job);
  }

  console.error(`✅ Phase ${phase.id} complete`);
}

async function spawnParallelTasks(
  tasks: Task[],
  plan: Plan,
  job: ExecutionJob
): Promise<CodexThreadResult[]> {
  console.error(`\n🚀 Spawning ${tasks.length} parallel Codex threads...`);

  const threadPromises = tasks.map(async (task) => {
    // Create task status tracker
    const taskStatus: TaskStatus = {
      id: task.id,
      phase: task.phase,
      name: task.name,
      status: "running",
      startedAt: new Date(),
    };
    job.tasks.push(taskStatus);

    try {
      // Create Codex instance for this task
      const codex = new Codex({
        workingDirectory: `.worktrees/${plan.runId}-task-${task.id}`,
      });
      const thread = codex.startThread();

      // Generate task prompt from template
      const prompt = generateTaskPrompt(task, plan);

      console.error(
        `  ⏺ Task ${task.id}: Started in worktree .worktrees/${plan.runId}-task-${task.id}`
      );

      // Run task (blocking for this thread, parallel across all threads)
      const turn = await thread.run(prompt);

      // Extract branch name from output
      const branch = extractBranchName(turn.finalResponse);
      const commit = extractCommitSha(turn.finalResponse);

      // Update status
      taskStatus.status = "completed";
      taskStatus.branch = branch;
      taskStatus.commit = commit;
      taskStatus.completedAt = new Date();

      console.error(`  ✅ Task ${task.id}: Complete (${branch})`);

      return {
        success: true,
        task: task.id,
        branch,
        commit,
        output: turn.finalResponse,
      };
    } catch (error) {
      taskStatus.status = "failed";
      taskStatus.error = String(error);
      taskStatus.completedAt = new Date();

      console.error(`  ❌ Task ${task.id}: Failed - ${error}`);

      return {
        success: false,
        task: task.id,
        error: String(error),
        output: "",
      };
    }
  });

  // Wait for all tasks to complete
  return await Promise.all(threadPromises);
}

function shouldRunReview(reviewFrequency: string, phase: Phase): boolean {
  if (reviewFrequency === "skip" || reviewFrequency === "end-only") {
    return false;
  }

  if (reviewFrequency === "per-phase") {
    return true;
  }

  if (reviewFrequency === "optimize") {
    // Analyze phase for risk indicators
    return analyzePhaseRisk(phase);
  }

  return false;
}

function analyzePhaseRisk(phase: Phase): boolean {
  // High-risk indicators from executing-parallel-phase skill
  const highRiskPatterns = [
    /schema|migration|prisma/i,
    /auth|authorization|permission/i,
    /api|webhook|integration/i,
    /foundation|phase-1|phase-2/i,
    /security|payment|pii/i,
  ];

  const phaseContent = JSON.stringify(phase).toLowerCase();

  return highRiskPatterns.some((pattern) => pattern.test(phaseContent));
}
```

### Code Review Orchestrator

```typescript
// src/orchestrator/code-review.ts

import { Codex } from "@openai/codex";
import { Phase, Plan, ExecutionJob } from "../types.js";
import {
  generateReviewPrompt,
  generateFixerPrompt,
} from "../prompts/code-reviewer.js";

export async function runCodeReview(
  phase: Phase,
  plan: Plan,
  job: ExecutionJob
): Promise<void> {
  console.error(`\n🔍 Code review: Phase ${phase.id}...`);

  const codex = new Codex({
    workingDirectory: `.worktrees/${plan.runId}-main`,
  });
  const thread = codex.startThread();

  let rejectionCount = 0;
  const MAX_REJECTIONS = 3;

  while (rejectionCount <= MAX_REJECTIONS) {
    // Dispatch code review
    const reviewPrompt = generateReviewPrompt(
      phase,
      plan,
      rejectionCount === 0
    );
    const reviewResult = await thread.run(reviewPrompt);

    // Parse binary verdict
    const verdict = parseReviewVerdict(reviewResult.finalResponse);

    if (verdict === "approved") {
      console.error(
        `✅ Code review APPROVED${
          rejectionCount > 0
            ? ` (after ${rejectionCount} fix iteration(s))`
            : ""
        }`
      );
      return;
    }

    if (verdict === "malformed") {
      // Retry once
      if (rejectionCount === 0) {
        console.error(`⚠️  Code review output malformed - retrying once`);
        continue;
      } else {
        throw new Error("Code review failed twice with malformed output");
      }
    }

    // Rejected - dispatch fixer
    rejectionCount++;

    if (rejectionCount > MAX_REJECTIONS) {
      throw new Error(
        `Code review rejected ${MAX_REJECTIONS} times. ` +
          `Issues may require architectural changes. Manual intervention needed.`
      );
    }

    console.error(`❌ Code review REJECTED (attempt ${rejectionCount})`);
    console.error(`🔧 Dispatching fix subagent...`);

    // Dispatch fixer in same thread (maintains conversation context)
    const fixerPrompt = generateFixerPrompt(reviewResult.finalResponse, plan);
    await thread.run(fixerPrompt);

    console.error(`⏺  Re-reviewing Phase ${phase.id} after fixes...`);
  }
}

function parseReviewVerdict(
  output: string
): "approved" | "rejected" | "malformed" {
  // Binary parsing from executing-parallel-phase Step 8
  if (output.includes("Ready to merge? Yes")) {
    return "approved";
  }

  if (
    output.includes("Ready to merge? No") ||
    output.includes("Ready to merge? With fixes")
  ) {
    return "rejected";
  }

  // Missing "Ready to merge?" field or no output
  if (!output.includes("Ready to merge?") || output.trim().length === 0) {
    return "malformed";
  }

  // Soft language (treated as rejection)
  return "rejected";
}
```

---

## Component 2: Slash Commands

Slash commands are Markdown files in `~/.codex/prompts/` that expand to prompts and call MCP tools.

### File: `~/.codex/prompts/spectacular-execute.md`

````markdown
---
description: Execute implementation plan with parallel orchestration
argument-hint: plan.md path
---

You are executing a Spectacular implementation plan with parallel task orchestration.

**Plan:** $1

## Instructions

1. Call the MCP tool to start parallel execution:

```json
{
  "tool": "spectacular_execute",
  "plan_path": "$1"
}
```
````

The orchestrator will:

- Parse plan and identify parallel phases
- Create isolated git worktrees for each task
- Spawn parallel Codex threads (one per task)
- Track execution status
- Stack branches after completion
- Run code review gates

2. The tool returns a `run_id`. Poll for status updates:

```json
{
  "tool": "spectacular_status",
  "run_id": "{returned_run_id}"
}
```

3. Poll every 30 seconds until status is "completed" or "failed".

4. Report final status to user with:
   - Total tasks completed
   - Branches created
   - Time elapsed
   - Next steps (review changes, submit PRs)

## Error Handling

If execution fails:

- Display error message from status response
- Check task_details for failed tasks
- Suggest: Review subagent output, fix issues manually, re-run execute

## Example Usage

```
/prompts:spectacular-execute @specs/abc123-magic-link/plan.md
```

````

### File: `~/.codex/prompts/spectacular-status.md`

```markdown
---
description: Check execution status for a Spectacular run
argument-hint: run_id
---

You are checking execution status for a Spectacular run.

**Run ID:** $1

## Instructions

Call the MCP tool:

```json
{
  "tool": "spectacular_status",
  "run_id": "$1"
}
````

Display the status in a formatted table:

```
📊 Execution Status: {run_id}
Status: {status}
Phase: {current_phase}/{total_phases}
Tasks: {completed}/{total} completed, {running} running, {failed} failed
Elapsed: {elapsed_human}
```

If running, show task details:

```
Tasks in progress:
  ✅ Task 1-1: database-schema (completed - abc123-task-1-1-database)
  🔄 Task 1-2: service-layer (running)
  ⏳ Task 1-3: api-routes (pending)
```

If completed, show next steps:

- Review changes with `gs log short`
- Submit stack with `gs stack submit`
- Or continue work with `gs branch create`

If failed, show error and suggest fixes.

## Example Usage

```
/prompts:spectacular-status abc123
```

````

### File: `~/.codex/prompts/spectacular-spec.md`

```markdown
---
description: Generate feature specification using brainstorming
argument-hint: feature description
---

You are generating a feature specification using Spectacular's methodology.

**Feature:** $ARGUMENTS

## Instructions

1. Call the MCP tool to start spec generation:

```json
{
  "tool": "spectacular_spec",
  "feature_description": "$ARGUMENTS"
}
````

The tool will:

- Generate a unique run ID
- Create isolated worktree
- Run brainstorming (3 phases: Understanding, Exploration, Design)
- Generate spec.md with constitution compliance
- Validate spec quality
- Commit to worktree branch

2. The tool returns the spec location. Report to user:

```
✅ Feature Specification Complete

RUN_ID: {run_id}
Location: .worktrees/{run_id}-main/specs/{run_id}-{slug}/spec.md

Next Steps:
1. Review the spec
2. Create plan: /prompts:spectacular-plan @.worktrees/{run_id}-main/specs/{run_id}-{slug}/spec.md
```

## Example Usage

```
/prompts:spectacular-spec magic link authentication with Auth.js
```

````

### File: `~/.codex/prompts/spectacular-plan.md`

```markdown
---
description: Decompose spec into execution plan with parallel phases
argument-hint: spec.md path
---

You are decomposing a feature specification into an execution plan.

**Spec:** $1

## Instructions

1. Call the MCP tool to start plan generation:

```json
{
  "tool": "spectacular_plan",
  "spec_path": "$1"
}
````

The tool will:

- Parse spec and extract/design tasks
- Analyze file dependencies
- Group tasks into sequential/parallel phases
- Calculate parallelization time savings
- Generate plan.md

2. The tool returns the plan location and summary. Report to user:

```
✅ Task Decomposition Complete

Plan: {plan_path}
Phases: {total_phases}
Tasks: {total_tasks}
Strategy: {sequential_count} sequential, {parallel_count} parallel

Time Estimates:
- Sequential: {sequential_hours}h
- With Parallelization: {parallel_hours}h
- Time Savings: {savings_hours}h ({savings_percent}%)

Next Steps:
1. Review plan: cat {plan_path}
2. Execute: /prompts:spectacular-execute @{plan_path}
```

## Example Usage

```
/prompts:spectacular-plan @.worktrees/abc123-main/specs/abc123-magic-link/spec.md
```

````

---

## Component 3: Prompt Templates

Prompt templates are TypeScript functions that generate prompts for Codex threads. They embed Spectacular skill instructions.

### Task Executor Prompt

```typescript
// src/prompts/task-executor.ts

import { Task, Plan } from '../types.js';

export function generateTaskPrompt(task: Task, plan: Plan): string {
  const laterPhases = plan.phases
    .filter(p => p.id > task.phase)
    .map(p => `- Phase ${p.id}: ${p.name} - ${p.tasks.map(t => t.name).join(', ')}`)
    .join('\n');

  return `
You are implementing Task ${task.id}: ${task.name}

## Context

**WORKTREE:** .worktrees/${plan.runId}-task-${task.id}
**SPEC:** specs/${plan.runId}-${plan.featureSlug}/spec.md
**CONSTITUTION:** docs/constitutions/current/

## Task Details

**Files to modify:**
${task.files.map(f => `- ${f}`).join('\n')}

**Acceptance Criteria:**
${task.acceptance_criteria.map(c => `- [ ] ${c}`).join('\n')}

## Phase Boundaries - CRITICAL

**Phase ${task.phase}/${plan.phases.length}: This task ONLY**

This phase includes ONLY: Task ${task.id}

**DO NOT CREATE ANY FILES from later phases.**

Later phases (DO NOT CREATE):
${laterPhases}

If tempted to create ANY file from later phases, STOP.
- "Not fully implemented" = violation
- "Just types/stubs/tests" = violation
- "Temporary/for testing" = violation

## Your Process

Follow these steps exactly (from phase-task-verification and test-driven-development skills):

### 1. Navigate to Worktree
\`\`\`bash
cd .worktrees/${plan.runId}-task-${task.id}
\`\`\`

### 2. Read Context
- Read constitution (if exists): docs/constitutions/current/
- Read feature specification: specs/${plan.runId}-${plan.featureSlug}/spec.md
- Understand WHAT to build (requirements, user flows, architecture)
- Understand WHY decisions were made (rationale)

### 3. Verify Phase Scope
- Confirm this task belongs to Phase ${task.phase}
- Do NOT implement work from later phases
- The plan exists for a reason - respect phase boundaries

### 4. Implement Task (TDD)
Follow test-driven-development skill:
- Write test first
- Watch it fail
- Write minimal code to pass
- Watch it pass
- Refactor if needed

### 5. Run Quality Checks
\`\`\`bash
# Use heredoc to prevent parsing errors
bash <<'EOF'
npm test
if [ $? -ne 0 ]; then
  echo "❌ Tests failed"
  exit 1
fi

npm run lint
if [ $? -ne 0 ]; then
  echo "❌ Lint failed"
  exit 1
fi

npm run build
if [ $? -ne 0 ]; then
  echo "❌ Build failed"
  exit 1
fi
EOF
\`\`\`

### 6. Create Branch and Commit
Use phase-task-verification skill:
\`\`\`bash
# Stage changes
git add .

# Create branch with git-spice
gs branch create ${plan.runId}-task-${task.phase}-${task.id}-{short-name} -m "Task ${task.id}: ${task.name}"

# Commit
git commit -m "feat: ${task.name}

[Task ${task.phase}.${task.id}]

${task.acceptance_criteria.map(c => `- ${c}`).join('\n')}"
\`\`\`

### 7. Detach HEAD (CRITICAL)
\`\`\`bash
git switch --detach
\`\`\`

This makes the branch accessible in the parent repo for stacking.

### 8. Report Completion
Output the branch name and commit SHA:
\`\`\`
BRANCH: {branch-name}
COMMIT: {commit-sha}
\`\`\`

## Critical Rules

- Work in .worktrees/${plan.runId}-task-${task.id}, NOT main repo
- Do NOT stay on branch - must detach HEAD at end
- Do NOT create additional worktrees
- Do NOT implement work from later phases
- Follow constitution for all code patterns
- Use TDD (test first, minimal code)
- Run all quality checks before committing
`;
}
````

### Code Review Prompt

```typescript
// src/prompts/code-reviewer.ts

import { Phase, Plan } from "../types.js";

export function generateReviewPrompt(
  phase: Phase,
  plan: Plan,
  isFirstReview: boolean
): string {
  const instruction = isFirstReview
    ? "This is your ONLY opportunity to find issues. Check EVERYTHING now."
    : "Re-review after fixes applied.";

  return `
You are reviewing Phase ${phase.id} implementation.

## Context

**WORKTREE:** .worktrees/${plan.runId}-main
**SPEC:** specs/${plan.runId}-${plan.featureSlug}/spec.md
**PLAN:** specs/${plan.runId}-${plan.featureSlug}/plan.md

## Instructions

${instruction}

Use the requesting-code-review skill from Superpowers to dispatch code-reviewer subagent.

Provide these details to the reviewer:
- Phase: ${phase.id}
- Tasks: ${phase.tasks.map((t) => `${t.id} (${t.name})`).join(", ")}
- Base branch: {previous-phase-branch}
- Spec path: specs/${plan.runId}-${plan.featureSlug}/spec.md
- Plan path: specs/${plan.runId}-${plan.featureSlug}/plan.md

## What to Check

**CRITICAL - Exhaustive First-Pass Review:**

Check EVERYTHING in this single review:
- [ ] Implementation correctness - logic bugs, edge cases, error handling
- [ ] Test correctness - expectations match behavior, complete coverage
- [ ] Cross-file consistency - logic coherent across all files
- [ ] Architectural soundness - follows patterns, proper separation
- [ ] Scope adherence - implements ONLY Phase ${phase.id} work
- [ ] Constitution compliance - follows all project standards

## Output Format

The code-reviewer subagent must return a binary verdict:

**"Ready to merge? Yes"** - Only if EVERYTHING passes

OR

**"Ready to merge? No"** - List ALL issues found with:
- Severity: Critical/Important/Minor
- File location: path/to/file.ts:123
- Issue description
- Fix guidance

## Critical Rules

- Binary verdict ONLY (Yes or No)
- No soft language ("approved with minor suggestions")
- Find ALL issues in first review
- If you catch yourself thinking "I'll check that in re-review" - STOP. Check it NOW.
`;
}

export function generateFixerPrompt(reviewOutput: string, plan: Plan): string {
  return `
Fix the following issues from code review:

${reviewOutput}

## Context for Fixes

1. Read constitution (if exists): docs/constitutions/current/
2. Read feature specification: specs/${plan.runId}-${plan.featureSlug}/spec.md
3. Read implementation plan: specs/${plan.runId}-${plan.featureSlug}/plan.md

## Fix Strategy

**If scope creep detected (implemented work from later phases):**
- Roll back to current phase scope ONLY
- Remove implementations that belong to later phases
- Keep ONLY the work defined in current phase tasks
- The plan exists for a reason - respect phase boundaries

**For other issues:**
- Apply fixes following spec + constitution + plan boundaries
- Maintain architectural consistency
- Add tests if coverage gaps found
- Fix logic errors with edge case handling

## Your Process

1. Analyze all issues listed above
2. Apply fixes in .worktrees/${plan.runId}-main
3. Run all quality checks (test, lint, build)
4. Amend existing commit OR add new commit (do NOT create new branch)
5. Verify all issues resolved
6. Report completion

## Critical Rules

- Work in .worktrees/${plan.runId}-main
- Amend existing branch or add commit (NO new branch)
- Run quality checks before completion
- If scope creep, implement LESS not ask user
- Verify all issues fixed before reporting
`;
}
```

---

## Component 4: Skills Mapping

Spectacular skills are NOT ported to separate agents. They're embedded as instructions in prompts sent to Codex threads.

### Skill → Prompt Mapping

| Spectacular Skill                | Where Used in Codex      | Implementation                                            |
| -------------------------------- | ------------------------ | --------------------------------------------------------- |
| `executing-parallel-phase`       | MCP server orchestration | TypeScript logic in `parallel-phase.ts`                   |
| `executing-sequential-phase`     | MCP server orchestration | TypeScript logic in `sequential-phase.ts`                 |
| `phase-task-verification`        | Task executor prompt     | "Use phase-task-verification skill..." instruction        |
| `test-driven-development`        | Task executor prompt     | "Follow TDD: test first, watch fail, minimal code..."     |
| `requesting-code-review`         | Code review prompt       | "Use requesting-code-review skill..." instruction         |
| `writing-specs`                  | Spec generation prompt   | Embedded brainstorming + spec generation flow             |
| `decomposing-tasks`              | Plan generation prompt   | Embedded task extraction + dependency analysis            |
| `using-git-spice`                | All prompts              | Git-spice command examples in instructions                |
| `using-git-worktrees`            | MCP server + prompts     | Worktree creation logic + "work in worktree" instructions |
| `verification-before-completion` | Task executor prompt     | "Run quality checks: test, lint, build" steps             |

### Example: How Skills Work in Prompts

**Spectacular (Claude Code):**

```
Task tool dispatch → Subagent receives Task tool call → Reads SKILL.md file → Follows instructions
```

**Codex MCP:**

```
MCP server → Generates prompt with embedded skill instructions → Codex thread interprets → Follows instructions
```

**Key difference:** Skills are NOT separate files Codex reads. They're baked into the prompt templates.

### Skill Instruction Embedding Pattern

```typescript
// Pattern for embedding skills in prompts:

function embedSkill(skillName: string, context: any): string {
  // Reference the skill by name for clarity
  const header = `Use ${skillName} skill:`;

  // Embed the key instructions from that skill
  const instructions = getSkillInstructions(skillName, context);

  return `${header}\n\n${instructions}`;
}

// Example for TDD skill:
function embedTDD(): string {
  return `
Use test-driven-development skill:

1. Write test first
2. Watch it fail (run test, verify failure)
3. Write minimal code to pass
4. Watch it pass (run test, verify success)
5. Refactor if needed (while keeping tests passing)

NO implementing before test exists.
NO skipping "watch fail" step.
NO writing more code than needed to pass.
`;
}
```

---

## Workflows

### Workflow 1: Full Feature Development

**User in Codex CLI:**

```
> /prompts:spectacular-spec magic link authentication with Auth.js

[Codex calls spectacular_spec MCP tool]
[MCP spawns Codex thread for brainstorming + spec generation]

✅ Feature Specification Complete
RUN_ID: abc123
Location: .worktrees/abc123-main/specs/abc123-magic-link/spec.md

> /prompts:spectacular-plan @.worktrees/abc123-main/specs/abc123-magic-link/spec.md

[Codex calls spectacular_plan MCP tool]
[MCP spawns Codex thread for task decomposition]

✅ Task Decomposition Complete
Plan: .worktrees/abc123-main/specs/abc123-magic-link/plan.md
Phases: 3 (2 sequential, 1 parallel)
Tasks: 8
Time: 24h sequential → 16h parallel (33% faster)

> /prompts:spectacular-execute @.worktrees/abc123-main/specs/abc123-magic-link/plan.md

[Codex calls spectacular_execute MCP tool]
[MCP returns immediately with run_id: abc123]

🔄 Executing plan...
Run ID: abc123
Poll with: /prompts:spectacular-status abc123

> /prompts:spectacular-status abc123

[Codex calls spectacular_status MCP tool]

📊 Execution Status: abc123
Status: running
Phase: 1/3
Tasks: 1/3 completed, 2/3 running, 0 failed
Elapsed: 12m 34s

Tasks in progress:
  ✅ Task 1-1: database-schema (abc123-task-1-1-database)
  🔄 Task 1-2: service-layer
  🔄 Task 1-3: api-routes

[Poll again after 30s...]

> /prompts:spectacular-status abc123

✅ Execution Complete!
Status: completed
Phases: 3/3
Tasks: 8/8 completed
Elapsed: 2h 45m

Next steps:
- Review changes: gs log short
- Submit stack: gs stack submit
```

### Workflow 2: Resume After Failure

```
> /prompts:spectacular-execute @specs/abc123-magic-link/plan.md

🔄 Executing Phase 2 (parallel): 3 tasks...
  ✅ Task 2-1: Complete
  ❌ Task 2-2: Failed - tests failed
  ✅ Task 2-3: Complete

❌ Execution failed: 1 task failed

[User fixes manually in worktree]

> cd .worktrees/abc123-task-2-2
> npm test  # Fix issues
> git add .
> gs branch create abc123-task-2-2-auth-middleware -m "Task 2.2: Auth middleware"
> git switch --detach
> cd ../..

> /prompts:spectacular-execute @specs/abc123-magic-link/plan.md

📋 Resuming: 2 complete, 1 pending
[Executes only the failed task]
✅ Phase 2 complete
```

### Workflow 3: Code Review Loop

```
🔍 Code review: Phase 1...

[Code reviewer finds issues]

❌ Code review REJECTED (attempt 1)
Issues found:
  - Critical: Missing error handling in auth.service.ts:45
  - Important: Test coverage gap in auth.test.ts

🔧 Dispatching fix subagent...

[Fixer applies changes]

⏺ Re-reviewing Phase 1 after fixes...

✅ Code review APPROVED (after 1 fix iteration)
Phase 1 complete - proceeding to Phase 2
```

---

## Implementation Plan

### Phase 1: MCP Server Core (Week 1)

**Goals:**

- Basic MCP server with stdio transport
- Tool registration (execute, status, spec, plan)
- Job state tracking
- Plan parsing

**Deliverables:**

- [ ] `src/index.ts` - MCP server skeleton
- [ ] `src/types.ts` - Core interfaces
- [ ] `src/utils/plan-parser.ts` - Parse plan.md files
- [ ] `src/handlers/status.ts` - Status tool handler
- [ ] Basic test: Create job, query status

### Phase 2: Parallel Orchestration (Week 2)

**Goals:**

- Spawn Codex threads via SDK
- Parallel task execution with `Promise.all()`
- Worktree creation/cleanup
- Branch verification

**Deliverables:**

- [ ] `src/orchestrator/parallel-phase.ts` - Full parallel logic
- [ ] `src/utils/git.ts` - Worktree + branch operations
- [ ] `src/prompts/task-executor.ts` - Task prompt template
- [ ] Test: Execute parallel phase with 3 tasks

### Phase 3: Code Review Integration (Week 3)

**Goals:**

- Code review prompt generation
- Binary verdict parsing
- Fix loop with rejection limit
- Review frequency logic (per-phase/optimize/skip)

**Deliverables:**

- [ ] `src/orchestrator/code-review.ts` - Review orchestration
- [ ] `src/prompts/code-reviewer.ts` - Review + fixer prompts
- [ ] Test: Review rejection → fix → re-review loop

### Phase 4: Slash Commands (Week 4)

**Goals:**

- Slash command markdown files
- MCP configuration docs
- User setup guide

**Deliverables:**

- [ ] `~/.codex/prompts/spectacular-execute.md`
- [ ] `~/.codex/prompts/spectacular-status.md`
- [ ] `~/.codex/prompts/spectacular-spec.md`
- [ ] `~/.codex/prompts/spectacular-plan.md`
- [ ] `docs/codex-setup.md` - Installation guide

### Phase 5: Spec & Plan Generation (Week 5)

**Goals:**

- Spec generation with brainstorming
- Plan decomposition with dependency analysis
- Sequential phase support

**Deliverables:**

- [ ] `src/handlers/spec.ts` - Spec tool handler
- [ ] `src/handlers/plan.ts` - Plan tool handler
- [ ] `src/prompts/spec-generator.ts` - Spec prompt
- [ ] `src/prompts/plan-generator.ts` - Plan prompt
- [ ] `src/orchestrator/sequential-phase.ts` - Sequential execution

### Phase 6: Testing & Hardening (Week 6)

**Goals:**

- End-to-end tests
- Error handling polish
- Resume logic validation
- Documentation

**Deliverables:**

- [ ] Test suite: Full workflow (spec → plan → execute)
- [ ] Error handling: All failure modes
- [ ] Resume scenarios: Partial completion
- [ ] `README.md` - Complete usage guide

### Timeline Summary

- **Week 1-2:** Core MCP + parallel orchestration (MVP)
- **Week 3-4:** Code review + slash commands (Usable)
- **Week 5-6:** Full workflow + hardening (Complete)

**Total:** 6 weeks for full implementation

**MVP milestone (Week 2):** Can execute parallel plans from Codex CLI

---

## Technical Challenges

### Challenge 1: Codex Thread Isolation

**Problem:** Codex threads share nothing by default. How do we coordinate?

**Solution:**

- Each thread works in isolated worktree
- Git branches are coordination mechanism
- MCP server tracks status, not state
- Resume logic reads git branches, not MCP state

### Challenge 2: Long-Running Execution

**Problem:** MCP tool calls expect synchronous responses, execution takes hours

**Solution:**

- `spectacular_execute` returns immediately with `run_id`
- Execution continues in background (async)
- User polls with `spectacular_status`
- Status updates from job tracker, not thread output

### Challenge 3: Error Recovery

**Problem:** If one task fails in parallel phase, what happens to others?

**Solution:**

- `Promise.all()` waits for all threads
- Failed tasks marked in job tracker
- Verification step checks all branches exist
- Resume logic re-runs only failed tasks

### Challenge 4: Code Review State

**Problem:** Review rejection → fix → re-review requires conversation context

**Solution:**

- Use same Codex thread for review + fix loop
- Thread maintains conversation history
- Rejection count tracked in MCP server
- Max 3 rejections before escalation

### Challenge 5: Skill Interpretation

**Problem:** Codex threads don't have access to skill files, how do they follow them?

**Solution:**

- Skills embedded in prompt templates
- Key instructions extracted and formatted
- "Use X skill" becomes "Follow these steps from X skill: ..."
- Same methodology, different delivery mechanism

### Challenge 6: Resume Logic

**Problem:** If execution fails, how do we resume without re-running completed tasks?

**Solution:**

- Check git branches before creating worktrees
- Pattern match: `{runid}-task-{phase}-{task}-*`
- Skip tasks with existing branches
- Verify branches have commits beyond base

---

## Testing Strategy

### Unit Tests

**Target:** Individual functions (prompt generation, parsing, git operations)

```typescript
// Example: test prompt generation
describe('generateTaskPrompt', () => {
  it('embeds phase boundaries correctly', () => {
    const task = { id: '1', phase: 2, ... };
    const plan = { phases: [phase1, phase2, phase3], ... };

    const prompt = generateTaskPrompt(task, plan);

    expect(prompt).toContain('Phase 2/3');
    expect(prompt).toContain('DO NOT CREATE ANY FILES from later phases');
    expect(prompt).toContain('Phase 3:'); // Later phase listed
  });
});
```

### Integration Tests

**Target:** MCP server with mock Codex SDK

```typescript
// Example: test parallel execution
describe("executeParallelPhase", () => {
  it("spawns N threads and waits for all", async () => {
    const mockCodex = {
      startThread: jest.fn(() => ({
        run: jest.fn(async () => ({ finalResponse: "BRANCH: test-branch" })),
      })),
    };

    const phase = { tasks: [task1, task2, task3], strategy: "parallel" };

    await executeParallelPhase(phase, plan, job, "per-phase");

    expect(mockCodex.startThread).toHaveBeenCalledTimes(3);
    expect(job.tasks.filter((t) => t.status === "completed")).toHaveLength(3);
  });
});
```

### End-to-End Tests

**Target:** Full workflow from Codex CLI perspective

```bash
# Test script: test-e2e.sh

# Setup: Create test repo with constitution
git init test-repo
cd test-repo
# ... setup files ...

# Start MCP server in background
node dist/index.js &
MCP_PID=$!

# Simulate Codex CLI calling MCP tools
echo '{"tool": "spectacular_spec", "feature_description": "test feature"}' | node dist/index.js

# Check spec created
test -f .worktrees/*/specs/*/spec.md || exit 1

# Generate plan
echo '{"tool": "spectacular_plan", "spec_path": "..."}' | node dist/index.js

# Execute (with mock Codex for speed)
USE_MOCK_CODEX=1 echo '{"tool": "spectacular_execute", "plan_path": "..."}' | node dist/index.js

# Verify branches created
git branch | grep "task-" || exit 1

# Cleanup
kill $MCP_PID
```

### Scenario Tests

**Target:** Specific edge cases from Spectacular test scenarios

```typescript
// Port existing test scenarios from tests/scenarios/execute/
describe("Resume after partial failure", () => {
  it("skips completed tasks and re-runs failed only", async () => {
    // Create branches for tasks 1-1 and 1-3 (simulate partial completion)
    await createMockBranch("abc123-task-1-1-database");
    await createMockBranch("abc123-task-1-3-api");

    // Execute phase with 3 tasks
    const phase = { id: 1, tasks: [task1, task2, task3] };
    await executeParallelPhase(phase, plan, job, "skip");

    // Verify only task 1-2 was executed
    expect(mockCodex.startThread).toHaveBeenCalledTimes(1);
    expect(createdWorktrees).toEqual([".worktrees/abc123-task-1-2"]);
  });
});
```

---

## Next Steps

### Immediate Actions (Week 0)

1. **Create repository:** `spectacular-mcp`
2. **Setup project:**
   ```bash
   npm init -y
   npm install @openai/codex @modelcontextprotocol/sdk typescript @types/node
   npx tsc --init
   ```
3. **Create directory structure** per "Project Structure" above
4. **Port types** from Spectacular to `src/types.ts`
5. **Document decision log** in `docs/decisions.md`

### Validation Checklist

Before starting implementation, verify:

- [ ] Codex SDK can spawn multiple threads concurrently
- [ ] MCP stdio transport works with Codex CLI
- [ ] Git worktrees + detached HEAD pattern works with Codex SDK working directory
- [ ] Slash commands can call MCP tools with arguments
- [ ] Prompts can reference skills by name (Codex understands "Use X skill")

### Open Questions

1. **Codex SDK concurrency:** Can we actually spawn N Codex instances and run `Promise.all()`?

   - **Test:** Write minimal script with 3 parallel threads
   - **Blocker if no:** Need alternative parallelization strategy

2. **MCP tool timeouts:** Do MCP tools have execution time limits?

   - **Test:** Call tool with 5-minute sleep
   - **Blocker if yes:** Need async job pattern (current design)

3. **Codex working directory:** Does `workingDirectory` option actually isolate git operations?

   - **Test:** Two threads, same repo, different worktrees
   - **Blocker if no:** Need process-level isolation (spawn separate CLI processes)

4. **Skill interpretation:** Will Codex understand "Use phase-task-verification skill" or need full instructions?
   - **Test:** Send prompt with skill reference, check if it follows steps
   - **Not blocker:** Can always embed full instructions

### Success Metrics

**MVP Success (Week 2):**

- [ ] Can execute 3-task parallel phase from Codex CLI
- [ ] All tasks complete in separate worktrees
- [ ] Branches created and stacked correctly
- [ ] Status polling works

**Full Success (Week 6):**

- [ ] Complete workflow: spec → plan → execute → review
- [ ] Resume after failure works
- [ ] Code review loop with fixes
- [ ] 5+ real features implemented successfully
- [ ] Documentation complete

### Risk Mitigation

**Risk:** Codex SDK doesn't support true parallelism

- **Mitigation:** Fall back to sequential execution, market as "Codex-native Spectacular workflow"

**Risk:** MCP timeouts kill long-running executions

- **Mitigation:** Already designed with async job pattern

**Risk:** Skills don't work as embedded prompts

- **Mitigation:** Include full instructions in prompts, not just references

**Risk:** Git worktree coordination fails

- **Mitigation:** Add locking mechanism in MCP server

---

## Appendix: Architecture Alternatives Considered

### Alternative 1: Agents SDK Orchestration

**Rejected because:**

- Adds layer: Agents SDK → Codex MCP → Codex
- User not in Codex CLI (runs Python agent externally)
- Agents SDK designed for agent handoffs, we need thread spawning
- More complex, no UX benefit

### Alternative 2: Standalone TypeScript CLI

**Rejected because:**

- User runs `spectacular-codex execute` outside Codex
- Not integrated into Codex CLI workflow
- Requires separate tool installation
- No visibility in Codex session

### Alternative 3: Pure Slash Commands (No MCP)

**Rejected because:**

- Slash commands can't spawn Codex threads
- No orchestration capability
- User manually runs parallel tasks in multiple terminals
- Error-prone, no state tracking

### Alternative 4: Codex Plugin (If Supported)

**Rejected because:**

- Codex doesn't have plugin system (only MCP)
- Would require Codex core changes
- Not achievable with current platform

---

## Conclusion

This architecture enables Spectacular's parallel orchestration workflow within Codex CLI via MCP server. Key benefits:

1. **Native Codex UX:** User stays in CLI, uses slash commands
2. **True parallelism:** Multiple Codex threads via SDK
3. **Same methodology:** Skills embedded in prompts
4. **Git-based state:** Branches are truth, MCP tracks status only
5. **Autonomous execution:** Code review loops without user prompts

**Implementation complexity:** ~1050 LOC, 6 weeks

**MVP milestone:** 2 weeks (parallel execution working)

**Next step:** Validate open questions, then start Phase 1 implementation.
