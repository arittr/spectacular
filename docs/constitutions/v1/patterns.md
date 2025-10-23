# Mandatory Patterns

## Core Principle

**These patterns are constitutional: violating them breaks architecture, not just style.**

Test each pattern: "If violated, does something break?" If yes, it belongs here. If no, it's just a preference.

## Skill Format

### MUST: Frontmatter with name and description

```markdown
---
name: skill-name
description: When to use this skill - trigger conditions
---
```

**Why constitutional:** Skill tool requires exact `name` field to invoke. Missing/wrong name = broken invocation.

### MUST: Structured sections

Every skill MUST include:

1. **When to Use** - Trigger conditions and scenarios
2. **The Process** - Step-by-step workflow
3. **Quality Rules** (if applicable) - Validation criteria
4. **Error Handling** (if applicable) - Recovery procedures

**Why constitutional:** Without structured sections, skills become ad-hoc advice instead of executable processes. Claude needs explicit triggers and steps.

### MUST: Announce usage

Skills with processes MUST include announcement instruction:

```markdown
**Announce:** "I'm using {skill-name} to {purpose}."
```

**Why constitutional:** Transparency catches errors early. Without announcement, we can't tell if skill was actually read/used or just rationalized away.

### SHOULD: Rationalization table

Skills enforcing discipline SHOULD include table of predictable rationalizations:

```markdown
| Rationalization | Reality |
|-----------------|---------|
| "This is simple, skill is overkill" | Simple tasks become complex when process skipped |
```

**Why constitutional:** Documents anti-patterns preemptively. Claude can rationalize away almost any rule - making rationalizations explicit prevents this.

### SHOULD: TodoWrite checklists

Multi-step processes SHOULD require TodoWrite:

```markdown
**Create TodoWrite todos for:**
- [ ] Step 1
- [ ] Step 2
- [ ] Step 3
```

**Why constitutional:** Steps get skipped without tracking. TodoWrite creates accountability.

## Command Format

### MUST: YAML frontmatter with description

```markdown
---
description: One-line description shown in command list
---
```

**Why constitutional:** Claude Code plugin system requires `description` field. Missing = command not discoverable.

### MUST: Delegate to skills

Commands MUST orchestrate by referencing skills, not implementing directly:

```markdown
✅ "Use the `writing-specs` skill to generate the specification."
❌ "First brainstorm ideas, then draft sections, then..." (reimplementing skill)
```

**Why constitutional:** Duplication = divergence. When skill updates, command logic becomes stale.

### MUST: Use TodoWrite for multi-step orchestration

```markdown
Create TodoWrite todos:
1. Validate environment
2. Generate specification
3. Review and commit
```

**Why constitutional:** Multi-step workflows lose track of progress without explicit state. TodoWrite creates visibility.

## TodoWrite Usage

### MUST: Create todos BEFORE starting work

Don't create todos retroactively after work is done.

**Why constitutional:** TodoWrite exists for planning and tracking, not performance theater. After-the-fact todos provide no value.

### MUST: Mark in_progress before starting task

Exactly ONE task must be in_progress at any time.

**Why constitutional:** Enables progress monitoring. Multiple in_progress = confusion. Zero in_progress = no visibility.

### MUST: Mark completed immediately after finishing

Don't batch multiple completions.

**Why constitutional:** Real-time status prevents forgetting steps. Batching makes todos meaningless.

### MUST: Use imperative form for content, continuous for activeForm

```json
{"content": "Run tests", "activeForm": "Running tests"}
{"content": "Build project", "activeForm": "Building project"}
```

**Why constitutional:** Consistency in UI presentation. Wrong forms = confusing status display.

## RED-GREEN-REFACTOR Pattern

### MUST: Assume Claude will rationalize away rules

When writing skills, assume Claude will find ways to skip steps.

**Document predictable shortcuts:**
- "I remember this skill" → Skills evolve, must read current version
- "This doesn't count as testing" → It counts, write test
- "Change is non-breaking" → Still needs versioning for audit trail

**Why constitutional:** Claude is smart enough to rationalize almost anything. Skills must preemptively block known rationalizations.

### MUST: Test skills with subagents before deployment

Use `testing-skills-with-subagents` from superpowers to validate skills work under pressure.

**Why constitutional:** Untested skills contain loopholes. Subagent testing finds them.

## Subagent Patterns

### MUST: Orchestrators delegate, never implement directly

Orchestrator subagents create worktrees and dispatch implementation subagents. They MUST NOT run git commands directly.

```markdown
✅ "Dispatch implementation subagent to work in worktree"
❌ "Run git checkout -b feature in worktree"
```

**Why constitutional:** Orchestrators lack isolation. Direct implementation creates race conditions in parallel work.

### MUST: Implementation subagents detach HEAD after branch creation

After `gs branch create`, implementation subagents MUST run:

```bash
git switch --detach
```

**Why constitutional:** Without detaching, parent repo can't access branch. Worktree cleanup fails.

### MUST: Implementation subagents verify before claiming success

Use `verification-before-completion` skill from superpowers.

**Why constitutional:** "Tests pass" without evidence = broken workflow continues. Verification catches failures early.

## Git-Spice Patterns

### MUST: Use stacked branches, not feature branches

```markdown
✅ task-1 → task-2 → task-3 (stack)
❌ main → feature-branch (single branch)
```

**Why constitutional:** Spectacular's entire workflow depends on stacking. Single branches break parallel execution and reviewable PRs.

### MUST: Use runId prefix for all task branches

```markdown
✅ a1b2c3-task-1-2-install-tsx
❌ install-tsx
```

**Why constitutional:** RunId enables multiple features developed simultaneously. Without prefix, branch names collide.

### MUST: Create branches with `gs branch create`, not `git checkout -b`

```bash
✅ gs branch create task-name
❌ git checkout -b task-name
```

**Why constitutional:** Git-spice tracks branch relationships. Using raw git bypasses stack tracking.

### MUST: Never force-push to shared branches

**Why constitutional:** Destroys collaborator work. Stacked PRs rely on stable history.

## Constitution Versioning

### MUST: Create new version for any mandatory pattern change

Even if change is "non-breaking", adding/removing/relaxing mandatory patterns requires new version.

**Why constitutional:** Audit trail matters. Future readers need to know WHEN rules changed.

### MUST: Never edit old versions after creating new version

v1/ is immutable after v2/ exists. v2/ is immutable after v3/ exists.

**Why constitutional:** Immutability enables version history. Edits destroy audit trail.

### MUST: Always reference current/ symlink

```markdown
✅ @docs/constitutions/current/patterns.md
❌ @docs/constitutions/v2/patterns.md
```

**Why constitutional:** Hardcoded versions break when new version created. Symlink abstracts version.

### MUST: Minimal changes only when versioning

Only change what needs changing. No reorganizing, reformatting, alphabetizing.

**Why constitutional:** Gratuitous changes obscure what actually changed. Diff should show real changes only.

## Superpowers Integration

### MUST: Reference superpowers skills, never duplicate

Before creating a new skill, check if superpowers provides it:

- `brainstorming` - Refine ideas before spec creation
- `test-driven-development` - Write test first
- `systematic-debugging` - Four-phase debugging
- `requesting-code-review` - Dispatch code-reviewer
- `verification-before-completion` - Evidence before assertions
- `using-git-worktrees` - Parallel task isolation

**Why constitutional:** Duplication = divergence. When superpowers updates, duplicated logic becomes stale.

### MUST: Follow superpowers skill format

Spectacular skills MUST follow same format as superpowers:
- Frontmatter with name/description
- Structured sections (When to Use, Process, Quality)
- Announcement instructions
- Rationalization tables

**Why constitutional:** Format consistency enables skill discovery and understanding. Ad-hoc formats break skill tool invocation.

## Violation Patterns

**What happens when patterns are violated?**

| Violation | Consequence |
|-----------|-------------|
| Missing skill frontmatter | Skill tool can't invoke skill |
| Command implements directly | Logic diverges from skills, hard to maintain |
| No TodoWrite for multi-step | Steps forgotten, workflow incomplete |
| Orchestrator runs git directly | Race conditions, broken isolation |
| Implementation subagent skips detach | Worktree cleanup fails, branches lost |
| Hardcoded version reference | Breaks when new constitution version created |
| Editing old constitution version | Lost immutability, broken audit trail |
| Duplicating superpowers skills | Missed improvements, divergence |

These aren't preferences - they're load-bearing patterns that if violated, cause concrete failures.
