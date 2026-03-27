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
  +---------+     +-----------+     +------+
  |Tech Lead| --> | Engineer  | --> |  QA  |
  +---------+     +-----------+     +------+
  Reads files,     TDD: tests       Runs tests,
  writes brief     first, then      verifies AC,
                   implement        commits if pass
       |
       | (if QA fails: new Tech Lead -> new Engineer -> QA again)
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

**Step B — Engineer** implements using strict TDD:
- Writes failing tests FIRST
- Implements until all tests pass
- Reports files changed, test output, and any concerns
- Does NOT commit — that's QA's job

**Step C — QA** independently verifies:
- Runs the full test suite for affected packages
- Checks TDD compliance (test files exist with meaningful assertions)
- Verifies every acceptance criterion is covered
- **Commits only if everything passes** (atomic, scoped commits)
- If tests fail: returns a detailed failure report with root cause analysis

### Fix Cycles

If QA reports failures, the dispatcher spawns a **new** Tech Lead to re-read the current state of files (they may have changed), produce an updated brief incorporating the failure report, and then a new Engineer implements the fix. This cycle repeats until the task passes.

**There is no fix limit.** The team delivers.

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

### Engineers Are Transient

Each engineer agent is spawned fresh with zero prior context. This prevents:
- Context pollution from previous tasks
- Stale state from earlier implementations
- Scope creep from accumulated understanding

When a fix is needed, a completely new engineer is spawned — never a continuation of the previous one.

### The Orchestrator Never Reads Code

The dispatcher's context window is the orchestration bus. Filling it with file contents would destroy its ability to track task state across many concurrent agents. Code analysis belongs in the agents' context windows, not the orchestrator's.

---

## Concurrency

The skill supports up to **10 simultaneous agents**. The dispatcher tracks active slots:

```
Active: [TL-TASK1, Engineer-TASK2, QA-TASK3] = 3 slots
Free: 7 -> can spawn 7 more
```

**Parallel strategy:**
- Independent tasks: spawn multiple Tech Leads simultaneously
- As briefs come back, spawn Engineers immediately
- As Engineers finish, spawn QA immediately
- Dependent tasks: execute sequentially
- Fill available slots aggressively — start the next task while waiting for QA on the current one

---

## Installation

### As a Claude Code Skill

Copy the `SKILL.md` file to your Claude Code skills directory:

```bash
mkdir -p ~/.claude/skills/dev-team
cp SKILL.md ~/.claude/skills/dev-team/SKILL.md
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
  SKILL.md            # The skill definition (install this)
  README.md           # This file
  evals/
    evals.json        # Evaluation test cases
  LICENSE             # MIT License
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
| Test discipline | Tests when asked | TDD enforced on every task |
| Task decomposition | Ad hoc | Structured backlog with dependencies |
| Parallelism | Sequential by default | Up to 10 concurrent agents |
| Scope control | Can drift | Engineers scoped to single tasks, spawned fresh |

---

## License

MIT
