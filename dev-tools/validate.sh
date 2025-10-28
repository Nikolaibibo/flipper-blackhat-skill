#!/bin/bash
# Pre-deployment validation script
# Catches common issues before they reach the device

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

ERRORS=0
WARNINGS=0

echo -e "${BLUE}╔════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║    Flipper BlackHat Validation Suite      ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════╝${NC}"
echo ""

# ============================================================================
# 1. Syntax Check
# ============================================================================
echo -e "${BLUE}1️⃣  Checking bash syntax...${NC}"
for script in examples/*.sh; do
    if bash -n "$script" 2>&1; then
        echo -e "  ${GREEN}✓${NC} $script"
    else
        echo -e "  ${RED}✗${NC} $script - SYNTAX ERROR"
        ((ERRORS++))
    fi
done
echo ""

# ============================================================================
# 2. ShellCheck Static Analysis
# ============================================================================
echo -e "${BLUE}2️⃣  Running ShellCheck...${NC}"
if command -v shellcheck &>/dev/null; then
    for script in examples/*.sh deploy.sh; do
        if [[ ! -f "$script" ]]; then
            continue
        fi

        # Run shellcheck and capture output
        if OUTPUT=$(shellcheck "$script" 2>&1); then
            echo -e "  ${GREEN}✓${NC} $script"
        else
            # Check severity - warnings vs errors
            if echo "$OUTPUT" | grep -q "error:"; then
                echo -e "  ${RED}✗${NC} $script - HAS ERRORS"
                echo "$OUTPUT" | head -10
                ((ERRORS++))
            else
                echo -e "  ${YELLOW}⚠${NC} $script - has warnings"
                ((WARNINGS++))
            fi
        fi
    done
else
    echo -e "  ${YELLOW}⚠${NC} ShellCheck not installed - skipping"
    echo -e "    Install: ${YELLOW}brew install shellcheck${NC}"
fi
echo ""

# ============================================================================
# 3. Check for Known Issues
# ============================================================================
echo -e "${BLUE}3️⃣  Checking for known pitfalls...${NC}"

# Issue #1: airodump-ng without stdin redirect (causes hanging)
echo -ne "  Checking for stdin hanging issues... "
if grep -r "airodump-ng" examples/*.sh | grep -v "</dev/null" | grep -q "&>/dev/null\|2>&1"; then
    echo -e "${RED}✗ FOUND${NC}"
    echo -e "    ${RED}ERROR: airodump-ng commands missing stdin redirect!${NC}"
    echo -e "    These will hang with strict mode:"
    grep -n "airodump-ng" examples/*.sh | grep -v "</dev/null" | grep "&>/dev/null\|2>&1" | sed 's/^/      /'
    ((ERRORS++))
else
    echo -e "${GREEN}✓${NC}"
fi

# Issue #2: aireplay-ng without stdin redirect
echo -ne "  Checking for aireplay stdin issues... "
if grep -r "aireplay-ng" examples/*.sh | grep -v "</dev/null" | grep -q "&>/dev/null\|2>&1"; then
    echo -e "${YELLOW}⚠ FOUND${NC}"
    echo -e "    ${YELLOW}WARNING: aireplay-ng may hang without stdin redirect${NC}"
    grep -n "aireplay-ng" examples/*.sh | grep -v "</dev/null" | grep "&>/dev/null\|2>&1" | sed 's/^/      /'
    ((WARNINGS++))
else
    echo -e "${GREEN}✓${NC}"
fi

# Issue #3: Use of iwconfig (unreliable on BlackHat OS)
echo -ne "  Checking for iwconfig usage... "
if grep -q "iwconfig" examples/*.sh 2>/dev/null; then
    echo -e "${YELLOW}⚠ FOUND${NC}"
    echo -e "    ${YELLOW}WARNING: iwconfig is unreliable on BlackHat OS${NC}"
    echo -e "    Use 'iw dev' instead:"
    grep -n "iwconfig" examples/*.sh | sed 's/^/      /'
    ((WARNINGS++))
else
    echo -e "${GREEN}✓${NC}"
fi

# Issue #4: bh wifi list in monitor mode
echo -ne "  Checking for bh wifi list on monitor interface... "
if grep -q "bh wifi list.*wlan0" examples/*.sh 2>/dev/null; then
    echo -e "${YELLOW}⚠ POTENTIAL ISSUE${NC}"
    echo -e "    ${YELLOW}WARNING: 'bh wifi list' fails on monitor mode interfaces${NC}"
    echo -e "    Ensure interface is in managed mode first"
    ((WARNINGS++))
else
    echo -e "${GREEN}✓${NC}"
fi

# Issue #5: Missing set -euo pipefail
echo -ne "  Checking for strict mode... "
MISSING_STRICT=()
for script in examples/*.sh; do
    if ! grep -q "set -euo pipefail" "$script"; then
        MISSING_STRICT+=("$script")
    fi
done

if [ ${#MISSING_STRICT[@]} -gt 0 ]; then
    echo -e "${YELLOW}⚠ MISSING${NC}"
    echo -e "    ${YELLOW}WARNING: Some scripts missing 'set -euo pipefail'${NC}"
    printf '      %s\n' "${MISSING_STRICT[@]}"
    ((WARNINGS++))
else
    echo -e "${GREEN}✓${NC}"
fi

# Issue #6: while loops without stdin redirect
echo -ne "  Checking for while loops with stdin issues... "
if grep -n "while.*read" examples/*.sh | grep -v "</dev/null" | grep -q "<<"; then
    echo -e "${YELLOW}⚠ POTENTIAL ISSUE${NC}"
    echo -e "    ${YELLOW}WARNING: while read loops may hang without stdin redirect${NC}"
    echo -e "    Consider adding </dev/null to heredocs and pipes"
    ((WARNINGS++))
else
    echo -e "${GREEN}✓${NC}"
fi

echo ""

# ============================================================================
# 4. Python Validation
# ============================================================================
echo -e "${BLUE}4️⃣  Validating Python wrappers...${NC}"
if [ -d "flipper-wrappers" ]; then
    for script in flipper-wrappers/*.py; do
        if [[ ! -f "$script" ]]; then
            continue
        fi

        if python3 -m py_compile "$script" 2>&1; then
            echo -e "  ${GREEN}✓${NC} $script"
        else
            echo -e "  ${RED}✗${NC} $script - SYNTAX ERROR"
            ((ERRORS++))
        fi
    done
else
    echo -e "  ${YELLOW}⚠${NC} No Python wrappers directory found"
fi
echo ""

# ============================================================================
# 5. File Structure Validation
# ============================================================================
echo -e "${BLUE}5️⃣  Checking file structure...${NC}"

REQUIRED_FILES=(
    "examples/01-recon-pipeline.sh"
    "examples/02-handshake-capture.sh"
    "examples/04-deauth-campaign.sh"
    "examples/05-network-monitor.sh"
    "deploy.sh"
    "MANUAL.md"
    "README.md"
)

for file in "${REQUIRED_FILES[@]}"; do
    if [[ -f "$file" ]]; then
        echo -e "  ${GREEN}✓${NC} $file"
    else
        echo -e "  ${RED}✗${NC} $file - MISSING"
        ((ERRORS++))
    fi
done
echo ""

# ============================================================================
# 6. Deployment Script Check
# ============================================================================
echo -e "${BLUE}6️⃣  Checking deployment configuration...${NC}"

if [[ -f "deploy.sh" ]]; then
    # Check if deploy script is executable
    if [[ -x "deploy.sh" ]]; then
        echo -e "  ${GREEN}✓${NC} deploy.sh is executable"
    else
        echo -e "  ${YELLOW}⚠${NC} deploy.sh not executable (run: chmod +x deploy.sh)"
        ((WARNINGS++))
    fi

    # Check for hardcoded credentials (security check)
    if grep -q "PASSWORD=.*[^#]" deploy.sh 2>/dev/null; then
        echo -e "  ${YELLOW}⚠${NC} Deploy script contains hardcoded credentials"
        echo -e "    Consider using environment variables"
        ((WARNINGS++))
    else
        echo -e "  ${GREEN}✓${NC} No hardcoded credentials detected"
    fi
fi
echo ""

# ============================================================================
# Summary
# ============================================================================
echo -e "${BLUE}════════════════════════════════════════════${NC}"
echo -e "Summary:"
echo -e "  Errors:   ${RED}$ERRORS${NC}"
echo -e "  Warnings: ${YELLOW}$WARNINGS${NC}"
echo -e "${BLUE}════════════════════════════════════════════${NC}"
echo ""

if [ $ERRORS -eq 0 ]; then
    echo -e "${GREEN}✓ Validation PASSED${NC}"
    echo -e "  Scripts are safe to deploy to device"
    if [ $WARNINGS -gt 0 ]; then
        echo -e "  ${YELLOW}Note: $WARNINGS warnings found (non-critical)${NC}"
    fi
    exit 0
else
    echo -e "${RED}✗ Validation FAILED${NC}"
    echo -e "  Fix $ERRORS error(s) before deploying"
    exit 1
fi
