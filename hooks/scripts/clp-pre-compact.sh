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
MANIFEST=$(jq -n \
  --arg clp_version "1.0" \
  --arg session_id "$SESSION_ID" \
  --arg timestamp "$TS" \
  --arg trigger "$TRIGGER" \
  --arg project "$PROJECT_DIR" \
  --argjson user_msgs "$USER_MSGS" \
  --argjson mod_files "$MOD_FILES" \
  '{
    clp_version: $clp_version,
    session_id: $session_id,
    timestamp: $timestamp,
    trigger: $trigger,
    project: $project,
    state: { current_goal: "See recent requests", status: "in_progress" },
    context: { recent_requests: $user_msgs, decisions: [], discoveries: [] },
    files: { modified: $mod_files, created: [] },
    tasks: { completed: [], pending: [] },
    active_skills: [],
    budget: {}
  }')

HFILE="$HANDOFF_DIR/${SESSION_ID}-${SLUG}.json"
echo "$MANIFEST" | jq "." > "$HFILE" 2>/dev/null || echo "$MANIFEST" > "$HFILE"

jq -n --arg path "$HFILE" --arg session_id "$SESSION_ID" --arg timestamp "$TS" \
  '{path: $path, session_id: $session_id, timestamp: $timestamp}' > "$HANDOFF_DIR/latest.json"
echo "CLP: Handoff written to $HFILE" >&2
exit 0
