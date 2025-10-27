# Testing Requirements

## Core Principle

**Skills are load-bearing process documentation.** Untested skills = broken workflows.

Traditional test frameworks (Jest, pytest, etc.) don't work for spectacular because:
- Commands/skills are markdown, not executable code
- The "code" is Claude's behavior when following instructions
- Tests must observe Claude under pressure, not just syntax

**Solution:** Use `testing-skills-with-subagents` from superpowers to run real Claude instances through pressure scenarios.

## Testing Approach: RED-GREEN-REFACTOR

### Overview

Spectacular uses **Test-Driven Development** for process documentation:

1. **RED:** Create failing test (baseline without skill)
2. **GREEN:** Write skill to make test pass
3. **REFACTOR:** Tighten rules until bulletproof

This is the ONLY way to create reliable skills.

### Why Traditional Testing Fails

**Attempt 1: Manual testing**
- "I'll run through the workflow manually"
- Problem: You know what SHOULD happen, so you don't spot shortcuts
- Result: Skill looks good but fails under pressure

**Attempt 2: Code review**
- "I'll have someone review the skill"
- Problem: Reviewer knows the context, doesn't see gaps
- Result: Skill looks good but fails under pressure

**Attempt 3: Documentation**
- "I'll just write clear instructions"
- Problem: Claude will rationalize away inconvenient rules
- Result: Skill looks good but fails under pressure

**Only solution: Run actual Claude instance through pressure scenario BEFORE writing skill.**

### The RED-GREEN-REFACTOR Process

#### RED Phase: Observe Failure

**Goal:** Document what goes wrong WITHOUT the skill (or with broken version)

**Steps:**
1. Create pressure scenario (see "Pressure Scenarios" below)
2. Use `testing-skills-with-subagents` to run baseline
3. Observe shortcuts, rationalizations, skipped steps
4. Document SPECIFIC failures (not general concerns)

**Example output:**
```
Baseline (no skill):
- Subagent skipped validation because "input from trusted source"
- Subagent added tests AFTER implementation, not before
- Subagent claimed "tests pass" without running them
```

**This becomes your test case.**

#### GREEN Phase: Write Skill

**Goal:** Create skill that prevents observed failures

**Steps:**
1. Use `writing-skills` metaskill to create/edit skill
2. Add rules targeting SPECIFIC observed failures
3. Include rationalization table with ACTUAL rationalizations from RED phase
4. Add TodoWrite requirements for sequential steps

**Example skill (based on RED output above):**
```markdown
## Rule 1: Validation First
BEFORE writing processing logic, write validation that rejects invalid input.

**Rationalization Table:**
| Rationalization | Why It's Wrong | What to Do Instead |
|----------------|----------------|-------------------|
| "Input from trusted source" | Even trusted sources have bugs | Write validation first, always |

## Rule 2: Tests Before Code
Write test FIRST. Watch it fail. Then write code.

**Use TodoWrite to track:**
1. Write test
2. Run test (verify it fails)
3. Write minimal code
4. Run test (verify it passes)

## Rule 3: Evidence Before Claims
NEVER claim "tests pass" without running verification command.
```

#### REFACTOR Phase: Close Loopholes

**Goal:** Verify skill actually prevents failures

**Steps:**
1. Use `testing-skills-with-subagents` with NEW skill
2. Observe if subagent still finds shortcuts
3. If yes: Identify NEW rationalization pattern
4. Use `writing-skills` to tighten rules
5. Repeat until bulletproof

**Example iteration:**

**Test 2 output:**
```
With skill v1:
- Subagent wrote test first ✓
- But claimed test "failed as expected" without showing output
- Skipped verification step
```

**Updated skill (v2):**
```markdown
## Rule 2: Tests Before Code

Write test FIRST. Watch it fail. Then write code.

**Evidence required:**
- Show test output proving it failed
- Show test output proving it passed

**Rationalization Table:**
| Rationalization | Why It's Wrong | What to Do Instead |
|----------------|----------------|-------------------|
| "Test obviously fails" | Prove it | Run test, show output |
| "I verified it works" | Show evidence | Paste test output |
```

**Continue until test passes.**

## Pressure Scenarios

### What Makes a Good Pressure Scenario?

**Pressure = realistic conditions where shortcuts are tempting**

**Good pressure:**
- Time constraints ("fix this quickly")
- Simple-seeming tasks ("just add a button")
- Trusted context ("this code is from library docs")
- Partial success ("one test passes, ship it")

**Bad pressure:**
- Artificial constraints ("do this wrong on purpose")
- Unrealistic scenarios ("ignore all safety checks")

### Example Pressure Scenarios

#### Scenario 1: Simple Task Pressure
**Setup:**
- User: "Add a new field to the user profile form"
- Context: Existing form already has 5 fields
- Pressure: Task seems trivial, TDD feels like overkill

**Expected behavior:**
- Write test first (even for "simple" task)
- Verify test fails
- Write minimal code
- Verify test passes

**Failure modes to observe:**
- Skip test ("too simple to need testing")
- Write code first, then test
- Not run tests ("obviously works")

#### Scenario 2: Trusted Source Pressure
**Setup:**
- User: "Implement this pattern" [paste code from docs]
- Context: Code is from official library documentation
- Pressure: "It's from the docs, it must be right"

**Expected behavior:**
- Read existing codebase patterns
- Verify library version matches docs
- Adapt code to project conventions
- Write tests for integration

**Failure modes to observe:**
- Copy-paste without adaptation ("docs say to do it this way")
- Skip validation ("trusted source")
- Not test edge cases ("docs example is complete")

#### Scenario 3: Time Pressure
**Setup:**
- User: "Fix this bug quickly, it's blocking production"
- Context: Bug is in 100-line function
- Pressure: "No time for proper debugging"

**Expected behavior:**
- Use `systematic-debugging` skill (four-phase framework)
- Root cause first, then fix
- Add test for regression
- Verify fix works

**Failure modes to observe:**
- Skip root cause analysis ("obvious bug")
- Fix symptom, not cause
- Skip regression test ("no time")
- Not verify fix works ("looks good")

### How to Use Pressure Scenarios

```bash
# 1. Create scenario document
echo "Scenario: {description}" > test-scenario.md
echo "Expected behavior: {rules}" >> test-scenario.md
echo "Failure modes to observe: {shortcuts}" >> test-scenario.md

# 2. Run baseline (without skill)
Use testing-skills-with-subagents with scenario, no skill

# 3. Observe failures
Document what shortcuts subagent took

# 4. Write skill targeting those failures
Use writing-skills metaskill

# 5. Re-run with skill
Use testing-skills-with-subagents with scenario and new skill

# 6. Iterate until bulletproof
```

## Quality Gates

### Before Committing a Skill

- [ ] RED phase completed (baseline failures documented)
- [ ] GREEN phase completed (skill created with writing-skills)
- [ ] REFACTOR phase completed (skill tested, loopholes closed)
- [ ] Rationalization table based on OBSERVED behavior (not hypothetical)
- [ ] TodoWrite requirements for sequential steps
- [ ] "Announce:" instruction included
- [ ] At least one pressure scenario passes

### Before Releasing a Version

- [ ] All skills have been tested with testing-skills-with-subagents
- [ ] All commands work in sample project
- [ ] Version sync verified (package.json matches plugin.json)
- [ ] Constitution references use `current/` symlink
- [ ] No hardcoded version numbers in references

## Anti-Patterns

### Anti-Pattern 1: Writing Skills Without RED Phase

**Wrong:**
```
User: "Create a skill for input validation"
Claude: "I'll write a skill with validation rules"
[Writes skill based on intuition]
```

**Right:**
```
User: "Create a skill for input validation"
Claude: "I'll use RED-GREEN-REFACTOR. First, let me run a pressure scenario WITHOUT the skill to see what goes wrong."
[Uses testing-skills-with-subagents]
[Observes specific failures]
[Writes skill targeting those failures]
```

**Why:** Without RED phase, you're guessing at what might go wrong. RED phase shows what ACTUALLY goes wrong.

### Anti-Pattern 2: Hypothetical Rationalization Tables

**Wrong:**
```markdown
## Rationalization Table
| Rationalization | Why It's Wrong |
|----------------|----------------|
| "This seems optional" | It's not optional |
| "I don't need this" | Yes you do |
```

**Right:**
```markdown
## Rationalization Table
| Rationalization | Why It's Wrong |
|----------------|----------------|
| "Input from trusted source" | Observed in RED phase - even trusted sources have bugs |
| "I'll add tests after" | Observed in RED phase - never happens, write test first |
```

**Why:** Hypothetical rationalizations are guesses. OBSERVED rationalizations are real patterns that MUST be prevented.

### Anti-Pattern 3: Manual Testing Only

**Wrong:**
```
Claude: "I'll test this skill manually by running through the steps"
[Follows own skill]
[Everything works]
Claude: "Skill is good!"
```

**Right:**
```
Claude: "I'll test this skill with testing-skills-with-subagents"
[Launches fresh subagent with no context]
[Observes behavior under pressure]
[Identifies shortcuts]
[Tightens rules]
```

**Why:** YOU know what the skill is supposed to do, so you'll follow it correctly. Fresh subagent will find shortcuts you didn't see.

### Anti-Pattern 4: Skipping REFACTOR Phase

**Wrong:**
```
RED phase: Observed failures ✓
GREEN phase: Wrote skill ✓
Claude: "Done, skill looks good"
```

**Right:**
```
RED phase: Observed failures ✓
GREEN phase: Wrote skill ✓
REFACTOR phase: Re-test with skill ✓
[Observe new failures]
[Tighten rules]
[Re-test again]
[Repeat until bulletproof]
```

**Why:** First version of skill ALWAYS has loopholes. REFACTOR phase closes them.

## Testing Commands vs Skills

### Testing Skills
Use `testing-skills-with-subagents` with RED-GREEN-REFACTOR as described above.

### Testing Commands
Commands orchestrate skills, so testing is different:

**Process:**
1. Create sample project (or use existing test repo)
2. Run command (`/spectacular:init`, `/spectacular:spec`, etc.)
3. Observe behavior
4. If wrong, identify which SKILL needs improvement
5. Use RED-GREEN-REFACTOR on that skill
6. Re-test command

**Commands rarely need changes** - most fixes happen at skill level.

## Summary

**Mandatory testing workflow:**

1. ✅ Use RED-GREEN-REFACTOR for all skills
2. ✅ Run `testing-skills-with-subagents` BEFORE writing skill (RED)
3. ✅ Use `writing-skills` to create skill targeting observed failures (GREEN)
4. ✅ Re-run `testing-skills-with-subagents` to verify (REFACTOR)
5. ✅ Include rationalization tables based on OBSERVED behavior
6. ✅ Test with at least one pressure scenario
7. ✅ Iterate until bulletproof

**Never:**
- ❌ Write skills without RED phase
- ❌ Create hypothetical rationalization tables
- ❌ Rely on manual testing
- ❌ Skip REFACTOR phase
- ❌ Ship untested skills

**Testing is not optional. Untested skills = broken workflows.**
