#!/bin/bash
# Dev-Team Hook: Output Protocol + Progress Reminder
# PostToolUse on Agent — SOFT WARNING
# Checks two things:
# 1. Agent output length — should be a 1-line status, not full analysis
# 2. After meaningful events (OK/PASS/FAIL), reminds to update progress file

input=$(cat)

# Only active when dev-team is running
[ ! -d ".dev-team" ] && [ ! -f "dev-team-progress.md" ] && exit 0

# Extract agent output (handle both string and nested formats)
output=$(echo "$input" | jq -r '
  if (.tool_output | type) == "string" then .tool_output
  elif (.tool_output.content | type) == "string" then .tool_output.content
  else (.tool_output | tostring)
  end // ""
' 2>/dev/null | head -c 5000) || exit 0

len=${#output}
msgs=""

# Check 1: Output protocol — agents should return 1-line status, not full analysis
if [ "$len" -gt 500 ]; then
  msgs="OUTPUT PROTOCOL VIOLATION: Agent returned ${len} chars. Expected a 1-line status (OK/FAIL/PASS + key info). The agent may not have written its full output to a .dev-team/ file. Do NOT relay this content to other agents — always pass file paths instead."
fi

# Check 2: Progress reminder after meaningful events
first_line=$(echo "$output" | head -1)
if echo "$first_line" | grep -qiE "^(PASS|OK|FAIL|GAPS|SKIP)"; then
  reminder="REMINDER: Update dev-team-progress.md now — record the task status change and append a log entry."
  if [ -n "$msgs" ]; then
    msgs="$msgs | $reminder"
  else
    msgs="$reminder"
  fi
fi

# Check 3: Warn if progress file doesn't exist but should (after PM returns)
if echo "$first_line" | grep -qiE "^OK.*tasks" && [ ! -f "dev-team-progress.md" ]; then
  create_msg="ACTION REQUIRED: PM completed. Create dev-team-progress.md NOW with the backlog table and initial log entry."
  if [ -n "$msgs" ]; then
    msgs="$msgs | $create_msg"
  else
    msgs="$create_msg"
  fi
fi

if [ -n "$msgs" ]; then
  jq -n --arg m "DEV-TEAM: $msgs" \
    '{"hookSpecificOutput":{"hookEventName":"PostToolUse","additionalContext":$m}}'
fi
