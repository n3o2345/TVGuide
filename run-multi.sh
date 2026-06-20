#!/bin/bash
set -euo pipefail

CONFIG_FILE="/config/settings.json"
LOG_DIR="${LOG_DIR:-/output/logs}"
mkdir -p "$LOG_DIR"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
LOGFILE="$LOG_DIR/run_$TIMESTAMP.log"

# Get host timezone if available, default to UTC
HOST_TZ="${HOST_TZ:-UTC}"

exec > >(tee -a "$LOGFILE") 2>&1

if test ! -f "$CONFIG_FILE"; then
  echo "[run-multi] ERROR: config file not found: $CONFIG_FILE"
  exit 1
fi

# Normalize lineups/zipcodes: handle JSON array or plain CSV string
LINEUPS=$(jq -r 'if .lineups | type == "array" then .lineups | join(",") else .lineups end' "$CONFIG_FILE")
ZIPCODES=$(jq -r '
  if .zipcodes | type == "array" then
    [ .zipcodes[] | if type == "object" then .zip else . end ] | join(",")
  else .zipcodes end
' "$CONFIG_FILE")
COUNTRY=$(jq -r '.country' "$CONFIG_FILE")
TIMESPAN=$(jq -r '.timespan' "$CONFIG_FILE")
VERBOSE=$(jq -r '.verbose' "$CONFIG_FILE")
OUTPUT_BASE=$(jq -r '.output_dir' "$CONFIG_FILE")

if test -z "$OUTPUT_BASE"; then
  OUTPUT_BASE="/output"
fi

get_time() {
    if command -v timedatectl &> /dev/null; then
        timedatectl show --property=Timezone --value 2>/dev/null || date
    else
        date
    fi
}

# Clear any stale zap2xml locks left by a previously crashed/killed run
ZAP_LOCK_DIR="/tmp/zap2xml.lock.d"
ZAP_LOCK_FILE="/tmp/zap2xml.run.lock"
if [ -d "$ZAP_LOCK_DIR" ]; then
  echo "[run-multi] Removing stale lock dir: $ZAP_LOCK_DIR"
  rm -rf "$ZAP_LOCK_DIR"
fi
if [ -f "$ZAP_LOCK_FILE" ]; then
  echo "[run-multi] Removing stale lock file: $ZAP_LOCK_FILE"
  rm -f "$ZAP_LOCK_FILE"
fi

echo "[run-multi] Starting EPG build at $(date '+%a %b %d %H:%M:%S %Z %Y')"
echo "[run-multi] Lineups: $LINEUPS"
echo "[run-multi] ZIPs: $ZIPCODES"
echo "[run-multi] Country: $COUNTRY"
echo "[run-multi] Timespan: $TIMESPAN"
echo "[run-multi] Output: $OUTPUT_BASE"

IFS=',' read -ra LINEUP_LIST <<< "$LINEUPS"
IFS=',' read -ra ZIP_LIST <<< "$ZIPCODES"

TEMP_DIR=$(mktemp -d /tmp/xmltv_parts.XXXXXX)
mkdir -p "$TEMP_DIR"
OUTFILES=()

zip_idx=0

for lineup_raw in "${LINEUP_LIST[@]}"; do
    lineup=$(echo "$lineup_raw" | xargs)
    zip=""
    
    if echo "$lineup" | grep -qi "OTA"; then
        # For OTA lineups, try to get corresponding ZIP code
        if test "$zip_idx" -lt "${#ZIP_LIST[@]}"; then
            zip=$(echo "${ZIP_LIST[$zip_idx]}" | xargs)
        fi
        
        if test -z "$zip"; then
            echo "[run-multi] WARNING: OTA lineup '$lineup' has no ZIP code, skipping"
            zip_idx=$((zip_idx + 1))
            continue
        fi
        
        zip_idx=$((zip_idx + 1))
    fi

    outfile="$TEMP_DIR/part_${#OUTFILES[@]}.xml"
    echo "[run-multi] Fetching lineup: $lineup (ZIP: ${zip:-none}) -> $outfile"
    
    if test -n "$zip"; then
        python3 /app/zap2xml.py --lineupId="$lineup" -c "$COUNTRY" -z "$zip" --timespan="$TIMESPAN" --output="$outfile" -v "$VERBOSE" 2>&1 || {
            echo "[run-multi] WARNING: Failed to fetch $lineup, skipping"
            continue
        }
    else
        python3 /app/zap2xml.py --lineupId="$lineup" -c "$COUNTRY" --timespan="$TIMESPAN" --output="$outfile" -v "$VERBOSE" 2>&1 || {
            echo "[run-multi] WARNING: Failed to fetch $lineup, skipping"
            continue
        }
    fi
    
    OUTFILES+=("$outfile")
done

if test ${#OUTFILES[@]} -eq 0; then
  echo "[run-multi] ERROR: No lineups were successfully fetched"
  rm -rf "$TEMP_DIR"
  exit 1
fi

mkdir -p "$OUTPUT_BASE"
MERGED="$OUTPUT_BASE/xmltv.xml"

echo "[run-multi] Merging ${#OUTFILES[@]} XML files..."
python3 /app/merge_xmltv.py "$MERGED" "${OUTFILES[@]}"

rm -rf "$TEMP_DIR"

SIZE=$(du -h "$MERGED" | cut -f1)
echo "[run-multi] Merged XMLTV written to: $MERGED (size: $SIZE)"
echo "[run-multi] Completed EPG build at $(date '+%a %b %d %H:%M:%S %Z %Y')"
echo "[run-multi] Log saved to $LOGFILE"