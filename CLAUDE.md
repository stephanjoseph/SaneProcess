# SaneProcess - Claude Code Instructions

> **PRIME DIRECTIVE: READ THE PROMPTS**
> Hook fires → Read the message → Find the answer → Succeed first try.
> Don't skim. Don't guess. The answer is in front of you.

## Quick Start

```bash
ruby scripts/qa.rb                    # Full QA check
ruby scripts/hooks/test/tier_tests.rb # Run 234 hook tests
ruby scripts/sync_check.rb ~/SaneBar  # Cross-project sync
```

## The 5 Core Rules

### 1. VERIFY BEFORE YOU TRY
Check docs/APIs exist before using them. Don't guess from memory.

**DO:** Check `.swiftinterface`, use `apple-docs` MCP, read type definitions
**DON'T:** "I remember this API has a .zoom property"

### 2. TWO STRIKES? INVESTIGATE
After 2 failures, STOP. Research. Don't guess a third time.

**DO:** "Failed twice. Checking SDK to verify this exists."
**DON'T:** "Let me try a slightly different approach..." (attempt #3)

### 3. TESTS MUST PASS
Fix all failures before claiming done. No tautologies (`#expect(true)`).

**DO:** Tests red → fix → run again → green → done
**DON'T:** "Tests failed but it's probably fine"

### 4. USE PROJECT TOOLS
Use SaneMaster, not raw commands. The tools exist for a reason.

**DO:** `./Scripts/SaneMaster.rb verify`
**DON'T:** `xcodebuild -scheme MyApp build`

### 5. STAY RESPONSIVE
Use subagents for heavy work. Answer user while tasks run.

**DO:** Spawn Task agent, keep responding to user
**DON'T:** "Hold on, let me finish this first..."

## Workflow

```
1. PLAN    → Understand task, identify files, state approach
2. VERIFY  → Check APIs exist before using
3. BUILD   → Make changes, run tests
4. CONFIRM → Tests pass, user approves
```

## When Hooks Block You

The hooks are helping, not fighting you:

| Block | Meaning | Fix |
|-------|---------|-----|
| Research incomplete | You skipped verification | Do the research first |
| MCP not verified | Didn't check MCP servers | Call read_graph, search_docs |
| Circuit breaker | 3+ failures in a row | Stop, investigate root cause |
| File too large | Over 500 lines | Split by responsibility |

## This Has Burned You Before

| Mistake | What Happened | Prevention |
|---------|---------------|------------|
| Guessed API | Used non-existent method, failed 4x | Rule #1: Verify first |
| Kept guessing | Same error 5 times, different "fixes" | Rule #2: Stop at 2 |
| Skipped tests | Shipped broken code | Rule #3: Tests pass |
| Raw xcodebuild | Missed project config | Rule #4: Use tools |

## Session End Format

```
## Session Summary
### Done: [1-3 bullet points]
### SOP: X/10 (rate RULE compliance, not task completion)
### Next: [Follow-up items]
```

## Project Structure

```
scripts/
├── hooks/           # 4 enforcement hooks
│   ├── saneprompt.rb   # UserPromptSubmit
│   ├── sanetools.rb    # PreToolUse
│   ├── sanetrack.rb    # PostToolUse
│   └── sanestop.rb     # Stop
├── SaneMaster.rb    # Main CLI
└── qa.rb            # Quality checks
```

## Cross-Project Sync

This syncs with SaneBar, SaneVideo, SaneSync. After changes:
```bash
ruby scripts/sync_check.rb ~/SaneBar
ruby scripts/sync_check.rb ~/SaneVideo
```
