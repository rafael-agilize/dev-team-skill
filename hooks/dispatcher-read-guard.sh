#!/bin/bash
# Dev-Team Hook: Dispatcher Read Guard
# PreToolUse on Read — SOFT WARNING (additionalContext, not a block)
# Warns when Read is used during dev-team. The orchestrator must not fill its
# context with source code — that's what subagents are for.
# Subagents also see this hook, so the message includes a conditional instruction.

input=$(cat)

# Only active when dev-team is running
[ ! -d ".dev-team" ] && [ ! -f "dev-team-progress.md" ] && exit 0

# Allow reading dev-team internal files and meta files
fp=$(echo "$input" | jq -r '.tool_input.file_path // ""' 2>/dev/null) || exit 0
case "$fp" in
  *dev-team-progress.md) exit 0 ;;
  */.dev-team/*) exit 0 ;;
  */.claude/*|*/CLAUDE.md) exit 0 ;;
  */MEMORY.md|*/memory/*) exit 0 ;;
  */.gitignore) exit 0 ;;
esac

jq -n '{"hookSpecificOutput":{"hookEventName":"PreToolUse","additionalContext":"DEV-TEAM DISPATCHER GUARD: If you are the dev-team ORCHESTRATOR/DISPATCHER, you must NOT read source files — your context window is reserved for orchestration state only. Spawn a subagent (PM, TL, or Engineer) to read files instead. Use Bash only for dev-team-progress.md. | If you are a TEAM MEMBER agent (PM, TL, Engineer, QA, Consultant), IGNORE this message entirely and proceed with your work."}}'
