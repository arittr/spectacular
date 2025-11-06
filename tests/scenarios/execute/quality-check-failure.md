# Test Scenario: Quality Check Failure

## Context

Testing `/spectacular:execute` quality check integration when tests, linting, or builds fail during task execution.

**Setup:**
- Feature spec with Phase 2 containing 3 parallel tasks
- CLAUDE.md defines quality check commands:
  ```markdown
  ## Development Commands

  ### Quality Checks
  - **test**: `npm test`
  - **lint**: `npm run lint`
  - **build**: `npm run build`
  ```
- Task 2 will have code that fails tests
- Tasks 1 and 3 will pass all quality checks
- Clean git state with git-spice initialized

**Why this matters:**
- Quality checks are mandatory gates before commits
- Failed checks should block branch creation
- Orchestrator must detect and report quality check failures
- User needs clear guidance on what failed and how to fix

## Expected Behavior

### Task Subagent Quality Check Workflow

**Documented in execute.md subagent prompt:**

```markdown
4. Run quality checks (check CLAUDE.md for commands)
   - Dependencies already installed
   - Run tests/lint/build using CLAUDE.md quality check commands

5. Create new stacked branch and commit your work:

   CRITICAL: Stage changes FIRST, then create branch

   a) FIRST: Stage your changes
      - Command: `git add .`

   b) THEN: Create new stacked branch
      - Command: `gs branch create {branch-name} -m "{message}"`
```

**Quality check execution order:**

All checks wrapped in heredoc for safe parsing:

```bash
bash <<'EOF'
# 1. Test check
npm test
if [ $? -ne 0 ]; then
  echo "❌ Tests failed"
  exit 1
fi

# 2. Lint check
npm run lint
if [ $? -ne 0 ]; then
  echo "❌ Lint failed"
  exit 1
fi

# 3. Build check
npm run build
if [ $? -ne 0 ]; then
  echo "❌ Build failed"
  exit 1
fi
EOF
```

**If all pass, proceed to branch creation**

### Test Failure Scenario

**Task 2 execution:**

1. Subagent implements feature in `.worktrees/{runid}-task-2`
2. Runs quality checks:
   ```bash
   npm test
   # Output:
   # FAIL  src/api/endpoints.test.ts
   #   POST /api/users
   #     ✗ should create new user (45 ms)
   #     ✗ should validate email format (12 ms)
   #
   # Tests Failed: 2 failed, 15 passed, 17 total
   # Exit code: 1
   ```

3. Subagent detects test failure (exit code 1)

4. **Subagent reports failure WITHOUT creating branch:**
   ```
   ❌ Task 2 FAILED: Quality checks did not pass

   Failed check: npm test
   Exit code: 1

   Failed tests:
   - POST /api/users › should create new user
   - POST /api/users › should validate email format

   Error details:
   [Full test output]

   Location: .worktrees/{runid}-task-2

   Next steps:
   1. Review test failures above
   2. Fix implementation in .worktrees/{runid}-task-2
   3. Re-run tests manually: cd .worktrees/{runid}-task-2 && npm test
   4. Once passing, create branch manually or let orchestrator retry
   ```

5. **Branch NOT created** (subagent exits before `gs branch create`)

### Orchestrator Detection

**After parallel agents complete:**

```bash
# Collect results
TASK_1_STATUS="success"
TASK_1_BRANCH="{runid}-task-2-1-user-management"

TASK_2_STATUS="failed"
TASK_2_BRANCH=""  # No branch created
TASK_2_ERROR="Quality checks failed: npm test (exit code 1)"

TASK_3_STATUS="success"
TASK_3_BRANCH="{runid}-task-2-3-api-docs"

# Check for failures
if [[ "$TASK_2_STATUS" == "failed" ]]; then
  echo "❌ Phase 2 execution failed"
  echo ""
  echo "Failed task: Task 2"
  echo "Reason: $TASK_2_ERROR"
  echo ""
  echo "Completed tasks:"
  echo "  ✅ Task 1: $TASK_1_BRANCH"
  echo "  ✅ Task 3: $TASK_3_BRANCH"
  echo ""
  echo "To resume:"
  echo "1. Fix quality check failures in .worktrees/{runid}-task-2"
  echo "2. Run quality checks manually to verify"
  echo "3. Create branch manually: gs branch create {branch-name} -m 'message'"
  echo "4. Re-run /spectacular:execute to complete phase"
  exit 1
fi
```

**Critical: Do NOT proceed to stacking if quality checks failed**

### Manual Fix and Resume

**User fixes the tests:**

```bash
cd .worktrees/{runid}-task-2

# Fix the implementation
vim src/api/endpoints.ts

# Verify fix locally
npm test
# ✅ All tests pass

# Create branch manually
git add .
gs branch create {runid}-task-2-2-api-endpoints -m "[Task 2-2] API endpoints"
git switch --detach

cd ../..
```

**Re-run execute:**

```bash
/spectacular:execute
```

**Resume behavior:**
- Detects Task 1 and Task 3 branches already exist
- Detects Task 2 branch now exists (fixed)
- Skips to stacking (Step 6)
- Completes phase successfully

## Success Criteria

### Quality Check Integration
- [ ] Subagent executes all quality checks from CLAUDE.md
- [ ] Checks run in order: test → lint → build
- [ ] First failure stops execution (no subsequent checks run)
- [ ] Quality check output shown to user

### Failure Detection
- [ ] Exit code from quality check command captured
- [ ] Non-zero exit code treated as failure
- [ ] Subagent reports failure with specific check name
- [ ] Subagent does NOT create branch on failure

### Error Reporting
- [ ] Clear indication of which check failed (test/lint/build)
- [ ] Full output from failed command shown
- [ ] Specific test names or lint errors shown
- [ ] Worktree path provided for debugging
- [ ] Actionable next steps included

### Partial Completion Handling
- [ ] Successful tasks create branches normally
- [ ] Failed task leaves no branch
- [ ] Worktree preserved for failed task
- [ ] Orchestrator stops before stacking
- [ ] Clear resume instructions provided

### Resume After Fix
- [ ] User can fix and verify locally
- [ ] User can create branch manually
- [ ] Re-running execute detects all branches present
- [ ] Execution resumes from stacking step
- [ ] Phase completes successfully

## Failure Modes to Test

### Issue 1: Quality Check Bypassed

**Symptom:** Branch created even though tests failed

**Root Cause:** Subagent doesn't check exit codes from quality check commands

**Detection:**
```bash
# If wrong, this branch exists despite test failures:
git branch | grep {runid}-task-2-2
# Should be empty if tests failed
```

### Issue 2: Silent Quality Check Failure

**Symptom:** Quality check fails but subagent doesn't report it clearly

**Root Cause:** Error output not captured or forwarded to orchestrator

**Detection:**
```bash
# Orchestrator should show specific error, not generic "task failed"
# Should see: "npm test failed: POST /api/users › should create new user"
# NOT: "Task 2 failed"
```

### Issue 3: Wrong Check Order

**Symptom:** Build runs even though tests failed

**Root Cause:** Checks run in parallel or wrong order

**Detection:**
```bash
# Test output should show tests ran first, stopped on failure
# Should NOT show "Running build..." if tests failed
```

### Issue 4: Branch Created Despite Failure

**Symptom:** Branch exists but contains failing code

**Root Cause:** `git add` and `gs branch create` run before quality checks

**Detection:**
```bash
git checkout {runid}-task-2-2-api-endpoints
npm test
# Should not exist, or if exists by mistake, tests should fail
```

### Issue 5: Missing Quality Commands

**Symptom:** Error or skip if CLAUDE.md doesn't define quality check commands

**Root Cause:** No fallback or clear error when commands missing

**Expected behavior:**
```bash
# If test command not in CLAUDE.md:
echo "⚠️  Warning: No 'test' command found in CLAUDE.md"
echo "Skipping test check"
# Continue with remaining checks
```

## Quality Check Variants to Test

### Variant A: Test Failure

```bash
npm test
# Exit code: 1
# Error: 2 tests failed
```

### Variant B: Lint Failure

```bash
npm run lint
# Exit code: 1
# Error:
#   src/api/endpoints.ts
#     15:10  error  'userId' is assigned a value but never used  @typescript-eslint/no-unused-vars
#     23:5   error  Missing return type on function              @typescript-eslint/explicit-function-return-type
```

### Variant C: Build Failure

```bash
npm run build
# Exit code: 1
# Error:
#   src/api/endpoints.ts:15:30 - error TS2304: Cannot find name 'UserID'.
#   Found 1 error.
```

### Variant D: Multiple Failures

```bash
npm test
# Fails

npm run lint
# Should NOT run (stopped at first failure)
```

### Variant E: All Pass

```bash
npm test     # Exit code: 0
npm run lint # Exit code: 0
npm run build # Exit code: 0
# Proceed to branch creation
```

## Test Execution

**Setup:**

1. Create test project with failing tests
2. Define quality check commands in CLAUDE.md
3. Create plan with parallel tasks

**Execute:**

```bash
/spectacular:execute

# Task 2 should fail at quality check
# Verify:
# - Error message shows test failure
# - No branch created for task 2
# - Execution stops before stacking
```

**Fix and resume:**

```bash
cd .worktrees/{runid}-task-2
# Fix tests
npm test  # Verify pass
git add .
gs branch create {branch} -m "message"
git switch --detach
cd ../..

/spectacular:execute
# Should resume and complete
```

## Related Scenarios

- **task-failure-recovery.md** - General task failure handling
- **sequential-stacking.md** - Quality checks in sequential phases
- **missing-setup-commands.md** - Handling missing CLAUDE.md commands
