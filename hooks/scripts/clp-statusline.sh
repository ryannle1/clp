#!/usr/bin/env bash
# CLP StatusLine — Real-time budget display
set -euo pipefail

USED="${CLAUDE_CONTEXT_TOKENS_USED:-0}"
TOTAL="${CLAUDE_CONTEXT_TOKENS_TOTAL:-200000}"

[ "$TOTAL" -eq 0 ] && echo "CLP: init..." && exit 0

read -r PCT USED_K TOTAL_K < <(awk "BEGIN {printf \"%.0f %.0fk %.0fk\n\", ($USED/$TOTAL)*100, $USED/1000, $TOTAL/1000}")

WARN=""
[ "$PCT" -ge 85 ] && WARN=" !! COMPACT"
[ "$PCT" -ge 75 ] && [ "$PCT" -lt 85 ] && WARN=" ! HIGH"

echo "CLP: ${PCT}% (${USED_K}/${TOTAL_K})${WARN}"
exit 0
