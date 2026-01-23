# XcodeBuildMCP Migration Plan

> Created: 2026-01-20
> Status: **DO NOT EXECUTE YET** - Documentation only

---

## Current Situation

Your local fork (`sane-patched` branch) has 3 custom patches that are NOT in upstream yet.

### Custom Patches in Your Fork

| Commit | PR | What It Does | Impact If Lost |
|--------|-----|--------------|----------------|
| `5301d4d` | #158 | Subsystem filter for log capture | Can't filter logs by subsystem during debugging |
| `a9cad89` | #168 | Sentry async import fix | Potential import errors when Sentry not configured |
| `6da6db7` | #169 | xcodebuild extraArgs validation | Invalid args might pass through silently |

### Upstream Has

| Commit | What It Does |
|--------|--------------|
| `a30ffe9` | Fix xcodemake argument corruption from overly broad string replacement |

---

## What Would Break If You Reset

### 8 .mcp.json Files Reference This Fork

```
~/.mcp.json                              (GLOBAL - affects everything)
~/SaneApps/infra/SaneProcess/.mcp.json
~/SaneApps/apps/SaneBar/.mcp.json
~/SaneApps/apps/SaneClip/.mcp.json
~/SaneApps/apps/SaneVideo/.mcp.json
~/SaneApps/apps/SaneSync/.mcp.json
~/SaneApps/apps/SaneHosts/.mcp.json
~/SaneApps/apps/SaneScript/.mcp.json
```

All of these point to:
```
/Users/sj/Dev/xcodebuild-mcp-local/build/index.js
```

### Features You'd Lose

1. **Subsystem log filtering** - Currently you can filter simulator logs by subsystem. Useful for debugging SwiftUI apps (`Self._printChanges()` logs)

2. **Sentry async loading** - If you ever add Sentry to any SaneApp, the current fix prevents import errors

3. **ExtraArgs validation** - Catches invalid xcodebuild arguments before they fail silently

---

## Options

### Option A: Wait for Upstream (Safest)

Check if your PRs have been merged to upstream:
```bash
cd ~/Dev/xcodebuild-mcp-local
git fetch origin
gh pr list --search "author:stephanjoseph" --state all
# or check: https://github.com/cameroncooke/XcodeBuildMCP/pulls
```

If merged, simple fast-forward pull will work.

### Option B: Rebase with Conflict Resolution (Medium Risk)

```bash
cd ~/Dev/xcodebuild-mcp-local
git checkout sane-patched
git fetch origin
git rebase origin/main
# Resolve conflicts manually in:
#   - src/mcp/tools/logging/start_sim_log_cap.ts
#   - src/utils/log-capture/index.ts
git rebase --continue
npm run build
```

**Test after:** Build all SaneApps, verify log capture still works.

### Option C: Submit Patches Upstream (Best Long-term)

1. Fork the repo under sane-apps org
2. Create clean PRs for each feature
3. Get them merged properly
4. Then pull clean upstream

### Option D: Stay on Current Version (Do Nothing)

Your current fork works. The upstream bug fix (`a30ffe9`) is for xcodemake argument corruption - if you're not using xcodemake or haven't seen issues, you don't need it.

---

## Pre-Migration Checklist

Before ANY migration:

- [ ] Verify all 7 SaneApps build successfully with current fork
- [ ] Document which features actually use subsystem log filtering
- [ ] Check if any app uses Sentry (if not, that patch is irrelevant)
- [ ] Test extraArgs validation is actually needed

## Post-Migration Testing

After any fork change:

```bash
# Rebuild the MCP
cd ~/Dev/xcodebuild-mcp-local
npm run build

# Test each app builds
for app in SaneBar SaneClip SaneVideo SaneSync SaneHosts SaneScript; do
  echo "Testing $app..."
  cd ~/SaneApps/apps/$app
  # Run build command for each
done

# Test log capture still works
# (Start a simulator session, verify logs filter correctly)
```

---

## Recommendation

**Do nothing for now.** Your fork works. The upstream fix is minor.

When you have dedicated time:
1. Check if your PRs got merged upstream
2. If yes, simple pull
3. If no, consider submitting them properly

---

## References

- XcodeBuildMCP upstream: https://github.com/cameroncooke/XcodeBuildMCP
- Your fork: ~/Dev/xcodebuild-mcp-local (branch: sane-patched)
- Last checked: 2026-01-20
