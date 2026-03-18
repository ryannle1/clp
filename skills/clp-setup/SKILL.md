---
name: clp-setup
description: Initialize CLP configuration in the current project. Creates the skill registry, zone manifest, directory structure, and .claudeignore. This skill should be used when the user asks to "initialize CLP", "set up CLP", or "configure CLP for this project".
---

<instructions>
Initialize CLP for the current project by performing these steps:

<setup_steps>
  <step name="create_directories">
    Create if not exists:
    - `.claude/clp/`
    - `.claude/handoffs/`
    - `.claude/sessions/`
    - `docs/specs/`
    - `docs/design/`
    - `docs/guides/`
  </step>

  <step name="create_manifest">
    Write `.claude/clp/manifest.json` with default zone budgets:
    - kernel: 22000 tokens
    - active: 40000 tokens
    - working: 133000 tokens
    - buffer: 5000 tokens
    
    Include default thresholds:
    - backup_start_pct: 40
    - compact_warning_pct: 75
    - compact_trigger_pct: 85
  </step>

  <step name="create_skill_registry">
    Analyze the current project to generate a relevant skill registry:
    
    1. Check for common frameworks (Next.js, Express, Django, Rails, etc.)
    2. Check for existing documentation in docs/ or similar directories
    3. Check for test frameworks (jest, vitest, pytest, etc.)
    4. Generate skill entries with appropriate trigger keywords
    
    If the project has no docs yet, create starter skills pointing to
    files the user should create (docs/specs/*, docs/guides/*).
  </step>

  <step name="create_claudeignore">
    If `.claudeignore` doesn't exist, create one based on the project type:
    - Detect package manager (npm, yarn, pnpm, pip, cargo, etc.)
    - Exclude: dependencies, build outputs, generated files, lock files
    - Exclude: CLP ephemeral files (.claude/handoffs/, .claude/sessions/)
  </step>

  <step name="audit_claude_md">
    Check the existing CLAUDE.md:
    - If it exists and is over 200 lines, suggest converting to pointer index pattern
    - If it doesn't exist, offer to create a starter pointer index
    - Show the before/after token count estimate
  </step>

  <step name="verify">
    Run /clp:doctor to validate the setup.
  </step>
</setup_steps>
</instructions>

<output_format>
After setup, show a concise summary:

**CLP initialized** for [project name]

- Created: [list of new files/directories]
- Skill registry: [N] skills configured
- CLAUDE.md: [status — already lean / needs slimming / created]
- .claudeignore: [created / already exists]

**Next:** Run `/clp:status` to see the baseline token usage.
</output_format>

<rules>
- Never overwrite existing files without asking.
- If .claude/clp/ already exists, ask if the user wants to reconfigure.
- Detect the project type automatically — don't ask the user.
- The skill registry should be immediately useful, not just a template.
</rules>
