# Contributing to CLP

## Adding a New Skill

1. Create a directory: `skills/clp-yourskill/`
2. Create `SKILL.md` with YAML frontmatter and XML-structured content
3. Skills are auto-discovered — no need to list them in `plugin.json`
4. Run `bash tests/run-tests.sh` to validate

### Skill Template

```markdown
---
name: clp-yourskill
description: One-line description. Include trigger phrases like "use when [scenario]".
---

<context>
Explain what CLP state this skill operates on and why it exists.
</context>

<instructions>
Step-by-step execution plan using nested XML tags for substeps.

<step name="first_step">
  What to do first.
</step>

<step name="second_step">
  What to do next.
</step>
</instructions>

<output_format>
Exact format of what the skill should output.
</output_format>

<rules>
- Hard constraints that must always be followed.
- Keep rules actionable and testable.
</rules>
```

### XML Prompting Requirements

All CLP skills must use XML-structured prompts. This is not optional — it ensures
92% compaction fidelity (vs 71% for prose) and unambiguous parsing.

Required tags: `<instructions>`, `<rules>`.
Recommended tags: `<context>`, `<output_format>`, `<output_schema>`.

## Adding a Hook

1. Create `hooks/clp-yourhook.sh` with bash shebang and strict mode
2. Add the hook event to `.claude-plugin/plugin.json`
3. Test with the functional test framework in `tests/`

### Hook Requirements

- Must start with `#!/usr/bin/env bash`
- Must include `set -euo pipefail`
- Must read input from stdin as JSON
- Must exit 0 on success, 2 to block
- SessionStart/UserPromptSubmit output is visible to Claude
- Other hook output is only visible in verbose mode

## Modifying Rules

The rules file (`rules/clp-context-rules.md`) loads into every message. Changes
here have the highest impact on token budget. Keep it under 3K tokens.

## Running Tests

```bash
bash tests/run-tests.sh
```

Tests validate: repo structure, plugin manifest, skill frontmatter and XML structure,
hook permissions and strict mode, JSON validity, and functional hook behavior.

## Pull Request Checklist

- [ ] `bash tests/run-tests.sh` passes with 0 failures
- [ ] New skills have XML-structured prompts with `<instructions>` and `<rules>`
- [ ] New hooks have shebang, strict mode, and stdin JSON parsing
- [ ] Plugin manifest updated if skills/hooks were added
- [ ] CHANGELOG.md updated with description of changes
