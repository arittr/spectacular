---
id: verification-skill-branch-creation-failures
type: pressure
severity: critical
estimated_duration: 10m
tags: [verification, branch-creation, error-handling]
---

# Pressure Test: Verification Skill Branch Creation Failures

## Context

The phase-task-verification skill is shared by both sequential-phase-task and parallel-phase-task. It must catch branch creation failures and verify HEAD state correctly. If verification silently fails, subagents think work is complete when branches were never created.

**Why critical:** Silent failures break worktree cleanup and cause lost work.

## Expected Behavior

The skill MUST:
1. Detect when `gs branch create` fails (duplicate name, git errors)
2. Verify HEAD matches expected branch in sequential mode
3. Verify HEAD is detached in parallel mode after `git switch --detach`
4. Exit with clear error message on any failure
5. Never report success when branch creation failed

## Verification Commands

```bash
# Check skill exists
test -f skills/phase-task-verification/SKILL.md

# Check for error handling section
grep -n "Error Handling" skills/phase-task-verification/SKILL.md

# Check for HEAD verification logic
grep -n "verify HEAD" skills/phase-task-verification/SKILL.md
grep -n "git rev-parse" skills/phase-task-verification/SKILL.md

# Check for MODE handling
grep -n "MODE: sequential" skills/phase-task-verification/SKILL.md
grep -n "MODE: parallel" skills/phase-task-verification/SKILL.md

# Check for detach in parallel mode
grep -n "git switch --detach" skills/phase-task-verification/SKILL.md
```

## Evidence of PASS

- [ ] Skill file exists at skills/phase-task-verification/SKILL.md
- [ ] Error Handling section present (grep finds it)
- [ ] HEAD verification logic uses `git rev-parse --abbrev-ref HEAD`
- [ ] MODE parameter handling documented
- [ ] Parallel mode includes `git switch --detach` step
- [ ] Self-verification catches branch creation failures
- [ ] Clear error messages for each failure scenario

## Evidence of FAIL

- [ ] Skill missing or incomplete
- [ ] No error handling section
- [ ] No HEAD verification logic
- [ ] Missing MODE parameter handling
- [ ] Parallel mode missing detach step
- [ ] Silent failures allowed (no verification)

## Pressure Scenario

**Setup:** Create a git repo with existing branch name that will conflict

**Test 1: Duplicate branch name**
- RUN_ID: test123
- TASK_ID: 1-1
- TASK_NAME: duplicate-test
- COMMIT_MESSAGE: "[Task 1.1] Test"
- MODE: sequential
- Pre-create branch: test123-task-1-1-duplicate-test
- Expected: Skill detects failure, exits with error
- Failure mode: Skill reports success despite no new branch

**Test 2: HEAD verification failure (sequential)**
- RUN_ID: test456
- TASK_ID: 2-1
- TASK_NAME: wrong-head
- COMMIT_MESSAGE: "[Task 2.1] Test"
- MODE: sequential
- Expected: After branch create, verify HEAD == test456-task-2-1-wrong-head
- Failure mode: Skill doesn't verify, reports success when HEAD is wrong

**Test 3: Detach failure (parallel)**
- RUN_ID: test789
- TASK_ID: 3-1
- TASK_NAME: detach-test
- COMMIT_MESSAGE: "[Task 3.1] Test"
- MODE: parallel
- Expected: After branch create, HEAD is detached
- Failure mode: Skill forgets to detach, breaks worktree cleanup

## Rationale

This skill is FOUNDATION for Phase 2 and 3. If verification is weak:
- Task skills report success when branches don't exist
- Worktree cleanup fails (can't find branches)
- Code review runs on wrong branches
- Work is lost

Must be bulletproof BEFORE task skills depend on it.
