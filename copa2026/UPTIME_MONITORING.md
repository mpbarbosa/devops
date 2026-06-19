# Uptime Monitoring — copa2026.mpbarbosa.com

Assessment of external uptime monitoring options for the Agora na Copa 2026
production server. "External" means checks run from outside the AWS host, so
they catch outages that the server itself cannot detect.

---

## What to monitor

| Target | URL | Expected result |
|--------|-----|-----------------|
| Health endpoint (primary) | `https://copa2026.mpbarbosa.com/api/health` | HTTP 200 + body contains `"status":"ok"` |
| Main page | `https://copa2026.mpbarbosa.com/` | HTTP 200 |
| TLS certificate | (same host) | Valid, ≥ 14 days remaining |

The health endpoint (`/api/health`) is the right primary check target: it
exercises the full stack (nginx → Node.js), returns a machine-readable status
field, and exposes uptime, load, and memory — more signal than a plain HTTP 200
on the root page.

### Current /api/health response shape

```json
{
  "status": "ok",
  "version": "unknown",
  "uptime": 2641,
  "load": [0.10, 0.10, 0.06],
  "memory": {
    "rss": 228532224,
    "heapUsed": 43860648,
    "heapTotal": 83030016,
    "external": 10901735
  },
  "system": {
    "freeMem": 1028898816,
    "totalMem": 2000437248
  }
}
```

> **Known issue**: `version` shows `"unknown"` in production because
> `process.env.npm_package_version` is only populated when running via `npm`.
> The systemd service runs `node dist/server.cjs` directly. Fix: read
> `package.json` at server startup with `readFileSync('package.json')` (the
> working directory `/var/www/agora_na_copa_2026` contains `package.json`
> as part of the deploy payload).

---

## Option comparison

### A — UptimeRobot ★ Simplest free option

- **Free tier**: 50 monitors, 5-minute interval, 2-month history
- **Check locations**: US East, US West, UK, Germany, Singapore (free tier: US only)
- **Notification channels**: email, Slack, webhook, Telegram, PagerDuty
- **Keyword check**: yes — can verify body contains `"status":"ok"`
- **SSL monitoring**: yes (alerts when cert expires within 30 days)
- **Status page**: yes (public or private)
- **Setup**: web UI at uptimerobot.com — no CLI/API required for basic use
- **Latency to BR audience**: checks from US, ~180 ms round-trip to AWS us-east-1

**Verdict**: Best choice if you want zero friction. 5-minute interval means a
brief outage (< 5 min) goes undetected, but for a personal project this is
acceptable. Most widely deployed, most documentation, simplest alerts.

---

### B — Better Stack (formerly Better Uptime) ★ Best free tier overall

- **Free tier**: unlimited monitors, **3-minute interval**, 180-day history
- **Check locations**: global (includes South America — São Paulo)
- **Notification channels**: email, Slack, PagerDuty, webhook, phone call (paid)
- **Keyword check**: yes
- **SSL monitoring**: yes
- **Incident management**: built-in (timeline, acknowledgement, post-mortems)
- **Status page**: yes, public branded page on free tier
- **Setup**: web UI at betterstack.com

**Verdict**: Stronger free tier than UptimeRobot: shorter interval, global
check locations (São Paulo matters for the Brazilian audience), incident
history UI, and a public status page at no cost. Slightly more complex to
navigate but not significantly. **Recommended if you want the best free option.**

---

### C — Freshping ★ Best 1-minute free tier

- **Free tier**: 50 monitors, **1-minute interval**, 10 global locations, 6-month history
- **Check locations**: includes **São Paulo** (lowest latency for BR users)
- **Notification channels**: email, Slack, webhook, SMS (paid)
- **Keyword check**: yes
- **SSL monitoring**: yes
- **Status page**: yes
- **Setup**: web UI at freshping.com (requires Freshworks account)

**Verdict**: Best raw monitoring frequency on the free tier. 1-minute checks
from São Paulo give the most accurate availability data for the target audience.
The Freshworks account requirement and UI are slightly heavier than the others.
**Recommended if response-time data from Brazil matters.**

---

### D — GitHub Actions scheduled workflow (zero new account)

- **Free tier**: included in existing GitHub Actions minutes (~2 000 min/month)
- **Interval**: minimum 15 minutes (GitHub does not guarantee cron precision)
- **Check**: `curl -f https://copa2026.mpbarbosa.com/api/health`
- **Notification**: email on workflow failure (standard GitHub notifications)
- **Keyword check**: possible with `jq` in the workflow step
- **SSL monitoring**: implicit (curl fails on bad cert)
- **Status page**: GitHub Actions run history (not a real status page)

**Sample workflow** (`.github/workflows/uptime-check.yml`):

```yaml
name: Uptime check
on:
  schedule:
    - cron: '*/15 * * * *'   # every 15 minutes
  workflow_dispatch:

jobs:
  ping:
    runs-on: ubuntu-latest
    timeout-minutes: 2
    steps:
      - name: Health check
        run: |
          response=$(curl -sf https://copa2026.mpbarbosa.com/api/health)
          echo "$response" | jq -e '.status == "ok"'
```

**Verdict**: No new account needed and it verifies the JSON body, not just HTTP
200. The 15-minute minimum interval and the lack of a proper incident dashboard
make it a supplement, not a replacement. Good as a second check if you already
use one of the dedicated services above.

---

### E — AWS CloudWatch Synthetics (native AWS)

- **Cost**: ~$0.0012 per canary run → **≈ $0.87/month** at 5-minute intervals (12 runs/hour × 720 hours × $0.0012)
- **Check locations**: same AWS region as the app (us-east-1)
- **Notification**: SNS → email, SMS, Lambda
- **Keyword check**: yes (Node.js canary script has full control)
- **SSL monitoring**: configurable in the canary script
- **Dashboard**: CloudWatch Metrics dashboard, native AWS console
- **Setup**: AWS Console → CloudWatch → Synthetics Canaries

**Verdict**: The only paid option here, but the cost is negligible. Native
integration means CloudWatch metrics, alarms, and dashboards can sit alongside
any other AWS monitoring. Overkill for a personal project unless the AWS console
is already part of the workflow. Not recommended unless you're already managing
other CloudWatch resources.

---

## Decision matrix

| Criterion | UptimeRobot | Better Stack | Freshping | GH Actions | CloudWatch |
|-----------|:-----------:|:------------:|:---------:|:----------:|:----------:|
| Free tier | ✓ | ✓ | ✓ | ✓ | ~$0.87/mo |
| Check interval | 5 min | 3 min | 1 min | 15 min | 5 min |
| São Paulo location | ✗ | ✓ | ✓ | US only | ✗ (us-east) |
| Keyword body check | ✓ | ✓ | ✓ | ✓ | ✓ |
| SSL cert alert | ✓ | ✓ | ✓ | implicit | ✓ |
| Public status page | ✓ | ✓ | ✓ | ✗ | ✗ |
| No new account | ✗ | ✗ | ✗ | ✓ | AWS console |
| Incident timeline | ✗ | ✓ | ✗ | ✗ | limited |

---

## Recommendation

**Primary**: **Better Stack** — best free tier, shortest interval (3 min),
São Paulo check location, incident history, and a free public status page.

**Supplement**: add the **GitHub Actions workflow** (Option D) to cover the
gap between the 3-minute checks and to verify the JSON body within the existing
CI infrastructure at no extra cost.

This combination costs nothing, requires only one new account (Better Stack),
and provides: external availability checks from South America, SSL cert
expiry alerts, a public status page, and a lightweight backup ping from GitHub
at 15-minute intervals.

---

## Setup instructions (Better Stack)

1. Create a free account at **betterstack.com/uptime**
2. Click **New Monitor** → type **Website**
3. Fill in:
   - **URL**: `https://copa2026.mpbarbosa.com/api/health`
   - **Check frequency**: 3 minutes
   - **Check regions**: include São Paulo
   - **Confirm string** (keyword check): `"status":"ok"`
4. Add a second monitor for the root page:
   - **URL**: `https://copa2026.mpbarbosa.com/`
   - Keyword: (optional — leave blank for HTTP 200 check only)
5. Configure alert channels (email is pre-configured on signup)
6. Optionally create a public **Status Page** and link it from the app

---

## Related files

All paths are relative to the `agora_na_copa_2026` repo.

| File | Purpose |
|------|---------|
| `shell_scripts/08_setup_monitoring.sh` | Layer 1 — nginx timed access log |
| `server.ts` (lines ~79–92) | Layer 2 — Express per-request logger + trust proxy |
| `server.ts` (`/api/health` route) | Layer 3 — health endpoint consumed by uptime monitors |
| `.github/workflows/ci.yml` | Existing CI — extend with `uptime-check.yml` for Option D |
