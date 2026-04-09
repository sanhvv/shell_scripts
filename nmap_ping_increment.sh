#!/usr/bin/env bash
# nmap network scanner script version 6 - 20250509
# -----------------------------------------------------------------------------------
# Dependencies:
# 1) package nmap is installed. 
# 2) the user account will need sudo rights
# 3) sudo password is suppressed
# -----------------------------------------------------------------------------------

# Machine variable metadata
HOSTNAME=$(hostname)
USER=$(whoami)
OS_NAME=$(grep '^PRETTY_NAME' /etc/os-release | cut -d= -f2 | tr -d '"')
UPTIME=$(uptime -p)


# Define the log directory and target file 
timestamp=$(date +"%Y%m%dT%H%M")
log_dir="$HOME/Downloads/network_logger"
logtarget="$log_dir/${HOSTNAME}_nmap_ping_increment_log_$timestamp.txt"

clear

# Ensure log directory exists
if [ ! -d "$log_dir" ]; then
    mkdir -p "$log_dir"
    echo "Directory created: $log_dir"
    sleep 1s
fi

# write a friendly output Header to log
{
    echo "Host Machine  : $HOSTNAME"
    echo "User Name     : $USER"
    echo "OS version    : $OS_NAME"
    echo "Machine Uptime: $UPTIME"
    echo "Nmap exec at  : $(date)"
    echo
} | tee "$logtarget"


# Get all non-loopback, non-docker IPv4 addresses
# This will omit Loopback, Docker, Tailscale, bridges & IPv6 addresses (that could scan for ages)
IP_ADDRS=$(ip -4 addr show | awk '/inet / {print $2}' | cut -d/ -f1)
FILTERED_IPS=()
for IP in $IP_ADDRS; do
    IFACE=$(ip -4 addr show | grep "$IP" | awk '{print $NF}')
    if [[ $IP == 127.* || $IFACE == docker* || $IFACE == tailscale* || $IFACE == br-* ]]; then
        continue
    fi
    FILTERED_IPS+=("$IP")
done


# Begin scanning each valid interface subnet
for IP_ADDR in "${FILTERED_IPS[@]}"; do
    if [[ $IP_ADDR == 172.21.0.* ]]; then
        NETWRK_SNET="172.21.0.0/20"
    else
        NETWRK_IP=$(echo $IP_ADDR | sed 's/\([0-9]\+\.[0-9]\+\.[0-9]\+\)\.[0-9]\+/\1.0/')
        NETWRK_SNET="${NETWRK_IP}/24"
    fi

    echo "------------------------------------------------" | tee -a "$logtarget"
    echo "Scan Source   : $IP_ADDR"  | tee -a "$logtarget"
    echo "Scan network  : $NETWRK_SNET" | tee -a "$logtarget"
    echo | tee -a "$logtarget"

declare -A mac_counter  # MAC address hit counter

# Get live IPs and scan for MACs
mapfile -t live_ips < <(sudo nmap -sn $NETWRK_SNET -oG - | awk '/Up$/{print $2}')

for ip in "${live_ips[@]}"; do
    while read line; do
        if echo "$line" | grep -q "Nmap scan report"; then
            ip_addr=$(echo "$line" | awk '{print $5}')
        elif echo "$line" | grep -q "MAC Address"; then
            mac=$(echo "$line" | awk '{print $3}')
            echo "MAC $mac NAME-or-IPv4 $ip_addr" | tee -a "$logtarget"

            # Increment hit counter
            ((mac_counter["$mac"]++))
        fi
    done < <(sudo nmap -sP "$ip")
done

# Output MAC summary per network
{
    echo
    #echo "MAC Address Hit Summary for $NETWRK_SNET:"
    total_unique_macs=${#mac_counter[@]}
    #for mac in "${!mac_counter[@]}"; do
        #echo "MAC $mac seen ${mac_counter[$mac]} times"
    #done
    echo "Total unique MAC addresses in $NETWRK_SNET: $total_unique_macs"
    echo
} | tee -a "$logtarget"

unset mac_counter

done

# Wrap-up
{
    echo "-------------------------------------------------"
    echo "Nmap logger completed at $(date)"
    echo
    echo "Log Output is $logtarget"
} | tee -a "$logtarget"

echo "-------------------------------------------------"
echo "Send this file to yourself using magic wormhole. Execute the command below"
echo "wormhole send $logtarget"
echo

sleep 1s
exit 0

