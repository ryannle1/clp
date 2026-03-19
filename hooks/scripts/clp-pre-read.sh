#!/usr/bin/env bash
# CLP Pre-Read Guard — Suggests targeted reads for large files
set -euo pipefail

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-.}"
CLP_DIR="$PROJECT_DIR/.claude/clp"

INPUT=$(cat)

# Single jq call to extract all fields
read -r FILE_PATH OFFSET LIMIT < <(echo "$INPUT" | jq -r '[.tool_input.file_path // "", .tool_input.offset // "", .tool_input.limit // ""] | @tsv' 2>/dev/null || echo "")
[ -z "$FILE_PATH" ] && exit 0

# If line range is already specified, allow silently
if [ -n "$OFFSET" ] || [ -n "$LIMIT" ]; then exit 0; fi

# Check file exists and get line count (bounded to avoid reading huge files)
[ ! -f "$FILE_PATH" ] && exit 0
LINE_COUNT=$(head -n 1001 "$FILE_PATH" 2>/dev/null | wc -l | tr -d ' ')

# Read threshold from manifest (default 300)
THRESHOLD=300
if [ -f "$CLP_DIR/manifest.json" ]; then
  THRESHOLD=$(jq -r '.tool_optimization.read_line_threshold // 300' "$CLP_DIR/manifest.json" 2>/dev/null || echo "300")
fi

if [ "$LINE_COUNT" -gt "$THRESHOLD" ]; then
  MSG="[CLP: ${LINE_COUNT}L file. Use Grep or line ranges. Delegate to Explore subagent for understanding.]"
  echo "$MSG" | jq -Rs '{hookSpecificOutput:{additionalContext:.}}'
fi
exit 0
