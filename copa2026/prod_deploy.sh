#!/bin/bash
set -e

GITHUB_DIR="$HOME/Documents/GitHub"

echo "prod_deploy: pulling mpbarbosa.com"
git -C "$GITHUB_DIR/mpbarbosa.com" pull origin main

echo "prod_deploy: running sync_to_staging --step2"
"$GITHUB_DIR/mpbarbosa_site/shell_scripts/sync_to_staging.sh" --step2 --production-dir "/var/www/mpbarbosa.com"
