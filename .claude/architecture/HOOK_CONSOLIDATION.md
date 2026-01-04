# Hook Architecture Consolidation

## Phase 1 Research Findings

### Current State (Inventory)

**23 files, ~4,260 lines total**

**Over 500 lines (needs splitting):**
- process_enforcer.rb: 924 lines - MAIN, does too much
- prompt_analyzer.rb: 634 lines - Prompt classification

**200-500 lines:**
- session_summary_validator.rb: 344 lines
- research_tracker.rb: 236 lines
- session_start.rb: 207 lines
- edit_validator.rb: 193 lines
- phase_manager.rb: 191 lines (module)
- state_signer.rb: 189 lines (module)
- deeper_look_trigger.rb: 182 lines

**Under 200 lines:**
- pattern_learner.rb: 152 lines
- test_quality_checker.rb: 150 lines
- rule_tracker.rb: 148 lines (module)
- sop_mapper.rb: 147 lines
- saneloop_enforcer.rb: 140 lines
- failure_tracker.rb: 130 lines
- stop_validator.rb: 121 lines
- path_rules.rb: 110 lines
- shortcut_detectors.rb: 106 lines (module)
- version_mismatch.rb: 96 lines
- audit_logger.rb: 95 lines
- circuit_breaker.rb: 93 lines
- two_fix_reminder.rb: 77 lines
- skill_validator.rb: 69 lines
- verify_reminder.rb: 37 lines

### Critical Issues Found

1. **process_enforcer.rb is 924 lines** - violates Rule #10 (800 max)
2. **bypass.rb is MISSING** - referenced but deleted, will cause runtime errors
3. **Duplicate concerns:**
   - Circuit breaker logic in 3 files
   - Research tracking in 2 files
   - SaneLoop enforcement in 3 files
   - Edit counting in 5 files
   - Bypass checking in 5 files
4. **Inconsistent state signing** - some files use StateSigner, others don't
5. **15+ separate state files** - hard to reason about

### Patterns from Industry (Pre-commit, ESLint, RuboCop, Husky)

1. **Separation of Concerns**: Detection -> Coordination -> Action
2. **Centralized State**: One state manager, file locking for concurrency
3. **Registry Pattern**: Hooks register themselves, coordinator runs them
4. **Configuration-Driven**: YAML/JSON config, not hardcoded
5. **Bail Semantics**: First blocker wins, others skip

---

## Target Architecture

```
scripts/hooks/
├── core/
│   ├── state_manager.rb      # Single source of truth for all state
│   ├── hook_registry.rb      # Hook discovery and registration
│   ├── coordinator.rb        # Detection -> Decision -> Action pipeline
│   └── config.rb             # Load .claude/hooks.yml
│
├── detectors/                # Pure detection - return findings, don't act
│   ├── base_detector.rb      # Shared interface
│   ├── research_detector.rb  # Is research done?
│   ├── saneloop_detector.rb  # Is saneloop required/active?
│   ├── circuit_detector.rb   # Is circuit breaker tripped?
│   ├── size_detector.rb      # File size violations?
│   ├── path_detector.rb      # Dangerous paths?
│   ├── shortcut_detector.rb  # Weasel words, lazy patterns?
│   └── summary_detector.rb   # Valid session summary?
│
├── actions/                  # What to do with detections
│   ├── blocker.rb            # Exit 2
│   ├── warner.rb             # Emit warning, exit 0
│   └── logger.rb             # Log to audit trail
│
├── trackers/                 # State mutations (PostToolUse)
│   ├── edit_tracker.rb       # Count edits, track files
│   ├── failure_tracker.rb    # Count failures, trip breaker
│   ├── research_tracker.rb   # Mark research complete
│   └── pattern_tracker.rb    # Learn from corrections
│
├── hooks/                    # Entry points (called by Claude Code)
│   ├── pre_tool_use.rb       # Runs detectors, coordinates response
│   ├── post_tool_use.rb      # Runs trackers, logs
│   ├── user_prompt.rb        # Prompt analysis
│   ├── session_start.rb      # Bootstrap
│   ├── session_end.rb        # Cleanup
│   └── stop.rb               # Post-response validation
│
└── legacy/                   # Old hooks during migration
    └── *.rb
```

### State Manager Design

**Single file: `.claude/state.json`**

```json
{
  "__signature__": "hmac...",
  "__updated_at__": "2026-01-04T...",

  "circuit_breaker": {
    "failures": 0,
    "tripped": false,
    "last_error": null
  },

  "requirements": {
    "requested": ["research", "saneloop"],
    "satisfied": ["research"]
  },

  "research": {
    "memory": { "completed_at": "...", "via_task": true },
    "docs": null,
    "web": null,
    "github": null,
    "local": null
  },

  "edits": {
    "count": 5,
    "unique_files": ["a.swift", "b.swift"]
  },

  "saneloop": {
    "active": true,
    "task": "Phase 1",
    "iteration": 3,
    "max_iterations": 20
  }
}
```

**API:**
```ruby
StateManager.get(:circuit_breaker, :failures)  # => 0
StateManager.set(:circuit_breaker, :failures, 1)
StateManager.update(:edits) { |e| e[:count] += 1; e }
StateManager.reset(:research)
```

### Coordinator Flow

```
Input arrives (tool_name, tool_input)
    |
    v
DETECTION PHASE (parallel)
Each detector returns:
{ detected: bool, severity: :block/:warn/:info, message: "..." }
  - circuit_detector.detect()
  - research_detector.detect()
  - saneloop_detector.detect()
  - size_detector.detect()
  - path_detector.detect()
    |
    v
DECISION PHASE
Sort by severity (block > warn)
Check enforcement breaker
(5x same block = halt system)
    |
    v
ACTION PHASE
If any :block -> Blocker.block()
If any :warn -> Warner.warn()
Always -> Logger.log()
```

### Configuration (.claude/hooks.yml)

```yaml
detectors:
  circuit:
    enabled: true
    threshold: 3

  research:
    enabled: true
    require_task_agents: true
    categories:
      - memory
      - docs
      - web
      - github
      - local

  size:
    enabled: true
    soft_limit: 500
    hard_limit: 800

  path:
    enabled: true
    blocked:
      - ~/.ssh
      - ~/.aws
      - ~/.claude_hook_secret
```

---

## Migration Plan

### Phase 2: State Manager
- Create `core/state_manager.rb`
- Single `.claude/state.json` file
- Migrate circuit_breaker.json first (simplest)
- Keep old files during migration

### Phase 3: Enforcement Engine Core
- Create `core/coordinator.rb`
- Create `core/hook_registry.rb`
- Basic detection -> decision -> action flow

### Phase 4: Detection Layer
- Extract detectors from process_enforcer.rb
- Each detector < 100 lines
- Pure functions, no side effects

### Phase 5: Logging & Reporting
- Unified audit logger
- Rule tracking consolidation
- Session reports

### Phase 6: Integration
- Update settings.json
- Wire up new hooks
- Remove legacy hooks

### Phase 7: Testing
- Verify each rule still fires
- Test bypass attempts blocked
- Verify state persistence

---

## Success Criteria

- [ ] No file > 200 lines (except coordinator ~300)
- [ ] Single state file
- [ ] All detectors testable in isolation
- [ ] `ruby -c` passes on all files
- [ ] Intentional violations still blocked
- [ ] 15-minute explainability test

---

## Anti-Patterns to Avoid (from Memory)

1. **NO bypass mechanisms** - Claude doesn't design escape hatches
2. **NO skip_once patterns** - One targeted fix per bug
3. **Clear state on SaneLoop start** - Prevent stale bypass
4. **Use warn() not JSON** - For visible output
5. **Sign all enforcement state** - Prevent tampering
