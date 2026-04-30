#!/bin/bash
set -euo pipefail
CONFIG_FILE="/config/settings.json"
LOG_DIR="${LOG_DIR:-/output/logs}"
mkdir -p "$LOG_DIR"

while true; do
    now=$(date +%s)
    target=$(date -d "03:00" +%s 2>/dev/null || date -d "03:00" +%s)
    if [ $target -le $now ]; then
        target=$(date -d "tomorrow 03:00" +%s)
    fi
    sleep_seconds=$(( target - now ))
    echo "[scheduler] Sleeping $sleep_seconds seconds until 3:00 AM..."
    sleep $sleep_seconds

    echo "[scheduler] Running scheduled EPG build at $(date)"
    /app/run-multi.sh
    echo "[scheduler] Scheduled run completed at $(date)"
done
