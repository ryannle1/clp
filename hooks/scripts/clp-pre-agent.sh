#!/usr/bin/env bash
# CLP Pre-Agent Logger — Logs subagent delegations to JSONL
set -euo pipefail

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-.}"
CLP_DIR="$PROJECT_DIR/.claude/clp"
LOG_FILE="$CLP_DIR/delegation-log.jsonl"

INPUT=$(cat)

# Single jq call to extract all fields
eval "$(echo "$INPUT" | jq -r '
  "SUBAGENT_TYPE=" + (.tool_input.subagent_type // "general" | @sh) +
  " DESCRIPTION=" + (.tool_input.description // "no description" | @sh) +
  " PROMPT_SUMMARY=" + ((.tool_input.prompt // "")[0:100] | @sh)
' 2>/dev/null || echo 'SUBAGENT_TYPE=general DESCRIPTION="no description" PROMPT_SUMMARY=""')"

# Check if delegation logging is enabled (default true)
LOGGING=true
if [ -f "$CLP_DIR/manifest.json" ]; then
  LOGGING=$(jq -r '.tool_optimization.delegation_logging // true' "$CLP_DIR/manifest.json" 2>/dev/null || echo "true")
fi

if [ "$LOGGING" = "true" ]; then
  mkdir -p "$CLP_DIR"
  jq -nc --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
         --arg type "$SUBAGENT_TYPE" \
         --arg desc "$DESCRIPTION" \
         --arg summary "$PROMPT_SUMMARY" \
    '{timestamp: $ts, subagent_type: $type, description: $desc, prompt_summary: $summary}' >> "$LOG_FILE"
fi
exit 0
