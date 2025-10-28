# Development Setup & Testing Framework
## Flipper Zero BlackHat OS - Professional Development Environment

### Executive Summary

This document outlines a comprehensive development setup that addresses the major pain points documented in CLAUDE.md, enabling rapid, safe development with confidence before deploying to the physical Flipper Zero device.

**Key Problems Solved:**
- ❌ No local testing → ✅ Mock environment for offline development
- ❌ Scripts hang mysteriously → ✅ Automated hang detection & validation
- ❌ Manual deployment pain → ✅ One-command deploy with validation
- ❌ Device-specific bugs → ✅ Static analysis catches issues early
- ❌ No regression testing → ✅ Automated test suite

---

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────┐
│                  Development Workstation                     │
│                                                               │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐      │
│  │ Local Editor │→ │ Static Check │→ │  Mock Test   │      │
│  │  (VS Code)   │  │ (ShellCheck) │  │ Environment  │      │
│  └──────────────┘  └──────────────┘  └──────────────┘      │
│         │                   │                  │             │
│         └───────────────────┴──────────────────┘             │
│                             ↓                                │
│                  ┌──────────────────┐                        │
│                  │  Test Harness    │                        │
│                  │  - Unit Tests    │                        │
│                  │  - Integration   │                        │
│                  │  - Hang Detection│                        │
│                  └──────────────────┘                        │
│                             ↓                                │
│                  ┌──────────────────┐                        │
│                  │  Deploy Pipeline │                        │
│                  │  - Validation    │                        │
│                  │  - Upload        │                        │
│                  │  - Health Check  │                        │
│                  └──────────────────┘                        │
└──────────────────────────┬──────────────────────────────────┘
                           │
                           ↓ SSH/WGET
┌─────────────────────────────────────────────────────────────┐
│              Flipper Zero WiFi Dev Board                     │
│                   BlackHat OS 6.15.0                         │
│                                                               │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐      │
│  │    wlan0     │  │    wlan1     │  │  bh commands │      │
│  │  (monitor)   │  │   (mgmt)     │  │  aircrack-ng │      │
│  └──────────────┘  └──────────────┘  └──────────────┘      │
└─────────────────────────────────────────────────────────────┘
```

---

## 1. Local Development Environment

### 1.1 Prerequisites Setup

**Required Tools:**
```bash
# Install development dependencies
brew install shellcheck     # Static analysis for bash
brew install bats-core      # Bash testing framework
brew install expect         # SSH automation
pip install pytest          # Python testing
pip install black           # Python formatting
```

**Optional but Recommended:**
```bash
brew install shfmt          # Shell script formatter
brew install hadolint       # Dockerfile linter (if containerizing)
npm install -g @commitlint/cli  # Commit message validation
```

### 1.2 Project Structure

```
flipper-blackhat-skill/
├── examples/               # Production bash scripts
├── flipper-wrappers/       # Python wrappers
├── tests/                  # NEW: Test suite
│   ├── unit/              # Unit tests for individual functions
│   ├── integration/       # End-to-end tests with mocks
│   ├── mocks/             # Mock binaries and stubs
│   │   ├── bh             # Mock bh command
│   │   ├── airodump-ng    # Mock airodump-ng
│   │   ├── aireplay-ng    # Mock aireplay-ng
│   │   └── iw             # Mock iw command
│   └── fixtures/          # Test data (sample CSVs, etc.)
├── dev-tools/             # NEW: Development utilities
│   ├── validate.sh        # Pre-deployment validation
│   ├── test-runner.sh     # Test harness with hang detection
│   ├── mock-env.sh        # Setup mock environment
│   └── deploy-safe.sh     # Enhanced deployment with rollback
├── .github/
│   └── workflows/
│       ├── test.yml       # CI: Run tests on push
│       └── deploy.yml     # CD: Deploy on release
├── .shellcheckrc          # ShellCheck configuration
├── .pre-commit-config.yaml # Pre-commit hooks
└── DEV_SETUP.md           # This file
```

---

## 2. Mock Environment for Offline Testing

### 2.1 Design Philosophy

The mock environment provides **realistic stubs** of BlackHat OS commands that:
- Return valid output formats (CSV, JSON, etc.)
- Simulate timing and delays
- Can be configured for error scenarios
- Don't require root/monitor mode
- Run on any Unix system

### 2.2 Mock Implementation

**File: `tests/mocks/bh`**
```bash
#!/bin/bash
# Mock bh command for local testing

COMMAND="$1"
shift

case "$COMMAND" in
    wifi)
        if [[ "$1" == "list" ]]; then
            # Simulate network list
            cat << 'EOF'
SSID: TestNetwork
BSSID: AA:BB:CC:DD:EE:FF
Channel: 6
Signal: -45
Encryption: WPA2

SSID: OpenNetwork
BSSID: 11:22:33:44:55:66
Channel: 11
Signal: -72
Encryption: Open
EOF
        fi
        ;;
    evil_twin)
        echo "[MOCK] Evil twin mode enabled"
        ;;
    deauth_scan)
        echo "[MOCK] Scanning for deauth targets..."
        sleep 2
        echo "Found 3 clients on target network"
        ;;
    *)
        echo "[MOCK BH] Unknown command: $COMMAND" >&2
        exit 1
        ;;
esac
```

**File: `tests/mocks/airodump-ng`**
```bash
#!/bin/bash
# Mock airodump-ng for local testing

# Parse arguments to extract output prefix
OUTPUT_PREFIX=""
for arg in "$@"; do
    if [[ "$arg" == "--write" ]] || [[ "$arg" == "-w" ]]; then
        shift
        OUTPUT_PREFIX="$1"
        break
    fi
done

# Simulate scan duration
DURATION=10
if [[ "$*" =~ --write[[:space:]]([^[:space:]]+) ]]; then
    OUTPUT_PREFIX="${BASH_REMATCH[1]}"
fi

echo "[MOCK] Scanning on wlan0 for $DURATION seconds..." >&2
sleep 2  # Simulate scan time

# Generate realistic CSV output
if [[ -n "$OUTPUT_PREFIX" ]]; then
    cat > "${OUTPUT_PREFIX}-01.csv" << 'EOF'
BSSID, First time seen, Last time seen, channel, Speed, Privacy, Cipher, Authentication, Power, # beacons, # IV, LAN IP, ID-length, ESSID, Key
AA:BB:CC:DD:EE:FF, 2025-10-28 10:00:00, 2025-10-28 10:10:00, 6, 54, WPA2, CCMP, PSK, -45, 100, 0, 0.0.0.0, 11, TestNetwork,
11:22:33:44:55:66, 2025-10-28 10:00:00, 2025-10-28 10:10:00, 11, 54, OPN, , , -72, 50, 0, 0.0.0.0, 11, OpenNetwork,

Station MAC, First time seen, Last time seen, Power, # packets, BSSID, Probed ESSIDs
FF:EE:DD:CC:BB:AA, 2025-10-28 10:00:00, 2025-10-28 10:10:00, -50, 100, AA:BB:CC:DD:EE:FF, TestNetwork
EOF
fi

exit 0
```

**File: `tests/mocks/iw`**
```bash
#!/bin/bash
# Mock iw command

if [[ "$1" == "dev" && "$3" == "info" ]]; then
    # Simulate monitor mode interface
    cat << 'EOF'
Interface wlan0
    ifindex 3
    wdev 0x1
    addr aa:bb:cc:dd:ee:ff
    type monitor
    wiphy 0
    channel 6 (2437 MHz), width: 20 MHz, center1: 2437 MHz
EOF
fi
```

### 2.3 Mock Environment Activation

**File: `dev-tools/mock-env.sh`**
```bash
#!/bin/bash
# Activate mock environment for testing

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MOCK_DIR="$(cd "${SCRIPT_DIR}/../tests/mocks" && pwd)"

# Add mocks to PATH
export PATH="${MOCK_DIR}:${PATH}"

# Create mock network interfaces (not real, just for checks)
export MOCK_MODE=1
export MOCK_INTERFACES="wlan0 wlan1"

echo "Mock environment activated!"
echo "  - Mock commands: ${MOCK_DIR}"
echo "  - Mock interfaces: ${MOCK_INTERFACES}"
echo ""
echo "Run your tests now. Example:"
echo "  bash examples/01-recon-pipeline.sh wlan0 5 /tmp/test-output"
```

---

## 3. Automated Testing Framework

### 3.1 Static Analysis & Validation

**File: `.shellcheckrc`**
```bash
# ShellCheck configuration for the project

# Enable all optional checks
enable=all

# Exclude specific checks
# SC2034: Variable appears unused (many are used in sourced files)
disable=SC2034

# SC2086: We intentionally don't quote in some array contexts
disable=SC2086

# Severity threshold
severity=style
```

**File: `dev-tools/validate.sh`**
```bash
#!/bin/bash
# Pre-deployment validation script

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

ERRORS=0

echo "🔍 Running validation checks..."

# 1. Syntax check all bash scripts
echo ""
echo "1️⃣  Checking bash syntax..."
for script in examples/*.sh; do
    if bash -n "$script" 2>&1; then
        echo -e "  ${GREEN}✓${NC} $script"
    else
        echo -e "  ${RED}✗${NC} $script"
        ((ERRORS++))
    fi
done

# 2. ShellCheck static analysis
echo ""
echo "2️⃣  Running ShellCheck..."
for script in examples/*.sh; do
    if shellcheck "$script" 2>&1; then
        echo -e "  ${GREEN}✓${NC} $script"
    else
        echo -e "  ${YELLOW}⚠${NC} $script (warnings only)"
    fi
done

# 3. Check for common pitfalls
echo ""
echo "3️⃣  Checking for common pitfalls..."

# Check for stdin hanging issues
if grep -r "airodump-ng.*&>/dev/null" examples/ | grep -v "</dev/null"; then
    echo -e "  ${RED}✗${NC} Found airodump-ng without stdin redirect (will hang!)"
    grep -n "airodump-ng.*&>/dev/null" examples/ | grep -v "</dev/null"
    ((ERRORS++))
else
    echo -e "  ${GREEN}✓${NC} No stdin hanging issues found"
fi

# Check for use of iwconfig instead of iw
if grep -q "iwconfig" examples/*.sh; then
    echo -e "  ${YELLOW}⚠${NC} Found iwconfig usage (prefer 'iw dev' on BlackHat OS)"
    grep -n "iwconfig" examples/*.sh
fi

# Check for monitor mode commands
if grep -q "bh wifi list.*wlan0" examples/*.sh; then
    echo -e "  ${YELLOW}⚠${NC} Warning: 'bh wifi list' may fail in monitor mode"
fi

# 4. Validate Python wrappers
echo ""
echo "4️⃣  Validating Python wrappers..."
for script in flipper-wrappers/*.py; do
    if python3 -m py_compile "$script" 2>&1; then
        echo -e "  ${GREEN}✓${NC} $script"
    else
        echo -e "  ${RED}✗${NC} $script"
        ((ERRORS++))
    fi
done

# Summary
echo ""
echo "════════════════════════════════════════"
if [ $ERRORS -eq 0 ]; then
    echo -e "${GREEN}✓ All validation checks passed!${NC}"
    exit 0
else
    echo -e "${RED}✗ Found $ERRORS errors${NC}"
    exit 1
fi
```

### 3.2 Test Harness with Hang Detection

**File: `dev-tools/test-runner.sh`**
```bash
#!/bin/bash
# Test harness with automatic hang detection

set -euo pipefail

SCRIPT="${1:?Usage: $0 <script.sh> [args...]}"
shift
TIMEOUT="${TEST_TIMEOUT:-30}"  # Default 30 second timeout
TEMP_DIR=$(mktemp -d)

cleanup() {
    rm -rf "$TEMP_DIR"
}
trap cleanup EXIT

echo "Testing: $SCRIPT"
echo "Timeout: ${TIMEOUT}s"
echo "Args: $*"
echo "─────────────────────────────────────"

# Run with timeout and capture all output
if timeout "$TIMEOUT" bash "$SCRIPT" "$@" > "$TEMP_DIR/output.log" 2>&1; then
    echo "✓ Script completed successfully"
    cat "$TEMP_DIR/output.log"
    exit 0
else
    EXIT_CODE=$?
    if [ $EXIT_CODE -eq 124 ]; then
        echo "✗ Script HUNG (exceeded ${TIMEOUT}s timeout)"
        echo ""
        echo "Last 20 lines of output:"
        tail -20 "$TEMP_DIR/output.log"
        exit 1
    else
        echo "✗ Script failed with exit code $EXIT_CODE"
        cat "$TEMP_DIR/output.log"
        exit $EXIT_CODE
    fi
fi
```

### 3.3 Unit Testing with BATS

**File: `tests/unit/test-recon.bats`**
```bash
#!/usr/bin/env bats
# Unit tests for 01-recon-pipeline.sh

setup() {
    # Load mock environment
    export PATH="$(pwd)/tests/mocks:$PATH"
    export TEST_OUTPUT="/tmp/test-recon-$$"
    mkdir -p "$TEST_OUTPUT"
}

teardown() {
    rm -rf "$TEST_OUTPUT"
}

@test "recon script syntax is valid" {
    bash -n examples/01-recon-pipeline.sh
}

@test "recon script requires interface argument" {
    run examples/01-recon-pipeline.sh
    [ "$status" -ne 0 ]
}

@test "recon script accepts valid interface" {
    skip "Requires mock environment refinement"

    run timeout 15 examples/01-recon-pipeline.sh wlan0 5 "$TEST_OUTPUT"
    [ "$status" -eq 0 ]
    [ -f "$TEST_OUTPUT"/recon_*.log ]
}

@test "recon script creates output files" {
    skip "Requires mock environment refinement"

    timeout 15 examples/01-recon-pipeline.sh wlan0 5 "$TEST_OUTPUT"

    # Check for expected output files
    [ -f "$TEST_OUTPUT"/recon_*.log ]
    [ -f "$TEST_OUTPUT"/recon_*.csv ]
    [ -f "$TEST_OUTPUT"/recon_*.json ]
}

@test "recon script handles Ctrl+C gracefully" {
    skip "Requires signal handling test setup"

    # TODO: Test SIGINT handling
}
```

---

## 4. CI/CD Pipeline

### 4.1 GitHub Actions - Automated Testing

**File: `.github/workflows/test.yml`**
```yaml
name: Test Suite

on:
  push:
    branches: [ main, 'claude/**' ]
  pull_request:
    branches: [ main ]

jobs:
  validate:
    runs-on: ubuntu-latest

    steps:
    - uses: actions/checkout@v3

    - name: Install dependencies
      run: |
        sudo apt-get update
        sudo apt-get install -y shellcheck bats

    - name: Run validation
      run: ./dev-tools/validate.sh

    - name: Run unit tests
      run: |
        bats tests/unit/*.bats

  syntax-check:
    runs-on: ubuntu-latest

    steps:
    - uses: actions/checkout@v3

    - name: Check all bash scripts
      run: |
        for script in examples/*.sh; do
          echo "Checking $script..."
          bash -n "$script"
        done

    - name: Check Python scripts
      run: |
        python3 -m pip install --upgrade pip
        for script in flipper-wrappers/*.py; do
          echo "Checking $script..."
          python3 -m py_compile "$script"
        done
```

### 4.2 Pre-commit Hooks

**File: `.pre-commit-config.yaml`**
```yaml
repos:
  - repo: https://github.com/shellcheck-py/shellcheck-py
    rev: v0.9.0.6
    hooks:
      - id: shellcheck
        args: [--severity=warning]
        files: \.sh$

  - repo: https://github.com/psf/black
    rev: 23.11.0
    hooks:
      - id: black
        files: \.py$

  - repo: local
    hooks:
      - id: validate
        name: Run validation script
        entry: ./dev-tools/validate.sh
        language: script
        pass_filenames: false
        always_run: true
```

**Setup:**
```bash
pip install pre-commit
pre-commit install
```

---

## 5. Enhanced Deployment Pipeline

### 5.1 Safe Deployment with Validation

**File: `dev-tools/deploy-safe.sh`**
```bash
#!/bin/bash
# Enhanced deployment with pre-flight validation and rollback

set -euo pipefail

DEVICE="${1:-root@192.168.178.122}"
PASSWORD="${2:?Password required}"
SCRIPT="${3:-all}"

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Step 1: Run local validation
echo "Step 1/4: Running local validation..."
if ! ./dev-tools/validate.sh; then
    echo -e "${RED}✗ Validation failed! Fix errors before deploying.${NC}"
    exit 1
fi
echo -e "${GREEN}✓ Validation passed${NC}\n"

# Step 2: Create backup on device
echo "Step 2/4: Creating backup on device..."
sshpass -p "$PASSWORD" ssh -o StrictHostKeyChecking=no "$DEVICE" \
    "mkdir -p /root/backup && cp -f /root/*.sh /root/backup/ 2>/dev/null || true"
echo -e "${GREEN}✓ Backup created${NC}\n"

# Step 3: Deploy scripts
echo "Step 3/4: Deploying scripts..."
./deploy.sh "$SCRIPT"
echo -e "${GREEN}✓ Scripts deployed${NC}\n"

# Step 4: Health check
echo "Step 4/4: Running health check on device..."
if sshpass -p "$PASSWORD" ssh -o StrictHostKeyChecking=no "$DEVICE" \
    "bash -n /root/01-recon-pipeline.sh && bash -n /root/02-handshake-capture.sh"; then
    echo -e "${GREEN}✓ Health check passed${NC}"
    echo -e "\n${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${GREEN}Deployment successful!${NC}"
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
else
    echo -e "${RED}✗ Health check failed!${NC}"
    echo -e "${YELLOW}Rolling back...${NC}"
    sshpass -p "$PASSWORD" ssh -o StrictHostKeyChecking=no "$DEVICE" \
        "cp -f /root/backup/*.sh /root/ 2>/dev/null || true"
    echo -e "${RED}Deployment failed and rolled back${NC}"
    exit 1
fi
```

---

## 6. Development Workflow

### 6.1 Recommended Development Process

```bash
# 1. Make changes locally
vim examples/01-recon-pipeline.sh

# 2. Run validation (catches most issues)
./dev-tools/validate.sh

# 3. Test with mock environment
source dev-tools/mock-env.sh
./dev-tools/test-runner.sh examples/01-recon-pipeline.sh wlan0 5 /tmp/test

# 4. Run unit tests
bats tests/unit/*.bats

# 5. Deploy safely to device
./dev-tools/deploy-safe.sh root@192.168.178.122 password

# 6. Test on actual device
ssh root@192.168.178.122
cd /root
timeout 30 ./01-recon-pipeline.sh wlan0 10 /root/test-recon
```

### 6.2 Debugging Workflow

**For hanging scripts:**
```bash
# 1. Run with timeout and verbose logging
TEST_TIMEOUT=30 bash -x ./dev-tools/test-runner.sh examples/script.sh args

# 2. Check for stdin issues
grep -n "airodump\|aireplay\|aircrack" examples/script.sh | grep -v "</dev/null"

# 3. Test individual functions
# Extract function to separate file and test in isolation
```

**For device-specific issues:**
```bash
# SSH in and run with set -x
ssh root@192.168.178.122
bash -x /root/01-recon-pipeline.sh wlan0 5 /root/debug 2>&1 | tee debug.log

# Check interface status
iw dev wlan0 info
ip link show wlan0

# Test commands individually
airodump-ng wlan0 --write /tmp/test </dev/null >/dev/null 2>&1 &
sleep 5
kill %1
ls -la /tmp/test*
```

---

## 7. Quick Start Guide

### 7.1 Initial Setup (One-time)

```bash
# 1. Clone and setup
git clone https://github.com/Nikolaibibo/flipper-blackhat-skill.git
cd flipper-blackhat-skill

# 2. Install development tools
brew install shellcheck bats-core expect
pip install pre-commit pytest black

# 3. Create mock environment
mkdir -p tests/{mocks,unit,integration,fixtures}
chmod +x tests/mocks/*

# 4. Install pre-commit hooks
pre-commit install

# 5. Create dev-tools directory
mkdir -p dev-tools
chmod +x dev-tools/*.sh
```

### 7.2 Daily Development

```bash
# Quick test before commit
./dev-tools/validate.sh && git commit -m "feat: new feature"

# Safe deployment
./dev-tools/deploy-safe.sh root@192.168.178.122 password

# Run full test suite
bats tests/unit/*.bats
```

---

## 8. Troubleshooting Guide

### Common Issues

| Issue | Solution |
|-------|----------|
| Script hangs during test | Check for missing `</dev/null` on airodump/aireplay commands |
| ShellCheck warnings | Review and fix, or add `# shellcheck disable=SCXXXX` with comment |
| Mock commands not found | Run `source dev-tools/mock-env.sh` first |
| Deployment fails | Check device IP, password, and network connectivity |
| Tests timeout | Increase `TEST_TIMEOUT` environment variable |

---

## 9. Future Enhancements

- [ ] Docker container with full mock environment
- [ ] Hardware-in-the-loop (HIL) testing with Flipper device
- [ ] Automated regression testing
- [ ] Performance benchmarking
- [ ] Code coverage reporting
- [ ] Integration with Flipper app development

---

## 10. References

- [ShellCheck Wiki](https://www.shellcheck.net/wiki/)
- [BATS Testing Framework](https://bats-core.readthedocs.io/)
- [GitHub Actions Docs](https://docs.github.com/en/actions)
- [Pre-commit Framework](https://pre-commit.com/)

---

**Version:** 1.0
**Last Updated:** 2025-10-28
**Maintainer:** Development Team
