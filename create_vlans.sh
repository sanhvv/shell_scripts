#!/usr/bin/env bash
clear
echo " This script will create all VLANs for the EdgePC"
echo " ----------------------------------------------------------------------"
echo " IMPORTANT - PLEASE READ AND UNDERSTAND BEFORE EXECUTING THIS SCRIPT!"
echo ""
echo " You will be prompted to check the new VLAN config BEFORE it is applied."
echo " Changes to the new VLANs can be actioned using command sudo nmtui or"
echo " with the Advanced Network Configuration app AFTER the script has run."
echo
echo " It is assumed after the VLANs are created, the EdgePC will be directly"
echo " connected to either the modem LAN port or a trunk port on the switch"
echo " ----------------------------------------------------------------------"
echo " Please reboot the EdgePC after the VLANs have been verified as good"
echo ""
read -rp " OKAY to proceed with the script? (y/N): " PRE_CONFIRM
case "$PRE_CONFIRM" in
    y|Y|yes|YES)
        echo "Proceeding..."
        ;;
    *)
        echo "Aborted."
        exit 1
        ;;
esac
clear
# --------------------------------------------------
# Step 1: Detect all physical NICs
# --------------------------------------------------
ALL_NICS=($(ls /sys/class/net | grep -E '^(e|en|eth|p)' ))
if [ ${#ALL_NICS[@]} -eq 0 ]; then
    echo "Error: No physical NICs detected."
    exit 1
fi
# Detect NIC used for default route (may be WiFi)
DEFAULT_NIC_RAW=$(ip route | awk '/default/ {print $5; exit}')
# Detect which physical NICs are actually UP
ACTIVE_PHYS=()
for NIC in "${ALL_NICS[@]}"; do
    if cat "/sys/class/net/${NIC}/operstate" 2>/dev/null | grep -qw up; then
        ACTIVE_PHYS+=("$NIC")
    fi
done
# Decide whether to assign a default physical NIC
if [[ " ${ALL_NICS[@]} " =~ " ${DEFAULT_NIC_RAW} " ]]; then
    # default NIC IS a physical NIC → normal behaviour
    DEFAULT_NIC="$DEFAULT_NIC_RAW"
elif [ ${#ACTIVE_PHYS[@]} -gt 0 ]; then
    # physical NICs exist & at least one is active but not default route
    DEFAULT_NIC="${ACTIVE_PHYS[0]}"
else
    # No physical NIC is in use → user likely on WiFi
    DEFAULT_NIC=""
fi
# Show NIC list
echo "Detected physical NICs:"
for NIC in "${ALL_NICS[@]}"; do
    if [[ -n "$DEFAULT_NIC" && "$NIC" == "$DEFAULT_NIC" ]]; then
        echo "  * $NIC (default)"
    else
        echo "    $NIC"
    fi
done
if [[ -z "$DEFAULT_NIC" ]]; then
    echo "Note: No active physical NICs detected. Possible WiFi NIC in use."
    echo "      You must manually choose a NIC below."
fi
# Prompt user
if [[ -n "$DEFAULT_NIC" ]]; then
    read -rp "Enter NIC to use for VLANs [default: $DEFAULT_NIC]: " USER_NIC
else
    read -rp "Enter NIC to use for VLANs: " USER_NIC
fi
if [ -z "$USER_NIC" ] && [ -n "$DEFAULT_NIC" ]; then
    PARENT_NIC="$DEFAULT_NIC"
else
    if [[ ! " ${ALL_NICS[@]} " =~ " ${USER_NIC} " ]]; then
        echo "Error: NIC '$USER_NIC' not found among detected physical NICs."
        exit 1
    fi
    PARENT_NIC="$USER_NIC"
fi
echo "Using parent NIC: $PARENT_NIC"
read -rp "Okay to proceed with this parent NIC? (y/N): " CONFIRM
case "$CONFIRM" in
    y|Y|yes|YES) echo "Proceeding...";;
    *) echo "Aborted."; exit 1;;
esac
# --------------------------------------------------
# Step 2: Define VLANs
# Format: name;id;ip/cidr;gateway-or-NOGATEWAY;dns;dns-search;priority;metric;comment
# --------------------------------------------------
VLAN_LIST=(
    "vl2010;2010;172.20.10.2/24;172.20.10.1;172.20.10.1;xlm-mgmt.lan;-1;100;not_for_FS.com_switches"
    "vl2020;2020;172.20.20.2/24;NOGATEWAY;172.20.20.1;xlm-wifimesh.lan;20;200;needed_for_all"
    "vl2100;2100;172.21.0.2/20;NOGATEWAY;172.21.0.1;xlm-gateways.lan;30;300;needed_for_all"
    "vl3200;3200;172.30.200.2/24;NOGATEWAY;172.30.200.1;xlm-ipcams.lan;40;400;needed_for_all"
)
# --------------------------------------------------
# Step 3: Create VLANs in a loop
# --------------------------------------------------
for ENTRY in "${VLAN_LIST[@]}"; do
    IFS=';' read -r NAME VID IPADDR GATEWAY DNS DNSSUFFIX PRIORITY METRIC COMMENT <<< "$ENTRY"
    VLAN_IFACE="${PARENT_NIC}.${VID}"
    echo "--------------------------------------------------"
    echo "Pending VLAN Configuration:"
    echo "  Connection Name : $NAME"
    echo "  VLAN ID         : $VID"
    echo "  Parent NIC      : $PARENT_NIC"
    echo "  VLAN Interface  : $VLAN_IFACE"
    echo "  IPv4 Address    : $IPADDR"
    if [[ "$GATEWAY" != "NOGATEWAY" ]]; then
        echo "  Gateway         : $GATEWAY"
    else
        echo "  Gateway         : (none)"
    fi
    echo "  DNS Server      : $DNS"
    echo "  Search Domain   : $DNSSUFFIX"
    echo "  Autoconnect Prio: $PRIORITY"
    echo "  Route Metric    : $METRIC"
    echo "--------------------------------------------------"
    echo "  Required Comment: $COMMENT"
    echo "--------------------------------------------------"
    echo ""
    read -rp "Create this VLAN? (y/N): " YN
    case "$YN" in
        y|Y|yes|YES)
            echo "Creating $NAME..."
            CMD=(
                sudo nmcli connection add type vlan
                con-name "$NAME"
                ifname "$VLAN_IFACE"
                dev "$PARENT_NIC"
                id "$VID"
                ip4 "$IPADDR"
                ipv4.dns "$DNS"
                ipv4.dns-search "$DNSSUFFIX"
                ipv4.method manual
                connection.autoconnect yes
                connection.autoconnect-priority "$PRIORITY"
                connection.metered no
                ipv4.route-metric "$METRIC"
            )
            if [[ "$GATEWAY" != "NOGATEWAY" ]]; then
                CMD+=("gw4" "$GATEWAY")
            fi
            "${CMD[@]}"
            echo "VLAN $NAME created and set to autoconnect."
            ;;
        *)
            echo "Skipping $NAME."
            ;;
    esac
    echo ""
done
echo "All VLAN creation complete. All created VLANs are configured to automatically connect when the parent NIC is active."
