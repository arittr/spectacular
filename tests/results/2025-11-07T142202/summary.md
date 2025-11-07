# Test Results Summary

**Run:** 2025-11-07T142202
**Date:** Fri Nov  7 14:28:13 PST 2025
**Results:** 17/19 passed (89.5%)

## Overview

- ✅ **Passed:** 17 scenarios
- ❌ **Failed:** 2 scenarios
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
- ✅ mixed-sequential-parallel-phases
- ✅ orchestrator-location-discipline
- ✅ parallel-stacking-2-tasks
- ✅ parallel-stacking-3-tasks
- ✅ quality-check-failure
- ✅ sequential-stacking
- ✅ single-task-parallel-phase
- ✅ spec-injection-subagents
- ✅ worktree-creation

### Failed Scenarios

- ❌ parallel-stacking-4-tasks
- ❌ task-failure-recovery

## Next Steps

2 scenario(s) failed. Review individual logs for details:

- `tests/results/2025-11-07T142202/scenarios/parallel-stacking-4-tasks.log`
- `tests/results/2025-11-07T142202/scenarios/task-failure-recovery.log`

**Action required:**
1. Review failure evidence in scenario logs
2. Fix implementation to meet requirements
3. Re-run failed scenarios: `./tests/run-tests.sh <command>`
4. Verify all tests pass before committing
