# Test Scenario: Code Review Binary Enforcement

## Context

Testing that code review acts as a **hard binary quality gate** after phase completion.

**Setup:**
- Feature with at least one completed phase (sequential or parallel)
- Code review agent dispatched using `requesting-code-review` skill
- Orchestrator must interpret review results strictly

**Why critical:**
- Prevents "APPROVED WITH MINOR SUGGESTIONS" from bypassing quality gates
- Treats missing/malformed output as failure (not success)
- Ensures issues are fixed before compounding across phases
- Binary decision enables autonomous execution without judgment calls

## Expected Behavior

### Success Case: Review Approves

**Code review returns:**
```
### Assessment

**Ready to merge? Yes**

**Reasoning:** All acceptance criteria met, tests passing, architecture follows constitution patterns.
```

**Orchestrator action:**
- ✅ Parse "Ready to merge? Yes"
- ✅ Announce: "Code review APPROVED - proceeding to Phase N+1"
- ✅ Continue to next phase

### Failure Case 1: Review Rejects

**Code review returns:**
```
### Issues

#### Critical
- Missing authentication check in API endpoint

### Assessment

**Ready to merge? No**

**Reasoning:** Critical security issue must be fixed.
```

**Orchestrator action:**
- ❌ Parse "Ready to merge? No"
- ❌ STOP execution
- ❌ List all Critical and Important issues from review
- ❌ Dispatch fix subagent to address all identified issues (autonomous - NO user prompt)
- ❌ Re-review after fixes complete
- ❌ Only proceed when review returns "Yes"

### Failure Case 2: Review Requires Fixes

**Code review returns:**
```
### Issues

#### Important
- Missing test coverage for error cases

### Assessment

**Ready to merge? With fixes**

**Reasoning:** Implementation solid but needs test coverage before proceeding.
```

**Orchestrator action:**
- ❌ Parse "Ready to merge? With fixes"
- ❌ STOP execution (treat as REJECTED)
- ❌ List all issues from review
- ❌ Dispatch fix subagent to address all identified issues (autonomous - NO user prompt)
- ❌ Re-review after fixes complete
- ❌ Only proceed when review returns "Yes"

### Failure Case 3: Soft Language (Anti-Pattern)

**Code review returns:**
```
### Assessment

**Ready to merge: With fixes**

Excellent! Code review complete with APPROVED WITH MINOR SUGGESTIONS. The implementation is high quality and ready for Phase 3.
```

**Orchestrator action:**
- ❌ Parse output - does NOT contain "Ready to merge? Yes"
- ❌ Detect soft language: "APPROVED WITH MINOR SUGGESTIONS"
- ❌ STOP execution (reject soft approvals)
- ❌ Warn: "Code review used soft language. Binary gate requires 'Ready to merge? Yes'"
- ❌ Re-review or fail execution

**Why reject:** "APPROVED WITH X" means NOT APPROVED. Only "Yes" proceeds.

### Failure Case 4: No Output

**Code review returns:**
```
(empty/timeout/error)
```

**Orchestrator sees:**
```
⏺ superpowers:code-reviewer(Code review Phase 5)
  ⎿  Done (55 tool uses · 57.1k tokens · 4m 9s)

[No output returned]
```

**Orchestrator action (first attempt):**
- ⚠️ Detect missing output
- ⚠️ Warn: "Code review returned no output - retrying once"
- 🔄 Dispatch `requesting-code-review` again (transient issue)
- ⏳ Wait for retry result

**If retry succeeds:**
- ✅ Parse retry output normally (Yes/No/With fixes)
- ✅ Announce: "Code review APPROVED (retry succeeded)" if Yes

**If retry ALSO has no output:**
- ❌ STOP execution immediately
- ❌ Report: "Code review failed twice with no output"
- ❌ Display both attempt results for debugging
- ❌ Suggest: "Check review agent logs, may need manual review"
- ❌ DO NOT proceed

**Why critical:** No output = unknown state. Retry once for transient issues, then fail.

**See also:** `code-review-malformed-retry.md` for detailed retry behavior.

### Failure Case 5: Malformed Output

**Code review returns:**
```
The code looks good overall. Some minor tweaks needed but nothing blocking.
```

**Orchestrator action (first attempt):**
- ⚠️ Search for "Ready to merge?" field - NOT FOUND
- ⚠️ Warn: "Code review output missing 'Ready to merge?' field - retrying once"
- 🔄 Dispatch `requesting-code-review` again (may be transient issue)
- ⏳ Wait for retry result

**If retry succeeds:**
- ✅ Parse retry output normally (Yes/No/With fixes)
- ✅ Announce: "Code review APPROVED (retry succeeded)" if Yes

**If retry ALSO missing field:**
- ❌ STOP execution immediately
- ❌ Report: "Code review failed twice with malformed output"
- ❌ Display excerpts from both attempts for debugging
- ❌ Suggest: "Review agent may not be following template - check code-reviewer skill"
- ❌ DO NOT hallucinate issues from malformed text
- ❌ DO NOT dispatch fix subagents
- ❌ Fail execution

**See also:** `code-review-malformed-retry.md` for detailed retry behavior and anti-hallucination rules.

## Parsing Algorithm

**Orchestrator must follow this strict algorithm:**

```python
def parse_review_result(output: str, is_retry: bool = False) -> Decision:
    # Check for no output
    if not output or output.strip() == "":
        if is_retry:
            return REJECTED("Both attempts returned no output")
        else:
            return RETRY("No output - retrying once")

    # Search for "Ready to merge?" field
    if "Ready to merge? Yes" in output:
        return APPROVED()

    if "Ready to merge? No" in output:
        return REJECTED("Review explicitly rejected")

    if "Ready to merge? With fixes" in output:
        return REJECTED("Review requires fixes before proceeding")

    # Soft language detection (immediate rejection, no retry)
    if "APPROVED" in output and "Ready to merge? Yes" not in output:
        return REJECTED("Soft language detected - binary gate requires explicit 'Yes'")

    # Missing field - retry once for transient issues
    if not is_retry:
        return RETRY("Missing 'Ready to merge?' field - retrying")
    else:
        return REJECTED("Both attempts produced malformed output")

# Main review flow
attempt_1 = parse_review_result(review_output_1, is_retry=False)

if attempt_1 == RETRY:
    # Dispatch code-reviewer again
    review_output_2 = dispatch_code_review()
    attempt_2 = parse_review_result(review_output_2, is_retry=True)
    return attempt_2
else:
    return attempt_1
```

**Only APPROVED() allows proceeding. RETRY triggers one retry attempt. Everything else stops execution.**

**Note:** See `code-review-malformed-retry.md` for comprehensive retry behavior specification.

## Anti-Patterns to Detect

### Anti-Pattern 1: Assuming Success from No Output

**Wrong:**
```
Review returned nothing → must be fine → proceed to next phase
```

**Correct:**
```
Review returned nothing → unknown state → STOP and report failure
```

### Anti-Pattern 2: Soft Approval Bypass

**Wrong:**
```
Review says "APPROVED WITH MINOR SUGGESTIONS" → contains "APPROVED" → proceed
```

**Correct:**
```
Review says "APPROVED WITH X" → NOT "Ready to merge? Yes" → STOP
```

### Anti-Pattern 3: Judgment Calls on Severity

**Wrong:**
```
Review found "Important" issues → but implementation is solid → proceed anyway
```

**Correct:**
```
Review says "With fixes" → STOP, no judgment calls → fix then re-review
```

### Anti-Pattern 4: Proceeding Without Re-Review

**Wrong:**
```
Review rejected → dispatch fix → assume fixed → proceed
```

**Correct:**
```
Review rejected → dispatch fix → re-run review → verify "Yes" → then proceed
```

## Success Criteria

### Code Review Parsing
- [ ] "Ready to merge? Yes" → orchestrator proceeds to next phase
- [ ] "Ready to merge? No" → orchestrator stops and reports rejection
- [ ] "Ready to merge? With fixes" → orchestrator stops and dispatches fixes
- [ ] No output → orchestrator stops and reports failure
- [ ] Soft language ("APPROVED WITH X") → orchestrator stops and warns

### Execution Flow
- [ ] After APPROVED: orchestrator announces approval and continues
- [ ] After REJECTED: orchestrator does NOT proceed to next phase
- [ ] After fixes: orchestrator re-runs review before proceeding
- [ ] Re-review loop: repeats until "Ready to merge? Yes"

### Documentation in Skills
- [ ] `executing-sequential-phase` documents binary parsing algorithm
- [ ] `executing-parallel-phase` documents binary parsing algorithm
- [ ] Both skills explicitly state: "Only 'Yes' allows proceeding"
- [ ] Both skills show how to detect soft language
- [ ] Both skills show how to handle no output

## Implementation Verification

**Check:** `skills/executing-sequential-phase/SKILL.md` at "Step 4: Code Review"

Should contain:
```markdown
1. Use `requesting-code-review` skill to call code-reviewer
2. Parse the output strictly:
   - "Ready to merge? Yes" → Phase complete, proceed
   - "Ready to merge? No" → STOP, dispatch fix subagent
   - "Ready to merge? With fixes" → STOP, dispatch fix subagent
   - No output → STOP, report failure
   - Other → STOP, warn about format
3. If stopped: fix issues, re-review, repeat until "Yes"
```

**Check:** `skills/executing-parallel-phase/SKILL.md` at "Step 8: Code Review"

Should contain identical parsing logic.

## Red Flag Indicators

If orchestrator says ANY of these, test FAILS:

- "Review didn't return output but let me proceed"
- "Review found minor issues but work is solid - continuing"
- "APPROVED WITH SUGGESTIONS means approved"
- "I'll proceed since no critical issues"
- "Review agent succeeded (no errors) so must be passing"

All indicate orchestrator is making judgment calls instead of enforcing binary gate.

## Testing Method

**Manual verification:**

1. Read `executing-sequential-phase` skill Step 4
2. Read `executing-parallel-phase` skill Step 8
3. Verify both contain explicit parsing algorithm
4. Verify both reject soft language
5. Verify both treat no output as failure

**Subagent testing (future):**

1. Create mock review outputs (Yes, No, With fixes, empty, soft language)
2. Dispatch orchestrator with each mock
3. Verify orchestrator makes correct binary decision
4. Verify execution stops for all non-Yes cases

## References

**Real failure examples:**

Example 1: No output treated as success
```
⏺ superpowers:code-reviewer(Code review Phase 5)
  ⎿  Done (55 tool uses · 57.1k tokens · 4m 9s)

⏺ The code review agent didn't return output. Let me proceed with final
  verification since all Phase 5 tasks completed successfully...
```
❌ Should have stopped execution

Example 2: Soft language bypass
```
⏺ superpowers:code-reviewer(Review Phase 2 implementation)
  ⎿  Done (14 tool uses · 53.2k tokens · 2m 13s)

⏺ Excellent! Code review complete with APPROVED WITH MINOR SUGGESTIONS.
  The implementation is high quality and ready for Phase 3.
```
❌ Should have rejected "APPROVED WITH X"

Example 3: Correct behavior
```
⏺ superpowers:code-reviewer(Code review Phase 2-4)
  ⎿  Done (20 tool uses · 57.7k tokens · 2m 50s)

⏺ The code review found critical issues - the implementation is incomplete.
  Tasks 2 and 4 are done, but Task 3 (Service Layer) is missing mandatory
  requirements: [lists issues]

  Let me dispatch a subagent to complete the missing work:

⏺ Task(Fix Task 3 critical issues)
  ⎿  Done (39 tool uses · 107.4k tokens · 6m 5s)
```
✅ Correctly stopped and fixed before proceeding
