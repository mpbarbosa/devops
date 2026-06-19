#!/usr/bin/env bash
set -euo pipefail

CLAUDE_EMAIL="mpbarbosa@gmail.com"
NODE_MAJOR=22

log()  { echo "[$(date '+%H:%M:%S')] $*"; }
ok()   { echo "[$(date '+%H:%M:%S')] ✓ $*"; }
warn() { echo "[$(date '+%H:%M:%S')] ⚠ $*"; }

# ── Node.js ──────────────────────────────────────────────────────────────────

install_node() {
  log "Setting up Node.js ${NODE_MAJOR}..."
  curl -fsSL "https://deb.nodesource.com/setup_${NODE_MAJOR}.x" | sudo -E bash -
  sudo apt-get install -y nodejs
  ok "Node.js $(node --version) installed"
}

if command -v node &>/dev/null; then
  CURRENT_MAJOR=$(node --version | sed 's/v\([0-9]*\).*/\1/')
  if [[ "$CURRENT_MAJOR" -lt "$NODE_MAJOR" ]]; then
    warn "Node.js v${CURRENT_MAJOR} is too old (need ${NODE_MAJOR}+). Upgrading..."
    install_node
  else
    ok "Node.js $(node --version) already installed"
  fi
else
  sudo apt-get update -qq
  install_node
fi

# ── Claude Code CLI ───────────────────────────────────────────────────────────

log "Installing/updating @anthropic-ai/claude-code..."
npm install -g @anthropic-ai/claude-code
ok "Claude Code $(claude --version) ready"

# ── Login ────────────────────────────────────────────────────────────────────

echo
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  LOGIN REQUIRED"
echo "  Account: ${CLAUDE_EMAIL}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo
echo "This is a headless server. Choose one of the options below:"
echo
echo "  OPTION A — Browser login (recommended)"
echo "    Run:  claude login"
echo "    Claude will print a URL. Open it on any device, sign in as"
echo "    ${CLAUDE_EMAIL}, and the token will be saved automatically."
echo
echo "  OPTION B — API key"
echo "    Add to ~/.bashrc (or ~/.zshrc):"
echo "    export ANTHROPIC_API_KEY='sk-ant-...'"
echo "    Then: source ~/.bashrc"
echo
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Attempt login now if running interactively
if [[ -t 0 ]]; then
  echo
  read -rp "Run 'claude login' now? [Y/n] " ANSWER
  ANSWER="${ANSWER:-Y}"
  if [[ "$ANSWER" =~ ^[Yy]$ ]]; then
    claude login
    ok "Login complete. Run 'claude' to start."
  fi
fi
