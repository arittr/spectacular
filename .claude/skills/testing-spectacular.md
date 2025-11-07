---
name: testing-spectacular
description: Use when creating or editing spectacular commands/skills before deployment, to verify implementation matches specification through RED-GREEN-REFACTOR testing with subagents - enforces binary pass/fail verdicts with evidence and artifact storage
---

# Testing Spectacular

## Overview

**Testing spectacular commands and skills IS Test-Driven Development applied to workflow documentation.**

You find real execution failures (git logs, test failures), create test scenarios that reproduce them, watch implementation fail the scenario (RED), fix the implementation (GREEN), and verify the fix works (REFACTOR).

**Core principle:** If you didn't watch implementation fail a test first, you don't know if your fix addresses the right problem.

**REQUIRED BACKGROUND:** You MUST understand superpowers:test-driven-development before using this skill. That skill defines the fundamental RED-GREEN-REFACTOR cycle. This skill applies TDD to spectacular development.

## When to Use

Use when:
- Creating new commands (\`commands/*.md\`)
- Editing existing skills (\`skills/*/SKILL.md\`)
- Investigating reported bugs or stalls
- Before committing changes to commands/skills
- Before releasing new spectacular versions

Don't use when:
- Just reading documentation
- Making trivial typo fixes
- Updating examples without changing logic

**Announce:** "I'm using testing-spectacular to verify this implementation against test scenarios."

## The Process

### RED Phase: Find Real Failure or Create Failing Test

**Goal:** Get evidence that implementation doesn't meet requirements.

**Two paths:**

**Path A: Real Failure (Bug Investigation)**
1. Review error reports, git logs, user feedback
2. Identify which test scenario covers this failure
3. Run test suite: \`./tests/run-tests.sh execute\`
4. Verify scenario FAILS with current implementation
5. Document exact failure mode (quote scenario requirements violated)

**Path B: New Feature (TDD)**
1. Create test scenario FIRST (see Scenario Format below)
2. Run test suite: \`./tests/run-tests.sh execute\`
3. Verify scenario FAILS (implementation doesn't exist yet)
4. Document what's missing

**Evidence Requirements:**
- [ ] Exact file locations where implementation falls short
- [ ] Quote scenario requirements that are violated
- [ ] Show verification command output proving failure
- [ ] Save artifacts to \`tests/results/{timestamp}/\`

### GREEN Phase: Fix Implementation

**Goal:** Make the failing test pass with minimal changes.

**Steps:**
1. Fix the command or skill to meet scenario requirements
2. Run affected scenarios: \`./tests/run-tests.sh execute\`
3. Verify scenarios now PASS
4. Check for regressions: Run full suite if changes were broad
5. Review artifacts in \`tests/results/{timestamp}/\`

**Quality checks:**
- [ ] Binary verdict: PASS or FAIL (no "mostly works")
- [ ] Evidence: File locations, line numbers, command outputs
- [ ] Rationale: Quote requirements, explain why this passes
- [ ] No regressions: Related scenarios still pass

### REFACTOR Phase: Close Loopholes

**Goal:** Find edge cases and improve clarity without breaking tests.

**Steps:**
1. Review related scenarios for similar issues
2. Identify potential edge cases not covered
3. Create additional test scenarios if needed
4. Improve implementation clarity
5. Re-run full test suite: \`./tests/run-tests.sh execute\`
6. Verify all tests still pass

**Common improvements:**
- Add explicit warnings to prevent misinterpretation
- Show exact commands to reduce ambiguity
- Add CRITICAL markers for safety-critical steps
- Cross-reference related skills

## Test Scenario Format

**Create scenarios in:** \`tests/scenarios/{command}/*.md\`

**Template:**

\`\`\`markdown
---
id: scenario-name
type: integration              # unit, integration, e2e
severity: critical             # critical, major, minor
estimated_duration: 5m
requires_git_repo: true
tags: [tag1, tag2]
---

# Test Scenario: [Title]

## Context

Brief description of what this tests and why it's important.

## Expected Behavior

Detailed description of correct behavior when implementation is working.

## Verification Commands

\`\`\`bash
# Commands test subagent will run to verify implementation
grep -n "expected text" skills/skill-name/SKILL.md
\`\`\`

## Evidence of PASS

- [ ] Line X in file Y contains: "expected text"
- [ ] Verification command exits with code 0
- [ ] NO lines contain anti-pattern text

## Evidence of FAIL

- [ ] Missing required text
- [ ] Contains anti-pattern wording
- [ ] Verification command fails
- [ ] File/section doesn't exist

## Anti-Patterns to Detect

List specific incorrect implementations that should fail this test.
\`\`\`

**Key elements:**
- Machine-readable frontmatter (YAML)
- Explicit verification commands (grep, test, etc.)
- Binary pass/fail criteria (checkboxes)
- No subjective assessment

## Running Tests

**Manually (during development):**
\`\`\`bash
# Run all execute scenarios
./tests/run-tests.sh execute

# Results saved to:
tests/results/{timestamp}/summary.md
tests/results/{timestamp}/scenarios/*.log
\`\`\`

**What happens:**
1. Script discovers scenarios matching command
2. Dispatches parallel subagents (one per scenario)
3. Each subagent verifies implementation
4. Results aggregated and saved
5. Summary report generated

**Exit codes:**
- 0 = All tests pass
- 1 = One or more tests fail

## Evidence Requirements

**Every test result MUST include:**

1. **Binary Verdict**: ✅ PASS or ❌ FAIL
   - No "mostly works"
   - No "documentation issue not functional bug"
   - Either meets requirements or doesn't

2. **Evidence**: Concrete proof
   - File locations with line numbers
   - Verification command outputs
   - Quoted text from implementation

3. **Rationale**: Why this verdict
   - Quote scenario requirements
   - Show how implementation meets/fails them
   - Cite specific success criteria

4. **Artifacts**: Saved for review
   - Individual scenario logs
   - Evidence files
   - Summary report

**Violation examples:**
- ❌ "This seems fine" (no evidence)
- ❌ "Close enough" (binary verdict required)
- ❌ "Minor documentation issue" (still FAIL)

## Artifact Storage

**Location:** \`tests/results/{timestamp}/\`

**Structure:**
\`\`\`
tests/results/2025-01-15-143027/
├── summary.md                    # Overall pass/fail, recommendations
├── scenarios/
│   ├── scenario-1.log           # Individual test results
│   ├── scenario-2.log
│   └── scenario-3.log
└── evidence/
    ├── skill-excerpts/          # Relevant file sections
    └── verification-outputs/     # Command results
\`\`\`

**Retention:** Keep all runs (manual cleanup when needed)

## Quality Rules

**Binary Verdicts:**
- ✅ Implementation meets ALL success criteria
- ❌ Implementation violates ANY success criteria
- No middle ground, no "mostly works"

**Evidence Required:**
- Every PASS must cite specific evidence
- Every FAIL must show what's missing
- Quote file locations and line numbers
- Show verification command outputs

**No Subjective Assessment:**
- "Seems good" → Show evidence
- "Minor issue" → Still FAIL, fix it
- "Good enough" → Meets criteria or doesn't

## Rationalization Table

| Rationalization | Reality | What To Do |
|----------------|---------|------------|
| "This mostly works" | FAIL - either meets requirements or doesn't | Mark FAIL, fix implementation |
| "Documentation issue not functional bug" | Still FAIL - docs are requirements | Fix documentation, re-test |
| "Good enough for now" | No - fix before committing | Apply GREEN fix, re-test |
| "Just need to tweak one thing" | Might introduce regression | Run full suite after any change |
| "Tests are too strict" | Tests encode actual requirements | Fix implementation, not tests |
| "Can skip testing for small changes" | Small changes cause big bugs | Test every change, no exceptions |
| "I already tested manually" | Manual testing ≠ repeatable verification | Run automated test suite |
| "I'll test if problems emerge" | Problems = agents can't use spectacular | Test BEFORE deploying |

## Red Flags - STOP and Test

If you're thinking ANY of these, you're about to skip testing:

- "Too simple to need testing"
- "I'll test after committing"
- "Just a small documentation fix"
- "I manually verified it works"
- "Testing is overkill for this"
- "No time to run tests"

**All of these mean: STOP. Run the test suite. No exceptions.**

## Common Mistakes

**❌ Subjective pass/fail assessment**
Treating "documentation issues" as less severe than "functional bugs".
✅ **Fix:** Both are FAIL. Fix and re-test.

**❌ No artifact storage**
Results only in conversation, can't review or compare.
✅ **Fix:** Save to \`tests/results/{timestamp}/\` every run.

**❌ Testing after implementation**
Writing code/docs then testing proves nothing (always passes).
✅ **Fix:** Create failing test FIRST (RED phase).

**❌ Accepting "mostly works"**
Relaxing standards under time pressure.
✅ **Fix:** Binary verdict required - meets criteria or doesn't.

**❌ Skipping tests for "small changes"**
Assuming minor edits can't break things.
✅ **Fix:** Test every change. Small changes cause big bugs.

## Integration with Development Workflow

**When creating new command:**
1. Write test scenario FIRST
2. Run tests (scenario fails - RED)
3. Write command implementation
4. Run tests (scenario passes - GREEN)
5. Improve clarity (REFACTOR)
6. Commit with test results

**When fixing bugs:**
1. Reproduce with test scenario
2. Verify scenario fails (RED)
3. Fix implementation
4. Verify scenario passes (GREEN)
5. Run full suite (no regressions)
6. Commit with evidence

**Before committing any change:**
1. Run affected scenarios
2. Verify all pass
3. Review artifacts
4. Include test results in commit message

## The Iron Law

**NO SPECTACULAR CHANGES WITHOUT PASSING TESTS FIRST**

This applies to:
- New commands
- New skills
- Edits to existing commands
- Edits to existing skills
- Bug fixes
- Documentation updates

**No exceptions:**
- Not for "simple additions"
- Not for "just fixing typos"
- Not for "documentation updates"
- Not for "quick fixes"

**Violating this = Deploying untested code**

## Testing Checklist

**IMPORTANT: Use TodoWrite to track these steps.**

**RED Phase:**
- [ ] Find real failure OR create test scenario first
- [ ] Run test suite: \`./tests/run-tests.sh execute\`
- [ ] Verify scenario FAILS with current implementation
- [ ] Document exact failure mode with evidence
- [ ] Save artifacts to review

**GREEN Phase:**
- [ ] Fix implementation to meet scenario requirements
- [ ] Run affected scenarios
- [ ] Verify scenarios now PASS
- [ ] Check for regressions (run full suite if needed)
- [ ] Review artifacts in \`tests/results/{timestamp}/\`

**REFACTOR Phase:**
- [ ] Identify edge cases not covered
- [ ] Create additional scenarios if needed
- [ ] Improve implementation clarity
- [ ] Re-run full test suite
- [ ] Verify all tests still pass

**Quality Checks:**
- [ ] All verdicts are binary (PASS or FAIL)
- [ ] All results include concrete evidence
- [ ] All artifacts saved to results directory
- [ ] No subjective assessments ("seems fine")
- [ ] No relaxed standards ("mostly works")

## The Bottom Line

**Testing spectacular IS TDD for workflow documentation.**

Same Iron Law: No changes without passing tests first.
Same cycle: RED (failing test) → GREEN (fix) → REFACTOR (improve).
Same benefits: Better quality, fewer surprises, bulletproof results.

If you follow TDD for code, follow it for spectacular. It's the same discipline applied to documentation.
