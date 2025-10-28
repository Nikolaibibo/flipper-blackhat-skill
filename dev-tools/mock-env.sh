#!/bin/bash
# Mock environment activation script
# Sets up PATH and environment variables to use mock commands

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
MOCK_DIR="${PROJECT_ROOT}/tests/mocks"

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Check if mocks exist
if [[ ! -d "$MOCK_DIR" ]]; then
    echo -e "${YELLOW}Warning: Mock directory not found at $MOCK_DIR${NC}"
    echo "Run from project root directory"
    return 1 2>/dev/null || exit 1
fi

# Ensure mocks are executable
chmod +x "$MOCK_DIR"/* 2>/dev/null

# Add mocks to PATH (prepend so they override real commands)
export PATH="${MOCK_DIR}:${PATH}"

# Set environment variables for mock mode
export MOCK_MODE=1
export MOCK_INTERFACES="wlan0 wlan1"
export MOCK_DEVICE_IP="192.168.178.122"

# Color output
echo -e "${BLUE}╔════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║     Mock Environment Activated             ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${GREEN}✓ Mock commands enabled${NC}"
echo -e "  Path: ${MOCK_DIR}"
echo ""
echo -e "${BLUE}Available mock commands:${NC}"
for cmd in "$MOCK_DIR"/*; do
    if [[ -x "$cmd" ]]; then
        echo -e "  • $(basename "$cmd")"
    fi
done
echo ""
echo -e "${BLUE}Mock interfaces:${NC} ${MOCK_INTERFACES}"
echo -e "${BLUE}Mock device IP:${NC}  ${MOCK_DEVICE_IP}"
echo ""
echo -e "${YELLOW}Usage examples:${NC}"
echo -e "  bh wifi list"
echo -e "  airodump-ng wlan0 --write /tmp/test"
echo -e "  iw dev wlan0 info"
echo -e "  ./examples/01-recon-pipeline.sh wlan0 5 /tmp/recon"
echo ""
echo -e "${GREEN}Ready to test!${NC}"
echo ""

# Make functions available if sourced
if [[ "${BASH_SOURCE[0]}" != "${0}" ]]; then
    # Script is being sourced
    echo -e "${BLUE}Note:${NC} Environment active in current shell"
    echo -e "      Run 'deactivate' or close terminal to reset"
    echo ""

    # Create deactivate function
    deactivate() {
        export PATH="${PATH#${MOCK_DIR}:}"
        unset MOCK_MODE
        unset MOCK_INTERFACES
        unset MOCK_DEVICE_IP
        unset -f deactivate
        echo "Mock environment deactivated"
    }
else
    # Script is being executed
    echo -e "${YELLOW}Note:${NC} Run with 'source dev-tools/mock-env.sh' to activate in current shell"
fi
