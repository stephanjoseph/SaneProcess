# Status Skill

> **Triggers**: `/status`, "status?", "what's the status", "where are we", "catch me up"

## Purpose

Fast situational awareness for any project. Under 30 seconds. Gives you clear next steps.

**This is NOT:**
- Docs audit (that's session close)
- Validation report (that's SaneProcess terminal)
- Full test suite (too slow)

---

## What To Do

Run these checks IN PARALLEL for speed:

### 1. Git Status
```bash
git status --short
git log --oneline -5
```
Show: What's changed? What branch? Recent commits?

### 2. SESSION_HANDOFF.md
Read if it exists. Extract:
- What was being worked on?
- What's pending/blocked?
- Any gotchas noted?

### 3. Memory MCP Search
```
search(query: "[ProjectName]", project: "[ProjectName]", limit: 5)
```
Show: Recent bugs, patterns, decisions for THIS project.

### 4. Build Health (Quick)
Only if fast (<10 sec). Skip if project has slow builds.
```bash
# For Swift projects with SaneMaster:
./scripts/SaneMaster.rb health 2>/dev/null || echo "No health check available"
```

---

## Output Format

Keep it scannable. No walls of text.

```markdown
## Status: [ProjectName]

**Branch:** main | **Changed:** 3 files | **Uncommitted:** Yes/No

### Recent Work
- [From SESSION_HANDOFF.md or git log]

### Known Issues
- [From memory MCP - bugs, patterns]

### Next Steps
1. [Most important action]
2. [Second action if applicable]
3. [Third action if applicable]
```

---

## Rules

1. **Fast** - Complete in <30 seconds
2. **Focused** - This project only, not meta
3. **Actionable** - End with clear next steps
4. **No lectures** - Just the facts

---

## Examples

User: "status?"
→ Run all checks, output status format, done.

User: "catch me up"
→ Same as status.

User: "/status"
→ Same as status.

---

## What Triggers Session Close Instead

These should NOT trigger /status - they trigger docs-audit:
- "end session", "wrap up", "I'm done"
- "push to git", "commit"
- "update the readme"
