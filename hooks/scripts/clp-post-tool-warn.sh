#!/usr/bin/env bash
# CLP Post-Tool Warning — Warns when tool output is large
set -euo pipefail

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-.}"
CLP_DIR="$PROJECT_DIR/.claude/clp"

INPUT=$(cat)
OUTPUT_LEN=$(echo "$INPUT" | jq -r '.tool_output | tostring | length' 2>/dev/null || echo "0")
[ "$OUTPUT_LEN" -eq 0 ] && exit 0

# Skip manifest read for small outputs (fast path for common case)
# Read threshold from manifest; skip manifest read for tiny outputs (common case)
THRESHOLD=8000
if [ -f "$CLP_DIR/manifest.json" ]; then
  THRESHOLD=$(jq -r '.tool_optimization.output_trim_threshold // 8000' "$CLP_DIR/manifest.json" 2>/dev/null || echo "8000")
fi

# Skip if below threshold
[ "$OUTPUT_LEN" -le "$THRESHOLD" ] && exit 0

DOUBLE=$((THRESHOLD * 2))
EST_TOKENS=$((OUTPUT_LEN / 4))  # ~4 chars per token estimate

if [ "$OUTPUT_LEN" -gt "$DOUBLE" ]; then
  MSG="[CLP WARNING: ${OUTPUT_LEN}ch (~${EST_TOKENS}t). Delegate similar reads to subagents.]"
  echo "$MSG" | jq -Rs '{hookSpecificOutput:{additionalContext:.}}'
elif [ "$OUTPUT_LEN" -gt "$THRESHOLD" ]; then
  MSG="[CLP: ${OUTPUT_LEN}ch (~${EST_TOKENS}t). Extract key info now, do not re-read.]"
  echo "$MSG" | jq -Rs '{hookSpecificOutput:{additionalContext:.}}'
fi
exit 0
