# Multi-Repo Support - Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Extend spectacular to support multi-repo workflows with single spec/plan, repo-tagged tasks, and per-repo worktrees/constitutions.

**Architecture:** Pure skills architecture (matching superpowers pattern) with thin wrapper commands. Multi-repo detection at workspace level, per-repo constitution and setup command lookup.

**Tech Stack:** Markdown skills, bash scripts, git worktrees, git-spice

---

## Execution Summary

- **Total Tasks**: 12
- **Total Phases**: 4
- **Sequential Time**: ~36h
- **Parallel Time**: ~24h
- **Time Savings**: ~12h (33%)

**Parallel Opportunities:**
- Phase 1: 4 tasks can run in parallel (command→skill conversions)
- Phase 2: 2 tasks can run in parallel (spec + plan skill updates)

---

## Phase 1: Architecture Refactor (Parallel)

**Strategy**: parallel
**Reason**: Each command conversion is independent - no shared files

### Task 1.1: Create validating-environment Skill

**Files**:
- Create: `skills/validating-environment/SKILL.md`
- Modify: `commands/init.md`

**Complexity**: M (3h)

**Dependencies**: None

**Description**:
Extract all validation logic from `commands/init.md` into a new `validating-environment` skill. The command becomes a thin wrapper that just invokes the skill.

**Implementation Steps**:

1. Create `skills/validating-environment/SKILL.md` with standard skill frontmatter
2. Move all Step 1-6 logic from `commands/init.md` into the skill
3. Add skill sections: Overview, When to Use, The Process, Quality Rules, Error Handling
4. Update `commands/init.md` to single line: "Invoke the spectacular:validating-environment skill"
5. Add multi-repo detection placeholder (detect workspace vs single repo)

**Acceptance Criteria**:
- [ ] `skills/validating-environment/SKILL.md` exists with complete validation logic
- [ ] `commands/init.md` is <10 lines (thin wrapper only)
- [ ] Running `/spectacular:init` produces same output as before
- [ ] Skill detects single-repo vs multi-repo workspace (placeholder for Phase 2)

**Mandatory Patterns**:
> Follow superpowers skill template structure exactly

---

### Task 1.2: Convert spec Command to Thin Wrapper

**Files**:
- Modify: `commands/spec.md`
- Modify: `skills/writing-specs/SKILL.md`

**Complexity**: M (4h)

**Dependencies**: None

**Description**:
Move all orchestration logic from `commands/spec.md` into the `writing-specs` skill. The command becomes a thin wrapper.

**Implementation Steps**:

1. Read current `commands/spec.md` (347 lines of orchestration)
2. Identify what belongs in skill vs command:
   - Skill: Run ID generation, worktree creation, brainstorming, spec generation, validation
   - Command: Just invoke the skill
3. Merge Steps 0-4 from command into `writing-specs/SKILL.md`
4. Update skill to handle full workflow (not just spec generation)
5. Reduce `commands/spec.md` to thin wrapper

**Acceptance Criteria**:
- [ ] `commands/spec.md` is <10 lines
- [ ] `skills/writing-specs/SKILL.md` contains full workflow
- [ ] Running `/spectacular:spec "feature"` works as before
- [ ] Skill includes Run ID generation and worktree setup

**Mandatory Patterns**:
> Follow superpowers skill template structure

---

### Task 1.3: Convert plan Command to Thin Wrapper

**Files**:
- Modify: `commands/plan.md`
- Modify: `skills/decomposing-tasks/SKILL.md`

**Complexity**: M (3h)

**Dependencies**: None

**Description**:
Move orchestration logic from `commands/plan.md` into the `decomposing-tasks` skill.

**Implementation Steps**:

1. Read current `commands/plan.md` (365 lines)
2. Move Steps 0-3 into `decomposing-tasks/SKILL.md`:
   - Run ID extraction
   - Worktree context switching
   - Subagent dispatch for plan generation
   - Plan review and commit
3. Reduce command to thin wrapper

**Acceptance Criteria**:
- [ ] `commands/plan.md` is <10 lines
- [ ] `skills/decomposing-tasks/SKILL.md` contains full workflow
- [ ] Running `/spectacular:plan @spec.md` works as before

---

### Task 1.4: Create executing-plan Skill and Convert execute Command

**Files**:
- Create: `skills/executing-plan/SKILL.md`
- Modify: `commands/execute.md`

**Complexity**: L (6h)

**Dependencies**: None

**Description**:
Create new `executing-plan` skill containing all orchestration logic from `commands/execute.md`. This is the largest command (~500 lines).

**Implementation Steps**:

1. Create `skills/executing-plan/SKILL.md`
2. Move Steps 0a-5 from `commands/execute.md`:
   - Run ID extraction
   - Worktree verification
   - Resume detection
   - Plan parsing
   - Setup command validation
   - Review frequency configuration
   - Phase dispatch (references executing-*-phase skills)
   - Verification and finishing
3. Keep phase execution skills separate (they're already well-factored)
4. Reduce command to thin wrapper

**Acceptance Criteria**:
- [ ] `skills/executing-plan/SKILL.md` exists with full orchestration
- [ ] `commands/execute.md` is <10 lines
- [ ] Phase execution skills remain unchanged
- [ ] Running `/spectacular:execute @plan.md` works as before

---

## Phase 2: Multi-Repo Core (Parallel)

**Strategy**: parallel
**Reason**: Spec and plan skill updates are independent

### Task 2.1: Add Multi-Repo Support to writing-specs Skill

**Files**:
- Modify: `skills/writing-specs/SKILL.md`

**Complexity**: M (4h)

**Dependencies**: Task 1.2 (spec command converted)

**Description**:
Update the writing-specs skill to support multi-repo workflows: workspace detection, per-repo constitution references, and multi-repo spec format.

**Implementation Steps**:

1. Add workspace detection logic:
   ```bash
   # Detect if we're in a workspace (parent of multiple repos)
   REPO_COUNT=$(find . -maxdepth 2 -name ".git" -type d | wc -l)
   if [ "$REPO_COUNT" -gt 1 ]; then
     WORKSPACE_MODE="multi-repo"
     WORKSPACE_ROOT=$(pwd)
   else
     WORKSPACE_MODE="single-repo"
   fi
   ```

2. Update spec storage location:
   - Single-repo: `specs/{runId}-{feature}/spec.md` (current behavior)
   - Multi-repo: `./specs/{runId}-{feature}/spec.md` (workspace root)

3. Add multi-repo constitution references section to spec template:
   ```markdown
   ## Constitutions

   This feature must comply with:
   - **backend**: @backend/docs/constitutions/current/
   - **frontend**: @frontend/docs/constitutions/current/
   ```

4. Update brainstorming to read constitutions from all relevant repos

5. Skip worktree creation for multi-repo mode (specs live at workspace root)

**Acceptance Criteria**:
- [ ] Skill detects single-repo vs multi-repo workspace
- [ ] Specs stored at workspace root in multi-repo mode
- [ ] Spec template includes multi-repo constitution references
- [ ] Single-repo mode unchanged (backwards compatible)

---

### Task 2.2: Add Multi-Repo Support to decomposing-tasks Skill

**Files**:
- Modify: `skills/decomposing-tasks/SKILL.md`

**Complexity**: M (4h)

**Dependencies**: Task 1.3 (plan command converted)

**Description**:
Update task decomposition to support `repo:` field in task definitions and generate multi-repo aware plans.

**Implementation Steps**:

1. Update task extraction to include `repo` field:
   ```
   {
     id: "task-1-1-database",
     repo: "backend",  // NEW FIELD
     files: ["prisma/schema.prisma"],
     ...
   }
   ```

2. Update plan.md template with repo field:
   ```markdown
   ### Task 1.1: Add user_preferences table

   **Repo**: backend
   **Files**:
   - prisma/schema.prisma
   ```

3. Update dependency analysis to consider cross-repo dependencies:
   - Tasks in same repo with shared files → sequential
   - Tasks in different repos → can be parallel

4. Add validation for multi-repo plans:
   - Each task must specify `repo:` in multi-repo mode
   - Repo must exist in workspace

5. Update execution summary to show per-repo breakdown

**Acceptance Criteria**:
- [ ] Tasks include `repo:` field in multi-repo mode
- [ ] Plan template shows repo for each task
- [ ] Cross-repo tasks can be parallelized
- [ ] Single-repo plans unchanged (backwards compatible)

---

## Phase 3: Execution Updates (Sequential)

**Strategy**: sequential
**Reason**: Each task builds on previous - execution flow is linear

### Task 3.1: Update executing-plan Skill for Multi-Repo

**Files**:
- Modify: `skills/executing-plan/SKILL.md`

**Complexity**: M (4h)

**Dependencies**: Task 1.4, Task 2.1, Task 2.2

**Description**:
Update the main execution orchestration to handle multi-repo plans: workspace detection, per-repo worktree creation, per-repo setup commands.

**Implementation Steps**:

1. Add workspace mode detection at start of execution

2. Update worktree verification for multi-repo:
   - Single-repo: `.worktrees/{runId}-main/` (current)
   - Multi-repo: `{repo}/.worktrees/{runId}-task-X-Y/` per task

3. Update plan parsing to extract repo field from tasks

4. Pass repo context to phase execution skills

5. Update final report to show per-repo summary

**Acceptance Criteria**:
- [ ] Execution detects multi-repo workspace
- [ ] Repo context passed to phase skills
- [ ] Final report shows per-repo breakdown
- [ ] Single-repo execution unchanged

---

### Task 3.2: Update executing-parallel-phase for Multi-Repo

**Files**:
- Modify: `skills/executing-parallel-phase/SKILL.md`

**Complexity**: L (5h)

**Dependencies**: Task 3.1

**Description**:
Update parallel phase execution to create worktrees in the correct repo for each task and look up per-repo setup commands.

**Implementation Steps**:

1. Update worktree creation to use task's repo:
   ```bash
   # For task with repo: backend
   TASK_REPO="backend"
   WORKTREE_PATH="${TASK_REPO}/.worktrees/${RUN_ID}-task-${PHASE}-${TASK}"
   cd ${TASK_REPO}
   git worktree add ${WORKTREE_PATH} ...
   ```

2. Update setup command lookup:
   ```bash
   # Read setup commands from task's repo CLAUDE.md
   INSTALL_CMD=$(grep -A1 "**install**:" ${TASK_REPO}/CLAUDE.md | tail -1)
   ```

3. Update subagent prompts to include:
   - Repo name
   - Repo-specific constitution path
   - Repo-specific CLAUDE.md path

4. Update worktree cleanup to handle multiple repos

5. Update stacking to create per-repo stacks

**Acceptance Criteria**:
- [ ] Worktrees created in correct repo directory
- [ ] Setup commands read from per-repo CLAUDE.md
- [ ] Subagents receive repo-specific context
- [ ] Cleanup handles multi-repo worktrees

---

### Task 3.3: Update executing-sequential-phase for Multi-Repo

**Files**:
- Modify: `skills/executing-sequential-phase/SKILL.md`

**Complexity**: M (4h)

**Dependencies**: Task 3.2

**Description**:
Update sequential phase execution for multi-repo: switch to correct repo for each task, maintain per-repo stacks.

**Implementation Steps**:

1. Update task execution to switch to task's repo:
   ```bash
   # Switch to repo's main worktree for this task
   cd ${TASK_REPO}/.worktrees/${RUN_ID}-main
   ```

2. Update setup command lookup per-repo

3. Update subagent context with repo-specific paths

4. Handle cross-repo sequential dependencies:
   - If Task 2 depends on Task 1 in different repo
   - Execute Task 1, then switch repos, execute Task 2

5. Update stacking for per-repo branches

**Acceptance Criteria**:
- [ ] Sequential tasks execute in correct repo
- [ ] Cross-repo dependencies handled correctly
- [ ] Per-repo stacks maintained
- [ ] Resume works across repos

---

## Phase 4: PR Submission & Polish (Sequential)

**Strategy**: sequential
**Reason**: Depends on all previous work being complete

### Task 4.1: Update Finishing Workflow for Multi-Repo

**Files**:
- Create: `skills/finishing-multi-repo/SKILL.md` (optional, may just update docs)
- Modify: `skills/using-git-spice/SKILL.md`

**Complexity**: M (3h)

**Dependencies**: Task 3.3

**Description**:
Update the finishing workflow to handle multi-repo PR submission: coordinate submission order across repos based on phase dependencies.

**Implementation Steps**:

1. Document per-repo stacking limitation in `using-git-spice/SKILL.md`

2. Add multi-repo submission guidance:
   ```markdown
   ## Multi-Repo PR Submission

   Git-spice operates per-repo. For multi-repo features:

   1. Submit PRs in phase order:
      - Phase 1 repos first (foundation)
      - Phase 2 repos second
      - etc.

   2. Per-repo submission:
      ```bash
      cd backend && gs stack submit
      cd ../frontend && gs stack submit
      ```
   ```

3. Update finishing skill to show multi-repo next steps

**Acceptance Criteria**:
- [ ] Multi-repo submission documented
- [ ] Phase-order submission guidance clear
- [ ] Per-repo gs commands documented

---

### Task 4.2: Update validating-environment for Multi-Repo

**Files**:
- Modify: `skills/validating-environment/SKILL.md`

**Complexity**: S (2h)

**Dependencies**: Task 1.1, Task 4.1

**Description**:
Update environment validation to check multi-repo workspace setup and validate per-repo requirements.

**Implementation Steps**:

1. Add workspace structure validation:
   ```bash
   # Check for multiple repos
   REPOS=$(find . -maxdepth 2 -name ".git" -type d | xargs -I{} dirname {})
   echo "Detected repos: $REPOS"
   ```

2. Validate each repo has:
   - `.git/` directory
   - `CLAUDE.md` with setup commands (warn if missing)
   - `docs/constitutions/current/` (optional, warn if missing)

3. Create `specs/` directory at workspace root if multi-repo

4. Update summary to show multi-repo status

**Acceptance Criteria**:
- [ ] Detects multi-repo workspace
- [ ] Validates each repo's CLAUDE.md
- [ ] Creates workspace-level specs directory
- [ ] Clear multi-repo status in summary

---

### Task 4.3: Update CLAUDE.md and Documentation

**Files**:
- Modify: `CLAUDE.md`
- Modify: `README.md` (if exists)

**Complexity**: M (3h)

**Dependencies**: Task 4.2

**Description**:
Update project documentation to reflect multi-repo support, new skill architecture, and usage examples.

**Implementation Steps**:

1. Update CLAUDE.md Architecture section:
   - Document pure skills architecture
   - Document thin wrapper commands
   - Add multi-repo workflow section

2. Add Multi-Repo Usage section:
   ```markdown
   ## Multi-Repo Workflows

   Spectacular supports features spanning multiple repos:

   ### Workspace Structure
   workspace/
   ├── specs/           # Specs live here
   ├── backend/         # Repo 1
   ├── frontend/        # Repo 2
   └── shared-lib/      # Repo 3

   ### Usage
   cd workspace
   /spectacular:spec "feature spanning repos"
   ```

3. Update command reference to note they're thin wrappers

4. Add migration guide for existing users

**Acceptance Criteria**:
- [ ] CLAUDE.md documents multi-repo support
- [ ] Architecture section shows skills-first approach
- [ ] Usage examples for multi-repo workflows
- [ ] Migration notes for existing users

---

## Testing Strategy

Each task should be tested by:

1. **Single-repo regression**: Verify existing behavior unchanged
2. **Multi-repo happy path**: Test with 2+ repo workspace
3. **Edge cases**: Empty repos, missing CLAUDE.md, missing constitutions

## Notes

- Backwards compatibility is critical - single-repo must work exactly as before
- Multi-repo is opt-in based on workspace detection
- Per-repo CLAUDE.md is required for setup commands
- Per-repo constitutions are optional but recommended
