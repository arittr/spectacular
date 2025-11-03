# Test Scenario: Init Error Handling

## Context

Testing `/spectacular:init` command's error handling, recovery guidance, and user experience when validations fail.

**Setup:**
- Various invalid states (missing dependencies, wrong versions, etc.)
- User who may not be technical
- Need clear, actionable error messages

**Purpose:**
- Verify error messages are helpful, not cryptic
- Test recovery instructions work
- Ensure init stops on critical failures
- Validate warnings vs errors handled correctly

## Expected Behavior

### Error Severity Levels

#### Critical Error (Stop Execution)
```
❌ {What's wrong}

{Why this matters}

To fix:
1. {Step 1}
2. {Step 2}
3. Run /spectacular:init again

{Optional: Link to more help}
```

**Stops init immediately - cannot proceed**

#### Warning (Continue with Caution)
```
⚠️ {What's suboptimal}

This may cause:
- {Potential issue 1}
- {Potential issue 2}

Recommended fix:
{How to improve}

Continuing anyway...
```

**Allows init to continue, but user informed of risks**

#### Info (FYI Only)
```
ℹ️ {Something user should know}

{Optional context}
```

**Pure information, no action needed**

### Example Error Flows

#### Flow 1: Everything Missing

```bash
/spectacular:init
```

**Expected output:**
```
Validating spectacular environment...

❌ Superpowers plugin not installed

Spectacular requires the superpowers plugin for:
- Feature design (brainstorming skill)
- TDD workflows (test-driven-development skill)
- Code review (requesting-code-review skill)
- Parallel execution (using-git-worktrees skill)

To install:
1. Visit: https://github.com/obra/superpowers
2. Clone or download the repository
3. Copy to: ~/.claude/plugins/cache/superpowers/
4. Restart Claude Code
5. Run /spectacular:init again

Initialization stopped.
```

**Stops at first critical error, doesn't check later validations**

#### Flow 2: Superpowers OK, git-spice Missing

```bash
/spectacular:init
```

**Expected output:**
```
Validating spectacular environment...

✅ Superpowers plugin detected (version 1.x.x)

❌ git-spice not installed

Spectacular requires git-spice for stacked branch management.

To install git-spice:

macOS (Homebrew):
  brew install abhinav/tap/git-spice

Linux:
  curl -fsSL https://github.com/abhinav/git-spice/releases/latest/download/install.sh | sh

Windows:
  Visit: https://github.com/abhinav/git-spice/releases/latest

After installing, run /spectacular:init again.

Initialization stopped.
```

#### Flow 3: Everything Installed, Not a Git Repo

```bash
# In directory without .git
/spectacular:init
```

**Expected output:**
```
Validating spectacular environment...

✅ Superpowers plugin detected
✅ git-spice installed (version 0.x.x)

❌ Not a git repository

Spectacular commands require a git repository.

To initialize git:
1. cd /path/to/your/project
2. git init
3. git add .
4. git commit -m "Initial commit"
5. Run /spectacular:init again

Or, if this directory should not be a git repo:
- Use spectacular commands from within a git repository
- spectacular works best with existing projects, not empty directories

Initialization stopped.
```

#### Flow 4: All OK, Auto-Fix Applied

```bash
# git-spice installed but repo not initialized
/spectacular:init
```

**Expected output:**
```
Validating spectacular environment...

✅ Superpowers plugin detected (version 1.x.x)
✅ git-spice installed (version 0.x.x)
✅ Git repository detected

⚠️ Repository not initialized for git-spice
   Initializing automatically...

✅ Repository initialized for git-spice

All validations passed!

You can now use spectacular commands:
- /spectacular:spec - Create feature specification
- /spectacular:plan - Decompose into tasks
- /spectacular:execute - Run implementation

Next steps:
1. Create a feature spec: /spectacular:spec
2. Or view examples: ~/.claude/plugins/cache/spectacular/examples/
```

## Failure Modes

### Issue 1: Cryptic Error Messages

**Bad:**
```
Error: ENOENT
```

**Good:**
```
❌ Superpowers plugin not found at: ~/.claude/plugins/cache/superpowers/

This directory should contain the superpowers plugin files.

To install: [installation steps]
```

**Prevention:** Every error must explain WHAT failed and HOW to fix

### Issue 2: Cascading Errors

**Bad:**
```
❌ Superpowers not found
❌ git-spice not found
❌ Not a git repo
❌ No package.json
[10 more errors...]
```

**Good:**
```
❌ Superpowers not found
[Installation instructions]

Initialization stopped.
[Don't show other errors until this is fixed]
```

**Prevention:** Stop at first critical error, don't overwhelm user

### Issue 3: No Recovery Path

**Bad:**
```
❌ Validation failed
```

**Good:**
```
❌ git-spice version 0.3.0 is too old

Spectacular requires git-spice >= 0.4.0 for:
- Improved stacking reliability
- Better conflict resolution
- Performance improvements

To upgrade:
  brew upgrade git-spice

Then run /spectacular:init again.
```

**Prevention:** Every error must include fix instructions

### Issue 4: Assumptive Errors

**Bad (assumes user knowledge):**
```
❌ gs not in PATH
```

**Good (explains for beginners):**
```
❌ git-spice command (gs) not found

The 'gs' command should be available after installing git-spice.

If you just installed git-spice:
1. Close and reopen your terminal
2. Run: gs --version (should show version)
3. If still not found, check PATH contains git-spice install location

If not installed:
  [Installation instructions]
```

## Success Criteria

### Clarity
- [ ] Every error explains WHAT failed in plain language
- [ ] Every error explains WHY it matters
- [ ] No jargon or assumed knowledge

### Actionability
- [ ] Every error includes HOW to fix
- [ ] Fix instructions are step-by-step
- [ ] Fix instructions tested and verified to work

### Severity Handling
- [ ] Critical errors stop execution
- [ ] Warnings allow continuation with clear risks
- [ ] Info messages don't look like errors

### User Experience
- [ ] User never confused about what to do next
- [ ] Errors don't blame user ("you didn't..." → "X not found")
- [ ] Positive tone when things work ("✅" not just absence of errors)

### Error Recovery
- [ ] After fixing error, init succeeds
- [ ] No residual issues from previous failures
- [ ] Clear confirmation that fix worked

## Test Execution

### Test Case 1: All Dependencies Missing

```bash
# Setup
mv ~/.claude/plugins/cache/superpowers ~/.claude/plugins/cache/superpowers.backup
sudo mv /usr/local/bin/gs /usr/local/bin/gs.backup

# Test
/spectacular:init

# Verify:
# - Stops at superpowers check
# - Clear installation instructions
# - Doesn't cascade to git-spice errors

# Cleanup
mv ~/.claude/plugins/cache/superpowers.backup ~/.claude/plugins/cache/superpowers
sudo mv /usr/local/bin/gs.backup /usr/local/bin/gs
```

### Test Case 2: Each Error Individually

Test each validation failure in isolation:

```bash
# Superpowers missing only
# git-spice missing only
# Not git repo only
# git-spice repo not initialized only
# Old git-spice version only
```

Verify each has clear, specific error message.

### Test Case 3: Error Recovery Flow

```bash
# Start with error state
/spectacular:init  # Fails with clear error

# Follow fix instructions from error message
[Execute suggested fix]

# Re-run
/spectacular:init  # Should now succeed

# Verify success message is clear
```

### Test Case 4: Multiple Errors (Staged)

```bash
# Both superpowers and git-spice missing
/spectacular:init
# Should stop at superpowers, not show git-spice error yet

# Fix superpowers
[Install superpowers]

/spectacular:init
# Now shows git-spice error

# Fix git-spice
[Install git-spice]

/spectacular:init
# Now succeeds
```

## Error Message Templates

### Template: Missing Dependency

```
❌ {Dependency} not installed

Spectacular requires {dependency} for:
- {Feature 1}
- {Feature 2}

To install {dependency}:

{Platform-specific instructions}

After installing, run /spectacular:init again.

More info: {Link to docs}
```

### Template: Invalid Configuration

```
❌ {What's wrong with configuration}

This prevents:
- {Impact 1}
- {Impact 2}

To fix:
1. {Step 1}
2. {Step 2}
3. Run /spectacular:init again

Current state: {Helpful diagnostic info}
Expected state: {What it should be}
```

### Template: Auto-Fixed Issue

```
⚠️ {What was wrong}
   Fixing automatically...

✅ {What was fixed}

{What user should know about the fix}
```

### Template: Warning

```
⚠️ {What's suboptimal}

This may cause:
- {Potential issue 1}

Recommended action:
{How to fix}

Continuing with initialization...
```

## Platform-Specific Error Handling

### macOS-Specific

```
Detected OS: macOS

To install git-spice:
  brew install abhinav/tap/git-spice

Don't have Homebrew?
  Install: /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  Then: brew install abhinav/tap/git-spice
```

### Linux-Specific

```
Detected OS: Linux

To install git-spice:
  curl -fsSL https://github.com/abhinav/git-spice/releases/latest/download/install.sh | sh

Or manual install:
  Visit: https://github.com/abhinav/git-spice/releases/latest
  Download the appropriate binary for your architecture
```

### Windows-Specific

```
Detected OS: Windows

To install git-spice:
  iwr -useb https://github.com/abhinav/git-spice/releases/latest/download/install.ps1 | iex

Or manual install:
  Visit: https://github.com/abhinav/git-spice/releases/latest
  Download git-spice_windows_amd64.zip
  Extract and add to PATH
```

## Related Scenarios

- **validate-superpowers.md** - Superpowers-specific error cases
- **validate-git-spice.md** - git-spice-specific error cases

## Quality Checklist for Error Messages

Before approving any error message:

- [ ] Does it explain WHAT failed in plain language?
- [ ] Does it explain WHY this matters?
- [ ] Does it include step-by-step HOW to fix?
- [ ] Are fix instructions platform-specific if needed?
- [ ] Is the tone helpful, not blaming?
- [ ] Would a non-technical user understand it?
- [ ] Have the fix instructions been tested?
- [ ] Is there a link to more detailed help?
- [ ] Is the severity appropriate (error vs warning)?
- [ ] Does it stop execution if critical?

**If any checkbox is NO, revise the error message.**
