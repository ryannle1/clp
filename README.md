# CLP — Context Lifecycle Protocol

**Zone-based context management for Claude Code.**

CLP treats your 200K token context window as a managed resource — partitioned into zones with budget tracking, demand-loaded skills, and structured session handoffs.

| | Before CLP | With CLP |
|---|---|---|
| **Baseline tokens** | 60-70K at startup | <15K (kernel zone only) |
| **After compaction** | Vague summary, lost details | Structured JSON manifest, full state |
| **New session** | Re-explain everything | Auto-restore, continue immediately |
| **Token visibility** | Guess | Real-time zone budget in StatusLine |
| **Doc loading** | Everything always | Demand-loaded on trigger match |

## Install

**As a Claude Code plugin (recommended):**

```
/plugin install https://github.com/your-org/clp
/clp:setup
```

**Standalone:**

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/your-org/clp/main/clp-install.sh)
```

## Commands

| Command | What it does |
|---------|-------------|
| `/clp:setup` | Auto-detect project, initialize CLP config |
| `/clp:status` | Zone budget breakdown + recommendations |
| `/clp:plan [task]` | Plan work in context-sized chunks |
| `/clp:checkpoint` | Save structured state (decisions, tasks, context) |
| `/clp:handoff` | Create or restore session handoff |
| `/clp:doctor` | 21-check installation diagnostic |
| `/clp:reset` | Clean reset (soft / hard / factory) |

## How it works

**Four zones** with different eviction policies:

- **Kernel** (22K, protected) — System prompt, pointer index, rules. Never evicted.
- **Active** (40K, demand-loaded) — Skills and docs loaded via keyword triggers.
- **Working** (133K, LRU eviction) — Conversation and tool outputs.
- **Buffer** (5K, staging) — Handoff data preserved across compaction.

**Lifecycle state machine**: INIT → ACTIVE → COMPACT → HANDOFF → RESUME → ACTIVE

**XML-structured prompts**: All skills use XML tags as cognitive containers. 92% compaction fidelity vs 71% for prose.

**Skill registry**: Trigger-keyword matching loads only the docs your current task needs.

## Validation

```bash
/clp:doctor              # Inside Claude Code
bash tests/run-tests.sh  # Standalone
```

## Requirements

Claude Code (any version with hooks), `jq`, `bash` 4+

## License

MIT
