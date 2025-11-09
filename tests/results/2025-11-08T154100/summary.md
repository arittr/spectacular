# Test Results Summary

**Run:** 2025-11-08T154100
**Date:** Sat Nov  8 15:46:34 PST 2025
**Results:** 16/20 passed (80.0%)

## Overview

- ✅ **Passed:** 16 scenarios
- ❌ **Failed:** 4 scenarios
- 📊 **Total:** 20 scenarios

## Detailed Results

### Passed Scenarios

- ✅ code-review-binary-enforcement
- ✅ code-review-malformed-retry
- ✅ code-review-optimize-mode
- ✅ code-review-rejection-loop
- ✅ large-parallel-phase
- ✅ missing-setup-commands
- ✅ mixed-sequential-parallel-phases
- ✅ orchestrator-location-discipline
- ✅ parallel-stacking-4-tasks
- ✅ phase-scope-boundary-enforcement
- ✅ quality-check-failure
- ✅ sequential-stacking
- ✅ single-task-parallel-phase
- ✅ spec-injection-subagents
- ✅ task-failure-recovery
- ✅ worktree-creation

### Failed Scenarios

- ❌ bash-pattern-consistency
- ❌ cleanup-tmp-branches (ambiguous)
- ❌ parallel-stacking-2-tasks
- ❌ parallel-stacking-3-tasks (ambiguous)

## Next Steps

4 scenario(s) failed. Review individual logs for details:

- `tests/results/2025-11-08T154100/scenarios/bash-pattern-consistency.log`
- `tests/results/2025-11-08T154100/scenarios/cleanup-tmp-branches (ambiguous).log`
- `tests/results/2025-11-08T154100/scenarios/parallel-stacking-2-tasks.log`
- `tests/results/2025-11-08T154100/scenarios/parallel-stacking-3-tasks (ambiguous).log`

**Action required:**
1. Review failure evidence in scenario logs
2. Fix implementation to meet requirements
3. Re-run failed scenarios: `./tests/run-tests.sh <command>`
4. Verify all tests pass before committing
