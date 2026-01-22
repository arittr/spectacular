# Test Scenario: Multi-Repo Workspace Detection

## Context

**Testing:** `/spectacular:init` detection of multi-repo vs single-repo workspace.

**Setup:**

- User runs Claude from a workspace directory containing multiple git repos as subdirectories
- Each repo should have CLAUDE.md with setup commands
- Optional: docs/constitutions/current/ in each repo

**Why this scenario:**

- Multi-repo detection is foundational to all multi-repo spectacular workflows
- Detection must be reliable and consistent across all skills
- Incorrect detection causes downstream failures in spec, plan, and execute

## Expected Behavior

### Step 1: Workspace Mode Detection

The validating-environment skill runs this check:

```bash
REPO_COUNT=$(find . -maxdepth 2 -name ".git" -type d 2>/dev/null | wc -l | tr -d ' ')
if [ "$REPO_COUNT" -gt 1 ]; then
  WORKSPACE_MODE="multi-repo"
else
  WORKSPACE_MODE="single-repo"
fi
```

### Step 2: Multi-Repo Summary Output

When WORKSPACE_MODE="multi-repo", the summary should include:

- Total number of repos detected
- List of repo names
- Per-repo validation status (CLAUDE.md present, constitutions present)
- Warning if any repo missing required setup

### Step 3: Specs Directory Creation

In multi-repo mode, creates `specs/` at workspace root (not inside any repo).

## Verification Commands

```bash
# Verify WORKSPACE_MODE detection in validating-environment skill
grep -n "WORKSPACE_MODE" skills/validating-environment/SKILL.md

# Verify detection logic uses find with maxdepth 2
grep -n "find.*-maxdepth 2.*\.git" skills/validating-environment/SKILL.md

# Verify multi-repo summary section exists
grep -n "Multi-Repo Workspace Summary\|multi-repo" skills/validating-environment/SKILL.md

# Verify specs directory creation at workspace root
grep -n "specs/" skills/validating-environment/SKILL.md
```

## Evidence of PASS

- [ ] `skills/validating-environment/SKILL.md` contains WORKSPACE_MODE variable
- [ ] Detection uses `find . -maxdepth 2 -name ".git"` pattern
- [ ] Multi-repo summary section outputs detected repos
- [ ] Specs directory created at workspace root (not repo root)
- [ ] Per-repo validation checks CLAUDE.md presence

## Evidence of FAIL

- [ ] WORKSPACE_MODE variable missing or incorrectly named
- [ ] Detection pattern doesn't use maxdepth 2 (would miss repos)
- [ ] No multi-repo summary output
- [ ] Specs directory created inside a repo (wrong location)

## Test Execution

**Manual test setup:**

```bash
# Create test workspace
mkdir -p /tmp/test-workspace/{backend,frontend}
cd /tmp/test-workspace/backend && git init
cd /tmp/test-workspace/frontend && git init
cd /tmp/test-workspace

# Run init
/spectacular:init
```

**Expected output:**

```
Multi-repo workspace detected (2 repos)
Available repos: backend frontend
...
Workspace Mode: multi-repo
```

## Related Scenarios

- **validate-superpowers.md** - Validates superpowers plugin presence
- **validate-git-spice.md** - Validates git-spice installation
- **error-handling.md** - Handles missing dependencies gracefully
