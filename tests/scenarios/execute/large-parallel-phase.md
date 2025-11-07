---
id: large-parallel-phase
type: integration
severity: major
duration: 5m
tags: [parallel-execution, scalability, performance]
---

# Test Scenario: Large Parallel Phase (10 Tasks)

## Context

Testing `/spectacular:execute` scalability with a large parallel phase containing 10 independent tasks.

**Setup:**
- Feature spec with Phase 2 containing 10 parallel tasks
- All tasks are independent (no dependencies)
- Clean git state with git-spice initialized
- Sufficient disk space for 10 worktrees (~500MB each = 5GB total)

**Why this matters:**
- Tests scalability beyond typical 3-4 task scenarios
- Verifies stacking performance doesn't degrade (should be O(N), not O(N²))
- Validates resource management at scale
- Identifies performance bottlenecks

## Expected Behavior

### Worktree Creation (10 worktrees)

**Time expectation: < 10 seconds**

```bash
cd "$REPO_ROOT"

BASE_BRANCH=$(git -C .worktrees/{runid}-main branch --show-current)

# Create 10 worktrees
for TASK_ID in 1 2 3 4 5 6 7 8 9 10; do
  git worktree add ".worktrees/{runid}-task-${TASK_ID}" --detach "$BASE_BRANCH"
  echo "✅ Created .worktrees/{runid}-task-${TASK_ID} (detached HEAD)"
done

# Verify all created
git worktree list | grep "{runid}-task-" | wc -l
# Expected: 10
```

### Parallel Execution (10 simultaneous subagents)

**Spawn 10 subagents in parallel:**

Each subagent:
- Works in isolated worktree (`.worktrees/{runid}-task-{N}`)
- Implements independent feature
- Runs quality checks
- Creates branch: `{runid}-task-2-{N}-{short-name}`
- Detaches HEAD

**Parallelism:**
- All 10 subagents run simultaneously
- No sequential bottleneck
- Each has dedicated worktree (no conflicts)

### Linear Stacking (9 upstack operations)

**Time expectation: < 30 seconds**

```bash
cd .worktrees/{runid}-main

# Task 1: Base of stack
git checkout {runid}-task-2-1-user-model
gs branch track
# (0.5s per operation)

# Task 2: Stack onto task 1
git checkout {runid}-task-2-2-user-service
gs branch track
gs upstack onto {runid}-task-2-1-user-model
# (1.5s per operation: checkout + track + upstack)

# Task 3: Stack onto task 2
git checkout {runid}-task-2-3-user-controller
gs branch track
gs upstack onto {runid}-task-2-2-user-service

# ... Task 4 through 10 follow same pattern ...

# Task 10: Stack onto task 9
git checkout {runid}-task-2-10-user-docs
gs branch track
gs upstack onto {runid}-task-2-9-user-tests

# Verify linear stack
gs log short
# Should show: task-1 → task-2 → ... → task-10 (linear chain)

cd "$REPO_ROOT"
```

**Total operations:**
- 1 checkout + track (task 1)
- 9 × (checkout + track + upstack onto) (tasks 2-10)
- 1 verification (gs log short)
- = 28 git-spice operations

**Performance requirement:** O(N) time complexity, not O(N²)

### Cleanup (10 worktree removals)

**Time expectation: < 5 seconds**

```bash
for TASK_ID in 1 2 3 4 5 6 7 8 9 10; do
  git worktree remove ".worktrees/{runid}-task-${TASK_ID}"
done

# Verify cleanup
git worktree list | grep "{runid}-task-" | wc -l
# Expected: 0
```

### Final State

```bash
gs ls
# main
# └─□ {runid}-main
#    └─□ {runid}-task-1-1-database         [Phase 1, if exists]
#       └─□ {runid}-task-2-1-user-model
#          └─□ {runid}-task-2-2-user-service
#             └─□ {runid}-task-2-3-user-controller
#                └─□ {runid}-task-2-4-user-validation
#                   └─□ {runid}-task-2-5-auth-middleware
#                      └─□ {runid}-task-2-6-api-endpoints
#                         └─□ {runid}-task-2-7-frontend-integration
#                            └─□ {runid}-task-2-8-error-handling
#                               └─□ {runid}-task-2-9-user-tests
#                                  └─□ {runid}-task-2-10-user-docs

# Perfect 11-branch linear chain (Phase 1 + 10 parallel tasks)
```

### Resource Usage

**Disk space:**
- 10 worktrees × ~500MB = ~5GB
- Should clean up to ~50MB after worktree removal

**Memory:**
- 10 parallel subagents × ~200MB = ~2GB peak usage
- Acceptable for modern development machines

**Time breakdown:**
- Worktree creation: 10s
- Parallel execution: Variable (depends on task complexity)
- Linear stacking: 30s
- Cleanup: 5s
- **Total overhead: ~45s** (excluding task implementation time)

## Success Criteria

### Scalability
- [ ] All 10 worktrees created successfully
- [ ] All 10 subagents spawn and execute
- [ ] Stacking completes in O(N) time (< 30s for N=10)
- [ ] No performance degradation compared to N=3 scenario

### Correctness
- [ ] All 10 task branches created
- [ ] Linear chain formed correctly (no branches or orphans)
- [ ] Each task stacked on previous task
- [ ] Final `gs log short` shows 10-task linear chain

### Resource Management
- [ ] Peak disk usage < 10GB
- [ ] All worktrees cleaned up after stacking
- [ ] No memory leaks or resource exhaustion
- [ ] No file handle exhaustion

### Reliability
- [ ] No failures due to number of parallel tasks
- [ ] No race conditions in git operations
- [ ] No conflicts between parallel subagents
- [ ] Stacking completes without retry or error

### Performance Benchmarks
- [ ] Worktree creation: < 1s per worktree (10s total)
- [ ] Stacking: < 3s per task (30s total for 9 upstack operations)
- [ ] Cleanup: < 1s per worktree (10s total)
- [ ] Total orchestration overhead: < 1 minute

## Failure Modes to Test

### Issue 1: Quadratic Stacking Time

**Symptom:** Stacking takes progressively longer for each task (O(N²) behavior)

**Root Cause:** Each `gs upstack onto` operation re-processes entire stack

**Detection:**
```bash
# Time each stacking operation:
time git checkout {runid}-task-2-2-user-service
time gs upstack onto {runid}-task-2-1-user-model
# Should be ~1.5s

time git checkout {runid}-task-2-10-user-docs
time gs upstack onto {runid}-task-2-9-user-tests
# Should still be ~1.5s (not 10s)
```

**Expected:** Linear time (each operation takes similar time regardless of position in stack)

### Issue 2: Resource Exhaustion

**Symptom:** Subagent 8 fails with "out of memory" or "too many open files"

**Root Cause:** System limits exceeded

**Detection:**
```bash
# Before execution:
ulimit -n  # File descriptors (should be > 1024)
free -h    # Available memory (should be > 4GB)

# During execution:
ps aux | grep spectacular | wc -l  # Active processes
```

### Issue 3: Git Operation Conflicts

**Symptom:** `git worktree add` or `gs branch track` fails for task 6+

**Root Cause:** Race condition or lock contention in git operations

**Detection:**
```bash
# Check for .git/index.lock files during execution
ls .git/*.lock 2>/dev/null
# Should be empty or transient (not stuck)
```

### Issue 4: Cleanup Fails Partway

**Symptom:** Only 7 of 10 worktrees removed, 3 remain

**Root Cause:** Error during cleanup doesn't stop loop, but some removals fail

**Detection:**
```bash
git worktree list | grep "{runid}-task-"
# Should be empty
# If not empty, indicates partial cleanup failure
```

## Performance Comparison

| Scenario | Tasks (N) | Worktrees | Stacking Ops | Expected Time | Actual Time |
|----------|-----------|-----------|--------------|---------------|-------------|
| parallel-stacking-2-tasks | 2 | 2 | 1 upstack | ~5s | TBD |
| parallel-stacking-3-tasks | 3 | 3 | 2 upstack | ~8s | TBD |
| parallel-stacking-4-tasks | 4 | 4 | 3 upstack | ~10s | TBD |
| **large-parallel-phase** | **10** | **10** | **9 upstack** | **~30s** | **TBD** |

**Performance should scale linearly:**
- 2 tasks → 3 tasks: +60% time
- 3 tasks → 10 tasks: +275% time (not +900%)

## Test Execution

**Setup:**

Create plan with 10 parallel tasks:

```markdown
## Phase 2 (Parallel - 30h estimated)
- Task 1: User model implementation (3h)
- Task 2: User service layer (3h)
- Task 3: User controller/routes (3h)
- Task 4: Input validation (3h)
- Task 5: Authentication middleware (3h)
- Task 6: API endpoint integration (3h)
- Task 7: Frontend UI components (3h)
- Task 8: Error handling (3h)
- Task 9: Unit & integration tests (3h)
- Task 10: Documentation (3h)
```

**Execute:**

```bash
time /spectacular:execute

# Measure:
# - Total execution time
# - Peak memory usage (monitor with htop)
# - Disk usage (du -sh .worktrees/)
# - Verify all 10 branches created
# - Verify linear chain in gs ls
```

## Why This Matters

**Real-world occurrence:**
- Large features may have 8-12 parallel implementation tasks
- Microservices might have 10+ parallel service implementations
- Validates spectacular can handle enterprise-scale features

**Performance validation:**
- Identifies algorithmic inefficiencies (O(N²) stacking would fail here)
- Tests resource limits before production usage
- Provides performance baseline for optimization

**User experience:**
- 10-task phase should feel fast, not sluggish
- Users shouldn't need to manually split into smaller phases
- Tooling should handle scale transparently

## Related Scenarios

- **parallel-stacking-4-tasks.md** - Previous largest test (N=4)
- **single-task-parallel-phase.md** - Smallest edge case (N=1)
- **task-failure-recovery.md** - Error handling scales to N=10

## Verification Commands

**Check loop-based worktree creation (scalable to N tasks):**

```bash
cd /Users/drewritter/projects/spectacular
grep -n "for.*worktree" commands/execute.md
grep -A5 "worktree add" commands/execute.md | grep -E "(for|while|loop)"
```

**Check array-based parallel execution:**

```bash
grep -n "parallel.*task" commands/execute.md
grep -A10 "spawn.*subagent" commands/execute.md | grep -E "(for|array|iterate)"
```

**Check linear stacking logic (no hardcoded task counts):**

```bash
grep -n "upstack onto" commands/execute.md
grep -B5 -A5 "upstack onto" commands/execute.md | grep -E "(for|loop|each|iterate)"
```

**Check cleanup loop (removes all worktrees):**

```bash
grep -n "worktree remove" commands/execute.md
grep -A5 "worktree remove" commands/execute.md | grep -E "(for|while|all)"
```

**Verify no hardcoded task limits:**

```bash
grep -E "(task-[0-9]|TASK_ID=[0-9])" commands/execute.md | grep -v "example"
grep -E "([1-9]0+|100|limit)" commands/execute.md | grep -i "task"
```

**Check scalability patterns (O(N) complexity):**

```bash
grep -n "O(N)" commands/execute.md
grep -B3 -A3 "linear" commands/execute.md | grep -i "time\|complexity\|scale"
```

**Verify resource management:**

```bash
grep -n "cleanup\|remove\|delete" commands/execute.md
grep -A5 "cleanup" commands/execute.md | grep -E "(all|every|complete)"
```

## Evidence of PASS

**Scales to N tasks without modification:**
- Worktree creation uses dynamic loop: `for TASK_ID in $(seq 1 $NUM_TASKS)`
- Parallel execution iterates over task array: `for task in "${PARALLEL_TASKS[@]}"`
- Stacking loops through all branches: `for i in $(seq 2 $NUM_TASKS)`
- Cleanup removes all worktrees: `for worktree in .worktrees/{runid}-task-*`

**No hardcoded task limits:**
- No explicit checks for `if NUM_TASKS > 10`
- No hardcoded task IDs (task-1, task-2, etc.) outside examples
- No maximum task count validation that fails for N=10
- Array operations work for any size

**Linear time complexity (O(N)):**
- Each worktree created independently (~1s per task)
- Each stacking operation is constant time (~1.5s per upstack)
- Total time = N × (worktree_time + stack_time + cleanup_time)
- No nested loops that multiply by task count

**Proper resource management:**
- All worktrees created in loop are also removed in loop
- Cleanup uses same pattern as creation (prevents orphaned worktrees)
- No resource accumulation (memory, file handles) as N increases
- Disk space reclaimed after cleanup (5GB → 50MB)

**Performance benchmarks met:**
- 10 worktrees created in < 10s (< 1s per worktree)
- 9 upstack operations in < 30s (< 3s per operation)
- 10 worktree removals in < 5s (< 0.5s per worktree)
- Total overhead < 1 minute for N=10

**Verification output shows:**
- `git worktree list | grep "{runid}-task-" | wc -l` returns 10
- `gs ls` shows linear chain of 10 branches
- `git branch | grep "{runid}-task-2-"` shows all 10 task branches
- No error messages about resource exhaustion

## Evidence of FAIL

**Hardcoded task limits:**
- Command contains explicit check: `if [ $NUM_TASKS -gt 5 ]; then error "Too many tasks"; fi`
- Worktree creation only handles tasks 1-5: `for TASK_ID in 1 2 3 4 5`
- Stacking logic assumes exactly 3 tasks: `upstack task-2 onto task-1; upstack task-3 onto task-2`
- Cleanup hardcoded: `git worktree remove .worktrees/{runid}-task-{1,2,3,4,5}`

**Quadratic time complexity (O(N²)):**
- Each stacking operation processes all previous tasks
- Task 10 takes 10× longer than task 1 (30s vs 3s)
- Total time = N × (N+1) / 2 operations
- Stacking 10 tasks takes 5+ minutes (not 30s)

**Resource exhaustion:**
- "Out of memory" error after spawning 8 subagents
- "Too many open files" error during worktree 9 creation
- Disk usage exceeds 10GB and doesn't cleanup
- Process count exceeds system limits (ulimit -u)

**Incomplete cleanup:**
- `git worktree list` shows 3 orphaned worktrees after cleanup
- Cleanup loop exits early on first error
- Disk usage remains at 5GB after completion
- Manual `git worktree prune` required to recover

**Performance degradation:**
- Worktree creation slows down: task 1 (0.5s) → task 10 (5s)
- Stacking time non-linear: tasks 1-3 (8s) → tasks 1-10 (120s)
- Total overhead exceeds 2 minutes for N=10
- System becomes unresponsive during parallel execution

**Error messages indicate:**
- `fatal: 'upstack' failed - stack too large`
- `error: unable to create worktree: resource temporarily unavailable`
- `warning: skipping cleanup for .worktrees/{runid}-task-8 (still in use)`
- `error: branch '{runid}-task-2-7' not found in repository`
