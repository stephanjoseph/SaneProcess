# Session Handoff: SessionStart Hook "error" Display

**Date:** 2026-01-08
**Status:** Incomplete - "error" still shows despite fix attempts

## The Problem

Every time Claude Code starts, user sees:
```
SessionStart:startup hook error
```

Even though:
- The hook runs successfully (debug log shows "SUCCESS")
- All 234 tests pass
- Exit code is 0
- JSON output added to stdout

## What Was Tried This Session

1. **Added JSON output to stdout** in `session_start.rb`:
   ```ruby
   result = { additionalContext: build_session_context }
   puts JSON.generate(result)
   ```

2. **Verified hook works locally:**
   ```bash
   echo '{}' | ruby scripts/hooks/session_start.rb 2>/dev/null | jq .
   # Returns: {"additionalContext": "# [SaneProcess] Session Started\nProject: SaneProcess\n..."}
   ```

3. **Checked debug log** - shows "SUCCESS" at end

**Result:** Still shows "error" in Claude Code v2.1.1

## Other Changes Made This Session

1. **sanestop.rb** - Added todo-enforcer (warns on incomplete todos at session end)
2. **sync_check.rb** - Added `session_start.rb` to SYNC_HOOKS
3. **Synced** to SaneBar, SaneVideo, SaneSync

## Theories for Next Session

### Theory 1: stderr output causes "error" label
Claude Code may show "error" if ANY output goes to stderr, regardless of exit code.
- **Test:** Comment out ALL `warn` calls in session_start.rb
- **If works:** Move all output to stdout JSON only

### Theory 2: Wrong JSON structure
Maybe Claude Code expects different JSON keys.
- **Test:** Try `{"continue": true}` or `{"success": true}`
- **Research:** Find actual Claude Code source/docs for hook output format

### Theory 3: Timing/timeout issue
Hook has 5s timeout in settings.json. If slow, may show error.
- **Test:** Add timing logs to see how long hook takes
- **Check:** `.claude/session_start_debug.log` timestamps

### Theory 4: This is cosmetic only
The "error" label may not mean anything functionally.
- **Test:** Check if the context injection actually works
- The system-reminder shows `SessionStart:startup hook success: Success` so maybe it IS working

## Quick Debug Commands

```bash
# Test hook JSON output
echo '{}' | ruby scripts/hooks/session_start.rb 2>/dev/null | jq .

# Test hook stderr output
echo '{}' | ruby scripts/hooks/session_start.rb 2>&1 >/dev/null | head -5

# Check debug log
tail -20 .claude/session_start_debug.log

# Check timing
grep -o '\[.*\]' .claude/session_start_debug.log | tail -10
```

## Files Changed

| File | Change |
|------|--------|
| `scripts/hooks/session_start.rb` | Added JSON stdout output with `additionalContext` |
| `scripts/hooks/sanestop.rb` | Added `check_incomplete_todos()` function |
| `scripts/sync_check.rb` | Added `session_start.rb` to SYNC_HOOKS |

## Starting Next Session

```
Read .claude/SESSION_HANDOFF.md - investigating SessionStart hook "error" display issue
```

## Research Sources

From jarrodwatts/claude-code-config research:
- SessionStart hooks: stdout added to Claude's context
- stderr: fed back to Claude for processing
- Exit 0 + valid JSON = success

Actual Claude Code v2.1.1 behavior may differ.

## Interesting Observation

The system-reminder at session start says:
```
SessionStart:startup hook success: Success
```

But the user's terminal shows "error". This suggests the **display** may be wrong even when functionality works.
