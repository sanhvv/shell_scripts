#!/bin/bash

# 1. Configuration
TARGET_FOLDER="/var/log/xsights/capture_cpu_mem_disk"
LOG_FILE="$TARGET_FOLDER/cpu_mem_disk.csv"
mkdir -p "$TARGET_FOLDER"

# 2. Add Header if file is new
if [ ! -f "$LOG_FILE" ]; then
    echo "Timestamp;CPU_Usage_%;Mem_Used_MB;Mem_Total_MB;Disk_Used_%;Disk_Free_GB" > "$LOG_FILE"
fi

# 3. Capture Metrics
TIMESTAMP=$(date +"%Y-%m-%d %H:%M:%S")

# CPU: Get idle time from top and subtract from 100
CPU_USAGE=$(top -bn1 | grep "Cpu(s)" | awk '{print 100 - $8}')

# Memory: Extract used and total in MB
MEM_INFO=$(free -m | awk 'NR==2{printf "%s;%s", $3, $2}')

# Disk: Extract usage % and free space for the Root (/) partition
DISK_INFO=$(df -h / | awk 'NR==2{printf "%s;%s", $5, $4}')

# 4. Save to CSV
echo "$TIMESTAMP;$CPU_USAGE;$MEM_INFO;$DISK_INFO" >> "$LOG_FILE"
