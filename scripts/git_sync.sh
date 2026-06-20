#!/bin/bash
#
# git_sync.sh - Pull updates for all git repos in ~/Documents/GitHub
#
# For each repo that has a configured remote, fetches and pulls when the
# local branch is behind. Skips repos with local changes to avoid conflicts.
#
# Usage:
#   ./git_sync.sh [--verbose]
#
# Options:
#   --verbose   Print status for every repo, not just ones that changed or errored
#
# Logs: ~/.local/log/git_sync.log (rotated at 500 KB)
#
# Author: mpb
# Repository: https://github.com/mpbarbosa/devops
# License: MIT

readonly SCRIPT_VERSION="1.0.5"
readonly GITHUB_DIR="$HOME/Documents/GitHub"
readonly LOG_FILE="$HOME/.local/log/git_sync.log"
readonly LOG_MAX_BYTES=512000   # 500 KB

GIT=$(command -v git)
VERBOSE=false
[[ "${1}" == "--verbose" ]] && VERBOSE=true

# ── logging ──────────────────────────────────────────────────────────────────

mkdir -p "$(dirname "$LOG_FILE")"

log() {
  local level="$1"; shift
  local msg="$*"
  local ts
  ts=$(date '+%Y-%m-%d %H:%M:%S')
  echo "[$ts] [$level] $msg" >> "$LOG_FILE"
  echo "[$level] $msg"
}

rotate_log() {
  if [[ -f "$LOG_FILE" ]] && (( $(stat -c%s "$LOG_FILE" 2>/dev/null || echo 0) > LOG_MAX_BYTES )); then
    mv "$LOG_FILE" "${LOG_FILE}.1"
  fi
}

# ── repo helpers ──────────────────────────────────────────────────────────────

# Return the name of the first configured remote, or empty string.
remote_name() {
  "$GIT" -C "$1" remote 2>/dev/null | head -1
}

# Return the upstream tracking ref for HEAD, e.g. "origin/main", or empty.
upstream() {
  "$GIT" -C "$1" rev-parse --abbrev-ref --symbolic-full-name '@{u}' 2>/dev/null
}

# Return number of commits local branch is behind its upstream.
commits_behind() {
  "$GIT" -C "$1" rev-list --count HEAD..@{u} 2>/dev/null
}

# True if the working tree has uncommitted changes (tracked files only).
has_local_changes() {
  ! "$GIT" -C "$1" diff --quiet HEAD 2>/dev/null
}

# ── main ──────────────────────────────────────────────────────────────────────

rotate_log
log INFO "=== git_sync started (v${SCRIPT_VERSION}) ==="

pulled=0
skipped=0
errors=0

for repo_dir in "$GITHUB_DIR"/*/; do
  repo_dir="${repo_dir%/}"
  log INFO "checking $repo_dir"

  if [[ ! -d "$repo_dir/.git" ]]; then
    log INFO "$(basename "$repo_dir"): not a git repo — skipping"
    continue
  fi

  repo=$(basename "$repo_dir")

  # Must have a remote configured
  log INFO "$repo: looking for remote"
  remote=$(remote_name "$repo_dir")
  if [[ -z "$remote" ]]; then
    log INFO "$repo: no remote — skipping"
    (( skipped++ ))
    continue
  fi
  log INFO "$repo: remote is '$remote'"

  # Fetch quietly; log and skip if it fails (network/auth issues)
  log INFO "$repo: fetching from $remote"
  fetch_out=$("$GIT" -C "$repo_dir" fetch "$remote" 2>&1)
  fetch_rc=$?
  if (( fetch_rc != 0 )); then
    log WARN "$repo: fetch failed — ${fetch_out//[$'\n']/ }"
    (( errors++ ))
    continue
  fi
  log INFO "$repo: fetch OK"

  # Must have a tracking upstream to compare against
  log INFO "$repo: resolving upstream tracking branch"
  up=$(upstream "$repo_dir")
  if [[ -z "$up" ]]; then
    log INFO "$repo: no upstream tracking branch — skipping"
    (( skipped++ ))
    continue
  fi
  log INFO "$repo: upstream is '$up'"

  log INFO "$repo: counting commits behind $up"
  behind=$(commits_behind "$repo_dir")
  if [[ -z "$behind" || "$behind" -eq 0 ]]; then
    log INFO "$repo: up to date"
    continue
  fi
  log INFO "$repo: $behind commit(s) behind"

  # Don't pull over local changes
  log INFO "$repo: checking for local changes"
  if has_local_changes "$repo_dir"; then
    log WARN "$repo: $behind commit(s) behind $up but has local changes — skipping"
    (( skipped++ ))
    continue
  fi
  log INFO "$repo: working tree clean"

  # Pull
  log INFO "$repo: pulling"
  pull_out=$("$GIT" -C "$repo_dir" pull 2>&1)
  pull_rc=$?
  if (( pull_rc == 0 )); then
    log INFO "$repo: pulled OK"
    (( pulled++ ))
    if [[ "$repo" == "agora_na_copa_2026" ]]; then
      prod_deploy="$repo_dir/copa_2026/prod_deploy.sh"
      if [[ -x "$prod_deploy" ]]; then
        log INFO "$repo: running $prod_deploy"
        bash "$prod_deploy" 2>&1 | while IFS= read -r line; do log INFO "$repo/prod_deploy: $line"; done
      else
        log WARN "$repo: $prod_deploy not found or not executable — skipping"
      fi
      local_sync="$repo_dir/scripts/git_sync.sh"
      if [[ -x "$local_sync" ]]; then
        log INFO "$repo: running $local_sync"
        bash "$local_sync" 2>&1 | while IFS= read -r line; do log INFO "$repo/git_sync: $line"; done
      else
        log WARN "$repo: $local_sync not found or not executable — skipping"
      fi
    fi
    if [[ "$repo" == "mpbarbosa.com" ]]; then
      prod_deploy="$repo_dir/copa_2026/prod_deploy.sh"
      if [[ -x "$prod_deploy" ]]; then
        log INFO "$repo: running $prod_deploy"
        bash "$prod_deploy" 2>&1 | while IFS= read -r line; do log INFO "$repo/prod_deploy: $line"; done
      else
        log WARN "$repo: $prod_deploy not found or not executable — skipping"
      fi
    fi
  else
    log ERROR "$repo: pull failed — ${pull_out//[$'\n']/ }"
    (( errors++ ))
  fi
done

log INFO "=== git_sync done: pulled=$pulled skipped=$skipped errors=$errors ==="
