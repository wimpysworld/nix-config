#!/usr/bin/env bash

set -u  # Enable nounset for better error detection
trap 'echo "Error on line $LINENO"' ERR

# Ensure script runs with sudo
if [ "$EUID" -ne 0 ]; then
    echo "ERROR! Please run as root"
    exit 1
fi

# Get default gateway and primary interface
default_route=$(ip route show default)
if [ -z "${default_route}" ]; then
    echo "ERROR! No default route found"
    exit 1
fi

gateway=$(echo "${default_route}" | grep -oP 'via \K[0-9.]+')
interface=$(echo "${default_route}" | grep -oP 'dev \K\w+')

echo "Gateway: ${gateway}"
echo "Interface: ${interface}"

# Get IP and netmask for primary interface
ip_info=$(ip addr show dev "${interface}" | grep -w inet)
if [ -z "${ip_info}" ]; then
    echo "ERROR! No IPv4 address found for interface ${interface}"
    exit 1
fi

host_ip=$(echo "$ip_info" | grep -oP 'inet \K[0-9.]+')
netmask=$(echo "$ip_info" | grep -oP '/\K[0-9]+')
subnet="${host_ip%.*}.0/$netmask"

echo "Host IP: ${host_ip}"
echo "Subnet: ${subnet}"

# Run nmap scan
sudo nmap \
    -vvv \
    -Pn -r --top-ports 1024 \
    -sS -sV \
    -O --osscan-limit \
    -oX /tmp/nmap_advanced_portscan.xml \
    --open \
    --stylesheet https://raw.githubusercontent.com/Haxxnet/nmap-bootstrap-xsl/main/nmap-bootstrap.xsl \
    "${subnet}"
