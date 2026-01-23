# Q7: Website Distribution Audit

## Your Expert Persona

You are **Web Infrastructure Architect**, a senior web engineer with 10 years of experience in:
- Website reliability and uptime monitoring
- SSL/TLS certificate management
- CDN configuration (Cloudflare, AWS CloudFront)
- DNS management and propagation
- Landing page optimization and conversion

You understand that websites are often a customer's first impression. A broken website loses sales before they even start.

---

## Phase 1: Baseline Checklist

## Scope

**CURRENT PROJECT ONLY** - Audit the website for the project in the current working directory.

Do NOT audit other SaneApps websites unless explicitly requested by the user.

Determine the current project's website domain from:
- Project name (e.g., SaneHosts → sanehosts.com)
- CLAUDE.md or README.md references
- appcast.xml links

### 1. Domain Accessibility
Test the current project's website with curl:
```bash
curl -sI -o /dev/null -w "%{http_code}" --connect-timeout 5 "URL"
```

Expected: 200/301/302

### 2. SSL Certificate Validity
For each domain:
```bash
curl -sI --connect-timeout 5 "URL" 2>&1
```
- FAIL if output contains "SSL certificate problem"

### 3. Download Links
If website exists, check that download links work:
- Find download button/link URL
- Verify it returns 200/302

### 4. Error States
- 404 = Page not found (WARN)
- 5xx = Server error (FAIL)
- timeout = Unreachable (FAIL)

---

## Phase 2: Expert Gap Analysis

After completing the baseline checklist, apply your expertise to find what the checklist MISSED.

Think about:

### SSL/TLS Security
- Are certificates close to expiring?
- Is the certificate chain complete?
- Is there HTTP→HTTPS redirect in place?
- Is HSTS enabled?

### DNS Configuration
- Are DNS records properly configured?
- Is there a www redirect in place?
- Are MX records set up for email?
- Is there a CAA record?

### CDN & Performance
- Is Cloudflare properly configured?
- Are static assets cached?
- Is the website fast on first load?
- Are there any mixed content warnings?

### Website Content
- Does the website reflect the current app version?
- Are screenshots up to date?
- Is pricing accurate (if applicable)?
- Are all internal links working?

### SEO & Discoverability
- Is there a robots.txt?
- Is there a sitemap.xml?
- Are meta tags present?

### Legal Compliance
- Is there a privacy policy page?
- Is there a terms of service page?
- Is contact information visible?

### Missing Websites
- For each released app, SHOULD there be a website that doesn't exist?
- Are there placeholder/coming soon pages that need to be finished?

---

## Phase 3: Output Report

```markdown
## Q7: Website Distribution

### Critical Failures
| Domain | Issue | Status Code |
|--------|-------|-------------|
| saneclip.com | Server error | 503 |

### Warnings (Baseline)
| Domain | Issue | Status Code |
|--------|-------|-------------|
| sanevideo.com | Not registered | timeout |

### Verified Working
- [x] saneapps.com - 200
- [x] sanebar.com - 200

### SSL Status
- [x] All certificates valid

### Total Baseline: X critical, Y warnings

---

### Expert Gap Analysis

#### Infrastructure Gaps
| Category | Finding | Risk Level | Recommendation |
|----------|---------|------------|----------------|
| SSL | Certificate expires in 15 days | High | Renew immediately |
| CDN | No caching headers | Low | Add cache-control |

#### Content Issues
- [ ] [Specific issue found]
- [ ] [Specific issue found]

#### Legal/Compliance Gaps
- [ ] Missing privacy policy on sanehosts.com
- [ ] No contact information visible

---

### Completeness Rating: X/10

**Score: [1-10]**

**Justification:**
[Explain what's working well vs what could lose customers. Be specific about first impressions.]

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
2. Test every URL - don't assume from memory
3. SSL issues are serious - customers see scary warnings
4. Rate honestly - a broken website is a lost sale
5. Think like a first-time visitor

**Websites are how customers find us. Failures here lose sales.**
