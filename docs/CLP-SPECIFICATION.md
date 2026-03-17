# Context Lifecycle Protocol (CLP) v1.0

## What this is

CLP is a unified protocol for managing Claude Code's context window as a structured,
zone-allocated, budget-tracked resource with standardized lifecycle states and a
machine-readable interchange format for session handoff.

It replaces the current patchwork of individual optimizations (CLAUDE.md diets,
ad-hoc PreCompact hooks, manual /compact discipline) with a single coherent system.

---

## The core idea

Context is memory. Treat it like an operating system treats RAM:

- **Zones** with different eviction policies (kernel = protected, active = demand-loaded, working = LRU-evictable, buffer = staging)
- **Budget accounting** that tracks per-zone allocation in real time
- **A state machine** governing lifecycle transitions (init → active → compact → handoff → resume)
- **A standardized interchange format** so any session can consume another session's state

---

## 1. Context zones

The 200K token window is partitioned into four zones. Each zone has a purpose,
a size budget, and an eviction policy.

### 1.1 Kernel zone (protected, ≤22K tokens)

**What lives here:** System prompt, pointer-index CLAUDE.md, .claude/rules/, hard
constraints, and the CLP runtime manifest (the index of what's available to load).

**Eviction policy:** Never. This zone is protected from compaction. Everything here
persists for the entire session lifetime.

**Why it matters:** This is the minimum viable context. A session with only the
kernel zone loaded should be able to: identify the project, know what rules apply,
and know where to find everything else. It should NOT contain detailed documentation,
examples, edge cases, or verbose tool schemas.

**Budget discipline:**
- Root CLAUDE.md: ≤2,000 tokens (pointer index, not knowledge dump)
- Rules directory: ≤2,000 tokens (hard rules only, no examples)
- CLP manifest: ≤500 tokens (JSON index of available skills/docs)
- System prompt + built-in tools: ~17,000 tokens (not user-controllable)
- **Total kernel: ≤22,000 tokens (~11% of budget)**

### 1.2 Active zone (demand-loaded, ≤40K tokens)

**What lives here:** Skill documentation, spec files, design docs, MCP tool schemas
— anything loaded in response to the current task. Content enters this zone via
trigger-keyword matching from the skill registry.

**Eviction policy:** Task-scoped. When the task changes (detected via prompt analysis),
stale active context can be evicted to make room. Within a task, active context persists.

**Loading mechanism:** The UserPromptSubmit hook scans each message against the skill
registry. Matched skills are loaded into the active zone. Unmatched skills stay on disk.
MCP Tool Search handles tool schema loading the same way.

**Budget discipline:**
- Each skill file: typically 500–3,000 tokens
- MCP tool schemas (when loaded): 50–100 tokens per tool (summary mode)
- **Target: ≤40,000 tokens allocated, but only loaded content counts**

### 1.3 Working zone (evictable, fills remainder)

**What lives here:** Conversation history, tool outputs (file reads, bash results,
grep matches), Claude's responses, and intermediate reasoning.

**Eviction policy:** LRU with compression. Oldest tool outputs are cleared first.
Conversation turns are summarized (not deleted) when space is needed. Recent turns
are preserved at full fidelity.

**This is where bloat happens.** A single file read can inject 5K–15K tokens. A
debugging session generates tens of thousands. The working zone is where budget
accounting matters most.

**Budget discipline:**
- Tool outputs: compressed or cleared after use (keep summary, drop raw output)
- Conversation: most recent 5–10 turns at full fidelity, older turns summarized
- **Available space: 200K - kernel - active - buffer = ~125K–165K tokens**

### 1.4 Buffer zone (staging, ≤5K tokens)

**What lives here:** Pre-compaction handoff data, checkpoint summaries, and the
current budget ledger snapshot.

**Eviction policy:** Flushed to disk on compaction or session end. Never evicted
during normal operation.

**Purpose:** This is the "crash recovery" zone. At any point, the buffer contains
enough structured data to rebuild a working session from scratch. The PreCompact
hook reads this zone and writes it to disk as the handoff manifest.

**Budget discipline:**
- Handoff state: ≤3,000 tokens
- Budget ledger snapshot: ≤500 tokens
- **Total buffer: ≤5,000 tokens (~2.5% of budget)**

---

## 2. Lifecycle state machine

CLP defines five states and the transitions between them.

```
INIT → ACTIVE → COMPACT → HANDOFF → RESUME → ACTIVE
                    ↑                              |
                    └──────────────────────────────-┘
```

### 2.1 INIT state

**Trigger:** Session start (new, resume, or after /clear).

**Actions:**
1. Load kernel zone (CLAUDE.md pointer index, rules, CLP manifest)
2. Run SessionStart hook to check for handoff manifests
3. If handoff found: transition to RESUME
4. If no handoff: transition to ACTIVE with empty working zone
5. Initialize budget ledger with zone allocations

**Exit condition:** Kernel zone loaded, budget ledger initialized.

### 2.2 ACTIVE state

**Trigger:** INIT complete or RESUME complete.

**Actions (continuous):**
1. On each user message: scan against skill registry, load matched skills into active zone
2. On each tool output: record in working zone, update budget ledger
3. On StatusLine tick: check budget utilization per zone
4. If working zone exceeds 80% of its allocation: trigger progressive backup to buffer
5. If total utilization exceeds compaction threshold: transition to COMPACT

**Exit condition:** Budget threshold exceeded, user triggers /compact, or /clear.

### 2.3 COMPACT state

**Trigger:** Auto-compaction threshold or manual /compact.

**Actions:**
1. PreCompact hook fires
2. Buffer zone contents flushed to disk as handoff manifest
3. Working zone summarized (conversation compressed, tool outputs cleared)
4. Active zone evaluated: stale skills evicted, relevant skills preserved
5. Budget ledger reset with new allocations
6. Transition to HANDOFF

**Exit condition:** Compaction complete, handoff written.

### 2.4 HANDOFF state

**Trigger:** COMPACT complete or session ending.

**Actions:**
1. Generate handoff manifest (see §3 for format)
2. Write manifest to .claude/handoffs/{session-id}-{timestamp}.json
3. Update .claude/handoffs/latest.json pointer
4. If session ending: write session memory file, run Stop hook
5. If compaction: transition back to ACTIVE with restored kernel + buffer

**Exit condition:** Handoff manifest written to disk.

### 2.5 RESUME state

**Trigger:** INIT finds a handoff manifest.

**Actions:**
1. Read latest handoff manifest
2. Restore kernel zone (should already be loaded)
3. Restore active zone: reload skills listed in manifest's active_skills
4. Inject working context: goals, decisions, pending tasks from manifest
5. Initialize budget ledger from manifest's budget snapshot
6. Transition to ACTIVE

**Exit condition:** Context restored, budget initialized.

---

## 3. Handoff manifest format

The handoff manifest is a JSON file that fully describes a session's state at a
point in time. Any Claude Code session can consume it to resume work.

```json
{
  "clp_version": "1.0",
  "session_id": "abc123",
  "timestamp": "2026-03-17T14:30:00Z",
  "project": "/path/to/project",

  "state": {
    "current_goal": "Implement OAuth2 flow with PKCE for the mobile app",
    "status": "in_progress",
    "phase": "implementation"
  },

  "context": {
    "decisions": [
      {
        "decision": "Use NextAuth with custom provider for OAuth",
        "rationale": "Better integration with existing Next.js middleware",
        "timestamp": "2026-03-17T13:45:00Z"
      }
    ],
    "discoveries": [
      "The existing auth middleware expects JWT, not opaque tokens",
      "Rate limiting is enforced at the gateway level, not per-service"
    ],
    "errors_resolved": [
      {
        "error": "PKCE challenge mismatch on callback",
        "resolution": "Base64url encoding without padding, not base64",
        "file": "lib/auth/pkce.ts"
      }
    ]
  },

  "files": {
    "modified": [
      { "path": "lib/auth/pkce.ts", "change": "Added PKCE challenge generation" },
      { "path": "app/api/auth/callback/route.ts", "change": "Added token exchange endpoint" }
    ],
    "created": [
      { "path": "lib/auth/oauth-provider.ts", "change": "Custom OAuth provider config" }
    ]
  },

  "tasks": {
    "completed": [
      "Set up PKCE challenge/verifier generation",
      "Implement authorization redirect endpoint",
      "Implement token exchange callback"
    ],
    "pending": [
      "Add refresh token rotation",
      "Write integration tests for the full flow",
      "Update API documentation"
    ],
    "blocked": []
  },

  "active_skills": [
    "docs/specs/auth-spec.md",
    "docs/design/api-conventions.md"
  ],

  "budget": {
    "kernel": { "allocated": 22000, "used": 19500 },
    "active": { "allocated": 40000, "used": 12000 },
    "working": { "allocated": 133000, "used": 98000 },
    "buffer": { "allocated": 5000, "used": 2200 }
  }
}
```

**Design principles for the manifest:**

1. **Machine-readable first.** JSON, not markdown. A hook script can parse it
   programmatically. A human can read it, but it's optimized for automated restoration.

2. **Minimal but complete.** Everything a fresh session needs to continue work
   without asking clarifying questions. Nothing it doesn't need.

3. **Composable.** Multiple manifests can be merged for parallel session coordination.
   The ledger pattern from Phase 5 of the plan reads from these manifests.

4. **Versioned.** The clp_version field enables forward compatibility as the
   protocol evolves.

---

## 4. Budget ledger

The budget ledger tracks real-time token allocation and utilization per zone.
It's maintained by a StatusLine hook that updates on every turn.

```json
{
  "total_capacity": 200000,
  "zones": {
    "kernel":  { "max": 22000, "current": 19500, "policy": "protected" },
    "active":  { "max": 40000, "current": 12000, "policy": "task_scoped" },
    "working": { "max": 133000, "current": 45000, "policy": "lru_evict" },
    "buffer":  { "max": 5000,  "current": 800,   "policy": "flush_on_compact" }
  },
  "utilization": 0.387,
  "thresholds": {
    "backup_start": 0.40,
    "backup_interval_tokens": 10000,
    "compact_warning": 0.75,
    "compact_trigger": 0.85
  },
  "last_backup": null,
  "backups_written": 0
}
```

The StatusLine displays: `CLP: 38.7% | K:19.5k A:12k W:45k B:0.8k`

---

## 5. Skill registry

The skill registry maps trigger keywords to loadable context files.
It's the routing table that makes demand-loading work.

```json
{
  "skills": [
    {
      "id": "auth",
      "triggers": ["auth", "oauth", "login", "jwt", "token", "session", "pkce"],
      "files": ["docs/specs/auth-spec.md"],
      "estimated_tokens": 1200,
      "zone": "active"
    },
    {
      "id": "api-design",
      "triggers": ["api", "endpoint", "rest", "route", "controller"],
      "files": ["docs/design/api-conventions.md"],
      "estimated_tokens": 800,
      "zone": "active"
    },
    {
      "id": "testing",
      "triggers": ["test", "spec", "jest", "vitest", "coverage", "mock"],
      "files": ["docs/guides/testing.md"],
      "estimated_tokens": 1500,
      "zone": "active"
    },
    {
      "id": "debugging",
      "triggers": ["bug", "error", "fix", "debug", "stack trace", "crash"],
      "files": ["docs/guides/debugging.md"],
      "estimated_tokens": 600,
      "zone": "active"
    }
  ],
  "fallback": "If no skills match, load only the pointer index."
}
```

---

## 6. File layout

CLP lives entirely within standard Claude Code conventions:

```
project-root/
├── CLAUDE.md                          # Pointer index (<2K tokens)
├── .claudeignore                      # Exclude noise
├── .claude/
│   ├── settings.json                  # Hook configuration
│   ├── clp/
│   │   ├── manifest.json              # CLP runtime manifest
│   │   ├── skill-registry.json        # Trigger-keyword routing
│   │   └── budget-config.json         # Zone allocations + thresholds
│   ├── hooks/
│   │   ├── clp-session-start.sh       # INIT: load kernel, check handoffs
│   │   ├── clp-prompt-scan.sh         # ACTIVE: skill trigger matching
│   │   ├── clp-pre-compact.sh         # COMPACT: generate handoff manifest
│   │   ├── clp-post-compact.sh        # Post-compact: restore from buffer
│   │   └── clp-session-end.sh         # HANDOFF: write session memory
│   ├── handoffs/
│   │   ├── latest.json                # Pointer to most recent handoff
│   │   └── {session-id}-{ts}.json     # Handoff manifests
│   └── sessions/
│       └── {date}-session.md          # Daily session memory files
├── docs/
│   ├── specs/                         # Demand-loaded specifications
│   ├── design/                        # Demand-loaded design docs
│   └── guides/                        # Demand-loaded guides
└── {component}/
    └── CLAUDE.md                      # Component-specific (auto-loaded)
```

Everything under .claude/ is git-committable. Handoff manifests can be
.gitignored (they're ephemeral) or committed (for team coordination).

---

## 7. What makes this different

| Approach | Problem it solves | What it misses |
|----------|------------------|----------------|
| CLAUDE.md diet | Reduces static bloat | No runtime management |
| .claudeignore | Reduces file-read noise | No active budget tracking |
| MCP Tool Search | Lazy-loads tool schemas | Only covers MCP, not docs/skills |
| PreCompact hooks | Saves state before compaction | No standardized format, no zones |
| Session memory files | Cross-session continuity | No budget awareness, manual |
| Subagent delegation | Isolates verbose operations | No coordination protocol |
| **CLP** | **All of the above as one system** | **—** |

CLP unifies these by defining:
1. A zone model that makes budget allocation explicit
2. A state machine that governs transitions between lifecycle phases
3. A standardized interchange format that any session can produce or consume
4. A skill registry that makes demand-loading systematic instead of ad-hoc
5. A budget ledger that makes resource usage visible in real time

---

## 8. Implementation order

1. **Kernel zone + pointer index** (Day 1): Restructure CLAUDE.md, create manifest
2. **Skill registry + prompt scanning hook** (Day 2-3): Build the demand-loading layer
3. **Budget ledger + StatusLine** (Day 4-5): Real-time token accounting
4. **Handoff manifest + PreCompact hook** (Day 6-8): Standardized state capture
5. **SessionStart restoration** (Day 9-10): Automated resume from manifest
6. **Session memory + Stop hook** (Day 11-13): Cross-session knowledge persistence
7. **Multi-session coordination** (Day 14-18): Ledger-based parallel workflows

Each step is independently useful. Step 1 alone saves 50%+ baseline tokens.
The full system, once operational, eliminates context bloat as a problem category.

---

## 9. Compatibility guarantee

CLP uses exclusively:
- CLAUDE.md files (standard Claude Code feature)
- .claude/hooks/ with shell scripts (standard hooks API)
- .claude/settings.json (standard configuration)
- .claudeignore (standard exclusion)
- /compact, /clear, /context (standard commands)
- Subagents via Task tool (standard delegation)
- Auto Memory via MEMORY.md (standard persistence)

No forks. No patches. No undocumented APIs. No version-specific workarounds.
If it runs Claude Code, it runs CLP.
