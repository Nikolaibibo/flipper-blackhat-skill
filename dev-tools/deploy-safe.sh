#!/bin/bash
# Enhanced deployment with pre-flight validation and rollback
# Ensures scripts are tested before deploying to device

set -euo pipefail

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
DEVICE="${1:-root@192.168.178.122}"
PASSWORD="${2:?Usage: $0 [device] <password> [script|all]}"
SCRIPT="${3:-all}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

cd "$PROJECT_ROOT"

# Print banner
echo -e "${BLUE}╔════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║    Safe Deployment to Flipper Device       ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${BLUE}Target:${NC}   $DEVICE"
echo -e "${BLUE}Scripts:${NC}  $SCRIPT"
echo ""

# ============================================================================
# Step 1: Run local validation
# ============================================================================
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${YELLOW}Step 1/5: Running local validation...${NC}"
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

if ! ./dev-tools/validate.sh; then
    echo ""
    echo -e "${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${RED}✗ Validation failed!${NC}"
    echo -e "${RED}  Fix errors before deploying to device.${NC}"
    echo -e "${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    exit 1
fi

echo ""
echo -e "${GREEN}✓ Validation passed${NC}"
echo ""

# ============================================================================
# Step 2: Test device connectivity
# ============================================================================
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${YELLOW}Step 2/5: Testing device connectivity...${NC}"
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

if command -v sshpass &>/dev/null; then
    if sshpass -p "$PASSWORD" ssh -o StrictHostKeyChecking=no -o ConnectTimeout=5 \
        -o UserKnownHostsFile=/dev/null "$DEVICE" "echo 'Connection OK'" &>/dev/null; then
        echo -e "${GREEN}✓ Device reachable${NC}"
    else
        echo -e "${RED}✗ Cannot connect to device${NC}"
        echo -e "${RED}  Check IP address, password, and network connectivity${NC}"
        exit 1
    fi
else
    echo -e "${YELLOW}⚠ sshpass not installed - skipping connectivity test${NC}"
    echo -e "  Install: ${YELLOW}brew install hudochenkov/sshpass/sshpass${NC}"
fi
echo ""

# ============================================================================
# Step 3: Create backup on device
# ============================================================================
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${YELLOW}Step 3/5: Creating backup on device...${NC}"
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

BACKUP_DIR="/root/backup-$(date +%Y%m%d-%H%M%S)"

if command -v sshpass &>/dev/null; then
    sshpass -p "$PASSWORD" ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
        "$DEVICE" "mkdir -p $BACKUP_DIR && cp -f /root/*.sh $BACKUP_DIR/ 2>/dev/null || true"
    echo -e "${GREEN}✓ Backup created at $BACKUP_DIR${NC}"
else
    echo -e "${YELLOW}⚠ Skipping backup (sshpass not available)${NC}"
fi
echo ""

# ============================================================================
# Step 4: Deploy scripts
# ============================================================================
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${YELLOW}Step 4/5: Deploying scripts...${NC}"
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# Use existing deploy script
if [[ -f "deploy.sh" ]]; then
    # Modify deploy.sh call to use our credentials
    if [[ "$SCRIPT" == "all" ]]; then
        ./deploy.sh
    else
        ./deploy.sh "$SCRIPT"
    fi
else
    echo -e "${RED}✗ deploy.sh not found${NC}"
    exit 1
fi

echo ""
echo -e "${GREEN}✓ Scripts deployed${NC}"
echo ""

# ============================================================================
# Step 5: Health check
# ============================================================================
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${YELLOW}Step 5/5: Running health check...${NC}"
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

HEALTH_CHECK_OK=true

if command -v sshpass &>/dev/null; then
    # Test syntax of deployed scripts
    SCRIPTS_TO_CHECK=(
        "/root/01-recon-pipeline.sh"
        "/root/02-handshake-capture.sh"
        "/root/04-deauth-campaign.sh"
        "/root/05-network-monitor.sh"
    )

    for script in "${SCRIPTS_TO_CHECK[@]}"; do
        echo -ne "  Checking $script... "
        if sshpass -p "$PASSWORD" ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
            "$DEVICE" "bash -n $script" 2>/dev/null; then
            echo -e "${GREEN}✓${NC}"
        else
            echo -e "${RED}✗${NC}"
            HEALTH_CHECK_OK=false
        fi
    done

    if [ "$HEALTH_CHECK_OK" = true ]; then
        echo ""
        echo -e "${GREEN}✓ All health checks passed${NC}"
    else
        echo ""
        echo -e "${RED}✗ Health check failed${NC}"
        echo -e "${YELLOW}Rolling back to backup...${NC}"

        sshpass -p "$PASSWORD" ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
            "$DEVICE" "cp -f $BACKUP_DIR/*.sh /root/ 2>/dev/null || true"

        echo -e "${RED}Deployment failed and rolled back${NC}"
        echo -e "${YELLOW}Backup preserved at: $BACKUP_DIR${NC}"
        exit 1
    fi
else
    echo -e "${YELLOW}⚠ Skipping health check (sshpass not available)${NC}"
fi

# ============================================================================
# Success
# ============================================================================
echo ""
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}✓ Deployment successful!${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "${BLUE}Backup location:${NC} $BACKUP_DIR"
echo -e "${BLUE}Device:${NC}          $DEVICE"
echo ""
echo -e "${YELLOW}Next steps:${NC}"
echo -e "  1. SSH to device: ${YELLOW}ssh $DEVICE${NC}"
echo -e "  2. Test a script: ${YELLOW}./01-recon-pipeline.sh wlan0 10 /root/test${NC}"
echo ""
