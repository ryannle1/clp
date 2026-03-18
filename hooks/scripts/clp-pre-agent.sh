#!/usr/bin/env bash
# CLP Pre-Agent Logger — Logs subagent delegations to JSONL
set -euo pipefail

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-.}"
CLP_DIR="$PROJECT_DIR/.claude/clp"
LOG_FILE="$CLP_DIR/delegation-log.jsonl"

INPUT=$(cat)
SUBAGENT_TYPE=$(echo "$INPUT" | jq -r '.tool_input.subagent_type // "general"' 2>/dev/null || echo "general")
DESCRIPTION=$(echo "$INPUT" | jq -r '.tool_input.description // "no description"' 2>/dev/null || echo "no description")
PROMPT_SUMMARY=$(echo "$INPUT" | jq -r '.tool_input.prompt // "" | .[0:100]' 2>/dev/null || echo "")

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
