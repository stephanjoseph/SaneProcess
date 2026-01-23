# Security Audit

> You are auditing for **accidentally leaked secrets, PII, and internal information**.
> This is the audit that prevents embarrassing security incidents.

---

## The Problem You're Solving

Documentation often contains:
- Real API keys that were "just for testing"
- Screenshots with visible passwords, tokens, or PII
- Internal URLs that shouldn't be public
- Email addresses of real users
- File paths that reveal system structure

One leaked secret in a README can compromise everything.

---

## What To Check

### 1. Secrets in Code Examples

Scan all markdown files for patterns that look like real credentials:

```
# API keys (various formats)
[A-Za-z0-9]{32,}
sk-[A-Za-z0-9]{20,}
api[_-]?key.*[=:]\s*['"][^'"]+['"]

# AWS
AKIA[0-9A-Z]{16}
aws[_-]?secret

# Private keys
-----BEGIN (RSA |EC |OPENSSH )?PRIVATE KEY-----

# Tokens
(bearer|token|auth)[_-]?.*[=:]\s*['"][^'"]+['"]

# Passwords
password[_-]?.*[=:]\s*['"][^'"]+['"]
```

**Red flags:**
- Any 32+ character alphanumeric string in a config example
- Anything that looks like `sk-`, `pk-`, `api_`, `secret_`
- Base64 strings that aren't obviously placeholders

**Safe patterns (OK to use):**
- `YOUR_API_KEY_HERE`
- `<api-key>`
- `xxxxxxxx`
- `test-key-do-not-use`

### 2. Screenshots with Sensitive Data

Review ALL images in docs for:
- Visible passwords or tokens
- Email addresses (especially real ones)
- Names of real people/users
- Internal URLs or IP addresses
- File paths showing usernames (`/Users/john/...`)
- Browser tabs with sensitive info
- Notification badges with private data

### 3. Internal URLs and Paths

Search for:
- `localhost` URLs that reveal internal architecture
- Internal domain names (`.internal`, `.local`, `.corp`)
- IP addresses (especially private ranges: 10.x, 192.168.x, 172.16-31.x)
- Internal tool URLs (Jira, Confluence, internal wikis)
- File paths with usernames or internal structure

### 4. Contact Information

Check for:
- Personal email addresses (use hello@company.com not john@company.com)
- Phone numbers
- Physical addresses (unless intentionally public)
- Slack/Discord channel IDs that shouldn't be public

### 5. Third-Party Service Details

Look for:
- Database connection strings
- OAuth client IDs/secrets
- Webhook URLs
- S3 bucket names (can be enumerated)
- Server names/hostnames

---

## Output Format

```markdown
## Security Audit Report

### 🔴 CRITICAL (Fix Immediately)
| File | Line | Issue | Looks Like |
|------|------|-------|------------|
| README.md | 45 | Possible API key | `sk-abc123...` |
| docs/setup.md | 12 | AWS key pattern | `AKIA...` |

### 🟡 WARNING (Review)
| File | Issue | Recommendation |
|------|-------|----------------|
| screenshot.png | Shows /Users/john path | Retake with generic path |
| config.md | localhost:3000 visible | OK if intentional |

### ✅ VERIFIED SAFE
- [ ] No real API keys found
- [ ] Screenshots reviewed for PII
- [ ] No internal URLs exposed
- [ ] Contact info uses official addresses
```

---

## Rules

1. **When in doubt, flag it** - False positive is better than leaked secret
2. **Placeholder !== Safe** - `password123` is not a safe example
3. **Screenshots need review** - Can't grep an image, must visually check
4. **File paths reveal structure** - `/Users/realname/` is PII

---

## Common Violations

| Violation | Example | Fix |
|-----------|---------|-----|
| Real-looking test key | `api_key: "sk_test_abc123xyz789"` | Use `YOUR_API_KEY` |
| Path with username | `/Users/john/project/` | Use `~/project/` or `/path/to/` |
| Screenshot with email | Profile page showing user@email.com | Blur or use test account |
| Internal Slack link | `https://company.slack.com/...` | Remove or make generic |
| Localhost with port | `http://localhost:5432` | OK in dev docs, flag for review |

---

## Automated Check Script

```bash
# Run this on docs to find potential secrets
grep -rn -E "(api[_-]?key|secret|password|token|bearer|AKIA)[^a-z]" *.md
grep -rn -E "[A-Za-z0-9]{32,}" *.md
grep -rn -E "sk-[A-Za-z0-9]{20,}" *.md
```

If ANY of these return results that aren't obviously placeholders, flag for review.
