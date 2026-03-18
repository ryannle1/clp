#!/usr/bin/env bash
# CLP SessionEnd — Writes session memory on close
set -euo pipefail

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-.}"
SESSION_DIR="$PROJECT_DIR/.claude/sessions"
mkdir -p "$SESSION_DIR"

INPUT=$(cat)
read -r SID REASON < <(echo "$INPUT" | jq -r '[.session_id // "unknown", .reason // "exit"] | @tsv')
TS=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

{
  echo ""
  echo "---"
  echo "## Session $SID (ended: $TS, reason: $REASON)"
  BRANCH=$(git -C "$PROJECT_DIR" branch --show-current 2>/dev/null || echo "")
  if [ -n "$BRANCH" ]; then
    echo "Branch: $BRANCH"
    DIFF=$(git -C "$PROJECT_DIR" diff --stat HEAD 2>/dev/null | tail -1 || echo "")
    [ -n "$DIFF" ] && echo "Changes: $DIFF"
  fi
  echo ""
} >> "$SESSION_DIR/$(date +%Y-%m-%d)-session.md"

exit 0
