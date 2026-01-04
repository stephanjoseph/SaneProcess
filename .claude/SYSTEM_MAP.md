# Hook System Architecture Map

## Overview

Dead simple: 4 hooks, 4 core modules, 1 state file.

```
┌─────────────────────────────────────────────────────────────────┐
│                        Claude Code                               │
└─────────────────────────┬───────────────────────────────────────┘
                          │
    ┌─────────────────────┼─────────────────────┐
    │                     │                     │
    ▼                     ▼                     ▼
┌─────────┐         ┌─────────┐          ┌─────────┐
│ Prompt  │         │  Tool   │          │  Stop   │
│ Submit  │         │  Call   │          │         │
└────┬────┘         └────┬────┘          └────┬────┘
     │                   │                    │
     ▼                   ▼                    ▼
┌─────────┐    ┌────────────────┐      ┌─────────┐
│saneprompt│    │   sanetools   │      │sanestop │
│   .rb   │    │     .rb       │      │   .rb   │
└────┬────┘    └───────┬───────┘      └────┬────┘
     │                 │                   │
     │          ┌──────┴──────┐            │
     │          ▼             ▼            │
     │    ┌─────────┐   ┌─────────┐        │
     │    │  ALLOW  │   │  BLOCK  │        │
     │    │ exit 0  │   │ exit 2  │        │
     │    └─────────┘   └─────────┘        │
     │                                     │
     │         Tool Executes...            │
     │                │                    │
     │                ▼                    │
     │         ┌─────────┐                 │
     │         │sanetrack│                 │
     │         │   .rb   │                 │
     │         └────┬────┘                 │
     │              │                      │
     └──────────────┼──────────────────────┘
                    │
                    ▼
           ┌────────────────┐
           │  state.json    │
           │ (single file)  │
           └────────────────┘
```

---

## Entry Points (settings.json)

| Hook Type         | Script           | When                    | Exit Codes        |
|-------------------|------------------|-------------------------|-------------------|
| UserPromptSubmit  | saneprompt.rb    | User sends message      | 0=allow           |
| PreToolUse        | sanetools.rb     | Before tool executes    | 0=allow, 2=block  |
| PostToolUse       | sanetrack.rb     | After tool completes    | 0=always (done)   |
| Stop              | sanestop.rb      | Session ends            | 0=allow           |

---

## Core Modules

```
scripts/hooks/core/
├── config.rb         # Paths, thresholds, settings
├── state_manager.rb  # Read/write state.json
├── hook_registry.rb  # Detector registration (unused - future)
└── coordinator.rb    # Orchestration layer (unused - future)
```

### config.rb
Single source for all configuration:
- `Config.project_dir` - Project root
- `Config.claude_dir` - .claude directory
- `Config.state_file` - state.json path
- `Config.bypass_file` - bypass_active.json path
- `Config.bypass_active?` - Is safemode enabled?
- `Config.circuit_breaker_threshold` - 3
- `Config.file_size_warning` - 500 lines
- `Config.file_size_limit` - 800 lines
- `Config.blocked_paths` - System paths to block

### state_manager.rb
All state in one signed JSON file:
- `StateManager.get(:section, :key)` - Read value
- `StateManager.set(:section, :key, value)` - Write value
- `StateManager.update(:section) { |s| s }` - Block update
- `StateManager.reset(:section)` - Reset to defaults
- File locking for concurrent access
- HMAC signing for tamper detection

---

## State Schema (.claude/state.json)

```
{
  "circuit_breaker": {
    "failures": 0,           # Consecutive failures
    "tripped": false,        # Is breaker tripped?
    "tripped_at": null,      # When tripped
    "last_error": null,      # Last error message
    "error_signatures": {}   # Per-signature counts
  },
  "requirements": {
    "requested": [],         # What user asked for
    "satisfied": [],         # What's been completed
    "is_task": false,        # Is this a task?
    "is_big_task": false     # Is this a big task?
  },
  "research": {
    "memory": null,          # MCP memory checked?
    "docs": null,            # Docs checked?
    "web": null,             # Web searched?
    "github": null,          # GitHub searched?
    "local": null            # Local files searched?
  },
  "edits": {
    "count": 0,              # Total edit count
    "unique_files": [],      # Files edited
    "last_file": null        # Last file edited
  },
  "saneloop": {
    "active": false,         # Is loop running?
    "task": null,            # Current task
    "iteration": 0,          # Current iteration
    "max_iterations": 20,    # Max before stop
    "acceptance_criteria": [],
    "started_at": null
  },
  "enforcement": {
    "blocks": [],            # Recent blocks
    "halted": false,         # Enforcement halted?
    "halted_at": null,
    "halted_reason": null
  },
  "action_log": [],          # Last 20 actions
  "learnings": []            # Learned patterns
}
```

---

## Data Flow

### 1. User Prompt → saneprompt.rb

```
User message
    │
    ▼
┌─────────────────────────┐
│     saneprompt.rb       │
├─────────────────────────┤
│ 1. Check for commands:  │
│    s+/s-/s? (safemode)  │
│    rb-/rb?  (breaker)   │
│    research (progress)  │
│                         │
│ 2. Classify prompt:     │
│    - Question? Skip     │
│    - Task? Gate edits   │
│    - Edit? Check gates  │
│                         │
│ 3. Check circuit breaker│
│    - 3 failures? Warn   │
│    - Tripped? Suggest   │
│      reset              │
└─────────────────────────┘
```

### 2. Tool Call → sanetools.rb

```
Tool call (Edit, Bash, etc.)
    │
    ▼
┌─────────────────────────┐
│      sanetools.rb       │
├─────────────────────────┤
│ 1. Bootstrap check:     │
│    Always allow Read,   │
│    Glob, Grep, MCP      │
│                         │
│ 2. Safemode check:      │
│    If s+ active, block  │
│    edits                │
│                         │
│ 3. Research gate:       │
│    Must complete 5      │
│    categories before    │
│    edits                │
│                         │
│ 4. Path check:          │
│    Block system paths   │
│    (.ssh, /etc, etc)    │
│                         │
│ 5. Size check:          │
│    Warn >500, block >800│
└─────────────────────────┘
    │
    ├─── exit 0 ──► Tool executes
    │
    └─── exit 2 ──► Tool blocked
```

### 3. Tool Result → sanetrack.rb

```
Tool result (success/failure)
    │
    ▼
┌─────────────────────────┐
│      sanetrack.rb       │
├─────────────────────────┤
│ 1. Track edits:         │
│    Count, unique files  │
│                         │
│ 2. Track research:      │
│    Mark category done   │
│    when tool used       │
│                         │
│ 3. Detect failures:     │
│    Check error field,   │
│    exit code, stderr    │
│    (NOT text matching!) │
│                         │
│ 4. Circuit breaker:     │
│    Increment failures   │
│    Track signatures     │
│    Trip at threshold    │
│                         │
│ 5. Log for learning:    │
│    Save action_log      │
└─────────────────────────┘
```

---

## Commands

### Safemode (saneprompt.rb)
- `s+` - Enable safemode (blocks edits)
- `s-` - Disable safemode
- `s?` - Show safemode status

### Circuit Breaker (saneprompt.rb)
- `rb-` or `rb+` or `reset breaker` - Reset circuit breaker
- `rb?` or `breaker status` - Show breaker status

### Research (saneprompt.rb)
- `research` - Show research progress

---

## Circuit Breaker Logic

```
Tool fails
    │
    ▼
Normalize error signature
(COMMAND_NOT_FOUND, SYNTAX_ERROR, etc.)
    │
    ├─── Increment failures count
    │
    ├─── Increment per-signature count
    │
    ▼
Check thresholds:
- 3 consecutive failures? → Trip
- 3x same signature? → Trip
    │
    ▼
If tripped:
- Block edits
- Show warning
- Suggest: "reset breaker"
```

---

## Research Gate Logic

```
Before Edit/Write allowed:
    │
    ▼
Check 5 categories:
┌──────────┬────────────────────────────┐
│ Category │ Satisfied by               │
├──────────┼────────────────────────────┤
│ memory   │ mcp__memory__*             │
│ docs     │ mcp__context7__*           │
│          │ mcp__apple-docs__*         │
│ web      │ WebSearch, WebFetch        │
│ github   │ mcp__github__*             │
│ local    │ Grep, Glob, Read           │
└──────────┴────────────────────────────┘
    │
    ▼
All 5 done? → Allow edits
Missing? → Block + show missing
```

---

## File Locations

```
.claude/
├── state.json           # All hook state (signed)
├── state.json.lock      # File lock
├── bypass_active.json   # Safemode marker (exists = active)
├── saneprompt.log       # Prompt hook log
├── sanetools.log        # Tools hook log
├── sanetrack.log        # Track hook log
├── sanestop.log         # Stop hook log
└── audit.jsonl          # Audit log

scripts/hooks/
├── saneprompt.rb        # UserPromptSubmit
├── sanetools.rb         # PreToolUse
├── sanetrack.rb         # PostToolUse
├── sanestop.rb          # Stop
├── core/
│   ├── config.rb        # Configuration
│   ├── state_manager.rb # State management
│   ├── hook_registry.rb # (future) Registry
│   └── coordinator.rb   # (future) Orchestration
└── legacy/              # Old hooks (archived)
```

---

## Testing

Each main hook has self-tests:

```bash
ruby scripts/hooks/saneprompt.rb --self-test  # 26 tests
ruby scripts/hooks/sanetools.rb --self-test   # 11 tests
ruby scripts/hooks/sanetrack.rb --self-test   # 8 tests
ruby scripts/hooks/sanestop.rb --self-test    # 4 tests
ruby scripts/hooks/core/config.rb --self-test # 5 tests
```

Total: 54 tests

---

## Exit Codes

| Code | Meaning                     | Effect               |
|------|-----------------------------|----------------------|
| 0    | Allow                       | Tool proceeds        |
| 1    | Warning (deprecated)        | Tool proceeds        |
| 2    | Block                       | Tool prevented       |

---

## Design Principles

1. **One state file** - No scattered JSON files
2. **Exit codes matter** - 0 allow, 2 block
3. **Fail safe** - On error, allow (don't block randomly)
4. **Self-testable** - Every hook has --self-test
5. **Centralized config** - All paths in Config module
6. **Text ≠ Error** - Check explicit error fields, not content
