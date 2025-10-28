# Testing & Development Setup - Quick Start

This document provides a quick overview of the testing infrastructure. For complete details, see [DEV_SETUP.md](DEV_SETUP.md).

## TL;DR - Start Here

```bash
# 1. One-command validation
./dev-tools/validate.sh

# 2. Test with mocks (no device needed!)
source dev-tools/mock-env.sh
./dev-tools/test-runner.sh examples/01-recon-pipeline.sh wlan0 5 /tmp/test

# 3. Deploy safely
./dev-tools/deploy-safe.sh root@192.168.178.122 password
```

## What Problems Does This Solve?

### Before (Pain Points)
- ❌ Must SSH to device for every test
- ❌ Scripts hang mysteriously with no debugging info
- ❌ No way to test without physical Flipper device
- ❌ Manual deployment, easy to break device
- ❌ No automated testing or CI/CD
- ❌ Device-specific bugs caught too late

### After (Solutions)
- ✅ Test locally with realistic mock environment
- ✅ Automatic hang detection with timeout
- ✅ Pre-deployment validation catches issues early
- ✅ Safe deployment with automatic rollback
- ✅ GitHub Actions CI/CD pipeline
- ✅ Fast development cycle

## Development Workflow

```
┌──────────────┐
│ Make Changes │
└──────┬───────┘
       │
       v
┌──────────────────┐
│ Run validate.sh  │  ← Catches syntax errors, common pitfalls
└──────┬───────────┘
       │
       v
┌──────────────────┐
│ Test with mocks  │  ← No device needed, fast feedback
└──────┬───────────┘
       │
       v
┌──────────────────┐
│ Git commit       │  ← Pre-commit hooks run automatically
└──────┬───────────┘
       │
       v
┌──────────────────┐
│ Deploy to device │  ← Safe deployment with rollback
└──────┬───────────┘
       │
       v
┌──────────────────┐
│ Test on device   │  ← Final validation
└──────────────────┘
```

## Tools Overview

| Tool | Purpose | When to Use |
|------|---------|-------------|
| **validate.sh** | Syntax check + static analysis | Before every commit |
| **test-runner.sh** | Run scripts with hang detection | Testing script changes |
| **mock-env.sh** | Activate offline testing | Development without device |
| **deploy-safe.sh** | Safe deployment with rollback | Deploying to device |

## Quick Examples

### Example 1: Fix a Script

```bash
# 1. Make changes
vim examples/01-recon-pipeline.sh

# 2. Validate
./dev-tools/validate.sh
# ✓ All checks passed

# 3. Test locally
source dev-tools/mock-env.sh
./dev-tools/test-runner.sh examples/01-recon-pipeline.sh wlan0 5 /tmp/test
# ✓ Script completed successfully (12s)

# 4. Commit
git add examples/01-recon-pipeline.sh
git commit -m "fix: resolve stdin hanging in parse_results()"
# Pre-commit hooks run automatically

# 5. Deploy
./dev-tools/deploy-safe.sh root@192.168.178.122 password
# ✓ Deployment successful!
```

### Example 2: Debug a Hanging Script

```bash
# Script times out after 30s
TEST_TIMEOUT=30 ./dev-tools/test-runner.sh examples/script.sh args

# Output shows:
# ✗ Script HUNG (exceeded 30s timeout)
# → Likely hung on aircrack-ng suite command
# → Check for missing '</dev/null' redirect

# Check validation for specific issue
./dev-tools/validate.sh | grep stdin
# Found airodump-ng without stdin redirect at line 123

# Fix the issue
vim examples/script.sh
# Add </dev/null to the problematic command

# Verify fix
./dev-tools/test-runner.sh examples/script.sh args
# ✓ Script completed successfully
```

### Example 3: Test New Feature

```bash
# Activate mock environment
source dev-tools/mock-env.sh

# Test individual commands
bh wifi list
airodump-ng wlan0 --write /tmp/scan
iw dev wlan0 info

# All commands return realistic output
# No device or root privileges needed!

# Test full script
./examples/01-recon-pipeline.sh wlan0 5 /tmp/recon
# Works offline with mocks
```

## What Gets Validated?

The validation script checks for:

### ✅ Syntax Errors
- Bash syntax (all .sh files)
- Python syntax (all .py files)

### ✅ Common Pitfalls
- **stdin hanging** - airodump-ng/aireplay-ng without `</dev/null`
- **iwconfig usage** - Should use `iw dev` instead
- **bh wifi list** in monitor mode - Will fail
- **Missing strict mode** - `set -euo pipefail`
- **while loops** without stdin redirects

### ✅ Static Analysis
- ShellCheck warnings/errors (if installed)
- Code quality issues

### ✅ Security
- Hardcoded credentials
- Private keys in repo

### ✅ File Structure
- Required scripts present
- Deployment script configured

## Mock Commands Available

All standard Flipper BlackHat OS commands are mocked:

```bash
# BlackHat OS commands
bh wifi list
bh wifi ap wlan0
bh evil_twin
bh evil_portal
bh deauth_all <bssid> <iface>
bh deauth_scan wlan0

# Aircrack-ng suite
airodump-ng wlan0 --write /tmp/scan
aireplay-ng --deauth 10 -a AA:BB:CC:DD:EE:FF wlan0
airmon-ng start wlan0

# Interface management
iw dev wlan0 info
iw dev wlan1 info
```

All mocks:
- Return realistic output formats (CSV, plain text, etc.)
- Simulate proper timing/delays
- Generate actual files where expected
- Work without root privileges
- Don't require actual network interfaces

## CI/CD Integration

### GitHub Actions
Automatically runs on every push:
- ✅ Syntax validation
- ✅ ShellCheck analysis
- ✅ Python validation
- ✅ BATS unit tests
- ✅ Security checks

See `.github/workflows/test.yml`

### Pre-commit Hooks
Automatically runs before every commit:
- ✅ ShellCheck on modified .sh files
- ✅ Black formatting on .py files
- ✅ Full validation suite
- ✅ Security checks

Install once:
```bash
pip install pre-commit
pre-commit install
```

## Installation

### Required Tools
```bash
# macOS
brew install shellcheck bats-core
brew install hudochenkov/sshpass/sshpass
pip install pre-commit

# Ubuntu
sudo apt-get install shellcheck bats sshpass
pip install pre-commit
```

### Optional but Recommended
```bash
brew install shfmt  # Shell script formatter
```

## Files Added

```
flipper-blackhat-skill/
├── DEV_SETUP.md                    # Comprehensive setup guide
├── TESTING.md                      # This file
├── .shellcheckrc                   # ShellCheck configuration
├── .pre-commit-config.yaml         # Pre-commit hooks config
│
├── dev-tools/                      # Development utilities
│   ├── README.md                   # Tool documentation
│   ├── validate.sh                 # Pre-deployment validation
│   ├── test-runner.sh              # Test harness with hang detection
│   ├── mock-env.sh                 # Mock environment activation
│   └── deploy-safe.sh              # Safe deployment with rollback
│
├── tests/                          # Test suite
│   ├── mocks/                      # Mock commands
│   │   ├── bh                      # Mock BlackHat OS commands
│   │   ├── airodump-ng             # Mock airodump-ng
│   │   ├── aireplay-ng             # Mock aireplay-ng
│   │   ├── iw                      # Mock iw command
│   │   └── airmon-ng               # Mock airmon-ng
│   │
│   ├── unit/                       # Unit tests
│   │   └── test-scripts.bats      # BATS test suite
│   │
│   ├── integration/                # Integration tests (future)
│   └── fixtures/                   # Test data (future)
│
└── .github/workflows/
    └── test.yml                    # CI/CD pipeline
```

## Common Issues & Solutions

### "Script hangs during test"
```bash
# Use test-runner with timeout
TEST_TIMEOUT=30 ./dev-tools/test-runner.sh script.sh args

# Check validation for stdin issues
./dev-tools/validate.sh | grep stdin
```

### "Mock commands not found"
```bash
# Activate mock environment
source dev-tools/mock-env.sh

# Or add to PATH manually
export PATH="$(pwd)/tests/mocks:$PATH"
```

### "Validation fails but script works on device"
```bash
# Check what specifically failed
./dev-tools/validate.sh 2>&1 | grep -E "ERROR|WARNING"

# Some warnings are non-critical
# Focus on fixing errors first
```

### "Deploy fails with connection error"
```bash
# Test connectivity first
ping 192.168.178.122

# Verify SSH works
ssh root@192.168.178.122 "echo OK"

# Check password is correct
# Check device is on network
```

## Performance Comparison

### Before (Manual Testing)
1. Edit script locally: **2 min**
2. SCP to device: **1 min**
3. SSH to device: **30 sec**
4. Test on device: **2 min**
5. Find bug, repeat: **5.5 min × N iterations**

**Total for 3 iterations: ~16.5 minutes**

### After (Mock Testing)
1. Edit script locally: **2 min**
2. Validate: **10 sec**
3. Test with mocks: **30 sec**
4. Fix bugs, repeat: **2.5 min × N iterations**
5. Deploy once when working: **2 min**

**Total for 3 iterations: ~11 minutes (33% faster)**

Plus:
- Fewer device reboots needed
- Less risk of bricking device
- Can work offline
- Parallel development possible

## Next Steps

1. **Read the complete guide**: [DEV_SETUP.md](DEV_SETUP.md)
2. **Install dependencies**: See "Installation" above
3. **Try the mock environment**:
   ```bash
   source dev-tools/mock-env.sh
   bh wifi list
   ```
4. **Set up pre-commit hooks**:
   ```bash
   pre-commit install
   ```
5. **Test a script**:
   ```bash
   ./dev-tools/test-runner.sh examples/01-recon-pipeline.sh wlan0 5 /tmp/test
   ```

## See Also

- [DEV_SETUP.md](DEV_SETUP.md) - Complete development setup guide
- [dev-tools/README.md](dev-tools/README.md) - Tool reference
- [CLAUDE.md](CLAUDE.md) - Development guidance for Claude
- [MANUAL.md](MANUAL.md) - User manual for scripts
- [examples/README.md](examples/README.md) - Script usage guide

---

**Questions?** Check [DEV_SETUP.md](DEV_SETUP.md) for detailed documentation.

**Found a bug?** The validation script should have caught it! If not, please improve the validation rules.
