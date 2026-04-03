#!/bin/bash
# Dev-Team Hook: Dispatcher Search Guard
# PreToolUse on Grep|Glob — SOFT WARNING
# The orchestrator must not search the codebase — PM and TL do exploration.

cat > /dev/null  # consume stdin (not needed for this check)

# Only active when dev-team is running
[ ! -d ".dev-team" ] && [ ! -f "dev-team-progress.md" ] && exit 0

jq -n '{"hookSpecificOutput":{"hookEventName":"PreToolUse","additionalContext":"DEV-TEAM DISPATCHER GUARD: If you are the dev-team ORCHESTRATOR/DISPATCHER, you must NOT search the codebase with Grep/Glob — this pollutes your context window with implementation details. Spawn a subagent (PM or TL) for codebase exploration. | If you are a TEAM MEMBER agent (PM, TL, Engineer, QA, Consultant), IGNORE this message and proceed."}}'
