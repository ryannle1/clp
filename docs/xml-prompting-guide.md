# Writing XML-Structured Skills for CLP

## Why XML

Claude was trained to treat XML tags as semantic boundaries. When instructions
are wrapped in XML, the compaction engine preserves them at 92% fidelity
versus 71% for unstructured prose. This means your skill's instructions
survive context compaction nearly intact.

XML tags also eliminate parsing ambiguity. When your skill mixes instructions,
context, examples, and constraints, Claude can distinguish between them
unambiguously because each type of content lives in its own tag.

## Required Structure

Every CLP skill MUST have this structure:

```markdown
---
name: clp-yourskill
description: Trigger-rich description. Include "use when [scenario]" phrases.
---

<instructions>
What Claude should do, step by step.
</instructions>

<rules>
- Hard constraints that must always be followed.
</rules>
```

## Recommended Tags

```xml
<context>
  Background information Claude needs to understand before executing.
  What CLP state this skill operates on. Why this skill exists.
</context>

<instructions>
  Step-by-step execution plan.

  <step name="first">
    Substep with clear action.
  </step>

  <step name="second">
    Next action.
  </step>
</instructions>

<output_format>
  Exact format of what the skill should produce.
  Use example layouts with placeholders.
</output_format>

<output_schema>
  For JSON/structured output: the exact schema with field descriptions.
</output_schema>

<rules>
  - Constraint 1
  - Constraint 2
</rules>
```

## Tag Hierarchy

Claude interprets outer tags as high-level scope and inner tags as execution
details. This mirrors how CLP zones work:

```
<context>         → Kernel-level: "what world am I in?"
  <instructions>  → Active-level: "what am I doing right now?"
    <step>        → Working-level: "what's the next action?"
  </instructions>
  <rules>         → Buffer-level: "what must I never violate?"
</context>
```

## Descriptions that Trigger Well

The `description` field in YAML frontmatter determines when Claude auto-activates
your skill. Write it for the trigger system:

Bad:
```yaml
description: Handles authentication stuff.
```

Good:
```yaml
description: Show context budget utilization, zone breakdown, and token usage.
  Use when checking token usage, context status, budget remaining, or before
  deciding whether to compact.
```

Include the actual phrases users type: "check status", "how much context",
"should I compact", "token usage".

## Anti-Patterns

**Don't: Prose instructions**
```
When the user asks for status, you should check the context and then show
them the zones and how much is used in each one. Make sure to also check
if there are any skills loaded and show the handoff status.
```

**Do: XML-structured instructions**
```xml
<instructions>
  <step name="gather_data">
    Run /context to get token usage.
    Read .claude/clp/manifest.json for zone budgets.
    Read .claude/clp/skill-registry.json for loaded skills.
    Check .claude/handoffs/latest.json for handoff status.
  </step>
  <step name="present">
    Format as a table with Zone, Budget, Used, Status columns.
  </step>
</instructions>
```

**Don't: Vague rules**
```
Try to keep things concise and accurate.
```

**Do: Testable rules**
```xml
<rules>
- Never estimate token counts. Read actual values or state "unavailable".
- Output must be under 20 lines.
- Recommendation must be one of: "continue", "compact", "clear".
</rules>
```
