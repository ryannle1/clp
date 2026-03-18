# CLP — Context Lifecycle Protocol

Claude Code plugin for zone-based context management. Bash + jq, no external dependencies.

## Project layout

```
.claude-plugin/plugin.json   # Plugin manifest (metadata, hooks path, rules)
hooks/
  hooks.json                  # Hook event config (references scripts via $CLAUDE_PLUGIN_ROOT)
  scripts/                    # Hook shell scripts (also embedded in clp-install.sh)
    clp-session-start.sh      # SessionStart: loads kernel zone, restores handoffs
    clp-prompt-scan.sh        # UserPromptSubmit: single-jq skill matching
    clp-pre-compact.sh        # PreCompact: generates handoff manifest JSON
    clp-session-end.sh        # SessionEnd: writes session memory
    clp-statusline.sh         # StatusLine: real-time budget display (wired via installer statusLine config)
skills/clp-*/SKILL.md         # 7 skills (auto-discovered), YAML frontmatter + XML content
rules/clp-context-rules.md    # Runtime rules (loaded every message, keep <3K tokens)
clp-install.sh                # Standalone installer (embeds copies of all hooks)
tests/run-tests.sh            # Test suite
docs/CLP-SPECIFICATION.md     # Full protocol spec
```

## Key constraints

- **Dual-source hooks**: Every hook exists in `hooks/scripts/` AND as an embedded copy inside `clp-install.sh`. Changes must be mirrored to both.
- **Hook I/O contract**: Hooks read JSON from stdin, write JSON to stdout. SessionStart/UserPromptSubmit output goes to Claude via `hookSpecificOutput`. Exit 0 on success, 2 to block.
- **Hook efficiency**: Hooks run on every message (prompt-scan) or session event. Minimize subprocess spawns — use single `jq` calls with `any()` for matching, not shell loops. Avoid redundant file reads.
- **JSON field names**: Manifest uses `version` and `budget_tokens`. Skill registry uses `name` (not `id`). Handoff manifests use `version`.
- **JSON safety**: Use `jq -Rs` for escaping strings into JSON (not sed). Use `jq -n --arg` for constructing JSON with variables (not string interpolation).
- **Skills use XML**: All skills must have `<instructions>` and `<rules>` tags. Required for compaction fidelity.
- **Skills are auto-discovered**: Do not list them in plugin.json. Place in `skills/<name>/SKILL.md`.
- **Skill descriptions**: Use third-person ("This skill should be used when...") with specific trigger phrases users would say.
- **Skill writing style**: Use imperative/infinitive form in body. No second-person ("you", "your").
- **Portable paths**: Hook commands use `$CLAUDE_PLUGIN_ROOT` (not hardcoded paths). Installer hooks use `$CLAUDE_PROJECT_DIR`.
- **StatusLine hook**: Lives in `hooks/scripts/` like other hooks, but is NOT a lifecycle event in `hooks.json`. It's wired via the `statusLine` config key in `settings.json` by the installer.

## Testing

```bash
bash tests/run-tests.sh    # Must pass with 0 failures before any PR
```

## Common tasks

- **Add a skill**: Create `skills/clp-name/SKILL.md` with frontmatter + XML. Auto-discovered, no manifest change needed. Description must use third-person with trigger phrases.
- **Add/modify a hook**: Edit in `hooks/scripts/`, update `hooks/hooks.json` if adding a new event, then mirror changes into the embedded copy in `clp-install.sh`. The installer wraps hook content in single-quoted strings — use `'"'"'` to embed literal single quotes.
- **Settings merge**: `clp-install.sh` merges CLP hooks into existing `settings.json` by concatenating hook arrays (not replacing), deduped by command.
