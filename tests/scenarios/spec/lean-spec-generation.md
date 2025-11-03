# Test Scenario: Lean Spec Generation

## Context

Testing `/spectacular:spec` command's ability to generate lean, constitution-anchored feature specifications.

**Setup:**
- Repository with constitutions defined (or without)
- User provides feature description (vague or detailed)
- Superpowers plugin installed (for brainstorming skill)

**Purpose:**
- Verify spec generation follows "lean spec" pattern
- Ensure constitution references (not duplication)
- Test brainstorming integration
- Validate spec structure and content quality

**Reference:** CLAUDE.md Anti-Patterns in Specs section

## Expected Behavior

### Input: Feature Description

User provides either:

**Vague description:**
```
"I need authentication for my app"
```

**Detailed description:**
```
"Add JWT-based authentication with email/password login,
OAuth providers (Google, GitHub), password reset via email,
and role-based access control"
```

### Step 1: Brainstorming (If Needed)

**For vague descriptions:**
```
Using brainstorming skill to refine feature requirements...

[Socratic questioning to clarify:]
- Authentication methods needed?
- User types (end users, admins, etc.)?
- Integration with existing user model?
- Security requirements?
```

**For detailed descriptions:**
- May still brainstorm to explore edge cases
- Or proceed directly to spec if sufficiently detailed

### Step 2: Spec Generation

**Using writing-specs skill to create specification...**

**File created:** `specs/{runid}-{feature-slug}/spec.md`

Example: `specs/a1b2c3-authentication/spec.md`

### Step 3: Spec Structure (Expected)

```markdown
# Feature: Authentication System

## Overview

[2-3 sentence summary of what and why]

## Requirements

### Functional Requirements
- FR1: Users can sign up with email/password
- FR2: Users can log in with OAuth (Google, GitHub)
- FR3: Users can reset password via email
- FR4: Role-based access control (user, admin)

### Non-Functional Requirements
- NFR1: Passwords hashed with bcrypt (see constitution: security.md)
- NFR2: JWT tokens expire after 24h
- NFR3: HTTPS required for all auth endpoints

## Architecture

### Integration Points
- User model (existing): [path]
- Email service: [provider]
- OAuth providers: Google, GitHub

### Constitution References
- See `docs/constitutions/current/security.md` for password hashing requirements
- See `docs/constitutions/current/api-patterns.md` for error handling
- See `docs/constitutions/current/testing.md` for auth testing approach

**Do NOT duplicate constitution rules here - reference them.**

## Acceptance Criteria

- [ ] Users can sign up and receive confirmation email
- [ ] Users can log in with email/password
- [ ] Users can log in with Google OAuth
- [ ] Users can log in with GitHub OAuth
- [ ] Users can reset password via email link
- [ ] Admin users can access admin-only endpoints
- [ ] Regular users cannot access admin endpoints
- [ ] All passwords stored hashed (never plaintext)
- [ ] JWT tokens expire and refresh correctly

## Out of Scope

- Multi-factor authentication (future feature)
- Social login beyond Google/GitHub
- Account deletion workflow

## References

- OAuth 2.0 spec: https://oauth.net/2/
- JWT best practices: https://tools.ietf.org/html/rfc8725
- Next.js auth patterns: https://next-auth.js.org/
```

### What Spec Should NOT Include

❌ **Implementation details:**
```markdown
## Implementation Steps
1. Install next-auth
2. Create auth.ts config file
3. Add API routes
```
→ This belongs in the PLAN, not spec

❌ **Code examples:**
```markdown
## Example Code
```typescript
export const authOptions = {
  providers: [...]
}
```
```
→ Link to docs instead

❌ **Duplicated constitution rules:**
```markdown
## Password Security
Passwords must be hashed with bcrypt, salt rounds >= 12, stored in secure column...
```
→ Reference constitution instead: "See security.md for password requirements"

❌ **Task breakdown:**
```markdown
## Tasks
- Task 1: Database schema
- Task 2: API endpoints
- Task 3: UI components
```
→ This is the plan, generated later

## Failure Modes

### Issue 1: Constitution Duplication

**Symptom:** Spec repeats rules from constitution verbatim

**Example:**
```markdown
## Code Style
- Use next-safe-action for all server actions
- Validate all inputs with zod
- Never use 'any' type
[50 more lines from patterns.md]
```

**Root Cause:** Didn't use writing-specs skill, or skill not followed

**Prevention:** writing-specs skill MUST enforce "reference, don't duplicate"

**Detection:**
```bash
# Check for constitution content in spec
grep -f docs/constitutions/current/patterns.md specs/*/spec.md
# Should be minimal/no matches
```

### Issue 2: No Constitution References

**Symptom:** Spec doesn't reference any constitutions

**Example:** Spec says "follow best practices" without pointing to where those are defined

**Root Cause:** Constitution-aware development not followed

**Prevention:** writing-specs skill should require explicit references

**Detection:** `grep -c "constitutions/current" specs/*/spec.md` should be > 0

### Issue 3: Implementation Plan in Spec

**Symptom:** Spec includes step-by-step implementation tasks

**Root Cause:** Confusion between spec (WHAT/WHY) and plan (HOW/WHEN)

**Prevention:** writing-specs skill clearly separates spec and plan responsibilities

### Issue 4: Spec Too Long (Not Lean)

**Symptom:** Spec is 10+ pages with detailed code examples

**Root Cause:** Including information that belongs in external docs or constitution

**Prevention:** Specs should be 2-5 pages typically, lean and focused

**Detection:** `wc -l specs/*/spec.md` - warn if >500 lines

## Success Criteria

### Structure
- [ ] File created at `specs/{runid}-{feature-slug}/spec.md`
- [ ] Contains sections: Overview, Requirements, Architecture, Acceptance Criteria
- [ ] No implementation tasks (those are in plan)

### Constitution Integration
- [ ] References constitution files by path
- [ ] Does NOT duplicate constitution rules
- [ ] At least 1-2 constitution references

### Content Quality
- [ ] Requirements are specific and testable
- [ ] Acceptance criteria are clear and verifiable
- [ ] Out of Scope section prevents scope creep
- [ ] References link to external docs (not embedded examples)

### Leanness
- [ ] Spec is 2-5 pages (not 10+)
- [ ] Focuses on WHAT and WHY
- [ ] Defers HOW to planning phase
- [ ] No code examples (links only)

### Brainstorming Integration
- [ ] Vague inputs trigger brainstorming
- [ ] Brainstorming refines requirements before spec
- [ ] Detailed inputs may skip brainstorming (but can still use it)

## Test Execution

### Test Case 1: Vague Input

```bash
/spectacular:spec

# Prompt: "Add authentication"

# Expected:
# - Brainstorming triggered to clarify
# - Questions about auth methods, user types, etc.
# - Final spec includes refined requirements
```

### Test Case 2: Detailed Input with Constitutions

```bash
# Setup: Repository has constitutions in docs/constitutions/current/
cd /path/to/project-with-constitutions

/spectacular:spec

# Prompt: [Detailed auth feature description]

# Expected:
# - Spec references constitution files
# - Does NOT duplicate constitution content
# - Spec is lean (2-5 pages)
```

### Test Case 3: No Constitutions Present

```bash
# Setup: Repository without constitutions
cd /path/to/project-without-constitutions

/spectacular:spec

# Prompt: "Add authentication"

# Expected:
# - Spec generated without constitution references
# - Still lean and focused
# - Warning that constitutions help maintain consistency
```

### Validation After Generation

```bash
# Check file exists
ls specs/*/spec.md

# Check structure
grep -q "## Requirements" specs/*/spec.md
grep -q "## Acceptance Criteria" specs/*/spec.md

# Check constitution references (if applicable)
grep -c "constitutions/current" specs/*/spec.md

# Check leanness
wc -l specs/*/spec.md  # Should be reasonable length

# Check no implementation tasks
grep -q "## Implementation" specs/*/spec.md && echo "FAIL: Has implementation section"
grep -q "## Tasks" specs/*/spec.md && echo "FAIL: Has tasks section"
```

## Comparison: Lean vs Bloated Specs

### Lean Spec (Good)
```markdown
## Architecture

### Authentication Flow
- User submits credentials → API validates → JWT issued
- See constitution security.md for token requirements
- See OAuth docs: [link]

### Integration
- User model: src/models/user.ts (existing)
- Email service: via SendGrid (constitution: integrations.md)
```

**Length:** 3 pages
**References:** External docs and constitutions
**Focus:** WHAT and WHY

### Bloated Spec (Bad)
```markdown
## Architecture

### Authentication Flow
User submits credentials. The system validates them against
the database using bcrypt password hashing with 12 salt rounds.
If valid, a JWT token is generated with the following structure:

{
  "userId": "123",
  "email": "user@example.com",
  "roles": ["user"],
  "exp": 1234567890
}

The token is signed with HS256 algorithm using a secret key
stored in environment variables...

[10 more pages of implementation details, code examples,
and constitution rules duplicated]
```

**Length:** 15 pages
**Duplicates:** Constitution and external docs
**Focus:** HOW (should be in plan)

## Related Scenarios

- **task-decomposition.md** - Tests plan generation (next step after spec)
- All execute scenarios depend on valid spec existing

## Integration with Planning

**After spec is generated:**

```bash
# User reviews spec
# User runs:
/spectacular:plan

# Plan generation reads spec
# Plan creates task breakdown with HOW and WHEN
# Spec remains unchanged (WHAT and WHY)
```

**Spec is immutable anchor - plan can be regenerated/modified**

## Edge Cases

### Very Simple Feature

**Input:** "Add a contact form"

**Expected spec:**
- Still has full structure
- Requirements may be brief but complete
- Acceptance criteria still listed
- Still 2-3 pages minimum

### Very Complex Feature

**Input:** "Complete e-commerce platform with cart, checkout, payments, inventory, etc."

**Expected:**
- Spec recommends splitting into multiple features
- Or spec focuses on MVP scope
- Out of Scope section is large
- Still lean by heavy use of references

### Feature Conflicts with Constitution

**Input:** "Add feature X that requires violating security rule Y"

**Expected:**
- Spec generation flags conflict
- Recommends either: modify feature OR update constitution
- Does NOT silently allow violation
