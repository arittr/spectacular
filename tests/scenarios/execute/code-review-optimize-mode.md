# Test Scenario: Code Review Optimize Mode

## Context

Testing that `REVIEW_FREQUENCY=optimize` mode makes intelligent decisions about when to run code reviews based on phase risk and complexity.

**Setup:**
- Feature with multiple phases (mix of high-risk and low-risk)
- `REVIEW_FREQUENCY` set to `"optimize"`
- Phase execution skills analyze completed phases
- Decision logic documented in executing-sequential-phase and executing-parallel-phase

**Why critical:**
- Balances speed and quality by focusing reviews where they matter
- Prevents review fatigue on trivial changes
- Ensures critical phases (schema, auth, foundation) get reviewed
- Saves 30-50% of review time while maintaining quality gates

## Expected Behavior

### High-Risk Phase Detection (SHOULD REVIEW)

**Phase 1: Database Foundation (Sequential)**
- **Tasks**: Schema changes, migrations, Prisma setup
- **Files**: `prisma/schema.prisma`, `prisma/migrations/*.sql`
- **Risk indicators**:
  - ✅ Schema or migration changes
  - ✅ Foundation phase (Phase 1 establishing patterns)
- **Expected decision**: REVIEW REQUIRED
- **Output**:
  ```
  Analyzing Phase 1 for code review necessity (optimize mode)...

  Phase assessment:
  - Phase number: 1
  - Tasks: Database schema, migration setup
  - Files: prisma/schema.prisma, prisma/migrations/
  - Risk indicators detected:
    ✅ Schema changes (high-risk)
    ✅ Foundation phase establishing patterns (high-risk)

  Decision: Code review REQUIRED
  Reasoning: Foundation phase with schema changes - critical to verify before subsequent phases build on this

  Proceeding to code review...
  ```

**Phase 2: Authentication Logic (Parallel)**
- **Tasks**: User auth, session management, JWT validation
- **Files**: `src/auth/*.ts`, `src/middleware/auth.ts`
- **Risk indicators**:
  - ✅ Authentication/authorization logic
  - ✅ Security-sensitive code
  - ✅ Foundation phase (Phase 2)
- **Expected decision**: REVIEW REQUIRED
- **Output**:
  ```
  Analyzing Phase 2 for code review necessity (optimize mode)...

  Phase assessment:
  - Phase number: 2
  - Tasks: User authentication, session management, JWT validation
  - Files: src/auth/login.ts, src/auth/session.ts, src/middleware/auth.ts
  - Risk indicators detected:
    ✅ Authentication/authorization logic (high-risk)
    ✅ Security-sensitive code (high-risk)
    ✅ Foundation phase (high-risk)

  Decision: Code review REQUIRED
  Reasoning: Auth logic is security-critical - must verify correct implementation before proceeding

  Proceeding to code review...
  ```

**Phase 3: API Integration (Sequential)**
- **Tasks**: External webhook receiver, API client, retry logic
- **Files**: `src/api/webhook.ts`, `src/api/client.ts`
- **Risk indicators**:
  - ✅ External API integrations or webhooks
  - ✅ Complex business logic (retry, error handling)
- **Expected decision**: REVIEW REQUIRED
- **Output**:
  ```
  Analyzing Phase 3 for code review necessity (optimize mode)...

  Phase assessment:
  - Phase number: 3
  - Tasks: Webhook receiver, API client, retry logic
  - Files: src/api/webhook.ts, src/api/client.ts, src/api/retry.ts
  - Risk indicators detected:
    ✅ External API integrations (high-risk)
    ✅ Complex business logic with edge cases (high-risk)

  Decision: Code review REQUIRED
  Reasoning: External integrations can fail in unexpected ways - review needed to verify error handling

  Proceeding to code review...
  ```

### Low-Risk Phase Detection (SHOULD SKIP)

**Phase 4: UI Components (Parallel - 4 tasks)**
- **Tasks**: Button component, Card component, Modal component, Loading spinner
- **Files**: `src/components/ui/Button.tsx`, `src/components/ui/Card.tsx`, etc.
- **Risk indicators**:
  - ✅ Pure UI component additions (no state/logic) - LOW RISK
  - ❌ No schema changes
  - ❌ No auth logic
  - ❌ No external APIs
- **Expected decision**: SKIP REVIEW
- **Output**:
  ```
  Analyzing Phase 4 for code review necessity (optimize mode)...

  Phase assessment:
  - Phase number: 4
  - Tasks: Button, Card, Modal, Loading components (parallel)
  - Files: src/components/ui/*.tsx (4 isolated components)
  - Risk indicators detected:
    None - pure presentational components with no state or business logic

  Decision: SKIP code review
  Reasoning: Isolated UI components with no state management or business logic - low risk

  ✓ Phase 4 assessed as low-risk - skipping review (optimize mode)
  Phase 4 complete - proceeding to next phase
  ```

**Phase 5: Documentation Updates (Sequential)**
- **Tasks**: Update README, add API docs, component examples
- **Files**: `README.md`, `docs/api.md`, `docs/components.md`
- **Risk indicators**:
  - ✅ Documentation or comment updates - LOW RISK
  - ❌ No code changes
  - ❌ No schema changes
- **Expected decision**: SKIP REVIEW
- **Output**:
  ```
  Analyzing Phase 5 for code review necessity (optimize mode)...

  Phase assessment:
  - Phase number: 5
  - Tasks: README updates, API documentation, component examples
  - Files: README.md, docs/*.md (documentation only)
  - Risk indicators detected:
    None - documentation updates with no code changes

  Decision: SKIP code review
  Reasoning: Documentation-only changes - no functional risk

  ✓ Phase 5 assessed as low-risk - skipping review (optimize mode)
  Phase 5 complete - proceeding to next phase
  ```

**Phase 6: Utility Functions (Parallel - 2 tasks)**
- **Tasks**: Date formatting helper, String validation utility
- **Files**: `src/utils/date.ts`, `src/utils/string.ts`
- **Risk indicators**:
  - ✅ Isolated utility functions - LOW RISK
  - ✅ Refactoring with existing test coverage - LOW RISK
  - ❌ No cross-layer dependencies
- **Expected decision**: SKIP REVIEW
- **Output**:
  ```
  Analyzing Phase 6 for code review necessity (optimize mode)...

  Phase assessment:
  - Phase number: 6
  - Tasks: Date formatting, string validation (parallel)
  - Files: src/utils/date.ts, src/utils/string.ts
  - Risk indicators detected:
    None - isolated pure functions with test coverage

  Decision: SKIP code review
  Reasoning: Self-contained utilities with tests - low coordination risk

  ✓ Phase 6 assessed as low-risk - skipping review (optimize mode)
  Phase 6 complete - proceeding to next phase
  ```

### Edge Case: Borderline Phase (3+ Parallel Tasks)

**Phase 7: Service Layer (Parallel - 3 tasks)**
- **Tasks**: User service, Product service, Order service
- **Files**: `src/services/user.ts`, `src/services/product.ts`, `src/services/order.ts`
- **Risk indicators**:
  - ✅ 3+ parallel tasks (coordination complexity) - HIGH RISK
  - ❌ Not auth/schema/API
  - ❌ Not foundation phase
- **Expected decision**: REVIEW REQUIRED
- **Output**:
  ```
  Analyzing Phase 7 for code review necessity (optimize mode)...

  Phase assessment:
  - Phase number: 7
  - Tasks: User service, Product service, Order service (3 parallel)
  - Files: src/services/*.ts (3 services)
  - Risk indicators detected:
    ✅ 3+ parallel tasks - coordination complexity (high-risk)

  Decision: Code review REQUIRED
  Reasoning: 3+ parallel services may have integration issues - verify they work together correctly

  Proceeding to code review...
  ```

## Decision Algorithm Verification

The phase execution skills must implement this exact logic:

```
IF REVIEW_FREQUENCY = "optimize" THEN
  Analyze completed phase:

  High-risk indicators (ANY = REVIEW):
  - Schema or migration changes
  - Authentication/authorization logic
  - External API integrations or webhooks
  - Foundation phases (Phase 1-2)
  - 3+ parallel tasks
  - New architectural patterns
  - Security-sensitive code (payment, PII, access control)
  - Complex business logic with edge cases
  - Changes affecting multiple layers (DB → API → UI)

  Low-risk indicators (ALL = SKIP):
  - Pure UI components (no state/logic)
  - Documentation or comment updates
  - Test additions without implementation
  - Refactoring with existing coverage
  - Isolated utility functions
  - Non-security config updates

  IF any high-risk indicator present THEN
    Run code review (binary enforcement)
  ELSE
    Skip review with reasoning
  END IF
END IF
```

## Success Criteria

### Decision Logic Documentation
- [ ] executing-sequential-phase Step 4 documents optimize mode decision logic
- [ ] executing-parallel-phase Step 8 documents optimize mode decision logic
- [ ] Both skills list identical high-risk indicators
- [ ] Both skills list identical low-risk indicators
- [ ] Both skills require reasoning when skipping review

### High-Risk Phase Behavior
- [ ] Schema changes trigger review
- [ ] Auth logic triggers review
- [ ] External APIs trigger review
- [ ] Foundation phases (1-2) trigger review
- [ ] 3+ parallel tasks trigger review
- [ ] Security-sensitive code triggers review
- [ ] Cross-layer changes trigger review

### Low-Risk Phase Behavior
- [ ] Pure UI components skip review
- [ ] Documentation-only skips review
- [ ] Test-only additions skip review
- [ ] Isolated utilities skip review (N<3 parallel)
- [ ] Non-security config skips review

### Output Quality
- [ ] Skipped reviews announce "optimize mode"
- [ ] Skipped reviews provide reasoning
- [ ] Triggered reviews explain which indicator was detected
- [ ] Decision is transparent and auditable

## Failure Modes

### Issue 1: Always Reviewing (Optimize = Per-Phase)

**Symptom:** All phases trigger review regardless of risk

**Root Cause:** Decision logic not implemented or always returns "review required"

**Detection:**
```bash
# Check execution output
grep "optimize mode" execution.log
# Should show some phases skipped
```

**Fix:** Verify decision algorithm implementation in skills

### Issue 2: Always Skipping (Optimize = End-Only)

**Symptom:** All phases skip review including high-risk ones

**Root Cause:** High-risk indicator detection broken

**Detection:**
```bash
# Check if Phase 1 (schema) was reviewed
grep "Phase 1.*code review" execution.log
# Should show review was triggered
```

**Fix:** Verify high-risk indicator detection logic

### Issue 3: No Reasoning Provided

**Symptom:** Review skipped without explanation

**Output:**
```
✓ Phase 4 complete - proceeding to next phase
```

**Root Cause:** Missing reasoning requirement in skip path

**Fix:** Add mandatory reasoning output when skipping review

### Issue 4: Inconsistent Decisions

**Symptom:** Same type of phase reviewed in Phase 2, skipped in Phase 5

**Root Cause:** Decision logic differs between sequential/parallel skills

**Detection:** Compare decision logic in both skills

**Fix:** Ensure identical high-risk/low-risk indicator lists in both skills

## Testing Method

**Manual verification:**

1. Read `executing-sequential-phase` SKILL.md Step 4
2. Read `executing-parallel-phase` SKILL.md Step 8
3. Verify both document optimize mode decision logic
4. Verify high-risk indicators are comprehensive
5. Verify low-risk indicators match expected cases
6. Verify reasoning is required when skipping

**Subagent testing:**

1. Create mock 6-phase plan (3 high-risk, 3 low-risk)
2. Set `REVIEW_FREQUENCY=optimize`
3. Execute plan
4. Verify exactly 3 reviews triggered (high-risk phases)
5. Verify exactly 3 reviews skipped (low-risk phases)
6. Verify all skips include reasoning

## Implementation Evidence

**Sequential Phase Skill** (lines 141-176):
```markdown
**If REVIEW_FREQUENCY is "optimize":**

Analyze the completed phase to decide if code review is needed:

**High-risk indicators (REVIEW REQUIRED):**
- Schema or migration changes
- Authentication/authorization logic
- External API integrations or webhooks
- Foundation phases (Phase 1-2 establishing patterns)
- New architectural patterns introduced
- Security-sensitive code (payment, PII, access control)
- Complex business logic with multiple edge cases
- Changes affecting multiple layers (database → API → UI)

**Low-risk indicators (SKIP REVIEW):**
- Pure UI component additions (no state/logic)
- Documentation or comment updates
- Test additions without implementation changes
- Refactoring with existing test coverage
- Single isolated utility function
- Configuration file updates (non-security)

**Decision:**
If ANY high-risk indicator present → Proceed to code review below
If ONLY low-risk indicators → Skip review with reasoning
```

**Parallel Phase Skill** (lines 298-334):
Same logic with addition of "3+ parallel tasks (coordination complexity)" to high-risk indicators.

## Expected Savings

**5-phase plan example:**
- Phase 1 (Schema): REVIEW (foundation + schema)
- Phase 2 (Auth): REVIEW (auth + security)
- Phase 3 (API): REVIEW (external integration)
- Phase 4 (UI components x4): SKIP (pure UI)
- Phase 5 (Docs): SKIP (documentation)

**Result:**
- Reviews triggered: 3 (60%)
- Reviews skipped: 2 (40%)
- Time saved: ~6-10 min (2 reviews @ 3-5 min each)
- Quality maintained: All critical phases reviewed

## Related Scenarios

- **code-review-binary-enforcement.md** - Verifies review parsing when triggered
- **mixed-sequential-parallel-phases.md** - Tests cross-phase review decisions
