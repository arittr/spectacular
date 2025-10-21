---
name: writing-specs
description: Use when creating feature specifications after brainstorming - generates lean spec documents that reference constitutions heavily, link to external docs instead of embedding examples, and focus on WHAT not HOW (implementation plans handled separately)
---

# Writing Specifications

## Overview

A **specification** defines WHAT to build and WHY. It is NOT an implementation plan.

**Core principle:** Reference constitutions, link to docs, keep it lean. The `/plan` command handles task decomposition.

**Spec = Requirements + Architecture**
**Plan = Tasks + Dependencies**

## When to Use

Use this skill when:
- Creating `specs/{feature-name}/spec.md` after brainstorming
- Called from `/spec` slash command (after brainstorming phases 1-3)
- Need to document feature requirements and architecture

Do NOT use for:
- Implementation plans with task breakdown → Use `/plan` instead
- API documentation → Goes in code comments or separate docs
- Runbooks or operational guides → Different document type

## Spec Structure

```markdown
# Feature: {Feature Name}

**Status**: Draft
**Created**: {date}

## Problem Statement

**Current State:**
{What exists today and what's missing/broken}

**Desired State:**
{What we want to achieve}

**Gap:**
{Specific problem this feature solves}

## Requirements

> **Note**: All features must follow @docs/constitutions/current/

### Functional Requirements
- FR1: {specific requirement}
- FR2: {specific requirement}

### Non-Functional Requirements
- NFR1: {performance/security/DX requirement}
- NFR2: {performance/security/DX requirement}

## Architecture

> **Layer boundaries**: @docs/constitutions/current/architecture.md
> **Required patterns**: @docs/constitutions/current/patterns.md

### Components

**New Files:**
- `src/lib/models/{name}.ts` - {purpose}
- `src/lib/services/{name}-service.ts` - {purpose}
- `src/lib/actions/{name}-actions.ts` - {purpose}

**Modified Files:**
- `{path}` - {what changes}

### Dependencies

**New packages:**
- `{package}` - {purpose}
- See: {link to official docs}

**Schema changes:**
- {migration name} - {purpose}
- Rules: @docs/constitutions/current/schema-rules.md

### Integration Points

- Auth: Uses existing Auth.js setup
- Database: Prisma client per @docs/constitutions/current/tech-stack.md
- Validation: Zod schemas per @docs/constitutions/current/patterns.md

## Acceptance Criteria

**Constitution compliance:**
- [ ] All patterns followed (@docs/constitutions/current/patterns.md)
- [ ] Architecture boundaries respected (@docs/constitutions/current/architecture.md)
- [ ] Testing requirements met (@docs/constitutions/current/testing.md)

**Feature-specific:**
- [ ] {criterion for this feature}
- [ ] {criterion for this feature}
- [ ] {criterion for this feature}

**Verification:**
- [ ] All tests pass
- [ ] Linting passes
- [ ] Feature works end-to-end

## Open Questions

{List any unresolved questions or decisions needed}

## References

- Architecture: @docs/constitutions/current/architecture.md
- Patterns: @docs/constitutions/current/patterns.md
- Schema Rules: @docs/constitutions/current/schema-rules.md
- Tech Stack: @docs/constitutions/current/tech-stack.md
- Testing: @docs/constitutions/current/testing.md
- {External SDK}: {link to official docs}
```

## Iron Laws

### 1. Reference, Don't Duplicate

❌ **NEVER recreate constitution rules in the spec**

<Bad>
```markdown
## Layered Architecture

The architecture has three layers:
- Models: Data access with Prisma
- Services: Business logic
- Actions: Input validation with Zod
```
</Bad>

<Good>
```markdown
## Architecture

> **Layer boundaries**: @docs/constitutions/current/architecture.md

Components follow the established 3-layer pattern.
```
</Good>

### 2. Link to Docs, Don't Embed Examples

❌ **NEVER include code examples from external libraries**

<Bad>
```markdown
### Zod Validation

```typescript
import { z } from 'zod';

export const schema = z.object({
  name: z.string().min(3),
  email: z.string().email()
});
```
```
</Bad>

<Good>
```markdown
### Validation

Use Zod schemas per @docs/constitutions/current/patterns.md

See: https://zod.dev for object schema syntax
```
</Good>

### 3. No Implementation Plans

❌ **NEVER include task breakdown or migration phases**

<Bad>
```markdown
## Migration Plan

### Phase 1: Database Schema
1. Create Prisma migration
2. Run migration
3. Verify indexes

### Phase 2: Backend Implementation
...
```
</Bad>

<Good>
```markdown
## Dependencies

**Schema changes:**
- Migration: `init_rooms` - Add Room, RoomParticipant, WaitingListEntry models

Implementation order determined by `/plan` command.
```
</Good>

### 4. No Success Metrics

❌ **NEVER include adoption metrics, performance targets, or measurement strategies**

<Bad>
```markdown
## Success Metrics

1. Adoption: 80% of users use feature within first month
2. Performance: Page loads in <500ms
3. Engagement: <5% churn rate
```
</Bad>

<Good>
```markdown
## Non-Functional Requirements

- NFR1: Page load performance <500ms (measured per @docs/constitutions/current/testing.md)
- NFR2: Support 1000 concurrent users
```
</Good>

## Common Mistakes

| Mistake | Why It's Wrong | Fix |
|---------|---------------|-----|
| Including full Prisma schemas | Duplicates what goes in code | List model names + purposes, reference schema-rules.md |
| Writing test code examples | Shows HOW not WHAT | List what to test, reference testing.md for how |
| Explaining ts-pattern syntax | Already in patterns.md | Reference patterns.md, list where pattern applies |
| Creating `/notes` subdirectory | Violates single-file principle | Keep spec lean, remove supporting docs |
| Adding timeline estimates | That's project management | Focus on requirements and architecture |

## Rationalization Table

| Excuse | Reality |
|--------|---------|
| "Thorough means showing complete code" | Thorough = complete requirements. Code = implementation. |
| "Spec needs examples so people understand" | Link to docs. Don't copy-paste library examples. |
| "Migration plan shows full picture" | `/plan` command handles decomposition. Spec = WHAT not HOW. |
| "Include constitutions for context" | Constitutions exist to avoid duplication. Reference, don't recreate. |
| "Testing code shows approach" | testing.md shows approach. Spec lists WHAT to test. |
| "Metrics demonstrate value" | NFRs show requirements. Metrics = measurement strategy (different doc). |
| "More detail = more helpful" | More detail = harder to maintain. Lean + links = durable. |

## Red Flags - STOP and Fix

Seeing any of these? Delete and reference instead:

- Full code examples from libraries (Zod, Prisma, Socket.io, etc.)
- Migration phases or implementation steps
- Success metrics or adoption targets
- Recreated architecture explanations
- Test implementation code
- Files in `specs/{feature}/notes/` directory
- Spec > 300 lines (probably duplicating constitutions)

**All of these mean: Too much implementation detail. Focus on WHAT not HOW.**

## Workflow Integration

This skill is called from `/spec` command:

1. **User runs**: `/spec {feature description}`
2. **Brainstorming**: Phases 1-3 run (understanding, exploration, design)
3. **This skill**: Generate `specs/{feature-name}/spec.md`
4. **User reviews**: Check spec for completeness
5. **Next step**: `/plan @specs/{feature-name}/spec.md` for task decomposition

## Quality Checklist

Before finalizing spec:

- [ ] Problem statement shows current → desired state gap
- [ ] All FRs and NFRs are testable/verifiable
- [ ] Architecture section lists files (not code examples)
- [ ] All constitution rules referenced (not recreated)
- [ ] All external libraries linked to docs (not copied)
- [ ] No implementation plan (saved for `/plan`)
- [ ] No success metrics or timelines
- [ ] Single file at `specs/{feature-name}/spec.md`
- [ ] Spec < 300 lines (if longer, check for duplication)

## The Bottom Line

**Specs define WHAT and WHY. Plans define HOW and WHEN.**

Reference heavily. Link to docs. Keep it lean.

If you're copy-pasting code or recreating rules, you're writing the wrong document.
