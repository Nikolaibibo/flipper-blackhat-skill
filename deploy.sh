#!/bin/bash

################################################################################
# Deployment Script for Flipper BlackHat Pentesting Scripts
################################################################################
# Purpose: Easy deployment of updated scripts to Flipper Zero BlackHat OS
# Usage: ./deploy.sh <flipper-ip> <password>
################################################################################

set -e

FLIPPER_IP="${1:-192.168.178.122}"
FLIPPER_PASS="${2:-niko0815}"
GITHUB_RAW="https://raw.githubusercontent.com/Nikolaibibo/flipper-blackhat-skill/main"

echo "═══════════════════════════════════════════════════════════════"
echo "  Flipper BlackHat Script Deployment"
echo "═══════════════════════════════════════════════════════════════"
echo ""
echo "Target: $FLIPPER_IP"
echo ""

# Check if expect is available
if ! command -v expect &>/dev/null; then
    echo "Error: 'expect' command not found. Please install it first."
    echo "  macOS: brew install expect"
    echo "  Linux: apt-get install expect / yum install expect"
    exit 1
fi

# Scripts to deploy
BASH_SCRIPTS=(
    "01-recon-pipeline.sh"
    "02-handshake-capture.sh"
    "03-evil-twin.sh"
    "04-deauth-campaign.sh"
    "05-network-monitor.sh"
)

PYTHON_SCRIPTS=(
    "wifi_recon.py"
    "capture_handshake.py"
    "evil_twin.py"
    "deauth_target.py"
    "network_monitor.py"
    "set_target.py"
)

echo "Deploying bash scripts..."
for script in "${BASH_SCRIPTS[@]}"; do
    echo -n "  - $script... "

    expect << EXPECTEOF >/dev/null 2>&1
    set timeout 30
    spawn ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@${FLIPPER_IP}
    expect "password:"
    send "${FLIPPER_PASS}\r"
    expect "#"
    send "wget -q -O /root/${script} ${GITHUB_RAW}/examples/${script}\r"
    expect "#"
    send "chmod +x /root/${script}\r"
    expect "#"
    send "exit\r"
    expect eof
EXPECTEOF

    if [ $? -eq 0 ]; then
        echo "✓"
    else
        echo "✗ (failed)"
    fi
done

echo ""
echo "Deploying Python wrappers..."
for script in "${PYTHON_SCRIPTS[@]}"; do
    echo -n "  - $script... "

    expect << EXPECTEOF >/dev/null 2>&1
    set timeout 30
    spawn ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@${FLIPPER_IP}
    expect "password:"
    send "${FLIPPER_PASS}\r"
    expect "#"
    send "wget -q -O /mnt/scripts/${script} ${GITHUB_RAW}/flipper-wrappers/${script}\r"
    expect "#"
    send "chmod +x /mnt/scripts/${script}\r"
    expect "#"
    send "exit\r"
    expect eof
EXPECTEOF

    if [ $? -eq 0 ]; then
        echo "✓"
    else
        echo "✗ (failed)"
    fi
done

echo ""
echo "═══════════════════════════════════════════════════════════════"
echo "  Deployment Complete!"
echo "═══════════════════════════════════════════════════════════════"
echo ""
echo "Bash scripts deployed to: /root/"
echo "Python wrappers deployed to: /mnt/scripts/"
echo ""
echo "Run './01-recon-pipeline.sh' on the device to test!"
echo ""
