# Test Scenarios for Spectacular Commands

This directory contains test scenarios for validating spectacular commands via the `testing-workflows-with-subagents` skill.

## Structure

Each scenario follows a standard format:

### Required Sections

1. **Context** - Setup, prerequisites, and scenario background
2. **Expected Behavior** - Step-by-step expected workflow
3. **Failure Modes** - Known issues and how to detect them
4. **Success Criteria** - Checklist for validation

### Optional Sections

- **Test Execution** - How to run the scenario
- **Related Scenarios** - Links to related tests
- **Edge Cases** - Unusual situations to test
- **Reference Commands** - Useful commands for debugging

## Scenarios by Command

### `/spectacular:init` (3 scenarios)

Tests environment validation and setup:

- **validate-superpowers.md** - Superpowers plugin detection and validation
- **validate-git-spice.md** - git-spice installation and repo initialization
- **error-handling.md** - Error message quality and recovery guidance

### `/spectacular:spec` (1 scenario)

Tests feature specification generation:

- **lean-spec-generation.md** - Constitution-anchored spec creation

### `/spectacular:plan` (1 scenario)

Tests task decomposition and phase grouping:

- **task-decomposition.md** - Quality rules, sizing, and parallelization

### `/spectacular:execute` (6 scenarios)

Tests execution orchestration and stacking:

- **parallel-stacking-2-tasks.md** - Minimal parallel case (2 tasks)
- **parallel-stacking-3-tasks.md** - Standard parallel case (3 tasks, 9f92a8 regression)
- **parallel-stacking-4-tasks.md** - Extended parallel case (4 tasks, scalability)
- **sequential-stacking.md** - Sequential task execution and natural stacking
- **worktree-creation.md** - Isolated worktree creation logic
- **cleanup-tmp-branches.md** - Temporary branch cleanup

## Regression Testing

Several scenarios specifically test fixes for the 9f92a8 regression:

**9f92a8 Issues:**
1. Nested worktree creation (path confusion)
2. Temporary branch pollution
3. Multiple stacking attempts (trial-and-error)
4. Context switching confusion

**Covered by:**
- parallel-stacking-3-tasks.md (full regression scenario)
- worktree-creation.md (Issue #1)
- cleanup-tmp-branches.md (Issue #2)

**Analysis files:**
- /analysis-9f92a8-stacking-issues.md
- /red-phase-findings.md

## Running Scenarios

### Using testing-workflows-with-subagents

```bash
# In Claude Code, invoke the testing skill:
Use testing-workflows-with-subagents skill to test [scenario file]

# Example:
Use testing-workflows-with-subagents skill to test tests/scenarios/execute/parallel-stacking-3-tasks.md
```

### Manual Testing

```bash
# Setup test repository
mkdir /tmp/test-spectacular
cd /tmp/test-spectacular
git init
gs repo init

# Run the command being tested
/spectacular:init
/spectacular:spec
/spectacular:plan
/spectacular:execute

# Validate against Success Criteria in scenario
```

## Success Criteria Summary

### All Scenarios Must:
- [ ] Have Context, Expected Behavior, Failure Modes, Success Criteria sections
- [ ] Reference specific failure modes (not generic)
- [ ] Include detection commands for failures
- [ ] Provide clear success validation

### Execute Scenarios Must Also:
- [ ] Reference 9f92a8 regression where applicable
- [ ] Test stacking patterns explicitly
- [ ] Verify worktree creation correctness
- [ ] Check for temporary branch pollution

## Adding New Scenarios

When adding a new test scenario:

1. **Use standard template:**
   ```markdown
   # Test Scenario: {Name}

   ## Context
   {Setup and background}

   ## Expected Behavior
   {Step-by-step workflow}

   ## Failure Modes
   {Known issues with detection}

   ## Success Criteria
   {Validation checklist}
   ```

2. **Reference specific issues:**
   - Link to regression analysis if testing a fix
   - Reference constitution rules if testing patterns
   - Link to related scenarios

3. **Make scenarios executable:**
   - Include exact commands to run
   - Provide validation commands
   - Clear setup/cleanup steps

4. **Test the scenario:**
   - Run it manually first
   - Verify success criteria are checkable
   - Ensure failure modes are detectable

## Maintenance

### When Updating Commands

If you modify a command (init.md, spec.md, plan.md, execute.md):

1. Check which scenarios test that command
2. Update scenarios to reflect new behavior
3. Add new scenarios if new features added
4. Mark deprecated scenarios if features removed

### When Fixing Bugs

After fixing a regression:

1. Create scenario documenting the bug
2. Show expected behavior (fixed state)
3. Document failure modes (how bug manifested)
4. Include detection to prevent regression

## Related Documentation

- **CLAUDE.md** - Constitution and patterns
- **commands/** - Command documentation
- **skills/testing-workflows-with-subagents/** - Testing skill
- **analysis-9f92a8-stacking-issues.md** - Regression analysis
- **red-phase-findings.md** - RED phase test results
