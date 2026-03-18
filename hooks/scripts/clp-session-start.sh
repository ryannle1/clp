#!/usr/bin/env bash
# CLP SessionStart — Loads kernel zone and restores handoff if available
set -euo pipefail

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-.}"
CLP_DIR="$PROJECT_DIR/.claude/clp"
HANDOFF_DIR="$PROJECT_DIR/.claude/handoffs"
SESSION_DIR="$PROJECT_DIR/.claude/sessions"

INPUT=$(cat)
SOURCE=$(echo "$INPUT" | jq -r ".source // \"startup\"")

CONTEXT=""

# Load CLP zone summary
if [ -f "$CLP_DIR/manifest.json" ]; then
  ZONE_SUMMARY=$(jq -r "\"CLP v\" + .version + \" | Zones: kernel(\" + (.zones.kernel.budget_tokens|tostring) + \") active(\" + (.zones.active.budget_tokens|tostring) + \") working(\" + (.zones.working.budget_tokens|tostring) + \") buffer(\" + (.zones.buffer.budget_tokens|tostring) + \")\"" "$CLP_DIR/manifest.json" 2>/dev/null || echo "")
  [ -n "$ZONE_SUMMARY" ] && CONTEXT="## CLP Runtime\n$ZONE_SUMMARY"
fi

# Load skill registry index
if [ -f "$CLP_DIR/skill-registry.json" ]; then
  SKILLS=$(jq -r ".skills[] | \"- \" + .name + \": \" + .description" "$CLP_DIR/skill-registry.json" 2>/dev/null || echo "")
  [ -n "$SKILLS" ] && CONTEXT="$CONTEXT\n\n## Available Skills (demand-loaded)\n$SKILLS\nSkills load when your prompt matches triggers. Do NOT pre-load."
fi

# Restore from handoff manifest
if [ -f "$HANDOFF_DIR/latest.json" ]; then
  LATEST_PATH=$(jq -r ".path // empty" "$HANDOFF_DIR/latest.json" 2>/dev/null || echo "")
  if [ -n "$LATEST_PATH" ] && [ -f "$LATEST_PATH" ]; then
    GOAL=$(jq -r ".state.current_goal // \"No goal\"" "$LATEST_PATH" 2>/dev/null)
    PENDING=$(jq -r "(.tasks.pending // [])[] | \"- [ ] \" + ." "$LATEST_PATH" 2>/dev/null || echo "")
    COMPLETED=$(jq -r "(.tasks.completed // [])[] | \"- [x] \" + ." "$LATEST_PATH" 2>/dev/null || echo "")
    MODIFIED=$(jq -r "(.files.modified // [])[] | \"- \" + .path + \": \" + .change" "$LATEST_PATH" 2>/dev/null || echo "")
    DECISIONS=$(jq -r "(.context.decisions // [])[] | \"- \" + .decision" "$LATEST_PATH" 2>/dev/null || echo "")

    CONTEXT="$CONTEXT\n\n## Restored from Handoff\n**Goal:** $GOAL"
    [ -n "$DECISIONS" ] && CONTEXT="$CONTEXT\n### Decisions\n$DECISIONS"
    [ -n "$MODIFIED" ] && CONTEXT="$CONTEXT\n### Files Changed\n$MODIFIED"
    [ -n "$COMPLETED" ] && CONTEXT="$CONTEXT\n### Progress\n$COMPLETED"
    [ -n "$PENDING" ] && CONTEXT="$CONTEXT\n$PENDING"
  fi
fi

# Git context
if command -v git &>/dev/null && git -C "$PROJECT_DIR" rev-parse --is-inside-work-tree &>/dev/null 2>&1; then
  BRANCH=$(git -C "$PROJECT_DIR" branch --show-current 2>/dev/null || echo "?")
  CONTEXT="$CONTEXT\n\n## Git\nBranch: $BRANCH"
fi

# Output
echo -e "$CONTEXT" | jq -Rs '{hookSpecificOutput:{hookEventName:"SessionStart",additionalContext:.}}'
exit 0
