# Production Testing Lessons - Flipper Zero BlackHat OS Scripts

This document captures critical lessons learned from production testing on Flipper Zero WiFi Dev Board (BlackHat OS 6.15.0, Bash 5.2.37) at IP 192.168.178.122.

## Critical Bugs Found & Fixed

### 1. Directory Creation Timing Bug ⚠️ CRITICAL

**Problem**: Scripts call `log()` function before creating output directory, causing "No such file or directory" errors.

**Affected Scripts**:
- 02-handshake-capture.sh
- 03-evil-twin.sh
- 04-deauth-campaign.sh

**Root Cause**:
```bash
main() {
    print_banner()
    validate_args()  # ← calls log() which writes to ${OUTPUT_DIR}/file.log
    preflight_check()  # ← creates ${OUTPUT_DIR}
}
```

**Fix**: Always create output directory FIRST in main():
```bash
main() {
    print_banner()

    # Create output directory first (before any logging)
    mkdir -p "${OUTPUT_DIR}"

    validate_args()  # Now safe to call log()
    preflight_check()
}
```

**Prevention**: In ALL scripts with logging, add `mkdir -p "${OUTPUT_DIR}"` immediately after `print_banner()` in `main()`.

---

### 2. Bash Strict Mode with Associative Arrays ⚠️ CRITICAL

**Problem**: `set -euo pipefail` causes scripts to exit when checking if associative array key exists.

**Affected Scripts**:
- 05-network-monitor.sh

**Error**:
```bash
set -euo pipefail
declare -A myarray
if [[ -n "${myarray[$key]}" ]]; then  # ← ERROR: unbound variable
```

**Root Cause**: `-u` flag treats unset associative array keys as errors in Bash 5.2.37

**Fix #1** - Remove `-u` flag:
```bash
set -eo pipefail  # Remove 'u'
```

**Fix #2** - Use `-v` test for key existence:
```bash
if [[ -v myarray[$key] ]]; then  # Safe with -u flag
    # key exists
fi
```

**Prevention**:
- For scripts with associative arrays, use `set -eo pipefail` (not `-euo`)
- Always use `[[ -v array[key] ]]` to check key existence
- Never use `[[ -n "${array[$key]}" ]]` without checking existence first

---

### 3. Subshell Array Modification Loss ⚠️ CRITICAL

**Problem**: Command substitution creates subshell, array modifications are lost when subshell exits.

**Affected Scripts**:
- 05-network-monitor.sh

**Bad Pattern**:
```bash
declare -A last_seen
process_scan() {
    last_seen[$bssid]=$current_time  # Modified in subshell
    echo "$new_count,$disappeared"    # Return via stdout
}

# ❌ Creates subshell, array modifications lost
local results=$(process_scan "$scan_file")
echo "Networks: ${#last_seen[@]}"  # Always shows 0
```

**Fix**: Use global counters + direct function call (no command substitution):
```bash
# Global counters (not in subshell)
scan_new_count=0
scan_disappeared_count=0

process_scan() {
    last_seen[$bssid]=$current_time
    ((scan_new_count++))  # Modify global
    # NO echo statement for return values
}

# ✓ Call directly, no command substitution
process_scan "$scan_file"
echo "Networks: ${#last_seen[@]}"  # Correct count
echo "New: $scan_new_count"        # Access globals
```

**Prevention**:
- Never use `$(function_call)` when function modifies arrays/associative arrays
- Use global variables for return values when arrays are involved
- Remove echo statements used for return values

---

### 4. Parameter Order Anti-Patterns

**Problem**: Unintuitive parameter order confuses users during testing.

**Bad Examples**:
```bash
# 01-recon-pipeline.sh (original)
INTERFACE="${1:-wlan0}"
SCAN_DURATION="${2:-10}"     # ← Should be last (optional)
OUTPUT_DIR="${3:-/root/recon}"  # ← Should be second (semi-optional)

# 02-handshake-capture.sh (original)
INTERFACE="${1:-wlan0}"
TARGET_BSSID="${2:-}"
TARGET_CHANNEL="${3:-}"
TARGET_ESSID="${4:-}"  # ← Most important, but last?
```

**Best Practice Order**:
```bash
1. Primary interface (wlan0) - Always first for consistency
2. Target identifiers (BSSID, Channel, ESSID) - Required attack params
3. Optional modifiers (Output dir, timing) - Least important
```

**Good Examples**:
```bash
# 01-recon-pipeline.sh (fixed)
INTERFACE="${1:-wlan0}"
OUTPUT_DIR="${2:-/root/recon}"  # More important than duration
SCAN_DURATION="${3:-10}"        # Optional timing

# 02-handshake-capture.sh (fixed)
INTERFACE="${1:-wlan0}"
TARGET_BSSID="${2:-}"           # Primary target
TARGET_CHANNEL="${3:-}"         # Required for target
OUTPUT_DIR="${4:-/root/handshakes}"
TARGET_ESSID="${5:-}"           # Optional (auto-detected)
MAX_ATTEMPTS="${6:-5}"          # Optional tuning
```

---

### 5. Optional Parameter Validation

**Problem**: Required validation for parameters that can be auto-detected.

**Bad Pattern**:
```bash
validate_args() {
    if [[ -z "$TARGET_BSSID" ]] || [[ -z "$TARGET_CHANNEL" ]] || [[ -z "$TARGET_ESSID" ]]; then
        usage
        exit 1
    fi
}
```

**Issue**: TARGET_ESSID can be auto-detected from 802.11 beacon frames, shouldn't be required.

**Fix**:
```bash
validate_args() {
    # Only validate truly required params
    if [[ -z "$TARGET_BSSID" ]] || [[ -z "$TARGET_CHANNEL" ]]; then
        usage
        exit 1
    fi
    # TARGET_ESSID is optional, will be auto-detected
}
```

**Prevention**:
- Only require parameters that CANNOT be auto-detected or inferred
- Document auto-detection behavior in usage message
- Validate format, not just presence

---

## Testing Best Practices

### Pre-Flight Checklist

Before testing ANY script on Flipper Zero:

1. **Verify Interface Status**:
```bash
iw dev | grep -E '(Interface|type|addr)'
```

2. **Check Monitor Mode** (should be OFF before testing):
```bash
if iw dev wlan0 info | grep -q "type monitor"; then
    airmon-ng stop wlan0
fi
```

3. **Verify SSH Interface** (should be wlan1, NOT wlan0):
```bash
ip addr show wlan1 | grep "inet "
```

4. **Check for Running Processes**:
```bash
pgrep -a airodump  # Should be empty
pgrep -a aireplay  # Should be empty
```

### Testing Order (Safest → Most Disruptive)

1. **01-recon-pipeline.sh** - Passive scanning only
2. **05-network-monitor.sh** - Passive monitoring (Ctrl+C to stop)
3. **02-handshake-capture.sh** - Active (deauth), limited duration
4. **04-deauth-campaign.sh** - Active (continuous deauth until Ctrl+C)
5. **03-evil-twin.sh** - Most dangerous (rogue AP + deauth)

### Deployment Best Practices

**HTTP + wget Method** (95% token reduction vs SCP):
```bash
# Start HTTP server (port 8888)
cd /path/to/scripts
python3 -m http.server 8888 &

# Get local IP
LOCAL_IP=$(ifconfig | grep -Eo 'inet ([0-9]*\.){3}[0-9]*' | head -1 | awk '{print $2}')

# On Flipper, download with wget
ssh root@192.168.178.122
wget http://$LOCAL_IP:8888/script.sh -O /root/script.sh
chmod +x /root/script.sh
```

---

## BlackHat OS Specific Quirks

### Bash Version: 5.2.37
- Stricter associative array handling than older versions
- Unbound variable checks (`-u` flag) fail on missing array keys
- Use `set -eo pipefail` (not `-euo`) for array-heavy scripts

### CSV Line Endings
- `airodump-ng` writes Windows line endings (`\r\n`)
- Must convert before parsing: `tr -d '\r' < file.csv > file.csv.unix`

### Interface Management
- `wlan0` - Attack interface (monitor mode)
- `wlan1` - Management interface (SSH, internet)
- Never put wlan1 in monitor mode (will kill SSH session!)

### bh Commands
- BlackHat OS specific utilities
- Not available in standard Linux
- Check existence: `command -v bh &>/dev/null`

---

## Script Template Checklist

When generating new BlackHat OS scripts, ensure:

- [ ] `set -eo pipefail` (NOT `-euo` if using associative arrays)
- [ ] `mkdir -p "${OUTPUT_DIR}"` at start of `main()` before any `log()` calls
- [ ] Parameter order: Interface → Target IDs → Optional params
- [ ] Only validate truly required parameters
- [ ] Use `[[ -v array[key] ]]` for array key existence checks
- [ ] No command substitution `$(func)` when modifying arrays
- [ ] `trap` handlers for cleanup on INT/TERM
- [ ] Comprehensive error messages with troubleshooting tips
- [ ] Color-coded output (RED/GREEN/YELLOW/CYAN/NC)
- [ ] Timestamped logging with levels (INFO/WARN/ERROR/SUCCESS)
- [ ] Final report generation with all artifacts
- [ ] CSV line ending conversion for airodump-ng output

---

## Testing Results Summary

**Device**: Flipper Zero WiFi Dev Board
**OS**: BlackHat OS 6.15.0
**Bash**: 5.2.37
**IP**: 192.168.178.122
**Date**: 2025-10-28

| Script | Status | Notes |
|--------|--------|-------|
| 01-recon-pipeline.sh | ✅ PASS | 9 networks discovered, ranked correctly |
| 02-handshake-capture.sh | ✅ PASS | Captured WPA2 handshake on first attempt |
| 03-evil-twin.sh | ✅ FIXED | Directory bug fixed, not live-tested (too dangerous) |
| 04-deauth-campaign.sh | ✅ PASS | 3 deauth rounds completed successfully |
| 05-network-monitor.sh | ✅ PASS | Tracked 7 networks with correct signal strengths |

**Bugs Fixed**: 5 critical, 0 minor
**Deployment Method**: HTTP + wget (95% token reduction)
**Git Commit**: c8c651d

---

## Future Improvements

1. **Auto-detection enhancements**:
   - Detect ESSID from beacon frames in handshake capture
   - Auto-select strongest signal AP in deauth campaign

2. **Resilience**:
   - Retry logic for transient network failures
   - Graceful degradation when bh commands unavailable

3. **Reporting**:
   - JSON export for all reports (machine-readable)
   - Integration with external C2 frameworks

4. **Testing**:
   - Automated test suite for all scripts
   - Mock interfaces for safe testing without hardware
