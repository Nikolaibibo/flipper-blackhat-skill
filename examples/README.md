# Flipper Zero BlackHat Pentesting Scripts

A comprehensive collection of automated WiFi penetration testing scripts for the Flipper Zero WiFi Dev Board running BlackHat OS.

## ⚠️ Legal Disclaimer

**These tools are for authorized penetration testing and security research only.**

- You MUST have written permission from network owners
- Unauthorized access is illegal under computer fraud laws
- These scripts are educational and for professional security testing
- The authors assume no liability for misuse

## Scripts Overview

### 01-recon-pipeline.sh (15KB)
**Automated WiFi Reconnaissance Pipeline**

Comprehensive target discovery and profiling with ranking and export capabilities.

**Usage:**
```bash
./01-recon-pipeline.sh [interface] [scan_duration] [output_dir]
```

**Features:**
- Airodump-ng integration for detailed scanning
- Target ranking by signal strength
- JSON/CSV export formats
- Interactive target selection
- Full logging and reporting

---

### 02-handshake-capture.sh (17KB)
**Smart WPA2 Handshake Capture**

Intelligent handshake capture with auto-retry and verification.

**Usage:**
```bash
./02-handshake-capture.sh <BSSID> <CHANNEL> <ESSID> [interface] [output_dir] [max_attempts]
```

**Features:**
- Client detection before deauth
- Escalating deauth strategies (5→10→20→50→100 packets)
- Automatic handshake verification
- Multi-attempt retry logic
- Next-steps cracking guidance

---

### 03-evil-twin.sh (18KB)
**Evil Twin Attack Automation**

Automated rogue AP deployment with optional credential capture.

**Usage:**
```bash
./03-evil-twin.sh <BSSID> <CHANNEL> <ESSID> [attack_iface] [inet_iface] [enable_portal] [output_dir]
```

**Features:**
- Rogue AP using bh commands
- Continuous client deauth
- Optional evil portal
- Internet passthrough
- Real-time connection monitoring

---

### 04-deauth-campaign.sh (18KB)
**Deauth Campaign Manager**

Sophisticated denial-of-service testing with multi-target support.

**Usage:**
```bash
./04-deauth-campaign.sh <MODE> [options]
```

**Modes:**
- `scan` - Interactive target discovery
- `single <BSSID>` - Attack single AP
- `multi <FILE>` - Batch attack from file
- `broadcast` - Attack all associations

**Features:**
- Multiple attack modes
- CSV statistics tracking
- Round-by-round logging
- Attack success metrics

---

### 05-network-monitor.sh (8KB)
**Network Health Monitor**

Continuous surveillance with anomaly detection.

**Usage:**
```bash
./05-network-monitor.sh [interface] [scan_interval] [output_dir] [watch_macs]
```

**Features:**
- Real-time network discovery
- Signal strength tracking
- Anomaly detection (new/disappeared networks)
- MAC address watchlist
- Alert logging

---

## Installation

1. Clone this repository to your Flipper Zero:
```bash
git clone https://github.com/Nikolaibibo/flipper-blackhat-skill.git
cd flipper-blackhat-skill/examples
```

2. Make scripts executable:
```bash
chmod +x *.sh
```

3. Run any script with `-h` or `--help` for detailed usage.

## Requirements

- Flipper Zero WiFi Dev Board
- BlackHat OS installed
- `aircrack-ng` suite
- `bh` command-line tool
- Monitor mode capable WiFi adapter

## Workflow Examples

### Basic Recon to Attack Flow

```bash
# 1. Discover targets
./01-recon-pipeline.sh wlan0 30

# 2. Capture handshake
./02-handshake-capture.sh AA:BB:CC:DD:EE:FF 6 'TargetWiFi'

# 3. Crack offline
aircrack-ng /root/captures/handshake_*.cap -w wordlist.txt
```

### Evil Twin Attack

```bash
# Setup evil twin with credential capture
./03-evil-twin.sh AA:BB:CC:DD:EE:FF 6 'CoffeeShop' wlan0 wlan1 true
```

### Continuous Monitoring

```bash
# Monitor for specific MAC addresses
./05-network-monitor.sh wlan0 15 /root/monitor AA:BB:CC:DD:EE:FF,11:22:33:44:55:66
```

## Output Structure

All scripts generate organized output:

```
/root/
├── recon/
│   ├── recon_TIMESTAMP.log
│   ├── recon_TIMESTAMP.json
│   ├── recon_TIMESTAMP.csv
│   └── report_TIMESTAMP.txt
├── captures/
│   ├── handshake_TIMESTAMP-01.cap
│   ├── capture_TIMESTAMP.log
│   └── report_TIMESTAMP.txt
├── evil-twin/
│   ├── evil-twin_TIMESTAMP.log
│   └── report_TIMESTAMP.txt
├── deauth-campaign/
│   ├── deauth_TIMESTAMP.log
│   ├── stats_TIMESTAMP.csv
│   └── report_TIMESTAMP.txt
└── monitor/
    ├── monitor_TIMESTAMP.log
    ├── networks.db
    └── alerts_TIMESTAMP.log
```

## Best Practices

1. **Always get authorization** before testing
2. **Test in isolated environments** first
3. **Document all activities** with logs
4. **Verify target networks** before attacking
5. **Restore services** after testing
6. **Follow responsible disclosure** for findings

## Troubleshooting

### Monitor Mode Issues
```bash
# Kill interfering processes
airmon-ng check kill

# Manually enable monitor mode
airmon-ng start wlan0
```

### No Handshake Captured
- Ensure clients are connected to target AP
- Move closer to target
- Increase max_attempts parameter
- Try different deauth strategies

### Evil Twin Not Working
- Verify both interfaces are available
- Check channel setting matches target
- Ensure hostapd is installed
- Review evil twin logs for errors

## Contributing

Improvements welcome! See [CONTRIBUTING.md](../CONTRIBUTING.md) for guidelines.

## Support

- Issues: https://github.com/Nikolaibibo/flipper-blackhat-skill/issues
- Documentation: See `docs/` directory
- Reference: `reference/blackhat-os-reference.md`

## License

MIT License - See [LICENSE](../LICENSE) for details.

---

**Remember: With great power comes great responsibility. Use these tools ethically and legally.**
