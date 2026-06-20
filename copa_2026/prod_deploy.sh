#!/bin/bash

GITHUB_DIR="$HOME/Documents/GitHub"

log() {
  local level="$1"; shift
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] [$level] $*"
}

log INFO "running sync_to_staging --step2"
if ! "$GITHUB_DIR/mpbarbosa_site/shell_scripts/sync_to_staging.sh" --step2 --production-dir "/var/www/mpbarbosa.com"; then
  log ERROR "sync_to_staging failed"
  exit 1
fi
log INFO "done"
