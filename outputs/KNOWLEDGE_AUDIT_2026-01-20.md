# Knowledge Audit Report

> Generated: 2026-01-20
> Triggered by: Claude didn't know Homebrew was discontinued

---

## Critical Gap Found

### Homebrew Discontinuation - NOT DOCUMENTED

**What happened:** You discontinued Homebrew distribution for ALL SaneApps.

**Where it's documented:**
- ✅ GitHub issue #26 response (your comment)
- ✅ SESSION_HANDOFF.md (just added this session)
- ❌ NOT in any permanent decision document
- ❌ NOT in memory graph
- ❌ NOT in CLAUDE.md
- ❌ NOT in any app README

**Stale references found:**
| File | Line | Content | Action Needed |
|------|------|---------|---------------|
| `SaneBar/CHANGELOG.md` | 52 | "Updated appcast and Homebrew cask" | Remove or note discontinued |
| `/evolve SKILL.md` | 90-92 | Checks `brew outdated --cask` for apps | Clarify this is for system tools only |

---

## Why I Didn't Know

1. **Memory graph returned empty** - Even though SaneBar's memory.json has entities, `mcp__memory__read_graph` returned `{"entities":[],"relations":[]}`

2. **No permanent decision doc** - Major decisions like "Homebrew discontinued" should be in a DECISIONS.md or similar

3. **CHANGELOG not updated** - Still references Homebrew cask as if it's active

---

## Recommended Fixes

### 1. Create a DECISIONS.md (HIGH PRIORITY)

For each major decision, document:
- What was decided
- When
- Why
- What it affects

Example entry:
```markdown
## Homebrew Distribution Discontinued
**Date:** 2026-01-20
**Affects:** All SaneApps (SaneBar, SaneClip, SaneVideo, SaneSync, SaneHosts, SaneScript)
**Reason:** Solo dev with family - keeping DMG, website, GitHub, AND Homebrew cask in sync was unsustainable
**New model:**
- $5 DMG (notarized, ready to use)
- Free: clone and build from source
**GitHub issue:** sane-apps/SaneBar#26
```

### 2. Update SaneBar CHANGELOG.md

Change line 52 from:
```
- Updated appcast and Homebrew cask for automatic updates
```
To:
```
- Updated appcast for automatic updates
- Note: Homebrew distribution discontinued as of Jan 2026
```

### 3. Add to memory graph

```ruby
# Add to SaneBar memory
{
  "name": "Decision_HomebrewDiscontinued",
  "entityType": "Decision",
  "observations": [
    "Homebrew distribution discontinued for ALL SaneApps as of Jan 2026",
    "Reason: Solo dev, keeping 4 distribution channels in sync was unsustainable",
    "New model: $5 DMG OR build from source",
    "GitHub issue: sane-apps/SaneBar#26"
  ]
}
```

### 4. Investigate memory MCP

Why did `read_graph` return empty when SaneBar memory.json has content?

Check:
- Is the right file path in `~/.mcp.json`?
- Is the MCP server reading from the right location?
- Session caching issue?

---

## Other Potential Gaps

Things that MIGHT not be documented properly (need verification):

| Topic | Where to Check | Documented? |
|-------|---------------|-------------|
| Intel support discontinued | SaneBar README says "Apple Silicon only" | ✅ |
| Pricing model ($5 DMG) | sanebar.com, README | ✅ |
| XcodeBuildMCP custom patches | outputs/XCODEBUILD_MCP_MIGRATION_PLAN.md | ✅ (just created) |
| Greptile plugin removed | SESSION_HANDOFF mentions Session 4 | Partial |
| MCP environment variables in .zprofile not .zshrc | CLAUDE.md "This Has Burned You Before" | ✅ |

---

## Process Improvement

**When making major decisions:**
1. Document in DECISIONS.md immediately
2. Add to memory graph
3. Update all affected docs (README, CHANGELOG, CLAUDE.md)
4. Tell Claude explicitly (or Claude won't know next session)

---

## Action Items

- [ ] Create `~/SaneApps/meta/DECISIONS.md` with major decisions
- [ ] Update `SaneBar/CHANGELOG.md` line 52
- [ ] Add HomebrewDiscontinued entity to SaneBar memory.json
- [ ] Investigate why memory MCP returned empty graph
- [ ] Close GitHub #26 after ~1 week if no response
