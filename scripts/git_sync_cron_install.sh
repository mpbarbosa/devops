#!/bin/bash
#
# git_sync_cron_install.sh - Install (or remove) the git_sync cron job
#
# Adds a crontab entry that runs git_sync.sh every 10 minutes.
# Safe to run multiple times — won't create duplicate entries.
#
# Usage:
#   ./git_sync_cron_install.sh           # install
#   ./git_sync_cron_install.sh --remove  # remove
#
# Author: mpb
# Repository: https://github.com/mpbarbosa/devops
# License: MIT

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GIT_SYNC="$SCRIPT_DIR/git_sync.sh"
CRON_ENTRY="*/10 * * * * $GIT_SYNC"
MARKER="git_sync.sh"

if [[ ! -f "$GIT_SYNC" ]]; then
  echo "ERROR: $GIT_SYNC not found" >&2
  exit 1
fi

if [[ "${1}" == "--remove" ]]; then
  if crontab -l 2>/dev/null | grep -q "$MARKER"; then
    crontab -l 2>/dev/null | grep -v "$MARKER" | crontab -
    echo "Removed cron entry for $GIT_SYNC"
  else
    echo "No cron entry found for $GIT_SYNC — nothing to remove"
  fi
  exit 0
fi

if crontab -l 2>/dev/null | grep -q "$MARKER"; then
  echo "Cron entry already exists:"
  crontab -l 2>/dev/null | grep "$MARKER"
  exit 0
fi

( crontab -l 2>/dev/null; echo "$CRON_ENTRY" ) | crontab -
echo "Installed cron entry:"
echo "  $CRON_ENTRY"
