#!/bin/bash

################################################################################
# Network Health Monitor for Flipper Zero BlackHat OS
################################################################################
# Purpose: Continuous surveillance with anomaly detection
# Author: Generated for authorized penetration testing only
# Requires: BlackHat OS with bh commands
################################################################################

set -eo pipefail

# Configuration
INTERFACE="${1:-wlan0}"
SCAN_INTERVAL="${2:-30}"
OUTPUT_DIR="${3:-/root/monitor}"
WATCH_MACS="${4:-}"  # Comma-separated MACs to watch for
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
LOG_FILE="${OUTPUT_DIR}/monitor_${TIMESTAMP}.log"
NETWORKS_DB="${OUTPUT_DIR}/networks.db"
ALERTS_FILE="${OUTPUT_DIR}/alerts_${TIMESTAMP}.log"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Tracking
declare -A last_seen
declare -A signal_history

# Scan result counters (global to avoid subshell issues)
scan_new_count=0
scan_disappeared_count=0

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

alert() {
    local message="$*"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[${timestamp}] ALERT: ${message}" | tee -a "${ALERTS_FILE}"
    echo -e "${RED}[ALERT] ${message}${NC}"
}

################################################################################
# Banner
################################################################################
print_banner() {
    echo -e "${CYAN}"
    cat << 'EOF'
╔═══════════════════════════════════════════════════════════════╗
║            Network Health Monitor v1.0                        ║
║          Continuous Surveillance & Anomaly Detection          ║
╚═══════════════════════════════════════════════════════════════╝
EOF
    echo -e "${NC}\n"
}

################################################################################
# Initialize
################################################################################
initialize() {
    mkdir -p "${OUTPUT_DIR}"

    # Create networks database if it doesn't exist
    if [[ ! -f "$NETWORKS_DB" ]]; then
        echo "# BSSID,ESSID,Channel,Encryption,FirstSeen,LastSeen" > "$NETWORKS_DB"
    fi

    log "INFO" "Monitor initialized"
}

################################################################################
# Scan Networks
################################################################################
scan_networks() {
    local temp_scan="/tmp/scan_$$"

    # Quick 5-second scan
    timeout 5 airodump-ng "${INTERFACE}" \
        -w "${temp_scan}" \
        --output-format csv \
        </dev/null >/dev/null 2>&1 || true

    if [[ -f "${temp_scan}-01.csv" ]]; then
        echo "${temp_scan}-01.csv"
    else
        echo ""
    fi
}

################################################################################
# Process Scan Results
################################################################################
process_scan() {
    local scan_file="$1"
    local current_time=$(date +%s)

    # Reset global counters
    scan_new_count=0
    scan_disappeared_count=0

    [[ ! -f "$scan_file" ]] && return

    # Convert Windows line endings to Unix
    tr -d '\r' < "$scan_file" > "${scan_file}.unix"
    mv "${scan_file}.unix" "$scan_file"

    # Mark current time for all networks
    declare -A seen_now

    # Process networks
    local in_networks=false
    while IFS=, read -r bssid first_seen last_seen channel speed privacy cipher auth power beacons iv lan_ip id_length essid key; do
        if [[ "$bssid" == "BSSID" ]]; then
            in_networks=true
            continue
        fi

        [[ "$bssid" == "Station MAC" ]] && break
        [[ ! "$in_networks" = true ]] && continue
        [[ -z "$bssid" ]] && continue

        bssid=$(echo "$bssid" | xargs)
        essid=$(echo "$essid" | xargs)
        channel=$(echo "$channel" | xargs)
        privacy=$(echo "$privacy" | xargs)
        power=$(echo "$power" | xargs)

        [[ -z "$bssid" ]] && continue

        seen_now["$bssid"]=1

        # Check if new network
        if [[ ! -v last_seen["$bssid"] ]]; then
            alert "NEW NETWORK: ${essid} (${bssid}) on channel ${channel}"
            echo "${bssid},${essid},${channel},${privacy},$(date -Iseconds),$(date -Iseconds)" >> "$NETWORKS_DB"
            ((scan_new_count++)) || true
        fi

        # Update last seen
        last_seen["$bssid"]=$current_time

        # Track signal strength changes
        if [[ -v signal_history["$bssid"] ]]; then
            local old_signal=${signal_history["$bssid"]}
            local signal_diff=$((power - old_signal))

            if [[ ${signal_diff#-} -gt 15 ]]; then
                alert "SIGNAL CHANGE: ${essid} (${bssid}) - ${old_signal}dBm → ${power}dBm"
            fi
        fi
        signal_history["$bssid"]=$power

        # Check for watch MACs
        if [[ -n "$WATCH_MACS" ]]; then
            if echo "$WATCH_MACS" | grep -qi "$bssid"; then
                alert "WATCHED MAC DETECTED: ${bssid} (${essid})"
            fi
        fi

    done < "$scan_file"

    # Check for disappeared networks
    if [[ ${#last_seen[@]} -gt 0 ]]; then
        for bssid in "${!last_seen[@]}"; do
            if [[ ! -v seen_now["$bssid"] ]]; then
                # Safety check: ensure last_seen value is numeric
                local last_time=${last_seen["$bssid"]}
                if [[ "$last_time" =~ ^[0-9]+$ ]]; then
                    local time_diff=$((current_time - last_time))
                    if [[ $time_diff -gt $((SCAN_INTERVAL * 3)) ]]; then
                        alert "NETWORK DISAPPEARED: ${bssid}"
                        unset last_seen["$bssid"]
                        ((scan_disappeared_count++)) || true
                    fi
                else
                    # Invalid timestamp, remove from tracking
                    unset last_seen["$bssid"]
                fi
            fi
        done
    fi

    rm -f "${scan_file}" 2>/dev/null || true
}

################################################################################
# Display Status
################################################################################
display_status() {
    clear 2>/dev/null || true
    print_banner

    echo -e "${BLUE}Monitor Status${NC}"
    echo -e "─────────────────────────────────────────────────────────────"
    echo -e "Interface:      ${INTERFACE}"
    echo -e "Scan Interval:  ${SCAN_INTERVAL}s"
    echo -e "Networks:       ${#last_seen[@]}"
    echo -e "Time:           $(date '+%Y-%m-%d %H:%M:%S')"
    echo -e "─────────────────────────────────────────────────────────────\n"

    echo -e "${CYAN}Active Networks (Last ${SCAN_INTERVAL}s)${NC}"
    echo -e "─────────────────────────────────────────────────────────────"

    if [[ ${#last_seen[@]} -eq 0 ]]; then
        echo -e "${YELLOW}No networks detected${NC}"
    else
        for bssid in "${!last_seen[@]}"; do
            local signal=${signal_history[$bssid]:-"N/A"}
            echo -e "${GREEN}${bssid}${NC} - Signal: ${signal} dBm"
        done
    fi

    echo -e "─────────────────────────────────────────────────────────────\n"
    echo -e "${YELLOW}Press Ctrl+C to stop monitoring${NC}\n"
}

################################################################################
# Main Monitor Loop
################################################################################
monitor_loop() {
    local scan_count=0

    log "INFO" "Starting monitor loop..."

    while true; do
        ((scan_count++)) || true

        log "INFO" "Scan #${scan_count} starting..."

        local scan_file=$(scan_networks)

        if [[ -n "$scan_file" ]]; then
            # Call process_scan directly (not in subshell) to preserve array modifications
            process_scan "$scan_file"

            log "INFO" "Scan #${scan_count}: ${#last_seen[@]} networks, ${scan_new_count} new, ${scan_disappeared_count} gone"
        fi

        display_status

        sleep "$SCAN_INTERVAL"
    done
}

################################################################################
# Generate Report
################################################################################
generate_report() {
    local report_file="${OUTPUT_DIR}/report_${TIMESTAMP}.txt"

    # Calculate counts safely before heredoc
    local network_count=0
    [[ ${#last_seen[@]} -gt 0 ]] && network_count=${#last_seen[@]} || true

    cat > "${report_file}" << REPORT
═══════════════════════════════════════════════════════════════
  Network Monitoring Report
═══════════════════════════════════════════════════════════════

Monitoring Started:  $(date)
Interface:           ${INTERFACE}
Scan Interval:       ${SCAN_INTERVAL} seconds
Total Networks Seen: ${network_count}

═══════════════════════════════════════════════════════════════
  Alerts Summary
═══════════════════════════════════════════════════════════════

$(cat "${ALERTS_FILE}" 2>/dev/null || echo "No alerts generated")

═══════════════════════════════════════════════════════════════
  Files Generated
═══════════════════════════════════════════════════════════════

Log:        ${LOG_FILE}
Database:   ${NETWORKS_DB}
Alerts:     ${ALERTS_FILE}
Report:     ${report_file}

═══════════════════════════════════════════════════════════════
REPORT

    echo -e "\n${GREEN}✓ Report saved to ${report_file}${NC}"
    log "INFO" "Report generated"
}

################################################################################
# Cleanup
################################################################################
cleanup() {
    echo -e "\n${YELLOW}Stopping monitor...${NC}"
    generate_report
    log "INFO" "Monitor stopped"
}

################################################################################
# Main
################################################################################
main() {
    print_banner

    echo -e "${BLUE}Configuration:${NC}"
    echo -e "  Interface:     ${INTERFACE}"
    echo -e "  Scan Interval: ${SCAN_INTERVAL}s"
    echo -e "  Output Dir:    ${OUTPUT_DIR}"
    if [[ -n "$WATCH_MACS" ]]; then
        echo -e "  Watch MACs:    ${WATCH_MACS}"
    fi
    echo ""

    initialize

    # Enable monitor mode
    if ! iw dev "${INTERFACE}" info 2>/dev/null | grep -q "type monitor"; then
        echo -e "${YELLOW}Enabling monitor mode...${NC}"
        airmon-ng start "${INTERFACE}" &>/dev/null || true
        sleep 2
    fi

    monitor_loop
}

trap 'cleanup; exit 130' INT TERM

main "$@"
