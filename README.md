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

### Fix Cycles

If QA reports failures, the dispatcher spawns a **new** Tech Lead to re-read the current state of files in the worktree, produce an updated brief incorporating the failure report, and then a new Engineer implements the fix in a fresh worktree. This cycle repeats until the task passes.

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

## TDD Enforcement Hooks

The skill includes **Claude Code hooks** that enforce TDD at the tool level — not just as a convention in the skill prompt, but as hard guardrails that prevent Claude from writing source code without tests or committing without test files staged.

These hooks live in `hooks/settings.json` and should be copied into your project's `.claude/settings.json`.

### Hook 1: Pre-Write/Edit — Test File Must Exist First

**Matcher:** `Write|Edit` (fires before any file creation or modification)

**What it does:**
1. Reads the file path Claude is about to write/edit
2. Checks if it's a source file inside `packages/backend/src/` or `packages/frontend/src/`
3. Skips if the file is itself a test (`.spec.ts`, `.spec.tsx`, `.cy.ts`) or a type declaration (`.d.ts`)
4. For any `.ts` or `.tsx` source file, checks whether a corresponding `.spec.ts` or `.spec.tsx` exists in the same directory
5. If no test file exists, **injects a TDD policy warning** into Claude's context telling it to create the test file first

**This means:** Claude literally cannot write implementation code for a source file that has no test file. It is forced to create the test first — true test-driven development enforced at the infrastructure level.

```
Trigger:  Write packages/backend/src/users/users.service.ts
Check:    Does packages/backend/src/users/users.service.spec.ts exist?
No:       "TDD POLICY: No test file found for users.service.ts.
           Write tests FIRST. Create the test file before implementing."
Yes:      Proceed normally
```

### Hook 2: Pre-Commit — Tests Must Be Staged

**Matcher:** `Bash` (fires before any bash command, filters for `git commit`)

**What it does:**
1. Detects if the bash command contains `git commit`
2. Inspects `git diff --cached --name-only` for staged files
3. Checks if any staged source files (`.ts`/`.tsx` in `packages/*/src/`, excluding test files) exist
4. Checks if any test files (`.spec.ts`, `.spec.tsx`, `.cy.ts`) are also staged
5. If source files are staged but **no test files** are staged, **blocks the commit entirely**

**This means:** No commit can enter the repository with source changes unless test changes are included. This catches the case where an engineer writes tests and source code, but only stages the source — the hook blocks it.

```
Staged:   packages/backend/src/users/users.service.ts     (source)
          packages/backend/src/users/users.controller.ts   (source)
Missing:  No .spec.ts or .cy.ts files staged
Result:   BLOCKED — "Stage test files before committing."
```

### How the Hooks Complement the Skill

The dev-team skill enforces TDD through **prompt instructions** — telling each Engineer agent to write tests first and having QA verify test existence. But prompts can be ignored or misinterpreted. The hooks add a **mechanical enforcement layer**:

| Layer | Mechanism | Catches |
|-------|-----------|---------|
| **Skill prompt** | "Write failing tests FIRST" instruction to Engineer agents | Normal flow — engineers follow TDD by instruction |
| **Hook 1** (Write/Edit) | Blocks source file creation if no test file exists | Engineers who skip ahead to implementation |
| **Hook 2** (Commit) | Blocks commits without test files staged | QA agents who try to commit incomplete work |

Together, these three layers make it nearly impossible for untested code to enter the repository.

### Installing the Hooks

Copy the hooks into your project's Claude Code settings:

```bash
# If .claude/settings.json doesn't exist yet
mkdir -p .claude
cp hooks/settings.json .claude/settings.json

# If .claude/settings.json already exists, merge the hooks manually
# or use jq to combine:
jq -s '.[0] * .[1]' .claude/settings.json hooks/settings.json > /tmp/merged.json \
  && mv /tmp/merged.json .claude/settings.json
```

### Customizing the Hooks

The hooks are configured for a **monorepo with `packages/backend/` and `packages/frontend/`** directories. To adapt them to your project structure:

1. **Change the source path pattern** — edit the `case` statement in Hook 1:
   ```bash
   # Default: */packages/backend/src/* | */packages/frontend/src/*
   # Single app: */src/*
   # Different structure: */apps/api/src/* | */apps/web/src/*
   ```

2. **Change the staged file pattern** — edit the `grep -E` in Hook 2:
   ```bash
   # Default: ^packages/(backend|frontend)/src/
   # Single app: ^src/
   # Different structure: ^apps/(api|web)/src/
   ```

3. **Add more test file extensions** — both hooks recognize `.spec.ts`, `.spec.tsx`, and `.cy.ts`. Add more patterns (e.g., `.test.ts`, `.e2e.ts`) by extending the `case`/`grep` patterns.

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
  SKILL.md            # The skill definition (install this)
  README.md           # This file
  hooks/
    settings.json     # TDD enforcement hooks for .claude/settings.json
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
| Test discipline | Tests when asked | TDD enforced on every task + hooks block untested code |
| Task decomposition | Ad hoc | Structured backlog with dependencies |
| Parallelism | Sequential by default | Up to 10 concurrent agents |
| Isolation | Works in main working tree | Each engineer in its own git worktree |
| Scope control | Can drift | Engineers scoped to single tasks, spawned fresh |
| Main branch safety | Changes land directly | Changes only merge after QA passes in worktree |

---

## License

MIT
