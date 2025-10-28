# CLAUDE.md - Flipper BlackHat Pentesting Skill

This file provides guidance for Claude Code sessions working on the Flipper Zero BlackHat WiFi pentesting scripts.

## Project Overview

**Purpose:** Comprehensive WiFi penetration testing automation for Flipper Zero WiFi Dev Board running BlackHat OS.

**Target Device:**
- Flipper Zero WiFi Dev Board
- BlackHat OS 6.15.0+
- Dual WiFi interfaces: wlan0 (attack/monitor), wlan1 (management)
- Tools: aircrack-ng suite, bh commands, Python 3.13

**Repository:** https://github.com/Nikolaibibo/flipper-blackhat-skill

## Architecture

### Script Categories

1. **Bash Scripts** (`examples/*.sh`) - Full-featured SSH scripts
   - 01-recon-pipeline.sh - WiFi reconnaissance
   - 02-handshake-capture.sh - WPA2 handshake capture
   - 03-evil-twin.sh - Rogue AP attacks
   - 04-deauth-campaign.sh - Deauth campaigns
   - 05-network-monitor.sh - Network monitoring
   - Deployed to: `/root/` on device

2. **Python Wrappers** (`flipper-wrappers/*.py`) - Flipper app triggers
   - wifi_recon.py, capture_handshake.py, etc.
   - Use `/root/target.conf` for configuration
   - Deployed to: `/mnt/scripts/` on device

3. **Documentation**
   - MANUAL.md - Comprehensive 20+ page reference
   - examples/README.md - Quick start guide
   - QUICK_REFERENCE.txt - Device cheat sheet

## Critical Technical Details

### Known Issues & Solutions

#### Issue #1: Script Hanging with Strict Mode (SOLVED)

**Problem:** Scripts hang when using `set -euo pipefail` with airodump-ng.

**Root Cause:** Airodump-ng reads from stdin even non-interactively. With strict mode + terminal-connected stdin = hang.

**Solution:** Always redirect stdin to /dev/null:
```bash
# Wrong - will hang:
airodump-ng wlan0 ... &>/dev/null || true

# Correct - works:
airodump-ng wlan0 ... </dev/null >/dev/null 2>&1 || true
```

**Commits:** 24aa227, 3cfe1ec, 71b1282, 358d1e3

#### Issue #2: Monitor Mode Detection

**Problem:** `iwconfig` doesn't work reliably on BlackHat OS.

**Solution:** Use `iw dev` instead:
```bash
# Wrong:
if iwconfig "${INTERFACE}" | grep "Mode:Monitor"; then

# Correct:
if iw dev "${INTERFACE}" info 2>/dev/null | grep -q "type monitor"; then
```

#### Issue #3: bh Commands in Monitor Mode

**Problem:** `bh wifi list wlan0` fails with "Operation not supported (-95)" when interface is in monitor mode.

**Solution:** Don't use `bh wifi list` on monitor mode interfaces. Use airodump-ng instead.

### Device Access

**SSH Connection:**
```bash
ssh root@192.168.178.122  # Default IP
# Password: (device-specific)
```

**File Transfer:**
- SCP not available (no sftp-server)
- Use heredoc over SSH or wget from GitHub
- Use `deploy.sh` script for automated deployment

### BlackHat OS Specifics

**Interface Management:**
- wlan0: Primary attack interface (usually in monitor mode)
- wlan1: Management interface (keeps SSH alive)
- DO NOT use airmon-ng if already in monitor mode
- Check mode: `iw dev wlan0 info`

**bh Commands:**
```bash
bh wifi ap <interface>        # Start access point
bh evil_twin                  # Enable evil twin mode
bh evil_portal                # Start credential portal
bh deauth_all <bssid> <iface> # Deauth all clients
bh deauth_scan <interface>    # Scan for deauth targets
```

**Aircrack-ng Suite:**
- airodump-ng: Network scanning & capture
- aireplay-ng: Injection & deauth
- aircrack-ng: Handshake cracking
- airmon-ng: Monitor mode (use carefully)

## Development Workflow

### Making Changes

1. **Always test on device first** - BlackHat OS has quirks
2. **Use strict mode** - `set -euo pipefail` catches bugs
3. **Redirect all I/O** - `</dev/null >/dev/null 2>&1`
4. **Test interactively first** - Then add to script
5. **Check for hanging** - Use `timeout` wrapper for testing

### Testing Scripts

```bash
# On device via SSH:
cd /root

# Quick syntax check:
bash -n ./01-recon-pipeline.sh

# Test with short duration:
./01-recon-pipeline.sh wlan0 5 /root/recon

# Monitor for hanging:
timeout 30 ./script.sh || echo "Script hung or failed"
```

### Adding New Scripts

1. Follow existing naming: `NN-descriptive-name.sh`
2. Include full banner and logging
3. Add pre-flight checks
4. Implement graceful Ctrl+C handling
5. Generate summary reports
6. Add to deploy.sh
7. Document in MANUAL.md and README.md

### Code Style

**Required Elements:**
```bash
#!/bin/bash
set -euo pipefail  # Strict mode

# Configuration with defaults
PARAM="${1:-default}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

# Logging function
log() {
    local level="$1"
    shift
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [$level] $*" | tee -a "$LOG_FILE"
}

# Cleanup function
cleanup() {
    log "INFO" "Cleaning up..."
    # Kill background processes
    # Remove temp files
}

# Trap for graceful exit
trap 'cleanup; exit 130' INT TERM
```

**I/O Redirection Pattern:**
```bash
# Interactive commands (need terminal):
command 2>&1

# Background processes (no terminal needed):
command </dev/null >/dev/null 2>&1 &

# Commands with timeout:
timeout 30 command </dev/null >/dev/null 2>&1 || true
```

## Deployment

### Quick Deploy (Recommended)

```bash
./deploy.sh 192.168.178.122 password
```

### Manual Deploy

Use heredoc over SSH (escape single quotes):
```bash
expect << 'EXPECTEOF'
spawn ssh root@192.168.178.122
expect "password:"
send "password\r"
expect "#"
send "cat > /root/script.sh << 'ENDFILE'\r"
send "#!/bin/bash\r"
send "# script contents...\r"
send "ENDFILE\r"
expect "#"
send "chmod +x /root/script.sh\r"
expect "#"
send "exit\r"
expect eof
EXPECTEOF
```

## Documentation Standards

### MANUAL.md Structure

- SSH vs Flipper App comparison
- Complete parameter reference
- Multiple examples per script
- Output file structure
- Workflow examples
- Troubleshooting guide
- Command reference

### Commit Message Format

```
<type>: <short description>

<detailed explanation>
- Bullet point changes
- Include file:line references
- Document root cause for fixes

Related commits: <hashes>

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>
```

Types: feat, fix, docs, refactor, test, chore

## Security & Ethics

**CRITICAL:** These tools are for **authorized penetration testing ONLY**.

When working on this project:
- Always include legal disclaimers
- Emphasize authorization requirements
- Document legitimate use cases only
- Don't add evasion techniques
- Focus on education & professional security testing

## Common Tasks

### Adding a New Script Feature

1. Research existing implementation patterns
2. Test command interactively on device
3. Add to script with proper error handling
4. Test with strict mode enabled
5. Update documentation
6. Commit with detailed message

### Fixing a Bug

1. Reproduce the issue on device
2. Identify root cause (check common issues above)
3. Test fix interactively first
4. Apply fix to all affected scripts
5. Verify with end-to-end test
6. Document in commit message

### Updating Documentation

1. Update examples/README.md for user-facing changes
2. Update MANUAL.md for detailed reference
3. Update CLAUDE.md for development notes
4. Keep QUICK_REFERENCE.txt concise

## Resources

- BlackHat OS Documentation: (device-specific)
- Aircrack-ng Wiki: https://www.aircrack-ng.org/
- Flipper Zero Docs: https://docs.flipper.net/
- Repository: https://github.com/Nikolaibibo/flipper-blackhat-skill

## Version History

- **v1.1 (2025-10-28)**: Fixed script hanging issue with stdin redirection
- **v1.0 (2025-10-27)**: Initial release with 5 scripts + Python wrappers

## Notes for Future Sessions

- wlan0 is usually already in monitor mode - don't run airmon-ng again
- Always test with `timeout` wrapper to catch hangs
- Device IP may change - verify with user
- Check for background processes before assuming crash
- Use expect for SSH automation, not sshpass (not available on macOS)
- Flipper device has limited storage - clean up test files
