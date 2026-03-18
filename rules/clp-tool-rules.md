<clp_protocol version="2.0">

<context_management>
  You are operating under the Context Lifecycle Protocol (CLP) v2.0.
  Your context window is partitioned into managed zones with budget tracking.
  Your tool use is guided by optimization rules: accuracy first, speed second, leanness third.
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

<tool_optimization>
  <accuracy priority="critical">
    Before reading any file, state what you are looking for.
    Use Grep to find it, then Read only the relevant line range.
  </accuracy>
  <accuracy priority="critical">
    Never read a file "to understand it." Delegate understanding tasks
    to an Explore subagent and receive a summary back.
  </accuracy>
  <accuracy priority="critical">
    When a task involves unknown codebase areas, dispatch an Explore
    subagent first. Do not start implementation until you have findings.
  </accuracy>
  <accuracy priority="high">
    When multiple files might contain what you need, Glob first to
    identify candidates, then Grep to confirm, then Read the match.
  </accuracy>

  <speed priority="critical">
    When 2+ independent questions need answering, dispatch parallel
    subagents. Never answer them sequentially.
  </speed>
  <speed priority="high">
    When implementation requires understanding multiple subsystems,
    dispatch one Explore subagent per subsystem in parallel.
  </speed>
  <speed priority="high">
    Prefer Grep with output_mode "content" and line context over Read
    when only a few lines are needed.
  </speed>

  <leanness priority="critical">
    After a tool returns output, never re-invoke the same tool for the
    same content. Extract what you need on first read.
  </leanness>
  <leanness priority="critical">
    Bash commands must include output limits: head, tail, | head -n,
    --max-count. Never run unbounded commands.
  </leanness>
  <leanness priority="high">
    When a Read result exceeds 200 lines, mentally note the key
    information and move on. Do not quote large sections back.
  </leanness>
  <leanness priority="high">
    Delegate all "find and report" tasks to subagents. Only bring
    results into main context, not the search process.
  </leanness>
</tool_optimization>

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
  execution plans), use XML tags internally to organize reasoning before
  producing the final output. This improves accuracy and ensures nothing is missed.

  User prompts may also use XML tags. Respect the tag hierarchy:
  outer tags define scope and intent, inner tags define execution details.
</xml_prompting_convention>

</clp_protocol>
