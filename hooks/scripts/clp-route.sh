#!/usr/bin/env bash
# CLP Task Router — Classifies prompts and outputs delegation hints
set -euo pipefail

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-.}"
CLP_DIR="$PROJECT_DIR/.claude/clp"

# Check if routing is enabled
if [ -f "$CLP_DIR/manifest.json" ]; then
  ENABLED=$(jq -r 'if .tool_optimization.routing_enabled == false then "false" else "true" end' "$CLP_DIR/manifest.json" 2>/dev/null || echo "true")
  [ "$ENABLED" = "false" ] && exit 0
fi

INPUT=$(cat)
MSG=$(echo "$INPUT" | jq -r '.user_message // ""' 2>/dev/null || echo "")
[ -z "$MSG" ] && exit 0

MSG_LOWER=$(echo "$MSG" | tr '[:upper:]' '[:lower:]')

# Task classification with word-boundary matching
# Priority order: debug > implement > refactor > explore > review
TASK_TYPE=""
DELEGATION=""
MAIN_CTX=""
EST_BUDGET=""

# Debug patterns
if echo "$MSG_LOWER" | grep -qwE 'fix|broken|error|failing|bug'; then
  TASK_TYPE="debug"
  DELEGATION="Explore relevant files and trace error path via subagent"
  MAIN_CTX="Apply fix once root cause is identified"
  EST_BUDGET="~15K working zone"
# Implement patterns
elif echo "$MSG_LOWER" | grep -qwE 'add|create|build|write'; then
  TASK_TYPE="implement"
  DELEGATION="Explore target area via subagent before coding"
  MAIN_CTX="Implementation stays in main context"
  EST_BUDGET="~25K working zone"
# Refactor patterns
elif echo "$MSG_LOWER" | grep -qwE 'refactor|simplify|rename' || echo "$MSG_LOWER" | grep -qF 'clean up'; then
  TASK_TYPE="refactor"
  DELEGATION="Explore current structure via subagent first"
  MAIN_CTX="Apply refactoring in main context"
  EST_BUDGET="~20K working zone"
# Explore patterns
elif echo "$MSG_LOWER" | grep -qwE 'find|explain' || echo "$MSG_LOWER" | grep -qF 'how does' || echo "$MSG_LOWER" | grep -qF 'where is' || echo "$MSG_LOWER" | grep -qF 'what is'; then
  TASK_TYPE="explore"
  DELEGATION="Heavy subagent delegation for exploration"
  MAIN_CTX="Receive and synthesize subagent findings"
  EST_BUDGET="~5K working zone"
# Review patterns
elif echo "$MSG_LOWER" | grep -qwE 'review|pr' || echo "$MSG_LOWER" | grep -qF 'look at' || echo "$MSG_LOWER" | grep -qE 'check .* code'; then
  TASK_TYPE="review"
  DELEGATION="Delegate to review subagent"
  MAIN_CTX="Synthesize review findings"
  EST_BUDGET="~10K working zone"
fi

if [ -n "$TASK_TYPE" ]; then
  printf 'CLP Route: %s\nDelegation: %s\nMain context: %s\nEstimated budget: %s' \
    "$TASK_TYPE" "$DELEGATION" "$MAIN_CTX" "$EST_BUDGET" | \
    jq -Rs '{hookSpecificOutput:{additionalContext:.}}'
fi
exit 0
