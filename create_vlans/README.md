# System Metrics Capture Scripts

A collection of shell scripts for capturing and logging system performance metrics including bandwidth, CPU usage, memory consumption, and disk space.

## Overview

These scripts are designed to collect time-series data on system performance metrics and export them in CSV format for analysis, monitoring, and alerting. Ideal for integration with monitoring dashboards like Prometheus/Grafana or custom analytics.

## Scripts

### 1. capture_bw.sh
Captures network bandwidth statistics using `vnstat`.

**Purpose**: Monitor network interface bandwidth usage (daily, monthly, and cumulative totals)

**Dependencies**:
- `vnstat` - Network traffic monitor
- `date` - Standard utility

**Output**: CSV file with bandwidth metrics

### 2. capture_cpu_mem_disk.sh
Captures CPU, memory, and disk usage metrics using system commands.

**Purpose**: Monitor system resource utilization

**Dependencies**:
- `top` - Process monitor
- `free` - Memory usage reporter
- `df` - Disk space usage reporter
- `date` - Standard utility

**Output**: CSV file with resource metrics

## Installation

### 1. Install Dependencies

**For capture_bw.sh**:
```bash
sudo apt-get update
sudo apt-get install vnstat
# or for other distributions
sudo yum install vnstat
```

**For capture_cpu_mem_disk.sh**:
Most dependencies are pre-installed on Linux systems. Verify:
```bash
which top free df date
```

### 2. Create Script Directory
```bash
mkdir -p ~/shell_scripts
cd ~/shell_scripts
```

### 3. Copy Scripts
Copy both scripts to the directory:
```bash
cp capture_bw.sh capture_cpu_mem_disk.sh ~/shell_scripts/
```

### 4. Make Executable
```bash
chmod +x ~/shell_scripts/capture_bw.sh
chmod +x ~/shell_scripts/capture_cpu_mem_disk.sh
```

### 5. Create Log Directories
```bash
sudo mkdir -p /var/log/xsights/capture_bandwidth
sudo mkdir -p /var/log/xsights/capture_cpu_mem_disk
sudo chown -R $USER:$USER /var/log/xsights/
```

## Usage

### Manual Execution

Run individual scripts:
```bash
# Capture bandwidth
~/shell_scripts/capture_bw.sh

# Capture CPU, Memory, Disk
~/shell_scripts/capture_cpu_mem_disk.sh

# Run both
~/shell_scripts/capture_bw.sh && ~/shell_scripts/capture_cpu_mem_disk.sh
```

### Automated Execution with Cron

Add to crontab for regular collection:
```bash
crontab -e
```

Add these lines (adjust frequency as needed):
```cron
# Capture bandwidth every minute
* * * * * ~/shell_scripts/capture_bw.sh >> /var/log/xsights/cron_capture_bw.log 2>&1

# Capture CPU/Memory/Disk every 5 minutes
*/5 * * * * ~/shell_scripts/capture_cpu_mem_disk.sh >> /var/log/xsights/cron_capture_cpu_mem_disk.log 2>&1
```

### Common Cron Schedules
```cron
* * * * *       # Every minute
*/5 * * * *     # Every 5 minutes
*/15 * * * *    # Every 15 minutes
*/30 * * * *    # Every 30 minutes
0 * * * *       # Every hour
0 0 * * *       # Daily
```

## Configuration

### capture_bw.sh

Edit the following variables:
```bash
TARGET_FOLDER="/var/log/xsights/capture_bandwidth"  # Output directory
FILENAME="$TARGET_FOLDER/traffic_history.csv"        # Output file
# Network interface configuration
vnstat -d -i eno2.2010 --oneline                     # Change interface as needed
```

**Change Network Interface**:
```bash
# Find available interfaces
ip link show

# Update the script to monitor desired interface
vnstat -d -i YOUR_INTERFACE --oneline
```

### capture_cpu_mem_disk.sh

Edit the following variables:
```bash
TARGET_FOLDER="/var/log/xsights/capture_cpu_mem_disk"  # Output directory
LOG_FILE="$TARGET_FOLDER/cpu_mem_disk.csv"              # Output file
# Modify disk monitoring path if needed
df -h /                                                  # Change / to different partition
```

**Change Monitored Disk Partition**:
```bash
# List all partitions
df -h

# Update the script to monitor different partition
df -h /home  # or any other mount point
```

## Output Files

### Bandwidth Output

**File**: `/var/log/xsights/capture_bandwidth/traffic_history.csv`

**Format**:
```
Entry_Time;API;IFACE;Date;RX_Day;TX_Day;Total_Day;Avg_Day;Month;RX_Month;TX_Month;Total_Month;Avg_Month;RX_All;TX_All;Total_All
2024-04-09 14:25:30;1;eno2.2010;09;1.25;2.50;3.75;1.88;04;125.50;250.75;376.25;12.54;1250;2507;3757
```

**Columns**:
| Column | Description |
|--------|-------------|
| Entry_Time | Timestamp of entry |
| API | vnstat version/API info |
| IFACE | Network interface name |
| Date | Day of month |
| RX_Day | Data received today (units: vnstat default) |
| TX_Day | Data transmitted today |
| Total_Day | Total traffic today |
| Avg_Day | Average traffic today |
| Month | Current month |
| RX_Month | Data received this month |
| TX_Month | Data transmitted this month |
| Total_Month | Total traffic this month |
| Avg_Month | Average traffic this month |
| RX_All | Total received (all-time) |
| TX_All | Total transmitted (all-time) |
| Total_All | Total traffic (all-time) |

### System Metrics Output

**File**: `/var/log/xsights/capture_cpu_mem_disk/cpu_mem_disk.csv`

**Format**:
```
Timestamp;CPU_Usage_%;Mem_Used_MB;Mem_Total_MB;Disk_Used_%;Disk_Free_GB
2024-04-09 14:25:30;15.5;4096;8192;65.3;20.5
```

**Columns**:
| Column | Description | Unit |
|--------|-------------|------|
| Timestamp | Time of measurement | YYYY-MM-DD HH:MM:SS |
| CPU_Usage_% | CPU utilization | % (0-100) |
| Mem_Used_MB | Memory currently in use | MB |
| Mem_Total_MB | Total available memory | MB |
| Disk_Used_% | Disk space utilization | % (0-100) |
| Disk_Free_GB | Free disk space | GB |

## Monitoring Integration

### Prometheus Integration

For metrics collection in Prometheus, convert CSV data to metrics using custom exporters or scripts.

Example query format:
```bash
# Parse CPU usage
awk -F';' 'NR>1 {print "cpu_usage{timestamp=\"" $1 "\"} " $2}' /var/log/xsights/capture_cpu_mem_disk/cpu_mem_disk.csv
```

### Grafana Visualization

1. Install Grafana CSV data source plugin
2. Configure data source pointing to CSV files
3. Create visualizations from metrics

**Suggested Panels**:
- CPU Usage over time (line chart)
- Memory utilization (area chart)
- Disk usage (gauge)
- Bandwidth trends (stacked area)

### Custom Analytics

Parse CSV files with standard tools:
```bash
# Get average CPU usage for the day
awk -F';' 'NR>1 {sum+=$2; count++} END {print "Average CPU: " sum/count "%"}' cpu_mem_disk.csv

# Get peak memory usage
awk -F';' 'NR>1 {print $4}' cpu_mem_disk.csv | sort -n | tail -1

# Calculate total bandwidth transferred
awk -F';' 'NR>1 {sum+=$5} END {print "Total transferred: " sum}' traffic_history.csv
```

## Troubleshooting

| Issue | Solution |
|-------|----------|
| **"vnstat: command not found"** | Install vnstat: `sudo apt-get install vnstat` |
| **Permission denied on log files** | Ensure `/var/log/xsights/` exists with proper permissions: `sudo chown -R $USER:$USER /var/log/xsights/` |
| **Cron job not executing** | Check cron logs: `grep CRON /var/log/syslog` |
| **CSV file not created** | Verify target folder exists: `mkdir -p /var/log/xsights/capture_*` |
| **vnstat shows no data** | Run `sudo vnstat -i eno2.2010` to initialize interface tracking |
| **Top command hangs** | Use timeout: `timeout 2 top -bn1` |
| **Disk space shows 0%** | Verify mount point exists: `df -h /` |
| **Memory values incorrect** | Try `free -m` manually to verify output format |

## Performance Considerations

### Bandwidth Capture
- **Overhead**: Minimal (~1-2% CPU)
- **Frequency**: Can run every minute without impact
- **Data Size**: ~500 bytes per entry; ~720KB per day at 1-minute intervals

### System Metrics Capture
- **Overhead**: Minimal (~1-2% CPU per execution)
- **Frequency**: Recommended every 5 minutes to balance accuracy and overhead
- **Data Size**: ~100 bytes per entry; ~28KB per day at 5-minute intervals

### Storage Estimates

**At 1-minute intervals**:
- Bandwidth data: ~15MB per month
- System metrics (5-min): ~1.7MB per month

**Recommendation**: Implement log rotation to manage disk space:

```bash
# Create /etc/logrotate.d/xsights_metrics
/var/log/xsights/capture_bandwidth/traffic_history.csv {
    daily
    rotate 30
    compress
    delaycompress
    missingok
    notifempty
}

/var/log/xsights/capture_cpu_mem_disk/cpu_mem_disk.csv {
    daily
    rotate 30
    compress
    delaycompress
    missingok
    notifempty
}
```

## Data Retention

Implement archival strategy:
```bash
# Archive weekly
0 0 * * 0 tar -czf /var/log/xsights/archive/metrics_$(date +\%Y\%m\%d).tar.gz /var/log/xsights/capture_*/*.csv && rm /var/log/xsights/capture_*/*.csv

# Keep archives for 90 days
find /var/log/xsights/archive -name "*.tar.gz" -mtime +90 -delete
```

## Advanced Usage

### Script Wrapper for Combined Collection

Create a wrapper script `/home/xsights/shell_scripts/collect_all_metrics.sh`:

```bash
#!/bin/bash
# Collect all metrics in one job

~/shell_scripts/capture_bw.sh
~/shell_scripts/capture_cpu_mem_disk.sh

# Optional: Additional metrics
# ~/shell_scripts/capture_io_stats.sh
# ~/shell_scripts/capture_network_stats.sh
```

Then add single cron entry:
```cron
*/5 * * * * ~/shell_scripts/collect_all_metrics.sh >> /var/log/xsights/cron_metrics.log 2>&1
```

### Alerting Based on Metrics

Create alert script for Slack/Email:
```bash
#!/bin/bash
# Check if CPU usage exceeds 80%

LATEST=$(tail -1 /var/log/xsights/capture_cpu_mem_disk/cpu_mem_disk.csv)
CPU=$(echo "$LATEST" | awk -F';' '{print $2}')

if (( $(echo "$CPU > 80" | bc -l) )); then
    echo "Alert: CPU usage is ${CPU}%" | mail -s "System Alert" admin@example.com
fi
```

### Real-time Dashboard

Use `watch` command to monitor in real-time:
```bash
# Watch bandwidth updates
watch -n 5 'tail -5 /var/log/xsights/capture_bandwidth/traffic_history.csv'

# Watch system metrics
watch -n 5 'tail -5 /var/log/xsights/capture_cpu_mem_disk/cpu_mem_disk.csv'
```

## Log Locations

```
/var/log/xsights/
├── capture_bandwidth/
│   └── traffic_history.csv          # Bandwidth data
├── capture_cpu_mem_disk/
│   └── cpu_mem_disk.csv             # System metrics
├── cron_capture_bw.log              # Cron execution log
├── cron_capture_cpu_mem_disk.log    # Cron execution log
└── archive/                         # Archived data
    └── metrics_20240409.tar.gz
```

## Security Considerations

1. **Log File Permissions**: Ensure log directories are readable only by authorized users
2. **Data Retention**: Implement log rotation to prevent disk space issues
3. **Sensitive Data**: Network interface names may be considered sensitive in some environments
4. **Cron Logging**: Redirect cron output to secure location

## Dependencies Summary

```
capture_bw.sh:
  ├── bash
  ├── date
  ├── vnstat
  └── mkdir

capture_cpu_mem_disk.sh:
  ├── bash
  ├── date
  ├── top
  ├── free
  ├── df
  └── awk
```

## Example Integration

### Complete Setup
```bash
# 1. Create directories
sudo mkdir -p /var/log/xsights/{capture_bandwidth,capture_cpu_mem_disk,archive}
sudo chown -R $USER:$USER /var/log/xsights/

# 2. Copy scripts
cp capture_bw.sh capture_cpu_mem_disk.sh ~/shell_scripts/
chmod +x ~/shell_scripts/capture_*.sh

# 3. Add cron jobs
crontab -e
# Add:
# * * * * * ~/shell_scripts/capture_bw.sh >> /var/log/xsights/cron_capture_bw.log 2>&1
# */5 * * * * ~/shell_scripts/capture_cpu_mem_disk.sh >> /var/log/xsights/cron_capture_cpu_mem_disk.log 2>&1

# 4. Verify execution
sleep 60 && tail -5 /var/log/xsights/capture_*/*.csv
```

## Support & References

- vnstat documentation: `man vnstat`
- Linux system commands: `man top`, `man free`, `man df`
- Cron documentation: `man crontab`
- CSV format: RFC 4180

## Version History

- **v1.0** (2024-04): Initial release
  - Bandwidth monitoring via vnstat
  - CPU/Memory/Disk metrics collection
  - CSV export format
  - Cron integration

## Notes

- CSV files use semicolon (`;`) as delimiter for easier parsing in many tools
- Headers are automatically created on first run
- All timestamps are in 24-hour format (HH:MM:SS)
- Disk usage reflects the root (`/`) partition by default

---

**Last Updated**: April 2024
**Location**: `/home/xsights/shell_scripts/`
