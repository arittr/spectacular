# Test Fixtures

## Overview

Minimal project templates for testing spectacular commands in isolation. Each fixture is a complete, working project with:
- Valid git repository with git-spice initialized
- Setup commands defined in CLAUDE.md
- Working tests (all passing)
- Quality check tooling (lint, format, build)

## Setup

**IMPORTANT**: Fixtures require git initialization before use.

```bash
# Initialize all fixtures (creates .git repos + git-spice)
./init-fixtures.sh

# Validate fixtures are ready
./validate-fixtures.sh
```

### What `init-fixtures.sh` does:
1. Creates git repository in each fixture (`git init`)
2. Makes initial commit with all fixture files
3. Initializes git-spice with trunk=main
4. Validates git and git-spice are working

### First-time setup timing:
- **simple-typescript**: ~12 seconds (374 npm packages)
- **simple-python**: ~6 seconds (10 pip packages)

Both fixtures install dependencies in <1 minute as required by the plan.

## Available Fixtures

### `simple-typescript/`

**Language**: TypeScript + Node.js
**Test Framework**: Jest
**Linting**: ESLint
**Formatting**: Prettier

**CLAUDE.md Commands**:
- `install`: `npm install`
- `test`: `npm test`
- `lint`: `npm run lint`
- `format`: `npm run format`
- `build`: `npm run build`

**Code**: Simple arithmetic functions (add, subtract, multiply, divide) with 6 passing tests.

**Use for**: Testing spectacular commands with TypeScript/Node.js projects.

### `simple-python/`

**Language**: Python 3.x
**Test Framework**: pytest
**Linting**: ruff
**Formatting**: black

**CLAUDE.md Commands**:
- `install`: `pip install -r requirements.txt`
- `test`: `pytest`
- `lint`: `ruff check .`
- `format`: `black .`
- `build`: `python -m py_compile src/main.py`

**Code**: Simple arithmetic functions (add, subtract, multiply, divide) with 5 passing tests.

**Use for**: Testing spectacular commands with Python projects.

## Why `.git` Directories Are Excluded

The parent repo's `.gitignore` excludes `tests/fixtures/*/.git/` because:

1. **Nested repos cause confusion**: Git doesn't track nested repositories well
2. **Fixtures are templates**: Meant to be cloned/copied for each test run
3. **Fresh state needed**: Each test scenario needs a clean git history
4. **git-spice initialization**: Each test needs to initialize git-spice independently

Fixture **files** are tracked in the parent repo, but their `.git` directories are created dynamically by `init-fixtures.sh`.

## Usage in Test Scenarios

Test scenarios (in `tests/scenarios/`) clone fixtures to temporary directories:

```bash
# Typical pattern in test scenario
TEMP_DIR=".worktrees/test-$(date +%s)"
cp -r tests/fixtures/simple-typescript "$TEMP_DIR"
cd "$TEMP_DIR"

# Fixture is already git-initialized (from init-fixtures.sh)
git status  # ✅ Works
gs ls       # ✅ Shows trunk branch

# Run spectacular command
/spectacular:spec "Add user authentication"
```

## Adding New Fixtures

**Only add new fixtures for language-specific behavior testing.**

Most tests should use existing fixtures. Add new fixtures when:
- Testing language-specific spectacular behavior
- Existing fixtures can't represent the scenario
- New tech stack needs validation

### Steps to add a fixture:

1. Create directory: `tests/fixtures/simple-{language}/`
2. Add minimal working project with:
   - CLAUDE.md (with setup + quality check commands)
   - Working code (1-2 simple functions)
   - Passing tests (5-10 tests)
   - .gitignore (exclude build artifacts)
3. Keep it minimal (<20 files, <1min setup time)
4. Run `./init-fixtures.sh` to initialize git
5. Run `./validate-fixtures.sh` to verify

## Troubleshooting

### "fatal: not a git repository"

**Cause**: Fixtures not initialized
**Fix**: Run `./init-fixtures.sh`

### "gs: command not found"

**Cause**: git-spice not installed
**Fix**: Install git-spice (see spectacular docs)

### "Could not locate `gs repo` state"

**Cause**: git-spice not initialized in fixture
**Fix**: Run `./init-fixtures.sh` (reinitializes all fixtures)

### Fixture setup takes >1 minute

**Cause**: Network issues or missing package cache
**Investigation**:
```bash
cd tests/fixtures/simple-typescript
time npm install  # Should be <15 seconds
```

If consistently slow, dependency list may need pruning.

## Validation

After initialization, validate fixtures are ready:

```bash
./validate-fixtures.sh
```

**Checks**:
- ✅ Git repository exists (`.git/` present)
- ✅ git-spice initialized (`gs ls` works)
- ✅ CLAUDE.md exists with required commands
- ✅ Setup completes in <1 minute

All checks must pass before using fixtures for testing.
