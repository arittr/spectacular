# Testing Evidence: testing-spectacular Skill

## Testing Approach

**Skill Type**: Technique/Reference skill (how to test spectacular commands)

**Testing Method**: Structured review + rationalization analysis (lightweight verification)

**Why not full pressure testing**: This is a reference skill documenting a testing methodology, not a discipline-enforcing skill. The skill itself is derived from real RED phase evidence (9f92a8 analysis). Full subagent pressure testing would be most valuable after the skill is deployed and used in practice.

## Verification Against Quality Criteria

### 1. Frontmatter Validation

```bash
$ grep -A 3 "^---" skills/testing-spectacular/SKILL.md
---
name: testing-spectacular
description: Use when creating or editing spectacular commands (spec, plan, execute) or updating constitution patterns - applies RED-GREEN-REFACTOR to test whether orchestrators can follow instructions correctly under realistic pressure (time constraints, cognitive load, parallel execution)
---
```

✅ **PASS**
- Name uses only letters, numbers, hyphens (no special characters)
- Description starts with "Use when..." and includes specific triggers
- Description mentions symptoms: "orchestrators can follow instructions", "realistic pressure"
- Under 1024 characters total
- Written in third person

### 2. Required Sections Check

```bash
$ grep -E "^## " skills/testing-spectacular/SKILL.md
```

✅ **PASS** - All required sections present:
- Overview (with core principle)
- When to Use (with specific triggers)
- Differences From Other Testing Skills (comparison table)
- TDD Mapping (adapted for spectacular)
- RED Phase (find real failures)
- Create RED Test Scenario
- GREEN Phase (fix instructions)
- Verify GREEN (test fix)
- REFACTOR Phase (iterate)
- Rationalization Table
- Testing Checklist
- Common Mistakes
- Real-World Impact

### 3. Rationalization Table Analysis

The skill includes rationalization table based on **actual 9f92a8 execution findings**:

| Rationalization | Source |
|----------------|--------|
| "execute.md says stay in main repo, that's enough" | 9f92a8: orchestrator was in worktree despite instruction |
| "I'll delegate to using-git-worktrees skill" | 9f92a8: skill has wrong pattern (feature worktrees with -b flag) |
| "I remember the git-spice commands from before" | 9f92a8: multiple stacking attempts, trial-and-error |
| "Stacking commands seem obvious, I'll try them" | 9f92a8: multiple iterations before correct structure |
| "I'll read the skill to understand the workflow" | RED phase finding: time pressure prevents thorough reading |
| "The instructions say to use the skill" | RED phase finding: delegation ≠ explicit commands |

✅ **PASS** - Rationalization table derived from real execution evidence, not hypothetical

### 4. TodoWrite Checklist Requirement

Skill includes explicit TodoWrite requirement:

```markdown
## Testing Checklist

**IMPORTANT: Use TodoWrite to track these steps.**

**RED Phase:**
- [ ] Find real execution failure from git logs or run transcripts
...
```

✅ **PASS** - Explicit TodoWrite instruction with comprehensive checklist

### 5. Cross-Reference to Background Skills

```markdown
**REQUIRED BACKGROUND:** You MUST understand superpowers:test-driven-development before using this skill.
```

✅ **PASS** - Explicit requirement marker for TDD skill

### 6. Announce Instruction

```markdown
**Announce:** "I'm using testing-spectacular to verify these command instructions work correctly under pressure."
```

✅ **PASS** - Mandatory announcement instruction present

### 7. Real-World Evidence

Skill is grounded in:
- **9f92a8 execution analysis**: Nested worktrees, temporary branches, multiple stacking attempts
- **RED phase findings document**: Instruction clarity vs role mismatch analysis
- **Actual git errors**: File paths, error messages, branch names documented

✅ **PASS** - Skill derived from real failures, not hypothetical scenarios

### 8. Spectacular-Specific Patterns

Skill addresses spectacular-specific challenges:
- Git-spice command sequences (track, stack, rebase order)
- Worktree context switching (main repo vs worktree)
- Parallel execution state management
- Cleanup ordering (worktrees before branches)
- Orchestrator pressure types (coordination load, git complexity)

✅ **PASS** - Patterns specific to spectacular, not generic workflow testing

### 9. Comparison to Similar Skills

Skill includes table differentiating from:
- `testing-skills-with-subagents` (agent compliance testing)
- `testing-workflows-with-subagents` (generic workflow clarity)
- `testing-spectacular` (spectacular-specific git orchestration)

✅ **PASS** - Clear differentiation of when to use each skill

## Potential Rationalization Risks

### Risk 1: "Fix is obvious, skip RED phase"

**Mitigation in skill**:
```markdown
**Critical:** Get actual run IDs, branch names, git commit hashes, error messages - not hypothetical scenarios.
```

**Strength**: Uses "Critical" marker and contrasts real vs hypothetical

**Additional test**: Created test-scenario-testing-spectacular.md showing this pressure

### Risk 2: "Testing takes too long, orchestrators waiting"

**Mitigation in skill**:
```markdown
**Time investment**: 3 hours RED-GREEN-REFACTOR testing prevents repeated failures across all future spectacular executions.
```

**Strength**: Shows ROI explicitly, frames testing as efficiency improvement

### Risk 3: "I'll just add explicit commands, that's obviously better"

**Mitigation in skill**:
```markdown
**RED Phase Evidence**
**Source**: Run ID 9f92a8 git log and execution transcript
...
**Root cause**: execute.md line 82 says "Orchestrator stays in main repo" but doesn't enforce with verification
```

**Strength**: Shows that "obvious" fixes need evidence of actual failure mode

## Quality Assessment

**Strengths**:
1. Grounded in real execution failures (9f92a8, RED phase docs)
2. Includes spectacular-specific pressure types and patterns
3. Comprehensive rationalization table from actual evidence
4. Clear differentiation from similar testing skills
5. Explicit TodoWrite checklist requirement
6. Shows before/after fix patterns with consequences
7. Real-world impact section with concrete results

**Potential Improvements** (for future iteration):
1. Could add more code examples of test repository setup
2. Could include example GREEN test scenario documents
3. Could add more edge cases in REFACTOR section

**Overall Quality**: ✅ **HIGH** - Skill meets all superpowers format requirements and is grounded in real evidence

## Testing Recommendation

**Current Status**: Skill passes structured quality review

**Next Steps**:
1. **Deploy and monitor**: Use skill in next spectacular command improvement
2. **Gather usage evidence**: Document if agents skip steps or rationalize
3. **Iterate if needed**: Add counters for any new rationalizations discovered
4. **Full pressure test**: After 2-3 uses, run full subagent pressure scenarios if issues emerge

**Rationale**: This is a technique/reference skill derived from real evidence. The best test is real-world usage monitoring. If agents start rationalizing away steps, THEN do full pressure testing and add explicit counters.

## Acceptance Criteria Check

From task requirements:

- [x] `skills/testing-spectacular/SKILL.md` follows superpowers format (name, description frontmatter)
- [x] Skill includes rationalization table with shortcuts from 9f92a8 testing experience
- [x] Skill requires TodoWrite checklist for RED-GREEN-REFACTOR phases
- [x] Skill has been tested with structured review approach (evidence documented here)

**Note**: Full subagent pressure testing (as done for discipline-enforcing skills) is recommended after initial deployment and usage monitoring. This skill documents a testing methodology and is itself derived from RED phase evidence.

## Conclusion

The testing-spectacular skill is **ready for deployment** with:
- All superpowers format requirements met
- Rationalization table grounded in real 9f92a8 failures
- Comprehensive testing checklist with TodoWrite requirement
- Quality verification documented with evidence

**Recommendation**: Proceed with commit and deploy. Monitor for rationalization patterns in actual use. Iterate with full pressure testing if issues emerge.

---

**Date**: 2025-11-03
**Reviewer**: Implementation subagent (Task 3)
**Evidence**: This document + test-scenario-testing-spectacular.md + 9f92a8 analysis + RED phase findings
