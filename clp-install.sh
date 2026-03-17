#!/usr/bin/env bash
# ╔══════════════════════════════════════════════════════════════╗
# ║  CLP — Context Lifecycle Protocol Installer v1.0            ║
# ║  Install: curl -fsSL <repo>/install.sh | bash               ║
# ║  Or:      bash clp-install.sh [--project /path/to/project]  ║
# ╚══════════════════════════════════════════════════════════════╝

set -euo pipefail

# ── Configuration ──
CLP_VERSION="1.0.0"
VERBOSE="${CLP_VERBOSE:-false}"
DRY_RUN="${CLP_DRY_RUN:-false}"
FORCE="${CLP_FORCE:-false}"

# ── Colors ──
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m'

# ── Helpers ──
info()    { echo -e "${BLUE}▸${NC} $1"; }
success() { echo -e "${GREEN}✓${NC} $1"; }
warn()    { echo -e "${YELLOW}⚠${NC} $1"; }
fail()    { echo -e "${RED}✗${NC} $1"; exit 1; }
step()    { echo -e "\n${BOLD}${CYAN}[$1/7]${NC} ${BOLD}$2${NC}"; }
debug()   { [[ "$VERBOSE" == "true" ]] && echo -e "${DIM}  → $1${NC}"; }

write_file() {
  local path="$1"
  local content="$2"
  if [[ "$DRY_RUN" == "true" ]]; then
    debug "Would write: $path"
    return
  fi
  mkdir -p "$(dirname "$path")"
  echo "$content" > "$path"
  debug "Wrote: $path"
}

# ── Parse arguments ──
PROJECT_DIR=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --project|-p)  PROJECT_DIR="$2"; shift 2 ;;
    --verbose|-v)  VERBOSE=true; shift ;;
    --dry-run)     DRY_RUN=true; shift ;;
    --force|-f)    FORCE=true; shift ;;
    --help|-h)
      echo "CLP Installer v${CLP_VERSION}"
      echo ""
      echo "Usage: clp-install.sh [OPTIONS]"
      echo ""
      echo "Options:"
      echo "  --project, -p PATH   Install into specific project (default: current dir)"
      echo "  --verbose, -v        Show detailed output"
      echo "  --dry-run            Show what would be done without writing files"
      echo "  --force, -f          Overwrite existing CLP installation"
      echo "  --help, -h           Show this help"
      exit 0 ;;
    *) fail "Unknown option: $1. Use --help for usage." ;;
  esac
done

# ── Resolve project directory ──
if [[ -z "$PROJECT_DIR" ]]; then
  PROJECT_DIR="$(pwd)"
fi
PROJECT_DIR="$(cd "$PROJECT_DIR" && pwd)"

# ── Banner ──
echo ""
echo -e "${BOLD}╔══════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}║  ${CYAN}CLP${NC}${BOLD} — Context Lifecycle Protocol v${CLP_VERSION}     ║${NC}"
echo -e "${BOLD}║  Zone-based context management for Claude Code ║${NC}"
echo -e "${BOLD}╚══════════════════════════════════════════════╝${NC}"
echo ""
echo -e "  Project: ${BOLD}$PROJECT_DIR${NC}"
echo ""

# ════════════════════════════════════════════════════════════════
# STEP 1: Pre-flight checks
# ════════════════════════════════════════════════════════════════
step "1" "Pre-flight checks"

# Check for existing installation
if [[ -d "$PROJECT_DIR/.claude/clp" ]] && [[ "$FORCE" != "true" ]]; then
  warn "CLP is already installed in this project."
  echo -e "  Use ${BOLD}--force${NC} to overwrite, or run ${BOLD}clp-doctor.sh${NC} to verify."
  exit 1
fi

# Check for Claude Code
if command -v claude &>/dev/null; then
  CLAUDE_VERSION=$(claude --version 2>/dev/null | head -1 || echo "unknown")
  success "Claude Code found: $CLAUDE_VERSION"
else
  warn "Claude Code not found in PATH (installation will proceed anyway)"
fi

# Check for jq (required for hooks)
if command -v jq &>/dev/null; then
  success "jq found: $(jq --version 2>/dev/null)"
else
  warn "jq not found — hooks require jq for JSON parsing"
  echo -e "  Install: ${BOLD}brew install jq${NC} (macOS) or ${BOLD}sudo apt install jq${NC} (Linux)"
fi

# Check for git
if git -C "$PROJECT_DIR" rev-parse --is-inside-work-tree &>/dev/null 2>&1; then
  success "Git repository detected"
else
  warn "Not a git repository (git features in hooks will be skipped)"
fi

success "Pre-flight complete"

# ════════════════════════════════════════════════════════════════
# STEP 2: Create directory structure
# ════════════════════════════════════════════════════════════════
step "2" "Creating directory structure"

DIRS=(
  ".claude/clp"
  ".claude/hooks"
  ".claude/handoffs"
  ".claude/sessions"
  "docs/specs"
  "docs/design"
  "docs/guides"
)

for dir in "${DIRS[@]}"; do
  if [[ "$DRY_RUN" != "true" ]]; then
    mkdir -p "$PROJECT_DIR/$dir"
  fi
  debug "Directory: $dir/"
done

success "Created ${#DIRS[@]} directories"

# ════════════════════════════════════════════════════════════════
# STEP 3: Write CLP configuration files
# ════════════════════════════════════════════════════════════════
step "3" "Writing CLP configuration"

# 3a. CLP manifest
write_file "$PROJECT_DIR/.claude/clp/manifest.json" '{
  "clp_version": "1.0",
  "zones": {
    "kernel": {
      "max_tokens": 22000,
      "policy": "protected",
      "contents": [
        { "type": "system", "source": "built-in" },
        { "type": "pointer_index", "source": "CLAUDE.md" },
        { "type": "rules", "source": ".claude/rules/" },
        { "type": "clp_manifest", "source": ".claude/clp/manifest.json" }
      ]
    },
    "active": {
      "max_tokens": 40000,
      "policy": "task_scoped",
      "loader": "skill_registry",
      "registry_path": ".claude/clp/skill-registry.json"
    },
    "working": {
      "max_tokens": 133000,
      "policy": "lru_evict"
    },
    "buffer": {
      "max_tokens": 5000,
      "policy": "flush_on_compact",
      "handoff_path": ".claude/handoffs/"
    }
  },
  "thresholds": {
    "backup_start_pct": 40,
    "backup_interval_tokens": 10000,
    "compact_warning_pct": 75,
    "compact_trigger_pct": 85
  }
}'
success "CLP manifest"

# 3b. Skill registry (starter template)
write_file "$PROJECT_DIR/.claude/clp/skill-registry.json" '{
  "clp_version": "1.0",
  "skills": [
    {
      "id": "example-auth",
      "triggers": ["auth", "oauth", "login", "jwt", "token", "session"],
      "files": ["docs/specs/auth-spec.md"],
      "estimated_tokens": 1200,
      "zone": "active",
      "description": "Authentication and authorization specifications"
    },
    {
      "id": "example-testing",
      "triggers": ["test", "spec", "jest", "vitest", "coverage", "mock"],
      "files": ["docs/guides/testing.md"],
      "estimated_tokens": 1500,
      "zone": "active",
      "description": "Testing conventions and patterns"
    }
  ],
  "max_concurrent_skills": 3,
  "evict_after_turns_inactive": 5,
  "fallback_message": "No skills matched. Working with pointer index only."
}'
success "Skill registry (starter template)"

# ════════════════════════════════════════════════════════════════
# STEP 4: Write hook scripts
# ════════════════════════════════════════════════════════════════
step "4" "Writing hook scripts"

# 4a. SessionStart hook
write_file "$PROJECT_DIR/.claude/hooks/clp-session-start.sh" '#!/usr/bin/env bash
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
  ZONE_SUMMARY=$(jq -r "\"CLP v\" + .clp_version + \" | Zones: kernel(\" + (.zones.kernel.max_tokens|tostring) + \") active(\" + (.zones.active.max_tokens|tostring) + \") working(\" + (.zones.working.max_tokens|tostring) + \") buffer(\" + (.zones.buffer.max_tokens|tostring) + \")\"" "$CLP_DIR/manifest.json" 2>/dev/null || echo "")
  [ -n "$ZONE_SUMMARY" ] && CONTEXT="## CLP Runtime\n$ZONE_SUMMARY"
fi

# Load skill registry index
if [ -f "$CLP_DIR/skill-registry.json" ]; then
  SKILLS=$(jq -r ".skills[] | \"- \" + .id + \": \" + .description" "$CLP_DIR/skill-registry.json" 2>/dev/null || echo "")
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
echo -e "$CONTEXT" | jq -Rs '"'"'{hookSpecificOutput:{hookEventName:"SessionStart",additionalContext:.}}'"'"''
exit 0'

# 4b. UserPromptSubmit hook
write_file "$PROJECT_DIR/.claude/hooks/clp-prompt-scan.sh" '#!/usr/bin/env bash
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
  SID=$(echo "$skill" | jq -r ".id")
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
  echo -e "$CTX" | jq -Rs '"'"'{hookSpecificOutput:{hookEventName:"UserPromptSubmit",additionalContext:.}}'"'"''
fi
exit 0'

# 4c. PreCompact hook
write_file "$PROJECT_DIR/.claude/hooks/clp-pre-compact.sh" '#!/usr/bin/env bash
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
  '"'"'{
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
  }'"'"')

HFILE="$HANDOFF_DIR/${SESSION_ID}-${SLUG}.json"
echo "$MANIFEST" | jq "." > "$HFILE" 2>/dev/null || echo "$MANIFEST" > "$HFILE"

jq -n --arg path "$HFILE" --arg session_id "$SESSION_ID" --arg timestamp "$TS" \
  '"'"'{path: $path, session_id: $session_id, timestamp: $timestamp}'"'"' > "$HANDOFF_DIR/latest.json"
echo "CLP: Handoff written to $HFILE" >&2
exit 0'

# 4d. SessionEnd hook
write_file "$PROJECT_DIR/.claude/hooks/clp-session-end.sh" '#!/usr/bin/env bash
# CLP SessionEnd — Writes session memory on close
set -euo pipefail

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-.}"
SESSION_DIR="$PROJECT_DIR/.claude/sessions"
mkdir -p "$SESSION_DIR"

INPUT=$(cat)
SID=$(echo "$INPUT" | jq -r ".session_id // \"unknown\"")
REASON=$(echo "$INPUT" | jq -r ".reason // \"exit\"")
TS=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

{
  echo ""
  echo "---"
  echo "## Session $SID (ended: $TS, reason: $REASON)"
  if command -v git &>/dev/null && git -C "$PROJECT_DIR" rev-parse --is-inside-work-tree &>/dev/null 2>&1; then
    echo "Branch: $(git -C "$PROJECT_DIR" branch --show-current 2>/dev/null || echo "?")"
    DIFF=$(git -C "$PROJECT_DIR" diff --stat HEAD 2>/dev/null | tail -1 || echo "")
    [ -n "$DIFF" ] && echo "Changes: $DIFF"
  fi
  echo ""
} >> "$SESSION_DIR/$(date +%Y-%m-%d)-session.md"

exit 0'

# 4e. StatusLine hook
write_file "$PROJECT_DIR/.claude/hooks/clp-statusline.sh" '#!/usr/bin/env bash
# CLP StatusLine — Real-time budget display
set -euo pipefail

USED="${CLAUDE_CONTEXT_TOKENS_USED:-0}"
TOTAL="${CLAUDE_CONTEXT_TOKENS_TOTAL:-200000}"

[ "$TOTAL" -eq 0 ] && echo "CLP: init..." && exit 0

PCT=$(awk "BEGIN {printf \"%.0f\", ($USED / $TOTAL) * 100}")
USED_K=$(awk "BEGIN {printf \"%.0fk\", $USED / 1000}")

WARN=""
[ "$PCT" -ge 85 ] && WARN=" !! COMPACT"
[ "$PCT" -ge 75 ] && [ "$PCT" -lt 85 ] && WARN=" ! HIGH"

echo "CLP: ${PCT}% (${USED_K}/${TOTAL})${WARN}"
exit 0'

# Make all hooks executable
if [[ "$DRY_RUN" != "true" ]]; then
  chmod +x "$PROJECT_DIR/.claude/hooks/"*.sh
fi

success "5 hook scripts written and made executable"

# ════════════════════════════════════════════════════════════════
# STEP 5: Write settings.json (merge with existing if present)
# ════════════════════════════════════════════════════════════════
step "5" "Configuring Claude Code hooks"

SETTINGS_PATH="$PROJECT_DIR/.claude/settings.json"
CLP_HOOKS='{
  "hooks": {
    "SessionStart": [
      { "matcher": "", "hooks": [{ "type": "command", "command": "bash $CLAUDE_PROJECT_DIR/.claude/hooks/clp-session-start.sh" }] }
    ],
    "UserPromptSubmit": [
      { "matcher": "", "hooks": [{ "type": "command", "command": "bash $CLAUDE_PROJECT_DIR/.claude/hooks/clp-prompt-scan.sh" }] }
    ],
    "PreCompact": [
      { "matcher": "", "hooks": [{ "type": "command", "command": "bash $CLAUDE_PROJECT_DIR/.claude/hooks/clp-pre-compact.sh" }] }
    ],
    "SessionEnd": [
      { "matcher": "", "hooks": [{ "type": "command", "command": "bash $CLAUDE_PROJECT_DIR/.claude/hooks/clp-session-end.sh" }] }
    ]
  },
  "statusLine": {
    "type": "command",
    "command": "bash $CLAUDE_PROJECT_DIR/.claude/hooks/clp-statusline.sh"
  }
}'

if [[ "$DRY_RUN" != "true" ]]; then
  if [[ -f "$SETTINGS_PATH" ]] && [[ "$FORCE" != "true" ]]; then
    # Merge: add CLP hooks alongside existing hooks
    EXISTING=$(cat "$SETTINGS_PATH")
    MERGED=$(jq -s '
      .[0] as $existing | .[1] as $new |
      ($existing // {}) * ($new // {}) |
      .hooks |= (
        ($existing.hooks // {}) as $eh | ($new.hooks // {}) as $nh |
        ($eh + $nh) | to_entries | map(
          .key as $k |
          .value = (($eh[$k] // []) + ($nh[$k] // []) | unique_by(.hooks[0].command))
        ) | from_entries
      )
    ' <<< "$EXISTING"$'\n'"$CLP_HOOKS" 2>/dev/null || echo "$CLP_HOOKS")
    echo "$MERGED" | jq '.' > "$SETTINGS_PATH"
    success "Merged CLP hooks into existing settings.json"
  else
    echo "$CLP_HOOKS" | jq '.' > "$SETTINGS_PATH"
    success "Created settings.json with CLP hooks"
  fi
fi

# ════════════════════════════════════════════════════════════════
# STEP 6: Create .claudeignore if not present
# ════════════════════════════════════════════════════════════════
step "6" "Setting up .claudeignore"

IGNORE_PATH="$PROJECT_DIR/.claudeignore"
if [[ ! -f "$IGNORE_PATH" ]] || [[ "$FORCE" == "true" ]]; then
  write_file "$IGNORE_PATH" '# CLP .claudeignore — reduce file-read token consumption

# Dependencies
node_modules/
vendor/
.pnpm-store/

# Build outputs
dist/
build/
.next/
out/

# Generated / large files
coverage/
*.min.js
*.min.css
*.map

# Lock files
package-lock.json
yarn.lock
pnpm-lock.yaml

# OS / IDE
.DS_Store
.vscode/
.idea/'
  success "Created .claudeignore"
else
  success ".claudeignore already exists (kept)"
fi

# ════════════════════════════════════════════════════════════════
# STEP 7: Write helper tools
# ════════════════════════════════════════════════════════════════
step "7" "Installing helper tools"

# clp-doctor: diagnostic tool
write_file "$PROJECT_DIR/.claude/hooks/clp-doctor.sh" '#!/usr/bin/env bash
# CLP Doctor — Validate your CLP installation
set -euo pipefail

RED="\033[0;31m"; GREEN="\033[0;32m"; YELLOW="\033[1;33m"; NC="\033[0m"; BOLD="\033[1m"
PASS=0; FAIL=0; WARN_CT=0

check() {
  if eval "$2" &>/dev/null; then
    echo -e "${GREEN}✓${NC} $1"
    PASS=$((PASS + 1))
  else
    echo -e "${RED}✗${NC} $1"
    FAIL=$((FAIL + 1))
  fi
}

warn_check() {
  if eval "$2" &>/dev/null; then
    echo -e "${GREEN}✓${NC} $1"
    PASS=$((PASS + 1))
  else
    echo -e "${YELLOW}⚠${NC} $1 (optional)"
    WARN_CT=$((WARN_CT + 1))
  fi
}

PROJECT_DIR="${1:-.}"
echo -e "\n${BOLD}CLP Doctor — Installation Diagnostic${NC}\n"
echo -e "Project: ${BOLD}$PROJECT_DIR${NC}\n"

echo -e "${BOLD}Dependencies${NC}"
check "jq installed" "command -v jq"
warn_check "git available" "command -v git"
warn_check "Claude Code installed" "command -v claude"

echo -e "\n${BOLD}Directory structure${NC}"
check ".claude/clp/ exists" "test -d $PROJECT_DIR/.claude/clp"
check ".claude/hooks/ exists" "test -d $PROJECT_DIR/.claude/hooks"
check ".claude/handoffs/ exists" "test -d $PROJECT_DIR/.claude/handoffs"
check ".claude/sessions/ exists" "test -d $PROJECT_DIR/.claude/sessions"
check "docs/ exists" "test -d $PROJECT_DIR/docs"

echo -e "\n${BOLD}Configuration files${NC}"
check "CLP manifest valid JSON" "jq empty $PROJECT_DIR/.claude/clp/manifest.json"
check "Skill registry valid JSON" "jq empty $PROJECT_DIR/.claude/clp/skill-registry.json"
check "settings.json valid JSON" "jq empty $PROJECT_DIR/.claude/settings.json"

echo -e "\n${BOLD}Hook scripts${NC}"
check "clp-session-start.sh exists + executable" "test -x $PROJECT_DIR/.claude/hooks/clp-session-start.sh"
check "clp-prompt-scan.sh exists + executable" "test -x $PROJECT_DIR/.claude/hooks/clp-prompt-scan.sh"
check "clp-pre-compact.sh exists + executable" "test -x $PROJECT_DIR/.claude/hooks/clp-pre-compact.sh"
check "clp-session-end.sh exists + executable" "test -x $PROJECT_DIR/.claude/hooks/clp-session-end.sh"
check "clp-statusline.sh exists + executable" "test -x $PROJECT_DIR/.claude/hooks/clp-statusline.sh"

echo -e "\n${BOLD}Hook wiring${NC}"
check "SessionStart hook configured" "jq -e \".hooks.SessionStart\" $PROJECT_DIR/.claude/settings.json"
check "UserPromptSubmit hook configured" "jq -e \".hooks.UserPromptSubmit\" $PROJECT_DIR/.claude/settings.json"
check "PreCompact hook configured" "jq -e \".hooks.PreCompact\" $PROJECT_DIR/.claude/settings.json"
check "SessionEnd hook configured" "jq -e \".hooks.SessionEnd\" $PROJECT_DIR/.claude/settings.json"
check "StatusLine configured" "jq -e \".statusLine\" $PROJECT_DIR/.claude/settings.json"

echo -e "\n${BOLD}Context optimization${NC}"
warn_check ".claudeignore exists" "test -f $PROJECT_DIR/.claudeignore"
warn_check "CLAUDE.md exists" "test -f $PROJECT_DIR/CLAUDE.md"
if [ -f "$PROJECT_DIR/CLAUDE.md" ]; then
  LINES=$(wc -l < "$PROJECT_DIR/CLAUDE.md")
  if [ "$LINES" -le 200 ]; then
    echo -e "${GREEN}✓${NC} CLAUDE.md is lean ($LINES lines, target ≤200)"
    PASS=$((PASS + 1))
  else
    echo -e "${YELLOW}⚠${NC} CLAUDE.md is $LINES lines (target ≤200 for kernel zone)"
    WARN_CT=$((WARN_CT + 1))
  fi
fi

echo -e "\n${BOLD}──────────────────────────────────${NC}"
echo -e "${GREEN}$PASS passed${NC}  ${RED}$FAIL failed${NC}  ${YELLOW}$WARN_CT warnings${NC}"
if [ $FAIL -eq 0 ]; then
  echo -e "\n${GREEN}${BOLD}CLP installation is healthy.${NC}"
else
  echo -e "\n${RED}${BOLD}CLP has $FAIL issue(s) to fix.${NC}"
  exit 1
fi'

# clp-test: integration test suite
write_file "$PROJECT_DIR/.claude/hooks/clp-test.sh" '#!/usr/bin/env bash
# CLP Test Suite — Exercises each hook in isolation
set -euo pipefail

RED="\033[0;31m"; GREEN="\033[0;32m"; NC="\033[0m"; BOLD="\033[1m"
PASS=0; FAIL=0

PROJECT_DIR="${1:-.}"
export CLAUDE_PROJECT_DIR="$PROJECT_DIR"

run_test() {
  local name="$1"
  local hook="$2"
  local input="$3"
  local check="$4"

  OUTPUT=$(echo "$input" | bash "$PROJECT_DIR/.claude/hooks/$hook" 2>/dev/null || echo "HOOK_ERROR")

  if echo "$OUTPUT" | eval "$check" &>/dev/null; then
    echo -e "${GREEN}✓${NC} $name"
    PASS=$((PASS + 1))
  else
    echo -e "${RED}✗${NC} $name"
    echo "  Output: $(echo "$OUTPUT" | head -1)"
    FAIL=$((FAIL + 1))
  fi
}

echo -e "\n${BOLD}CLP Integration Tests${NC}\n"

echo -e "${BOLD}SessionStart hook${NC}"
run_test "Returns valid JSON" "clp-session-start.sh" \
  "{\"source\":\"startup\",\"session_id\":\"test-001\"}" \
  "jq -e .hookSpecificOutput"

run_test "Contains CLP Runtime context" "clp-session-start.sh" \
  "{\"source\":\"startup\",\"session_id\":\"test-002\"}" \
  "grep -q \"CLP\""

echo -e "\n${BOLD}Prompt Scan hook${NC}"
run_test "Matches auth skill on oauth keyword" "clp-prompt-scan.sh" \
  "{\"user_message\":\"Add OAuth login flow\"}" \
  "grep -qi \"auth\""

run_test "Matches test skill on test keyword" "clp-prompt-scan.sh" \
  "{\"user_message\":\"Write unit tests for the API\"}" \
  "grep -qi \"test\""

run_test "No output on generic prompt" "clp-prompt-scan.sh" \
  "{\"user_message\":\"Hello, how are you?\"}" \
  "test -z"

echo -e "\n${BOLD}PreCompact hook${NC}"
run_test "Creates handoff file" "clp-pre-compact.sh" \
  "{\"session_id\":\"test-compact\",\"trigger\":\"auto\",\"transcript_path\":\"\"}" \
  "true"
run_test "latest.json updated" "true" \
  "" \
  "test -f $PROJECT_DIR/.claude/handoffs/latest.json"
run_test "Handoff is valid JSON" "true" \
  "" \
  "jq empty $PROJECT_DIR/.claude/handoffs/latest.json"

echo -e "\n${BOLD}SessionEnd hook${NC}"
run_test "Creates session memory file" "clp-session-end.sh" \
  "{\"session_id\":\"test-end\",\"reason\":\"exit\"}" \
  "true"
SESSION_FILE="$PROJECT_DIR/.claude/sessions/$(date +%Y-%m-%d)-session.md"
run_test "Session file contains session ID" "true" "" \
  "grep -q \"test-end\" \"$SESSION_FILE\""

echo -e "\n${BOLD}StatusLine hook${NC}"
export CLAUDE_CONTEXT_TOKENS_USED=50000
export CLAUDE_CONTEXT_TOKENS_TOTAL=200000
run_test "Shows percentage" "clp-statusline.sh" "" "grep -q \"25%\""

export CLAUDE_CONTEXT_TOKENS_USED=170000
run_test "Shows warning at high usage" "clp-statusline.sh" "" "grep -q \"HIGH\\\|COMPACT\""

unset CLAUDE_CONTEXT_TOKENS_USED CLAUDE_CONTEXT_TOKENS_TOTAL

# Cleanup test artifacts
rm -f "$PROJECT_DIR/.claude/handoffs/test-compact-"*.json 2>/dev/null

echo -e "\n${BOLD}──────────────────────────────────${NC}"
echo -e "${GREEN}$PASS passed${NC}  ${RED}$FAIL failed${NC}"
[ $FAIL -eq 0 ] && echo -e "\n${GREEN}${BOLD}All tests passed.${NC}" || echo -e "\n${RED}${BOLD}$FAIL test(s) failed.${NC}"
exit $FAIL'

# clp-uninstall: clean removal
write_file "$PROJECT_DIR/.claude/hooks/clp-uninstall.sh" '#!/usr/bin/env bash
# CLP Uninstall — Cleanly removes CLP from a project
set -euo pipefail

RED="\033[0;31m"; GREEN="\033[0;32m"; YELLOW="\033[1;33m"; NC="\033[0m"; BOLD="\033[1m"

PROJECT_DIR="${1:-.}"
echo -e "\n${BOLD}CLP Uninstall${NC}\n"
echo -e "Project: ${BOLD}$PROJECT_DIR${NC}\n"

read -p "Remove CLP from this project? This removes hooks, configs, handoffs, and sessions. [y/N] " -n 1 -r
echo ""
[[ ! $REPLY =~ ^[Yy]$ ]] && echo "Cancelled." && exit 0

rm -rf "$PROJECT_DIR/.claude/clp"
rm -f "$PROJECT_DIR/.claude/hooks/clp-"*.sh
rm -rf "$PROJECT_DIR/.claude/handoffs"
rm -rf "$PROJECT_DIR/.claude/sessions"

# Remove CLP hooks from settings.json (leave other hooks intact)
if [ -f "$PROJECT_DIR/.claude/settings.json" ]; then
  jq "del(.hooks.SessionStart[] | select(.hooks[].command | test(\"clp-\"))) |
      del(.hooks.UserPromptSubmit[] | select(.hooks[].command | test(\"clp-\"))) |
      del(.hooks.PreCompact[] | select(.hooks[].command | test(\"clp-\"))) |
      del(.hooks.SessionEnd[] | select(.hooks[].command | test(\"clp-\"))) |
      if .statusLine.command? and (.statusLine.command | test(\"clp-\")) then del(.statusLine) else . end" \
    "$PROJECT_DIR/.claude/settings.json" > "$PROJECT_DIR/.claude/settings.json.tmp" 2>/dev/null && \
    mv "$PROJECT_DIR/.claude/settings.json.tmp" "$PROJECT_DIR/.claude/settings.json"
fi

echo -e "\n${GREEN}✓${NC} CLP removed. Your CLAUDE.md and .claudeignore were preserved."
echo -e "${YELLOW}⚠${NC} Review your CLAUDE.md — it may still reference CLP patterns."'

if [[ "$DRY_RUN" != "true" ]]; then
  chmod +x "$PROJECT_DIR/.claude/hooks/clp-doctor.sh"
  chmod +x "$PROJECT_DIR/.claude/hooks/clp-test.sh"
  chmod +x "$PROJECT_DIR/.claude/hooks/clp-uninstall.sh"
fi

success "Installed: clp-doctor, clp-test, clp-uninstall"

# ════════════════════════════════════════════════════════════════
# Done!
# ════════════════════════════════════════════════════════════════
echo ""
echo -e "${BOLD}${GREEN}════════════════════════════════════════════════${NC}"
echo -e "${BOLD}${GREEN}  CLP installed successfully!${NC}"
echo -e "${BOLD}${GREEN}════════════════════════════════════════════════${NC}"
echo ""
echo -e "  ${BOLD}Next steps:${NC}"
echo ""
echo -e "  1. ${CYAN}Verify installation:${NC}"
echo -e "     bash .claude/hooks/clp-doctor.sh"
echo ""
echo -e "  2. ${CYAN}Run integration tests:${NC}"
echo -e "     bash .claude/hooks/clp-test.sh"
echo ""
echo -e "  3. ${CYAN}Edit your CLAUDE.md${NC} to use the pointer index pattern"
echo -e "     (keep it under 200 lines / 2K tokens)"
echo ""
echo -e "  4. ${CYAN}Customize the skill registry:${NC}"
echo -e "     Edit .claude/clp/skill-registry.json with your project's skills"
echo ""
echo -e "  5. ${CYAN}Start a Claude Code session${NC} and watch CLP in action"
echo ""
echo -e "  ${DIM}Docs:  github.com/ryannle1/clp${NC}"
echo -e "  ${DIM}Help:  bash .claude/hooks/clp-doctor.sh${NC}"
echo -e "  ${DIM}Remove: bash .claude/hooks/clp-uninstall.sh${NC}"
echo ""
