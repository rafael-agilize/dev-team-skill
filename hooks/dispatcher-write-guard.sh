#!/bin/bash
# Dev-Team Hook: Dispatcher Write Guard
# PreToolUse on Write|Edit — SOFT WARNING
# The orchestrator must not write/edit code — Engineers handle implementation.
# Only dev-team-progress.md (via Bash heredoc) and .gitignore are allowed.

input=$(cat)

# Only active when dev-team is running
[ ! -d ".dev-team" ] && [ ! -f "dev-team-progress.md" ] && exit 0

# Allow writing dev-team internal files
fp=$(echo "$input" | jq -r '.tool_input.file_path // ""' 2>/dev/null) || exit 0
case "$fp" in
  */.dev-team/*|*dev-team-progress.md|*/.gitignore) exit 0 ;;
esac

jq -n '{"hookSpecificOutput":{"hookEventName":"PreToolUse","additionalContext":"DEV-TEAM DISPATCHER GUARD: If you are the dev-team ORCHESTRATOR/DISPATCHER, you must NOT write/edit files directly — Engineers handle all implementation in isolated worktrees. Use Bash heredoc only for dev-team-progress.md. | If you are a TEAM MEMBER agent (PM, TL, Engineer, QA, Consultant), IGNORE this message and proceed."}}'
