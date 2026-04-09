# VLAN Creation Script for EdgePC

An interactive Bash script for automated creation and configuration of multiple VLANs on EdgePC using NetworkManager. Simplifies network segmentation and VLAN setup with user-friendly prompts and automatic parent NIC detection.

## Overview

This script automates the creation of VLANs (Virtual Local Area Networks) for network segmentation on EdgePC. It detects available physical network interfaces, allows user selection, and guides through the creation of predefined VLANs with specific IP addressing and DNS configurations.

## Features

- **Automatic NIC Detection**: Identifies all physical network interfaces
- **Smart Default Selection**: Detects active interfaces and default route NIC
- **Interactive Prompts**: User confirms each step before execution
- **Error Prevention**: Validates NIC selection before proceeding
- **Flexible Configuration**: Per-VLAN confirmation for selective creation
- **NetworkManager Integration**: Uses `nmcli` for robust connection management
- **Autoconnect Support**: VLANs automatically connect when parent interface is active
- **Route Metrics**: Configurable routing priority for each VLAN
- **DNS Management**: Per-VLAN DNS servers and search domains

## Requirements

### System Requirements
- Linux system with NetworkManager installed
- Bash shell
- sudo privileges (for network configuration)
- Physical network interface(s)

### Dependencies
```bash
# Check if NetworkManager is installed
nmcli --version

# Check if nmcli is available
which nmcli
```

### Install NetworkManager (if needed)
```bash
# Debian/Ubuntu
sudo apt-get update
sudo apt-get install network-manager

# RHEL/CentOS
sudo yum install NetworkManager

# Fedora
sudo dnf install NetworkManager
```

## Installation

### 1. Copy Script
```bash
cp create_vlans.sh ~/shell_scripts/
chmod +x ~/shell_scripts/create_vlans.sh
```

### 2. Verify Prerequisites
```bash
# Check NetworkManager status
sudo systemctl status NetworkManager

# Ensure it's running
sudo systemctl start NetworkManager
sudo systemctl enable NetworkManager
```

### 3. Verify Physical NICs
```bash
# List all network interfaces
ip link show

# Check interface status
ip link
```

## Usage

### Basic Execution
```bash
./create_vlans.sh
```

### Execution with Explicit Path
```bash
~/shell_scripts/create_vlans.sh
```

### With sudo (if required)
```bash
sudo ~/shell_scripts/create_vlans.sh
```

## Script Workflow

### Step 1: Initial Confirmation
Script displays important warnings and asks for user confirmation to proceed.

```
This script will create all VLANs for the EdgePC
...
OKAY to proceed with the script? (y/N): y
```

### Step 2: Physical NIC Detection
Script automatically:
- Detects all physical NICs (eth*, en*, eno*, enp*)
- Identifies active NICs
- Determines default route NIC
- Displays NIC list with default marked

```
Detected physical NICs:
  * eno1 (default)
    eno2
    eno3
```

### Step 3: Parent NIC Selection
User selects which physical NIC to use as parent for VLANs.

```
Enter NIC to use for VLANs [default: eno1]: eno2
Using parent NIC: eno2
Okay to proceed with this parent NIC? (y/N): y
```

### Step 4: VLAN Creation Loop
For each predefined VLAN:
- Displays pending configuration
- Prompts user for confirmation
- Creates connection if approved
- Sets autoconnect properties

```
--------------------------------------------------
Pending VLAN Configuration:
  Connection Name : vl2010
  VLAN ID         : 2010
  Parent NIC      : eno2
  VLAN Interface  : eno2.2010
  IPv4 Address    : 172.20.10.2/24
  Gateway         : 172.20.10.1
  DNS Server      : 172.20.10.1
  Search Domain   : xlm-mgmt.lan
  Autoconnect Prio: -1
  Route Metric    : 100
--------------------------------------------------
Create this VLAN? (y/N): y
```

## Predefined VLANs

### 1. Management VLAN (vl2010)
- **VLAN ID**: 2010
- **IP Address**: 172.20.10.2/24
- **Gateway**: 172.20.10.1
- **DNS**: 172.20.10.1
- **Search Domain**: xlm-mgmt.lan
- **Autoconnect Priority**: -1 (highest)
- **Route Metric**: 100
- **Purpose**: Management interface, not for FS.com switches
- **Status**: Full gateway configuration

### 2. WiFi Mesh VLAN (vl2020)
- **VLAN ID**: 2020
- **IP Address**: 172.20.20.2/24
- **Gateway**: None
- **DNS**: 172.20.20.1
- **Search Domain**: xlm-wifimesh.lan
- **Autoconnect Priority**: 20
- **Route Metric**: 200
- **Purpose**: WiFi mesh network communication
- **Status**: Critical for all operations

### 3. Gateway VLAN (vl2100)
- **VLAN ID**: 2100
- **IP Address**: 172.21.0.2/20 (subnet mask 255.255.240.0)
- **Gateway**: None
- **DNS**: 172.21.0.1
- **Search Domain**: xlm-gateways.lan
- **Autoconnect Priority**: 30
- **Route Metric**: 300
- **Purpose**: Gateway connectivity
- **Status**: Critical for all operations

### 4. IP Cameras VLAN (vl3200)
- **VLAN ID**: 3200
- **IP Address**: 172.30.200.2/24
- **Gateway**: None
- **DNS**: 172.30.200.1
- **Search Domain**: xlm-ipcams.lan
- **Autoconnect Priority**: 40
- **Route Metric**: 400
- **Purpose**: IP camera network isolation
- **Status**: Critical for all operations

## Configuration Guide

### Modifying VLAN Settings

Edit the `VLAN_LIST` array in the script to customize VLANs:

```bash
VLAN_LIST=(
    "name;id;ip/cidr;gateway-or-NOGATEWAY;dns;dns-search;priority;metric;comment"
    "vl2010;2010;172.20.10.2/24;172.20.10.1;172.20.10.1;xlm-mgmt.lan;-1;100;not_for_FS.com_switches"
    # Add more entries...
)
```

### Field Definitions

| Field | Example | Description |
|-------|---------|-------------|
| Name | vl2010 | Connection name in NetworkManager |
| VID | 2010 | VLAN Identifier |
| IP/CIDR | 172.20.10.2/24 | Static IP with CIDR notation |
| Gateway | 172.20.10.1 or NOGATEWAY | Default gateway (NOGATEWAY = no gateway) |
| DNS | 172.20.10.1 | DNS server address |
| DNS Search | xlm-mgmt.lan | DNS search domain |
| Priority | -1 | Autoconnect priority (lower = earlier) |
| Metric | 100 | Route metric (lower = higher priority) |
| Comment | Purpose | Description/comment |

### Adding New VLANs

1. Edit the VLAN_LIST array
2. Add new entry with proper format (semicolon-separated)
3. Save file
4. Run script

Example - Adding new VLAN:
```bash
VLAN_LIST=(
    # ... existing entries ...
    "vl4500;4500;192.168.45.2/24;192.168.45.1;192.168.45.1;new-network.lan;50;500;new_network"
)
```

### Changing Autoconnect Priority

Lower priority number = connects earlier

```bash
-1  # Connects first (highest priority)
 0  # Default priority
20  # Connects after vl2010
30  # Connects after vl2020
```

## Output & Verification

### Verify VLAN Creation

After script completes, verify VLANs were created:

```bash
# List all connections
nmcli connection show

# Show connection names only
nmcli -t -f NAME connection show

# Show specific VLAN details
nmcli connection show vl2010

# Show active VLAN interfaces
ip link show

# Check VLAN interface status
nmcli device show eno2.2010

# Verify IP configuration
ip addr show eno2.2010
```

### Check Autoconnect Status

```bash
# Verify autoconnect enabled
nmcli connection show vl2010 | grep autoconnect

# Show autoconnect priority
nmcli connection show vl2010 | grep autoconnect-priority
```

### Test VLAN Connectivity

```bash
# Ping gateway on VLAN
ping 172.20.10.1

# Test DNS resolution on VLAN
nslookup example.com 172.20.10.1

# Trace route on VLAN
traceroute -i vl2010 8.8.8.8
```

## Management with nmtui

After VLAN creation, modify settings using NetworkManager TUI:

```bash
sudo nmtui
```

Navigate to:
1. Edit a connection
2. Select desired VLAN
3. Modify settings as needed
4. Activate/Deactivate connections

## Management with Advanced Network Configuration

GUI tool for network management:
```bash
# Launch Advanced Network Configuration
gnome-control-center network
# or
nm-connection-editor
```

## Troubleshooting

| Issue | Solution |
|-------|----------|
| **"No physical NICs detected"** | Verify NIC hardware: `ls /sys/class/net` |
| **"NIC not found among detected"** | Check spelling; use `ip link show` to list NICs |
| **VLAN creation fails** | Ensure sudo privileges; check NetworkManager is running |
| **No VLAN interface appears** | Verify parent NIC is active: `ip link show eno2` |
| **VLAN doesn't autoconnect** | Check priority settings; verify parent NIC status |
| **DNS not resolving** | Test DNS server: `nslookup example.com 172.20.10.1` |
| **Cannot ping gateway** | Verify IP configuration: `ip addr show` |
| **Script won't execute** | Make executable: `chmod +x create_vlans.sh` |
| **Permission denied** | Run with sudo or check user permissions |

## Network Architecture

### Typical Setup After Execution

```
Internet/Modem
    ↓
[Parent NIC - eno2]
    ├── VLAN 2010 (Management) → 172.20.10.0/24
    ├── VLAN 2020 (WiFi Mesh) → 172.20.20.0/24
    ├── VLAN 2100 (Gateways) → 172.21.0.0/20
    └── VLAN 3200 (IP Cameras) → 172.30.200.0/24
```

### IP Address Plan

```
Management (VLAN 2010):
  Network: 172.20.10.0/24
  Gateway: 172.20.10.1
  EdgePC:  172.20.10.2
  Range:   172.20.10.3 - 172.20.10.254

WiFi Mesh (VLAN 2020):
  Network: 172.20.20.0/24
  EdgePC:  172.20.20.2
  Range:   172.20.20.3 - 172.20.20.254

Gateways (VLAN 2100):
  Network: 172.21.0.0/20 (255.255.240.0)
  EdgePC:  172.21.0.2
  Range:   172.21.0.3 - 172.21.15.254

IP Cameras (VLAN 3200):
  Network: 172.30.200.0/24
  EdgePC:  172.30.200.2
  Range:   172.30.200.3 - 172.30.200.254
```

## Post-Configuration Tasks

### 1. Reboot EdgePC
```bash
sudo reboot
```

Verify VLANs reconnect automatically.

### 2. Test Each VLAN
```bash
# Test management VLAN
ping 172.20.10.1

# Test WiFi mesh VLAN
ping 172.20.20.1

# Test gateway VLAN
ping 172.21.0.1

# Test camera VLAN
ping 172.30.200.1
```

### 3. Configure Router/Switch
Ensure trunk port or VLAN configuration on connected device supports all 4 VLANs.

### 4. Document Configuration
Save output of:
```bash
nmcli connection show > vlan_config_backup.txt
ip addr show > ip_config_backup.txt
```

## Advanced Configuration

### Modify Existing VLAN

After creation, modify with nmcli:
```bash
# Change DNS for a VLAN
nmcli connection modify vl2010 ipv4.dns "8.8.8.8 8.8.4.4"

# Change static IP
nmcli connection modify vl2010 ipv4.addresses "172.20.10.5/24"

# Change gateway
nmcli connection modify vl2010 ipv4.gateway "172.20.10.254"

# Apply changes
nmcli connection up vl2010
```

### Delete VLAN

```bash
# Delete a VLAN connection
nmcli connection delete vl2010
```

### Backup Configuration

```bash
# Export all VLAN configurations
nmcli connection show > vlan_backup_$(date +%Y%m%d).txt

# Backup NetworkManager config directory
sudo tar -czf nm_config_backup.tar.gz /etc/NetworkManager/
```

### Restore from Backup

See NetworkManager documentation for restoration procedures.

## Performance Optimization

### Route Metrics

Currently configured:
- vl2010: metric 100 (preferred for routing)
- vl2020: metric 200
- vl2100: metric 300
- vl3200: metric 400

Lower metric = higher routing priority.

Adjust metrics based on network requirements.

## Security Considerations

1. **VLAN Segregation**: Ensures network isolation between segments
2. **Access Control**: Use firewall rules to control inter-VLAN traffic
3. **DNS Security**: Verify DNS servers are trusted
4. **Documentation**: Keep network diagram updated
5. **Backup**: Backup configuration before making changes

## Script Safety Features

- ✓ Requires explicit user confirmation before proceeding
- ✓ Displays pending configuration before creation
- ✓ Per-VLAN confirmation allows selective creation
- ✓ Validates parent NIC selection
- ✓ Error checking on NIC detection
- ✓ Safe defaults (no automatic execution)

## Dependencies Summary

```
create_vlans.sh:
  ├── bash
  ├── nmcli (NetworkManager)
  ├── ip (iproute2)
  ├── grep
  ├── awk
  ├── sed
  ├── ls
  ├── cat
  └── read (builtin)
```

## Related Commands

### Monitor VLAN Status
```bash
# Real-time VLAN status
watch -n 2 'ip link show; echo "---"; ip addr show'

# Monitor NetworkManager events
sudo nmcli monitor
```

### Troubleshooting Commands
```bash
# Check NetworkManager logs
journalctl -u NetworkManager -f

# Test VLAN connectivity
mtr -c 10 172.20.10.1

# Check route table
ip route show

# Check ARP table
ip neigh show
```

## Support & Documentation

- NetworkManager documentation: `man nmcli`
- VLAN configuration: `man ip-link`
- Routing: `man ip-route`

## Version History

- **v1.0** (2024-04): Initial release
  - Automatic NIC detection
  - Interactive VLAN creation
  - 4 predefined VLANs
  - User confirmation workflow

## Notes

- Script creates VLANs but doesn't remove existing configurations
- Parent NIC must be active on a trunk port for traffic to flow
- Reboot recommended after VLAN creation
- All VLANs configured to autoconnect when parent NIC is available
- DNS settings configured but may be overridden by system settings

---

**Last Updated**: April 2024
**Location**: `/home/xsights/shell_scripts/create_vlans.sh`
