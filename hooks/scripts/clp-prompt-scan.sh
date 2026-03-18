#!/usr/bin/env bash
# CLP Prompt Scan — Matches user messages to skill registry
set -euo pipefail

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-.}"
REGISTRY="$PROJECT_DIR/.claude/clp/skill-registry.json"

[ ! -f "$REGISTRY" ] && exit 0

INPUT=$(cat)
MSG=$(echo "$INPUT" | jq -r ".user_message // \"\"" 2>/dev/null || echo "")
[ -z "$MSG" ] && exit 0

MSG_LOWER=$(echo "$MSG" | tr "[:upper:]" "[:lower:]")

# Single jq call to match all skills — avoids per-skill subprocess spawning
RESULT=$(jq -r --arg msg "$MSG_LOWER" '
  (.max_concurrent_skills // 3) as $max |
  [ .skills[] |
    select(any(.triggers[]; ascii_downcase | . as $t | $msg | contains($t))) |
    "- \(.name): \(.description // "no description") -> Read: \(.files | join(", ")) (~\(.estimated_tokens // "?")t)"
  ] | .[:$max] | .[]
' "$REGISTRY" 2>/dev/null || echo "")

if [ -n "$RESULT" ]; then
  COUNT=$(echo "$RESULT" | wc -l | tr -d ' ')
  CTX="## CLP Skill Match\n${COUNT} skill(s) matched:\n${RESULT}\nLoad the listed files for task context."
  echo -e "$CTX" | jq -Rs '{hookSpecificOutput:{hookEventName:"UserPromptSubmit",additionalContext:.}}'
fi
exit 0
