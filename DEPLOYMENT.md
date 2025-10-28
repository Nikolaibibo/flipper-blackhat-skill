# Deployment Workflow

## Quick Deploy (Recommended)

```bash
# Deploy single script
./deploy.sh 05-network-monitor.sh

# Deploy all scripts
./deploy.sh all
```

The script automatically:
1. Starts HTTP server if needed (port 8888)
2. Uses wget on device to download files
3. Sets executable permissions

## Manual HTTP Server Method

If you need more control:

```bash
# Terminal 1: Start HTTP server
cd examples
python3 -m http.server 8888

# Terminal 2: Deploy via SSH
ssh root@192.168.178.122
wget http://192.168.178.189:8888/05-network-monitor.sh -O /root/05-network-monitor.sh
chmod +x /root/05-network-monitor.sh
```

## Tools Installed

- **sshpass**: For password-based SSH (installed via Homebrew)
  - Located: `/opt/homebrew/bin/sshpass`
  - Note: SCP doesn't work on device (no sftp-server)

## Device Info

- IP: `192.168.178.122`
- User: `root`
- Password: `niko0815`
- OS: BlackHat OS 6.15.0 (Flipper Zero WiFi Dev Board)

## Troubleshooting

**"Connection refused"**: HTTP server not running
```bash
cd examples && python3 -m http.server 8888 &
```

**"File not found"**: Wrong directory
```bash
# deploy.sh must be run from project root
cd /private/tmp/flipper-blackhat-skill
```

**Kill HTTP server**:
```bash
pkill -f 'python3 -m http.server 8888'
```
