#!/usr/bin/env bash
# Runs claude auth login, captures the OAuth URL, and saves it to a file.
# Each run generates a new unique URL (single-use OAuth PKCE flow).

set -euo pipefail

CLAUDE_BIN="${CLAUDE_BIN:-$(which claude)}"
OUTPUT_FILE="${1:-claude_login_url.txt}"
SCRIPT_TMP=$(mktemp)

trap 'rm -f "$SCRIPT_TMP"' EXIT

script -q -c "$CLAUDE_BIN auth login" "$SCRIPT_TMP" &
SCRIPT_PID=$!

# Wait for the URL to appear (up to 10s)
for i in $(seq 1 20); do
  sleep 0.5
  if grep -qaP 'https://claude\.com/cai/oauth/authorize' "$SCRIPT_TMP" 2>/dev/null; then
    break
  fi
done

kill "$SCRIPT_PID" 2>/dev/null
wait "$SCRIPT_PID" 2>/dev/null || true

URL=$(python3 - "$SCRIPT_TMP" << 'PYEOF'
import re, sys
raw = open(sys.argv[1], 'rb').read().decode('utf-8', errors='replace')
urls = re.findall(r'https://claude\.com/cai/oauth/authorize\?[^\s\x1b\]]+', raw)
print(urls[0] if urls else '')
PYEOF
)

if [[ -z "$URL" ]]; then
  echo "ERROR: could not extract login URL" >&2
  exit 1
fi

echo "$URL" > "$OUTPUT_FILE"
echo "Saved to: $OUTPUT_FILE"
echo "$URL"
