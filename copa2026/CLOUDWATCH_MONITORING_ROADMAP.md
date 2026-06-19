# CloudWatch Monitoring Roadmap — copa2026.mpbarbosa.com

Implementation plan for external uptime monitoring of the Agora na Copa 2026
production server using AWS CloudWatch Synthetics. All resources live in
`us-east-1`, co-located with the EC2 host (`ip-172-31-7-80`).

Estimated monthly cost: **~$1.75** (2 canaries × 12 runs/hour × 720 h × $0.0012).

---

## Overview

```
Canary (health)  ─┐
                   ├─→ CloudWatch Metrics → Alarms → SNS → email
Canary (root)    ─┘

CloudWatch Dashboard  (availability + latency + memory/load from health)
```

---

## Phase 1 — SNS alert topic

Create the notification target before any alarms are wired up.

```bash
# Create topic
aws sns create-topic \
  --name copa2026-alerts \
  --region us-east-1

# Subscribe your email (replace ARN from output above)
aws sns subscribe \
  --topic-arn arn:aws:sns:us-east-1:<ACCOUNT_ID>:copa2026-alerts \
  --protocol email \
  --notification-endpoint mpbarbosa@gmail.com \
  --region us-east-1
```

Confirm the subscription from the email AWS sends before proceeding — alarms
will not deliver until the subscription is confirmed.

---

## Phase 2 — Canary 1: health endpoint

Checks `https://copa2026.mpbarbosa.com/api/health` every 5 minutes.
Fails if HTTP status ≠ 200 **or** if the JSON body does not contain
`"status":"ok"`.

### Canary script

Save as `canaries/health-check.js` in this repo.

```javascript
// CloudWatch Synthetics runtime: syn-nodejs-puppeteer-9.x
const synthetics = require('Synthetics');
const log = require('SyntheticsLogger');
const https = require('https');

const TARGET = 'https://copa2026.mpbarbosa.com/api/health';

const checkHealth = async () => {
  const result = await new Promise((resolve, reject) => {
    https.get(TARGET, { timeout: 10000 }, (res) => {
      let body = '';
      res.on('data', chunk => (body += chunk));
      res.on('end', () => resolve({ status: res.statusCode, body }));
    }).on('error', reject);
  });

  if (result.status !== 200) {
    throw new Error(`HTTP ${result.status} — expected 200`);
  }

  const json = JSON.parse(result.body);
  if (json.status !== 'ok') {
    throw new Error(`status="${json.status}" — expected "ok"`);
  }

  // Log extra signals for the dashboard (not used in pass/fail logic)
  log.info('health', JSON.stringify({
    uptime: json.uptime,
    load1:  json.load?.[0],
    memFree: json.system?.freeMem,
  }));
};

exports.handler = async () => synthetics.executeStep('health-check', checkHealth);
```

### Canary creation (AWS Console path)

1. **CloudWatch → Synthetics → Canaries → Create canary**
2. Blueprint: **Inline editor** (paste the script above)
3. Name: `copa2026-health`
4. Schedule: every **5 minutes**
5. Data retention: **31 days** (free tier covers 1 month)
6. IAM role: let the wizard create one (`CloudWatchSyntheticsRole-copa2026-health`)
7. VPC: **none** — the target is public internet

### Canary creation (AWS CLI path)

```bash
# 1. Zip the script
zip canary-health.zip canaries/health-check.js

# 2. Upload to S3 (bucket must already exist)
aws s3 cp canary-health.zip s3://<YOUR_BUCKET>/canaries/

# 3. Create the canary
aws synthetics create-canary \
  --name copa2026-health \
  --code S3Bucket=<YOUR_BUCKET>,S3Key=canaries/canary-health.zip,Handler=health-check.handler \
  --artifact-s3-location s3://<YOUR_BUCKET>/artifacts/ \
  --execution-role-arn arn:aws:iam::<ACCOUNT_ID>:role/CloudWatchSyntheticsRole-copa2026 \
  --schedule Expression="rate(5 minutes)" \
  --runtime-version syn-nodejs-puppeteer-9.x \
  --region us-east-1
```

---

## Phase 3 — Canary 2: root page

Checks `https://copa2026.mpbarbosa.com/` every 5 minutes. Fails if
HTTP status ≠ 200. A simpler check that catches nginx/routing failures
that the health endpoint might mask.

### Canary script

Save as `canaries/root-check.js`.

```javascript
const synthetics = require('Synthetics');
const https = require('https');

const TARGET = 'https://copa2026.mpbarbosa.com/';

const checkRoot = async () => {
  const status = await new Promise((resolve, reject) => {
    https.get(TARGET, { timeout: 10000 }, res => resolve(res.statusCode))
      .on('error', reject);
  });

  if (status !== 200) {
    throw new Error(`HTTP ${status} — expected 200`);
  }
};

exports.handler = async () => synthetics.executeStep('root-check', checkRoot);
```

Canary name: `copa2026-root`. Same schedule and settings as Phase 2.

---

## Phase 4 — CloudWatch Alarms

Create one alarm per canary on the `SuccessPercent` metric.

```bash
# Alarm for health canary
aws cloudwatch put-metric-alarm \
  --alarm-name "copa2026-health-down" \
  --alarm-description "Health endpoint failing" \
  --namespace CloudWatchSynthetics \
  --metric-name SuccessPercent \
  --dimensions Name=CanaryName,Value=copa2026-health \
  --period 300 \
  --evaluation-periods 2 \
  --threshold 100 \
  --comparison-operator LessThanThreshold \
  --statistic Average \
  --treat-missing-data breaching \
  --alarm-actions arn:aws:sns:us-east-1:<ACCOUNT_ID>:copa2026-alerts \
  --ok-actions    arn:aws:sns:us-east-1:<ACCOUNT_ID>:copa2026-alerts \
  --region us-east-1

# Alarm for root canary (same shape, different CanaryName and alarm-name)
aws cloudwatch put-metric-alarm \
  --alarm-name "copa2026-root-down" \
  --alarm-description "Root page failing" \
  --namespace CloudWatchSynthetics \
  --metric-name SuccessPercent \
  --dimensions Name=CanaryName,Value=copa2026-root \
  --period 300 \
  --evaluation-periods 2 \
  --threshold 100 \
  --comparison-operator LessThanThreshold \
  --statistic Average \
  --treat-missing-data breaching \
  --alarm-actions arn:aws:sns:us-east-1:<ACCOUNT_ID>:copa2026-alerts \
  --ok-actions    arn:aws:sns:us-east-1:<ACCOUNT_ID>:copa2026-alerts \
  --region us-east-1
```

`evaluation-periods 2` means two consecutive 5-minute periods must fail
before an alert fires (~10-minute lag), which avoids false positives from
transient checks. Lower to `1` if you prefer immediate alerts.

---

## Phase 5 — CloudWatch Dashboard

Create a single dashboard that surfaces availability and latency at a glance.

```bash
aws cloudwatch put-dashboard \
  --dashboard-name copa2026 \
  --dashboard-body file://canaries/dashboard.json \
  --region us-east-1
```

### dashboard.json

```json
{
  "widgets": [
    {
      "type": "metric",
      "properties": {
        "title": "Availability — health endpoint (%)",
        "metrics": [
          ["CloudWatchSynthetics","SuccessPercent","CanaryName","copa2026-health"]
        ],
        "period": 300,
        "stat": "Average",
        "view": "timeSeries",
        "yAxis": {"left": {"min": 0, "max": 100}}
      }
    },
    {
      "type": "metric",
      "properties": {
        "title": "Availability — root page (%)",
        "metrics": [
          ["CloudWatchSynthetics","SuccessPercent","CanaryName","copa2026-root"]
        ],
        "period": 300,
        "stat": "Average",
        "view": "timeSeries",
        "yAxis": {"left": {"min": 0, "max": 100}}
      }
    },
    {
      "type": "metric",
      "properties": {
        "title": "Canary duration (ms)",
        "metrics": [
          ["CloudWatchSynthetics","Duration","CanaryName","copa2026-health", {"label":"health"}],
          ["CloudWatchSynthetics","Duration","CanaryName","copa2026-root",   {"label":"root"}]
        ],
        "period": 300,
        "stat": "Average",
        "view": "timeSeries"
      }
    },
    {
      "type": "alarm",
      "properties": {
        "title": "Alarm status",
        "alarms": [
          "arn:aws:cloudwatch:us-east-1:<ACCOUNT_ID>:alarm:copa2026-health-down",
          "arn:aws:cloudwatch:us-east-1:<ACCOUNT_ID>:alarm:copa2026-root-down"
        ]
      }
    }
  ]
}
```

Replace `<ACCOUNT_ID>` with your 12-digit AWS account ID throughout.

---

## Phase 6 — SSL certificate alarm

CloudWatch has a managed metric for ACM-issued certificates. If the cert is
managed by ACM, this is free and zero-effort.

```bash
# Find the cert ARN
aws acm list-certificates --region us-east-1

# Create alarm: alert when < 30 days remain
aws cloudwatch put-metric-alarm \
  --alarm-name "copa2026-cert-expiry" \
  --alarm-description "TLS cert expiring within 30 days" \
  --namespace AWS/CertificateManager \
  --metric-name DaysToExpiry \
  --dimensions Name=CertificateArn,Value=<CERT_ARN> \
  --period 86400 \
  --evaluation-periods 1 \
  --threshold 30 \
  --comparison-operator LessThanOrEqualToThreshold \
  --statistic Minimum \
  --alarm-actions arn:aws:sns:us-east-1:<ACCOUNT_ID>:copa2026-alerts \
  --region us-east-1
```

If the cert is Let's Encrypt (self-managed, not ACM), skip this phase — the
canary will fail naturally when the cert expires and curl rejects it.

---

## Phase 7 — Fix the `version: "unknown"` field (optional)

From `UPTIME_MONITORING.md`: the health endpoint returns `"version":"unknown"`
because `process.env.npm_package_version` is empty when the systemd service
runs `node dist/server.cjs` directly.

In `server.ts`, near the top:

```typescript
import { readFileSync } from 'fs';

const pkg = JSON.parse(readFileSync('package.json', 'utf8')) as { version: string };
const APP_VERSION = pkg.version;
```

Then in the `/api/health` handler, replace `process.env.npm_package_version`
with `APP_VERSION`. The working directory `/var/www/agora_na_copa_2026`
contains `package.json` as part of the deploy payload.

This doesn't affect monitoring pass/fail, but gives the dashboard a real
version string to correlate incidents with deploys.

---

## Execution checklist

| # | Phase | AWS service | Cost |
|---|-------|-------------|------|
| 1 | SNS topic + email subscription | SNS | free |
| 2 | Canary: health endpoint | CloudWatch Synthetics | ~$0.87/mo |
| 3 | Canary: root page | CloudWatch Synthetics | ~$0.87/mo |
| 4 | Alarms (2) | CloudWatch | free (10 alarms free tier) |
| 5 | Dashboard | CloudWatch | free (3 dashboards free tier) |
| 6 | SSL cert alarm | ACM / CloudWatch | free (if ACM-managed) |
| 7 | Fix `version` field | code change | — |
| **Total** | | | **~$1.75/mo** |

---

## Files in this repo

| File | Purpose |
|------|---------|
| `canaries/health-check.js` | Canary 1 script |
| `canaries/root-check.js` | Canary 2 script |
| `canaries/dashboard.json` | Dashboard widget definition |

---

## Related

- [`UPTIME_MONITORING.md`](./UPTIME_MONITORING.md) — full option comparison (UptimeRobot, Better Stack, Freshping, GH Actions, CloudWatch)
- Production host: `ip-172-31-7-80`, `us-east-1`, running `node dist/server.cjs` under systemd
