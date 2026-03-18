---
name: clp-reset
description: Reset CLP state for a fresh start. Clears handoffs, session memory, and optionally the skill registry. This skill should be used when starting a completely new task unrelated to previous work, or when handoff state has become stale or corrupted.
---

<instructions>
Reset CLP state based on the requested level:

<reset_levels>
  <level name="soft" trigger="/clp:reset or /clp:reset soft">
    Clear only the handoff state:
    - Delete all files in `.claude/handoffs/`
    - The skill registry and configuration are preserved
    - Session memory files are preserved
    - Use when: switching to a new task but same project
  </level>

  <level name="hard" trigger="/clp:reset hard">
    Clear all ephemeral state:
    - Delete all files in `.claude/handoffs/`
    - Delete all files in `.claude/sessions/`
    - The skill registry and configuration are preserved
    - Use when: starting completely fresh on this project
  </level>

  <level name="factory" trigger="/clp:reset factory">
    Reset to initial installation state:
    - Delete `.claude/handoffs/`, `.claude/sessions/`
    - Reset skill-registry.json to starter template
    - Reset manifest.json to default zone budgets
    - Preserve hook scripts and settings.json wiring
    - Use when: CLP configuration has become corrupted
  </level>
</reset_levels>

Always confirm the reset level with the user before executing.
After reset, run /clp:doctor to verify the installation is healthy.
</instructions>

<rules>
- Always ask for confirmation before any destructive action.
- Never delete hook scripts, settings.json, or CLAUDE.md.
- After reset, suggest running /clp:status to verify clean state.
- If $ARGUMENTS specifies a level, use it. Otherwise default to "soft".
</rules>
