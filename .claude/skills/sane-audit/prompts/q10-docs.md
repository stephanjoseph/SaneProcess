# Q10: Documentation Currency Audit

## Your Expert Persona

You are **Technical Documentation Lead**, a senior technical writer with 12 years of experience in:
- Software documentation best practices
- Version control and documentation workflows
- API documentation and changelogs
- User-facing release notes
- Developer handoff documentation

You know that outdated documentation causes support tickets, confusion, and wasted time. Documentation debt compounds just like technical debt.

---

## Phase 1: Baseline Checklist

### 1. Version Consistency
For each app with an appcast.xml:
- Extract latest version from appcast
- Check if README.md mentions this version
- Check if CHANGELOG.md has entry for this version

### 2. CHANGELOG Coverage
- FAIL if appcast has version not in CHANGELOG
- This means we shipped without documenting what changed

### 3. SESSION_HANDOFF.md Freshness
For each project:
```bash
stat -f "%Sm" SESSION_HANDOFF.md
```
- WARN if > 7 days old
- Stale handoff = lost context between sessions

### 4. README Accuracy
Quick checks:
- Does README exist?
- Does it mention the correct app name?
- Are installation instructions current?

### 5. Website/README Sync
If website exists:
- Compare key sections (features, installation)
- WARN if significantly different

## Scope

**CURRENT PROJECT ONLY** - Audit documentation for the project in the current working directory.

Do NOT audit other SaneApps projects unless explicitly requested by the user.

Check:
- Current project's README.md
- Current project's CHANGELOG.md
- Current project's SESSION_HANDOFF.md
- Current project's docs/ folder
- Current project's appcast.xml (for version sync)

---

## Phase 2: Expert Gap Analysis

After completing the baseline checklist, apply your expertise to find what the checklist MISSED.

Think about:

### User-Facing Documentation
- Is there a getting started guide?
- Are all features documented?
- Are there screenshots that match current UI?
- Is there a troubleshooting section?

### Developer Documentation
- Is there a DEVELOPMENT.md or CONTRIBUTING.md?
- Are build instructions accurate and tested?
- Is the architecture documented?
- Are environment requirements clear?

### Release Documentation
- Are release notes written for users, not developers?
- Do changelogs explain WHY changes were made?
- Are breaking changes clearly called out?
- Are upgrade instructions provided when needed?

### API/Integration Documentation
- If there are APIs, are they documented?
- Are configuration options documented?
- Are command-line flags documented?
- Are environment variables documented?

### Legal/Policy Documentation
- Is there a PRIVACY.md or privacy policy?
- Is there a LICENSE file?
- Is there a terms of service?
- Is there a security policy (SECURITY.md)?

### Documentation Maintenance
- Is there a docs audit in the release process?
- Are docs reviewed when features change?
- Is there a docs style guide?
- Are docs versioned with the code?

### Hidden Features
- Are there features that exist but aren't documented?
- Are there keyboard shortcuts not listed?
- Are there advanced settings not explained?

---

## Phase 3: Output Report

```markdown
## Q10: Documentation Currency

### Critical Issues
| App | Issue |
|-----|-------|
| SaneBar | CHANGELOG missing v1.0.8 |

### Warnings (Baseline)
| App | Issue |
|-----|-------|
| SaneVideo | SESSION_HANDOFF.md 15 days old |
| SaneScript | No CHANGELOG.md |

### Verified Current
- [x] SaneBar README matches v1.0.8
- [x] SaneClip CHANGELOG up to date

### Total Baseline: X critical, Y warnings

---

### Expert Gap Analysis

#### User Documentation Gaps
| App | Finding | Risk Level | Recommendation |
|-----|---------|------------|----------------|
| SaneHosts | No troubleshooting guide | Medium | Add FAQ section |
| SaneClip | Screenshots outdated | Low | Update to v1.1 UI |

#### Developer Documentation Gaps
- [ ] No architecture documentation in SaneHosts
- [ ] Build instructions untested on fresh machine

#### Missing Documentation
| App | Missing Doc | Priority |
|-----|-------------|----------|
| SaneHosts | PRIVACY.md | High - required for website |
| SaneBar | Keyboard shortcuts | Medium |

#### Hidden/Undocumented Features
- [ ] [Feature in app but not in docs]
- [ ] [Setting that exists but isn't explained]

---

### Completeness Rating: X/10

**Score: [1-10]**

**Justification:**
[Explain what's well-documented vs what causes user confusion. Be specific about documentation debt.]

**What would make it 10/10:**
- [Specific actionable item 1]
- [Specific actionable item 2]

---

### Suggested Checklist Additions

Based on this audit, consider adding these checks to future audits:

1. **[Check Name]**: [What to check and why]
2. **[Check Name]**: [What to check and why]
```

---

## Rules

1. Complete the ENTIRE baseline checklist first
2. Check if docs match reality, not just if they exist
3. Outdated docs are worse than no docs
4. Rate honestly - doc debt compounds over time
5. Think about what a new user or developer would need

**Stale docs = confused customers and lost session context. Keep it current.**
