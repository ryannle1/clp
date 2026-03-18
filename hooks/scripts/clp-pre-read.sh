#!/usr/bin/env bash
# CLP Pre-Read Guard — Suggests targeted reads for large files
set -euo pipefail

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-.}"
CLP_DIR="$PROJECT_DIR/.claude/clp"

INPUT=$(cat)
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty' 2>/dev/null || echo "")
[ -z "$FILE_PATH" ] && exit 0

OFFSET=$(echo "$INPUT" | jq -r '.tool_input.offset // empty' 2>/dev/null || echo "")
LIMIT=$(echo "$INPUT" | jq -r '.tool_input.limit // empty' 2>/dev/null || echo "")

# If line range is already specified, allow silently
[ -n "$OFFSET" ] || [ -n "$LIMIT" ] && exit 0

# Check file exists and get line count
[ ! -f "$FILE_PATH" ] && exit 0
LINE_COUNT=$(wc -l < "$FILE_PATH" 2>/dev/null | tr -d ' ')

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
