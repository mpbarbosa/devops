# Development environment memory

Generated: 2026-06-14T02:00:31-03:00

## Role

- This machine is the **development environment** for `agora_na_copa_2026`.
- The **production environment runs on a different machine** and has its own memory doc in `docs/production-environment-memory.md`.

## Repository context

- Repository: `mpbarbosa/agora_na_copa_2026`
- Remote: `https://github.com/mpbarbosa/agora_na_copa_2026.git`
- Working tree root: `/home/mpb/Documents/GitHub/agora_na_copa_2026`
- Active branch: `main`
- Sibling staging repository: `/home/mpb/Documents/GitHub/mpbarbosa.com`
- Deployment subtree in staging repo: `agora_na_copa_2026/`

## Machine and runtime

- Hostname: `tatooine`
- OS: `Linux 7.0.0-22-generic x86_64 GNU/Linux`
- Node.js: `v26.3.0`
- npm: `11.17.0`

## Hardware

- CPU: `Intel(R) Core(TM) Ultra 5 135U`
- Architecture: `x86_64`
- Logical CPU cores: `14`
- Memory: `30 GiB`
- Swap: `2.0 GiB`
- Root filesystem: `441G total, 267G free`

## Application commands available here

- `npm run dev` - starts the Express/Vite development server
- `npm run build` - builds the frontend and bundles `server.ts` into `dist/server.cjs`
- `npm start` - runs the production bundle locally
- `npm run lint` - runs `tsc --noEmit`
- `npm run test:e2e` - runs Playwright end-to-end tests
- `npm run deploy:preflight` - builds and validates the deploy payload locally
- `npm run deploy` - syncs the deploy payload to the sibling `mpbarbosa.com` staging repository, pushes that subtree, and only runs the live-app redeploy step on hosts that already have `/var/www/agora_na_copa_2026` plus the `agora-na-copa-2026` systemd unit

## Deployment helpers available here

- `scripts/deploy-preflight.sh` - production preflight for `dist/` plus smoke checks
- `scripts/deploy.sh` - `guia_js`-style staging deploy into `mpbarbosa.com/agora_na_copa_2026/`, plus an automatic `06_redeploy.sh` handoff when run on a production host with the live service installed
- `shell_scripts/01_setup_app_directory.sh` - prepares the app directory from staged payload or local `dist/`
- `shell_scripts/06_redeploy.sh` - redeploy helper for server-side setup flows

## Notes for future memory use

- Treat this document as environment-specific context for **development and staging** tasks.
- This machine has both the source repo and the sibling `mpbarbosa.com` staging repo available locally.
- Do not assume the production host has the same Node/npm versions, filesystem paths, or local sibling repositories.
