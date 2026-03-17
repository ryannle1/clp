---
name: clp-status
description: Show current CLP context budget utilization, zone breakdown, active skills, and session health. Use when checking token usage, context status, budget remaining, or before deciding whether to compact.
---

<context>
You are operating under the Context Lifecycle Protocol (CLP). The context window is
partitioned into four zones, each with a budget and eviction policy:

- **Kernel** (≤22K tokens): Protected. System prompt, CLAUDE.md pointer index, rules.
- **Active** (≤40K tokens): Demand-loaded. Skills, specs, MCP schemas for current task.
- **Working** (≤133K tokens): Evictable. Conversation history, tool outputs.
- **Buffer** (≤5K tokens): Staging. Handoff data for compaction recovery.
</context>

<instructions>
Generate a CLP status report by performing these steps:

1. Run `/context` or read the current token usage from the environment
2. Read `.claude/clp/manifest.json` to get zone budget allocations
3. Read `.claude/clp/skill-registry.json` to list available and currently-loaded skills
4. Check `.claude/handoffs/latest.json` for the most recent handoff timestamp
5. Check `.claude/sessions/` for today's session memory file

Present the report using this exact XML structure for your own reasoning,
then output a clean summary:

<status_report>
  <budget>
    <total_capacity>200000</total_capacity>
    <total_used>[from /context]</total_used>
    <utilization_pct>[calculated]</utilization_pct>
  </budget>
  <zones>
    <zone name="kernel" budget="22000" used="[estimate]" status="protected"/>
    <zone name="active" budget="40000" used="[estimate]" status="[skills loaded]"/>
    <zone name="working" budget="133000" used="[estimate]" status="[turns in context]"/>
    <zone name="buffer" budget="5000" used="[estimate]" status="[handoff staged]"/>
  </zones>
  <skills_loaded>[list of currently active skill files]</skills_loaded>
  <last_handoff>[timestamp or "none"]</last_handoff>
  <recommendation>[compact now / continue / clear and restart]</recommendation>
</status_report>
</instructions>

<output_format>
Present the status as a concise, scannable summary — not a wall of text.
Use this structure:

**CLP Status** — [utilization]% used ([X]k / 200k tokens)

| Zone | Budget | Used | Status |
|------|--------|------|--------|
| Kernel | 22k | Xk | Protected |
| Active | 40k | Xk | [N skills loaded] |
| Working | 133k | Xk | [N turns] |
| Buffer | 5k | Xk | [staged/empty] |

**Active Skills:** [list or "none"]
**Last Handoff:** [timestamp or "none"]
**Recommendation:** [action]
</output_format>

<rules>
- Never guess token counts. Read actual values from /context or environment.
- If /context is unavailable, state that clearly rather than estimating.
- The recommendation should be actionable: "continue working", "consider /compact",
  "run /clp:checkpoint then /compact", or "start fresh with /clear".
- Keep the output under 20 lines.
</rules>
