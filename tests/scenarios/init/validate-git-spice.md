# Test Scenario: Validate Git-Spice

## Context

Testing `/spectacular:init` command's ability to detect and validate git-spice installation and configuration.

**Setup:**
- System may or may not have git-spice installed
- If installed, repository may or may not be initialized for git-spice
- git-spice version may or may not be compatible

**Purpose:**
- Verify git-spice CLI is installed and in PATH
- Check git-spice version compatibility
- Validate git-spice repository initialization
- Provide clear installation/configuration guidance

## Expected Behavior

### Case 1: Git-Spice Installed and Repository Initialized

**Detection:**
```bash
# Check 1: Command exists in PATH
command -v gs
# Expected: /path/to/gs (e.g., /usr/local/bin/gs)

# Check 2: Version check
gs --version
# Expected: git-spice version 0.x.x or higher

# Check 3: Repository initialized
gs repo init --check 2>&1
# Expected: "Repository already initialized" or exit code 0

# Or alternative:
git config --get spice.submit.publishTo
# Expected: Value exists (e.g., "github" or "gitlab")
```

**Expected output:**
```
✅ git-spice installed
✅ Version: 0.x.x
✅ Repository initialized for git-spice
```

### Case 2: Git-Spice Not Installed

**Detection:**
```bash
command -v gs
# Exit code 1 (command not found)
```

**Expected output:**
```
❌ git-spice not installed

Spectacular requires git-spice for stacked branch management.

To install git-spice:

**macOS (Homebrew):**
brew install abhinav/tap/git-spice

**Linux:**
curl -fsSL https://github.com/abhinav/git-spice/releases/latest/download/install.sh | sh

**Manual install:**
Visit: https://github.com/abhinav/git-spice/releases
Download the binary for your platform and add to PATH

After installing, run /spectacular:init again.
```

**Action:** Stop initialization

### Case 3: Git-Spice Installed, Repository Not Initialized

**Detection:**
```bash
# Command exists
command -v gs  # Success

# But repository not initialized
gs repo init --check 2>&1
# Exit code 1 or "not initialized" message
```

**Expected output:**
```
✅ git-spice installed (version 0.x.x)
⚠️ Current repository not initialized for git-spice

Initializing git-spice for this repository...
```

**Action:**
```bash
# Auto-initialize
gs repo init

# Verify
gs repo init --check
```

**Follow-up output:**
```
✅ Repository initialized for git-spice

You can now use spectacular commands:
- /spectacular:spec - Create feature specification
- /spectacular:plan - Decompose into tasks
- /spectacular:execute - Run implementation
```

### Case 4: Git-Spice Version Too Old

**Detection:**
```bash
gs --version
# Expected format: git-spice version 0.5.0
# Extract version number and compare

VERSION=$(gs --version | grep -oE '[0-9]+\.[0-9]+\.[0-9]+')
# If VERSION < 0.4.0, warn
```

**Expected output:**
```
⚠️ git-spice version 0.3.0 detected
⚠️ Spectacular requires git-spice >= 0.4.0

Some features may not work correctly with older versions.

To upgrade:

**macOS (Homebrew):**
brew upgrade git-spice

**Manual:**
Visit: https://github.com/abhinav/git-spice/releases/latest
Download and replace existing installation

After upgrading, run /spectacular:init again.
```

## Failure Modes

### Issue 1: False Positive (Command Exists But Wrong)

**Symptom:** `gs` command exists but it's not git-spice (e.g., GhostScript)

**Detection:**
```bash
# Check version output format
gs --version 2>&1 | grep -q "git-spice"
# If this fails, it's not git-spice
```

**Prevention:**
```bash
# Validate it's actually git-spice
if command -v gs >/dev/null 2>&1; then
  if ! gs --version 2>&1 | grep -q "git-spice"; then
    echo "❌ Found 'gs' command but it's not git-spice"
    echo "Detected: $(gs --version 2>&1 | head -1)"
    exit 1
  fi
fi
```

### Issue 2: Auto-Initialize Fails

**Symptom:** Repository initialization attempted but fails

**Root Cause:** No git remote, or git-spice configuration conflicts

**Expected behavior:**
```bash
gs repo init
# If fails:
echo "⚠️ Could not auto-initialize git-spice"
echo "Error: $(gs repo init 2>&1)"
echo ""
echo "Please run manually: gs repo init"
echo "And follow the prompts to configure."
```

**Don't:** Silently fail and claim initialization succeeded

### Issue 3: Permissions/PATH Issues

**Symptom:** git-spice installed but not in PATH

**Detection:**
```bash
# Check common install locations
if [ -f /usr/local/bin/gs ]; then
  echo "⚠️ git-spice found at /usr/local/bin/gs but not in PATH"
  echo "Add to PATH: export PATH=\"/usr/local/bin:\$PATH\""
fi
```

**Help user debug PATH issues**

### Issue 4: Repository Not a Git Repo

**Symptom:** Try to check git-spice repo init, but not in git repo

**Expected error:**
```
❌ Not a git repository

Spectacular requires a git repository to function.

To initialize git:
cd /path/to/your/project
git init
git add .
git commit -m "Initial commit"

Then run /spectacular:init again.
```

## Success Criteria

### Detection
- [ ] Correctly identifies git-spice installed vs not installed
- [ ] Distinguishes git-spice from other `gs` commands
- [ ] Checks version compatibility
- [ ] Detects repository initialization status

### Auto-Configuration
- [ ] Auto-initializes repository if git-spice installed but repo not initialized
- [ ] Initialization succeeds without user intervention
- [ ] Clear error if auto-initialization fails

### Error Messages
- [ ] Platform-specific installation instructions
- [ ] Links to official documentation
- [ ] Clear next steps
- [ ] No assumed technical knowledge

### User Experience
- [ ] Installation instructions match user's OS
- [ ] After installing git-spice, init succeeds
- [ ] No confusing error messages
- [ ] Progress clearly indicated

## Test Execution

### Test Case 1: Clean System (git-spice not installed)

```bash
# Setup: Rename git-spice temporarily
sudo mv /usr/local/bin/gs /usr/local/bin/gs.backup 2>/dev/null || true

# Test
/spectacular:init

# Expected: Installation instructions, init stops

# Cleanup
sudo mv /usr/local/bin/gs.backup /usr/local/bin/gs 2>/dev/null || true
```

### Test Case 2: Fresh Repository (git-spice installed, repo not initialized)

```bash
# Setup: Create new git repo
mkdir /tmp/test-spectacular-init
cd /tmp/test-spectacular-init
git init

# Test
/spectacular:init

# Expected:
# ✅ git-spice installed
# ⚠️ Initializing repository...
# ✅ Repository initialized

# Verify
gs repo init --check  # Should succeed

# Cleanup
cd .. && rm -rf /tmp/test-spectacular-init
```

### Test Case 3: Fully Configured Repository

```bash
# Setup: Repository already initialized
cd /path/to/existing/project
gs repo init --check  # Already initialized

# Test
/spectacular:init

# Expected:
# ✅ git-spice installed
# ✅ Repository initialized
# Proceeds to next validation
```

### Test Case 4: Wrong `gs` Command

```bash
# Setup: Create fake gs that's not git-spice
cat > /tmp/fake-gs << 'EOF'
#!/bin/bash
echo "GhostScript 9.50"
EOF
chmod +x /tmp/fake-gs
export PATH="/tmp:$PATH"

# Test
/spectacular:init

# Expected: Error that gs is not git-spice

# Cleanup
rm /tmp/fake-gs
```

## Validation Logic

### Comprehensive Check

```bash
# Step 1: Check command exists
if ! command -v gs >/dev/null 2>&1; then
  echo "❌ git-spice not installed"
  # [Print installation instructions for detected OS]
  exit 1
fi

# Step 2: Verify it's actually git-spice
if ! gs --version 2>&1 | grep -q "git-spice"; then
  echo "❌ 'gs' command found but it's not git-spice"
  echo "Found: $(gs --version 2>&1 | head -1)"
  exit 1
fi

# Step 3: Check version
VERSION=$(gs --version 2>&1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)
echo "✅ git-spice version $VERSION"

# Step 4: Check repository initialization
if ! git rev-parse --git-dir >/dev/null 2>&1; then
  echo "❌ Not a git repository"
  # [Print git init instructions]
  exit 1
fi

if ! gs repo init --check >/dev/null 2>&1; then
  echo "⚠️ Repository not initialized for git-spice"
  echo "Initializing..."

  if gs repo init; then
    echo "✅ Repository initialized"
  else
    echo "❌ Auto-initialization failed"
    echo "Please run: gs repo init"
    exit 1
  fi
else
  echo "✅ Repository already initialized for git-spice"
fi
```

## Platform-Specific Installation Instructions

### macOS
```markdown
**Using Homebrew:**
brew install abhinav/tap/git-spice

**Using curl:**
curl -fsSL https://github.com/abhinav/git-spice/releases/latest/download/install.sh | sh
```

### Linux
```markdown
**Using install script:**
curl -fsSL https://github.com/abhinav/git-spice/releases/latest/download/install.sh | sh

**Manual installation:**
1. Visit: https://github.com/abhinav/git-spice/releases/latest
2. Download: git-spice_linux_amd64.tar.gz (or appropriate variant)
3. Extract: tar -xzf git-spice_linux_amd64.tar.gz
4. Move to PATH: sudo mv gs /usr/local/bin/
5. Verify: gs --version
```

### Windows
```markdown
**Using install script (PowerShell):**
iwr -useb https://github.com/abhinav/git-spice/releases/latest/download/install.ps1 | iex

**Manual installation:**
1. Visit: https://github.com/abhinav/git-spice/releases/latest
2. Download: git-spice_windows_amd64.zip
3. Extract gs.exe
4. Add to PATH
5. Verify: gs --version
```

## Related Scenarios

- **validate-superpowers.md** - Similar validation for superpowers dependency
- **error-handling.md** - Tests error message quality
- All spectacular commands depend on git-spice being installed

## Edge Cases

### Git-Spice Installed via Different Method

**Scenario:** User installed git-spice from source, not pre-built binary

**Expected:** Should still detect via `command -v gs` and version check

### Multiple Git-Spice Versions

**Scenario:** Multiple `gs` binaries in PATH

```bash
/usr/local/bin/gs  # v0.5.0
~/bin/gs           # v0.4.0 (older)
```

**Expected:** Uses first in PATH, warns if version too old

### Repository Partially Initialized

**Scenario:** Some git-spice config exists but incomplete

**Expected:** `gs repo init` should handle gracefully (update config, not error)
