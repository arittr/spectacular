---
id: code-review-rejection-loop
type: integration
severity: critical
estimated_duration: 5m
requires_git_repo: false
tags: [code-review, autonomous-execution, fix-loop, iteration-tracking]
---

# Test Scenario: Code Review Rejection Loop with Automatic Fixes

## Context

Testing that orchestrator **automatically dispatches fix subagents** when code review rejects, then re-reviews in a loop until approval - with NO user prompting.

**Setup:**
- Feature with Phase 1 completed (sequential or parallel)
- Code review finds critical issues and returns "Ready to merge? No"
- Orchestrator must autonomously fix → re-review → repeat until "Yes"

**Why critical:**
- Core value prop: Autonomous execution from spec to stack
- User intervention breaks flow and defeats parallelization benefits
- Fix → re-review loop proves quality gates work end-to-end
- Tests orchestrator under realistic pressure (rejections are common)

## Expected Behavior

### Flow Overview

```
Phase completes → Code review → REJECTED
                              ↓
                    Dispatch fix subagent (NO USER PROMPT)
                              ↓
                    Fix completes → Re-review
                              ↓
                    Still REJECTED? → Repeat loop
                              ↓
                    APPROVED? → Continue to next phase
```

**Critical:** Orchestrator NEVER asks user "what should I do?" - it autonomously fixes.

### Iteration 1: Initial Review Rejection

**Phase 1 completes:**
```
✅ Phase 1: Database Foundation complete
   Task 1.1: Schema definition (branch: {runid}-task-1-1-schema)
```

**Orchestrator dispatches code review:**
```
⏺ Skill(requesting-code-review)
  Prompt: Review Phase 1 implementation against spec
  ⎿  Done (18 tool uses · 54.2k tokens · 2m 15s)
```

**Code review returns REJECTION:**
```markdown
### Issues

#### Critical
- Missing index on `users.email` field (schema.prisma:15)
- Unique constraint on `games.accessCode` is case-sensitive, should be case-insensitive

#### Important
- Migration missing down migration for rollback safety

### Assessment

**Ready to merge? No**

**Reasoning:** Schema has critical performance and correctness issues that must be fixed before proceeding to API layer.
```

**Orchestrator response (CORRECT):**
```
⏺ ❌ Code review REJECTED - critical issues found

Issues identified:
- Critical: Missing index on users.email field
- Critical: Unique constraint on games.accessCode is case-sensitive
- Important: Migration missing down migration

⏺ Dispatching fix subagent to address all identified issues...

⏺ Task(Fix Phase 1 code review issues)
  Prompt: Fix the following issues in Phase 1:
  [Lists all issues with locations]

  CRITICAL: Work in .worktrees/{runid}-main
  CRITICAL: Amend or add to existing branch {runid}-task-1-1-schema

  ⎿  Running...
```

**What orchestrator does NOT do:**
```
❌ WRONG: "Phase 1 code review found issues. Would you like me to:
           1. Fix now
           2. Manual fix
           3. Skip and proceed"

❌ WRONG: "Critical issues found. Please review and let me know how to proceed."

❌ WRONG: "Code review rejected. See issues above."
```

### Iteration 2: Fix Applied, Re-Review Automatically

**Fix subagent completes:**
```
⏺ Task(Fix Phase 1 code review issues)
  ⎿  Done (12 tool uses · 31.5k tokens · 1m 45s)

✅ Fixed all identified issues:
   - Added index on users.email
   - Changed accessCode constraint to case-insensitive
   - Added down migration

Branch updated: {runid}-task-1-1-schema
```

**Orchestrator AUTOMATICALLY dispatches re-review (no user prompt):**
```
⏺ Re-reviewing Phase 1 after fixes...

⏺ Skill(requesting-code-review)
  Prompt: Review Phase 1 implementation against spec (retry after fixes)
  ⎿  Done (15 tool uses · 48.7k tokens · 2m 5s)
```

**Code review returns approval:**
```markdown
### Assessment

**Ready to merge? Yes**

**Reasoning:** All critical issues resolved. Schema follows best practices, migration is reversible, indexes properly configured.
```

**Orchestrator response:**
```
✅ Code review APPROVED (after 1 fix iteration) - Phase 1 complete, proceeding to Phase 2
```

**Total iterations: 2 (reject → fix → approve)**

### Iteration 3+: Multiple Fix Cycles (Pressure Test)

**Scenario:** Code review rejects multiple times due to complex issues.

**First rejection:**
```
Ready to merge? No
- Missing authentication checks
- SQL injection vulnerability
```

**Orchestrator:** Dispatches fix subagent (no prompt)

**Second rejection:**
```
Ready to merge? With fixes
- Tests still failing after security fixes
- Edge case not handled (empty email)
```

**Orchestrator:** Dispatches fix subagent AGAIN (no prompt)

**Third review:**
```
Ready to merge? Yes
```

**Orchestrator:** Proceeds to next phase

**Total iterations: 3 (reject → fix → reject → fix → approve)**

## Success Criteria

### Autonomous Fix Dispatch
- [ ] "Ready to merge? No" → orchestrator dispatches fix subagent immediately
- [ ] "Ready to merge? With fixes" → orchestrator dispatches fix subagent immediately
- [ ] NO user prompt appears (no "Would you like me to...", no options)
- [ ] Orchestrator reports issues found but does NOT ask what to do

### Automatic Re-Review Loop
- [ ] After fix subagent completes → orchestrator dispatches review automatically
- [ ] NO user confirmation required between fix and re-review
- [ ] Loop continues until "Ready to merge? Yes"
- [ ] Supports multiple iterations (1, 2, 3+ fix cycles)

### Fix Subagent Integration
- [ ] Fix subagent receives all issues from review output
- [ ] Fix subagent works in correct worktree/branch
- [ ] Fix subagent amends or adds to existing branch (no new branch)
- [ ] Fixes are comprehensive (addresses all listed issues)

### Messaging Clarity
- [ ] Orchestrator reports: "Code review REJECTED" (not "found issues - what should I do?")
- [ ] Orchestrator reports: "Dispatching fix subagent" (not "asking user")
- [ ] Orchestrator reports: "Re-reviewing after fixes" (automatic, not prompted)
- [ ] Final message: "Code review APPROVED (after N iterations)"

### Edge Cases
- [ ] Handles rejection on first review
- [ ] Handles rejection on second review (fix wasn't sufficient)
- [ ] Handles approval on first review (no fixes needed)
- [ ] Handles 3+ rejection cycles without confusion

## Verification Commands

```bash
# Check sequential phase for autonomous fix dispatch
grep -n "Dispatch fix subagent" skills/executing-sequential-phase/SKILL.md
grep -n "DO NOT ask user" skills/executing-sequential-phase/SKILL.md
grep -n "Re-reviewing" skills/executing-sequential-phase/SKILL.md
grep -n "REJECTION_COUNT" skills/executing-sequential-phase/SKILL.md

# Check parallel phase for same requirements
grep -n "Dispatch fix subagent" skills/executing-parallel-phase/SKILL.md
grep -n "DO NOT ask user" skills/executing-parallel-phase/SKILL.md
grep -n "Re-reviewing" skills/executing-parallel-phase/SKILL.md
grep -n "REJECTION_COUNT" skills/executing-parallel-phase/SKILL.md

# Verify escalation logic exists
grep -n "REJECTION_COUNT.*>.*3" skills/executing-sequential-phase/SKILL.md
grep -n "REJECTION_COUNT.*>.*3" skills/executing-parallel-phase/SKILL.md
```

## Evidence of PASS

### Sequential Phase
- [ ] Line X in `skills/executing-sequential-phase/SKILL.md` contains: "Dispatch fix subagent to address all identified issues"
- [ ] Line Y contains: "DO NOT ask user what to do - autonomous fixing is expected"
- [ ] Line Z contains: "Re-reviewing Phase" (automatic re-review after fixes)
- [ ] REJECTION_COUNT variable implemented for iteration tracking
- [ ] Escalation check exists: `if [ $REJECTION_COUNT -gt 3 ]`
- [ ] NO lines contain: "or report to user"
- [ ] NO lines contain: "Would you like me to"
- [ ] NO lines contain: "Should I"

### Parallel Phase
- [ ] Same requirements met in `skills/executing-parallel-phase/SKILL.md`
- [ ] All autonomous dispatch and iteration tracking present
- [ ] Escalation logic identical to sequential phase

### Fix Subagent Prompt
- [ ] Both skills include fix subagent prompt template
- [ ] Prompt includes spec anchoring (CONTEXT FOR FIXES section)
- [ ] Prompt instructs reading constitution and spec before fixes
- [ ] Prompt lists all issues with file locations
- [ ] Prompt specifies working in correct worktree/branch

## Evidence of FAIL

- [ ] Missing "Dispatch fix subagent" instruction in either skill
- [ ] Contains ambiguous wording: "or report to user"
- [ ] Contains user prompting: "Would you like me to", "Should I"
- [ ] Missing automatic re-review instruction
- [ ] Missing REJECTION_COUNT iteration tracking
- [ ] Missing escalation check after 3 rejections
- [ ] Fix subagent prompt missing spec anchoring
- [ ] Verification commands fail or return no matches

## Anti-Patterns to Detect

### Anti-Pattern 1: Asking User Instead of Fixing

**Symptom:**
```
⏺ Phase 1 code review found critical issues that need fixing:
  - Missing index on users.email
  - Case-sensitive constraint on accessCode

Options:
1. Fix now: I can dispatch a fix subagent
2. Manual fix: You fix manually
3. Review detailed report

Would you like me to fix automatically?
```

**Why WRONG:**
- ❌ Gives user false choice - fixing IS the workflow
- ❌ Breaks autonomous execution
- ❌ Suggests orchestrator lacks confidence in its design

**Correct behavior:**
```
⏺ ❌ Code review REJECTED - critical issues found
  - Missing index on users.email
  - Case-sensitive constraint on accessCode

⏺ Dispatching fix subagent to address all identified issues...
```

### Anti-Pattern 2: Stopping After Fix Without Re-Review

**Symptom:**
```
⏺ Task(Fix Phase 1 issues)
  ⎿  Done

✅ Issues fixed. Phase 1 complete - proceeding to Phase 2
```

**Why WRONG:**
- ❌ No verification that fixes actually resolved issues
- ❌ Could proceed with broken code
- ❌ Defeats purpose of code review gate

**Correct behavior:**
```
⏺ Task(Fix Phase 1 issues)
  ⎿  Done

⏺ Re-reviewing Phase 1 after fixes...

⏺ Skill(requesting-code-review)
  ⎿  Done

✅ Code review APPROVED - Phase 1 complete, proceeding
```

### Anti-Pattern 3: Asking Between Fix and Re-Review

**Symptom:**
```
⏺ Task(Fix Phase 1 issues)
  ⎿  Done

Issues should now be resolved. Should I re-run code review?
```

**Why WRONG:**
- ❌ Obvious answer (always re-review)
- ❌ Introduces unnecessary user wait
- ❌ Breaks autonomous flow

**Correct behavior:**
```
⏺ Task(Fix Phase 1 issues)
  ⎿  Done

⏺ Re-reviewing Phase 1 after fixes...
```

### Anti-Pattern 4: Infinite Loop on Repeated Rejections

**Symptom:**
```
Review 1: REJECTED → Fix → Review 2: REJECTED → Fix → Review 3: REJECTED → Fix → Review 4: REJECTED → ...
(loops forever without escalation)
```

**Why WRONG:**
- ❌ Wastes resources on unsolvable problems
- ❌ Should detect repeated failures and report to user

**Correct behavior:**
```
Review 1: REJECTED → Fix → Review 2: REJECTED → Fix → Review 3: REJECTED

⏺ ⚠️  Code review rejected 3 times. Issues may require architectural changes
  beyond subagent scope. Reporting to user:

[Detailed issue analysis and suggested next steps]
```

**Acceptable iteration limits:** 3-5 attempts, then escalate to user.

## Test Execution

### Setup

1. Create feature spec with Phase 1: Database Foundation
2. Intentionally introduce issues:
   - Missing index
   - Incorrect constraint config
   - Missing migration down
3. Run `/spectacular:execute`

### Execute

```bash
/spectacular:execute @specs/{runid}-{feature}/plan.md

# Phase 1 completes
# Code review dispatched
# REJECTION returned

# Verify: NO user prompt appears
# Verify: Fix subagent dispatched automatically
# Verify: Re-review dispatched after fix
# Verify: Loop continues until approval
```

### Verification Points

**After first rejection:**
- [ ] Check orchestrator output for "Dispatching fix subagent" (not "Would you like me to...")
- [ ] Verify Task tool invoked with fix prompt
- [ ] Verify NO AskUserQuestion tool invoked

**After fix completes:**
- [ ] Check orchestrator output for "Re-reviewing" (not "Should I re-review?")
- [ ] Verify Skill(requesting-code-review) invoked again
- [ ] Verify iteration count tracked

**After approval:**
- [ ] Check final message includes iteration count: "(after N iterations)"
- [ ] Verify orchestrator proceeds to next phase
- [ ] Verify NO user interaction required throughout loop

## Related Scenarios

- **code-review-binary-enforcement.md** - Binary Yes/No/With fixes parsing logic
- **code-review-malformed-retry.md** - Handling malformed review output
- **task-failure-recovery.md** - General task failure handling patterns

## Pressure Test Variants

### Variant A: Single Fix Cycle
- Review rejects → Fix → Review approves
- **Expected iterations:** 2 (reject, approve)

### Variant B: Double Fix Cycle
- Review rejects → Fix → Review rejects again → Fix → Review approves
- **Expected iterations:** 3 (reject, reject, approve)

### Variant C: Immediate Approval
- Review approves on first try
- **Expected iterations:** 1 (approve)
- **No fix subagent dispatched**

### Variant D: Complex Multi-Issue Fixes
- Review finds 5+ issues across multiple files
- Fix addresses all simultaneously
- **Expected iterations:** 2 (reject, approve)
- **Fix subagent must handle complexity**

### Variant E: Escalation After 3 Rejections
- Review rejects → Fix → Review rejects → Fix → Review rejects → Fix → Review rejects
- **Expected behavior:** After 3-5 rejections, report to user for manual intervention
- **Prevents infinite loops on unsolvable problems**

## Implementation Notes

**Where autonomous dispatch happens:**

Both `executing-parallel-phase` and `executing-sequential-phase` skills document this at Step 8 (Code Review):

```markdown
- ❌ **"Ready to merge? No"** → REJECTED
  - Dispatch fix subagent to address all identified issues
  - DO NOT ask user what to do - autonomous fixing is expected
  - Go to step 5 (re-review after fixes)
```

**Fix subagent prompt should include:**
- All issues from review (Critical + Important + Minor)
- File locations for each issue
- **SPEC ANCHORING:** Instruction to read constitution (docs/constitutions/current/)
- **SPEC ANCHORING:** Instruction to read feature spec (specs/{run-id}-{feature-slug}/spec.md)
- **SPEC ANCHORING:** Explanation of why spec provides context for fixes (architectural rationale, integration requirements)
- Instruction to apply fixes following spec + constitution patterns
- Instruction to work in existing branch (amend or add commit)
- Instruction to run quality checks before completion

**Why spec anchoring in fix subagents:**
- Fix subagents modify existing code, need same architectural context as original implementation
- Without spec: Fixes may violate architectural decisions or integration requirements
- Without constitution: Fixes may use patterns inconsistent with codebase standards
- Fixes without context create new drift while "fixing" old drift

**Re-review should:**
- Use same `requesting-code-review` skill
- Pass same phase context as original review
- Include note: "(retry after fixes applied)"

## Red Flags

If orchestrator says ANY of these, test FAILS:

- "Would you like me to fix automatically?"
- "Options: 1. Fix now, 2. Manual fix, 3. Continue"
- "Review rejected - what should I do?"
- "Issues found. Please review and advise."
- "Should I re-run code review after fixes?"
- "Code review requires manual intervention"

All indicate orchestrator is asking permission instead of acting autonomously.
