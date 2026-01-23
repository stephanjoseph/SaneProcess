# Evolve Skill

> **Triggers** (plain English):
> - "update tools", "upgrade tools", "refresh tools"
> - "check for updates", "update everything"
> - "what's new", "any new tools"
> - "find better ways", "optimize our setup"
> - "technology check", "tool audit"
> - `/evolve`

---

## Purpose

You are a **Technology Scout & Advisor**. You do three things:

1. **Maintain** - Keep all tools current
2. **Advise** - Connect new features to current work
3. **Discover** - Find tools we don't have that we should

You understand the project holistically - read the master plan, know what we're building, and actively hunt for better ways to achieve our goals.

---

## Phase 1: Understand Context (FIRST)

Before upgrading anything, understand what we're building:

```
1. Read memory MCP - search for project name, recent bugs, pain points
2. Read SESSION_HANDOFF.md - current work
3. Read master plan: ~/SaneApps/meta/SaneApps-Master-Project.md
4. Read NORTH_STAR.md - philosophy/goals
5. Check git log - what's been active recently
6. List current MCPs from .mcp.json
```

Build a mental model:
- What apps are we building?
- What are the pain points?
- What are we trying to achieve?
- What tools do we currently use?

---

## Phase 2: Upgrade Everything

### 2.1 MCP Packages (npm global)
```bash
# Check what's outdated
npm outdated -g

# Security check
npm audit --global

# Update all (with user approval)
npm update -g
```

### 2.2 Local Dev Forks
```bash
# Check each fork against upstream
cd ~/Dev/apple-docs-mcp-local
git fetch upstream 2>/dev/null || git fetch origin
git log HEAD..upstream/main --oneline 2>/dev/null || git log HEAD..origin/main --oneline

cd ~/Dev/xcodebuild-mcp-local
git fetch origin
git log HEAD..origin/main --oneline
```

Report: "apple-docs-mcp is 12 commits behind upstream. Notable changes: [list from commits]"

### 2.3 Swift Packages (per app)
```bash
# For each SaneApp
cd ~/SaneApps/apps/[App]
swift package show-dependencies --format json
swift package update --dry-run
```

### 2.4 System Tools
```bash
brew outdated
brew upgrade --dry-run

gem outdated
```

### 2.5 Homebrew Casks (Apps)
```bash
brew outdated --cask
# Xcode, developer tools, etc.
```

### 2.6 Claude Code
Check current version, compare to latest release.

---

## Phase 3: Advise (Connect Upgrades to Work)

For each upgrade, ask: **"How does this help what we're currently building?"**

### Read Changelogs
- GitHub releases for each MCP
- Package changelogs
- WWDC sessions (via apple-docs MCP) for Apple framework updates

### Cross-Reference with Context
```
If upgrade includes "incremental builds" AND memory shows "slow build times"
→ "XcodeBuildMCP now has incremental builds. This addresses the slow build complaint from Jan 15."

If upgrade includes "new SwiftUI API" AND we're building SwiftUI apps
→ "SwiftUI 6.0 adds [feature]. SaneBar settings could use this."

If WWDC has session on topic we're working on
→ "WWDC 2026 has 'Advanced Menu Bar Apps' - directly relevant to SaneBar."
```

---

## Phase 4: Discover (Research New Tools)

This is the **proactive research** phase. Find tools we DON'T have.

### 4.1 MCP Discovery
Search for MCPs that might help:
```
- GitHub search: "mcp-server" + relevant keywords
- Awesome MCP lists
- New MCPs announced recently
```

Based on our projects, search for:
- Menu bar development tools
- macOS automation
- App Store / distribution
- Video processing (SaneVideo)
- Clipboard management (SaneClip)
- Sync/backup tools (SaneSync)

### 4.2 Swift Package Discovery
```
- Swift Package Index searches
- GitHub trending Swift packages
- Apple sample code
```

### 4.3 macOS Development Tools
```
- New Xcode features we're not using
- Instruments templates
- Build system improvements
- New frameworks in latest macOS
```

### 4.4 Workflow Tools
```
- Fastlane plugins
- CI/CD improvements
- Testing frameworks
- Documentation generators
```

### 4.5 AI/Automation Tools
```
- New Claude Code features
- MCP ecosystem growth
- Automation opportunities
```

---

## Phase 5: Report & Recommend

Present findings in this format:

```markdown
# Technology Evolution Report

## Current State
- MCPs: 8 configured, X outdated
- Swift packages: Y total, Z outdated
- System tools: [status]
- Forks: [commits behind]

## Upgrades Applied
| Tool | From | To | Notable Changes |
|------|------|-----|-----------------|
| context7 | 1.2.0 | 1.3.0 | Added caching |

## Recommendations (Based on Your Work)

### High Impact
1. **[Tool/Feature]** - [Why it matters for YOUR projects]
   - You complained about [X] on [date]
   - This solves it by [how]
   - Enable with: [command/config]

### New Tools to Consider
1. **[Tool Name]** - [What it does]
   - Relevant because: [connection to your work]
   - Install: [how]
   - Used by: [social proof if any]

### WWDC/Apple Updates
1. **[Session/API]** - [Relevance to your apps]

## Research Notes
Things I looked into that weren't relevant (so you know I checked):
- [Tool X] - not useful because [reason]
```

---

## Key Principles

1. **Context-aware** - Every recommendation tied to YOUR work, not generic advice
2. **Proactive** - Don't just maintain, actively scout for improvements
3. **Explain WHY** - Not "update X" but "update X because it fixes the problem you had"
4. **Research broadly** - Look beyond what we have, find what we're missing
5. **Plain English** - No jargon, clear actionable suggestions
6. **Ask before breaking** - Get approval before major upgrades

---

## Example Outputs

**User:** "update tools"

**Response:**
> Ran full evolution check. Key findings:
>
> **Upgrades:** Updated 3 npm packages, synced apple-docs fork (was 8 commits behind - now has WWDC 2026 data).
>
> **For SaneBar:** XcodeBuildMCP now supports menu bar app testing. You've been manually testing - this could automate it.
>
> **New Discovery:** Found `mcp-server-keychain` - would let you manage Keychain entries from Claude without popup floods. Relevant to your API key workflow.
>
> **WWDC Alert:** "What's New in AppKit" has a section on menu bar improvements. Want me to fetch the transcript?

---

**User:** "find better ways to do what we're doing"

**Response:**
> Analyzed your workflow across 6 SaneApps. Found:
>
> 1. **You're manually syncing configs** across projects. There's a tool called `mise` that manages tool versions across projects - would eliminate the .mcp.json drift we just fixed.
>
> 2. **Brand compliance checking** is manual. Found `SwiftLint` custom rules that could enforce color/font standards automatically at build time.
>
> 3. **No crash reporting** in any app. Sentry has a new Swift SDK that's lightweight. Matches your "know what's breaking" need.
>
> Want details on any of these?

---

## Triggers to Remember

Natural language - user shouldn't need to remember a command:
- "update tools" / "upgrade tools"
- "check for updates" / "what needs updating"
- "any new tools I should know about"
- "find better ways"
- "technology check"
- "what am I missing"
- "tool recommendations"
- "optimize our setup"
