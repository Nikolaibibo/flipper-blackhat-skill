#!/bin/bash

################################################################################
# Automated WiFi Reconnaissance Pipeline for Flipper Zero BlackHat OS
################################################################################
# Purpose: Comprehensive target discovery, ranking, and profiling
# Author: Generated for authorized penetration testing only
# Requires: BlackHat OS with bh commands, aircrack-ng suite
################################################################################

set -euo pipefail

# Configuration
INTERFACE="${1:-wlan0}"
SCAN_DURATION="${2:-10}"
OUTPUT_DIR="${3:-/root/recon}"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
LOG_FILE="${OUTPUT_DIR}/recon_${TIMESTAMP}.log"
JSON_FILE="${OUTPUT_DIR}/recon_${TIMESTAMP}.json"
CSV_FILE="${OUTPUT_DIR}/recon_${TIMESTAMP}.csv"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

################################################################################
# Logging Function
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
    echo -e "${CYAN}"
    cat << 'EOF'
╔═══════════════════════════════════════════════════════════════╗
║           Flipper BlackHat Recon Pipeline v1.0                ║
║              Automated Target Discovery                       ║
╚═══════════════════════════════════════════════════════════════╝
EOF
    echo -e "${NC}"
}

################################################################################
# Pre-flight Checks
################################################################################
preflight_check() {
    log "INFO" "Starting pre-flight checks..."

    # Create output directory
    mkdir -p "${OUTPUT_DIR}"

    # Check if interface exists
    if ! ip link show "${INTERFACE}" &>/dev/null; then
        log "ERROR" "Interface ${INTERFACE} not found!"
        echo -e "${RED}Error: Interface ${INTERFACE} does not exist${NC}"
        exit 1
    fi

    # Check if interface is up
    if ! ip link show "${INTERFACE}" | grep -q "UP"; then
        log "WARN" "Interface ${INTERFACE} is down, bringing it up..."
        ip link set "${INTERFACE}" up
        sleep 2
    fi

    # Check for required commands
    for cmd in bh airmon-ng; do
        if ! command -v "$cmd" &>/dev/null; then
            log "ERROR" "Required command not found: $cmd"
            echo -e "${RED}Error: $cmd not installed${NC}"
            exit 1
        fi
    done

    log "INFO" "Pre-flight checks completed successfully"
    echo -e "${GREEN}✓ Pre-flight checks passed${NC}\n"
}

################################################################################
# Scan WiFi Networks
################################################################################
scan_networks() {
    log "INFO" "Starting WiFi scan on ${INTERFACE} for ${SCAN_DURATION} seconds..."
    echo -e "${YELLOW}[*] Scanning for WiFi networks...${NC}"

    # Start monitor mode if needed
    if ! iw dev "${INTERFACE}" info 2>/dev/null | grep -q "type monitor"; then
        log "INFO" "Enabling monitor mode on ${INTERFACE}..."
        airmon-ng start "${INTERFACE}" &>/dev/null || true
    fi

    # Capture networks with airodump-ng
    local airodump_file="${OUTPUT_DIR}/scan_${TIMESTAMP}"
    timeout "${SCAN_DURATION}" airodump-ng "${INTERFACE}" \
        -w "${airodump_file}" \
        --output-format csv \
        --write-interval 1 \
        </dev/null >/dev/null 2>&1 || true

    log "INFO" "Scan completed"
    echo -e "${GREEN}✓ Scan completed${NC}\n"
}

################################################################################
# Parse Scan Results
################################################################################
parse_results() {
    log "INFO" "Parsing scan results..."
    echo -e "${YELLOW}[*] Analyzing discovered networks...${NC}"

    local csv_scan="${OUTPUT_DIR}/scan_${TIMESTAMP}-01.csv"

    if [[ ! -f "${csv_scan}" ]]; then
        log "ERROR" "Scan file not found: ${csv_scan}"
        echo -e "${RED}Error: No scan data available${NC}"
        return 1
    fi

    # Initialize JSON structure
    echo "{" > "${JSON_FILE}"
    echo "  \"scan_timestamp\": \"$(date -Iseconds)\"," >> "${JSON_FILE}"
    echo "  \"interface\": \"${INTERFACE}\"," >> "${JSON_FILE}"
    echo "  \"networks\": [" >> "${JSON_FILE}"

    # Initialize CSV
    echo "BSSID,Channel,Signal,Encryption,SSID,Clients" > "${CSV_FILE}"

    # Parse networks from airodump CSV
    local network_count=0
    local in_networks=false

    while IFS=, read -r bssid first_seen last_seen channel speed privacy cipher auth power beacons iv lan_ip id_length essid key; do
        # Skip until we hit the network section
        if [[ "$bssid" == "BSSID" ]]; then
            in_networks=true
            continue
        fi

        # Stop when we hit the clients section
        if [[ "$bssid" == "Station MAC" ]]; then
            in_networks=false
            break
        fi

        if [[ "$in_networks" == true ]] && [[ -n "$bssid" ]]; then
            # Clean up fields
            bssid=$(echo "$bssid" | xargs </dev/null)
            channel=$(echo "$channel" | xargs </dev/null)
            power=$(echo "$power" | xargs </dev/null)
            privacy=$(echo "$privacy" | xargs </dev/null)
            essid=$(echo "$essid" | xargs </dev/null)

            # Skip if BSSID is empty or invalid
            [[ -z "$bssid" || "$bssid" == "BSSID" ]] && continue

            # Add to JSON
            if [[ $network_count -gt 0 ]]; then
                echo "    ," >> "${JSON_FILE}"
            fi

            cat >> "${JSON_FILE}" </dev/null << JSON_ENTRY
    {
      "bssid": "${bssid}",
      "channel": "${channel}",
      "signal": ${power:-0},
      "encryption": "${privacy}",
      "ssid": "${essid}",
      "rank": $((network_count + 1))
    }
JSON_ENTRY

            # Add to CSV
            echo "${bssid},${channel},${power},${privacy},${essid},0" >> "${CSV_FILE}"

            ((network_count++))
        fi
    done < "${csv_scan}"

    # Close JSON
    echo "  ]," >> "${JSON_FILE}"
    echo "  \"total_networks\": ${network_count}" >> "${JSON_FILE}"
    echo "}" >> "${JSON_FILE}"

    log "INFO" "Discovered ${network_count} networks"
    echo -e "${GREEN}✓ Parsed ${network_count} networks${NC}\n"
}

################################################################################
# Rank Targets
################################################################################
rank_targets() {
    log "INFO" "Ranking targets by signal strength and vulnerability..."
    echo -e "${YELLOW}[*] Ranking targets...${NC}\n"

    echo -e "${CYAN}════════════════════════════════════════════════════════════════${NC}"
    echo -e "${CYAN}Rank  Signal  Channel  Encryption    SSID${NC}"
    echo -e "${CYAN}════════════════════════════════════════════════════════════════${NC}"

    # Sort by signal strength (column 3), descending
    local rank=1
    tail -n +2 "${CSV_FILE}" | sort -t',' -k3 -nr | while IFS=, read -r bssid channel signal encryption essid clients; do
        # Color code by encryption
        local color="${NC}"
        case "$encryption" in
            *WPA3*) color="${RED}" ;;
            *WPA2*) color="${YELLOW}" ;;
            *WPA*) color="${GREEN}" ;;
            *WEP*) color="${GREEN}" ;;
            *OPN*) color="${GREEN}" ;;
            *) color="${NC}" ;;
        esac

        printf "${color}%-4s  %-6s  %-7s  %-12s  %s${NC}\n" \
            "$rank" "$signal" "$channel" "$encryption" "$essid"

        ((rank++))
    done

    echo -e "${CYAN}════════════════════════════════════════════════════════════════${NC}\n"
}

################################################################################
# Display Target Selection Menu
################################################################################
select_target() {
    echo -e "${YELLOW}[*] Target Selection Menu${NC}\n"

    echo "Select target by rank (or 'q' to quit, 's' to skip):"
    read -p "> " selection

    case "$selection" in
        q|Q)
            log "INFO" "User exited target selection"
            exit 0
            ;;
        s|S)
            log "INFO" "User skipped target selection"
            return
            ;;
        [0-9]*)
            local target_line=$(tail -n +2 "${CSV_FILE}" | sort -t',' -k3 -nr | sed -n "${selection}p")
            if [[ -n "$target_line" ]]; then
                local bssid=$(echo "$target_line" | cut -d',' -f1)
                local channel=$(echo "$target_line" | cut -d',' -f2)
                local essid=$(echo "$target_line" | cut -d',' -f5)

                echo -e "\n${GREEN}Selected Target:${NC}"
                echo -e "  BSSID:   ${CYAN}${bssid}${NC}"
                echo -e "  SSID:    ${CYAN}${essid}${NC}"
                echo -e "  Channel: ${CYAN}${channel}${NC}\n"

                log "INFO" "Target selected: ${essid} (${bssid}) on channel ${channel}"

                # Save selected target
                cat > "${OUTPUT_DIR}/target_${TIMESTAMP}.txt" << TARGET
BSSID=${bssid}
CHANNEL=${channel}
ESSID=${essid}
TARGET

                echo -e "${GREEN}✓ Target saved to ${OUTPUT_DIR}/target_${TIMESTAMP}.txt${NC}"
            else
                echo -e "${RED}Invalid selection${NC}"
                select_target
            fi
            ;;
        *)
            echo -e "${RED}Invalid input${NC}"
            select_target
            ;;
    esac
}

################################################################################
# Generate Summary Report
################################################################################
generate_report() {
    log "INFO" "Generating summary report..."

    local report_file="${OUTPUT_DIR}/report_${TIMESTAMP}.txt"

    cat > "${report_file}" << REPORT
═══════════════════════════════════════════════════════════════
  Flipper BlackHat WiFi Reconnaissance Report
═══════════════════════════════════════════════════════════════

Scan Timestamp: $(date)
Interface:      ${INTERFACE}
Scan Duration:  ${SCAN_DURATION} seconds
Output Dir:     ${OUTPUT_DIR}

Networks Discovered: $(tail -n +2 "${CSV_FILE}" | wc -l)

═══════════════════════════════════════════════════════════════
  Top Targets (by signal strength)
═══════════════════════════════════════════════════════════════

$(tail -n +2 "${CSV_FILE}" | sort -t',' -k3 -nr | head -10 | awk -F',' '{printf "%-18s  %-7s  %-6s  %-12s  %s\n", $1, $2, $3, $4, $5}')

═══════════════════════════════════════════════════════════════
  Encryption Distribution
═══════════════════════════════════════════════════════════════

$(tail -n +2 "${CSV_FILE}" | cut -d',' -f4 | sort | uniq -c | awk '{printf "%-20s: %d\n", $2, $1}')

═══════════════════════════════════════════════════════════════
  Files Generated
═══════════════════════════════════════════════════════════════

Log:    ${LOG_FILE}
JSON:   ${JSON_FILE}
CSV:    ${CSV_FILE}
Report: ${report_file}

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

    # Remove temporary airodump files
    rm -f "${OUTPUT_DIR}"/scan_"${TIMESTAMP}"*.cap 2>/dev/null || true
    rm -f "${OUTPUT_DIR}"/scan_"${TIMESTAMP}"*.kismet.* 2>/dev/null || true

    log "INFO" "Cleanup completed"
}

################################################################################
# Main Execution
################################################################################
main() {
    print_banner

    echo -e "${BLUE}Configuration:${NC}"
    echo -e "  Interface:     ${INTERFACE}"
    echo -e "  Scan Duration: ${SCAN_DURATION}s"
    echo -e "  Output Dir:    ${OUTPUT_DIR}\n"

    preflight_check
    scan_networks
    parse_results
    rank_targets
    select_target
    generate_report
    cleanup

    echo -e "\n${GREEN}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}  Recon pipeline completed successfully!${NC}"
    echo -e "${GREEN}═══════════════════════════════════════════════════════════════${NC}\n"

    log "INFO" "Recon pipeline completed successfully"
}

# Handle Ctrl+C gracefully
trap 'echo -e "\n${RED}Interrupted by user${NC}"; cleanup; exit 130' INT TERM

# Run main function
main "$@"
