#!/bin/bash
set -e

echo "[start] ========================================="
echo "[start] Starting TVGuide"
echo "[start] ========================================="

# Ensure directories exist
mkdir -p /config /output/logs /data

# Start scheduler in background
echo "[start] Starting scheduler (runs at 3:00 AM daily)..."
/app/scheduler.sh &

# Start Flask web UI (keeps container running)
echo "[start] Starting Web UI on port ${WEBUI_PORT:-5000}..."
exec python -u /app/app.py