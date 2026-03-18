#!/usr/bin/env bash
# CLP SessionStart — Loads kernel zone and restores handoff if available
set -euo pipefail

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-.}"
CLP_DIR="$PROJECT_DIR/.claude/clp"
HANDOFF_DIR="$PROJECT_DIR/.claude/handoffs"

INPUT=$(cat)

CONTEXT=""

# Load CLP zone summary
if [ -f "$CLP_DIR/manifest.json" ]; then
  ZONE_SUMMARY=$(jq -r "\"CLP v\" + .version + \" | Zones: kernel(\" + (.zones.kernel.budget_tokens|tostring) + \") active(\" + (.zones.active.budget_tokens|tostring) + \") working(\" + (.zones.working.budget_tokens|tostring) + \") buffer(\" + (.zones.buffer.budget_tokens|tostring) + \")\"" "$CLP_DIR/manifest.json" 2>/dev/null || echo "")
  [ -n "$ZONE_SUMMARY" ] && CONTEXT="## CLP Runtime\n$ZONE_SUMMARY"
fi

# Load skill registry index
if [ -f "$CLP_DIR/skill-registry.json" ]; then
  SKILLS=$(jq -r '.skills[] | "- " + .name + ": " + (.description // "no description")' "$CLP_DIR/skill-registry.json" 2>/dev/null || echo "")
  [ -n "$SKILLS" ] && CONTEXT="$CONTEXT\n\n## Available Skills (demand-loaded)\n$SKILLS\nSkills load when your prompt matches triggers. Do NOT pre-load."
fi

# Restore from handoff manifest
if [ -f "$HANDOFF_DIR/latest.json" ]; then
  LATEST_PATH=$(jq -r ".path // empty" "$HANDOFF_DIR/latest.json" 2>/dev/null || echo "")
  if [ -n "$LATEST_PATH" ] && [ -f "$LATEST_PATH" ]; then
    # Single jq call to extract all handoff fields
    HANDOFF_CTX=$(jq -r '
      "## Restored from Handoff\n**Goal:** " + (.state.current_goal // "No goal") +
      (if (.context.decisions // []) | length > 0
       then "\n### Decisions\n" + ([(.context.decisions // [])[] | "- " + .decision] | join("\n"))
       else "" end) +
      (if (.files.modified // []) | length > 0
       then "\n### Files Changed\n" + ([(.files.modified // [])[] | "- " + .path + ": " + .change] | join("\n"))
       else "" end) +
      (if (.tasks.completed // []) | length > 0
       then "\n### Progress\n" + ([(.tasks.completed // [])[] | "- [x] " + .] | join("\n"))
       else "" end) +
      (if (.tasks.pending // []) | length > 0
       then "\n" + ([(.tasks.pending // [])[] | "- [ ] " + .] | join("\n"))
       else "" end)
    ' "$LATEST_PATH" 2>/dev/null || echo "")
    [ -n "$HANDOFF_CTX" ] && CONTEXT="$CONTEXT\n\n$HANDOFF_CTX"
  fi
fi

# Git context
BRANCH=$(git -C "$PROJECT_DIR" branch --show-current 2>/dev/null || echo "")
[ -n "$BRANCH" ] && CONTEXT="$CONTEXT\n\n## Git\nBranch: $BRANCH"

# Output
if [ -n "$CONTEXT" ]; then
  echo -e "$CONTEXT" | jq -Rs '{hookSpecificOutput:{hookEventName:"SessionStart",additionalContext:.}}'
fi
exit 0
