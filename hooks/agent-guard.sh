#!/bin/bash
# Dev-Team Hook: Agent Model Assignment + Worktree Isolation + Sequencing Guard
# PreToolUse on Agent — HARD BLOCK
# Safe: only the orchestrator spawns agents in the dev-team workflow.
set -euo pipefail

input=$(cat)

# Only active when dev-team is running
[ ! -d ".dev-team" ] && [ ! -f "dev-team-progress.md" ] && exit 0

# Extract fields (fail silently if jq fails)
model=$(echo "$input" | jq -r '.tool_input.model // "unset"' 2>/dev/null) || exit 0
isolation=$(echo "$input" | jq -r '.tool_input.isolation // "none"' 2>/dev/null) || exit 0
prompt_lower=$(echo "$input" | jq -r '.tool_input.prompt // ""' 2>/dev/null | tr '[:upper:]' '[:lower:]' | head -c 4000) || exit 0

# --- Detect role from prompt keywords ---
role=""
expected_model=""

if echo "$prompt_lower" | grep -q "product manager"; then
  role="PM"; expected_model="opus"
elif echo "$prompt_lower" | grep -q "senior engineer consultant\|senior consultant"; then
  role="CONSULTANT"; expected_model="opus"
elif echo "$prompt_lower" | grep -q "tech lead"; then
  role="TL"; expected_model="sonnet"
elif echo "$prompt_lower" | grep -q "isolated git worktree\|you are a senior software engineer"; then
  role="ENGINEER"; expected_model="sonnet"
elif echo "$prompt_lower" | grep -q "qa engineer\|qa.*verify that"; then
  role="QA"; expected_model="sonnet"
elif echo "$prompt_lower" | grep -q "final review\|performing a final review"; then
  role="FINAL_REVIEW"; expected_model="sonnet"
elif echo "$prompt_lower" | grep -q "database migration specialist"; then
  role="DB_MIGRATION"; expected_model="sonnet"
fi

# No recognized dev-team role — skip all checks
[ -z "$role" ] && exit 0

# --- Check 1: Model assignment ---
if [ "$model" = "unset" ]; then
  jq -n --arg r "$role" --arg e "$expected_model" \
    '{"decision":"block","reason":"DEV-TEAM MODEL POLICY: \($r) agent spawned without explicit model parameter. Required: model=\"\($e)\". PM and Senior Consultant use opus; TL, Engineer, QA, and Final Review use sonnet."}'
  exit 0
fi

if [ "$model" != "$expected_model" ]; then
  jq -n --arg r "$role" --arg e "$expected_model" --arg m "$model" \
    '{"decision":"block","reason":"DEV-TEAM MODEL POLICY: \($r) requires model=\"\($e)\", but got model=\"\($m)\". Fix: PM+Consultant=opus, TL+Engineer+QA+FinalReview+DB=sonnet."}'
  exit 0
fi

# --- Check 2: Worktree isolation for engineers ---
if [ "$role" = "ENGINEER" ] && [ "$isolation" != "worktree" ]; then
  jq -n '{"decision":"block","reason":"DEV-TEAM ISOLATION POLICY: Engineer agents MUST run in a git worktree (isolation: \"worktree\"). Worktrees enable parallel safety and protect the main branch from broken code."}'
  exit 0
fi

# --- Check 3: Sequencing — backlog must exist before TL/Engineer/QA ---
if [ "$role" = "TL" ] || [ "$role" = "ENGINEER" ] || [ "$role" = "QA" ] || [ "$role" = "FINAL_REVIEW" ]; then
  if [ ! -f ".dev-team/backlog.md" ]; then
    jq -n --arg r "$role" \
      '{"decision":"block","reason":"DEV-TEAM SEQUENCING: Cannot spawn \($r) — .dev-team/backlog.md does not exist. The PM agent must complete first and produce the backlog before task execution begins."}'
    exit 0
  fi
fi

# --- Check 4: Brief must exist before Engineer/QA (extract task number) ---
if [ "$role" = "ENGINEER" ] || [ "$role" = "QA" ]; then
  # Try to extract task number from prompt (e.g., "TASK-1", "TASK-2")
  task_num=$(echo "$prompt_lower" | grep -oE 'task-[0-9]+' | head -1)
  if [ -n "$task_num" ]; then
    brief_file=".dev-team/brief-${task_num^^}.md"  # uppercase TASK-N
    # Also check lowercase variant
    brief_lower=".dev-team/brief-${task_num}.md"
    if [ ! -f "$brief_file" ] && [ ! -f "$brief_lower" ]; then
      jq -n --arg r "$role" --arg t "${task_num^^}" --arg b "$brief_file" \
        '{"decision":"block","reason":"DEV-TEAM SEQUENCING: Cannot spawn \($r) for \($t) — brief file \($b) not found. The Tech Lead must produce the brief before the Engineer/QA can start."}'
      exit 0
    fi
  fi
fi
