# Test Results Summary

**Run:** 2025-11-07T143951
**Date:** Fri Nov  7 15:16:27 PST 2025
**Results:** 16/19 passed (84.2%)

## Overview

- ✅ **Passed:** 16 scenarios
- ❌ **Failed:** 3 scenarios
- 📊 **Total:** 19 scenarios

## Detailed Results

### Passed Scenarios

- ✅ bash-pattern-consistency
- ✅ cleanup-tmp-branches
- ✅ code-review-binary-enforcement
- ✅ code-review-malformed-retry
- ✅ code-review-optimize-mode
- ✅ code-review-rejection-loop
- ✅ large-parallel-phase
- ✅ missing-setup-commands
- ✅ orchestrator-location-discipline
- ✅ parallel-stacking-2-tasks
- ✅ parallel-stacking-3-tasks
- ✅ parallel-stacking-4-tasks
- ✅ sequential-stacking
- ✅ single-task-parallel-phase
- ✅ spec-injection-subagents
- ✅ worktree-creation

### Failed Scenarios

- ❌ mixed-sequential-parallel-phases
- ❌ quality-check-failure
- ❌ task-failure-recovery

## Next Steps

3 scenario(s) failed. Review individual logs for details:

- `tests/results/2025-11-07T143951/scenarios/mixed-sequential-parallel-phases.log`
- `tests/results/2025-11-07T143951/scenarios/quality-check-failure.log`
- `tests/results/2025-11-07T143951/scenarios/task-failure-recovery.log`

**Action required:**
1. Review failure evidence in scenario logs
2. Fix implementation to meet requirements
3. Re-run failed scenarios: `./tests/run-tests.sh <command>`
4. Verify all tests pass before committing
