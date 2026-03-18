#!/usr/bin/env bash
# CLP Pre-Bash Guard — Suggests bounded alternatives for output-heavy commands
set -euo pipefail

INPUT=$(cat)
CMD=$(echo "$INPUT" | jq -r '.tool_input.command // empty' 2>/dev/null || echo "")
[ -z "$CMD" ] && exit 0

WARNINGS=""

# Pattern: cat without head/tail pipe (no start anchor — catches compound commands)
if echo "$CMD" | grep -qE '\bcat\s' && ! echo "$CMD" | grep -qE '\|\s*(head|tail|grep|wc|jq)'; then
  WARNINGS="${WARNINGS}unbounded cat; "
fi

# Pattern: find without depth limit or head pipe
if echo "$CMD" | grep -qE '\bfind\s' && ! echo "$CMD" | grep -qE '(-maxdepth|\|\s*head)'; then
  WARNINGS="${WARNINGS}unbounded find; "
fi

# Pattern: ls -R on broad directory
if echo "$CMD" | grep -qE '\bls\s+(-\w*R|-\w*l\w*R|--recursive)'; then
  WARNINGS="${WARNINGS}recursive ls; "
fi

# Pattern: curl without output limit
if echo "$CMD" | grep -qE '\bcurl\s' && ! echo "$CMD" | grep -qE '(\|\s*head|--max-filesize|-o\s)'; then
  WARNINGS="${WARNINGS}unbounded curl; "
fi

if [ -n "$WARNINGS" ]; then
  MSG="[CLP: ${WARNINGS% ; }. Add output limits.]"
  echo "$MSG" | jq -Rs '{hookSpecificOutput:{additionalContext:.}}'
fi
exit 0
