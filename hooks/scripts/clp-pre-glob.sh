#!/usr/bin/env bash
# CLP Pre-Glob Guard — Warns on overly broad glob patterns
set -euo pipefail

INPUT=$(cat)
PATTERN=$(echo "$INPUT" | jq -r '.tool_input.pattern // empty' 2>/dev/null || echo "")
[ -z "$PATTERN" ] && exit 0

# Warn if pattern has no file extension filter (catches *, **/, **/* and variants like src/**/* )
if echo "$PATTERN" | grep -qE '^(\*\*/?\*?|\*|.+/\*\*/\*?)$' && ! echo "$PATTERN" | grep -qE '\.\w+'; then
  MSG="[CLP: broad glob. Add extension filter e.g. **/*.ts]"
  echo "$MSG" | jq -Rs '{hookSpecificOutput:{additionalContext:.}}'
fi
exit 0
