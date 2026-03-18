#!/usr/bin/env bash
# CLP Prompt Scan — Matches user messages to skill registry
set -euo pipefail

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-.}"
REGISTRY="$PROJECT_DIR/.claude/clp/skill-registry.json"

INPUT=$(cat)
MSG=$(echo "$INPUT" | jq -r ".user_message // \"\"" 2>/dev/null || echo "")

{ [ ! -f "$REGISTRY" ] || [ -z "$MSG" ]; } && exit 0

MSG_LOWER=$(echo "$MSG" | tr "[:upper:]" "[:lower:]")
MATCHED=""
COUNT=0
MAX=$(jq -r ".max_concurrent_skills // 3" "$REGISTRY" 2>/dev/null)

while IFS= read -r skill; do
  SID=$(echo "$skill" | jq -r ".name")
  for trigger in $(echo "$skill" | jq -r ".triggers[]"); do
    if echo "$MSG_LOWER" | grep -qiF "$trigger"; then
      FILES=$(echo "$skill" | jq -r ".files | join(\", \")")
      DESC=$(echo "$skill" | jq -r ".description")
      TOKENS=$(echo "$skill" | jq -r ".estimated_tokens")
      [ $COUNT -lt "$MAX" ] && MATCHED="$MATCHED\n- $SID: $DESC -> Read: $FILES (~${TOKENS}t)" && COUNT=$((COUNT + 1))
      break
    fi
  done
done < <(jq -c ".skills[]" "$REGISTRY")

if [ $COUNT -gt 0 ]; then
  CTX="## CLP Skill Match\n${COUNT} skill(s) matched:$MATCHED\nLoad the listed files for task context."
  echo -e "$CTX" | jq -Rs '{hookSpecificOutput:{hookEventName:"UserPromptSubmit",additionalContext:.}}'
fi
exit 0
