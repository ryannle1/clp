# CLP — Context Lifecycle Protocol

Claude Code plugin for zone-based context management. Bash + jq, no external dependencies.

## Project layout

```
.claude-plugin/plugin.json   # Plugin manifest (metadata, hooks path, rules)
hooks/
  hooks.json                  # Hook event config (references scripts via $CLAUDE_PLUGIN_ROOT)
  scripts/                    # Hook shell scripts
    clp-session-start.sh      # SessionStart: loads kernel zone, restores handoffs
    clp-prompt-scan.sh        # UserPromptSubmit: single-jq skill matching
    clp-pre-compact.sh        # PreCompact: generates handoff manifest JSON
    clp-session-end.sh        # SessionEnd: writes session memory
    clp-statusline.sh         # StatusLine: real-time budget display
skills/clp-*/SKILL.md         # 7 skills (auto-discovered), YAML frontmatter + XML content
rules/clp-context-rules.md    # Runtime rules (loaded every message, keep <3K tokens)
tests/run-tests.sh            # Test suite
docs/CLP-SPECIFICATION.md     # Full protocol spec
```

## Key constraints

- **Hook I/O contract**: Hooks read JSON from stdin, write JSON to stdout. SessionStart/UserPromptSubmit output goes to Claude via `hookSpecificOutput`. Exit 0 on success, 2 to block.
- **Hook efficiency**: Hooks run on every message (prompt-scan) or session event. Minimize subprocess spawns — use single `jq` calls with `any()` for matching, not shell loops. Avoid redundant file reads.
- **JSON field names**: Manifest uses `version` and `budget_tokens`. Skill registry uses `name` (not `id`). Handoff manifests use `version`.
- **JSON safety**: Use `jq -Rs` for escaping strings into JSON (not sed). Use `jq -n --arg` for constructing JSON with variables (not string interpolation).
- **Skills use XML**: All skills must have `<instructions>` and `<rules>` tags. Required for compaction fidelity.
- **Skills are auto-discovered**: Do not list them in plugin.json. Place in `skills/<name>/SKILL.md`.
- **Skill descriptions**: Use third-person ("This skill should be used when...") with specific trigger phrases users would say.
- **Skill writing style**: Use imperative/infinitive form in body. No second-person ("you", "your").
- **Portable paths**: Hook commands in `hooks.json` use `$CLAUDE_PLUGIN_ROOT`. Hook scripts at runtime use `$CLAUDE_PROJECT_DIR` for user project paths.

## Testing

```bash
bash tests/run-tests.sh    # Must pass with 0 failures before any PR
```

## Common tasks

- **Add a skill**: Create `skills/clp-name/SKILL.md` with frontmatter + XML. Auto-discovered, no manifest change needed. Description must use third-person with trigger phrases.
- **Add/modify a hook**: Edit in `hooks/scripts/`, update `hooks/hooks.json` if adding a new event.
