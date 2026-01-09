# SaneProcess Development Guide

> Ruby hooks for Claude Code enforcement. Source of truth for all Sane projects.

## Quick Start

```bash
ruby scripts/qa.rb                    # Full QA check
ruby scripts/hooks/test/tier_tests.rb # Run hook tests
ruby scripts/sync_check.rb ~/SaneBar  # Cross-project sync
```

## The 5 Core Rules

1. **VERIFY BEFORE YOU TRY** - Check APIs exist before using
2. **TWO STRIKES? INVESTIGATE** - Stop at 2 failures, research
3. **TESTS MUST PASS** - Green before claiming done
4. **USE PROJECT TOOLS** - `ruby scripts/qa.rb`, not raw commands
5. **STAY RESPONSIVE** - Subagents for heavy work

## Project Structure

```
scripts/
├── hooks/                 # Enforcement hooks (synced to all projects)
│   ├── session_start.rb   # SessionStart - bootstrap
│   ├── saneprompt.rb      # UserPromptSubmit - classify task
│   ├── sanetools.rb       # PreToolUse - block until research done
│   ├── sanetrack.rb       # PostToolUse - track failures
│   ├── sanestop.rb        # Stop - capture learnings
│   ├── core/              # Shared infrastructure
│   └── test/              # Hook tests
├── SaneMaster.rb          # CLI entry (different from Swift projects)
└── qa.rb                  # Quality assurance
```

## Testing

```bash
ruby scripts/hooks/test/tier_tests.rb           # All tests
ruby scripts/hooks/test/tier_tests.rb --tier easy    # Easy tier
ruby scripts/hooks/test/tier_tests.rb --tier hard    # Hard tier
ruby scripts/hooks/test/tier_tests.rb --tier villain # Villain tier
```

## Cross-Project Sync

SaneProcess hooks sync to: SaneBar, SaneVideo, SaneSync

```bash
# Check sync status
ruby scripts/sync_check.rb ~/SaneBar

# Sync hooks after changes
rsync -av scripts/hooks/ ~/SaneBar/scripts/hooks/
rsync -av scripts/hooks/ ~/SaneVideo/scripts/hooks/
rsync -av scripts/hooks/ ~/SaneSync/scripts/hooks/
```

## Before Pushing

1. `ruby scripts/qa.rb` - QA passes
2. `ruby scripts/hooks/test/tier_tests.rb` - All tests pass
3. Sync to other projects if hooks changed
