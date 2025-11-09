# Spectacular Testing Strategy

## Executive Summary

Spectacular now has a **hybrid testing framework** that combines three complementary approaches to prevent regressions:

1. **Validation tests** - Fast grep-based guards (2-5s each)
2. **Execution tests** - Git mechanics verification (1-2s each)
3. **Pressure tests** - Agent compliance under temptation (5-10m each)

**Total coverage:** 6 validation scenarios + 2 execution tests + 1 pressure test = comprehensive protection against regressions without hour-long manual e2e testing.

## The Problem

**Before this framework:**
- Manual e2e testing took ~1 hour per scenario
- Regressions discovered in production (user reports)
- No way to verify agent compliance under pressure
- Brittle grep tests that failed on wording changes

**Example production bug:**
- Phase 2 subagent implemented Phases 3-4 work (scope creep)
- Orchestrator asked user instead of autonomous fixes
- No test caught this before it hit production

## The Solution: Hybrid Testing

### Three Complementary Layers

```
┌─────────────────────────────────────────────────────┐
│ 1. VALIDATION TESTS (Fast Guards)                  │
│    - Grep for required patterns                    │
│    - Catch deleted sections                        │
│    - 6 scenarios, ~30 seconds total                │
└─────────────────────────────────────────────────────┘
                      ↓
┌─────────────────────────────────────────────────────┐
│ 2. EXECUTION TESTS (Git Mechanics)                 │
│    - Actual git operations                         │
│    - Verify branch stacking                        │
│    - 2 tests, ~3 seconds total                     │
└─────────────────────────────────────────────────────┘
                      ↓
┌─────────────────────────────────────────────────────┐
│ 3. PRESSURE TESTS (Agent Compliance)               │
│    - RED-GREEN-REFACTOR methodology                │
│    - Test under realistic temptation               │
│    - 1 test, ~8 minutes                            │
└─────────────────────────────────────────────────────┘
```

### Why All Three?

**Validation tests alone:**
- ❌ Miss git mechanics bugs (wrong branch names, broken stacking)
- ❌ Miss agent behavior bugs (ignores phase boundaries)
- ✅ Fast feedback on documentation structure

**Execution tests alone:**
- ❌ Miss documentation gaps (no PHASE CONTEXT section)
- ❌ Miss agent compliance (follows mechanics but ignores scope)
- ✅ Fast feedback on git operations

**Pressure tests alone:**
- ❌ Too slow for every commit (8 minutes each)
- ❌ Expensive ($0.50-$1.50 per test)
- ✅ Definitive proof of agent compliance

**All three together:**
- ✅ Fast feedback (validation + execution in <1 minute)
- ✅ Confidence in mechanics (execution tests prove git works)
- ✅ Proof of compliance (pressure tests prove skills work)
- ✅ No hour-long manual testing needed

## Test Coverage

### Execute Command (6 Critical Scenarios)

**Validation Tests:**
1. `phase-scope-boundary-enforcement.md` - Verify PHASE CONTEXT sections exist ✅
2. `code-review-rejection-loop.md` - Verify autonomous fix loop patterns ✅
3. `spec-injection-subagents.md` - Verify spec reading steps ✅
4. `parallel-stacking-4-tasks.md` - Verify parallel execution patterns ✅
5. `sequential-stacking.md` - Verify sequential execution patterns ✅
6. `mixed-sequential-parallel-phases.md` - Verify phase transition patterns ✅

**Execution Tests:**
1. `sequential-stacking.sh` - 3 tasks, natural stacking, worktree cleanup (14 assertions) ✅
2. `parallel-stacking-4-tasks.sh` - 4 tasks, isolated worktrees, linear stacking (16 assertions) ✅

**Pressure Tests:**
1. `phase-boundaries.md` - Scope creep resistance under 5 pressures (RED-GREEN-REFACTOR) ✅

### Test Results

**Current status:**
- Validation: 6/6 passing (100%)
- Execution: 2/2 passing (100%)
- Pressure: Ready to run (requires Claude Code dispatch)

**Historical:**
- 2025-11-08: Fixed phase scope creep bug, added enforcement test
- Previous: 16/20 validation tests passing (80%)
- After consolidation: 6/6 critical tests passing (100%)

## Running Tests

### Quick Commands

```bash
# Run all test types for execute
./tests/run-tests.sh execute

# Run only fast tests (validation + execution)
./tests/run-tests.sh execute --type=validation
./tests/run-tests.sh execute --type=execution

# Run only pressure tests (slow, requires subagents)
./tests/run-tests.sh execute --type=pressure
```

### Via Claude Code

```
# Fast feedback loop (< 1 minute)
"Run validation and execution tests for execute command"

# Full compliance check (~ 8 minutes)
"Run pressure test for phase boundary enforcement"

# Before release (~ 15 minutes)
"Run the complete test suite for execute command"
```

### Expected Times

| Test Type | Count | Time Each | Total Time |
|-----------|-------|-----------|------------|
| Validation | 6 | 3-5s | ~30s |
| Execution | 2 | 1-2s | ~3s |
| Pressure | 1 | 8m | ~8m |
| **Total** | **9** | - | **~9 minutes** |

**Compare to manual:** 1 hour per scenario × 6 scenarios = 6 hours → **40x faster**

## Test Architecture

### Directory Structure

```
tests/
├── run-tests.sh                 # Unified test runner
├── aggregate-results.sh         # Results aggregation
├── README.md                    # Testing guide
├── TESTING-STRATEGY.md          # This document
│
├── scenarios/                   # Validation tests (grep-based)
│   └── execute/
│       ├── README.md            # Explains 6 critical scenarios
│       ├── phase-scope-boundary-enforcement.md
│       ├── code-review-rejection-loop.md
│       ├── spec-injection-subagents.md
│       ├── parallel-stacking-4-tasks.md
│       ├── sequential-stacking.md
│       └── mixed-sequential-parallel-phases.md
│
├── execution/                   # Execution tests (git mechanics)
│   ├── README.md                # Execution testing guide
│   ├── lib/
│   │   └── test-harness.sh     # Reusable test utilities
│   └── execute/
│       ├── sequential-stacking.sh
│       └── parallel-stacking-4-tasks.sh
│
├── pressure/                    # Pressure tests (agent compliance)
│   ├── README.md                # RED-GREEN-REFACTOR guide
│   └── execute/
│       └── phase-boundaries.md  # Scope creep resistance test
│
└── results/                     # Test results (timestamped)
    ├── latest/                  # Symlink to most recent
    └── {timestamp}/
        ├── summary.md           # Pass/fail summary (committed)
        ├── scenarios/*.log      # Validation logs (gitignored)
        ├── execution/*.log      # Execution logs (gitignored)
        └── pressure/*.log       # Pressure logs (gitignored)
```

### Test Harness Library

**Location:** `tests/execution/lib/test-harness.sh`

**Provides:**
- `setup_test_repo(name)` - Creates isolated temp repo
- `cleanup_test_repo()` - Removes temp repo
- `assert_branch_exists(name)` - Verifies branch created
- `assert_stack_order(b1, b2, b3)` - Verifies linear stacking
- `assert_worktree_count(n)` - Verifies cleanup
- `create_mock_spec/plan()` - Generates test fixtures
- `report_test_results(name)` - Shows pass/fail summary

**Example usage:**
```bash
source tests/execution/lib/test-harness.sh

setup_test_repo "my-test"
create_mock_spec "abc123" "feature-name"

# Simulate git operations
# ...

assert_branch_exists "abc123-task-1-1-schema"
assert_worktree_count 0

report_test_results "my-test"
cleanup_test_repo
```

## Development Workflow

### Before Committing Changes

```bash
# 1. Fast feedback (< 1 minute)
./tests/run-tests.sh execute --type=validation
./tests/run-tests.sh execute --type=execution

# 2. If tests pass, commit changes
git add .
git commit -m "feat: your change"

# 3. Optionally run pressure tests before push (~ 8 minutes)
# Via Claude Code: "Run pressure test for phase boundary enforcement"
```

### When Fixing Bugs

**RED-GREEN-REFACTOR cycle:**

1. **RED Phase:**
   - Bug reported: Phase 2 implements Phase 3 work
   - Create validation test: Grep for PHASE CONTEXT section → FAIL (missing)
   - Create execution test: Verify scope boundary → FAIL (not enforced)
   - Create pressure test: Test under temptation → FAIL (agent violates)

2. **GREEN Phase:**
   - Fix implementation: Add PHASE CONTEXT extraction
   - Run validation test → PASS (section exists)
   - Run execution test → PASS (boundaries enforced)
   - Run pressure test → PASS (agent complies)

3. **REFACTOR Phase:**
   - Improve clarity of PHASE CONTEXT
   - Add more rationalization counters
   - Re-run all tests → All PASS

### When Adding Features

1. Write validation test FIRST (TDD)
2. Write execution test (if git mechanics involved)
3. Write pressure test (if agent behavior involved)
4. Implement feature
5. Run tests until all pass
6. Commit with test evidence

## Maintenance

### Updating Tests

**When to update validation tests:**
- Skill/command structure changes intentionally
- New mandatory sections added
- Rationalization table expanded

**When to update execution tests:**
- Branch naming convention changes
- Stacking strategy changes
- Worktree management changes

**When to update pressure tests:**
- New loopholes discovered
- New types of pressure identified
- New rationalization patterns observed

**When NOT to update tests:**
- Rewording for clarity
- Adding examples
- Improving documentation

### Adding New Tests

**Validation test (grep-based):**
```bash
# 1. Create scenario file
touch tests/scenarios/execute/new-scenario.md

# 2. Add frontmatter
---
id: new-scenario
type: integration
severity: major
---

# 3. Add verification commands
## Verification Commands
```bash
grep -n "required pattern" skills/skill-name/SKILL.md
```

# 4. Run test
# Via Claude: "Run validation tests for execute command"
```

**Execution test (git mechanics):**
```bash
# 1. Create test script
touch tests/execution/execute/new-test.sh
chmod +x tests/execution/execute/new-test.sh

# 2. Use template from tests/execution/README.md

# 3. Run test
./tests/execution/execute/new-test.sh
```

**Pressure test (agent compliance):**
```markdown
# 1. Create scenario
tests/pressure/execute/new-pressure.md

# 2. Use template from tests/pressure/README.md

# 3. Document pressures applied

# 4. Define RED-GREEN-REFACTOR phases

# 5. Run via Claude Code
"Run pressure test for new-pressure"
```

## Performance Optimization

### Current Performance

| Operation | Time | Cost |
|-----------|------|------|
| Single validation test | 3-5s | Free (grep) |
| Single execution test | 1-2s | Free (git) |
| Single pressure test | 8m | ~$1 (API) |
| All validation (6 tests) | 30s | Free |
| All execution (2 tests) | 3s | Free |
| All pressure (1 test) | 8m | ~$1 |
| **Full suite** | **~9m** | **~$1** |

### Optimization Strategies

**Validation tests:**
- ✅ Already fast (grep-based)
- Could parallelize subagent dispatch (10 at once)

**Execution tests:**
- ✅ Already fast (git operations)
- Could parallelize test scripts (run 2+ simultaneously)

**Pressure tests:**
- ⚠️ Inherently slow (subagent dispatch required)
- Run only before releases or when agent behavior changes
- Cache results for unchanged skills

## Future Improvements

### Short Term
- [ ] Add 4 more execution tests (cover all 6 critical scenarios)
- [ ] Add 2 more pressure tests (code review, spec injection)
- [ ] Parallel execution of tests (reduce total time)

### Medium Term
- [ ] Test fixtures for common scenarios
- [ ] More assertion helpers (commit messages, file contents)
- [ ] Coverage tracking (which patterns are tested)

### Long Term
- [ ] Automated pressure test execution (if Claude Code API available)
- [ ] Continuous integration (run on every commit)
- [ ] Performance benchmarks and trends
- [ ] Historical loophole tracking

## References

- **Validation tests:** `tests/scenarios/execute/README.md`
- **Execution tests:** `tests/execution/README.md`
- **Pressure tests:** `tests/pressure/README.md`
- **Test harness:** `tests/execution/lib/test-harness.sh`
- **Main testing guide:** `tests/README.md`

## Summary

**The hybrid testing framework provides:**

✅ **Fast feedback** - Validation + execution tests run in < 1 minute
✅ **Confidence in mechanics** - Execution tests prove git operations work
✅ **Proof of compliance** - Pressure tests prove agents follow rules
✅ **No manual e2e testing** - 40x faster than hour-long manual tests
✅ **Comprehensive coverage** - 3 complementary approaches catch different bug types

**Before pushing changes:**
1. Run validation + execution tests (< 1 minute)
2. Optionally run pressure tests (~ 8 minutes)
3. Commit with confidence - no hour-long manual testing needed
