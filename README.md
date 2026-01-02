# SaneProcess

**Battle-tested SOP enforcement for Claude Code.**

Stop AI doom loops. Ship reliable code.

---

## The Problem

Claude Code is powerful but undisciplined:
- Guesses the same broken fix 10 times
- Assumes APIs exist without checking
- Skips verification, forgets context
- Wastes 20+ minutes on preventable mistakes

## The Solution

SaneProcess enforces discipline through:

| Feature | What It Does |
|---------|--------------|
| **11 Golden Rules** | Memorable rules like "TWO STRIKES? INVESTIGATE" |
| **Circuit Breaker** | Auto-stops after 3 same errors or 5 total failures |
| **Memory System** | Bug patterns persist across sessions |
| **Compliance Loop** | Enforced task completion with verification |
| **Self-Rating** | Accountability after every task |

## What's Included

```
├── docs/SaneProcess.md      # Complete SOP documentation (1,100+ lines)
├── scripts/init.sh          # One-command project setup
├── scripts/mac_context.rb   # Mac development knowledge injection (757 lines)
├── scripts/skill_loader.rb  # Load/unload domain-specific knowledge
├── skills/                  # Modular expert knowledge
│   ├── swift-concurrency.md    # Actors, @MainActor, Swift 6.2
│   ├── swiftui-performance.md  # View anti-patterns, optimization
│   └── crash-analysis.md       # Reading crash reports, symbolication
└── Hooks & configs          # Circuit breaker, memory compactor, lefthook
```

### Skills System

Load only what you need for your current task:

```bash
ruby scripts/skill_loader.rb list                    # See available skills
ruby scripts/skill_loader.rb load swift-concurrency  # Load a skill
ruby scripts/skill_loader.rb status                  # See what's loaded
ruby scripts/skill_loader.rb unload --all            # Clear all skills
```

Skills add domain-specific knowledge to your context. Base context is 757 lines; with all skills loaded: ~1,350 lines.

## The "Supervisor" Advantage

SaneProcess isn't just rules - it's a **Mac App Factory** layer:

| Feature | What It Does |
|---------|--------------|
| **Mac Context Injection** | 757 lines of Info.plist, entitlements, sandboxing, WWDC 2025 APIs, crash analysis |
| **Circuit Breaker** | Stops Claude after 3 same errors (prevents $20 token burn) |
| **XcodeGen Integration** | Never let Claude touch .xcodeproj directly |
| **Build Loop Handler** | Captures errors, strips noise, feeds back only essentials |

---

## The Sane* Family

All tools share the **Sane** prefix so you know when you're using our battle-tested components:

| Tool | What It Does |
|------|--------------|
| **SaneProcess** | The methodology + product |
| **SaneMaster** | CLI tool for build, verify, launch, logs |
| **SaneLoop** | Iteration loop with enforced exit conditions |
| **SaneSkills** | Load/unload domain knowledge on demand |
| **SaneRules** | Path-specific guidance (Tests/, Views/, Services/) |
| **SaneBreaker** | Circuit breaker - stops after repeated failures |

Each component is designed to work together. When you see "Sane*", you know it's enforcing discipline.

---

## Pricing

**$29 one-time** - Lifetime upgrades included.

No subscriptions. No recurring fees. Pay once, get all future updates.

**To purchase:** [Open an issue](https://github.com/stephanjoseph/SaneProcess/issues/new) with subject "License Request"

---

## Preview

You can view the full source code here. To use it in your projects, purchase a license.

**Quick look at the Golden Rules:**

```
#0  NAME THE RULE BEFORE YOU CODE
#1  STAY IN YOUR LANE (files in project)
#2  VERIFY BEFORE YOU TRY (check docs)
#3  TWO STRIKES? INVESTIGATE
#4  GREEN MEANS GO (tests must pass)
#5  USE PROJECT TOOLS
#6  BUILD, KILL, LAUNCH, LOG
#7  NO TEST? NO REST
#8  FILE SIZE LIMITS (500/800)
#9  NEW FILE? UPDATE PROJECT
#10 TRACK WITH TodoWrite
```

---

## License

**Source Available** - You may view this code for evaluation. Usage requires a paid license. See [LICENSE](LICENSE) for details.

---

## Questions?

Open an issue or contact [@stephanjoseph](https://github.com/stephanjoseph)

---

*SaneProcess v2.1 - January 2026*
