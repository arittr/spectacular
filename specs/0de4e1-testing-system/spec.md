# Testing System for Spectacular

**RUN_ID**: 0de4e1
**Feature**: Systematic testing infrastructure for spectacular commands and workflows
**Created**: 2025-11-03

## Problem Statement

### Current State

Spectacular has no systematic way to test commands and workflows before deployment. Testing is ad-hoc:

- Commands are tested manually by invoking them in sample projects
- Regression testing requires remembering what scenarios to test
- No test fixtures or documented test scenarios
- When bugs are found (like the 9f92a8 stacking regression), we fix them but don't encode the test case
- No way to validate fixes before deployment beyond "it worked once"

This leads to:
- Regressions slipping through (9f92a8 stacking issues)
- Time wasted recreating test scenarios from scratch
- No confidence that fixes don't break other scenarios
- Manual testing is inconsistent and incomplete

### Desired State

Spectacular should have a **reusable testing system** that:

- Documents test scenarios as executable markdown files
- Provides test fixtures (TypeScript + non-TypeScript projects) for realistic testing
- Automates test execution with `/spectacular:test [command]`
- Applies RED-GREEN-REFACTOR methodology systematically
- Catches regressions before deployment
- Makes the testing process we used for 9f92a8 stacking fixes **repeatable and systematic**

## Requirements

### Functional Requirements

#### FR1: Test Scenarios
Test scenarios must be stored as structured markdown files that can be executed by subagents.

**Location**: `tests/scenarios/{command}/`

**Structure**:
```markdown
# Test Scenario: {name}

## Context
{What state is the system in before test starts}

## Expected Behavior
{What should happen when command runs}

## Failure Modes to Observe
{What shortcuts or rationalizations might occur}

## Success Criteria
{How to verify test passed}
```

**Coverage**:
- Execute command: parallel stacking (2 tasks, 3 tasks, 4 tasks), sequential stacking, worktree creation, cleanup
- Init command: dependency validation, git-spice setup, error handling
- Spec command: constitution referencing, lean spec generation
- Plan command: task decomposition, phase grouping, dependency detection

#### FR2: Test Fixtures
Provide realistic project templates for testing commands end-to-end.

**Fixtures Required**:
- `tests/fixtures/simple-typescript/` - Minimal TypeScript project with package.json, git repo
- `tests/fixtures/simple-python/` - Minimal Python project with requirements.txt, git repo

**Each fixture must**:
- Be a valid git repository (initialized with `git init`)
- Have git-spice initialized (`gs repo init`)
- Include setup commands in CLAUDE.md (install, postinstall, test, lint, build)
- Be small enough to clone/setup quickly (<1 minute)
- Represent common project patterns (not edge cases)

#### FR3: Testing Skill
Document the testing process as a reusable skill following superpowers format.

**Location**: `skills/testing-spectacular/SKILL.md`

**Process**:
1. RED: Run baseline test without fixes (document failures)
2. GREEN: Apply fixes to commands/skills
3. REFACTOR: Re-run tests with edge cases (catch flaws like 9f92a8 worktree creation)
4. Iterate until all scenarios pass

**Must include**:
- When to Use section (before releases, after finding regressions)
- Rationalization table (shortcuts to avoid during testing)
- TodoWrite checklist for RED-GREEN-REFACTOR phases
- Integration with `testing-workflows-with-subagents` from superpowers

#### FR4: Test Command
Provide `/spectacular:test [command]` to automate test execution.

**Interface**:
```bash
/spectacular:test execute    # Test execute command scenarios
/spectacular:test init       # Test init command scenarios
/spectacular:test all        # Test all scenarios
```

**Behavior**:
- Dispatch subagents in parallel (default) to run test scenarios
- Each subagent gets fresh test fixture clone
- Report pass/fail for each scenario
- Aggregate results at end
- Exit with non-zero code if any test fails (for future CI integration)

#### FR5: Manual Testing First, CI Later
System must work for manual testing now. CI/CD integration is future work.

**Current scope**: Human invokes `/spectacular:test`, reviews results, iterates on fixes
**Future scope**: GitHub Actions runs tests on PR, blocks merge if tests fail

### Non-Functional Requirements

#### NFR1: Constitution Compliance
All components must follow spectacular's constitution:

- **Architecture**: Testing skill in `skills/` layer, test command in `commands/` layer, constitutions referenced not duplicated
- **Patterns**: Use `testing-workflows-with-subagents` skill, include rationalization tables, require TodoWrite checklists
- **Tech Stack**: Markdown + YAML frontmatter only, no build process, no test frameworks
- **Testing**: Test the testing skill itself using `testing-skills-with-subagents` before deployment

See: [`docs/constitutions/current/`](../../docs/constitutions/current/)

#### NFR2: Integration with Superpowers
Must use `testing-workflows-with-subagents` skill from superpowers, not recreate testing workflows.

Reference: [superpowers plugin](https://github.com/obra/superpowers)

#### NFR3: Maintainability
Test scenarios must be easy to add/update as commands evolve.

**Design principle**: One scenario file = one test case. Adding regression test = adding one markdown file.

#### NFR4: Performance
Test execution should be fast enough for frequent use.

**Targets**:
- Single scenario: <5 minutes (subagent startup + test execution)
- Full test suite: <30 minutes (parallel execution across scenarios)
- Test fixture setup: <1 minute (simple projects, no heavy dependencies)

## Architecture

### New Components

#### `tests/` Directory Structure
```
tests/
├── scenarios/
│   ├── execute/
│   │   ├── parallel-stacking-2-tasks.md
│   │   ├── parallel-stacking-3-tasks.md
│   │   ├── parallel-stacking-4-tasks.md
│   │   ├── sequential-stacking.md
│   │   ├── worktree-creation.md
│   │   └── cleanup-tmp-branches.md
│   ├── init/
│   │   ├── validate-superpowers.md
│   │   ├── validate-git-spice.md
│   │   └── error-handling.md
│   ├── spec/
│   │   └── lean-spec-generation.md
│   └── plan/
│       └── task-decomposition.md
└── fixtures/
    ├── simple-typescript/
    │   ├── CLAUDE.md          # Setup + quality check commands
    │   ├── package.json       # Minimal deps
    │   ├── tsconfig.json
    │   ├── src/index.ts       # Trivial app
    │   └── .git/              # Initialized repo with gs
    └── simple-python/
        ├── CLAUDE.md          # Setup + quality check commands
        ├── requirements.txt   # Minimal deps
        ├── src/main.py        # Trivial app
        └── .git/              # Initialized repo with gs
```

#### `skills/testing-spectacular/SKILL.md`
New skill following superpowers format that documents:
- When to use (before releases, after finding regressions)
- The process (RED-GREEN-REFACTOR with test scenarios)
- Quality rules (all scenarios must pass before committing fixes)
- Rationalization table (avoid shortcuts like "manually tested once is enough")

#### `commands/test.md`
New command that orchestrates test execution:
- Clones test fixture to temp directory
- Dispatches subagents in parallel to run scenarios
- Collects and reports results
- Cleans up temp directories

### Modified Components

None. This is purely additive - no changes to existing commands, skills, or constitution.

### Dependencies

**Internal**:
- `testing-workflows-with-subagents` skill from superpowers (RED-GREEN-REFACTOR methodology)
- Task tool for dispatching subagents
- Bash tool for fixture setup and cleanup

**External**:
- Git (for fixture repositories)
- Git-spice (fixtures must have `gs repo init` run)

## Acceptance Criteria

### AC1: Test Scenarios Executable
- [ ] All test scenarios in `tests/scenarios/` are structured markdown files
- [ ] Each scenario has Context, Expected Behavior, Failure Modes, Success Criteria sections
- [ ] Scenarios can be executed by subagents via `testing-workflows-with-subagents` skill
- [ ] At least 6 scenarios for execute command (covering 9f92a8 regression cases)

### AC2: Test Fixtures Realistic
- [ ] `tests/fixtures/simple-typescript/` is valid git repo with git-spice initialized
- [ ] `tests/fixtures/simple-python/` is valid git repo with git-spice initialized
- [ ] Each fixture has CLAUDE.md with setup commands (install, postinstall, test, lint, build)
- [ ] Fixtures can be cloned and setup in <1 minute

### AC3: Testing Skill Complete
- [ ] `skills/testing-spectacular/SKILL.md` follows superpowers format
- [ ] Skill includes rationalization table with observed shortcuts from 9f92a8 testing
- [ ] Skill requires TodoWrite checklist for RED-GREEN-REFACTOR phases
- [ ] Skill has been tested with `testing-skills-with-subagents` before deployment

### AC4: Test Command Functional
- [ ] `/spectacular:test [command]` dispatches subagents to run scenarios
- [ ] Subagents run in parallel (default behavior)
- [ ] Test results aggregated and reported at end
- [ ] Exit code non-zero if any test fails (for future CI)

### AC5: Regression Tests Pass
- [ ] All 6 execute command scenarios pass with current fixes (post-9f92a8)
- [ ] Scenarios include edge cases (2-task, 4-task) that caught worktree creation flaw
- [ ] Tests can be re-run to validate future changes don't regress

### AC6: Documentation Complete
- [ ] README.md or TESTING.md documents how to use the testing system
- [ ] Examples of adding new test scenarios
- [ ] Guidance on when to run tests (before releases, after finding bugs)

## Open Questions

None - all design decisions validated during brainstorming phase.

## References

### Constitution
- [Architecture](../../docs/constitutions/current/architecture.md) - Layer boundaries (commands, skills, constitution)
- [Patterns](../../docs/constitutions/current/patterns.md) - Mandatory workflows (RED-GREEN-REFACTOR, metaskills usage)
- [Tech Stack](../../docs/constitutions/current/tech-stack.md) - Markdown + YAML only, no build process
- [Testing](../../docs/constitutions/current/testing.md) - Use `testing-workflows-with-subagents` for all testing

### External Documentation
- [Superpowers Plugin](https://github.com/obra/superpowers) - Source of `testing-workflows-with-subagents` skill
- [Git-Spice](https://github.com/abhinav/git-spice) - Stacked branch management (required in fixtures)

### Related Specs
None - this is the first systematic testing infrastructure for spectacular.

### Execution Logs
- [Run 9f92a8](../../logs/execute/9f92a8/) - Stacking regression that motivated this testing system
- [Analysis](../../analysis-9f92a8-stacking-issues.md) - Root cause analysis of regression
- [Test Results](../../REFACTOR-TEST-RESULTS.md) - RED-GREEN-REFACTOR testing that caught worktree creation flaw

## Usage

**Before releases**:
```bash
/spectacular:test all
# Review results, fix any failures, re-test until all pass
```

**After finding regressions**:
1. Add test scenario to `tests/scenarios/{command}/regression-{issue}.md`
2. Run `/spectacular:test {command}` to verify scenario fails (RED)
3. Fix the command/skill
4. Run `/spectacular:test {command}` to verify scenario passes (GREEN)
5. Run `/spectacular:test all` to check for side effects (REFACTOR)
6. Commit fix + test scenario together

**Adding new scenarios**:
1. Create `tests/scenarios/{command}/{scenario-name}.md` with standard structure
2. Run `/spectacular:test {command}` to validate scenario is executable
3. Commit scenario to repository

## Timeline

Not applicable - this is a spec, not a project plan. See `/spectacular:plan` for task decomposition and estimates.
