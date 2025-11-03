# Test Scenario: Validate Superpowers Plugin

## Context

Testing `/spectacular:init` command's ability to detect and validate the superpowers plugin installation.

**Setup:**
- Fresh Claude Code environment
- May or may not have superpowers installed
- May have superpowers but wrong version

**Purpose:**
- Verify superpowers plugin detection
- Provide clear error messages if missing
- Validate critical superpowers skills are available

## Expected Behavior

### Case 1: Superpowers Installed and Valid

**Detection:**
```bash
# Check if superpowers plugin directory exists
ls ~/.claude/plugins/cache/superpowers/

# Verify plugin.json exists
cat ~/.claude/plugins/cache/superpowers/.claude-plugin/plugin.json

# Check for critical skills
ls ~/.claude/plugins/cache/superpowers/skills/brainstorming/SKILL.md
ls ~/.claude/plugins/cache/superpowers/skills/test-driven-development/SKILL.md
ls ~/.claude/plugins/cache/superpowers/skills/requesting-code-review/SKILL.md
ls ~/.claude/plugins/cache/superpowers/skills/using-git-worktrees/SKILL.md
```

**Expected output:**
```
✅ Superpowers plugin detected
✅ Version: {version}
✅ Critical skills available:
   - brainstorming
   - test-driven-development
   - requesting-code-review
   - using-git-worktrees
```

### Case 2: Superpowers Not Installed

**Detection:**
```bash
ls ~/.claude/plugins/cache/superpowers/
# Exit code 1 (directory doesn't exist)
```

**Expected output:**
```
❌ Superpowers plugin not found

Spectacular requires the superpowers plugin to function.

To install superpowers:
1. Visit: https://github.com/obra/superpowers
2. Clone or download the repository
3. Copy to: ~/.claude/plugins/cache/superpowers/
4. Restart Claude Code
5. Run /spectacular:init again

Why superpowers is required:
- brainstorming: Feature design refinement
- test-driven-development: TDD workflow enforcement
- requesting-code-review: Automated code review
- using-git-worktrees: Parallel task isolation
```

**Action:** Stop initialization, do not proceed

### Case 3: Superpowers Installed But Incomplete

**Detection:**
```bash
# Plugin directory exists
ls ~/.claude/plugins/cache/superpowers/  # Success

# But critical skills missing
ls ~/.claude/plugins/cache/superpowers/skills/brainstorming/SKILL.md
# Exit code 1 (file not found)
```

**Expected output:**
```
⚠️ Superpowers plugin found but incomplete

Missing critical skills:
- brainstorming: ~/.claude/plugins/cache/superpowers/skills/brainstorming/SKILL.md

This may indicate:
- Corrupted installation
- Outdated version
- Partial download

Recommended action:
1. Remove existing installation: rm -rf ~/.claude/plugins/cache/superpowers
2. Reinstall from: https://github.com/obra/superpowers
3. Run /spectacular:init again
```

**Action:** Stop initialization with warning

## Failure Modes

### Issue 1: False Positive Detection

**Symptom:** Init claims superpowers installed when it's not

**Root Cause:** Only checked directory existence, not content

**Detection:**
```bash
# Directory exists but empty:
ls ~/.claude/plugins/cache/superpowers/  # Success
ls ~/.claude/plugins/cache/superpowers/.claude-plugin/plugin.json  # Fails
```

**Prevention:** Check for specific files, not just directory

### Issue 2: Version Compatibility Not Checked

**Symptom:** Init passes but spectacular commands fail with "skill not found"

**Root Cause:** Old superpowers version missing newly required skills

**Detection:**
```bash
# Compare plugin versions
cat ~/.claude/plugins/cache/superpowers/.claude-plugin/plugin.json | grep version
# Check against known compatible versions
```

**Prevention:** Validate minimum superpowers version

### Issue 3: Ambiguous Error Messages

**Symptom:** User doesn't understand how to fix missing superpowers

**Root Cause:** Error message doesn't provide actionable steps

**Bad message:**
```
Error: Superpowers not found
```

**Good message:**
```
❌ Superpowers plugin not found at: ~/.claude/plugins/cache/superpowers/

To install:
1. Visit: https://github.com/obra/superpowers
2. Copy to: ~/.claude/plugins/cache/superpowers/
3. Restart Claude Code

After installing, run /spectacular:init again.
```

### Issue 4: Silent Failure

**Symptom:** Init completes successfully despite superpowers missing

**Root Cause:** Validation skipped or error ignored

**Impact:** Later commands fail mysteriously when trying to use superpowers skills

**Prevention:** Make superpowers validation required (not optional warning)

## Success Criteria

### Detection Accuracy
- [ ] Correctly identifies when superpowers is installed
- [ ] Correctly identifies when superpowers is missing
- [ ] Correctly identifies partial/corrupted installations

### Error Messages
- [ ] Clear explanation of what's wrong
- [ ] Actionable steps to fix
- [ ] Links to installation instructions
- [ ] No jargon or assumed knowledge

### Validation Depth
- [ ] Checks plugin directory exists
- [ ] Checks plugin.json exists and is valid
- [ ] Checks critical skills exist
- [ ] (Optional) Checks version compatibility

### User Experience
- [ ] Init stops if superpowers missing (doesn't continue)
- [ ] User knows exactly what to do to fix
- [ ] After fixing, init succeeds
- [ ] No false positives or negatives

## Test Execution

### Test Case 1: Clean Install (Superpowers Missing)

```bash
# Setup: Remove superpowers
mv ~/.claude/plugins/cache/superpowers ~/.claude/plugins/cache/superpowers.backup

# Test
/spectacular:init

# Expected: Clear error with installation instructions

# Cleanup
mv ~/.claude/plugins/cache/superpowers.backup ~/.claude/plugins/cache/superpowers
```

### Test Case 2: Valid Installation

```bash
# Setup: Ensure superpowers installed
ls ~/.claude/plugins/cache/superpowers/.claude-plugin/plugin.json

# Test
/spectacular:init

# Expected: ✅ Superpowers detected, proceeds to next check
```

### Test Case 3: Corrupted Installation

```bash
# Setup: Corrupt superpowers (remove critical skill)
mv ~/.claude/plugins/cache/superpowers/skills/brainstorming \
   ~/.claude/plugins/cache/superpowers/skills/brainstorming.backup

# Test
/spectacular:init

# Expected: ⚠️ Incomplete installation warning

# Cleanup
mv ~/.claude/plugins/cache/superpowers/skills/brainstorming.backup \
   ~/.claude/plugins/cache/superpowers/skills/brainstorming
```

## Validation Logic

### Minimal Check (Basic)

```bash
# Check 1: Directory exists
if [ ! -d ~/.claude/plugins/cache/superpowers ]; then
  echo "❌ Superpowers not installed"
  exit 1
fi

# Check 2: plugin.json exists
if [ ! -f ~/.claude/plugins/cache/superpowers/.claude-plugin/plugin.json ]; then
  echo "❌ Superpowers installation corrupted"
  exit 1
fi

echo "✅ Superpowers detected"
```

### Comprehensive Check (Recommended)

```bash
# Check 1: Directory exists
SUPERPOWERS_DIR="$HOME/.claude/plugins/cache/superpowers"
if [ ! -d "$SUPERPOWERS_DIR" ]; then
  echo "❌ Superpowers not installed"
  # [Print installation instructions]
  exit 1
fi

# Check 2: plugin.json exists and is valid
PLUGIN_JSON="$SUPERPOWERS_DIR/.claude-plugin/plugin.json"
if [ ! -f "$PLUGIN_JSON" ]; then
  echo "❌ Superpowers installation corrupted (plugin.json missing)"
  exit 1
fi

# Check 3: Critical skills exist
CRITICAL_SKILLS=(
  "brainstorming"
  "test-driven-development"
  "requesting-code-review"
  "using-git-worktrees"
)

MISSING_SKILLS=()
for SKILL in "${CRITICAL_SKILLS[@]}"; do
  SKILL_FILE="$SUPERPOWERS_DIR/skills/$SKILL/SKILL.md"
  if [ ! -f "$SKILL_FILE" ]; then
    MISSING_SKILLS+=("$SKILL")
  fi
done

if [ ${#MISSING_SKILLS[@]} -gt 0 ]; then
  echo "⚠️ Superpowers incomplete. Missing skills:"
  for SKILL in "${MISSING_SKILLS[@]}"; do
    echo "  - $SKILL"
  done
  exit 1
fi

echo "✅ Superpowers validated"
```

## Related Scenarios

- **validate-git-spice.md** - Similar validation for git-spice dependency
- **error-handling.md** - Tests error message quality and recovery

## Integration Points

This validation must pass before:
- Git-spice validation
- Git repository validation
- Any spectacular command execution

**Order matters:** Check superpowers first because spectacular commands may need to use superpowers skills to guide fixes for later validation failures.

## Edge Cases

### Symlinked Installation

**Scenario:** Superpowers installed via symlink

```bash
ls -la ~/.claude/plugins/cache/superpowers
# lrwxr-xr-x ... superpowers -> /path/to/superpowers-repo
```

**Expected:** Should work - follow symlink to validate

### Multiple Versions

**Scenario:** Multiple superpowers installations (cache vs local dev)

```bash
~/.claude/plugins/cache/superpowers/  # Official
~/dev/superpowers/                    # Development version
```

**Expected:** Check only `~/.claude/plugins/cache/superpowers/` (Claude Code standard location)

### Permissions Issues

**Scenario:** Superpowers exists but not readable

```bash
ls ~/.claude/plugins/cache/superpowers/
# Permission denied
```

**Expected:** Clear error about permissions, not "not found"
