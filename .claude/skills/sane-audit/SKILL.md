# SaneProcess Full Audit Skill

> **Trigger:** `/audit` or "run audit" or "full audit"

## Purpose

Comprehensive system audit using **PARALLEL SUB-AGENTS** for each section. This prevents context bloat and ensures deep, focused analysis.

**CRITICAL:** Each audit section MUST be run by a dedicated Task agent. Do NOT run checks inline - delegate to sub-agents.

---

## Execution Flow

### Step 1: Launch All Audit Agents IN PARALLEL

You MUST launch these Task agents in a SINGLE message with multiple tool calls. This runs them concurrently.

```
Launch these 6 agents IN PARALLEL (single message, multiple Task tool calls):

1. Task(subagent_type="Explore", prompt=<Q0_CONFIG_PROMPT>)
2. Task(subagent_type="Explore", prompt=<Q6_RELEASE_PROMPT>)
3. Task(subagent_type="Explore", prompt=<Q7_WEBSITE_PROMPT>)
4. Task(subagent_type="Explore", prompt=<Q8_SIGNING_PROMPT>)
5. Task(subagent_type="Explore", prompt=<Q9_SUPPORT_PROMPT>)
6. Task(subagent_type="Explore", prompt=<Q10_DOCS_PROMPT>)
```

### Step 2: Run Ruby Validation (Background)

While agents run, also execute the Ruby validation script:

```bash
ruby ~/SaneApps/infra/SaneProcess/scripts/validation_report.rb 2>&1
```

### Step 3: Collect & Present Results

Wait for all agents to complete, then present unified report.

---

## Sub-Agent Prompts (Intelligent Expert Personas)

Each sub-agent has:
1. **Expert Persona** - Domain expertise to find gaps
2. **Phase 1: Baseline Checklist** - Known items to verify
3. **Phase 2: Expert Gap Analysis** - Find what checklist missed
4. **Phase 3: Output Report** - Rating, gaps, suggestions

### Q0: Config Consistency Agent
**Persona:** DevOps Config Guardian (15 yrs infrastructure experience)

Read: `prompts/q0-config.md`

Baseline Focus:
- Deprecated plugins in settings.json
- MCP server paths (npm vs local)
- Hook configurations
- Environment variable locations (.zprofile vs .zshrc)
- Sister app consistency

Expert Gap Analysis:
- Configuration drift and orphaned files
- Security concerns in configs
- Maintainability issues
- Cross-platform readiness

### Q6: Release Integrity Agent (CRITICAL)
**Persona:** Release Engineering Lead (12 yrs macOS distribution)

Read: `prompts/q6-release.md`

Baseline Focus:
- Appcast.xml URLs return 200/302 (NOT 404)
- GitHub releases exist for each app
- DMG files downloadable
- Sparkle signatures present
- minimumSystemVersion not too restrictive

Expert Gap Analysis:
- Release infrastructure resilience
- Download reliability
- Update experience for users
- Release process gaps
- **NEVER suggests Homebrew**

**This catches the SaneBar disaster before customers complain.**

### Q7: Website Distribution Agent
**Persona:** Web Infrastructure Architect (10 yrs web reliability)

Read: `prompts/q7-website.md`

Baseline Focus:
- All product domains accessible
- SSL certificates valid
- Download links work
- No 5xx errors

Expert Gap Analysis:
- SSL/TLS security
- DNS configuration
- CDN & performance
- Website content accuracy
- Legal compliance

### Q8: Code Signing Agent
**Persona:** Apple Security Engineer (12 yrs macOS security)

Read: `prompts/q8-signing.md`

Baseline Focus:
- Developer ID Application identity exists
- Certificates not expired
- Notarytool keychain profile works
- App bundles properly signed
- Notarization stapled

Expert Gap Analysis:
- Certificate health and expiration
- Hardened runtime and entitlements
- DMG signing
- Build process integrity
- Archive management

### Q9: Support Infrastructure Agent
**Persona:** Customer Success Architect (10 yrs support ops)

Read: `prompts/q9-support.md`

Baseline Focus:
- Keychain has required API keys
- Resend API responding
- Sane-Mem service running
- Support email working

Expert Gap Analysis:
- **Lemon Squeezy store per app**
- Email infrastructure
- Support channels
- Credential security
- Monitoring & alerting
- Customer data handling

### Q10: Documentation Currency Agent
**Persona:** Technical Documentation Lead (12 yrs tech writing)

Read: `prompts/q10-docs.md`

Baseline Focus:
- README mentions current version
- CHANGELOG has latest release
- SESSION_HANDOFF.md not stale
- Version consistency across docs

Expert Gap Analysis:
- User-facing documentation gaps
- Developer documentation
- Release documentation quality
- Legal/policy documentation
- Hidden/undocumented features

---

## Report Format

After all agents complete, aggregate their reports into a unified view:

```markdown
# Full System Audit Report

**Generated:** [timestamp]
**Verdict:** [WORKING / NEEDS ATTENTION / BROKEN PIPELINE]

---

## Completeness Scorecard

| Section | Expert | Score | Justification |
|---------|--------|-------|---------------|
| Q0 | DevOps Config Guardian | 7/10 | Hooks good, missing centralized config |
| Q6 | Release Engineering Lead | 8/10 | URLs work, no rollback plan |
| Q7 | Web Infrastructure Architect | 6/10 | Sites up, privacy policy missing |
| Q8 | Apple Security Engineer | 9/10 | Signing solid, archives not preserved |
| Q9 | Customer Success Architect | 5/10 | Keys present, Lemon Squeezy not set up |
| Q10 | Technical Documentation Lead | 6/10 | Versions match, hidden features undocumented |

**Overall Score: X/10** (average of all sections)

---

## Critical Issues (Customer-Facing)
| Section | Issue | Impact |
|---------|-------|--------|
| Q6 | Release URL 404 | Customers can't update |

## Expert-Identified Gaps (Beyond Checklist)
| Section | Gap | Risk Level | Recommendation |
|---------|-----|------------|----------------|
| Q9 | No Lemon Squeezy store for SaneHosts | High | Set up before launch |
| Q8 | Archives not preserved | Medium | Save .xcarchive files |

## Warnings
| Section | Issue | Recommendation |
|---------|-------|----------------|

## All Clear (Baseline)
- Q0: Config ✅
- Q7: Websites ✅

## Actions Required
1. [ ] [Critical] Fix release URL for SaneClip
2. [ ] [High] Set up Lemon Squeezy for SaneHosts
3. [ ] [Medium] Update README version

---

## Suggested Checklist Improvements

Based on expert analysis, add these checks to future audits:

| Section | Suggested Addition | Why |
|---------|-------------------|-----|
| Q8 | Archive preservation check | Can't recreate releases without them |
| Q9 | Per-app Lemon Squeezy verification | Caught missing payment infrastructure |
```

---

## Key Rules

1. **CURRENT PROJECT ONLY** - Audit the project in CWD, not all SaneApps
2. **PARALLEL EXECUTION** - All 6 agents launch in ONE message
3. **NO INLINE CHECKS** - Everything delegated to sub-agents
4. **FOCUSED CONTEXT** - Each agent only sees its specific domain
5. **CUSTOMER-FIRST** - Q6/Q7/Q8 issues are CRITICAL
6. **ACTIONABLE OUTPUT** - Clear list of what to fix
7. **INTELLIGENT ANALYSIS** - Agents find gaps BEYOND the checklist
8. **COMPLETENESS RATINGS** - Every section rated 1-10 with justification
9. **CONTINUOUS IMPROVEMENT** - Agents suggest checklist additions
10. **NO HOMEBREW** - Never suggest Homebrew distribution. Ever.

**Exception:** User can explicitly request cross-project audit (e.g., "audit all apps").

---

## Quick Mode

`/audit --quick` - Run only Q6 (Release) and Q8 (Signing) for fast pre-release check.

---

## Why Sub-Agents?

| Problem | Solution |
|---------|----------|
| Context bloat | Each agent has focused scope |
| Skimming | Agent can't skip - that's all it does |
| Lost details | Parallel execution, nothing dropped |
| Slow | Concurrent execution |

**This is how you designed it. This is how it runs.**
