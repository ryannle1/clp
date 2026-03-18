---
name: clp-plan
description: Plan a task with context budget awareness. Breaks work into context-sized chunks, estimates token cost per phase, and suggests when to checkpoint or use subagents. This skill should be used before starting any non-trivial task, when the user asks to "plan this", "estimate tokens", or "break this into phases".
---

<context>
Context is the most important resource to manage in Claude Code. A plan that ignores
context budget will fail midway through when compaction fires and critical state is lost.
CLP-aware planning accounts for this by designing work in context-sized chunks with
explicit checkpoint boundaries.
</context>

<instructions>
Given the user's task description (provided as $ARGUMENTS or in the preceding message),
create a CLP-aware execution plan:

<planning_steps>
  <step name="assess_budget">
    Check current context utilization with /clp:status.
    Calculate available working tokens for this task.
  </step>

  <step name="decompose_task">
    Break the task into phases that each fit within a single context window.
    Each phase should be independently completable — if compaction fires between
    phases, the handoff manifest should be sufficient to continue.
  </step>

  <step name="identify_delegations">
    Which phases involve heavy file reading or exploration?
    These should be delegated to subagents to keep the main context clean.
    Mark these as "subagent: true" in the plan.
  </step>

  <step name="estimate_cost">
    For each phase, estimate token cost:
    - File reads: ~100 tokens per KB of source code
    - Tool outputs: ~500-2000 tokens per bash command
    - Conversation: ~200 tokens per turn (user + assistant)
    - Skill loading: check estimated_tokens in skill-registry.json
  </step>

  <step name="place_checkpoints">
    Insert /clp:checkpoint calls at natural breakpoints:
    - After each phase completes
    - Before any phase that might trigger compaction
    - Before switching from planning to implementation
  </step>
</planning_steps>

<plan_format>
## CLP Execution Plan: [task name]

**Available budget:** [X]k tokens remaining
**Estimated total cost:** [Y]k tokens
**Phases:** [N] | **Checkpoints:** [M] | **Subagent tasks:** [P]

### Phase 1: [name] (~[X]k tokens)
- [ ] [step 1]
- [ ] [step 2]
- **Skills needed:** [skill IDs]
- **Subagent:** [yes/no — if yes, what it investigates]
- ⏸ **Checkpoint after this phase**

### Phase 2: [name] (~[X]k tokens)
...

### Execution notes
- [Any risks, dependencies, or ordering constraints]
- [Suggested Plan Mode vs Normal Mode for each phase]
</plan_format>
</instructions>

<rules>
- Every plan must include at least one checkpoint.
- If estimated total cost exceeds 60% of available budget, split into multiple sessions.
- Exploration phases (reading code to understand it) should always use subagents.
- Implementation phases should be in the main context.
- Suggest Plan Mode (Shift+Tab) for planning/analysis phases to halve token cost.
- If $ARGUMENTS is empty, ask the user what they want to accomplish.
</rules>
