# claude-mem Removal (Feb 2026, Session 38-39)

## What Happened
claude-mem (thedotmack) permanently removed. Had 4 critical open bugs (#1090, #1089, #1077, #1075): process leaks, OOM, infinite notification loops.

## New Memory Stack
- **Official Memory MCP** — `@modelcontextprotocol/server-memory`, knowledge-graph.jsonl (61 entities/relations)
- **session_learnings.jsonl** — auto-captured by sanestop.rb when 3+ edits or breaker trips. 200-line cap with archive.
- **Serena memories** — project-specific patterns
- **SESSION_HANDOFF.md** — detailed session context

## Key Files Changed
- `sanestop.rb` — capture_session_learnings + enforce_learnings_cap added
- `session_briefing.rb` — load_recent_learnings reads last 5 entries at session start
- `session_start.rb` — learnings injected into briefing context
- `structural_compliance.rb` — inverted check now verifies remnants are GONE
- `qa_drift_checks.rb` — stale patterns detect claude-mem/Sane-Mem/localhost:37777

## Scope of Cleanup
28+ files across 8 repos. All app CLAUDE.md files, DEVELOPMENT.md files, templates, skills, meta docs updated. 9 auto-generated SaneBar subdirectory CLAUDE.md files trashed. SaneProcess-templates merged into SaneProcess/templates/.

## When to Reconsider
Only if Claude Code ships native built-in memory (tengu_session_memory config gate exists) OR session_learnings.jsonl proves insufficient for 500+ entries needing semantic search.
