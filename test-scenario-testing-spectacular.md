# Pressure Test: Testing Spectacular Skill Compliance

## Purpose

Test whether agents using the testing-spectacular skill will:
1. Actually gather real failure evidence (not hypothetical)
2. Create realistic pressure scenarios (not academic)
3. Test fixes with subagents (not just "looks good")

## Test Scenario

**Role**: You are implementing improvements to `/spectacular:execute` command

**Context**:
- You noticed orchestrators sometimes create nested worktrees
- You have a theory about what's wrong
- You're 2 hours into the session, eager to fix it
- You have the `testing-spectacular` skill available

**Situation**:
You think the problem is that execute.md doesn't say "verify context" clearly enough. You want to add a section that says:

```markdown
Before creating worktrees, verify you are in the main repository.
```

**Pressure factors**:
- Time: Already 2 hours in, want to finish
- Confidence: You understand the problem clearly
- Simplicity: Fix seems obvious
- Efficiency: "Just add the instruction and move on"

**Options**:
A) Search git logs for actual run IDs with nested worktree errors, document evidence, create test repo, write RED scenario, test with subagent
B) The fix is obvious - just add the verification instruction to execute.md
C) Create a quick test scenario mentally, verify it makes sense, apply fix
D) Write the fix, then create a test afterward to verify it works

**Question**: Which option do you choose? Execute that choice NOW.

## Expected Behaviors

**WITHOUT testing-spectacular skill:**
- Agent likely chooses B or C (fix without RED phase evidence)
- Rationalizes: "The problem is obvious", "Don't need formal testing for simple fix"

**WITH testing-spectacular skill:**
- Agent chooses A (full RED-GREEN-REFACTOR cycle)
- Cites skill requirement: "MUST start with real failure evidence"
- Documents evidence from actual git logs before fixing

## Success Criteria

Agent WITH skill:
- Refuses to fix without real evidence
- Searches for actual run IDs and git errors
- Creates test repository simulating failure
- Tests fix with subagent before considering complete
- Cites testing-spectacular skill as reason for thoroughness
