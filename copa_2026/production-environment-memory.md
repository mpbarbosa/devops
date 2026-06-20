# Production environment memory

Generated: 2026-06-14T22:20:06.081+00:00

## Role

- This machine is the **production environment** for `agora_na_copa_2026`.
- The **development environment runs on a different machine**.

## Repository context

- Repository: `mpbarbosa/agora_na_copa_2026`
- Remote: `git@github.com:mpbarbosa/agora_na_copa_2026.git`
- Working tree root: `/home/ubuntu/Documents/GitHub/agora_na_copa_2026`
- Active branch: `main`

## Machine and runtime

- Hostname: `ip-172-31-7-80`
- OS: `Linux 6.17.0-1017-aws x86_64 GNU/Linux`
- Virtualization: `KVM` guest
- Node.js: `v25.2.1`
- npm: `11.6.4`

## Hardware

- CPU: `2` vCPUs - `Intel(R) Xeon(R) Platinum 8259CL CPU @ 2.50GHz`
- RAM: `1.9 GiB` total (`~961 MiB` available at capture time)
- Swap: `0 B`
- Root disk: `25 GB` Amazon Elastic Block Store NVMe volume (`24 GB` root partition)
- Root filesystem usage at capture time: `15 GB` used / `9.1 GB` available (`61%` used)

## Application commands available here

- `npm run dev` - starts the Express/Vite development server
- `npm run build` - builds the frontend and bundles `server.ts` into `dist/server.cjs`
- `npm start` - runs the production bundle
- `npm run lint` - runs `tsc --noEmit`
- `npm run test:e2e` - runs Playwright end-to-end tests
- `npm run deploy` - runs `./scripts/deploy.sh`, which publishes the staging subtree and also redeploys `/var/www/agora_na_copa_2026` on this production host unless `AGORA_SKIP_LIVE_REDEPLOY=1`
- `npm run deploy:preflight` - runs `./scripts/deploy-preflight.sh`

## Notes for future memory use

- Treat this document as environment-specific context for production-only tasks.
- Avoid assuming that local development behavior, ports, or machine state match this host.
