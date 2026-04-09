#!/bin/bash

# --- AUTOMATIC PATH DETECTION ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# --- CONFIGURATION ---
HOST_FILE="$SCRIPT_DIR/edgepc_hosts.txt"
THRESHOLD=10                         

CYCLES=20
LOG_BASE="/var/log/mtr"                  
PROM_DIR="/var/lib/node_exporter/textfile_collector/"    
# Path fixed with underscores
LOG_RUN="/var/log/mtr/mtr_run_logs.log"
MTR_CMD="/usr/bin/mtr"
HOSTNAME=$(hostname)


# --- FUNCTION TO CHECK INDIVIDUAL HOST ---
run_check() {
    local name=$1   
    local ip=$2     
    
    # Capture MTR output into the variable
    # Removed the '>> $LOG_RUN' from here to keep the variable clean
    local MTR_FULL
    MTR_FULL=$("$MTR_CMD" -rn -c "$CYCLES" "$ip")
    
    # Extract metrics from the last line
    local RESULT=$(echo "$MTR_FULL" | tail -n 1)
    
    # Parse metrics with safety fallbacks to avoid bc errors
    # MTR output format: hop IP Loss% Snt Last Avg Best Wrst StDev
    local LOSS=$(echo "$RESULT" | awk '{print $3}' | sed 's/%//' | grep -E '^[0-9.]+$' || echo "100")
    local LAST=$(echo "$RESULT" | awk '{print $5}' | grep -E '^[0-9.]+$' || echo "0")
    local AVG=$(echo "$RESULT" | awk '{print $6}' | grep -E '^[0-9.]+$' || echo "0")
    local BEST=$(echo "$RESULT" | awk '{print $7}' | grep -E '^[0-9.]+$' || echo "0")
    local WRST=$(echo "$RESULT" | awk '{print $8}' | grep -E '^[0-9.]+$' || echo "0")
    local STDDEV=$(echo "$RESULT" | awk '{print $9}' | grep -E '^[0-9.]+$' || echo "0")
    local HOP_IP=$(echo "$RESULT" | awk '{print $2}' | sed 's/^[0-9]*\.--[[:space:]]*//')
    local HOP_NUM=$(echo "$RESULT" | awk '{print $1}')

    if [[ -z "$LOSS" ]]; then LOSS=100; LAST=0; AVG=0; BEST=0; WRST=0; STDDEV=0; fi

    # --- ALWAYS WRITE PROMETHEUS FORMAT FILE (for Prometheus scraping) ---
    local PROM_FILENAME="mtr_${name}_${ip}.prom"
    local PROM_CONTENT="# HELP mtr_loss_percent Packet loss percentage to destination
# TYPE mtr_loss_percent gauge
mtr_loss_percent{hostname=\"$HOSTNAME\",destination=\"$name\",target_ip=\"$ip\"} $LOSS

# HELP mtr_latency_last_ms Last latency measurement to destination in milliseconds
# TYPE mtr_latency_last_ms gauge
mtr_latency_last_ms{hostname=\"$HOSTNAME\",destination=\"$name\",target_ip=\"$ip\"} $LAST

# HELP mtr_latency_avg_ms Average latency to destination in milliseconds
# TYPE mtr_latency_avg_ms gauge
mtr_latency_avg_ms{hostname=\"$HOSTNAME\",destination=\"$name\",target_ip=\"$ip\"} $AVG

# HELP mtr_latency_best_ms Best (minimum) latency to destination in milliseconds
# TYPE mtr_latency_best_ms gauge
mtr_latency_best_ms{hostname=\"$HOSTNAME\",destination=\"$name\",target_ip=\"$ip\"} $BEST

# HELP mtr_latency_worst_ms Worst (maximum) latency to destination in milliseconds
# TYPE mtr_latency_worst_ms gauge
mtr_latency_worst_ms{hostname=\"$HOSTNAME\",destination=\"$name\",target_ip=\"$ip\"} $WRST

# HELP mtr_stddev_ms Standard dseviation of latency to destination in milliseconds
# TYPE mtr_stddev_ms gauge
mtr_stddev_ms{hostname=\"$HOSTNAME\",destination=\"$name\",target_ip=\"$ip\"} $STDDEV
"
    echo "$PROM_CONTENT" | sudo tee "$PROM_DIR/$PROM_FILENAME" > /dev/null

    # --- CONDITIONAL: LOG RAW MTR OUTPUT (BASED ON THRESHOLD) ---
    if (( ${LOSS%.*} > THRESHOLD )); then
        local DATETIME=$(date '+%Y %m %d %H %Y%m%d-%H%M%S')
        local Y=$(echo "$DATETIME" | awk '{print $1}')
        local M=$(echo "$DATETIME" | awk '{print $2}')
        local D=$(echo "$DATETIME" | awk '{print $3}')
        local H=$(echo "$DATETIME" | awk '{print $4}')
        local TS=$(echo "$DATETIME" | awk '{print $5}')

        local TARGET_DIR="$LOG_BASE/$Y/$M/$D/$H"
        sudo mkdir -p "$TARGET_DIR"

        # Save raw MTR output (only when LOSS > THRESHOLD)
        local FILENAME="${name}_${TS}.txt"
        echo "$MTR_FULL" | sudo tee "$TARGET_DIR/$FILENAME" > /dev/null
    fi
}

# --- MAIN EXECUTION ---
# Path fixed for new EdgePC
sudo mkdir -p "$LOG_BASE"
sudo chown -R $USER:$USER "$LOG_BASE"
# Create prometheus format directory once
sudo mkdir -p "$PROM_DIR"

# Print Date and Start Header ONCE per script run
sudo tee -a "$LOG_RUN" <<< "------------------------------------------" > /dev/null
sudo tee -a "$LOG_RUN" <<< "Script Execution Start: $(date '+%Y-%m-%d %H:%M:%S')" > /dev/null

# Validate if the host file exists
if [[ ! -f "$HOST_FILE" ]]; then
    sudo tee -a "$LOG_RUN" <<< "[$(date '+%H:%M:%S')] Error: Host file not found at $HOST_FILE" > /dev/null
    exit 1
fi

# Read file line by line
declare -a pids
while read -r name ip || [[ -n "$name" ]]; do
    [[ -z "$name" || "$name" =~ ^# || -z "$ip" ]] && continue
    
    # Run in background and track PID
    run_check "$name" "$ip" &
    pids+=("$!")
done < "$HOST_FILE"

# Wait for all background tasks and check for errors
failed=0
for pid in "${pids[@]}"; do
    if ! wait "$pid"; then
        ((failed++))
    fi
done

if [[ $failed -gt 0 ]]; then
    sudo tee -a "$LOG_RUN" <<< "Warning: $failed background job(s) failed" > /dev/null
fi

sudo tee -a "$LOG_RUN" <<< "Script Execution Finished: $(date '+%Y-%m-%d %H:%M:%S')" > /dev/null
