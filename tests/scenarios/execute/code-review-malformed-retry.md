---
id: code-review-malformed-retry
type: integration
severity: critical
duration: 3m
tags: [code-review, error-handling, retry, verdict-parsing]
---

# Test Scenario: Code Review Malformed Output - Automatic Retry

## Context

Testing that code review **automatically retries once** when output is malformed or missing the verdict field, then fails if retry also produces malformed output.

**Setup:**
- Feature with at least one completed phase
- Code review agent dispatched using `requesting-code-review` skill
- Review returns malformed output (missing "Ready to merge?" field)

**Why critical:**
- Network glitches or model issues can cause one-off malformed responses
- Automatic retry prevents unnecessary workflow halts for transient issues
- Second failure indicates real problem, not transient glitch
- Prevents orchestrator from hallucinating issues or proceeding blindly

## Expected Behavior

### Success Case: First Attempt Malformed, Retry Succeeds

**First review attempt returns:**
```
The code looks good overall. Some minor tweaks needed but nothing blocking.
```

**Orchestrator detects:**
- ❌ Search for "Ready to merge?" field - NOT FOUND
- ⚠️ Malformed output detected

**Orchestrator action:**
- ⚠️ Warn: "Code review output missing 'Ready to merge?' field - retrying once"
- 🔄 Dispatch `requesting-code-review` skill again with same parameters
- ⏳ Wait for retry result

**Retry returns:**
```
### Assessment

**Ready to merge? Yes**

**Reasoning:** All acceptance criteria met, tests passing, architecture follows constitution patterns.
```

**Orchestrator action:**
- ✅ Parse "Ready to merge? Yes" from retry
- ✅ Announce: "Code review APPROVED (retry succeeded) - proceeding to Phase N+1"
- ✅ Continue to next phase

### Failure Case: Both Attempts Malformed

**First review attempt returns:**
```
The implementation is solid. No blocking issues found.
```

**Orchestrator detects:**
- ❌ Search for "Ready to merge?" field - NOT FOUND
- ⚠️ Malformed output detected

**Orchestrator action:**
- ⚠️ Warn: "Code review output missing 'Ready to merge?' field - retrying once"
- 🔄 Dispatch `requesting-code-review` skill again

**Retry also returns malformed:**
```
Great work! The code quality is high and meets all standards.
```

**Orchestrator detects:**
- ❌ Search for "Ready to merge?" field - NOT FOUND (second time)
- ❌ Retry also failed

**Orchestrator action:**
- ❌ STOP execution immediately
- ❌ Report: "Code review failed twice with malformed output"
- ❌ Display both outputs for debugging
- ❌ Suggest: "Review agent may not be following template - check code-reviewer skill"
- ❌ DO NOT proceed to next phase
- ❌ DO NOT hallucinate issues or dispatch fix subagents

### Anti-Pattern: Hallucinating Issues from Malformed Output

**Review returns (malformed):**
```
(64.7k tokens of analysis but no "Ready to merge?" field)
```

**WRONG orchestrator behavior:**
```
⏺ Review verdict: NOT FOUND in standard format

⏺ The review provided comprehensive analysis but didn't include the explicit
  "Ready to merge? Yes/No/With fixes" field. However, it clearly identified
  a CRITICAL issue (blocking test failure) that must be fixed.

⏺ Let me dispatch a fix subagent to resolve the test issue:

⏺ Task(Fix test file after schema change)
  ⎿  Done (10 tool uses · 43.1k tokens · 1m 10s)
```

**Why WRONG:**
- ❌ No retry attempted
- ❌ Hallucinated "CRITICAL issue" from unstructured text
- ❌ Dispatched fix subagent based on hallucination
- ❌ Wasted time and tokens on imaginary problem
- ❌ May have broken working code

**CORRECT behavior:**
```
⏺ Review verdict: NOT FOUND in standard format

⏺ Code review output missing 'Ready to merge?' field. This may be a transient
  issue. Retrying once...

⏺ requesting-code-review (retry attempt)
  ⎿  Done

⏺ Retry succeeded! Code review APPROVED - proceeding to Phase N+1
```

OR if retry also fails:

```
⏺ Retry also produced malformed output. Both attempts failed to include verdict.

⏺ First attempt output (excerpt):
  "The review provided comprehensive analysis..."

⏺ Retry attempt output (excerpt):
  "The implementation looks solid..."

⏺ ❌ STOPPING execution - cannot determine review verdict
⏺ Please review the code-reviewer agent output and re-run manually
```

## Parsing Algorithm with Retry

**Orchestrator must follow this algorithm:**

```python
def parse_review_with_retry(output: str, is_retry: bool = False) -> Decision:
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

    # Missing field - retry once
    if not is_retry:
        return RETRY("Missing 'Ready to merge?' field - retrying")
    else:
        return REJECTED("Both attempts produced malformed output")

# Main review flow
attempt_1 = parse_review_with_retry(review_output_1, is_retry=False)

if attempt_1 == RETRY:
    # Dispatch code-reviewer again
    review_output_2 = dispatch_code_review()
    attempt_2 = parse_review_with_retry(review_output_2, is_retry=True)
    return attempt_2
else:
    return attempt_1
```

## Success Criteria

### Retry Logic
- [ ] Malformed output on first attempt → orchestrator retries once
- [ ] Retry succeeds with "Yes" → orchestrator proceeds
- [ ] Retry also malformed → orchestrator stops and fails
- [ ] No retry on second attempt (max 1 retry)

### Error Reporting
- [ ] First failure: Warns about malformed output and retry attempt
- [ ] Retry success: Announces approval with "(retry succeeded)"
- [ ] Retry failure: Reports both outputs for debugging
- [ ] Clear guidance: "Check code-reviewer skill" not "proceed anyway"

### Anti-Pattern Detection
- [ ] Does NOT hallucinate issues from unstructured review text
- [ ] Does NOT dispatch fix subagents without valid rejection
- [ ] Does NOT proceed without "Ready to merge? Yes"
- [ ] Does NOT assume silence/confusion means approval

### Documentation
- [ ] `executing-sequential-phase` documents retry logic
- [ ] `executing-parallel-phase` documents retry logic
- [ ] Both skills explain when retry happens vs immediate failure
- [ ] Both skills show max retry count (1)

## Implementation Verification

**Check:** `skills/executing-sequential-phase/SKILL.md` at "Step 4: Code Review"

Should contain:
```markdown
1. Use `requesting-code-review` skill to call code-reviewer
2. Parse the output:
   - "Ready to merge? Yes" → Phase complete, proceed
   - "Ready to merge? No" → STOP, dispatch fix subagent
   - "Ready to merge? With fixes" → STOP, dispatch fix subagent
   - Missing verdict → Retry review ONCE
3. If retry also fails: STOP and report both outputs
4. If retry succeeds: Proceed with approval
5. DO NOT hallucinate issues from malformed text
6. DO NOT proceed without explicit "Yes"
```

**Check:** `skills/executing-parallel-phase/SKILL.md` at "Step 8: Code Review"

Should contain identical retry logic.

## Verification Commands

### Check Sequential Phase Skill Contains Retry Logic

```bash
# Verify retry logic exists in code review step
grep -A 10 "Missing verdict.*Retry review ONCE" /Users/drewritter/projects/spectacular/skills/executing-sequential-phase/SKILL.md

# Verify explicit retry count limit
grep "retry ONCE\|max.*1.*retry\|one.*retry" /Users/drewritter/projects/spectacular/skills/executing-sequential-phase/SKILL.md

# Verify anti-hallucination warning
grep -i "DO NOT hallucinate issues" /Users/drewritter/projects/spectacular/skills/executing-sequential-phase/SKILL.md
```

### Check Parallel Phase Skill Contains Retry Logic

```bash
# Verify retry logic exists in code review step
grep -A 10 "Missing verdict.*Retry review ONCE" /Users/drewritter/projects/spectacular/skills/executing-parallel-phase/SKILL.md

# Verify explicit retry count limit
grep "retry ONCE\|max.*1.*retry\|one.*retry" /Users/drewritter/projects/spectacular/skills/executing-parallel-phase/SKILL.md

# Verify anti-hallucination warning
grep -i "DO NOT hallucinate issues" /Users/drewritter/projects/spectacular/skills/executing-parallel-phase/SKILL.md
```

### Check Execute Command Documents Retry Behavior

```bash
# Verify execute command references retry logic
grep -i "retry.*malformed\|malformed.*retry" /Users/drewritter/projects/spectacular/commands/execute.md
```

## Evidence of PASS

### Minimal Evidence (First Attempt Malformed, Retry Succeeds)

**Orchestrator output shows:**
```
⏺ superpowers:code-reviewer(Review Phase 1 implementation)
  ⎿  Done (15 tool uses · 64.7k tokens · 2m 12s)

⏺ Review verdict: NOT FOUND in standard format

⏺ Code review output missing 'Ready to merge?' field. This may be a transient
  issue. Retrying once...

⏺ superpowers:requesting-code-review (retry attempt)
  ⎿  Done (12 tool uses · 45.3k tokens · 1m 45s)

⏺ Retry succeeded! Code review APPROVED - proceeding to Phase 2
```

**Why this is PASS:**
- ✅ Detected malformed output from first attempt
- ✅ Announced retry with clear reasoning
- ✅ Dispatched code review skill again
- ✅ Parsed verdict from retry successfully
- ✅ Proceeded to next phase after approval

### Complete Evidence (Both Attempts Malformed, Proper Failure)

**Orchestrator output shows:**
```
⏺ superpowers:code-reviewer(Review Phase 1 implementation)
  ⎿  Done (15 tool uses · 64.7k tokens · 2m 12s)

⏺ Review verdict: NOT FOUND in standard format

⏺ Code review output missing 'Ready to merge?' field. Retrying once...

⏺ superpowers:requesting-code-review (retry attempt)
  ⎿  Done (13 tool uses · 52.1k tokens · 1m 58s)

⏺ ❌ Retry also produced malformed output. Both attempts failed to include verdict.

⏺ First attempt output (excerpt):
  "The implementation is solid. No blocking issues found."

⏺ Retry attempt output (excerpt):
  "Great work! The code quality is high and meets all standards."

⏺ ❌ STOPPING execution - cannot determine review verdict
⏺ Please review the code-reviewer agent output and re-run manually
```

**Why this is PASS:**
- ✅ Detected malformed output from first attempt
- ✅ Retried exactly once
- ✅ Detected malformed output from retry
- ✅ Stopped execution immediately
- ✅ Displayed both outputs for debugging
- ✅ Clear error message with actionable guidance
- ✅ Did NOT proceed to next phase
- ✅ Did NOT hallucinate issues

## Evidence of FAIL

### FAIL Pattern 1: No Retry Attempted

**Orchestrator output shows:**
```
⏺ superpowers:code-reviewer(Review Phase 1 implementation)
  ⎿  Done (15 tool uses · 64.7k tokens · 2m 12s)

⏺ Review verdict: NOT FOUND in standard format

⏺ The review provided comprehensive analysis but didn't include the explicit
  "Ready to merge? Yes/No/With fixes" field. However, it clearly identified
  a CRITICAL issue (blocking test failure) that must be fixed.

⏺ Let me dispatch a fix subagent to resolve the test issue:
```

**Why this is FAIL:**
- ❌ No retry attempted despite malformed output
- ❌ Proceeded to interpret unstructured text
- ❌ Hallucinated "CRITICAL issue" without valid verdict
- ❌ Dispatched fix subagent based on hallucination

### FAIL Pattern 2: Proceeds Despite Malformed Output

**Orchestrator output shows:**
```
⏺ superpowers:code-reviewer(Review Phase 1 implementation)
  ⎿  Done (15 tool uses · 64.7k tokens · 2m 12s)

⏺ Review verdict: NOT FOUND in standard format

⏺ The review seems generally positive, so proceeding to Phase 2...
```

**Why this is FAIL:**
- ❌ No retry attempted
- ❌ Assumed positive outcome without valid verdict
- ❌ Proceeded without explicit "Ready to merge? Yes"

### FAIL Pattern 3: Infinite Retry Loop

**Orchestrator output shows:**
```
⏺ superpowers:code-reviewer(Review Phase 1 implementation)
  ⎿  Done (15 tool uses · 64.7k tokens · 2m 12s)

⏺ Review verdict: NOT FOUND - retrying...

⏺ superpowers:requesting-code-review (retry attempt 1)
  ⎿  Done (12 tool uses · 45.3k tokens · 1m 45s)

⏺ Review verdict: NOT FOUND - retrying...

⏺ superpowers:requesting-code-review (retry attempt 2)
  ⎿  Done (11 tool uses · 43.8k tokens · 1m 38s)

⏺ Review verdict: NOT FOUND - retrying...
```

**Why this is FAIL:**
- ❌ Retry count exceeds 1
- ❌ No failure after second malformed output
- ❌ Wastes time and tokens on repeated failures

## Testing Method

**Verification approach:**

1. Read `executing-sequential-phase` skill Step 4
2. Read `executing-parallel-phase` skill Step 8
3. Verify both contain retry logic for malformed output
4. Verify retry count is limited to 1
5. Verify orchestrator stops after second failure
6. Verify NO hallucination of issues from unstructured text

## References

**Real failure example (from user's NOTES.md):**

```
⏺ superpowers:code-reviewer(Review Phase 1 implementation)
  ⎿  Done (15 tool uses · 64.7k tokens · 2m 12s)

⏺ The code review identified a CRITICAL issue that must be fixed before proceeding:
  the test file still validates the old unique constraint behavior.

⏺ Review verdict: NOT FOUND in standard format

⏺ The review provided comprehensive analysis but didn't include the explicit
  "Ready to merge? Yes/No/With fixes" field. However, it clearly identified a
  CRITICAL issue (blocking test failure) that must be fixed.

⏺ Let me dispatch a fix subagent to resolve the test issue:

⏺ Task(Fix test file after schema change)
  ⎿  Done (10 tool uses · 43.1k tokens · 1m 10s)
```

**What went wrong:**
1. ❌ No retry attempted - should have retried code review
2. ❌ Hallucinated "CRITICAL issue" from malformed output
3. ❌ Dispatched fix subagent based on hallucination
4. ❌ Eventually stalled asking about database reset

**Correct behavior would be:**
1. ✅ Detect malformed output
2. ✅ Retry code review once
3. ✅ If retry fails: Report error and STOP (don't hallucinate)
4. ✅ If retry succeeds: Parse verdict and proceed
