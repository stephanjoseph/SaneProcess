# SaneProcess

A battle-tested SOP enforcement system for Claude Code.

## Quick Start

```bash
# In your project folder:
curl -sL saneprocess.dev/init | bash

# Or run locally:
./scripts/init.sh
```

## What's Inside

```
SaneProcess/
├── docs/
│   ├── SaneProcess.md    # Full documentation (the SOP)
│   └── SaneProcess.pdf   # PDF version for distribution
├── scripts/
│   └── init.sh           # Project initializer (detects type, creates configs)
└── examples/             # Example configurations
```

## The Problem

Claude Code is powerful but undisciplined. It:
- Guesses the same broken fix 10 times (doom loops)
- Assumes APIs exist without checking
- Skips tests, forgets to verify
- Loses context between sessions

## The Solution

SaneProcess enforces discipline through:

1. **Golden Rules** - 11 memorable rules like "TWO STRIKES? INVESTIGATE"
2. **Circuit Breaker** - Auto-stops after 3 same errors or 5 total failures
3. **Memory System** - Persists bug patterns across sessions
4. **Hooks** - Automatic enforcement via Claude Code hooks
5. **Self-Rating** - Accountability after every task

## Target Users

- Developers using Claude Code for macOS/iOS development
- Teams wanting consistent AI-assisted coding practices
- Anyone tired of AI wasting time on doom loops

## Version

2.1 - January 2026
