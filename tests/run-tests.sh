#!/usr/bin/env bash
# ╔══════════════════════════════════════════════════════════════╗
# ║  CLP Test Suite — Validates plugin structure, hooks, skills  ║
# ║  Run: bash tests/run-tests.sh                                ║
# ║  CI:  exits 0 on all pass, 1 on any failure                  ║
# ╚══════════════════════════════════════════════════════════════╝

set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; DIM='\033[2m'; NC='\033[0m'

PASS=0; FAIL=0; SKIP=0
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"

info()    { echo -e "${CYAN}▸${NC} $1"; }
pass()    { echo -e "  ${GREEN}✓${NC} $1"; PASS=$((PASS + 1)); }
fail()    { echo -e "  ${RED}✗${NC} $1"; FAIL=$((FAIL + 1)); }
skip()    { echo -e "  ${YELLOW}○${NC} $1 ${DIM}(skipped)${NC}"; SKIP=$((SKIP + 1)); }
section() { echo -e "\n${BOLD}$1${NC}"; }

assert_file_exists() {
  [ -f "$REPO_ROOT/$1" ] && pass "$1 exists" || fail "$1 missing"
}

assert_dir_exists() {
  [ -d "$REPO_ROOT/$1" ] && pass "$1/ exists" || fail "$1/ missing"
}

assert_json_valid() {
  if command -v jq &>/dev/null; then
    jq empty "$REPO_ROOT/$1" 2>/dev/null && pass "$1 is valid JSON" || fail "$1 is invalid JSON"
  else
    skip "$1 JSON validation (jq not installed)"
  fi
}

assert_executable() {
  [ -x "$REPO_ROOT/$1" ] && pass "$1 is executable" || fail "$1 is not executable"
}

assert_file_contains() {
  grep -q "$2" "$REPO_ROOT/$1" 2>/dev/null && pass "$1 contains '$2'" || fail "$1 missing '$2'"
}

assert_skill_valid() {
  local skill_dir="$1"
  local skill_md="$REPO_ROOT/skills/$skill_dir/SKILL.md"

  if [ ! -f "$skill_md" ]; then
    fail "skills/$skill_dir/SKILL.md missing"
    return
  fi

  # Check frontmatter exists
  head -1 "$skill_md" | grep -q "^---" && pass "skills/$skill_dir has frontmatter" || fail "skills/$skill_dir missing frontmatter"

  # Check name field
  grep -q "^name:" "$skill_md" && pass "skills/$skill_dir has name" || fail "skills/$skill_dir missing name field"

  # Check description field
  grep -q "^description:" "$skill_md" && pass "skills/$skill_dir has description" || fail "skills/$skill_dir missing description"

  # Check for XML structure in content
  grep -q "<instructions>" "$skill_md" && pass "skills/$skill_dir uses XML structure" || fail "skills/$skill_dir missing XML <instructions>"

  # Check for rules section
  grep -q "<rules>" "$skill_md" && pass "skills/$skill_dir has <rules>" || fail "skills/$skill_dir missing <rules>"
}

# ════════════════════════════════════════════════════════════════
echo -e "\n${BOLD}${CYAN}CLP Test Suite${NC}"
echo -e "${DIM}Repository: $REPO_ROOT${NC}"
# ════════════════════════════════════════════════════════════════

section "1. Repository Structure"
assert_file_exists "README.md"
assert_file_exists "LICENSE"
assert_file_exists "CONTRIBUTING.md"
assert_file_exists "CHANGELOG.md"
assert_file_exists "clp-install.sh"
assert_dir_exists ".claude-plugin"
assert_dir_exists "skills"
assert_dir_exists "hooks"
assert_dir_exists "rules"
assert_dir_exists "tests"
assert_dir_exists "docs"

section "2. Plugin Manifest"
assert_file_exists ".claude-plugin/plugin.json"
assert_json_valid ".claude-plugin/plugin.json"
assert_file_exists ".claude-plugin/marketplace.json"
assert_json_valid ".claude-plugin/marketplace.json"

if command -v jq &>/dev/null; then
  # Verify plugin.json has required fields
  PLUGIN_NAME=$(jq -r '.name' "$REPO_ROOT/.claude-plugin/plugin.json" 2>/dev/null)
  [ "$PLUGIN_NAME" = "clp" ] && pass "Plugin name is 'clp'" || fail "Plugin name is '$PLUGIN_NAME', expected 'clp'"

  # Verify auto-discovered skills exist on disk
  SKILL_COUNT=$(find "$REPO_ROOT/skills" -name "SKILL.md" 2>/dev/null | wc -l | tr -d ' ')
  [ "$SKILL_COUNT" -ge 7 ] && pass "Found $SKILL_COUNT skills via auto-discovery (≥7)" || fail "Found only $SKILL_COUNT skills (need ≥7)"

  # Verify hooks.json exists and has required events
  HOOKS_PATH=$(jq -r '.hooks // empty' "$REPO_ROOT/.claude-plugin/plugin.json" 2>/dev/null)
  if [ -n "$HOOKS_PATH" ]; then
    HOOKS_FILE="$REPO_ROOT/${HOOKS_PATH#./}"
    [ -f "$HOOKS_FILE" ] && pass "hooks config file exists at $HOOKS_PATH" || fail "hooks config file missing at $HOOKS_PATH"
    if [ -f "$HOOKS_FILE" ]; then
      HOOK_COUNT=$(jq 'keys | length' "$HOOKS_FILE" 2>/dev/null)
      [ "$HOOK_COUNT" -ge 4 ] && pass "Hooks config declares $HOOK_COUNT hook events (≥4)" || fail "Hooks config declares only $HOOK_COUNT hook events (need ≥4)"
    fi
  fi

  info "Checking auto-discovered skills exist on disk..."
  for skill_dir in "$REPO_ROOT"/skills/*/; do
    skill_name=$(basename "$skill_dir")
    [ -f "$skill_dir/SKILL.md" ] && pass "skills/$skill_name/SKILL.md exists" || fail "skills/$skill_name/SKILL.md missing"
  done
fi

section "3. Skill Validation"
for skill_dir in clp-status clp-checkpoint clp-handoff clp-doctor clp-plan clp-reset clp-setup; do
  info "Validating $skill_dir..."
  assert_skill_valid "$skill_dir"
done

section "4. Hook Scripts"
for hook in clp-session-start clp-prompt-scan clp-pre-compact clp-session-end; do
  assert_file_exists "hooks/scripts/$hook.sh"
  assert_executable "hooks/scripts/$hook.sh"

  # Check shebang
  head -1 "$REPO_ROOT/hooks/scripts/$hook.sh" | grep -q "#!/usr/bin/env bash" && \
    pass "hooks/scripts/$hook.sh has bash shebang" || fail "hooks/scripts/$hook.sh missing shebang"

  # Check set -euo pipefail
  grep -q "set -euo pipefail" "$REPO_ROOT/hooks/scripts/$hook.sh" && \
    pass "hooks/scripts/$hook.sh uses strict mode" || fail "hooks/scripts/$hook.sh missing strict mode"
done

section "5. Rules"
assert_file_exists "rules/clp-context-rules.md"
assert_file_contains "rules/clp-context-rules.md" "<clp_protocol"
assert_file_contains "rules/clp-context-rules.md" "<zone_awareness>"
assert_file_contains "rules/clp-context-rules.md" "<token_discipline>"
assert_file_contains "rules/clp-context-rules.md" "<handoff_protocol>"

section "6. Standalone Installer"
assert_file_exists "clp-install.sh"
assert_executable "clp-install.sh"
assert_file_contains "clp-install.sh" "CLP_VERSION="
assert_file_contains "clp-install.sh" "Pre-flight checks"

section "7. Documentation"
assert_file_exists "docs/CLP-SPECIFICATION.md"
assert_file_contains "docs/CLP-SPECIFICATION.md" "Context Lifecycle Protocol"
assert_file_contains "docs/CLP-SPECIFICATION.md" "version"

section "8. Hook Functional Tests"
if command -v jq &>/dev/null; then
  # Create temp project for hook testing
  TEMP_DIR=$(mktemp -d)
  mkdir -p "$TEMP_DIR/.claude/clp" "$TEMP_DIR/.claude/handoffs" "$TEMP_DIR/.claude/sessions"

  # Copy test configs
  cat > "$TEMP_DIR/.claude/clp/manifest.json" << 'MANIFEST'
{"version":"1.0","zones":{"kernel":{"budget_tokens":22000},"active":{"budget_tokens":40000},"working":{"budget_tokens":133000},"buffer":{"budget_tokens":5000}}}
MANIFEST

  cat > "$TEMP_DIR/.claude/clp/skill-registry.json" << 'REGISTRY'
{"version":"1.0","skills":[{"name":"auth","triggers":["auth","oauth","login"],"files":["docs/auth.md"],"estimated_tokens":1000,"zone":"active","description":"Auth specs"},{"name":"testing","triggers":["test","jest","spec"],"files":["docs/testing.md"],"estimated_tokens":800,"zone":"active","description":"Testing guide"}],"max_concurrent_skills":3}
REGISTRY

  export CLAUDE_PROJECT_DIR="$TEMP_DIR"

  info "Testing SessionStart hook..."
  SS_OUT=$(echo '{"source":"startup","session_id":"test-ss"}' | bash "$REPO_ROOT/hooks/scripts/clp-session-start.sh" 2>/dev/null || echo "ERROR")
  echo "$SS_OUT" | jq -e '.hookSpecificOutput' &>/dev/null && pass "SessionStart returns valid hookSpecificOutput" || fail "SessionStart output invalid"
  echo "$SS_OUT" | grep -qi "CLP" && pass "SessionStart mentions CLP" || fail "SessionStart missing CLP context"

  info "Testing PromptScan hook (should match)..."
  PS_MATCH=$(echo '{"user_message":"Add OAuth login flow"}' | bash "$REPO_ROOT/hooks/scripts/clp-prompt-scan.sh" 2>/dev/null || echo "")
  echo "$PS_MATCH" | grep -qi "auth" && pass "PromptScan matches 'auth' skill on 'OAuth'" || fail "PromptScan failed to match auth skill"

  info "Testing PromptScan hook (should not match)..."
  PS_NONE=$(echo '{"user_message":"Hello world"}' | bash "$REPO_ROOT/hooks/scripts/clp-prompt-scan.sh" 2>/dev/null || echo "")
  [ -z "$PS_NONE" ] && pass "PromptScan returns empty for generic prompt" || fail "PromptScan incorrectly matched generic prompt"

  info "Testing PreCompact hook..."
  PC_OUT=$(echo '{"session_id":"test-pc","trigger":"auto","transcript_path":""}' | bash "$REPO_ROOT/hooks/scripts/clp-pre-compact.sh" 2>/dev/null || echo "ERROR")
  [ -f "$TEMP_DIR/.claude/handoffs/latest.json" ] && pass "PreCompact creates latest.json" || fail "PreCompact failed to create latest.json"
  jq empty "$TEMP_DIR/.claude/handoffs/latest.json" 2>/dev/null && pass "latest.json is valid JSON" || fail "latest.json is invalid"

  HANDOFF_PATH=$(jq -r '.path' "$TEMP_DIR/.claude/handoffs/latest.json" 2>/dev/null || echo "")
  [ -n "$HANDOFF_PATH" ] && [ -f "$HANDOFF_PATH" ] && pass "Handoff manifest file exists" || fail "Handoff manifest file missing"
  [ -n "$HANDOFF_PATH" ] && jq -e '.version' "$HANDOFF_PATH" &>/dev/null && pass "Handoff has version field" || fail "Handoff missing version"

  info "Testing SessionEnd hook..."
  echo '{"session_id":"test-se","reason":"exit"}' | bash "$REPO_ROOT/hooks/scripts/clp-session-end.sh" 2>/dev/null
  SESSION_FILE="$TEMP_DIR/.claude/sessions/$(date +%Y-%m-%d)-session.md"
  [ -f "$SESSION_FILE" ] && pass "SessionEnd creates session memory" || fail "SessionEnd failed to write session file"
  grep -q "test-se" "$SESSION_FILE" 2>/dev/null && pass "Session memory contains session ID" || fail "Session memory missing session ID"

  info "Testing SessionStart handoff restoration..."
  SS_RESTORE=$(echo '{"source":"compact","session_id":"test-restore"}' | bash "$REPO_ROOT/hooks/scripts/clp-session-start.sh" 2>/dev/null || echo "ERROR")
  echo "$SS_RESTORE" | grep -qi "handoff\|restored\|goal" && pass "SessionStart restores from handoff" || fail "SessionStart failed to restore handoff"

  # Cleanup
  rm -rf "$TEMP_DIR"
  unset CLAUDE_PROJECT_DIR
else
  skip "Hook functional tests (jq not installed)"
fi

# ════════════════════════════════════════════════════════════════
echo -e "\n${BOLD}════════════════════════════════════════════════${NC}"
TOTAL=$((PASS + FAIL + SKIP))
echo -e "${GREEN}$PASS passed${NC}  ${RED}$FAIL failed${NC}  ${YELLOW}$SKIP skipped${NC}  ${DIM}($TOTAL total)${NC}"

if [ $FAIL -eq 0 ]; then
  echo -e "${GREEN}${BOLD}All tests passed.${NC}\n"
  exit 0
else
  echo -e "${RED}${BOLD}$FAIL test(s) failed.${NC}\n"
  exit 1
fi
