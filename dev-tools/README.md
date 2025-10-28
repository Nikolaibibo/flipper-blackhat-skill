# Development Tools

Professional development utilities for Flipper Zero BlackHat OS scripts.

## Quick Start

```bash
# 1. Validate before committing
./dev-tools/validate.sh

# 2. Test with mock environment
source dev-tools/mock-env.sh
./dev-tools/test-runner.sh examples/01-recon-pipeline.sh wlan0 5 /tmp/test

# 3. Deploy safely to device
./dev-tools/deploy-safe.sh root@192.168.178.122 password
```

## Tools Overview

### validate.sh
**Purpose:** Pre-deployment validation and static analysis

**Features:**
- Bash syntax checking
- ShellCheck static analysis
- Detects common pitfalls (stdin hanging, iwconfig usage, etc.)
- Python syntax validation
- File structure verification

**Usage:**
```bash
./dev-tools/validate.sh
```

**Exit Codes:**
- `0`: All checks passed
- `1`: Errors found (fix before deploying)

**Example Output:**
```
╔════════════════════════════════════════════╗
║    Flipper BlackHat Validation Suite      ║
╚════════════════════════════════════════════╝

1️⃣  Checking bash syntax...
  ✓ examples/01-recon-pipeline.sh
  ✓ examples/02-handshake-capture.sh

2️⃣  Running ShellCheck...
  ✓ examples/01-recon-pipeline.sh

3️⃣  Checking for known pitfalls...
  ✓ No stdin hanging issues found

Summary:
  Errors:   0
  Warnings: 0

✓ Validation PASSED
```

---

### test-runner.sh
**Purpose:** Run scripts with automatic hang detection

**Features:**
- Configurable timeout (default 30s)
- Captures all output to log file
- Detects and reports hanging scripts
- Shows last N lines of output on failure
- Execution time tracking

**Usage:**
```bash
./dev-tools/test-runner.sh <script.sh> [args...]

# Custom timeout
TEST_TIMEOUT=60 ./dev-tools/test-runner.sh examples/01-recon-pipeline.sh wlan0 10 /tmp/test
```

**Example Output:**
```
╔════════════════════════════════════════════╗
║      Flipper BlackHat Test Runner          ║
╚════════════════════════════════════════════╝

Script:   examples/01-recon-pipeline.sh
Timeout:  30s
Args:     wlan0 5 /tmp/test
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

[*] Running script...

✓ Script completed successfully
  Duration: 12s
```

**Hang Detection:**
If a script hangs, you'll see:
```
✗ Script HUNG (exceeded 30s timeout)
  Duration: 30s

Debugging tips:
  1. Check for commands reading stdin without </dev/null
  2. Look for 'read' commands in loops

Last 30 lines of output:
[Shows output...]

Analyzing hang location...
  → Likely hung on aircrack-ng suite command
  → Check for missing '</dev/null' redirect
```

---

### mock-env.sh
**Purpose:** Activate mock environment for offline testing

**Features:**
- Provides mock versions of BlackHat OS commands
- No root/hardware required
- Generates realistic output
- Can be sourced for persistent activation

**Usage:**
```bash
# Activate in current shell
source dev-tools/mock-env.sh

# Now test with mocks
bh wifi list
airodump-ng wlan0 --write /tmp/scan
iw dev wlan0 info

# Run scripts with mocks
./examples/01-recon-pipeline.sh wlan0 5 /tmp/test

# Deactivate when done
deactivate
```

**Standalone execution:**
```bash
# Just show info (doesn't activate)
./dev-tools/mock-env.sh
```

**Example Output:**
```
╔════════════════════════════════════════════╗
║     Mock Environment Activated             ║
╚════════════════════════════════════════════╝

✓ Mock commands enabled
  Path: /path/to/tests/mocks

Available mock commands:
  • bh
  • airodump-ng
  • aireplay-ng
  • iw
  • airmon-ng

Mock interfaces: wlan0 wlan1
Mock device IP:  192.168.178.122

Ready to test!
```

---

### deploy-safe.sh
**Purpose:** Enhanced deployment with validation and rollback

**Features:**
- Runs validation before deploying
- Tests device connectivity
- Creates backup before deployment
- Runs health checks after deployment
- Automatic rollback on failure

**Usage:**
```bash
./dev-tools/deploy-safe.sh [device] <password> [script|all]

# Deploy all scripts
./dev-tools/deploy-safe.sh root@192.168.178.122 password

# Deploy single script
./dev-tools/deploy-safe.sh root@192.168.178.122 password 01-recon-pipeline.sh
```

**Deployment Steps:**
1. Run local validation
2. Test device connectivity
3. Create backup on device
4. Deploy scripts
5. Run health checks

**Example Output:**
```
╔════════════════════════════════════════════╗
║    Safe Deployment to Flipper Device       ║
╚════════════════════════════════════════════╝

Target:   root@192.168.178.122
Scripts:  all

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Step 1/5: Running local validation...
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

[Validation output...]

✓ Validation passed

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Step 2/5: Testing device connectivity...
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

✓ Device reachable

[... more steps ...]

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
✓ Deployment successful!
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Backup location: /root/backup-20251028-143022
Device:          root@192.168.178.122

Next steps:
  1. SSH to device: ssh root@192.168.178.122
  2. Test a script: ./01-recon-pipeline.sh wlan0 10 /root/test
```

---

## Mock Commands

Located in `tests/mocks/`, these provide realistic simulations of BlackHat OS commands:

### bh (BlackHat OS commands)
```bash
bh wifi list              # List networks
bh wifi ap wlan0         # Start AP
bh evil_twin             # Enable evil twin
bh evil_portal           # Start portal
bh deauth_all <bssid> <iface>
bh deauth_scan wlan0
```

### airodump-ng
```bash
airodump-ng wlan0 --write /tmp/scan
# Creates realistic CSV with networks and clients
```

### aireplay-ng
```bash
aireplay-ng --deauth 10 -a AA:BB:CC:DD:EE:FF wlan0
```

### iw
```bash
iw dev wlan0 info        # Shows monitor mode
iw dev wlan1 info        # Shows managed mode
```

### airmon-ng
```bash
airmon-ng start wlan0
airmon-ng stop wlan0
```

---

## Development Workflow

### Standard Workflow

```bash
# 1. Make changes
vim examples/01-recon-pipeline.sh

# 2. Validate locally
./dev-tools/validate.sh

# 3. Test with mocks
source dev-tools/mock-env.sh
./dev-tools/test-runner.sh examples/01-recon-pipeline.sh wlan0 5 /tmp/test

# 4. Commit (pre-commit hooks run automatically)
git add examples/01-recon-pipeline.sh
git commit -m "fix: resolve stdin hanging issue"

# 5. Deploy to device
./dev-tools/deploy-safe.sh root@192.168.178.122 password

# 6. Test on device
ssh root@192.168.178.122
./01-recon-pipeline.sh wlan0 10 /root/test
```

### Debugging Hung Scripts

```bash
# 1. Run with test harness
TEST_TIMEOUT=30 ./dev-tools/test-runner.sh examples/script.sh args

# 2. Check validation for stdin issues
./dev-tools/validate.sh | grep "stdin"

# 3. Run with bash -x to trace execution
bash -x ./dev-tools/test-runner.sh examples/script.sh args

# 4. Test individual commands with mocks
source dev-tools/mock-env.sh
airodump-ng wlan0 --write /tmp/test </dev/null >/dev/null 2>&1 &
sleep 5
kill %1
```

---

## CI/CD Integration

### GitHub Actions

See `.github/workflows/test.yml` for automated testing.

**Triggers:**
- Push to `main` or `claude/**` branches
- Pull requests
- Manual workflow dispatch

**Jobs:**
- Syntax validation
- ShellCheck analysis
- Python validation
- BATS unit tests
- Security checks

### Pre-commit Hooks

Install once:
```bash
pip install pre-commit
pre-commit install
```

**Hooks:**
- ShellCheck on all .sh files
- Black formatting for Python
- Validation script execution
- File size checks
- Private key detection
- Trailing whitespace removal

---

## Requirements

### Required
- bash 4.0+
- Python 3.7+

### Optional (but recommended)
- `shellcheck` - Static analysis
- `bats` - Unit testing
- `sshpass` - Automated deployment
- `pre-commit` - Git hooks

### Installation

**macOS:**
```bash
brew install shellcheck bats-core
brew install hudochenkov/sshpass/sshpass
pip install pre-commit
```

**Ubuntu/Debian:**
```bash
sudo apt-get install shellcheck bats sshpass
pip install pre-commit
```

---

## Troubleshooting

### "sshpass not found"

**macOS:**
```bash
brew install hudochenkov/sshpass/sshpass
```

**Ubuntu:**
```bash
sudo apt-get install sshpass
```

### "ShellCheck not installed"

```bash
# macOS
brew install shellcheck

# Ubuntu
sudo apt-get install shellcheck
```

### "Mock commands not found"

Ensure you've activated the mock environment:
```bash
source dev-tools/mock-env.sh
```

Or add to PATH manually:
```bash
export PATH="$(pwd)/tests/mocks:$PATH"
```

### "Validation fails on working scripts"

Some warnings are non-critical. Check the specific issue:
```bash
./dev-tools/validate.sh 2>&1 | grep -A 5 "WARNING\|ERROR"
```

---

## See Also

- [DEV_SETUP.md](../DEV_SETUP.md) - Complete development setup guide
- [CLAUDE.md](../CLAUDE.md) - Development guidance for Claude sessions
- [MANUAL.md](../MANUAL.md) - User manual for scripts
- [examples/README.md](../examples/README.md) - Script usage guide
