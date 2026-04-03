#!/bin/bash
# Dev-Team Hook: Orchestrator Commit Guard
# PreToolUse on Bash — SOFT WARNING
# The orchestrator must not run git commit/merge — only QA agents do this.

input=$(cat)

# Only active when dev-team is running
[ ! -d ".dev-team" ] && [ ! -f "dev-team-progress.md" ] && exit 0

cmd=$(echo "$input" | jq -r '.tool_input.command // ""' 2>/dev/null) || exit 0

# Check for git commit or git merge commands
case "$cmd" in
  *'git commit'*|*'git merge'*)
    jq -n '{"hookSpecificOutput":{"hookEventName":"PreToolUse","additionalContext":"DEV-TEAM COMMIT GUARD: If you are the dev-team ORCHESTRATOR/DISPATCHER, you must NOT run git commit or git merge directly — only QA agents handle commits and merges after independent verification. This ensures the quality gate: code enters the repository only after QA approval. | If you are a QA agent performing verification, IGNORE this message and proceed with the commit/merge."}}'
    ;;
esac
