#!/bin/bash
# Test harness with automatic hang detection
# Runs scripts with timeout and captures detailed output

set -euo pipefail

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
SCRIPT="${1:?Usage: $0 <script.sh> [args...]}"
shift
TIMEOUT="${TEST_TIMEOUT:-30}"  # Default 30 second timeout
TEMP_DIR=$(mktemp -d)
LOG_FILE="$TEMP_DIR/output.log"
START_TIME=$(date +%s)

cleanup() {
    rm -rf "$TEMP_DIR"
}
trap cleanup EXIT

# Print header
echo -e "${BLUE}╔════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║      Flipper BlackHat Test Runner          ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${BLUE}Script:${NC}   $SCRIPT"
echo -e "${BLUE}Timeout:${NC}  ${TIMEOUT}s"
echo -e "${BLUE}Args:${NC}     $*"
echo -e "${BLUE}Log:${NC}      $LOG_FILE"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# Run with timeout and capture all output
echo -e "${YELLOW}[*] Running script...${NC}"
echo ""

# Use timeout with script execution
if timeout "$TIMEOUT" bash -x "$SCRIPT" "$@" > "$LOG_FILE" 2>&1; then
    EXIT_CODE=0
else
    EXIT_CODE=$?
fi

END_TIME=$(date +%s)
DURATION=$((END_TIME - START_TIME))

# Display results
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

if [ $EXIT_CODE -eq 0 ]; then
    echo -e "${GREEN}✓ Script completed successfully${NC}"
    echo -e "${GREEN}  Duration: ${DURATION}s${NC}"
    echo ""
    echo -e "${BLUE}Output:${NC}"
    cat "$LOG_FILE"
    exit 0

elif [ $EXIT_CODE -eq 124 ]; then
    echo -e "${RED}✗ Script HUNG (exceeded ${TIMEOUT}s timeout)${NC}"
    echo -e "${RED}  Duration: ${DURATION}s${NC}"
    echo ""
    echo -e "${YELLOW}Debugging tips:${NC}"
    echo -e "  1. Check for commands reading stdin without </dev/null"
    echo -e "  2. Look for 'read' commands in loops"
    echo -e "  3. Check for blocking network operations"
    echo -e "  4. Run with 'bash -x' to see where it hangs"
    echo ""
    echo -e "${BLUE}Last 30 lines of output:${NC}"
    tail -30 "$LOG_FILE"
    echo ""
    echo -e "${BLUE}Full log available at: ${LOG_FILE}${NC}"

    # Try to identify where it hung
    echo ""
    echo -e "${YELLOW}Analyzing hang location...${NC}"
    if grep "airodump-ng\|aireplay-ng" "$LOG_FILE" | tail -5; then
        echo -e "${YELLOW}  → Likely hung on aircrack-ng suite command${NC}"
        echo -e "${YELLOW}  → Check for missing '</dev/null' redirect${NC}"
    elif grep "while.*read" "$LOG_FILE" | tail -5; then
        echo -e "${YELLOW}  → Likely hung on 'while read' loop${NC}"
        echo -e "${YELLOW}  → Check for stdin redirect issues${NC}"
    fi

    exit 1

else
    echo -e "${RED}✗ Script failed with exit code $EXIT_CODE${NC}"
    echo -e "${RED}  Duration: ${DURATION}s${NC}"
    echo ""
    echo -e "${BLUE}Full output:${NC}"
    cat "$LOG_FILE"
    exit $EXIT_CODE
fi
