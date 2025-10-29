---
description: Generate a lean feature specification using brainstorming and the writing-specs skill
---

You are creating a feature specification.

## Constitution Adherence

**All specifications MUST follow**: @docs/constitutions/current/
- architecture.md - Layer boundaries, project structure
- patterns.md - Mandatory patterns (next-safe-action, ts-pattern, etc.)
- schema-rules.md - Database design philosophy
- tech-stack.md - Approved libraries and versions
- testing.md - Testing requirements

## Input

User will provide: `/spectacular:spec {feature-description}`

Example: `/spectacular:spec magic link authentication with Auth.js`

## Workflow

### Step 0: Generate Run ID

**First action**: Generate a unique run identifier for this spec.

```bash
# Generate 6-char hash from feature name + timestamp
RUN_ID=$(echo "{feature-description}-$(date +%s)" | shasum -a 256 | head -c 6)
echo "RUN_ID: $RUN_ID"
```

**Store for use in:**
- Spec directory name: `specs/{run-id}-{feature-slug}/`
- Spec frontmatter metadata
- Plan generation
- Branch naming during execution

**Announce:** "Generated RUN_ID: {run-id} for tracking this spec run"

### Step 0.5: Create Isolated Worktree

**Announce:** "Creating isolated worktree for this spec run..."

**Create worktree for isolated development:**

1. **Create branch using git-spice**:
   - Use `using-git-spice` skill to create branch `{runId}-main` from current branch
   - Branch name format: `{runId}-main` (e.g., `abc123-main`)

2. **Create worktree**:
   ```bash
   # Create worktree at .worktrees/{runId}-main/
   git worktree add .worktrees/${RUN_ID}-main ${RUN_ID}-main
   ```

3. **Error handling**:
   - If worktree already exists: "Worktree {runId}-main already exists. Remove it first with `git worktree remove .worktrees/{runId}-main` or use a different feature name."
   - If worktree creation fails: Report the git error details and exit

**Working directory context:**
- All subsequent file operations happen in `.worktrees/{runId}-main/`
- Brainstorming and spec generation occur in the worktree context
- Main repository working directory remains unchanged

**Announce:** "Worktree created at .worktrees/{runId}-main/ - all work will happen in isolation"

### Step 1: Brainstorm Requirements

**Context:** All brainstorming happens in the context of the worktree (`.worktrees/{runId}-main/`)

**Announce:** "I'm brainstorming the design using Phases 1-3 (Understanding, Exploration, Design Presentation)."

**Create TodoWrite checklist:**

```
Brainstorming for Spec:
- [ ] Phase 1: Understanding (purpose, constraints, criteria)
- [ ] Phase 2: Exploration (2-3 approaches proposed)
- [ ] Phase 3: Design Presentation (design validated)
- [ ] Proceed to Step 2: Generate Specification
```

#### Phase 1: Understanding

**Goal:** Clarify scope, constraints, and success criteria.

1. Check current project state in working directory (note: we're in the worktree)
2. Read @docs/constitutions/current/ to understand constraints:
   - architecture.md - Layer boundaries
   - patterns.md - Mandatory patterns
   - tech-stack.md - Approved libraries
   - schema-rules.md - Database rules
3. Ask ONE question at a time to refine the idea
4. Use AskUserQuestion tool for multiple choice options
5. Gather: Purpose, constraints, success criteria

**Constitution compliance:**
- All architectural decisions must follow @docs/constitutions/current/architecture.md
- All pattern choices must follow @docs/constitutions/current/patterns.md
- All library selections must follow @docs/constitutions/current/tech-stack.md

#### Phase 2: Exploration

**Goal:** Propose and evaluate 2-3 architectural approaches.

1. Propose 2-3 different approaches that follow constitutional constraints
2. For each approach explain:
   - Core architecture (layers, patterns)
   - Trade-offs (complexity vs features)
   - Constitution compliance (which patterns used)
3. Use AskUserQuestion tool to present approaches as structured choices
4. Ask partner which approach resonates

#### Phase 3: Design Presentation

**Goal:** Present detailed design incrementally and validate.

1. Present design in 200-300 word sections
2. Cover: Architecture, components, data flow, error handling, testing
3. After each section ask: "Does this look right so far?" (open-ended)
4. Use open-ended questions for freeform feedback
5. Adjust design based on feedback

**After Phase 3:** Mark TodoWrite complete and proceed immediately to Step 2.

### Step 2: Generate Specification

**Announce:** "I'm using the Writing Specs skill to create the specification."

Use the `writing-specs` skill to generate the spec document.

**Task for writing-specs skill:**
- Feature: {feature-description}
- Design context: {summary from brainstorming}
- RUN_ID: {run-id from Step 0}
- Output location: `.worktrees/{run-id}-main/specs/{run-id}-{feature-slug}/spec.md`
- **Constitution**: All design decisions must follow @docs/constitutions/current/
- Analyze codebase for task-specific context:
  - Existing files to modify
  - New files to create (with exact paths per @docs/constitutions/current/architecture.md)
  - Dependencies needed (must be in @docs/constitutions/current/tech-stack.md)
  - Schema changes required (following @docs/constitutions/current/schema-rules.md)
- Follow all Iron Laws:
  - Reference constitutions, don't duplicate
  - Link to SDK docs, don't embed examples
  - No implementation plans (that's `/spectacular:plan`'s job)
  - Keep it lean (<300 lines)

**Spec frontmatter must include:**
```yaml
---
runId: {run-id}
feature: {feature-slug}
created: {date}
status: draft
---
```

### Step 2.5: Commit Spec to Worktree

**After spec generation completes, commit the spec to the worktree branch:**

```bash
cd .worktrees/${RUN_ID}-main
git add specs/
git commit -m "spec: add ${feature-slug} specification [${RUN_ID}]"
```

**Announce:** "Spec committed to {runId}-main branch in worktree"

### Step 3: Architecture Quality Validation

**CRITICAL**: Before reporting completion, validate the spec against architecture quality standards.

**Announce:** "Validating spec against architecture quality standards..."

Read the generated spec and check against these dimensions:

#### 3.1 Constitution Compliance
- [ ] **Architecture**: All components follow layer boundaries (@docs/constitutions/current/architecture.md)
  - Models → Services → Actions → UI (no layer violations)
  - Server/Client component boundaries respected
- [ ] **Patterns**: All mandatory patterns referenced (@docs/constitutions/current/patterns.md)
  - next-safe-action for server actions
  - ts-pattern for discriminated unions
  - Zod schemas for validation
  - routes.ts for navigation
- [ ] **Schema**: Database design follows rules (@docs/constitutions/current/schema-rules.md)
  - Proper indexing strategy
  - Naming conventions
  - Relationship patterns
- [ ] **Tech Stack**: All dependencies approved (@docs/constitutions/current/tech-stack.md)
  - No unapproved libraries
  - Correct versions specified
- [ ] **Testing**: Testing strategy defined (@docs/constitutions/current/testing.md)

#### 3.2 Specification Quality (Iron Laws)
- [ ] **No Duplication**: Constitution rules referenced, not recreated
- [ ] **No Code Examples**: External docs linked, not embedded
- [ ] **No Implementation Plans**: Focus on WHAT/WHY, not HOW/WHEN
- [ ] **Lean**: Spec < 300 lines (if longer, likely duplicating constitutions)

#### 3.3 Requirements Quality
- [ ] **Completeness**: All FRs and NFRs defined, no missing scenarios
- [ ] **Clarity**: All requirements unambiguous and specific (no "fast", "good", "better")
- [ ] **Measurability**: All requirements have testable acceptance criteria
- [ ] **Consistency**: No conflicts between sections
- [ ] **Edge Cases**: Boundary conditions and error handling addressed
- [ ] **Dependencies**: External dependencies and assumptions documented

#### 3.4 Architecture Traceability
- [ ] **File Paths**: All new/modified files have exact paths per architecture.md
- [ ] **Integration Points**: How feature integrates with existing system clear
- [ ] **Migration Impact**: Schema changes and data migrations identified
- [ ] **Security**: Auth/authz requirements explicit

#### 3.5 Surface Issues

If ANY checks fail, create `.worktrees/{run-id}-main/specs/{run-id}-{feature-slug}/clarifications.md` with:

```markdown
# Clarifications Needed

## [Category: Constitution/Quality/Requirements/Architecture]

**Issue**: {What's wrong}
**Location**: {Spec section reference}
**Severity**: [BLOCKER/CRITICAL/MINOR]
**Question**: {What needs to be resolved}

Options:
- A: {Option with trade-offs}
- B: {Option with trade-offs}
- Custom: {User provides alternative}
```

**Iteration limit**: Maximum 3 validation cycles. If issues remain after 3 iterations, escalate to user with clarifications.md.

### Step 4: Report Completion

**IMPORTANT**: After reporting completion, **STOP HERE**. Do not proceed to plan generation automatically. The user must review the spec and explicitly run `/spectacular:plan` when ready.

After validation passes OR clarifications documented, report to user:

**If validation passed:**
```
✅ Feature Specification Complete & Validated

RUN_ID: {run-id}
Worktree: .worktrees/{run-id}-main/
Branch: {run-id}-main
Location: .worktrees/{run-id}-main/specs/{run-id}-{feature-slug}/spec.md

Constitution Compliance: ✓
Architecture Quality: ✓
Requirements Quality: ✓

Note: Spec is in isolated worktree, main repo unchanged.

Next Steps (User Actions - DO NOT AUTO-EXECUTE):
1. Review the spec: .worktrees/{run-id}-main/specs/{run-id}-{feature-slug}/spec.md
2. When ready, create implementation plan: /spectacular:plan @.worktrees/{run-id}-main/specs/{run-id}-{feature-slug}/spec.md
```

**If clarifications needed:**
```
⚠️  Feature Specification Complete - Clarifications Needed

RUN_ID: {run-id}
Worktree: .worktrees/{run-id}-main/
Branch: {run-id}-main
Location: .worktrees/{run-id}-main/specs/{run-id}-{feature-slug}/spec.md
Clarifications: .worktrees/{run-id}-main/specs/{run-id}-{feature-slug}/clarifications.md

Note: Spec is in isolated worktree, main repo unchanged.

Next Steps:
1. Review spec: .worktrees/{run-id}-main/specs/{run-id}-{feature-slug}/spec.md
2. Answer clarifications: .worktrees/{run-id}-main/specs/{run-id}-{feature-slug}/clarifications.md
3. Once resolved, re-run: /spectacular:spec {feature-description}
```

Now generate the specification for: {feature-description}
