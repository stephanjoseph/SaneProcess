# Session Handoff

> Last updated: 2026-01-20 (Session 8)

---

## FOLLOW-UP ITEMS

### GitHub Issue #26 - Homebrew Discontinued
- **Issue:** https://github.com/sane-apps/SaneBar/issues/26
- **Status:** You responded explaining Homebrew discontinuation
- **Action:** Check in ~1 week. If no response or resolved, close it.
- **Context:** Homebrew discontinued for ALL SaneApps - DMG ($5) or build from source

### XcodeBuildMCP Fork - DO NOT RESET
- **Plan saved:** `outputs/XCODEBUILD_MCP_MIGRATION_PLAN.md`
- **Status:** Your fork has 3 custom patches, upstream has 1 bug fix
- **Risk:** 8 .mcp.json files depend on your fork
- **Action:** Leave as-is until dedicated migration time

### Deploy Logo Fix
- New logo ready at `~/SaneApps/web/saneapps.com/logo.png`
- Commit and push to deploy via GitHub Pages
- Backup at `logo-old.png` if rollback needed

---

## Completed This Session (2026-01-20 Session 8)

### Memory System Overhaul
**Problem:** Project memories were isolated - global decisions (like "Homebrew discontinued") weren't shared across projects. I didn't know Homebrew was killed because it was only in SaneBar's memory.

**Solution:**
- Created `~/.claude/global-memory.json` for cross-project decisions
- Created `scripts/sync_global_memory.rb` to propagate to all 8 projects
- Run: `ruby scripts/sync_global_memory.rb` after adding global decisions

**Global entities now synced:**
- `Decision_HomebrewDiscontinued`
- `Decision_PricingModel`
- `Decision_XcodeBuildMCPFork`
- `Pattern_MemoryIsolation`
- `Tool_CloudflareAPI`
- `Tool_LemonSqueezyAPI`

### Broken MCPs Removed
**Problem:** cloudflare and lemonsqueezy MCPs were failing (broken packages)

**Solution:**
- Removed from all 8 `.mcp.json` files
- Documented direct API access in global memory
- APIs still work via Keychain tokens

**API Access (No MCPs needed):**
```bash
# Cloudflare
TOKEN=$(security find-generic-password -s cloudflare -a api_token -w)
curl -H "Authorization: Bearer $TOKEN" https://api.cloudflare.com/client/v4/zones

# Lemon Squeezy
KEY=$(security find-generic-password -s lemonsqueezy -a api_key -w)
curl -H "Authorization: Bearer $KEY" -H "Accept: application/vnd.api+json" https://api.lemonsqueezy.com/v1/orders
```

### Files Created/Modified
| File | Change |
|------|--------|
| `~/.claude/global-memory.json` | NEW - Cross-project decisions |
| `scripts/sync_global_memory.rb` | NEW - Syncs global → project memories |
| `outputs/KNOWLEDGE_AUDIT_2026-01-20.md` | NEW - Knowledge gaps found |
| 8x `.mcp.json` files | Removed cloudflare, lemonsqueezy |
| 8x `.claude/memory.json` files | Added global entities |

---

## Completed Session 7 (earlier today)

### /evolve Command - Technology Audit
- Ran full evolution check on MCP stack and tools
- **All npm MCPs current** - context7, github, memory, macos-automator
- **Homebrew upgraded** - ffmpeg, yq, fastlane, gh, ~20 others
- **XcodeBuildMCP fork conflict documented** - migration plan saved
- **Verdict on new MCPs:** MacPilot and Terminator not needed

---

## Quick Commands

```bash
# Run validation report
ruby ~/SaneApps/infra/SaneProcess/scripts/validation_report.rb

# Sync global memory to all projects
ruby ~/SaneApps/infra/SaneProcess/scripts/sync_global_memory.rb

# Verify all apps have configs
for app in SaneBar SaneClip SaneVideo SaneSync SaneHosts SaneAI SaneScript; do
  ls ~/SaneApps/apps/$app/.mcp.json ~/SaneApps/apps/$app/.claude/memory.json 2>/dev/null && echo "$app: OK"
done
```

---

## Current MCP Stack (6 servers per project)

| MCP | Status | Notes |
|-----|--------|-------|
| apple-docs | ✅ Working | Local fork |
| github | ✅ Working | npm global |
| memory | ✅ Working | Per-project isolation |
| context7 | ✅ Working | npm global |
| XcodeBuildMCP | ✅ Working | Local fork (custom patches) |
| macos-automator | ✅ Working | npm global |
| ~~cloudflare~~ | ❌ Removed | Use Keychain + curl |
| ~~lemonsqueezy~~ | ❌ Removed | Use Keychain + curl |

---

## Previous Sessions Context

### Session 6 (earlier today)
- Logo fix ready to deploy (200x200 icon-only version)

### Session 5 (earlier today)
- All 15 configuration issues fixed
- 7 apps fully configured with .mcp.json, memory.json, settings.json
- validation_report.rb now has 5 additional Q0 checks
