#!/usr/bin/env bash
# CLP SessionEnd — Writes session memory on close
set -euo pipefail

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-.}"
SESSION_DIR="$PROJECT_DIR/.claude/sessions"
mkdir -p "$SESSION_DIR"

INPUT=$(cat)
SID=$(echo "$INPUT" | jq -r ".session_id // \"unknown\"")
REASON=$(echo "$INPUT" | jq -r ".reason // \"exit\"")
TS=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

{
  echo ""
  echo "---"
  echo "## Session $SID (ended: $TS, reason: $REASON)"
  if command -v git &>/dev/null && git -C "$PROJECT_DIR" rev-parse --is-inside-work-tree &>/dev/null 2>&1; then
    echo "Branch: $(git -C "$PROJECT_DIR" branch --show-current 2>/dev/null || echo "?")"
    DIFF=$(git -C "$PROJECT_DIR" diff --stat HEAD 2>/dev/null | tail -1 || echo "")
    [ -n "$DIFF" ] && echo "Changes: $DIFF"
  fi
  echo ""
} >> "$SESSION_DIR/$(date +%Y-%m-%d)-session.md"

exit 0
