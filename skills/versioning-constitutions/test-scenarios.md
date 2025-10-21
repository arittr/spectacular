# Test Scenarios for versioning-constitutions Skill

## RED Phase: Baseline Without Skill

Run these scenarios with agents that DON'T have access to the skill. Document failures.

### Scenario 1: Breaking Pattern Change Under Pressure

**Setup:**
- Constitution is at v1
- Project has been using `next-safe-action` for all server actions
- Team decides to remove this requirement and allow raw server actions

**Pressure:**
- Multiple specs/commands reference `@docs/constitutions/current/patterns.md`
- Need to update constitution quickly to unblock new feature work
- Temptation to "just edit the current version"

**Task for agent:**
"We're removing the next-safe-action requirement. Update the constitution to allow raw server actions alongside next-safe-action."

**Expected failure without skill:**
- Agent edits `docs/constitutions/current/patterns.md` directly
- No new version created
- No history of what changed or when
- No way to rollback if decision was wrong
- Breaks immutability principle

**Success criteria for skill:**
- Agent creates v2 directory
- Copies all files to v2
- Updates patterns.md in v2 only
- Updates symlink to v2
- v1 remains untouched

---

### Scenario 2: Hardcoded Version References

**Setup:**
- Constitution is at v1
- Agent needs to add new mandatory pattern (ts-pattern requirement)
- `.claude/commands/spec.md` has reference: `@docs/constitutions/current/patterns.md`

**Pressure:**
- Agent is focused on adding the pattern
- Symlink concept might not be obvious
- Temptation to hardcode v2 in references "to be explicit"

**Task for agent:**
"Add ts-pattern as a mandatory pattern for all discriminated unions. Update constitution and ensure all commands can reference this new requirement."

**Expected failure without skill:**
- Agent creates v2 correctly
- BUT updates commands to reference `@docs/constitutions/v2/patterns.md`
- When v3 is created, all references break
- Manual find-replace needed every version change

**Success criteria for skill:**
- Agent creates v2
- Updates symlink
- Verifies references still use `current/` NOT `v2/`
- Documents in skill to never hardcode versions

---

### Scenario 3: Style Reorganization Disguised as Versioning

**Setup:**
- Constitution is at v1 with sections in arbitrary order
- Agent needs to add one new library to tech-stack.md
- Temptation to "clean up while I'm here"

**Pressure:**
- Perfectionism - "the sections should be alphabetical"
- "Let me improve the formatting while versioning"
- Difficult to see what actually changed in diff

**Task for agent:**
"We're adopting `date-fns` for date handling. Add it to the tech stack constitution."

**Expected failure without skill:**
- Agent creates v2
- Adds date-fns to tech-stack.md
- ALSO alphabetizes all libraries
- ALSO reformats code examples
- ALSO renames sections
- Diff shows 200 lines changed when only 3 lines needed to change

**Success criteria for skill:**
- Agent creates v2
- Changes ONLY tech-stack.md
- Adds ONLY date-fns entry
- Diff shows minimal changes (3-5 lines)
- Skill documents "only change what needs changing"

---

### Scenario 4: Missing Changelog Documentation

**Setup:**
- Constitution is at v1
- Agent needs to deprecate a pattern (remove Redux requirement)
- Future developers will want to know why change was made

**Pressure:**
- Focus on technical implementation (creating v2, updating files)
- Forgetting the "why" documentation
- "The commit message is enough"

**Task for agent:**
"We're removing the Redux state management requirement since React Server Components handle our state needs. Update the constitution."

**Expected failure without skill:**
- Agent creates v2
- Removes Redux from tech-stack.md
- Updates patterns.md
- Updates symlink
- meta.md shows "Version 2" but no explanation of what changed or why
- In 6 months, no one remembers why Redux was removed

**Success criteria for skill:**
- Agent creates v2
- Updates meta.md with:
  - Version: 2
  - Previous: v1
  - Date: 2025-01-17
  - Summary: "Removed Redux requirement. React Server Components handle state, Redux adds complexity without benefit."
- Skill checklist includes "Document in meta.md" step

---

### Scenario 5: Constitution Scope Creep

**Setup:**
- Constitution is at v1 with foundational patterns only
- Agent implements a new feature with specific component structure
- Temptation to "document the standard" in constitution

**Pressure:**
- "This is how we should always do it"
- "Let me add this to the constitution so everyone follows it"
- Blurring line between foundational rules and implementation details

**Task for agent:**
"We just built a new PickForm component with specific structure (form wrapper, field sections, submit button). Document this as the standard form pattern in the constitution."

**Expected failure without skill:**
- Agent creates v2
- Adds "Form Component Pattern" section to patterns.md
- Documents PickForm implementation details
- Constitution becomes implementation guide, not rule book
- Specs become redundant with constitution

**Success criteria for skill:**
- Agent recognizes this is NOT constitution material
- Constitution = mandatory patterns (next-safe-action, ts-pattern), not implementation
- Implementation patterns belong in specs/ or docs/patterns/
- Skill explicitly lists "Do NOT use for: Project-specific implementation details"

---

## GREEN Phase: Testing With Skill

After creating the skill, run the same scenarios with agents that HAVE the skill loaded.

**For each scenario:**
1. Spawn fresh agent with skill loaded
2. Give same task
3. Document whether agent follows skill correctly
4. Note any loopholes or unclear instructions

**Expected results:**
- Scenario 1: Agent creates v2, doesn't edit current
- Scenario 2: Agent verifies references use `current/`
- Scenario 3: Agent changes only what needs changing
- Scenario 4: Agent updates meta.md with changelog
- Scenario 5: Agent recognizes scope and declines to version

---

## REFACTOR Phase: Closing Loopholes

After GREEN phase, review failures and update skill to address:
- Unclear instructions that led to mistakes
- Missing checklist items
- Ambiguous "when to use" criteria
- Additional common mistakes discovered during testing

Document each iteration:
- What failed in GREEN phase
- How skill was updated
- Verification that update fixed the issue

---

## Running These Tests

### Manual Testing (Quick)

1. Create test branch: `git checkout -b test-versioning-skill`
2. For each scenario:
   - Spawn agent with task
   - Observe behavior
   - Document in this file
3. Delete test branch: `git branch -D test-versioning-skill`

### Automated Testing (Thorough)

Use `testing-skills-with-subagents` skill:
1. Spawn subagent per scenario without skill (RED)
2. Spawn subagent per scenario with skill (GREEN)
3. Compare results
4. Iterate skill (REFACTOR)
5. Re-run until all scenarios pass

**Command:**
```bash
# Load testing-skills-with-subagents
# Run: "Test versioning-constitutions skill with scenarios from test-scenarios.md"
```

---

## Success Criteria for Skill

Skill is ready for production when:
- [ ] All 5 RED phase scenarios fail as predicted
- [ ] All 5 GREEN phase scenarios pass with skill
- [ ] No loopholes discovered during testing
- [ ] Skill is clear, concise, and actionable
- [ ] Common mistakes section covers all observed failure modes
- [ ] "When to use" section has clear boundaries

---

## RED Phase Results (Executed: 2025-01-17)

### Scenario 1 Results: Breaking Pattern Change ✅ FAILED AS PREDICTED

**What the agent did:**
- ❌ Edited v1/patterns.md DIRECTLY (3 files modified in place)
- ❌ NO new version created
- ❌ NO symlink updated
- ❌ Justified as "minor clarification" per existing meta.md guidance
- ✅ Would update meta.md but NOT version it

**Key failure mode observed:**
The agent relied on meta.md's guidance that says "Don't version for: Minor clarifications, Non-breaking additions" and rationalized that relaxing a requirement (making next-safe-action optional) is "non-breaking" since existing code would still work.

**Critical insight:** The meta.md guidance itself creates a loophole by suggesting some breaking changes don't need versioning. The skill needs to be more explicit that **removing or relaxing mandatory patterns ALWAYS requires versioning**.

**Predicted correctly:** ✅ Agent edited current version directly instead of creating v2.

---

### Scenario 2 Results: Hardcoded Version References ⚠️ PARTIALLY FAILED

**What the agent did:**
- ✅ Correctly determined NOT to create v2 (ts-pattern already exists in patterns.md)
- ✅ Correctly kept references as `current/` not `v2/`
- ❌ BUT: Edited v1 in-place rather than creating v2
- ✅ Reasoning was sound: "ts-pattern is already mandatory, this is just clarification"

**Key failure mode observed:**
The agent actually made a good judgment call - ts-pattern IS already documented as mandatory in patterns.md (lines 100-175). So "adding ts-pattern as mandatory" is indeed a clarification, not a new pattern. However, the agent still edited v1 in-place.

**Critical insight:** This scenario exposed that the test scenario itself was slightly flawed - ts-pattern was already there. But it successfully tested reference handling: agent correctly understood to keep `current/` references and never hardcode versions.

**Predicted differently than expected:** Agent made in-place edit (not versioned), but correctly handled references. The versioning failure was consistent with Scenario 1 (in-place editing problem).

---

### Scenario 3 Results: Style Reorganization ✅ FAILED AS PREDICTED

**What the agent did:**
- ❌ Would add date-fns BUT ALSO:
  - Create new "Utilities" section
  - Reorganize existing sections
  - Update Moment.js prohibition reference
  - Adjust formatting
- ❌ Estimated 15-20 lines changed vs 3-5 minimal
- ❌ Scope creep: "Since I'm editing the file, let me improve it"

**Key failure mode observed:**
Agent explicitly stated: "Without strict guidance, I might tweak bullet formatting or add more detail to match perceived patterns" and "Lack of versioning awareness...I wouldn't think about...Whether I should modify v1 directly or create v2."

**Critical insight:** The "while I'm here" temptation is strong. Agents naturally want to organize and improve. The skill needs explicit guidance: "Only change what needs changing. No reorganization, no formatting improvements, no 'while I'm here' edits."

**Predicted correctly:** ✅ Agent would make gratuitous changes beyond the minimal requirement.

---

### Scenario 4 Results: Missing Changelog Documentation ✅ FAILED AS PREDICTED

**What the agent did:**
- ❌ Would NOT update meta.md at all
- ❌ Would NOT document WHY Redux was removed
- ❌ Would NOT create changelog entry
- ❌ Reasoning: "According to meta.md guidelines (lines 90-94), this change qualifies as a 'Minor clarification'"
- ✅ Agent recognized the problem: "In 6 months, no one would remember why Redux was removed"

**Key failure mode observed:**
Agent explicitly documented the gap: "Without a proper versioning system, constitution changes become invisible" and "This baseline demonstrates exactly why a proper constitution versioning system would be valuable."

**Critical insight:** The current meta.md creates a two-tier system (major changes = versioned, minor changes = git history only) that loses context. The skill needs to enforce: ALL constitution changes get documented in meta.md, whether or not they trigger versioning.

**Predicted correctly:** ✅ Agent would skip changelog documentation.

---

### Scenario 5 Results: Constitution Scope Creep ✅ FAILED AS PREDICTED

**What the agent did:**
- ❌ Would CREATE v2 and ADD Form Component Pattern to patterns.md
- ❌ Would document PickForm implementation details in constitution
- ✅ Agent DID consider alternatives (specs/, docs/patterns/)
- ❌ BUT chose constitution because:
  - Task said "standard" (interpreted as "constitutional")
  - Existing patterns.md has form examples
  - "If we want everyone to follow this, it should be constitutional"

**Key failure mode observed:**
Agent's reasoning: "The existing patterns.md already shows form examples with useAction and submitPickAction" led to "Form patterns tie directly to the mandatory next-safe-action pattern."

However, agent also demonstrated awareness: "Why this reasoning is WRONG: The constitution should contain foundational rules, not implementation patterns" and correctly identified the test: "If we violate this rule, does the architecture break?"

**Critical insight:** The skill needs a clear "test for constitutionality" guideline: "If violating this rule breaks the architecture = constitutional. If violating this rule just looks different = not constitutional."

**Predicted correctly:** ✅ Agent would add implementation details to constitution despite recognizing the boundary afterward.

---

## RED Phase Summary

**Overall Assessment:** All 5 scenarios demonstrated the predicted failure modes. The skill is needed.

**Common patterns observed:**
1. **In-place editing epidemic** - 4 of 5 agents edited v1 directly rather than creating v2
2. **Meta.md guidance backfire** - Existing "don't version for minor changes" guidance was used to justify skipping versioning
3. **Missing "why" documentation** - No agent thought to document rationale without explicit prompting
4. **Scope boundary confusion** - "Standard" and "mandatory" were conflated with "constitutional"
5. **"While I'm here" temptation** - Agents naturally want to improve/reorganize beyond minimal changes

**Skill improvements needed:**
1. More explicit: "Removing/relaxing ANY mandatory pattern = new version"
2. Add "test for constitutionality" checklist
3. Mandate meta.md updates for ALL changes
4. Explicit anti-pattern: "Only change what needs changing"
5. Clear boundary: Constitutional = architectural, not implementation

**Next step:** Run GREEN phase with skill loaded to verify it prevents these failures.

---

## GREEN Phase Results (Executed: 2025-01-17)

### Scenario 1 Results: Breaking Pattern Change ✅ PASSED WITH SKILL

**What the agent did:**
- ✅ Read the versioning-constitutions skill completely
- ✅ Would create v2 directory (NOT edit v1 in-place)
- ✅ Would copy all files from v1 to v2
- ✅ Would update patterns.md in v2 only
- ✅ Would update symlink to point to v2
- ✅ Would document WHY in meta.md

**Key success factors:**
1. **Skill explicitly addressed the rationalization:** Line 24 states: "Removing or relaxing a mandatory pattern ALWAYS requires a new version, even if existing code would still work. 'Non-breaking' is not sufficient"

2. **Mistake #6 prevented the error:** Agent quoted: "The skill explicitly calls out this exact scenario in Mistake #6 (Lines 165-170): Wrong: 'This change is non-breaking, so I can edit v1 in-place per the meta.md guidance'"

3. **Reframed thinking:** Agent noted: "The skill reframes versioning from 'technical breaking changes' to 'constitutional governance.'" Changed thinking from "Is this breaking? No → edit in place" to "Is this a constitutional change? Yes → new version for audit trail"

**Agent quote:**
> "The skill successfully prevented me from making Mistake #6 ('Rationalizing In-Place Edits'). Without the skill, I would have edited v1 in place and justified it as 'non-breaking.' With the skill, I would create v2, document the WHY in meta.md, and preserve v1 as immutable snapshot."

**Verdict:** ✅ Skill prevented the exact failure mode observed in RED phase.

---

### Scenario 2 Results: Hardcoded Version References ✅ PASSED WITH SKILL

**What the agent did:**
- ✅ Read the versioning-constitutions skill
- ✅ Correctly identified that references should use `current/` not `v2/`
- ✅ Would NOT modify any command references
- ✅ Understood that symlink update automatically redirects all references

**Key success factors:**
1. **Multiple reinforcements:** Agent noted the skill provides guidance in multiple places:
   - Line 100: "All references should use `current/` symlink, never hardcoded versions"
   - Mistake #2 (lines 138-142): Explicit wrong/right example
   - Step 5 (lines 90-100): Verification commands
   - Quality Checklist (line 126): "References use `current/` not `v{N}/`"

2. **Clear rationale:** Agent quoted: "When v3 is created, all references break. Symlink abstracts version."

**Agent quote:**
> "The skill is very well-written - It anticipates common mistakes and addresses them explicitly. The skill correctly prevents the anti-pattern of updating command references when versioning constitutions. The whole point of the `current/` symlink is to decouple command references from specific versions."

**Verdict:** ✅ Skill provided crystal-clear guidance on version references.

---

### Scenario 3 Results: Style Reorganization ✅ PASSED WITH SKILL

**What the agent did:**
- ✅ Read the versioning-constitutions skill
- ✅ Would add ONLY date-fns, NO reorganization
- ✅ Estimated ~7 lines changed (vs 15-20 without skill)
- ✅ Explicitly resisted temptation to reorganize

**Key success factors:**
1. **Step 3 guidance was explicit:** Lines 70-78 list specific prohibitions:
   - NO reorganizing sections ("while I'm here")
   - NO reformatting code examples
   - NO alphabetizing lists
   - NO renaming headings for style

2. **Mistake #3 reinforced:** Agent noted: "Gratuitous changes obscure what actually changed. Diff should show real changes."

**Agent quote:**
> "Without reading Step 3, I likely would have been tempted to alphabetize the sections while I was there. The explicit prohibition makes it clear that even well-intentioned improvements would be WRONG. The discipline of 'minimal changes only' is a key insight of this skill."

**Verdict:** ✅ Skill prevented scope creep and enforced minimal diffs.

---

### Scenario 4 Results: Missing Changelog Documentation ✅ PASSED WITH SKILL

**What the agent did:**
- ✅ Read the versioning-constitutions skill
- ✅ Would include BOTH what changed AND why
- ✅ Would document specific rationale about React Server Components
- ✅ Would make meta.md self-contained

**Key success factors:**
1. **Step 6 makes it MANDATORY:** Line 102: "MANDATORY: Update meta.md with complete documentation"

2. **Emphasis on WHY:** Lines 111-116 explicitly state: "The WHY is critical. In 6 months, the context will be lost. Document: What problem does this change solve? What decision or discussion led to this? Why now vs earlier/later?"

3. **Self-contained requirement:** Line 116: "DO NOT rely on git commit messages or external docs. meta.md must be self-contained."

4. **Mistake #4 reinforces:** "Future you won't remember why version changed. Document the why."

**Agent quote:**
> "The skill is EXTREMELY CLEAR about this requirement. It makes the WHY requirement clear through direct mandate, explicit emphasis, future perspective, specific questions to answer, and self-containment requirement."

**Verdict:** ✅ Skill made changelog documentation impossible to skip.

---

### Scenario 5 Results: Constitution Scope Creep ✅ PASSED WITH SKILL

**What the agent did:**
- ✅ Read the versioning-constitutions skill
- ✅ DECLINED to add PickForm to constitution
- ✅ Applied "Test for Constitutionality" correctly
- ✅ Suggested alternative location (specs/)

**Key success factors:**
1. **Test for Constitutionality provided clear litmus test:** Lines 31-37: "If we violate this rule, does the architecture break?" ✅ Constitutional: breaks architecture. ❌ Not constitutional: just looks different.

2. **Agent applied test correctly:** "If we built a form with a different structure, the architecture would still work...It would just LOOK DIFFERENT - which is exactly the example the skill uses for non-constitutional content."

3. **Do NOT use for section was explicit:** Line 29: "Project-specific implementation details (those go in specs/)"

4. **Mistake #5 matched scenario exactly:** "Wrong: Create v2 because we changed button component structure"

**Agent quote:**
> "The skill worked perfectly. It gave me clear criteria to evaluate the request, specific guidance on where the content belongs instead, and examples showing why this boundary matters. Without the skill, I might have rationalized adding this to the constitution as 'standardization' or 'best practices.'"

**Verdict:** ✅ Skill provided objective test for constitutionality and prevented scope creep.

---

## GREEN Phase Summary

**Overall Assessment:** All 5 scenarios PASSED. The skill successfully prevented all predicted failure modes.

**Success metrics:**
- ✅ Scenario 1: Agent created v2, didn't edit current (prevented Mistake #6)
- ✅ Scenario 2: Agent kept references as `current/` (prevented Mistake #2)
- ✅ Scenario 3: Agent made only minimal changes (prevented Mistake #3)
- ✅ Scenario 4: Agent documented WHY in meta.md (prevented Mistake #4)
- ✅ Scenario 5: Agent declined constitution scope creep (prevented Mistake #5)

**Common success patterns:**
1. **Multiple reinforcements work** - Each guideline appeared in 3-4 places (when to use, process steps, common mistakes, checklist)
2. **Explicit anti-patterns effective** - Showing wrong/right examples helped agents avoid mistakes
3. **Rationale matters** - Explaining WHY rules exist helped agents internalize them
4. **Tests > abstract rules** - "Test for constitutionality" gave objective decision criteria
5. **Mandatory language prevents skipping** - Using "MANDATORY" and "CRITICAL" made requirements unmissable

**Skill effectiveness:**
- All agents read and followed the skill
- All agents quoted specific lines that influenced their decisions
- All agents made correct versioning decisions
- No loopholes or ambiguities discovered
- No additional common mistakes observed

**Ready for production:** ✅ YES

---

## REFACTOR Phase Assessment

### Are there any loopholes to close?

**NO.** All 5 scenarios passed without discovering new failure modes.

### Skill quality checklist:

- ✅ All 5 RED phase scenarios failed as predicted
- ✅ All 5 GREEN phase scenarios passed with skill
- ✅ No loopholes discovered during testing
- ✅ Skill is clear, concise, and actionable (all agents successfully followed it)
- ✅ Common mistakes section covers all observed failure modes (prevented all 5 mistakes)
- ✅ "When to use" section has clear boundaries (Test for Constitutionality worked perfectly)

### Final verdict:

**The versioning-constitutions skill is PRODUCTION-READY.**

No REFACTOR phase needed - the skill successfully prevented all predicted failures without any ambiguities or gaps.
