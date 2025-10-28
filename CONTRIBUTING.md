# Contributing to Flipper BlackHat Skill

Thanks for your interest in contributing! This skill is designed to grow with community input.

## How to Contribute

### 1. Example Scripts (`examples/`)

We're always looking for practical, well-documented scripts:

**WiFi Scripts** (`examples/wifi-scripts/`)
- Auto-capture handshakes
- Mass deauth tools
- Evil twin automations
- Network mapping

**BadUSB Payloads** (`examples/badusb-payloads/`)
- HID injection scripts
- Rubber Ducky conversions
- Platform-specific exploits

**Sub-GHz Signals** (`examples/sub-ghz-signals/`)
- Signal analysis
- Replay attack tools
- Protocol decoders

**Script Guidelines:**
- Use bash for maximum compatibility
- Include header with purpose, usage, author
- Add error handling
- Document dependencies
- Test on actual hardware

### 2. Documentation Improvements

**Areas for expansion:**
- Troubleshooting patterns
- New attack vectors
- Defense testing workflows
- Hardware compatibility notes

### 3. New Modules

Planning to expand beyond WiFi:
- Bluetooth/BLE pentesting
- NFC/RFID attacks
- Sub-GHz analysis
- Multi-protocol attacks

## Contribution Process

1. **Fork** the repository
2. **Create branch**: `git checkout -b feature/your-feature`
3. **Make changes**
4. **Test** on real hardware if possible
5. **Commit**: Use clear, descriptive messages
6. **Push**: `git push origin feature/your-feature`
7. **Pull Request**: Describe your changes

## Code Style

### Bash Scripts
```bash
#!/bin/bash
# Script: script_name.sh
# Purpose: Brief description
# Author: Your Name
# Usage: ./script.sh [args]

set -e  # Exit on error

# Functions first
cleanup() {
    # Cleanup code
}
trap cleanup EXIT

# Main logic
main() {
    # Your code
}

main "$@"
```

### Documentation
- Use clear headings
- Provide practical examples
- Explain *why*, not just *how*
- Link to official docs when relevant

## Testing

Before submitting:
- [ ] Scripts run without errors
- [ ] Documentation is accurate
- [ ] Examples work on real hardware
- [ ] No hardcoded sensitive data

## Security Considerations

**DO NOT include:**
- Captured handshakes or credentials
- Real MAC addresses from non-test environments
- Personally identifiable information
- Actual network passwords

**DO include:**
- Placeholder values (e.g., `AA:BB:CC:DD:EE:FF`)
- Clear warnings about legal requirements
- Responsible disclosure guidance

## Questions?

Open an issue for:
- Feature requests
- Bug reports
- Documentation clarifications
- General questions

## Code of Conduct

This project follows a professional security researcher code of conduct:
- Respect legal boundaries
- Promote responsible disclosure
- Help others learn ethically
- No tolerance for malicious use

## Recognition

Contributors will be acknowledged in:
- README.md
- Release notes
- Script headers (for authored scripts)

---

**Remember**: This skill exists to improve security through authorized testing. Let's build something that makes the internet safer.
