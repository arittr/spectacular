---
id: bash-pattern-consistency
type: integration
severity: major
estimated_duration: 5m
requires_git_repo: false
tags: [bash-patterns, consistency, safety, orchestrator]
---

# Test Scenario: Bash Command Pattern Consistency

## Context

Testing that all bash commands in skills/commands follow safe, standardized patterns to prevent parse errors.

**Setup:**
- All skills in `skills/` directory
- All commands in `commands/` directory
- Grep analysis to extract bash patterns

**Why critical:**
- Multi-line bash without heredoc gets mis-parsed when wrapped in larger contexts
- Inconsistent patterns lead to models improvising broken commands
- Variable capture after pipes captures wrong exit code
- One standard pattern prevents entire class of syntax errors

**Real failure from NOTES.md:**
```
⏺ Bash(cd "/path/.worktrees/26db45-main" && pnpm build 2>&1 | grep -E "(Build|error)" | tail -20
     EXIT_CODE=${PIPESTATUS[0]}
     echo Exit code: $EXIT_CODE)
  ⎿  Error: Exit code 1
     tail: EXIT_CODE=: No such file or directory
     tail: echo: No such file or directory
     tail: : No such file or directory
```

**Root cause:** Variable assignment after pipes gets parsed as `tail` argument, not bash command.

## Expected Behavior

### Safe Patterns (ALLOWED)

**Pattern 1: Heredoc for multi-line commands (PREFERRED)**

```bash
bash <<'EOF'
npm test
if [ $? -ne 0 ]; then
  echo "❌ Tests failed"
  exit 1
fi

npm run lint
if [ $? -ne 0 ]; then
  echo "❌ Lint failed"
  exit 1
fi

npm run build
if [ $? -ne 0 ]; then
  echo "❌ Build failed"
  exit 1
fi
EOF
```

**Why safe:**
- Explicit bash boundaries prevent mis-parsing
- Won't be broken by orchestrator wrapping commands
- `'EOF'` prevents variable expansion issues
- Can include helpful error messages

**Pattern 2: Single-line with semicolons (ALLOWED for simple commands)**

```bash
npm test; if [ $? -ne 0 ]; then exit 1; fi
```

**Why allowed:**
- Single line = no parsing ambiguity
- Useful for very simple checks
- Legacy pattern, gradually migrate to heredoc

**When to use:**
- Only for single command with single conditional
- No error messages needed
- Prefer heredoc for consistency

### Unsafe Patterns (FORBIDDEN)

**Anti-pattern 1: Multi-line without heredoc wrapper**

```markdown
INSTRUCTIONS:

5. Run quality checks:
   npm test
   if [ $? -ne 0 ]; then
     echo "❌ Tests failed"
     exit 1
   fi
```

**Why forbidden:**
- When orchestrator constructs larger bash command, newlines break parsing
- Claude may wrap this in pipes or variable capture
- Results in `tail: echo: No such file or directory` errors

**Anti-pattern 2: Variable capture after pipes**

```bash
npm build 2>&1 | grep -E "(Build|error)" | tail -20
EXIT_CODE=$?  # ← WRONG: This is tail's exit code, not build's
echo "Build exit code: $EXIT_CODE"
```

**Why forbidden:**
- `$?` captures last command in pipe (tail), not first (build)
- Need `${PIPESTATUS[0]}` to get build exit code
- Even then, newlines after pipes cause parsing issues

**Correct approach:**
```bash
bash <<'EOF'
npm build > /tmp/build-output.txt 2>&1
BUILD_EXIT=$?

if [ $BUILD_EXIT -ne 0 ]; then
  echo "❌ Build failed"
  tail -20 /tmp/build-output.txt
  exit 1
fi
EOF
```

**Anti-pattern 3: Echo/variable assignment in pipe context**

```bash
cd "path" && command 2>&1 | grep pattern | tail -20
echo "Done"  # ← Gets parsed as tail argument, not bash command
```

**Why forbidden:**
- Commands after pipes without proper bash context get mis-parsed
- Shell thinks `echo` is an argument to `tail`
- Always use heredoc to create clear bash context

## Test Method

**Static analysis script:**

```bash
# Find all quality check commands in skills/commands
echo "=== Scanning for bash patterns in skills/ and commands/ ==="
echo ""

# Pattern 1: Find npm/pytest/cargo commands
echo "Pattern 1: Quality check commands"
grep -rn "npm test\|npm run\|pytest\|cargo test\|go test" skills/ commands/ 2>/dev/null | head -20

echo ""
echo "Pattern 2: Multi-line if statements (potential unsafe)"
grep -rn "if \[ \$? -ne 0 \]" skills/ commands/ -A 2 2>/dev/null | grep -v "^--$" | head -30

echo ""
echo "Pattern 3: Variable capture patterns"
grep -rn "EXIT_CODE=\|BUILD_EXIT=\|TEST_EXIT=" skills/ commands/ 2>/dev/null | head -20

echo ""
echo "Pattern 4: Heredoc usage (safe pattern)"
grep -rn "bash <<'EOF'" skills/ commands/ 2>/dev/null | head -20

echo ""
echo "=== Analysis ==="
echo "Safe patterns should use:"
echo "  ✅ bash <<'EOF' ... EOF (heredoc wrapper)"
echo "  ✅ Single-line with semicolons (simple commands only)"
echo ""
echo "Unsafe patterns to fix:"
echo "  ❌ Multi-line if without heredoc wrapper"
echo "  ❌ Variable capture after pipes"
echo "  ❌ Commands after pipes without bash context"
```

## Success Criteria

### Pattern Consistency
- [ ] All quality check commands in `skills/executing-sequential-phase/` use heredoc
- [ ] All quality check commands in `skills/executing-parallel-phase/` use heredoc
- [ ] Both execution skills use IDENTICAL bash pattern
- [ ] No bare multi-line if statements without heredoc wrapper

### Pattern Safety
- [ ] No variable capture after pipes (use heredoc + temp files instead)
- [ ] No echo/commands after pipes without bash context
- [ ] All heredocs use `'EOF'` (single quotes) to prevent variable expansion

### Documentation Consistency
- [ ] Commands reference the same pattern used in skills
- [ ] Test scenarios document safe patterns only
- [ ] No examples showing unsafe multi-line patterns

## Verification Commands

```bash
# Pattern 1: Find all heredoc usage (safe pattern)
echo "=== Heredoc patterns (SAFE) ==="
grep -n "bash <<'EOF'" skills/executing-sequential-phase/SKILL.md skills/executing-parallel-phase/SKILL.md

# Pattern 2: Find multi-line if statements
echo ""
echo "=== Multi-line if statements (check context) ==="
grep -n "if \[ \$? -ne 0 \]" skills/executing-sequential-phase/SKILL.md skills/executing-parallel-phase/SKILL.md -A 3

# Pattern 3: Check for variable capture after pipes (UNSAFE)
echo ""
echo "=== Variable capture patterns ==="
grep -n "EXIT_CODE=\|PIPESTATUS" skills/executing-sequential-phase/SKILL.md skills/executing-parallel-phase/SKILL.md

# Pattern 4: Check for commands after pipes (UNSAFE)
echo ""
echo "=== Commands after pipes (potential parsing issues) ==="
grep -n "| tail\|| grep" skills/executing-sequential-phase/SKILL.md skills/executing-parallel-phase/SKILL.md -A 1

# Pattern 5: Verify consistent quality check patterns
echo ""
echo "=== Quality check sections ==="
grep -n "npm test\|pytest\|cargo test" skills/executing-sequential-phase/SKILL.md skills/executing-parallel-phase/SKILL.md -B 2 -A 5
```

## Evidence of PASS

### Pattern Standardization
- [ ] Both skills use heredoc pattern: `bash <<'EOF' ... EOF`
- [ ] IDENTICAL quality check implementation in sequential and parallel skills
- [ ] All multi-line bash wrapped in heredoc (no bare multi-line if statements)
- [ ] Single quotes on EOF markers: `'EOF'` to prevent variable expansion

### Unsafe Pattern Elimination
- [ ] NO variable capture after pipes (`EXIT_CODE=${PIPESTATUS[0]}`)
- [ ] NO echo/commands after pipes without bash context
- [ ] NO multi-line if statements outside heredoc wrapper
- [ ] All exit code checks use `$?` immediately after command

### Documentation Quality
- [ ] Pattern includes explanatory comment: "Why heredoc: Prevents parsing errors"
- [ ] Error messages included for debugging: `echo "❌ Tests failed"`
- [ ] Each quality check (test, lint, build) has own if block
- [ ] Consistent formatting between sequential and parallel skills

### Verification Success
- [ ] `grep "bash <<'EOF'"` finds matches in both skills
- [ ] No `PIPESTATUS` or variable capture after pipes found
- [ ] All if statements are within heredoc blocks
- [ ] Sequential and parallel skills show identical patterns

## Evidence of FAIL

### Unsafe Patterns Detected
- [ ] Multi-line if statements found outside heredoc wrapper
- [ ] Variable capture after pipes: `EXIT_CODE=${PIPESTATUS[0]}`
- [ ] Commands after pipes without bash context
- [ ] Echo statements in pipe chains

### Inconsistency Detected
- [ ] Sequential skill uses different pattern than parallel skill
- [ ] Single-line pattern in one skill, multi-line in another
- [ ] Missing heredoc wrapper in one or both skills
- [ ] Different error messages or formatting

### Documentation Issues
- [ ] Missing explanatory comments about heredoc usage
- [ ] No error messages for debugging
- [ ] Unclear which pattern is "correct"
- [ ] Examples show unsafe patterns

### Verification Failures
- [ ] `grep "bash <<'EOF'"` returns no matches or only one skill
- [ ] `grep "PIPESTATUS"` finds unsafe variable capture
- [ ] Quality check patterns differ between skills
- [ ] Parsing errors when orchestrator wraps commands

## Files to Check

**Skills (highest priority):**
- `skills/executing-sequential-phase/SKILL.md` - Quality check step
- `skills/executing-parallel-phase/SKILL.md` - Quality check step

**Commands:**
- `commands/execute.md` - Step 3 verification commands

**Test scenarios (should document safe patterns only):**
- `tests/scenarios/execute/quality-check-failure.md`
- `tests/scenarios/execute/sequential-stacking.md`

## Expected Test Results

### RED Phase (Current State)

**Execute grep analysis above, should find:**

1. ✅ `skills/executing-sequential-phase/SKILL.md` - Single-line pattern (safe)
   ```
   npm test; if [ $? -ne 0 ]; then exit 1; fi
   ```

2. ❌ `skills/executing-parallel-phase/SKILL.md` - Multi-line without heredoc (UNSAFE)
   ```
   npm test
   if [ $? -ne 0 ]; then
     echo "❌ Tests failed"
     exit 1
   fi
   ```

3. ⚠️ Different patterns between sequential and parallel (INCONSISTENT)

**Test verdict: FAIL** - Unsafe multi-line pattern found, inconsistent between skills

### GREEN Phase (After Fix)

**After fixing all skills to use heredoc:**

1. ✅ `skills/executing-sequential-phase/SKILL.md` - Heredoc pattern
2. ✅ `skills/executing-parallel-phase/SKILL.md` - IDENTICAL heredoc pattern
3. ✅ No multi-line if statements without heredoc wrapper
4. ✅ Consistent pattern across all skills

**Test verdict: PASS** - All bash patterns use safe, standardized heredoc

## Real-World Impact

**Without standardization (current state):**
- Sequential skill teaches single-line pattern
- Parallel skill teaches multi-line pattern
- Model sees both, chooses randomly
- Orchestrator wraps chosen pattern in pipes → syntax error
- Burns time/context with re-dos

**With standardization (after fix):**
- All skills teach heredoc pattern
- Model learns one safe approach
- Heredoc isolates commands from orchestrator wrapping
- No syntax errors from parsing ambiguity
- Reliable, predictable execution

## Implementation Notes

**When fixing skills:**

1. Replace all quality check sections with standard heredoc
2. Use identical wording in both sequential and parallel skills
3. Include error messages (helpful for debugging)
4. Add comment explaining why heredoc is required

**Standard template:**
```markdown
5. Run quality checks with exit code validation:

   **CRITICAL**: Use heredoc to prevent bash parsing errors:

   ```bash
   bash <<'EOF'
   npm test
   if [ $? -ne 0 ]; then
     echo "❌ Tests failed"
     exit 1
   fi

   npm run lint
   if [ $? -ne 0 ]; then
     echo "❌ Lint failed"
     exit 1
   fi

   npm run build
   if [ $? -ne 0 ]; then
     echo "❌ Build failed"
     exit 1
   fi
   EOF
   ```

   **Why heredoc**: Prevents parsing errors when commands are wrapped by orchestrator.
```
