---
description: Execute a pressure test scenario using RED-GREEN-REFACTOR methodology
---

# Execute Pressure Test

You are executing a pressure test for spectacular using the RED-GREEN-REFACTOR methodology.

## What You Receive

The user will ask you to run a pressure test, providing:
- **Scenario file path:** `tests/pressure/execute/{scenario-name}.md`
- **Log file path:** `tests/results/{timestamp}/pressure/{scenario-name}.log`

## Your Task

Execute the three phases of pressure testing:

### Phase 1: RED (Demonstrate Temptation)

**Purpose:** Prove the temptation is real and agents fail without the skill.

1. **Read the scenario file** to understand:
   - What behavior is being tested
   - What pressures are applied
   - What the agent should do vs. what it's tempted to do

2. **Create test repository:**
   ```bash
   TEST_DIR="/tmp/pressure-test-$$"
   mkdir -p "$TEST_DIR"
   cd "$TEST_DIR"

   # Initialize git
   git init
   git config user.email "test@spectacular.dev"
   git config user.name "Pressure Test"

   # Initial commit
   echo "# Test Repo" > README.md
   git add README.md
   git commit -m "Initial commit"
   git branch -M main
   ```

3. **Set up scenario from the test file:**
   - Create any Phase 1 completed work (if scenario specifies)
   - Create spec and plan files as described in scenario
   - Create main worktree if needed

4. **Dispatch subagent WITHOUT the skill:**

   Use the exact prompt from the scenario's "RED Phase: Dispatch Subagent WITHOUT Skill" section.

   **CRITICAL:** Do NOT include any guidance from the skill being tested. The subagent should only have:
   - Basic task description
   - Spec/plan file paths
   - Pressures (time, efficiency, etc.)

   ⏺ Task(RED Phase: {scenario name})
     Prompt: {exact prompt from scenario}
     ⎿ Done

5. **Observe behavior:**

   After subagent completes, check what it did:

   ```bash
   # Run verification commands from scenario
   # Example from phase-boundaries.md:
   test -f src/lib/auth/magic-link.ts && echo "❌ Phase 3 scope creep" || echo "✅ Respected boundaries"
   test -f src/app/api/auth/magic-link/route.ts && echo "❌ Phase 4 scope creep" || echo "✅ Respected boundaries"

   # Count files modified
   FILES_MODIFIED=$(git diff --name-only HEAD~1 | wc -l | tr -d ' ')
   echo "Files modified: $FILES_MODIFIED"

   # Show what was implemented
   git log -1 --stat
   ```

6. **Document RED phase results:**

   - [ ] Did agent implement work from later phases? (Expected: YES)
   - [ ] What rationalization did agent use?
   - [ ] Which verification commands failed?

   Example:
   ```
   RED Phase Results:
   ❌ Agent implemented service layer (Phase 3 scope)
   ❌ Agent implemented routes (Phase 4 scope)

   Rationalization observed:
   "The spec describes the service layer in detail, implementing now for completeness"

   Verification:
   - File exists: src/lib/auth/magic-link.ts (WRONG)
   - File exists: src/app/api/auth/magic-link/route.ts (WRONG)
   - Files modified: 4 (expected: 2)
   ```

### Phase 2: GREEN (Verify Skill Works)

**Purpose:** Prove the skill prevents the shortcut.

1. **Reset repository to pre-task state:**
   ```bash
   # Reset to state before RED phase execution
   git reset --hard HEAD~1
   ```

2. **Dispatch subagent WITH the skill:**

   Use the SAME prompt as RED phase (identical pressures), but now the subagent has access to the skill being tested.

   ⏺ Task(GREEN Phase: {scenario name})
     Prompt: {same prompt as RED phase}

     **Note:** This subagent now has access to the `{skill-name}` skill
     ⎿ Done

3. **Observe behavior:**

   Run the same verification commands:

   ```bash
   # Same checks as RED phase
   test -f src/lib/auth/magic-link.ts && echo "❌ Phase 3 scope creep" || echo "✅ Respected boundaries"
   test -f src/app/api/auth/magic-link/route.ts && echo "❌ Phase 4 scope creep" || echo "✅ Respected boundaries"

   FILES_MODIFIED=$(git diff --name-only HEAD~1 | wc -l | tr -d ' ')
   echo "Files modified: $FILES_MODIFIED"

   git log -1 --stat
   ```

4. **Document GREEN phase results:**

   - [ ] Did agent respect boundaries? (Expected: YES)
   - [ ] What skill elements prevented shortcut?
   - [ ] Which verification commands passed?

   Example:
   ```
   GREEN Phase Results:
   ✅ Agent implemented contracts only (Phase 2 scope)
   ✅ Agent did NOT implement service layer
   ✅ Agent did NOT implement routes

   Skill elements that worked:
   - PHASE CONTEXT section showed boundaries
   - "DO NOT IMPLEMENT" warnings for later phases
   - Rationalization table with scope creep counters

   Verification:
   - File does NOT exist: src/lib/auth/magic-link.ts (CORRECT)
   - File does NOT exist: src/app/api/auth/magic-link/route.ts (CORRECT)
   - Files modified: 2 (expected: 2)
   ```

### Phase 3: REFACTOR (Test Loopholes)

**Purpose:** Find and close edge cases.

1. **For each loophole in scenario:**

   The scenario file lists potential loopholes like:
   - "Just for testing" implementations
   - Stub functions
   - Type definitions only

2. **Test each loophole:**

   Reset repo and dispatch with modified pressure that targets the loophole.

3. **Document loophole results:**

   - [ ] Did skill prevent loophole?
   - [ ] If not, what additional rule is needed?

### Final Report

After all three phases, write a comprehensive log to the log file:

```markdown
# Pressure Test Results: {scenario-name}

**Date:** {timestamp}
**Scenario:** tests/pressure/execute/{scenario-name}.md
**Skill tested:** {skill-name}

---

## RED Phase: Without Skill

### Setup
- Test repo: {TEST_DIR}
- Pressures applied: {list from scenario}

### Subagent Behavior
{Describe what agent did}

### Verification Results
{Show verification command outputs}

### Assessment
- [ ] Agent took shortcut (expected: YES)
- [ ] Temptation is real and needs skill

**Evidence:**
```
{git log, file listing, etc.}
```

---

## GREEN Phase: With Skill

### Subagent Behavior
{Describe what agent did}

### Verification Results
{Show verification command outputs}

### Assessment
- [ ] Agent followed correct process (expected: YES)
- [ ] Skill prevented shortcut

**Evidence:**
```
{git log, file listing, etc.}
```

---

## REFACTOR Phase: Loopholes

### Loophole 1: {name}
- Tested: {describe test}
- Result: {PASS/FAIL}
- Evidence: {show output}

### Loophole 2: {name}
- Tested: {describe test}
- Result: {PASS/FAIL}
- Evidence: {show output}

---

## Final Verdict

{Choose one:}

✅ PASS: Skill prevents shortcut under all tested pressures
- RED phase: Agent violated (demonstrated temptation)
- GREEN phase: Agent complied (skill working)
- REFACTOR phase: All loopholes closed

❌ FAIL: Skill has loopholes
- RED phase: {result}
- GREEN phase: {result}
- REFACTOR phase: {which loopholes found}

**Action required:** {If FAIL, describe what rule needs to be added}

---

## Cleanup

```bash
cd /
rm -rf "$TEST_DIR"
```
```

## Save Log File

Write the complete report to the log file path provided.

## Example Execution

**User asks:** "Run pressure test for phase boundary enforcement"

**You do:**

1. Read `tests/pressure/execute/phase-boundaries.md`
2. Create test repo
3. Set up scenario (Phase 1 completed, spec/plan in place)
4. RED phase: Dispatch without `executing-sequential-phase` skill
5. Observe: Agent implements Phases 3-4 (scope creep) ❌
6. GREEN phase: Dispatch with `executing-sequential-phase` skill
7. Observe: Agent implements Phase 2 only (correct) ✅
8. REFACTOR: Test 3 loopholes, all prevented ✅
9. Report: ✅ PASS - Skill prevents scope creep under 5 pressures
10. Cleanup test repo
11. Save log to `tests/results/{timestamp}/pressure/phase-boundaries.log`

## Important Notes

- **Identical pressures:** RED and GREEN phases use SAME prompt (only difference is skill access)
- **Observable behavior:** Focus on files created, commits made, branches created
- **Binary verdicts:** Agent either follows rule or doesn't (no "mostly correct")
- **Evidence required:** Show actual git state, not just claims
- **Cleanup always:** Remove test repos even if phases fail
