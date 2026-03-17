#!/usr/bin/env bash
# CLP PreCompact — Generates structured handoff manifest before compaction
set -euo pipefail

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-.}"
HANDOFF_DIR="$PROJECT_DIR/.claude/handoffs"
mkdir -p "$HANDOFF_DIR"

INPUT=$(cat)
SESSION_ID=$(echo "$INPUT" | jq -r ".session_id // \"unknown\"")
TRANSCRIPT=$(echo "$INPUT" | jq -r ".transcript_path // \"\"")
TRIGGER=$(echo "$INPUT" | jq -r ".trigger // \"auto\"")
TS=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
SLUG=$(date +"%Y%m%d-%H%M%S")

# Extract modified files from transcript
MOD_FILES="[]"
USER_MSGS="[]"
if [ -n "$TRANSCRIPT" ] && [ -f "$TRANSCRIPT" ]; then
  MOD_FILES=$(jq -s "[.[] | select(.type==\"tool_use\") | select(.name==\"Write\" or .name==\"Edit\" or .name==\"MultiEdit\") | .input.file_path // .input.path // empty] | unique | map({path:., change:\"Modified\"})" "$TRANSCRIPT" 2>/dev/null || echo "[]")
  USER_MSGS=$(jq -s "[.[] | select(.type==\"human\") | .content // empty] | if length > 8 then .[-8:] else . end | map(if type==\"array\" then [.[]|select(.type==\"text\")|.text]|join(\" \") elif type==\"string\" then . else empty end) | map(if length > 150 then .[:150]+\"...\" else . end)" "$TRANSCRIPT" 2>/dev/null || echo "[]")
fi

# Write manifest
MANIFEST="{
  \"clp_version\": \"1.0\",
  \"session_id\": \"$SESSION_ID\",
  \"timestamp\": \"$TS\",
  \"trigger\": \"$TRIGGER\",
  \"project\": \"$PROJECT_DIR\",
  \"state\": { \"current_goal\": \"See recent requests\", \"status\": \"in_progress\" },
  \"context\": { \"recent_requests\": $USER_MSGS, \"decisions\": [], \"discoveries\": [] },
  \"files\": { \"modified\": $MOD_FILES, \"created\": [] },
  \"tasks\": { \"completed\": [], \"pending\": [] },
  \"active_skills\": [],
  \"budget\": {}
}"

HFILE="$HANDOFF_DIR/${SESSION_ID}-${SLUG}.json"
echo "$MANIFEST" | jq "." > "$HFILE" 2>/dev/null || echo "$MANIFEST" > "$HFILE"

echo "{\"path\":\"$HFILE\",\"session_id\":\"$SESSION_ID\",\"timestamp\":\"$TS\"}" > "$HANDOFF_DIR/latest.json"
echo "CLP: Handoff written to $HFILE" >&2
exit 0
