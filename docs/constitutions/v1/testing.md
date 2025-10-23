# Testing

## Core Principle

**Documentation-only projects require different validation than code projects.**

Traditional unit tests don't apply to markdown. Instead, we validate that:
1. Commands execute correctly when invoked
2. Skills guide Claude to correct behavior under pressure
3. Patterns resist rationalization

## Testing Philosophy

### What We Test

**Commands:**
- Do they invoke correctly via `/spectacular:*`?
- Do they delegate to skills properly?
- Do prerequisite checks catch invalid environments?
- Do TodoWrite todos track progress correctly?

**Skills:**
- Do they guide Claude to correct behavior?
- Do they resist rationalization under pressure?
- Do quality rules catch violations?
- Do error recovery steps work?

**Constitutions:**
- Are references using `current/` symlink?
- Are all required files present in each version?
- Is version history documented in meta.md?

### What We Don't Test

**Not tested:**
- Line coverage (no code to cover)
- Unit tests (no functions to test)
- Integration tests (no integrations beyond Claude Code)
- Performance (documentation has no runtime)

## Command Testing

### Manual Testing Approach

**Process:**
1. Create test repository or use existing project
2. Invoke command via `/spectacular:{command}`
3. Observe behavior, check TodoWrite updates
4. Verify expected outcome (spec created, plan generated, etc.)

**Example:**
```bash
# In test repository
cd ~/test-project

# Invoke command in Claude Code
/spectacular:init

# Expected: Environment validation, dependency checks
# Expected: TodoWrite shows validation steps
# Expected: Success message or clear error
```

### Command Checklist

Before marking command as complete:

- [ ] Command invokes without errors
- [ ] Description appears in command list
- [ ] Frontmatter is valid YAML
- [ ] Skills are referenced correctly (not duplicated)
- [ ] TodoWrite todos track progress
- [ ] Error messages are clear and actionable
- [ ] Prerequisites are validated before execution
- [ ] Output matches expected format

### Test Scenarios

**Happy path:**
- Valid environment, dependencies installed
- Expected: Command completes successfully

**Missing dependencies:**
- Superpowers not installed
- Expected: Clear error message, installation instructions

**Invalid state:**
- Not in git repository (for git-dependent commands)
- Expected: Error message, fix instructions

**Partial completion:**
- Command interrupted mid-execution
- Expected: TodoWrite shows incomplete state, can resume

## Skill Testing

### Testing Skills with Subagents

**Primary method:** Use `testing-skills-with-subagents` skill from superpowers

**Process:**
1. Create pressure scenarios that test skill rules
2. Run baseline (subagent without skill) - should fail
3. Run with skill - should pass
4. Iterate on skill until bulletproof

**Example:**
```markdown
# Test scenario: Constitution versioning
Scenario: Add new pattern to constitution
Expected: Create new version, not edit current
Pressure: "This change is non-breaking, can edit in-place"
Success: Subagent creates v2, updates symlink
```

### Skill Quality Checklist

Before marking skill as complete:

- [ ] Frontmatter has name and description
- [ ] "When to Use" section with clear triggers
- [ ] "The Process" with numbered steps
- [ ] "Announce" instruction present
- [ ] Rationalization table (if applicable)
- [ ] TodoWrite checklist (if multi-step)
- [ ] Tested with subagent under pressure
- [ ] Quality rules are enforceable
- [ ] Error handling covers common failures

### Rationalization Testing

**Critical:** Skills must resist predictable rationalizations

**Test method:**
1. Identify likely shortcuts Claude will take
2. Document them in rationalization table
3. Run subagent with pressure to skip steps
4. Verify skill prevents shortcuts

**Example rationalizations:**
- "I remember this skill" → Skill says MUST read current version
- "This is simple, skill is overkill" → Skill says simple tasks become complex when process skipped
- "Change is non-breaking" → Skill says ANY pattern change needs versioning

**Success criteria:** Subagent follows process despite pressure to skip.

## Constitution Testing

### Validation Checks

**After creating new version:**

```bash
# Verify all required files exist
ls docs/constitutions/v1/meta.md
ls docs/constitutions/v1/architecture.md
ls docs/constitutions/v1/patterns.md
ls docs/constitutions/v1/tech-stack.md
ls docs/constitutions/v1/schema-rules.md
ls docs/constitutions/v1/testing.md

# Verify symlink points to correct version
ls -la docs/constitutions/current
# Should show: current -> v1

# Verify no hardcoded version references
grep -r "constitutions/v[0-9]" commands/
grep -r "constitutions/v[0-9]" skills/
# Should return nothing (all references use current/)
```

### Constitution Checklist

Before marking constitution version as complete:

- [ ] All 6 files present (meta, architecture, patterns, tech-stack, schema-rules, testing)
- [ ] meta.md has version number and changelog
- [ ] meta.md documents rationale (why, not just what)
- [ ] Previous version (if exists) is untouched
- [ ] Symlink points to new version
- [ ] All references use current/ not v{N}/
- [ ] Minimal changes only (no reorganizing)

## Integration Testing

### End-to-End Workflow

**Test complete workflow in real project:**

1. Initialize: `/spectacular:init`
2. Spec: `/spectacular:spec` - create feature spec
3. Plan: `/spectacular:plan` - decompose into tasks
4. Execute: `/spectacular:execute` - run with worktrees and subagents

**Success criteria:**
- Each command completes without errors
- Spec references constitutions correctly
- Plan has valid task breakdown
- Execution creates branches, runs tests, stacks correctly

**Test frequency:** Before each release

### Cross-Plugin Integration

**Test with superpowers:**

Verify spectacular correctly delegates to superpowers skills:
- `brainstorming` - Used in spec creation
- `requesting-code-review` - Used in execute workflow
- `using-git-worktrees` - Used for parallel execution
- `verification-before-completion` - Used before marking tasks done

**Success criteria:** Delegation works, no duplication of superpowers logic

## Regression Testing

### After Changes

**When to test:**
- After editing command
- After editing skill
- After creating new constitution version
- Before creating release

**What to test:**
- Commands still invoke correctly
- Skills still guide to correct behavior
- Constitution references still valid
- No broken symlinks

### Known Issues Tracking

**If bugs found:**
1. Document issue and reproduction steps
2. Create fix
3. Test fix in isolation
4. Test fix in full workflow
5. Document in changelog if significant

**No formal issue tracker** - this is a small plugin. Use git issues if needed.

## Release Testing

### Pre-Release Checklist

Before running release scripts:

- [ ] All commands tested manually
- [ ] Skills tested with subagents (if changed)
- [ ] Constitution validation passes
- [ ] Version number in package.json updated
- [ ] Version synced to plugin.json (`npm run sync-version`)
- [ ] Git status is clean (no uncommitted changes)
- [ ] Recent commits have meaningful messages

### Post-Release Validation

After running `pnpm release:*`:

- [ ] Git tag created (e.g., `v1.2.0`)
- [ ] Version bumped correctly in both package.json and plugin.json
- [ ] Changes pushed to remote
- [ ] Plugin still loads in Claude Code
- [ ] Commands still invoke

## Automated Validation (Future)

### Potential Scripts

Could add automated checks:

**scripts/validate-plugin.sh:**
```bash
#!/bin/bash
# Verify plugin.json is valid JSON
# Verify all commands listed in plugin.json exist in commands/
# Verify all command files have valid frontmatter
```

**scripts/validate-skills.sh:**
```bash
#!/bin/bash
# Verify all skills have SKILL.md file
# Verify all skills have valid frontmatter with name/description
```

**scripts/validate-constitution.sh:**
```bash
#!/bin/bash
# Verify all constitution versions have 6 required files
# Verify current symlink exists and is valid
# Verify no hardcoded version references in commands/skills
```

**Not currently implemented** - manual testing sufficient for current scale.

## Test Coverage Philosophy

**Traditional coverage metrics don't apply.**

Instead, we measure:
- **Command coverage:** All commands tested in real workflow? Yes/No
- **Skill coverage:** All skills tested with subagents under pressure? Yes/No
- **Constitution coverage:** All references use current/ symlink? Yes/No
- **Integration coverage:** End-to-end workflow tested before release? Yes/No

**Success criteria:** 100% on all four metrics before each release.

## Testing in Development

### Quick Validation During Development

**After editing command:**
```bash
# Test invocation
/spectacular:{command}
```

**After editing skill:**
```bash
# Read skill to verify format
# Test via command that uses it, or invoke directly with Skill tool
```

**After editing constitution:**
```bash
# Verify symlink
ls -la docs/constitutions/current

# Check references
grep -r "constitutions/v[0-9]" commands/ skills/
```

### Continuous Validation

**On each change:**
1. Make edit
2. Test immediately (command invocation or skill usage)
3. Fix issues before moving to next change

**Don't batch testing** - immediate feedback prevents cascading failures.

## Failure Modes

### What Breaks if Testing is Skipped?

| Skipped Test | Consequence |
|--------------|-------------|
| Command not tested | Breaks in production, user sees errors |
| Skill not pressure-tested | Claude rationalizes away rules, skill ineffective |
| Constitution references not validated | Broken links when new version created |
| Integration not tested | Commands work in isolation but fail in workflow |
| Version sync not verified | plugin.json/package.json version mismatch |

**Testing isn't optional** - it's the only way to verify documentation works under real conditions.

## When Tests are Passing

**Definition of "passing":**
- All commands invoke without errors
- All skills guide Claude to correct behavior under pressure
- All constitution references use current/ symlink
- End-to-end workflow completes successfully
- Version numbers are synced

**When tests pass, you can:**
- Create release
- Merge changes
- Deploy to users

**When tests don't pass:**
- Fix issues
- Re-test
- Don't release until passing

No exceptions.
