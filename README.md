# Dev Team Skill for Claude Code

**An autonomous development team orchestrator that spawns specialized AI agents to build features and fix bugs end-to-end using strict Test-Driven Development.**

---

## What Is This?

The **Dev Team** skill turns Claude Code into a full autonomous development team. Instead of a single AI assistant doing everything in one context window, this skill spawns **four specialized agent roles** — each with its own fresh context, focused responsibility, and no shared state — to deliver production-quality code with full test coverage.

You describe what you want built or fixed. The skill handles the rest: codebase analysis, task breakdown, engineering briefs, TDD implementation, independent QA verification, and atomic commits.

---

## How It Works

### The Core Idea: Pure Dispatcher Architecture

The orchestrator (Claude Code's main context) acts as a **pure dispatcher** — it never reads files, writes code, or analyzes anything directly. Every piece of work happens inside spawned subagents. This is a deliberate architectural choice:

- The orchestrator's context window stays clean for tracking task state across many agents
- Each agent gets exactly the context it needs and nothing more
- No single agent becomes a bottleneck or context-pollution risk

### The Team

| Role | Responsibility | Context Strategy |
|------|---------------|-----------------|
| **Product Manager (PM)** | Explores the codebase, understands the requirement, produces a structured backlog of small testable tasks | Broad exploration — reads CLAUDE.md, scans related files, maps architecture |
| **Tech Lead (TL)** | Reads all relevant source files for a specific task and produces a complete, self-contained engineering brief | Deep and focused — reads every file the engineer will need, pastes full contents |
| **Engineer** | Receives the brief, writes failing tests first, then implements until tests pass | Zero prior context — works only from the brief, clean slate every time |
| **QA** | Runs tests independently, verifies acceptance criteria, commits if passing | Independent verification — no bias from having written the code |

### Why Separate Agents?

Each role is a **separate subagent** spawned via Claude Code's `Agent` tool. This means:

1. **No context pollution**: The PM's broad codebase scan doesn't crowd out the engineer's focused implementation work
2. **Independent verification**: QA has never seen the code before — it verifies from scratch, catching assumptions the engineer might have baked in
3. **Transient engineers**: Each engineer is spawned fresh per task. No stale state, no scope creep, no accumulated context from previous tasks
4. **Parallel execution**: Up to 10 agents can run simultaneously, with independent tasks processed in parallel

---

## Execution Flow

```
User Requirement
       |
       v
  +---------+
  |   PM    |  Phase 1: Analyze codebase, create structured backlog
  +---------+
       |
       v
  For each task (respecting dependencies):
       |
       v
  +---------+     +--worktree--+     +------+
  |Tech Lead| --> | Engineer   | --> |  QA  |
  +---------+     | (isolated) |     +------+
  Reads files,    +------------+     Verifies in
  writes brief     TDD: tests        worktree,
                   first, then        commits,
                   implement          merges to main
       |
       | (if QA fails: new Tech Lead -> new Engineer worktree -> QA again)
       v
  +---------+
  |  Final  |  Phase 3: Run full test suite, verify all requirements met
  | Review  |
  +---------+
       |
       v
  Done (or loop back for gaps)
```

### Phase 1 — Product Manager Analysis

The PM agent is spawned first. It:

1. Reads the project's `CLAUDE.md` to learn the stack, conventions, and test commands
2. Explores the codebase — reads files related to the requirement
3. Creates a **structured backlog** of small, independently testable tasks
4. Produces a **context dump** — complete file contents, interfaces, types, and patterns that engineers will need

Each task in the backlog includes:
- **What**: Clear description
- **Acceptance Criteria**: Specific, testable checkboxes
- **Relevant Files**: Full paths to read and/or modify
- **Dependencies**: Which tasks must complete first
- **Tests Required**: Unit specs + Cypress E2E (if UI-facing)

### Phase 2 — Task Execution Pipeline

For each task, three agents are spawned sequentially:

**Step A — Tech Lead** prepares a self-contained engineering brief:
- Reads ALL relevant files (not just paths — full contents)
- Includes existing test patterns so the engineer matches the style
- Specifies exact TDD workflow, file paths, and test commands
- Documents what NOT to do (scope boundaries)

**Step B — Engineer** implements in an **isolated git worktree** (`isolation: "worktree"`):
- Gets a fresh, isolated copy of the repository — no conflicts with other parallel engineers
- Writes failing tests FIRST
- Implements until all tests pass
- Reports files changed, test output, worktree path/branch, and any concerns
- Does NOT commit — that's QA's job

**Step C — QA** independently verifies **in the engineer's worktree**:
- `cd`s into the worktree to run tests in the engineer's isolated environment
- Runs the full test suite for affected packages
- Checks TDD compliance (test files exist with meaningful assertions)
- Verifies every acceptance criterion is covered
- **If tests pass:** commits in the worktree, merges the branch back to main (`--no-ff`), and cleans up the worktree
- **If tests fail:** returns a detailed failure report with root cause analysis (worktree preserved for fix cycle)

### Escalation Ladder — Fully Autonomous Delivery

The team must deliver without blocking on human input. When QA fails:

**Level 1: Sonnet Retries (attempts 1-3)** — New TL reads the QA failure report + current codebase state, produces updated brief, new Engineer in fresh worktree, QA again.

**Level 2: Senior Consultant (after every 3 failures)** — An opus-level Senior Engineer Consultant reads ALL failure reports, the codebase, and the original brief. Produces a corrective diagnosis with exact guidance. The next TL+Engineer cycle must follow this guidance.

**Level 3: Repeat** — The pattern cycles: every 3 sonnet failures trigger a new consultant round with access to all prior failures and prior consultant guidance.

**Emergency Valve** — After 3 consultant rounds (~12 attempts), the task is marked SKIPPED and remaining tasks continue. The user gets maximum delivered work, not a stalled pipeline.

```
Attempts 1-3:   sonnet TL -> sonnet Eng -> sonnet QA
                | (3 fails)
Consultant R1:  opus diagnosis -> corrective guidance
Attempts 4-6:   sonnet TL (with R1 guidance) -> sonnet Eng -> sonnet QA
                | (3 more fails)
Consultant R2:  opus (reads R1 + all failures) -> refined guidance
                ... and so on until delivery or skip
```

### Phase 3 — Final Review

After all tasks are complete, a Final Review agent:
1. Verifies each task resulted in a commit (`git log`)
2. Runs the complete test suite across all packages
3. Reads modified files to verify the implementation matches the original requirement
4. Reports any gaps — which trigger new tasks back in Phase 2

---

## Key Design Decisions

### QA Commits, Not Engineers

This is a deliberate **quality gate**. Code only enters the repository after independent verification. The engineer who wrote the code is never the one who commits it.

### TDD Is Non-Negotiable

Every task follows test-first development. If an engineer returns work without tests, the dispatcher flags it and spawns a new engineer to write the missing tests. This ensures coverage from the start, not as an afterthought.

### Engineers Work in Git Worktrees

Each engineer agent is spawned with `isolation: "worktree"`, giving it a completely isolated copy of the repository. This is the git equivalent of a per-task staging environment:

1. **True parallel safety** — multiple engineers can modify the same files simultaneously without conflicts, because each works in its own worktree
2. **Main branch protection** — broken or incomplete work never touches the main working tree; it only merges after QA passes
3. **Clean rollback** — if an engineer's work fails QA, the worktree can be discarded with zero cleanup on the main branch
4. **Sequential merges** — QA merges one worktree at a time to avoid merge conflicts on main

The QA agent verifies inside the worktree, commits there, then merges the worktree branch back to main with `--no-ff` (preserving merge history) before cleaning up.

### Engineers Are Transient

Each engineer agent is spawned fresh with zero prior context. This prevents:
- Context pollution from previous tasks
- Stale state from earlier implementations
- Scope creep from accumulated understanding

When a fix is needed, a completely new engineer is spawned — never a continuation of the previous one.

### The Orchestrator Never Reads Code

The dispatcher's context window is the orchestration bus. Filling it with file contents would destroy its ability to track task state across many concurrent agents. Code analysis belongs in the agents' context windows, not the orchestrator's.

### File-Based Inter-Agent Communication

Agents communicate through **files on disk** in the `.dev-team/` directory, not through the orchestrator. Each agent writes its full output to a file and returns only a 1-line status. The orchestrator passes file paths between agents — never pastes contents. This is what enables long-running sessions without context exhaustion.

### Model Assignments

Not all roles need the same capability level:
- **PM + Senior Consultant** use `opus` — deep reasoning for requirement decomposition and stuck-task diagnosis
- **TL + Engineer + QA + Final Review** use `sonnet` — fast, focused execution

This is enforced by the Agent Guard hook — wrong model assignments are hard-blocked.

### Progress Persistence

`dev-team-progress.md` tracks all task state, commit SHAs, and an append-only event log. If the session is interrupted (context limit, timeout, user break), the orchestrator reads this file on resume and picks up exactly where it left off — no re-planning, no duplicate work.

---

## Concurrency

The skill supports up to **10 simultaneous agents**. The dispatcher tracks active slots:

```
Active: [TL-TASK1, Engineer-TASK2, QA-TASK3] = 3 slots
Free: 7 -> can spawn 7 more
```

**Parallel strategy:**
- Independent tasks: spawn multiple Tech Leads simultaneously
- As briefs come back, spawn Engineers immediately — **each in its own worktree**, so they can't conflict
- As Engineers finish, spawn QA immediately
- Dependent tasks: execute sequentially (QA must merge TASK-N before the next task's Tech Lead reads the codebase)
- QA merges are sequential (one at a time) to avoid merge conflicts on main
- Fill available slots aggressively — start the next task while waiting for QA on the current one

---

## Enforcement Hooks

The skill includes **8 Claude Code hooks** that mechanically enforce the dev-team protocol — not just as conventions in the skill prompt, but as infrastructure-level guardrails. The hooks are **dormant by default** and only activate when `.dev-team/` directory or `dev-team-progress.md` exists (i.e., when the dev-team skill is running).

### Hook Architecture

A key design challenge: hooks fire for ALL Claude processes — both the orchestrator and its subagents (PM, TL, Engineer, QA). The **Agent tool is only used by the orchestrator**, so Agent hooks can safely hard-block. For Read/Write/Grep/Glob/Bash, subagents also use them, so those hooks use **conditional soft warnings** with "if you are a team member agent, IGNORE this" phrasing.

| # | Hook | Trigger | Type | Enforces |
|---|------|---------|------|----------|
| 1 | Agent Guard | `PreToolUse:Agent` | HARD BLOCK | Model assignments, worktree isolation, sequencing |
| 2 | Dispatcher Read Guard | `PreToolUse:Read` | Soft warn | Orchestrator must not read source files |
| 3 | Dispatcher Search Guard | `PreToolUse:Grep\|Glob` | Soft warn | Orchestrator must not search codebase |
| 4 | Dispatcher Write Guard | `PreToolUse:Write\|Edit` | Soft warn | Orchestrator must not write code |
| 5 | Commit Guard | `PreToolUse:Bash` | Soft warn | Only QA agents commit/merge |
| 6 | Output Protocol Guard | `PostToolUse:Agent` | Soft warn | Agents return 1-line status + progress reminders |
| 7 | TDD Source Guard | `PreToolUse:Write\|Edit` | Soft warn | Test file must exist before source file |
| 8 | TDD Commit Guard | `PreToolUse:Bash` | HARD BLOCK | Commits must include test files |

### Hook 1: Agent Guard (HARD BLOCK)

The most critical hook. Performs 4 checks before any agent is spawned:

**Model Assignment** — Detects role from prompt keywords and enforces:
- PM, Senior Consultant → `model: "opus"` (deep reasoning)
- TL, Engineer, QA, Final Review → `model: "sonnet"` (fast execution)
- Blocks if model is missing or wrong

**Worktree Isolation** — Engineer agents MUST have `isolation: "worktree"`. Blocks if missing.

**Backlog Sequencing** — TL/Engineer/QA/Final Review blocked if `.dev-team/backlog.md` doesn't exist (PM must complete first).

**Brief Sequencing** — Engineer/QA blocked if `.dev-team/brief-TASK-N.md` doesn't exist for their task (TL must complete first).

### Hooks 2-4: Dispatcher Purity Guards (Soft Warnings)

These protect the orchestrator's context window — its most precious resource:

- **Read Guard**: Warns when reading source files (allows `dev-team-progress.md`, `.dev-team/*`, `CLAUDE.md`, `.claude/*`)
- **Search Guard**: Warns when using Grep/Glob for codebase exploration
- **Write Guard**: Warns when using Write/Edit on source files (allows `.dev-team/*`, `.gitignore`)

Each warning includes conditional language: team member agents (PM, TL, Engineer, QA) are explicitly told to ignore the message.

### Hook 5: Commit Guard (Soft Warning)

Warns when `git commit` or `git merge` is detected in a Bash command. The orchestrator must never commit — only QA agents do. QA agents are told to ignore the warning.

### Hook 6: Output Protocol Guard (Soft Warning)

Fires after each Agent tool returns. Checks three things:

1. **Output length** — Flags responses >500 chars. Agents should return a 1-line status (e.g., `OK 5 tasks`, `PASS merged abc1234`, `FAIL see .dev-team/qa-TASK-1.md`) and write full output to disk.
2. **Progress reminder** — After OK/PASS/FAIL responses, reminds to update `dev-team-progress.md`.
3. **Progress creation** — After PM returns (detected by `OK N tasks` pattern), warns if `dev-team-progress.md` doesn't exist yet.

### Hooks 7-8: TDD Enforcement (Existing)

**Hook 7: Test File Must Exist First** (`Write|Edit`)
- Checks if a `.ts`/`.tsx` source file in `packages/*/src/` has a corresponding `.spec.ts`/`.spec.tsx`
- Injects TDD policy warning if no test file exists

**Hook 8: Tests Must Be Staged** (`Bash` — HARD BLOCK)
- Detects `git commit` commands
- Blocks if source files are staged without any test files (`.spec.ts`/`.spec.tsx`/`.cy.ts`)

### How All Layers Work Together

| Layer | Mechanism | What It Catches |
|-------|-----------|----------------|
| **Skill prompt** | Instructions in agent prompts | Normal flow — agents follow protocol by design |
| **Agent Guard** | Hard blocks on Agent tool | Wrong model, missing worktree, broken sequencing |
| **Dispatcher Guards** | Soft warnings on Read/Write/Grep/Glob | Orchestrator polluting its context window |
| **Output Protocol** | Post-tool warning on Agent | Agents dumping full output instead of file paths |
| **Commit Guard** | Soft warning on Bash | Orchestrator attempting git commit/merge |
| **TDD Hooks** | Hard block on Write/Edit + Bash | Untested code entering the repository |

### Installing the Hooks

**Option A: User-level installation** (recommended — works across all projects):

```bash
# Install the skill + hooks
mkdir -p ~/.claude/skills/dev-team/hooks
cp SKILL.md ~/.claude/skills/dev-team/SKILL.md
cp hooks/*.sh ~/.claude/skills/dev-team/hooks/
chmod +x ~/.claude/skills/dev-team/hooks/*.sh

# Merge hook config into your user settings
# (manually merge hooks/settings.json into ~/.claude/settings.json)
```

**Option B: Project-level installation** (per-project):

```bash
# Copy hooks config to project settings
mkdir -p .claude
cp hooks/settings.json .claude/settings.json

# If .claude/settings.json already exists, merge manually or:
jq -s '.[0] * .[1]' .claude/settings.json hooks/settings.json > /tmp/merged.json \
  && mv /tmp/merged.json .claude/settings.json
```

### Customizing TDD Hooks

The TDD hooks (7 & 8) are configured for a **monorepo with `packages/backend/` and `packages/frontend/`**. To adapt:

1. **Source path pattern** — edit the `case` statement in Hook 7:
   ```bash
   # Default: */packages/backend/src/* | */packages/frontend/src/*
   # Single app: */src/*
   # Custom: */apps/api/src/* | */apps/web/src/*
   ```

2. **Staged file pattern** — edit the `grep -E` in Hook 8:
   ```bash
   # Default: ^packages/(backend|frontend)/src/
   # Single app: ^src/
   ```

3. **Test extensions** — add `.test.ts`, `.e2e.ts`, etc. by extending the `case`/`grep` patterns.

---

## Installation

### 1. Install the Skill

Copy the `SKILL.md` file to your Claude Code skills directory:

```bash
mkdir -p ~/.claude/skills/dev-team
cp SKILL.md ~/.claude/skills/dev-team/SKILL.md
```

### 2. Install the TDD Hooks

Copy or merge the hooks into your project:

```bash
# New project (no existing settings)
mkdir -p .claude
cp hooks/settings.json .claude/settings.json

# Existing project (merge hooks)
jq -s '.[0] * .[1]' .claude/settings.json hooks/settings.json > /tmp/merged.json \
  && mv /tmp/merged.json .claude/settings.json
```

### 3. (Optional) Install Evals

```bash
mkdir -p ~/.claude/skills/dev-team/evals
cp evals/evals.json ~/.claude/skills/dev-team/evals/evals.json
```

### Trigger Phrases

The skill activates when you say things like:
- "build this feature"
- "fix this bug"
- "dev-team"
- "I need the team to handle..."
- Any substantial development request that would benefit from structured team execution

You don't need to explicitly invoke `/dev-team` — Claude Code recognizes when a task warrants the full team approach.

---

## Evaluation Suite

The `evals/` directory contains test scenarios for validating the skill's behavior:

| ID | Scenario | What It Tests |
|----|----------|---------------|
| 1 | Fix a crash when `agent.description` is undefined | Simple 1-task bug fix flow — PM -> Engineer -> QA |
| 2 | Add "created at" timestamp to agent cards | Multi-concern feature (formatting utility + component update) |
| 3 | Build a delete confirmation dialog | Multi-task feature with new component + integration + E2E tests |

Run evals to verify the skill produces correct team behavior and task decomposition.

---

## Project Structure

```
dev-team-skill/
  SKILL.md                           # The skill definition (install to ~/.claude/skills/dev-team/)
  README.md                          # This file
  hooks/
    settings.json                    # Full hook config for .claude/settings.json
    agent-guard.sh                   # Model assignment + worktree + sequencing (HARD BLOCK)
    dispatcher-read-guard.sh         # Orchestrator source read prevention
    dispatcher-search-guard.sh       # Orchestrator codebase search prevention
    dispatcher-write-guard.sh        # Orchestrator code write prevention
    commit-guard.sh                  # QA-only commit/merge enforcement
    output-protocol-guard.sh         # Agent output protocol + progress reminders
  evals/
    evals.json                       # Evaluation test cases
  LICENSE                            # MIT License
```

---

## Requirements

- **Claude Code** CLI (with Agent tool support)
- A project with a `CLAUDE.md` file describing the stack and conventions
- Test infrastructure (the skill expects `pnpm test` or similar to work)

---

## How It Differs from Regular Claude Code

| Aspect | Regular Claude Code | Dev Team Skill |
|--------|-------------------|----------------|
| Context management | Single context window for everything | Separate context per role |
| Code quality gate | User reviews before commit | Independent QA agent verifies before commit |
| Test discipline | Tests when asked | TDD enforced on every task + hooks block untested code |
| Task decomposition | Ad hoc | Structured backlog with dependencies |
| Parallelism | Sequential by default | Up to 10 concurrent agents |
| Isolation | Works in main working tree | Each engineer in its own git worktree |
| Scope control | Can drift | Engineers scoped to single tasks, spawned fresh |
| Main branch safety | Changes land directly | Changes only merge after QA passes in worktree |

---

## License

MIT
