# Mandatory Patterns

## Core Principle

**Skills are load-bearing process documentation.** When Claude executes a skill, it's not following suggestions - it's running code. Poor skills = broken workflows.

Therefore: **Use metaskills from superpowers to create/edit spectacular skills.** Metaskills enforce rigor that prevents rationalization.

## Pattern 1: RED-GREEN-REFACTOR for Skills

**Rule:** ALWAYS use RED-GREEN-REFACTOR approach when creating or editing skills.

### The Process

1. **RED Phase - Create failing test**
   - Use `testing-skills-with-subagents` to create pressure scenario
   - Run baseline WITHOUT the skill (or with old version)
   - Document specific failures: what shortcuts did Claude take? Where did it rationalize?

2. **GREEN Phase - Write skill to address failures**
   - Use `writing-skills` metaskill to create/edit skill
   - Write strict rules targeting the observed rationalization patterns
   - Include rationalization table with ACTUAL rationalizations from RED phase

3. **REFACTOR Phase - Close loopholes**
   - Re-run test scenario with new skill
   - If Claude still rationalizes, identify NEW rationalization patterns
   - Tighten rules to prevent them
   - Iterate until skill is bulletproof

### Why This Matters

Claude is an AI that **will rationalize away inconvenient rules**. Examples:
- "This task is simple, so I'll skip brainstorming"
- "The user was specific, so TDD would be overkill"
- "I remember the pattern, no need to read the skill"

RED-GREEN-REFACTOR forces you to observe ACTUAL rationalization in practice, then write rules that prevent it. Without this, skills become vague suggestions.

### Example

**Scenario:** Creating a skill for "always validate input before processing"

**❌ Wrong approach (no RED phase):**
```markdown
## Rule
Always validate input before processing it.
```

**✅ Right approach (RED-GREEN-REFACTOR):**

**RED:** Run test scenario where subagent processes invalid input
- Observe: Subagent skips validation because "input comes from trusted source"
- Observe: Subagent adds validation after bug occurs, not before

**GREEN:** Write skill with specific rules:
```markdown
## Rule
BEFORE writing ANY processing logic, write validation logic that rejects invalid input.

**Rationalization Table:**
| Rationalization | Why It's Wrong | What to Do Instead |
|----------------|----------------|-------------------|
| "Input comes from trusted source" | Even trusted sources can have bugs | Write validation first, always |
| "I'll add validation after tests pass" | Tests won't catch all edge cases | Validation before processing, no exceptions |
```

**REFACTOR:** Re-run test, observe subagent now validates first

## Pattern 2: Use Superpowers Metaskills (Mandatory)

**Rule:** ALWAYS use superpowers metaskills when creating or editing spectacular skills/commands.

### Required Metaskills

#### `writing-skills` - For all skill creation/editing
**When:** Creating new skill, editing existing skill, fixing broken skill

**Why:** This skill enforces superpowers format, ensures rationalization tables, adds TodoWrite checklists

**How to invoke:**
```
Use the writing-skills metaskill from superpowers
```

**Anti-pattern:**
- ❌ "I remember the format, I'll write the skill directly"
- ❌ "Just a small edit, no need for writing-skills"
- ❌ "I read the skill template, I can do it myself"

**Why mandatory:** Every skill needs rationalization tables, TodoWrite checklists, and superpowers format. writing-skills ensures you don't miss these.

#### `testing-skills-with-subagents` - For all skill validation
**When:** After creating/editing skill, before considering it complete

**Why:** This is the RED-GREEN-REFACTOR testing harness. It runs subagents through pressure scenarios to find rationalization patterns.

**How to invoke:**
```
Use the testing-skills-with-subagents metaskill from superpowers to validate this skill
```

**Anti-pattern:**
- ❌ "The skill looks good, I'll skip testing"
- ❌ "Manual testing is enough"
- ❌ "I'll test it when someone reports a bug"

**Why mandatory:** You cannot predict how Claude will rationalize. Only pressure testing reveals the patterns.

#### `brainstorming` - For all new features
**When:** User requests new command/skill, before writing spec or code

**Why:** Ensures design is fully formed before implementation starts

**How to invoke:**
```
Use the brainstorming skill from superpowers to refine this idea
```

**Anti-pattern:**
- ❌ "The request is specific enough, no need to brainstorm"
- ❌ "Brainstorming would slow us down"
- ❌ "I understand what they want, let's just build it"

**Why mandatory:** Even specific requests have hidden assumptions. Brainstorming surfaces them BEFORE you write code.

### Workflow Enforcement

**Creating a new skill:**
```
1. Use brainstorming skill (if idea needs refinement)
2. Use writing-skills metaskill to create initial version
3. Use testing-skills-with-subagents to find rationalization patterns (RED)
4. Use writing-skills to add rationalization table (GREEN)
5. Use testing-skills-with-subagents again to verify (REFACTOR)
6. Iterate until bulletproof
```

**Editing an existing skill:**
```
1. Read current version
2. Use writing-skills metaskill to make changes
3. Use testing-skills-with-subagents to verify no regressions
4. If new rationalizations appear, use writing-skills to address them
5. Re-test until solid
```

**Creating a new command:**
```
1. Use brainstorming skill to refine workflow
2. Draft command referencing existing skills
3. Test command in sample project
4. If behavior is wrong, update skills (using metaskills)
```

## Pattern 3: Rationalization Tables (Mandatory)

**Rule:** Every skill with strict rules MUST have a rationalization table.

### Format

```markdown
## Rationalization Table

| Rationalization | Why It's Wrong | What to Do Instead |
|----------------|----------------|-------------------|
| {Excuse Claude might use} | {Why that excuse doesn't hold} | {Correct action} |
```

### How to Populate

1. Use RED phase of testing-skills-with-subagents
2. Observe what shortcuts Claude takes
3. Document those as "Rationalization" column
4. Add "Why It's Wrong" and "What to Do Instead"

### Example: TDD Skill

From superpowers `test-driven-development` skill:

| Rationalization | Why It's Wrong | What to Do Instead |
|----------------|----------------|-------------------|
| "The test is obvious, I'll write code first" | Test is only obvious because you know the solution | Write test first anyway, even if "obvious" |
| "User gave specific instructions" | Specific instructions = WHAT to do, not permission to skip TDD | Write test first. Specific requirements make this easier, not optional |

**Why mandatory:** Without rationalization table, Claude will find the loophole. Document the loophole first, then it can't be exploited.

## Pattern 4: TodoWrite for Checklists (Mandatory)

**Rule:** If a skill has sequential steps, it MUST require TodoWrite.

### When Required

- Skill has 3+ sequential steps
- Skill has critical steps that must not be skipped
- Skill has validation checkpoints

### How to Enforce

Add instruction in "The Process" section:

```markdown
## The Process

**BEFORE starting, create TodoWrite todos for each step.**

1. Step one
2. Step two
3. Step three
...
```

### Why Mandatory

Claude will skip steps if they're not tracked. TodoWrite makes skipping visible.

**Example from versioning-constitutions:**
```markdown
## Quality Checklist

Before updating symlink:
- [ ] New version directory exists at `docs/constitutions/v{N}/`
- [ ] All 6 files present (meta, architecture, patterns, tech-stack, schema-rules, testing)
- [ ] `meta.md` has correct version number and changelog
...
```

Then require: "Use TodoWrite to track this checklist."

## Pattern 5: Evidence Before Assertions

**Rule:** Never claim work is complete without running verification commands.

This is superpowers `verification-before-completion` skill - use it.

**Anti-pattern:**
- ❌ "The skill looks good" (did you test it?)
- ❌ "I fixed the bug" (did you run the failing test?)
- ❌ "All tests pass" (show me the output)

**Right approach:**
```bash
# Run verification
npm test

# Show output
# [paste output]

# Only THEN claim "tests pass"
```

**Why mandatory:** Claude will claim success based on code correctness, not actual execution. Require evidence.

## Pattern 6: Announce Skill Usage

**Rule:** Every skill MUST include an "Announce:" instruction.

### Format

```markdown
**Announce:** "I'm using {skill-name} to {purpose}."
```

### Example

From `writing-specs`:
```markdown
**Announce:** "I'm using writing-specs to create the feature specification."
```

### Why Mandatory

1. **Transparency:** User knows what process is running
2. **Verification:** Claude must read skill to announce it (prevents "I remember" shortcut)
3. **Debugging:** When things go wrong, you can see which skill was (or wasn't) used

**Anti-pattern:**
- ❌ Making announcement optional ("Optionally announce...")
- ❌ Skipping announcement for "simple" skills

**Right approach:** EVERY skill has mandatory announcement. No exceptions.

## Pattern 7: No Softening Rules

**Rule:** Do NOT make rules "easier" or "more flexible" to reduce friction.

### The Temptation

When testing reveals a skill is "too strict" or "annoying":
- "Maybe we can make this optional..."
- "Could we relax this rule for simple cases..."
- "What if we add an escape hatch..."

### Why This Is Wrong

**Friction is the point.** Strict rules prevent bugs. Softening rules = reintroducing bugs.

**Example:**

**Tempting change:**
```markdown
Use writing-skills metaskill when creating complex skills (simple skills can be written directly)
```

**Why this is wrong:**
- Who defines "complex"? Claude will rationalize that every skill is "simple"
- "Simple" skills still need rationalization tables and TodoWrite checklists
- Loophole = guaranteed shortcuts

**Right approach:**
```markdown
ALWAYS use writing-skills metaskill when creating or editing skills. No exceptions.
```

### When to Soften (Rarely)

Only soften if:
1. Rule is causing false positives (prevents valid work)
2. AND you have RED-GREEN-REFACTOR test showing better rule works
3. AND rationalization table documents why old rule was wrong

**Process:**
1. Document the problem with current rule
2. Propose new rule
3. Test new rule with testing-skills-with-subagents
4. Verify it's actually better (not just easier)
5. Update skill using writing-skills metaskill

## Summary: Mandatory Workflow

**For ALL spectacular skill/command work:**

1. ✅ Use `brainstorming` if design unclear
2. ✅ Use `writing-skills` to create/edit skills
3. ✅ Use `testing-skills-with-subagents` to validate (RED-GREEN-REFACTOR)
4. ✅ Include rationalization tables based on observed behavior
5. ✅ Require TodoWrite for sequential steps
6. ✅ Require "Announce:" instruction in every skill
7. ✅ Do NOT soften rules without RED-GREEN-REFACTOR validation

**Violating these patterns = skills that don't work under pressure.**
