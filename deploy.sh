#!/bin/bash
#
# Quick deployment script for Flipper Zero BlackHat OS scripts
# Usage: ./deploy.sh [script_name or 'all']
# 
# Uses HTTP server + wget (simple and reliable)
#

set -euo pipefail

# Configuration
DEVICE="root@192.168.178.122"
PASSWORD="niko0815"
SCRIPTS_DIR="examples"
REMOTE_DIR="/root"
HTTP_PORT="8888"

# Get local IP
LOCAL_IP=$(ifconfig | grep -Eo 'inet (addr:)?([0-9]*\.){3}[0-9]*' | grep -Eo '([0-9]*\.){3}[0-9]*' | grep -v '127.0.0.1' | head -1)

# Color output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Script list
ALL_SCRIPTS=(
    "01-recon-pipeline.sh"
    "02-handshake-capture.sh"
    "04-deauth-campaign.sh"
    "05-network-monitor.sh"
)

# Start HTTP server if not running
start_http_server() {
    if ! lsof -i :$HTTP_PORT > /dev/null 2>&1; then
        echo -e "${YELLOW}Starting HTTP server on port $HTTP_PORT...${NC}"
        cd "${SCRIPTS_DIR}"
        python3 -m http.server $HTTP_PORT > /tmp/deploy_http.log 2>&1 &
        HTTP_PID=$!
        cd ..
        sleep 2
        echo -e "${GREEN}✓ HTTP server started (PID: $HTTP_PID)${NC}"
        echo -e "${BLUE}Server URL: http://$LOCAL_IP:$HTTP_PORT/${NC}"
    else
        echo -e "${GREEN}✓ HTTP server already running${NC}"
    fi
}

deploy_file() {
    local file="$1"
    local local_path="${SCRIPTS_DIR}/${file}"

    if [[ ! -f "$local_path" ]]; then
        echo -e "${RED}✗ File not found: $local_path${NC}"
        return 1
    fi

    echo -e "${BLUE}Deploying $file...${NC}"

    # Download via wget
    sshpass -p "$PASSWORD" ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
        "$DEVICE" "wget -q -O ${REMOTE_DIR}/${file} http://${LOCAL_IP}:${HTTP_PORT}/${file} && chmod +x ${REMOTE_DIR}/${file}"

    echo -e "${GREEN}✓ $file deployed${NC}"
}

# Main
cd "$(dirname "$0")"

start_http_server

if [[ $# -eq 0 ]] || [[ "$1" == "all" ]]; then
    echo "Deploying all scripts..."
    for script in "${ALL_SCRIPTS[@]}"; do
        deploy_file "$script"
    done
    echo -e "\n${GREEN}✓ All scripts deployed successfully!${NC}"
else
    deploy_file "$1"
fi

echo -e "\n${YELLOW}Note: HTTP server is still running. Kill manually if needed:${NC}"
echo -e "${YELLOW}  pkill -f 'python3 -m http.server $HTTP_PORT'${NC}"
