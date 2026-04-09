# MTR Monitoring Script for EdgePC

A Bash automation script that monitors network connectivity to multiple hosts using `mtr` (My Traceroute) and exports metrics in Prometheus format for monitoring infrastructure.

## Overview

This script performs continuous network path analysis to specified hosts, capturing latency and packet loss metrics. It integrates with Prometheus for time-series monitoring and creates detailed logs when network issues are detected.

## Features

- **Multi-host Monitoring**: Monitor multiple destinations simultaneously
- **Prometheus Integration**: Exports metrics in Prometheus text file collector format
- **Packet Loss Detection**: Conditional logging when packet loss exceeds threshold
- **Parallel Execution**: Runs checks in background for improved performance
- **Automatic Path Detection**: Script-relative configuration file loading
- **Detailed Metrics**: Captures loss %, latency (last/avg/best/worst), and standard deviation
- **Hierarchical Logging**: Organized by date/time for efficient data management
- **Error Handling**: Validates configuration and tracks failed jobs

## Requirements

### System Requirements
- Linux/Unix environment
- Bash shell
- `mtr` command-line tool installed
- `sudo` privileges for directory and log file operations
- Node Exporter with textfile collector configured

### Prerequisites
```bash
# Install mtr
sudo apt-get install mtr  # Debian/Ubuntu
sudo yum install mtr      # RHEL/CentOS

# Install Node Exporter (if not already installed)
# Follow Node Exporter documentation for your distribution
```

## Installation

### 1. Create Project Directory
```bash
mkdir -p ~/shell_scripts/mtr_monitoring
cd ~/shell_scripts/mtr_monitoring
```

### 2. Place Script Files
Copy the following files to the directory:
- `mtr_monitoring_edgepc.sh` - Main monitoring script
- `edgepc_hosts.txt` - Target hosts configuration

### 3. Make Script Executable
```bash
chmod +x mtr_monitoring_edgepc.sh
```

### 4. Configure Node Exporter

Create textfile collector directory:
```bash
sudo mkdir -p /var/lib/node_exporter/textfile_collector
```

Update `docker-compose.yml` in `~/xlm_monitoring`:
```yaml
node-exporter:
  command:
    - "--collector.textfile.directory=/textfile_collector"
  volumes:
    - "/var/lib/node_exporter/textfile_collector:/textfile_collector:ro"
```

Restart Node Exporter:
```bash
docker compose -f ~/xlm_monitoring/docker-compose.yml up -d --no-deps node-exporter
```

### 5. Create Log Directory
```bash
sudo mkdir -p /var/log/mtr
sudo chown -R $USER:$USER /var/log/mtr
```

## Configuration

### Host Configuration File: `edgepc_hosts.txt`

Format: `HOSTNAME IP_ADDRESS` (space-separated)

Example:
```
xhq                 211.27.196.175
google-dns          8.8.8.8
cloudflare-dns      1.1.1.1
corporate-gateway   10.0.0.1
```

**Rules**:
- One host per line
- Format: `<name> <ip_address>`
- Blank lines and comments (lines starting with `#`) are ignored
- Name and IP must be space-separated

### Script Parameters

Edit the following variables at the top of the script:

```bash
HOST_FILE="$SCRIPT_DIR/edgepc_hosts.txt"    # Path to hosts configuration
THRESHOLD=10                                 # Packet loss % threshold for logging
CYCLES=20                                   # Number of MTR probe cycles per host
LOG_BASE="/var/log/mtr"                     # Base directory for detailed logs
PROM_DIR="/var/lib/node_exporter/textfile_collector/"  # Prometheus metrics output
LOG_RUN="/var/log/mtr/mtr_run_logs.log"     # Script execution log
MTR_CMD="/usr/bin/mtr"                      # Path to MTR executable
```

## Usage

### Manual Execution
```bash
# Run once
./mtr_monitoring_edgepc.sh

# Run with explicit sudo if needed
sudo ./mtr_monitoring_edgepc.sh
```

### Automated Execution with Cron

Add to crontab to run every minute:
```bash
crontab -e
```

Add this line:
```cron
* * * * * /home/xsights/shell_scripts/mtr_monitoring/mtr_monitoring_edgepc.sh >> /var/log/xsights/cron_mtr_monitoring_edgepc.log 2>&1
```

**Common Cron Patterns**:
- `* * * * *` - Every minute
- `*/5 * * * *` - Every 5 minutes
- `0 * * * *` - Every hour
- `0 0 * * *` - Daily

## Output

### Prometheus Metrics Files

Generated in `/var/lib/node_exporter/textfile_collector/`

Filename: `mtr_<hostname>_<ip>.prom`

Example content:
```prometheus
# HELP mtr_loss_percent Packet loss percentage to destination
# TYPE mtr_loss_percent gauge
mtr_loss_percent{hostname="edgepc",destination="xhq",target_ip="211.27.196.175"} 0

# HELP mtr_latency_last_ms Last latency measurement to destination in milliseconds
# TYPE mtr_latency_last_ms gauge
mtr_latency_last_ms{hostname="edgepc",destination="xhq",target_ip="211.27.196.175"} 45.5

# HELP mtr_latency_avg_ms Average latency to destination in milliseconds
# TYPE mtr_latency_avg_ms gauge
mtr_latency_avg_ms{hostname="edgepc",destination="xhq",target_ip="211.27.196.175"} 42.3
```

### Detailed Logs

Generated when packet loss exceeds `THRESHOLD`

Location: `/var/log/mtr/YYYY/MM/DD/HH/`

Filename: `<hostname>_<timestamp>.txt`

Example:
```
/var/log/mtr/2024/04/09/14/xhq_20240409-142530.txt
```

### Execution Log

Location: `/var/log/mtr/mtr_run_logs.log`

Contents:
```
------------------------------------------
Script Execution Start: 2024-04-09 14:25:30
Warning: 0 background job(s) failed
Script Execution Finished: 2024-04-09 14:25:45
```

## Metrics Exported

### Prometheus Metrics (Always)
Each host generates the following metrics:

| Metric | Description | Unit |
|--------|-------------|------|
| `mtr_loss_percent` | Packet loss percentage | % |
| `mtr_latency_last_ms` | Most recent latency measurement | ms |
| `mtr_latency_avg_ms` | Average latency over all probes | ms |
| `mtr_latency_best_ms` | Minimum latency recorded | ms |
| `mtr_latency_worst_ms` | Maximum latency recorded | ms |
| `mtr_stddev_ms` | Standard deviation of latency | ms |

### Labels
All metrics include labels:
- `hostname`: Source machine hostname
- `destination`: Friendly name from `edgepc_hosts.txt`
- `target_ip`: Target IP address

### Raw MTR Output (Conditional)
Raw MTR output is logged only when `LOSS > THRESHOLD`

## How It Works

### Execution Flow

1. **Initialization**
   - Detects script directory automatically
   - Creates required directories with proper permissions
   - Validates that host file exists

2. **Host Processing**
   - Reads each host from `edgepc_hosts.txt`
   - Launches MTR check for each host in background
   - Tracks process IDs for error monitoring

3. **MTR Execution**
   - Runs `mtr -rn -c CYCLES` to each target
   - Extracts raw MTR output
   - Parses metrics from final hop line

4. **Metric Extraction**
   - Packet Loss: `%` column
   - Latency: Last, Average, Best, Worst values
   - Stddev: Standard deviation calculation

5. **Prometheus Export**
   - Generates text file in Prometheus format
   - Always exported regardless of loss
   - Overwrites previous metrics for each host

6. **Conditional Logging**
   - If `LOSS > THRESHOLD`:
     - Creates timestamped directory structure
     - Saves full raw MTR output for investigation

7. **Error Handling**
   - Waits for all background jobs
   - Counts failed jobs and logs warnings
   - Records execution timestamps

## Monitoring with Prometheus

### Add Scrape Configuration

Update your `prometheus.yml`:
```yaml
scrape_configs:
  - job_name: 'node'
    static_configs:
      - targets: ['localhost:9100']
```

Node Exporter automatically discovers textfile collector metrics.

### Prometheus Queries

```promql
# Current packet loss to all destinations
mtr_loss_percent

# Average latency to specific destination
mtr_latency_avg_ms{destination="xhq"}

# Alert on high packet loss
mtr_loss_percent > 5

# Alert on high latency
mtr_latency_avg_ms > 100

# Compare latencies across all destinations
avg by (destination) (mtr_latency_avg_ms)
```

### Grafana Dashboard

Create dashboard panels using the exported metrics:
- **Panel 1**: Loss Percentage (gauge or timeseries)
- **Panel 2**: Average Latency (timeseries)
- **Panel 3**: Best/Worst Latency comparison
- **Panel 4**: Packet Loss alerts (stat panel)

## Troubleshooting

| Issue | Solution |
|-------|----------|
| **Script fails with "Host file not found"** | Ensure `edgepc_hosts.txt` is in same directory as script |
| **Permission denied on log files** | Run with `sudo` or check directory ownership |
| **MTR command not found** | Install mtr: `sudo apt-get install mtr` |
| **Prometheus not scraping metrics** | Verify `PROM_DIR` path and Node Exporter config |
| **No metrics appearing in Prometheus** | Check textfile collector directory permissions |
| **Blank/invalid metric values** | Check MTR output format; may need to adjust parsing |
| **Cron job not running** | Check cron logs: `grep CRON /var/log/syslog` |
| **Background jobs failing** | Run script manually to see error messages |

## Log Locations

```
/var/log/mtr/
├── mtr_run_logs.log              # Script execution log
├── 2024/04/09/14/
│   ├── xhq_20240409-142530.txt   # Raw MTR output (when LOSS > THRESHOLD)
│   └── ...
└── ...

/var/log/xsights/
└── cron_mtr_monitoring_edgepc.log  # Cron execution log
```

## Performance Considerations

- **CYCLES**: More cycles = more accurate metrics but slower execution
  - Recommended: 20-30 cycles
  - Minimum: 10 cycles
  - Trade-off: Accuracy vs speed

- **THRESHOLD**: Controls logging overhead
  - Higher threshold = less logging but may miss issues
  - Lower threshold = more logging but uses more disk

- **Parallel Execution**: Significantly reduces total runtime
  - Benefits increase with more hosts
  - Monitor system load if running on many hosts

## Security Considerations

1. **File Permissions**: Script uses `sudo` for sensitive directories
2. **Credential Protection**: No credentials stored in script
3. **Log Access**: Logs contain network information; restrict access appropriately
4. **Host File**: Contains target IP addresses; secure accordingly

## Advanced Configuration

### Custom MTR Parameters

Modify the `MTR_CMD` line in script:
```bash
MTR_CMD="/usr/bin/mtr"
# Add custom parameters:
# MTR_CMD="/usr/bin/mtr --aslookup --report"
```

### Custom Metric Labels

Modify `PROM_CONTENT` in the `run_check()` function to add additional labels

### Log Retention Policy

Implement log rotation:
```bash
# Create /etc/logrotate.d/mtr
/var/log/mtr/*.log {
    daily
    rotate 30
    compress
    delaycompress
    missingok
    notifempty
}
```

## Dependencies Summary

```
mtr                    # Network diagnostic tool
bash                   # Shell interpreter
Node Exporter          # Metrics collection
Prometheus             # Metrics storage (optional)
Grafana                # Visualization (optional)
```

## Version History

- **v1.0** (2024-04): Initial release with multi-host support
  - Prometheus integration
  - Conditional detailed logging
  - Parallel execution
  - Error tracking

## Support & Documentation

For additional information:
- MTR documentation: `man mtr`
- Prometheus textfile collector: https://github.com/prometheus/node_exporter#textfile-collector
- Node Exporter setup: https://prometheus.io/docs/guides/node-exporter/

## License

This script is part of the automation infrastructure for network monitoring.

---

**Last Updated**: April 2024
**Location**: `/home/xsights/shell_scripts/mtr_monitoring/`
