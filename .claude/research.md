# Research Cache

> **Working scratchpad for research agents.** Check here before researching. Update after finding.
> When findings become permanent knowledge, graduate them to ARCHITECTURE.md or DEVELOPMENT.md.
> **Size cap: 200 lines.** If over cap, graduate oldest verified findings first.

---

## Email System Catastrophe — Root Cause & Fix
**Updated:** 2026-02-02 | **Status:** verified-fixed | **TTL:** 90d
**Source:** Direct investigation of Cloudflare API, Resend API, D1 database, worker source code

### Root Cause (3 problems)
1. **MX pointed to Amazon SES, not Cloudflare.** Email routing rule existed (hi@saneapps.com -> worker) but never fired. All inbound went through Resend webhook instead.
2. **Webhook error handler returned 500 with no storage.** Any processing failure = email silently lost.
3. **Self-send loop.** 94 "Thank you for your kind words!" emails sent TO hi@saneapps.com flooding Resend receiving.

### Impact
- **12 real customer/influencer emails lost** between Jan 20-30
- Critical losses: Bartender plist (alberth@matos.cc), first refund request (kian), update bug report (michal@stratusone.pl), detailed bug report (spokomaciek), influencer replies (macvince, patrick)
- D1 confirmed clean via sqlite_sequence — emails were never stored, not deleted

### Fixes Applied (Feb 2, 2026)
1. **MX switched** to Cloudflare (route1/2/3.mx.cloudflare.net) — confirmed propagated
2. **Worker parsing fixed** — `message.raw` is ReadableStream not function; now uses postal-mime
3. **Error handler stores emails** with status='error' + notifies owner + returns 200
4. **From header** used instead of envelope sender (avoids SES bounce addresses)

### Files Modified
- `sane-email-automation/src/index.js` — postal-mime import, parseEmail rewrite, error handlers
- `sane-email-automation/src/db.js` — storeEmail accepts status parameter

---

## Resend API — Correct Usage Reference
**Updated:** 2026-02-02 | **Status:** verified | **TTL:** 90d
**Source:** resend.com/docs/api-reference/*, resend.com/docs/llms.txt

### Pagination (CRITICAL — we got this wrong before)
- **Cursor-based**, NOT offset. `offset` parameter does not exist.
- Params: `limit` (1-100, default 20), `after` (cursor ID), `before` (cursor ID)
- Response: `{ object: "list", has_more: bool, data: [...] }`
- Iterate: use last item's `id` as `after` value until `has_more: false`

### Key Endpoints
| Endpoint | Method | Purpose |
|----------|--------|---------|
| `/emails` | GET | List sent emails (paginated) |
| `/emails` | POST | Send email |
| `/emails/receiving` | GET | List received emails (paginated) |
| `/emails/receiving/{id}` | GET | Get received email content (text, html, raw URL) |
| `/emails/receiving/{id}/attachments/{aid}` | GET | Get attachment download_url |
| `/emails?limit=100&after={id}` | GET | Paginate sent emails |

### Rate Limits
- 2 req/sec (all endpoints, can request increase)
- Headers: `ratelimit-limit`, `ratelimit-remaining`, `ratelimit-reset`, `retry-after`
- Quotas: `x-resend-daily-quota` (free only), `x-resend-monthly-quota` (all)

### Webhooks Ingester
- Open source: github.com/resend/resend-webhooks-ingester
- Stores all webhook events in your own DB (Postgres/MySQL/Supabase)
- Svix signature verification, idempotent storage, Docker available
- Resend retries failed webhooks for 24 hours; manual replay from dashboard

---

## Cloudflare vs Resend — Migration Verdict
**Updated:** 2026-02-02 | **Status:** verified | **TTL:** 30d

**Current architecture:** Cloudflare Email Routing (inbound) -> Worker -> D1. Resend API (outbound).
**Cloudflare Email Service:** Still private beta (Feb 2026). No GA date. Cannot replace Resend yet.
**Decision:** Stay with Resend for outbound. Monitor beta. Re-evaluate Q2-Q3 2026.

---

## Email Checking Procedure
**Updated:** 2026-02-02 | **Status:** verified | **TTL:** 90d

```bash
# 1. Get Resend API key
RESEND_KEY=$(security find-generic-password -s resend -a api_key -w)

# 2. List received emails (PROPER cursor pagination)
EMAILS=$(curl -s "https://api.resend.com/emails/receiving?limit=100" \
  -H "Authorization: Bearer $RESEND_KEY")
# Check has_more, use last ID with &after= to get next page

# 3. Read specific email content
curl -s "https://api.resend.com/emails/receiving/{id}" \
  -H "Authorization: Bearer $RESEND_KEY"

# 4. Download attachment
# First get download_url from attachment endpoint:
curl -s "https://api.resend.com/emails/receiving/{email_id}/attachments/{attachment_id}" \
  -H "Authorization: Bearer $RESEND_KEY"
# Then download from the download_url (signed, expires)

# 5. Check D1 for stored emails
cd ~/SaneApps/infra/sane-email-automation
npx wrangler d1 execute sane-email-db --remote \
  --command "SELECT id, from_email, subject, status, created_at FROM emails ORDER BY id DESC LIMIT 10"

# 6. Send reply (as Mr. Sane)
curl -X POST "https://api.resend.com/emails" \
  -H "Authorization: Bearer $RESEND_KEY" \
  -H "Content-Type: application/json" \
  -d '{"from":"Mr. Sane <hi@saneapps.com>","to":"recipient","subject":"Re: ...","text":"..."}'
```
