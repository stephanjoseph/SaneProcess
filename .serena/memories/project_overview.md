# SaneProcess Project Overview

## Purpose
SaneProcess is an SOP (Standard Operating Procedure) enforcement system for Claude Code that prevents AI doom loops through automated rule enforcement, circuit breakers, and persistent memory.

## Tech Stack
- **Language**: Ruby (hooks and CLI)
- **Target**: macOS (Darwin)
- **Integration**: Claude Code hooks system

## Project Structure
```
scripts/
├── hooks/                    # 4 main enforcement hooks
│   ├── saneprompt.rb        # UserPromptSubmit - classify intent
│   ├── sanetools.rb         # PreToolUse - block until research done
│   ├── sanetrack.rb         # PostToolUse - track failures
│   ├── sanestop.rb          # Stop - capture learnings
│   └── core/                # Shared modules
│       ├── state_manager.rb # Thread-safe JSON state
│       └── config.rb        # Configuration
├── sanemaster/              # 19 CLI modules
└── qa.rb                    # Quality checks
.claude/
├── rules/                   # Pattern-based rules
│   ├── views.md, tests.md, services.md, models.md, scripts.md, hooks.md
└── settings.json            # Hook configuration
```

## Key Concepts
- **16 Golden Rules**: Scientific method enforcement for AI
- **Circuit Breaker**: Auto-stops after 3 consecutive failures
- **State Signing**: HMAC signatures prevent tampering
- **Cross-Project Sync**: Hooks shared with SaneBar, SaneVideo, SaneSync
