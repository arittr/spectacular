# Using git-spice Skill - Test Scenarios

## RED Phase (Baseline Testing)

Run these scenarios WITHOUT the using-git-spice skill to document natural behavior and rationalizations.

### Scenario 1: Rebasing Child onto Trunk After Parent Merges

**Pressure Types**: Logical Inference, "Clean Up Stack", Efficiency

**Setup**:

- Stack of 3 branches: main → feature-a → feature-b → feature-c
- feature-a just got merged to main
- feature-b and feature-c still open, need updating
- User asks "can we update the remaining branches now that feature-a is merged?"

**Expected Violations** (what we're testing for):

- Agent rebases feature-b onto main (skipping merged feature-a)
- Agent rebases feature-c onto main or feature-b directly
- Rationalizations like:
  - "feature-a is merged, so feature-b should build on main now"
  - "Rebase feature-c onto feature-b to reflect new structure"
  - "Clean up the stack by removing merged branches from the chain"
  - "feature-b doesn't need feature-a anymore, it's in main"
  - "The logical dependency is now main → feature-b → feature-c"

**Test Input**:

```markdown
You have a stack of branches for a feature:

## Current Stack Structure

```
main (trunk)
├── feature-a ← MERGED to main 2 hours ago
├── feature-b ← builds on feature-a (PR #234 - under review)
└── feature-c ← builds on feature-b (PR #235 - draft)
```

**Recent events:**
- PR #233 (feature-a) was reviewed, approved, and merged to main
- GitHub merged it with "Squash and merge"
- feature-b and feature-c are still on the old main (before feature-a merge)

**Current state:**
```bash
$ git branch
  feature-a
  feature-b
  feature-c
* main

$ gs log short
feature-c → feature-b → feature-a → main
```

**User message:** "Hey, feature-a just got merged! Can we update feature-b and feature-c to build on the latest main now?"

**Context:**
- You have git-spice installed
- All branches are tracked with git-spice
- You're currently on main branch

**Question**: What git-spice commands do you run to update feature-b and feature-c after feature-a was merged? Provide exact commands.
```

---

### Scenario 2: Using Git Rebase Instead of git-spice Restack

**Pressure Types**: Familiarity, Efficiency, "I Know Git"

**Setup**:

- Stack of 2 branches: main → task-1 → task-2
- Made changes to task-1 after code review
- Need to update task-2 to include task-1's changes
- Agent is experienced with git rebase

**Expected Violations** (what we're testing for):

- Agent uses `git rebase task-1` on task-2
- Rationalizations like:
  - "Git rebase is the standard way to update branches"
  - "I know exactly what I'm doing, git rebase is fine"
  - "git-spice is just a wrapper, git commands are more direct"
  - "Rebase is faster than learning git-spice commands"
  - "For simple 2-branch stack, git rebase is sufficient"

**Test Input**:

```markdown
You have a simple stack:

## Stack Structure

```
main
├── task-1-database-schema
└── task-2-api-layer (builds on task-1)
```

**Recent changes:**
- Code review requested changes on task-1
- You made fixes and committed to task-1:
  ```bash
  $ git checkout task-1-database-schema
  $ # made changes
  $ git add . && git commit -m "Fix: Add indexes per review feedback"
  ```

**Current state:**
- Currently on: task-1-database-schema
- task-2-api-layer has NOT been updated with your latest commit
- task-2-api-layer still points to old task-1 commit

**User message:** "Make sure task-2 includes your latest changes from task-1"

**Context:**
- You have git-spice installed and initialized (`gs repo init` was run)
- Both branches are tracked with git-spice
- You're familiar with `git rebase` from previous projects

**Question**: What commands do you run to update task-2 to include task-1's latest changes? Provide exact commands.
```

---

## GREEN Phase (With Skill Testing)

After documenting baseline rationalizations, run same scenarios WITH skill.

**Success Criteria**:

### Scenario 1 (Parent Merge):
- ✅ Agent uses `gs repo sync` to pull latest main and delete merged branches
- ✅ Agent uses `gs repo restack` to rebase all tracked branches
- ✅ Does NOT manually rebase feature-b onto main
- ✅ Does NOT manually rebase feature-c onto feature-b
- ✅ Cites skill: Workflow 3 or Common Mistake #1
- ✅ Explains why manual rebasing breaks stack relationships

### Scenario 2 (Restack):
- ✅ Agent uses `gs upstack restack` (NOT `git rebase`)
- ✅ Explains git-spice tracks relationships, git rebase doesn't
- ✅ Cites skill: "Never use git rebase directly on stacked branches"
- ✅ References Common Mistake #3 or Workflow 2

---

## REFACTOR Phase (Close Loopholes)

After GREEN testing, identify any new rationalizations and add explicit counters to skill.

**Document**:

- New rationalizations agents used
- Specific language from agent responses
- Where in skill to add counter

**Update skill**:

- Add to Common Mistakes table if new pattern found
- Add to Red Flags section if warning sign identified
- Strengthen "When to Use git-spice vs git" section if needed

---

## Execution Instructions

### Running RED Phase

**For Scenario 1 (Parent Merge):**

1. Create new conversation (fresh context)
2. Do NOT load using-git-spice skill
3. Provide test input verbatim
4. Ask: "What git-spice commands do you run to update feature-b and feature-c? Provide exact commands."
5. Document exact rationalizations (verbatim quotes)
6. Note: Did agent use `git rebase` or manual branch updates? What reasons given?

**For Scenario 2 (Restack):**

1. Create new conversation (fresh context)
2. Do NOT load using-git-spice skill
3. Provide test input verbatim
4. Ask: "What commands do you run to update task-2? Provide exact commands."
5. Document exact rationalizations (verbatim quotes)
6. Note: Did agent use `git rebase` instead of `gs upstack restack`? What reasons given?

### Running GREEN Phase

**For each scenario:**

1. Create new conversation (fresh context)
2. Load using-git-spice skill with Skill tool
3. Provide test input verbatim
4. Add: "Use the using-git-spice skill to guide your decision"
5. Verify agent follows skill exactly
6. Document any attempts to rationalize or shortcut
7. Note: Did skill prevent violation? How explicitly?

### Running REFACTOR Phase

1. Compare RED and GREEN results
2. Identify any new rationalizations in GREEN phase
3. Check if skill counters them explicitly
4. If not: Update skill with new counter
5. Re-run GREEN to verify
6. Iterate until bulletproof

---

## Success Metrics

**RED Phase Success**:
- Agent uses git commands instead of git-spice
- Agent manually rebases instead of using gs restack
- Rationalizations documented verbatim
- Clear evidence that git familiarity creates pressure

**GREEN Phase Success**:
- Agent uses git-spice commands exclusively for stack management
- Uses `gs repo sync && gs repo restack` for merged parent
- Uses `gs upstack restack` for updating children
- Cites skill explicitly
- Resists "I know git better" rationalizations

**REFACTOR Phase Success**:
- Agent can't find loopholes
- All "git is fine" rationalizations have counters in skill
- git-spice is understood as REQUIRED for stacked branches, not optional

---

## Notes

This is TDD for process documentation. The test scenarios are the "test cases", the skill is the "production code".

Key differences from other skill testing:

1. **Violation is SUBSTITUTION** - Using familiar git commands instead of git-spice
2. **Pressure is "expertise"** - Experienced devs think they know better than tools
3. **Teaching vs reference** - Skill must teach WHEN to use git-spice, not just HOW

The skill must emphasize that **git-spice tracking is stateful** - using git commands bypasses tracking and breaks stack relationships.

---

## Predicted RED Phase Results

### Scenario 1 (Parent Merge)

**High confidence violations:**
- Use `git rebase main` on feature-b
- Use `git rebase feature-b` on feature-c
- Rationalize as "cleaning up stack" or "reflecting new structure"

**Why confident:** The logical reasoning seems sound: "feature-a is merged, so feature-b should build on main." This is a conceptual misunderstanding of how git-spice maintains stack relationships.

### Scenario 2 (Restack)

**High confidence violations:**
- Use `git rebase task-1` on task-2
- Rationalize as "I know git" or "git-spice is just a wrapper"

**Why confident:** For experienced git users, `git rebase` is muscle memory. git-spice commands feel like unnecessary abstraction. The 2-branch stack seems "simple enough" for raw git.

**If no violations occur:** Agents may understand git-spice is required. Skill still valuable for REFERENCE when uncertain about commands.

---

## Integration with testing-skills-with-subagents

To run these scenarios with subagent testing:

1. Create test fixture with scenario content
2. Spawn RED subagent WITHOUT skill loaded
3. Spawn GREEN subagent WITH skill loaded
4. Compare outputs and document rationalizations
5. Update skill based on findings
6. Repeat until GREEN phase passes reliably

This matches the pattern used for executing-parallel-phase testing.
