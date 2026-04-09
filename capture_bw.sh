#!/bin/bash

# 1. Define the folder and ensure it exists
TARGET_FOLDER="/var/log/xsights/capture_bandwidth"
mkdir -p "$TARGET_FOLDER"

# 2. Define the timestamp (Year-Month-Day_Hour-Minute)
TIMESTAMP=$(date +"%Y-%m-%d_%H-%M")

# 3. Define the full path for the new file
FILENAME="$TARGET_FOLDER/traffic_history.csv"

# 4. Add header if file is new
if [ ! -f "$FILENAME" ]; then
    echo "Entry_Time;API;IFACE;Date;RX_Day;TX_Day;Total_Day;Avg_Day;Month;RX_Month;TX_Month;Total_Month;Avg_Month;RX_All;TX_All;Total_All" > "$FILENAME"
fi
# 5. Extract data save to the file
echo -n "$(date +"%Y-%m-%d %H:%M:%S");" >> "$FILENAME"
vnstat -d -i eno2.2010 --oneline  >> "$FILENAME"

