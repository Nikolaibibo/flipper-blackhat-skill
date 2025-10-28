# Quick Start Guide

Get up and running with the Flipper BlackHat Skill in 5 minutes.

## Prerequisites

- Flipper Zero with WiFi Dev Board
- BlackHat OS installed
- Claude Desktop/API or Claude.ai with Projects

## Installation

### Option 1: Claude Desktop/API

```bash
# Navigate to your MCP skills directory
cd /path/to/mcp_server_files/skills/user/

# Clone the repository
git clone https://github.com/[your-username]/flipper-blackhat-skill

# Done! Claude will auto-load the skill
```

### Option 2: Claude.ai Web

1. Go to your Project in Claude.ai
2. Click "Add Content" → "Upload"
3. Upload `SKILL.md`
4. (Optional) Upload docs from `docs/wifi/` for enhanced context

## First Commands

### Test the Skill

**You**: "Flipper Zero handshake capture"

**Claude**: [Provides step-by-step bh commands]

### Example Workflows

#### 1. Network Reconnaissance
```
You: "Scan for WiFi networks with my Flipper"
Claude: Provides bh wifi list and bh kismet commands
```

#### 2. Handshake Capture
```
You: "Capture WPA2 handshake for network with BSSID AA:BB:CC:DD:EE:FF on channel 6"
Claude: Complete airodump-ng + bh deauth workflow
```

#### 3. Evil Twin Setup
```
You: "Create evil twin for 'CompanyWiFi' with credential harvesting"
Claude: Full setup with bh commands, hostapd, and captive portal
```

#### 4. Script Generation
```
You: "Write a bash script to auto-capture handshakes from all WPA2 networks"
Claude: Generates complete script with error handling
```

## Hardware Setup Reminder

**Dual-Radio Best Practice:**
- **wlan0** (onboard): SSH connection for remote access
- **wlan1** (USB dongle): Attack operations (monitor mode)

```bash
# Connect wlan0 for stable SSH
bh set SSID "YourNetwork"
bh set PASS "password"
bh wifi con wlan0

# Use wlan1 for attacks
bh deauth_scan wlan1
```

## Common Questions

### Q: Which commands does the skill know?

**A**: Complete `bh` tool suite + aircrack-ng + standard pentesting tools:
- `bh wifi *` - Network management
- `bh deauth *` - Deauthentication attacks
- `bh evil_twin` - MITM with internet
- `bh evil_portal` - Credential harvesting
- `bh kismet` - Packet capture
- `airodump-ng`, `aireplay-ng`, `aircrack-ng`
- `nmap`, `arpspoof`, `bettercap`

### Q: Does it work for other Flipper features?

**A**: Currently WiFi-focused. Planned expansions:
- Bluetooth/BLE
- NFC/RFID
- Sub-GHz
- BadUSB

### Q: Can it generate scripts?

**A**: Yes! The skill excels at:
- Bash automation scripts
- Attack chain workflows
- Custom tool integration
- Error handling and logging

### Q: What about legal/ethical guidance?

**A**: The skill:
- Shows one-time disclaimer on first use
- Assumes professional security testing context
- Provides technical guidance without repetitive warnings
- Redirects clearly malicious requests

## Tips for Best Results

### Be Specific
**Good**: "Capture handshake on channel 6, BSSID AA:BB:CC:DD:EE:FF"  
**Less Good**: "Help me with WiFi"

### Mention Hardware Context
"Using wlan1 on my Flipper" → Claude adjusts commands accordingly

### Ask for Explanations
"Why does deauth attack work?" → Get educational context

### Request Troubleshooting
"My handshake capture isn't working" → Systematic debugging

## Next Steps

1. **Read the docs**: `docs/wifi/` has comprehensive tutorials
2. **Explore examples**: Check `examples/` for pre-built scripts (coming soon)
3. **Experiment safely**: Use your own test network first
4. **Contribute**: Found a bug or have a script to share? See CONTRIBUTING.md

## Support

- **Issues**: GitHub Issues for bugs/features
- **Questions**: Open Discussion on GitHub
- **Documentation**: All docs in `docs/` directory

## Quick Reference Card

```bash
# Reconnaissance
bh wifi dev              # List interfaces
bh wifi list wlan0       # Scan networks
bh kismet wlan1          # Deep packet capture

# Attacks
bh deauth_scan wlan1                    # Find targets
bh deauth <client> <ap> wlan1           # Targeted deauth
bh deauth_all <ap> wlan1                # Disconnect all clients
bh evil_twin                            # MITM attack
bh evil_portal                          # Credential harvest

# Capture & Analysis
airodump-ng -c <ch> --bssid <mac> -w capture wlan1
aireplay-ng --deauth 50 -a <ap> -c <client> wlan1
aircrack-ng capture-01.cap

# System
bh get                   # View config
bh set SSID "network"    # Configure
bh wifi con wlan0        # Connect
bh ssh                   # Enable SSH
```

---

**Ready to go!** Start with "Help me scan for WiFi networks with my Flipper Zero" and explore from there.
