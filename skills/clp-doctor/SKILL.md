---
name: clp-doctor
description: Diagnose and validate the CLP installation. Checks directory structure, configuration files, hook wiring, skill registry, and context optimization. This skill should be used when something seems wrong, after initial setup, or to audit the installation.
---

<instructions>
Run a comprehensive diagnostic of the CLP installation by checking each category:

<diagnostic_checks>
  <category name="dependencies">
    - Is `jq` installed and available?
    - Is `git` available?
  </category>

  <category name="directory_structure">
    - Does `.claude/clp/` exist?
    - Does `.claude/hooks/` exist?
    - Does `.claude/handoffs/` exist?
    - Does `.claude/sessions/` exist?
    - Does `docs/` exist?
  </category>

  <category name="configuration">
    - Is `.claude/clp/manifest.json` valid JSON?
    - Is `.claude/clp/skill-registry.json` valid JSON?
    - Is `.claude/settings.json` valid JSON?
    - Does the manifest define all four zones (kernel, active, working, buffer)?
    - Do zone budgets sum to ≤200K tokens?
  </category>

  <category name="hook_wiring">
    - Is SessionStart hook configured in settings.json?
    - Is UserPromptSubmit hook configured?
    - Is PreCompact hook configured?
    - Is SessionEnd hook configured?
    - Is StatusLine configured?
    - Do all referenced hook scripts exist and have execute permission?
  </category>

  <category name="context_optimization">
    - Does `.claudeignore` exist?
    - Does `CLAUDE.md` exist?
    - Is `CLAUDE.md` under 200 lines? (Report actual line count)
    - Does `CLAUDE.md` use the pointer index pattern (references docs/ files)?
    - Are there component-specific CLAUDE.md files in subdirectories?
  </category>

  <category name="skill_registry">
    - How many skills are defined?
    - Does each skill have triggers, files, and estimated_tokens?
    - Do the referenced skill files exist on disk?
    - Are there trigger keyword overlaps between skills?
  </category>
</diagnostic_checks>

Present results as: ✓ for pass, ✗ for fail, ⚠ for warning (non-critical).
End with a summary: X passed, Y failed, Z warnings.
If there are failures, provide specific fix instructions for each one.
</instructions>

<rules>
- Actually check the filesystem. Do not assume files exist.
- For JSON validation, try parsing with jq or by reading the file.
- Be precise about what's wrong and how to fix it.
- Keep output scannable — one line per check, details only for failures.
</rules>
