# EC2 Capacity & Deploy-Safety Roadmap — copa2026.mpbarbosa.com

Plan to stop the production EC2 host from running out of memory during deploys.
The host (`ip-172-31-7-80`, `us-east-1`) is a small burstable instance:
**2 vCPU, ~1.9 GiB RAM, 0 swap, ~24 GB gp EBS root**. At rest it is healthy
(load ~0.03, ~900 MB free), but a deploy melts it.

## Incident that motivated this (2026-06-22)

Running `npm run deploy` **on the prod host** runs the full toolchain
(`vite build` + `esbuild` + `tsc` + deploy-preflight smoke test + `npm ci`) while
the live service is still serving. On 1.9 GiB with no swap this exhausts RAM and
thrashes. `top` during the deploy showed:

- **Load average 30.58** on 2 vCPUs (~15× capacity)
- **88.7% sy, 0.0% idle, 11.1% iowait** — kernel-bound + disk-bound
- **72 MB free of 1908**, **0 swap**, `kswapd` (kernel thread) at ~84% CPU
- Many processes in `D` (uninterruptible I/O) state
- `https://copa2026.mpbarbosa.com/api/health` **timed out — site offline during the deploy**

Root cause: **building on the prod host**. The dev machine's deploy already
produces a prebuilt `dist/`; prod should never re-run the build.

## Estimated cost

| Action | Monthly cost |
|---|---|
| Phase 1 — swap file | **$0** (uses existing EBS free space) |
| Phase 2 — build off-host / no-build go-live | **$0** |
| Phase 3 — systemd memory guardrails | **$0** |
| Phase 4 — instance upgrade (last resort) | **~+$15/mo** (2 GiB → 4 GiB class) |

Preferred path is Phases 1–3 (zero cost). Phase 4 only if memory pressure
persists after building off-host.

---

## Phase 1 — Add a swap file (immediate, do first)

A 1.9 GiB box with zero swap has no cushion: a memory spike becomes OOM-thrash
or an OOM-kill of the live service. A 2 GB swapfile turns that into "slower but
survives." Run on the prod host:

```bash
sudo fallocate -l 2G /swapfile
sudo chmod 600 /swapfile
sudo mkswap /swapfile
sudo swapon /swapfile

# Persist across reboots
echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab

# Prefer RAM, only swap under real pressure
echo 'vm.swappiness=10' | sudo tee /etc/sysctl.d/99-swappiness.conf
sudo sysctl -p /etc/sysctl.d/99-swappiness.conf

# Verify
free -h
swapon --show
```

---

## Phase 2 — Build off-host (the real fix: never build on prod)

The dev machine's `scripts/deploy.sh` already builds `dist/` and publishes the
**prebuilt** payload to the `mpbarbosa.com` repo. Prod's go-live should consume
that prebuilt payload only — **no vite/esbuild/tsc on prod**.

Target prod "go-live" sequence (no build):

```bash
# On prod: pull the prebuilt deploy payload, then sync + restart only.
cd ~/Documents/GitHub/mpbarbosa.com && git pull --ff-only
# rsync the prebuilt dist into /var/www, install runtime deps, restart:
#   rsync -a --delete (excluding .env)  mpbarbosa.com/agora_na_copa_2026/ -> /var/www/agora_na_copa_2026/
#   npm ci --omit=dev
#   sudo systemctl restart agora-na-copa-2026
```

Action items (in the app repo `agora_na_copa_2026`):
- `shell_scripts/06_redeploy.sh` already rsyncs + `npm ci --omit=dev` + restarts;
  ensure it points `STAGING_DIR` at the **prebuilt** `mpbarbosa.com/agora_na_copa_2026`
  payload, and never hits the "local project selected … rebuilding" branch on prod.
- Add a thin `go-live` wrapper (or document the command above) so the operator
  never runs full `npm run deploy` on prod.

Result: prod go-live becomes a fast rsync + restart (seconds, low memory)
instead of a multi-minute, RAM-hungry build.

---

## Phase 3 — systemd memory guardrails (defense in depth)

Cap the service so a runaway build or leak can't take the whole box down, and so
the kernel kills the offender (not sshd/critical services). Add a drop-in:

```bash
sudo systemctl edit agora-na-copa-2026
```
```ini
[Service]
# Soft throttle, then hard ceiling well under total RAM
MemoryHigh=1200M
MemoryMax=1500M
```
```bash
sudo systemctl daemon-reload
sudo systemctl restart agora-na-copa-2026
```

Pair with the memory/load alarm from `CLOUDWATCH_MONITORING_ROADMAP.md`
(the `/api/health` payload already exposes `memory` and `load`).

---

## Phase 4 — Right-size the instance (last resort, costs money)

Only if memory pressure persists *after* building off-host. The owner is
minimizing cost, so treat this as a fallback, not a first move.

| Option | RAM | ~On-demand (us-east-1) | Notes |
|---|---|---|---|
| Current (~2 GiB, T-series) | ~1.9 GiB | baseline | Fine at rest; tight under load |
| Upgrade to 4 GiB class (t3.medium) | 4 GiB | ~+$15/mo | Comfortable headroom |

Also watch **T-series CPU credits**: sustained high CPU (e.g. a long build) can
deplete burst credits and throttle the instance. Building off-host avoids this
too. Check credits in CloudWatch (`CPUCreditBalance`) before considering Unlimited
mode or a non-burstable type.

---

## Recommended order

1. **Phase 1** (swap) — now, zero cost, immediate safety net.
2. **Phase 2** (build off-host) — removes the root cause of the meltdown.
3. **Phase 3** (systemd limits) — guardrail so failures stay contained.
4. **Phase 4** (upgrade) — only if 1–3 prove insufficient.
