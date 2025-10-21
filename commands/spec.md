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

### Step 1: Brainstorm Requirements

Use the `brainstorming` skill for Phases 1-3 ONLY:
- Phase 1: Understanding - Clarify scope and boundaries
- Phase 2: Exploration - Explore alternatives, identify architectural decisions
- Phase 3: Design Presentation - Present design incrementally

**Constitution compliance during brainstorming:**
- Architectural decisions must follow @docs/constitutions/current/architecture.md
- Pattern choices must follow @docs/constitutions/current/patterns.md
- Library selections must follow @docs/constitutions/current/tech-stack.md

**IMPORTANT**: STOP after Phase 3 (Design Presentation). Do NOT continue to:
- Phase 4: Worktree Setup
- Phase 5: Planning Handoff

Return to this /spectacular:spec workflow after design is validated.

### Step 2: Generate Specification

**Announce:** "I'm using the Writing Specs skill to create the specification."

Use the `writing-specs` skill to generate the spec document.

**Task for writing-specs skill:**
- Feature: {feature-description}
- Design context: {summary from brainstorming}
- RUN_ID: {run-id from Step 0}
- Output location: `specs/{run-id}-{feature-slug}/spec.md`
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

If ANY checks fail, create `specs/{run-id}-{feature-slug}/clarifications.md` with:

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

After validation passes OR clarifications documented, report to user:

**If validation passed:**
```
✅ Feature Specification Complete & Validated

RUN_ID: {run-id}
Location: specs/{run-id}-{feature-slug}/spec.md
Constitution Compliance: ✓
Architecture Quality: ✓
Requirements Quality: ✓

Next Steps:
1. Review the spec: specs/{run-id}-{feature-slug}/spec.md
2. Create implementation plan: /spectacular:plan @specs/{run-id}-{feature-slug}/spec.md
```

**If clarifications needed:**
```
⚠️  Feature Specification Complete - Clarifications Needed

RUN_ID: {run-id}
Location: specs/{run-id}-{feature-slug}/spec.md
Clarifications: specs/{run-id}-{feature-slug}/clarifications.md

Next Steps:
1. Review spec: specs/{run-id}-{feature-slug}/spec.md
2. Answer clarifications: specs/{run-id}-{feature-slug}/clarifications.md
3. Once resolved, re-run: /spectacular:spec {feature-description}
```

Now generate the specification for: {feature-description}
