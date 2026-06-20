#!/bin/bash
set -e

cd ~/Documents/GitHub/mpbarbosa_site
cd ../mpbarbosa.com && git pull && cd ../mpbarbosa_site
./shell_scripts/sync_to_staging.sh --step2 --production-dir "/var/www/mpbarbosa.com"
