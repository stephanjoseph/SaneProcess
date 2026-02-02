# Research Cache

> **Working scratchpad for research agents.** Check here before researching. Update after finding.
> When findings become permanent knowledge, graduate them to ARCHITECTURE.md or DEVELOPMENT.md.
> **Size cap: 200 lines.** If over cap, graduate oldest verified findings first.

---

## Hook Audit Findings
**Updated:** 2026-02-01 | **Status:** audit-complete | **TTL:** 7d
**Source:** Comprehensive audit of all hook files

| # | File | Line | Issue | Severity |
|---|------|------|-------|----------|
| 1 | saneprompt.rb | 152 | Hardcoded "Must complete: docs, web, github, local" - only lists 4 but says "All 4 research categories cleared" (correct) | LOW |
| 2 | saneprompt.rb | 500 | Comment says "Must complete all 5 research categories for THIS task" but should be 4 | MEDIUM |
| 3 | saneprompt.rb | 582 | Comment says "Research for Task A should NOT unlock edits for Task B" (correct logic) | LOW |
| 4 | saneprompt.rb | 682 | Auto-saneloop comment says "Research ALL 4 categories" - correct | LOW |
| 5 | sanetools.rb | 121-139 | RESEARCH_CATEGORIES hash defines 4 categories (docs, web, github, local) - correct, memory removed | LOW |
| 6 | sanetools.rb | 148 | Function `research_complete?` checks all categories - correct | LOW |
| 7 | sanetools.rb | 179 | Comment says "Reset edit attempt counter ONLY when...ALL 5 categories are now complete" - should be 4 | HIGH |
| 8 | sanetools.rb | 326-330 | Display message says "Missing (do these NOW)" and lists 4 categories - correct | LOW |
| 9 | sanetools_checks.rb | 310-332 | `check_research_before_edit` builds instructions for 4 categories, no memory reference - correct | LOW |
| 10 | sanetools_checks.rb | 627-632 | `check_rapid_research` checks "if timestamps.length < 5" - should be 4 | HIGH |
| 11 | sanetrack.rb | 36 | Comment "NOTE: Memory MCP removed Jan 2026" - correct awareness | LOW |
| 12 | sanetrack.rb | 44-51 | RESEARCH_PATTERNS has 4 categories (docs, web, github, local) - correct | LOW |
| 13 | sanestop.rb | 26 | Comment "DEPRECATED: Memory staging file no longer used (Jan 2026)" - correct awareness | LOW |
| 14 | sanestop.rb | 197 | Function `stage_memory_learnings` is now a no-op stub - correct | LOW |
| 15 | sanestop.rb | 582 | Display says "Research: #{stats[:research_done]}/5 categories" - should be /4 | HIGH |
| 16 | session_start.rb | 222-223 | SESSION_DOC_CANDIDATES array lists docs - correct | LOW |
| 17 | state_manager.rb | 60-65 | research schema defines 5 categories INCLUDING :memory - should remove :memory key | CRITICAL |
| 18 | state_manager.rb | 120-124 | mcp_health schema includes memory MCP - should be removed | MEDIUM |
| 19 | validation_report.rb | Line N/A | No stale "5 categories" references found - uses dynamic count from RESEARCH_CATEGORIES | LOW |
| 20 | sanetools.rb | state_manager | Unbounded data structure: action_log could grow without cap (schema defines [] but no MAX) | MEDIUM |
| 21 | state_manager.rb | 156 | action_log comment says "Last 20 actions" but MAX_ACTION_LOG in sanetrack.rb is 20 - consistent | LOW |
| 22 | state_manager.rb | 98 | patterns.session_scores keeps "Last 100" but sanestop.rb line 183 keeps last 10 - INCONSISTENT | MEDIUM |
| 23 | sanetrack.rb | 156 | MAX_ACTION_LOG = 20, correctly enforced in log_action_for_learning at line 509 | LOW |
| 24 | sanestop.rb | 70 | patterns[:session_scores].last(10) - enforces cap, matches comment | LOW |
| 25 | state_manager.rb | Dead key | research.memory still in schema but never used - should be removed | MEDIUM |
| 26 | state_manager.rb | Dead key | mcp_health.mcps.memory still in schema but MCP doesn't exist | MEDIUM |
| 27 | sanetools_checks.rb | 315 | Comment "NOTE: Memory category removed Jan 2026" - correct awareness | LOW |
| 28 | sanetrack_research.rb | 18 | RESEARCH_SIZE_CAP = 200 lines - enforced, correct | LOW |
| 29 | qa.rb | 53 | EXPECTED_RULE_COUNT = 16 - check if accurate | LOW |
| 30 | session_start.rb | 158 | MEMORY_STAGING_FILE referenced but deprecated - used only for cleanup check | LOW |

### Summary by Severity — ALL FIXED 2026-02-01

**CRITICAL (1): FIXED**
- ~~state_manager.rb schema still has :memory research category~~ → Removed :memory from research schema

**HIGH (3): ALL FIXED**
- ~~sanetools.rb line 179: "ALL 5 categories"~~ → Fixed to "ALL 4 categories"
- ~~sanetools_checks.rb line 627: timestamps.length < 5~~ → Fixed to < 4
- ~~sanestop.rb line 582: "/5 categories"~~ → Fixed to "/4 categories"

**MEDIUM (5): ALL FIXED**
- ~~saneprompt.rb line 500: "5 research categories"~~ → Fixed to "4 research categories"
- ~~state_manager.rb line 98: "Last 100 scores"~~ → Fixed to "Last 10"
- ~~state_manager.rb line 120: memory MCP in mcp_health~~ → Removed memory entry
- ~~state_manager.rb: research.memory dead key~~ → Removed
- ~~state_manager.rb: mcp_health.mcps.memory dead key~~ → Removed

**Additional fixes (same batch):**
- All markdown docs updated (CLAUDE.md, ARCHITECTURE.md, DEVELOPMENT.md, README.md, copilot-instructions.md)
- real_failures_test.rb and sanetools_test.rb updated
- session_started_at timestamp added (replaces Time.now - 3600 approximation)
- enforcement.blocks capped at 50 entries (trimmed at session start)
- Q3 SOP scoring redesigned: measures blocks-before-compliance instead of violations

**Remaining LOW items (cosmetic, not blocking):**
- MEMORY_STAGING_FILE in session_start.rb (cleanup check only — harmless)
- `stage_memory_learnings()` no-op stub in sanestop.rb (prevents NoMethodError)
- action_log unbounded in schema but MAX_ACTION_LOG = 20 enforced in sanetrack.rb

---

## MCP Tool Inventory & Adoption Status
**Updated:** 2026-02-01 | **Status:** adoption-audit-complete | **TTL:** 30d
**Source:** Codebase audit of hooks, scripts, skills, and Serena memories

### Status Key
- ✅ ACTIVE — Used in production workflows
- 📝 DOCUMENTED — In skills/docs but not automated
- ⚠️ AVAILABLE — Enabled but no usage found
- ❌ MISSING — Not in permissions

### 1. Gemini MCP (30+ tools)
**Status:** ❌ MISSING from permissions
- Tools live in ToolSearch but not whitelisted in settings.json
- No usage found in hooks, scripts, or skills
- Zero claude-mem observations referencing gemini
- **Recommendation:** Add to permissions for `/evolve` skill adoption tracking
- **High-value targets:** `gemini-deep-research` (competitor analysis), `gemini-analyze-image` (customer support), `gemini-generate-image` (marketing)

### 2. Serena LSP & Memories
**Status:** 📝 DOCUMENTED in `/evolve` skill only
- Plugin enabled, zero permission blocks (MCP available)
- **Active usage:** 16 Serena memory files across 6 projects (SaneProcess, SaneClip, SaneHosts)
- Memories used for: release script fixes, DMG icon lessons, brand guidelines, audit findings
- **Code tools unused:** No grep hits for `find_symbol`, `rename_symbol`, `replace_symbol_body`
- **Recommendation:** Use LSP tools for Ruby refactoring (safer than grep-based edits)

### 3. Apple-Docs WWDC Tools
**Status:** ⚠️ AVAILABLE but specialized tools unused
- `search_apple_docs` ✅ used in session_start.rb verification
- WWDC tools (`search_wwdc_content`, `get_wwdc_code_examples`, `find_related_wwdc_videos`) — ZERO usage
- `get_documentation_updates`, `find_similar_apis` — NOT referenced anywhere
- **Recommendation:** `/evolve` skill mentions these but doesn't use them. Add to research workflows.

### 4. macos-automator
**Status:** 📝 DOCUMENTED for menu bar testing only
- In permissions, mentioned in CLAUDE.md for SaneBar UI testing
- `get_scripting_tips` (493 scripts) — ZERO invocations found
- **Recommendation:** Use for repetitive AppleScript tasks (no evidence of current automation)

## Claude-Mem vs Serena Memories — Adoption Comparison
**Updated:** 2026-02-01 | **Status:** adoption-verified | **TTL:** 30d
**Source:** Directory audit + health check + version inspection

| Aspect | Claude-Mem | Serena Memories |
|--------|-----------|-----------------|
| Storage | SQLite + ChromaDB (port 37777) | Markdown files in `.serena/memories/` |
| Version | v9.0.6 (Jan 22, 2026) | Plugin enabled, unknown version |
| Status | ✅ Running (health OK) | ✅ 16 files across 6 projects |
| Capture | Auto via hooks | Manual write_memory |
| Search | Semantic vector | File name / grep |
| Adoption | HIGH (thousands of observations) | MODERATE (curated docs) |
| Use cases | Bug patterns, API learnings | Release scripts, DMG fixes, brand rules |

**Both actively used.** Claude-Mem is automatic context; Serena is curated project knowledge.

## Subagent Capability Matrix
**Updated:** 2026-02-01 | **Status:** verified | **TTL:** 30d
**Source:** Task tool definition analysis

| Agent Type | Write/Edit | Ask User | MCP Tools | Sub-Tasks | Default Model |
|------------|-----------|----------|-----------|-----------|--------------|
| Explore | NO | NO | YES | NO | Haiku |
| general-purpose | YES | YES | YES | YES | Inherits (parent) |
| Plan | NO | YES | YES | NO | Inherits |
| Bash | NO | NO | NO | NO | Inherits |
| feature-dev:code-explorer | NO | NO | Limited | NO | Inherits |
| feature-dev:code-architect | NO | NO | Limited | NO | Inherits |
| feature-dev:code-reviewer | NO | NO | Limited | NO | Inherits |

**Key insight:** Explore agents are search drones. For research that persists, asks questions, or branches into sub-topics, use general-purpose + sonnet.
