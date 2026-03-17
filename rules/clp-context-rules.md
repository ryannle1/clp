<clp_protocol version="1.0">

<context_management>
  You are operating under the Context Lifecycle Protocol (CLP).
  Your context window is partitioned into managed zones with budget tracking.
  Follow these rules to minimize context bloat and maximize session longevity.
</context_management>

<zone_awareness>
  <zone name="kernel" budget="22K" policy="protected">
    System prompt, CLAUDE.md pointer index, CLP manifest, rules.
    Never evicted. Keep CLAUDE.md lean — pointer index only.
  </zone>
  <zone name="active" budget="40K" policy="demand-loaded">
    Skills, specs, docs loaded via trigger-keyword matching.
    Only load what the current task needs. Evict stale skills.
  </zone>
  <zone name="working" budget="133K" policy="lru-evict">
    Conversation history and tool outputs.
    This is where bloat happens. Be deliberate about what enters this zone.
  </zone>
  <zone name="buffer" budget="5K" policy="flush-on-compact">
    Handoff staging data. Preserved across compaction.
  </zone>
</zone_awareness>

<token_discipline>
  <rule priority="critical">
    Before reading a file, ask: does this task require the full file content?
    If only a function signature or a specific section is needed, use Grep or
    targeted Read with line ranges instead of reading the entire file.
  </rule>
  <rule priority="critical">
    Delegate exploration tasks to subagents. When investigating how a system works,
    reading multiple files to understand patterns, or searching for code — use a
    subagent. The subagent's file reads stay in its isolated context, not yours.
  </rule>
  <rule priority="high">
    After completing a tool operation, summarize the result mentally before proceeding.
    The raw tool output persists in the working zone. If the output was large (>2K tokens),
    note the key information you extracted so you don't need to re-read it.
  </rule>
  <rule priority="high">
    When approaching 75% context utilization, run /clp:checkpoint to preserve state,
    then consider /compact to free working zone space.
  </rule>
  <rule priority="normal">
    Use Plan Mode (Shift+Tab) for analysis and planning tasks.
    Switch to normal mode for implementation. This roughly halves token cost
    for thinking-heavy work.
  </rule>
</token_discipline>

<skill_loading>
  Skills are demand-loaded via the skill registry (.claude/clp/skill-registry.json).
  When a user prompt matches trigger keywords, the matched skill files are suggested.
  
  <rule>Do NOT pre-read all documentation files at session start.</rule>
  <rule>Do NOT read skill files unless the current task requires them.</rule>
  <rule>When a skill is suggested by the prompt scan hook, read it once and retain
    the key information. Do not re-read on subsequent turns.</rule>
  <rule>If working on a task that doesn't match any skill, proceed with the
    pointer index in CLAUDE.md — that should be sufficient for routing.</rule>
</skill_loading>

<handoff_protocol>
  <when_to_checkpoint>
    - After completing a logical unit of work (a feature, a fix, a refactor phase)
    - Before switching from one task to a different task
    - When context utilization exceeds 60%
    - Before running /compact manually
    - When the user asks to pause, stop, or hand off work
  </when_to_checkpoint>
  
  <checkpoint_quality>
    A good checkpoint lets a fresh session continue without asking clarifying questions.
    Include: the goal (why), decisions made (what and why), files changed (where),
    pending tasks (what's next), and any non-obvious context (errors seen, API quirks).
  </checkpoint_quality>
</handoff_protocol>

<xml_prompting_convention>
  When generating structured content for CLP (handoff manifests, status reports,
  execution plans), use XML tags internally to organize your reasoning before
  producing the final output. This improves accuracy and ensures nothing is missed.
  
  The user's prompts may also use XML tags. Respect the tag hierarchy:
  outer tags define scope and intent, inner tags define execution details.
</xml_prompting_convention>

</clp_protocol>
