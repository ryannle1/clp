---
name: clp-handoff
description: Generate or restore a session handoff. This skill should be used when starting a new session, transferring work to another developer, resuming after compaction, or preparing to hand off work. Supports both creating handoffs and loading existing ones.
---

<context>
CLP handoff manifests are machine-readable JSON files that fully describe a session's
state at a point in time. Any Claude Code session can consume a manifest to resume
work without re-explanation. Manifests live in `.claude/handoffs/`.
</context>

<instructions>
This skill operates in two modes based on the argument:

<mode name="create">
  **Trigger:** `/clp:handoff` or `/clp:handoff create`

  1. Run `/clp:checkpoint` to capture the current session state
  2. Read the generated manifest from `.claude/handoffs/latest.json`
  3. Generate a human-readable summary alongside the JSON manifest
  4. Output instructions for how to use this handoff in a new session

  <human_summary_format>
  # Session Handoff — [date]

  **Goal:** [current goal]
  **Status:** [in_progress/blocked/complete]
  **Branch:** [git branch]

  ## What's Done
  - [completed task 1]
  - [completed task 2]

  ## What's Next
  1. [highest priority pending task]
  2. [next priority]

  ## Key Decisions
  - [decision]: [rationale]

  ## To Resume
  Start a new Claude Code session in this project and run:
  `/clp:handoff load`
  </human_summary_format>
</mode>

<mode name="load">
  **Trigger:** `/clp:handoff load` or `/clp:handoff load [path]`

  1. Find the latest handoff manifest (or use the specified path)
  2. Parse the JSON manifest
  3. Load the goal, decisions, file changes, and pending tasks into working context
  4. Identify and suggest reloading the active skills listed in the manifest
  5. Summarize what was restored and what the immediate next step is

  <restoration_output>
  **Handoff restored** from [timestamp]

  **Goal:** [current goal]
  **Resuming at:** [first pending task]
  **Skills to reload:** [list, or "already loaded"]

  Ready to continue. The most important next step is: [first pending task]
  </restoration_output>
</mode>
</instructions>

<rules>
- When creating: always generate both the JSON manifest AND the human-readable summary.
- When loading: always confirm what was restored and state the immediate next action.
- If no handoff exists when loading, say so clearly and suggest running /clp:checkpoint first.
- The human summary should be concise enough to paste into a Slack message or PR description.
- Never load a handoff older than 24 hours without warning the user it may be stale.
</rules>
