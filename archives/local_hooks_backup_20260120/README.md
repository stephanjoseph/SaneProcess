# Local Hooks Archive - 2026-01-20

## Why This Exists

These are archived copies of project-local Claude Code hooks that were **superseded by centralized SaneProcess hooks**.

### Projects Consolidated:
- **SaneBar** - Had feature drift: `rotate_log_files`, Feature Reminders, **lock timeout mechanism**
- **SaneSync** - Older version, missing newer features
- **SaneVideo** - Older version, different code style only

### What Was Backported to SaneProcess:
1. `rotate_log_files` function (from SaneBar's session_start.rb)
2. Feature Reminders system (from SaneBar's sanetrack.rb):
   - `/rewind` suggestion after errors
   - `/context` suggestion every 5 edits
   - Explore subagent suggestion for complex searches
3. **Lock timeout mechanism** (from SaneBar's core/state_manager.rb):
   - Non-blocking locks with 2s timeout
   - Prevents hook hangs from stale locks
   - Critical reliability improvement

### Changes Made:
- Updated `~/.claude/plugins/.../serena/.mcp.json` - Added `--project-from-cwd` for auto-activation
- Updated each project's `.claude/settings.json` to reference SaneProcess hooks
- Backported unique features to SaneProcess hooks

### If You Need to Restore:
```bash
# Copy back to original location (example for SaneBar):
cp -r SaneBar_hooks/* ~/SaneApps/apps/SaneBar/scripts/hooks/
```

### Original Local Hook Directories:
- `~/SaneApps/apps/SaneBar/scripts/hooks/` - Still exists (now unused)
- `~/SaneApps/apps/SaneSync/Scripts/hooks/` - Still exists (now unused)
- `~/SaneApps/apps/SaneVideo/Scripts/hooks/` - Still exists (now unused)

These can be deleted once consolidation is verified stable.
