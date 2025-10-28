# Teil 1: Passive WiFi Reconnaissance mit Kismet
## Flipper Zero WiFi Dev Board Pentesting Tutorial

---

## Inhaltsverzeichnis

1. [Einführung und Grundlagen](#1-einführung-und-grundlagen)
2. [802.11 Protokoll-Basics](#2-80211-protokoll-basics)
3. [Setup und Verbindung](#3-setup-und-verbindung)
4. [Kismet Grundlagen](#4-kismet-grundlagen)
5. [Passive Reconnaissance durchführen](#5-passive-reconnaissance-durchführen)
6. [Datenanalyse und Export](#6-datenanalyse-und-export)
7. [Praktische Übungen](#7-praktische-übungen)
8. [Command Cheatsheet](#8-command-cheatsheet)

---

## 1. Einführung und Grundlagen

### Was ist Passive Reconnaissance?

Passive Reconnaissance bedeutet, dass wir Netzwerke beobachten **ohne aktiv Pakete zu senden**. Wir setzen die WiFi-Karte in den "Monitor Mode" und lauschen dem Traffic, der sowieso durch die Luft gesendet wird.

**Vorteile:**
- Schwer zu detektieren (wir senden nichts)
- Legal in eigenem Netzwerk
- Gibt guten Überblick über die Umgebung
- Lernt Netzwerkstruktur kennen

**Was wir sammeln können:**
- Access Points (APs) und deren Eigenschaften
- Verbundene Clients (Geräte)
- Signal-Stärken und Kanäle
- Verschlüsselungstypen
- Versteckte SSIDs
- Vendor-Informationen (Hersteller)

### Rechtliche und Ethische Hinweise

⚠️ **WICHTIG:**
- **NUR in eigenen Netzwerken** testen
- Keine fremden Netzwerke ohne explizite Genehmigung
- Auch passives Lauschen kann in manchen Ländern rechtliche Grauzonen betreffen
- Diese Tutorials sind für **Bildungszwecke** und **autorisiertes Pentesting**
- Dokumentiere immer deine Autorisierung bei professionellem Testing

---

## 2. 802.11 Protokoll-Basics

### WiFi Frame-Typen

WiFi-Kommunikation basiert auf verschiedenen Frame-Typen. Die wichtigsten für passive Reconnaissance:

#### Management Frames
Diese Frames verwalten Verbindungen und sind im Monitor Mode sichtbar:

**Beacon Frames:**
- Werden von Access Points regelmäßig gesendet (normalerweise 10x pro Sekunde)
- Enthalten: SSID, unterstützte Geschwindigkeiten, Verschlüsselung, Kanal
- Auch versteckte SSIDs senden Beacons (nur mit leerem SSID-Feld)

**Probe Request/Response:**
- Probe Request: Client sucht nach bekannten Netzwerken
- Probe Response: AP antwortet auf Anfrage
- Gibt Aufschluss über Geräte-Historie (welche Netzwerke kennt ein Client?)

**Authentication/Association:**
- Zeigt aktive Verbindungsaufbauten
- Hilft bei Client-zu-AP Zuordnung

#### Data Frames
- Enthalten verschlüsselte Nutzdaten
- Im passiven Modus meist nur Metadaten interessant (Größe, Frequenz, Sender/Empfänger)

#### Control Frames
- RTS/CTS (Request to Send / Clear to Send)
- ACK (Acknowledgment)
- Zeigen Netzwerk-Aktivität und Performance

### WiFi Kanäle

WiFi nutzt verschiedene Frequenzbänder:

**2.4 GHz Band:**
- Kanäle 1-14 (regional unterschiedlich)
- Kanäle überlappen sich (nur 1, 6, 11 sind nicht-überlappend)
- Größere Reichweite, langsamer

**5 GHz Band:**
- Viele nicht-überlappende Kanäle
- Kürzere Reichweite, schneller
- Weniger Interferenzen

**Wichtig für Monitoring:**
- Eine WiFi-Karte kann nur einen Kanal gleichzeitig hören
- Kismet "hüpft" zwischen Kanälen (Channel Hopping)
- Je länger auf einem Kanal, desto mehr Daten, aber andere werden verpasst

### Verschlüsselungstypen

**Offen (None):**
- Kein Passwort
- Traffic unverschlüsselt
- Selten, aber existiert

**WEP (Wired Equivalent Privacy):**
- Veraltet und unsicher
- Kann in Minuten geknackt werden
- Sollte nicht mehr verwendet werden

**WPA/WPA2-PSK (Pre-Shared Key):**
- Standard für Heimnetzwerke
- Nutzt 4-Way-Handshake für Verbindungsaufbau
- Handshake kann captured und offline attackiert werden

**WPA2/WPA3-Enterprise:**
- Nutzt RADIUS-Server
- Individuelle Credentials pro User
- Sicherer als PSK

**WPA3:**
- Neuester Standard
- SAE (Simultaneous Authentication of Equals) statt 4-Way-Handshake
- Schwerer zu attackieren

---

## 3. Setup und Verbindung

### Verbindung zum Flipper herstellen

Du hast zwei Möglichkeiten:

#### Option 1: Serielle Konsole (USB)

**macOS:**
```bash
# Finde das Gerät
ls /dev/tty.usb*

# Verbinde (typischerweise):
screen /dev/tty.usbmodemflipperXXXXX 115200

# Alternativ mit minicom:
brew install minicom
minicom -D /dev/tty.usbmodemflipperXXXXX -b 115200
```

**Windows (PC):**
```bash
# Mit PuTTY:
# 1. Öffne PuTTY
# 2. Connection Type: Serial
# 3. Serial Line: COM3 (oder welcher COM-Port in Device Manager angezeigt wird)
# 4. Speed: 115200

# Oder mit Windows Terminal:
# Installiere Python und pyserial:
pip install pyserial
# Dann:
python -m serial.tools.miniterm COM3 115200
```

**Beenden:**
- screen: `Ctrl+A` dann `K` dann `Y`
- minicom: `Ctrl+A` dann `X`
- PuTTY: Fenster schließen

#### Option 2: SSH über WiFi

Voraussetzung: Flipper ist mit deinem WLAN verbunden (bereits konfiguriert via Captive Portal oder Config)

**Finde die IP-Adresse des Flippers:**

Auf dem Flipper (via Serial Console):
```bash
ip addr show wlan0
# Oder:
ifconfig wlan0
```

**Von deinem Laptop aus:**

```bash
# macOS/Linux:
ssh root@<FLIPPER_IP>

# Windows (mit OpenSSH oder PuTTY):
ssh root@<FLIPPER_IP>

# Beispiel:
ssh root@192.168.1.100
```

**Standard-Credentials (falls nicht geändert):**
- User: `root`
- Password: (prüfe Blackhat OS Dokumentation, oft kein Password oder `blackhat`)

### System-Check

Sobald verbunden, überprüfe das System:

```bash
# Zeige OS-Version
cat /etc/os-release

# Zeige verfügbare WiFi-Interfaces
iw dev

# Typischer Output:
# phy#0
#   Interface wlan0
#     ifindex 3
#     wdev 0x1
#     addr XX:XX:XX:XX:XX:XX
#     type managed

# Prüfe, ob Kismet installiert ist
which kismet
kismet --version

# Prüfe verfügbaren Speicherplatz (für Logs)
df -h
```

### WiFi-Interface in Monitor Mode setzen

**Wichtig:** Bevor wir Kismet starten, müssen wir verstehen, was Monitor Mode ist.

**Managed Mode (normal):**
- Interface ist mit einem AP verbunden
- Kann nur eigenen Traffic sehen
- Standard-Modus

**Monitor Mode:**
- Interface hört allen Traffic auf dem Kanal
- Nicht mit AP verbunden
- Benötigt für Packet Sniffing

**Manuell Monitor Mode aktivieren (zu Lernzwecken):**

```bash
# Stoppe Netzwerk-Manager (verhindert Interferenzen)
systemctl stop NetworkManager
# Oder auf manchen Systemen:
killall wpa_supplicant

# Interface herunterfahren
ip link set wlan0 down

# In Monitor Mode setzen
iw dev wlan0 set type monitor

# Interface wieder hochfahren
ip link set wlan0 up

# Verifizieren
iw dev wlan0 info
# "type monitor" sollte erscheinen

# Optional: Kanal setzen (z.B. Kanal 6)
iw dev wlan0 set channel 6
```

**Zurück zu Managed Mode:**
```bash
ip link set wlan0 down
iw dev wlan0 set type managed
ip link set wlan0 up
systemctl start NetworkManager
```

**Hinweis:** Kismet kann das Interface auch automatisch in Monitor Mode setzen. Wir machen das manuell zu Lernzwecken.

---

## 4. Kismet Grundlagen

### Was ist Kismet?

Kismet ist ein leistungsstarkes Wireless Network Detector, Sniffer und IDS (Intrusion Detection System). Es kann:
- Netzwerke passiv entdecken
- Detaillierte Informationen sammeln
- Daten für spätere Analyse speichern
- Über Web-Interface oder CLI bedient werden

### Kismet Konfiguration

Wichtige Config-Dateien:
```bash
# Haupt-Konfiguration
/etc/kismet/kismet.conf

# Oder im Home-Verzeichnis (überschreibt System-Config)
~/.kismet/kismet.conf
```

**Minimale Konfiguration prüfen/erstellen:**

```bash
# Erstelle User-Config falls nicht vorhanden
mkdir -p ~/.kismet

# Editiere Config
vi ~/.kismet/kismet.conf
# Oder:
nano ~/.kismet/kismet.conf
```

**Wichtige Config-Parameter:**

```bash
# Interface definieren (wlan0 in Monitor Mode)
source=wlan0

# Log-Verzeichnis (ausreichend Platz!)
log_prefix=/tmp/kismet

# Server binden (alle Interfaces, damit du vom Laptop zugreifen kannst)
httpd_bind_address=0.0.0.0
httpd_port=2501

# Channel Hopping aktivieren (durchläuft alle Kanäle)
channel_hop=true
channel_hop_speed=5  # Wechselt 5x pro Sekunde

# Alternativ: Auf spezifischen Kanälen bleiben
# channel_hop=false
# source=wlan0:channels="1,6,11"
```

### Kismet Starten

**Einfacher Start:**
```bash
# Mit Default-Config und als Root
kismet

# Mit spezifischem Interface
kismet -c wlan0
```

**Erweiterte Optionen:**
```bash
# Mit Custom-Config
kismet --config-file=~/.kismet/kismet.conf

# Verbose Output (für Debugging)
kismet -c wlan0 --verbose

# Im Hintergrund (Daemon)
kismet -c wlan0 --daemonize

# Nur ohne GUI (Terminal UI)
kismet_server -c wlan0
```

**Beim ersten Start:**
- Kismet fragt nach Username/Password für Web-Interface
- Wähle sichere Credentials!
- Diese werden in `~/.kismet/kismet_httpd.conf` gespeichert

**Kismet stoppen:**
```bash
# Wenn im Vordergrund: Ctrl+C

# Wenn als Daemon:
killall kismet
```

---

## 5. Passive Reconnaissance durchführen

### Zugriff auf Kismet Web-Interface

Kismet läuft auf dem Flipper, aber du greifst via Browser von deinem Laptop zu.

**Von Mac/PC aus:**

1. Öffne Browser (Chrome, Firefox, Safari)
2. Gehe zu: `http://<FLIPPER_IP>:2501`
3. Login mit den erstellten Credentials
4. Beispiel: `http://192.168.1.100:2501`

**Erste Schritte im Web-Interface:**

Das Interface ist in mehrere Bereiche unterteilt:

#### Dashboard
- Übersicht über aktive Scans
- Anzahl entdeckter Devices
- Channel Hopping Status
- Datenrate

#### Device List
Hauptansicht für entdeckte Geräte:
- **Type:** AP (Access Point), Client, Bridged, etc.
- **Name/SSID:** Netzwerkname
- **MAC Address:** Eindeutige Hardware-Adresse
- **Encryption:** Verschlüsselungstyp
- **Channel:** WiFi-Kanal
- **Signal:** Signalstärke (dBm)
- **Packets:** Anzahl empfangener Pakete
- **Manufacturer:** Hersteller (via MAC OUI Lookup)

#### Channels
Zeigt Aktivität pro Kanal:
- Wie viele APs/Clients pro Kanal
- Hilft bei Kanal-Optimierung
- Zeigt überlaufende Kanäle

### Netzwerke Identifizieren und Analysieren

#### Access Points (APs) verstehen

**Was verrät ein AP?**

Klicke auf einen AP in der Device List für Details:

```
SSID: MeinHeimNetz
MAC: AA:BB:CC:DD:EE:FF
Manufacturer: TP-Link
Encryption: WPA2-PSK
Channel: 6 (2.4 GHz)
Signal: -45 dBm (stark)
First Seen: 14:23:01
Last Seen: 14:28:45
Beacon Rate: 10/sec
```

**Signalstärke interpretieren:**
- -30 dBm = Ausgezeichnet (sehr nah)
- -50 dBm = Sehr gut (normale Entfernung)
- -60 dBm = Gut
- -70 dBm = Schwach
- -80 dBm = Sehr schwach
- -90 dBm = Kaum nutzbar

**Verschlüsselung:**
- "None" = Offenes Netzwerk (Sicherheitsrisiko!)
- "WEP" = Veraltet (extrem unsicher)
- "WPA" = Veraltet
- "WPA2-PSK" = Standard (sicher bei starkem Passwort)
- "WPA3" = Modern und sicher

#### Clients Identifizieren

**Was ist ein Client?**
- Jedes Gerät, das mit einem AP verbunden ist
- Smartphones, Laptops, IoT-Devices, etc.

**Client-Details:**
```
Type: WiFi Client
MAC: 11:22:33:44:55:66
Manufacturer: Apple
Connected to: MeinHeimNetz (AA:BB:CC:DD:EE:FF)
Signal: -50 dBm
Packets: 1234
Data: 15.6 MB
```

**Was verrät ein Client?**
- Manufacturer gibt Hinweis auf Gerätetyp (Apple = iPhone/Mac, Samsung = Android, etc.)
- Signal-Stärke zeigt Nähe zum AP
- Packet-Anzahl zeigt Aktivität
- Probe Requests zeigen bekannte Netzwerke (Historik)

#### Versteckte SSIDs entdecken

Manche APs senden Beacons ohne SSID (hidden network):

**Im Kismet:**
- SSID erscheint als `<Hidden SSID>` oder leer
- MAC-Adresse ist trotzdem sichtbar
- Manufacturer hilft bei Identifikation

**Wie versteckte SSID aufdecken?**
- Warte auf Client-Verbindung: Probe Request/Response verraten SSID
- Oder in Teil 2 (Active Recon) forcieren wir Probe Responses

### Channel Hopping vs. Fixed Channel

**Channel Hopping (Default):**
```bash
# Kismet wechselt automatisch zwischen Kanälen
# Gut für: Überblick über alle Netzwerke
# Nachteil: Verpasst Pakete während Kanal-Wechsel
```

**Fixed Channel (gezieltes Monitoring):**

Wenn du ein spezifisches Netzwerk detailliert überwachen willst:

```bash
# Stoppe Kismet
killall kismet

# Setze Interface auf festen Kanal (z.B. Kanal 6)
iw dev wlan0 set channel 6

# Starte Kismet ohne Channel Hopping
kismet -c wlan0 --override channelhop false
```

**Oder via Config:**
```bash
# In ~/.kismet/kismet.conf:
source=wlan0:hop=false,channel=6
```

---

## 6. Datenanalyse und Export

### Kismet Log-Dateien

Kismet speichert alle Daten automatisch. Standard-Location:

```bash
# Prüfe aktive Logs
ls -lh /tmp/kismet/

# Typische Dateien:
# Kismet-YYYYMMDD-HH-MM-SS.kismet  (Haupt-DB, SQLite)
# Kismet-YYYYMMDD-HH-MM-SS.pcapng  (Packet Capture)
# Kismet-YYYYMMDD-HH-MM-SS.log     (Text-Log)
```

### Logs vom Flipper auf deinen Laptop kopieren

**Via SCP (macOS/Linux/Windows mit OpenSSH):**

```bash
# Von deinem Laptop aus:
scp root@<FLIPPER_IP>:/tmp/kismet/*.pcapng ~/Desktop/kismet_captures/
scp root@<FLIPPER_IP>:/tmp/kismet/*.kismet ~/Desktop/kismet_captures/

# Beispiel:
scp root@192.168.1.100:/tmp/kismet/*.pcapng ~/Desktop/kismet_captures/
```

**Via WinSCP (Windows):**
1. Öffne WinSCP
2. Verbinde zu `<FLIPPER_IP>` mit root-Credentials
3. Navigiere zu `/tmp/kismet/`
4. Drag & Drop Dateien auf lokalen PC

### Analyse mit Wireshark (Mac/PC)

**Wireshark installieren:**

**macOS:**
```bash
brew install --cask wireshark

# Oder Download von: https://www.wireshark.org/download.html
```

**Windows:**
```bash
# Download Installer von: https://www.wireshark.org/download.html
# Installiere mit Admin-Rechten
```

**PCAP-Datei öffnen:**

```bash
# macOS Terminal:
wireshark ~/Desktop/kismet_captures/Kismet-20250101-120000.pcapng

# Oder GUI: Wireshark öffnen → File → Open
```

### Wireshark Filter für WiFi-Analyse

**Nur Beacon Frames:**
```
wlan.fc.type_subtype == 0x08
```

**Nur Probe Requests:**
```
wlan.fc.type_subtype == 0x04
```

**Nur Probe Responses:**
```
wlan.fc.type_subtype == 0x05
```

**Spezifischer Access Point (MAC):**
```
wlan.bssid == aa:bb:cc:dd:ee:ff
```

**Spezifischer Client:**
```
wlan.sa == 11:22:33:44:55:66
```

**Alle Management Frames:**
```
wlan.fc.type == 0
```

**Kombination (Beacons von spezifischem AP):**
```
wlan.fc.type_subtype == 0x08 && wlan.bssid == aa:bb:cc:dd:ee:ff
```

### Interessante Informationen extrahieren

**Im Wireshark:**

1. **Beacon Frames analysieren:**
   - Filter: `wlan.fc.type_subtype == 0x08`
   - Rechtsklick auf Frame → Follow → UDP Stream (nein, das geht nicht bei WiFi)
   - Besser: Frame Details aufklappen:
     ```
     IEEE 802.11 Beacon Frame
       → Tagged parameters
         → SSID
         → Supported Rates
         → DS Parameter Set (Channel)
         → RSN Information (Encryption)
     ```

2. **Probe Requests analysieren (Client-History):**
   - Filter: `wlan.fc.type_subtype == 0x04`
   - Zeigt welche SSIDs ein Client sucht
   - Verrät wo Gerät vorher war

3. **Signal-Stärke über Zeit:**
   - Statistics → WLAN Traffic
   - Zeigt Aktivität pro AP/Client

### Kismet Database mit kismetdb_dump_devices

Kismet-DB ist SQLite, aber besser via Tool auslesen:

**Auf dem Flipper:**
```bash
# Liste alle Devices
kismetdb_dump_devices --in /tmp/kismet/Kismet-20250101.kismet

# Als JSON exportieren
kismetdb_dump_devices --in /tmp/kismet/Kismet-20250101.kismet --json > devices.json

# JSON auf Laptop kopieren
scp root@<FLIPPER_IP>:/root/devices.json ~/Desktop/
```

**JSON analysieren (auf Mac/PC):**
```bash
# Mit Python (pretty print)
python3 -m json.tool devices.json

# Mit jq (muss installiert sein)
brew install jq  # macOS
cat devices.json | jq '.[] | select(.kismet.device.base.type == "Wi-Fi AP")'
```

---

## 7. Praktische Übungen

### Übung 1: Netzwerk-Inventar erstellen

**Ziel:** Erstelle eine Liste aller Access Points in deiner Umgebung.

**Schritte:**
1. Starte Kismet mit Channel Hopping
2. Lasse es 10 Minuten laufen
3. Exportiere Device-Liste
4. Erstelle Tabelle:

```
SSID          | MAC               | Kanal | Verschlüsselung | Signal | Hersteller
MeinNetz      | AA:BB:CC:DD:EE:FF | 6     | WPA2-PSK        | -45dBm | TP-Link
NachbarNetz   | 11:22:33:44:55:66 | 11    | WPA2-PSK        | -72dBm | Netgear
```

**Fragen:**
- Welcher Kanal ist am überfülltesten?
- Gibt es veraltete Verschlüsselung (WEP/WPA)?
- Welche APs sind am stärksten/schwächsten?

### Übung 2: Client-Tracking

**Ziel:** Identifiziere alle Clients in deinem Netzwerk.

**Schritte:**
1. Fokussiere auf dein eigenes Netzwerk (fester Kanal)
2. Identifiziere verbundene Clients
3. Ordne Clients Geräten zu (via Manufacturer)

**Fragen:**
- Wie viele Geräte sind verbunden?
- Erkennst du alle? (Überraschende IoT-Devices?)
- Welches Gerät ist am aktivsten? (meiste Pakete)

### Übung 3: Versteckte SSID entdecken

**Ziel:** Falls du ein hidden network hast, entdecke die SSID.

**Vorbereitung:**
- Konfiguriere einen alten Router/AP mit hidden SSID (nur für diesen Test)
- Oder nutze Feature deines Hauptrouters

**Schritte:**
1. Starte Kismet
2. Suche nach `<Hidden SSID>` Einträgen
3. Warte auf Client-Verbindung oder Reconnect
4. Beobachte Probe Request/Response

**Erkenntnis:**
- "Hidden" bedeutet nicht "unsichtbar"
- Jede Client-Verbindung verrät SSID

### Übung 4: Channel-Nutzung analysieren

**Ziel:** Finde den besten Kanal für dein WLAN.

**Schritte:**
1. Kismet mit Channel Hopping
2. Nach 15 Minuten: Channels-Tab im Web-Interface
3. Notiere Anzahl APs pro Kanal

**2.4 GHz (ideal: 1, 6, 11 - nicht überlappend):**
```
Kanal 1:  5 APs
Kanal 6:  12 APs (überfüllt!)
Kanal 11: 3 APs (gut)
```

**Empfehlung:**
- Wechsle eigenen Router auf weniger genutzten Kanal

### Übung 5: Wireshark Deep-Dive

**Ziel:** Verstehe Frame-Struktur.

**Schritte:**
1. Capture 5 Minuten auf deinem Kanal
2. Exportiere PCAP
3. Öffne in Wireshark
4. Analysiere einen Beacon Frame im Detail:

```
Frame 42: 250 bytes on wire
  IEEE 802.11 Beacon Frame
    Frame Control: 0x80
      Type/Subtype: Beacon (0x08)
    Duration: 0
    Destination: Broadcast (ff:ff:ff:ff:ff:ff)
    Source: aa:bb:cc:dd:ee:ff
    BSS ID: aa:bb:cc:dd:ee:ff
    Fragment: 0
    Sequence: 1234
  
  Tagged Parameters:
    SSID: "MeinNetz"
    Supported Rates: 1, 2, 5.5, 11 Mbps
    DS Parameter: Channel 6
    Traffic Indication Map (TIM)
    Country Info: DE
    Power Constraint: 0 dB
    RSN Information:
      Group Cipher: CCMP (AES)
      Pairwise Cipher: CCMP (AES)
      Auth Key Mgmt: PSK
```

**Fragen:**
- Was bedeutet Broadcast-Destination?
- Warum ist Source = BSS ID?
- Was ist TIM?

---

## 8. Command Cheatsheet

### Flipper/Linux System

```bash
# System-Info
uname -a                        # Kernel-Version
cat /etc/os-release             # OS-Details
df -h                           # Speicherplatz
free -h                         # RAM-Nutzung

# Netzwerk-Interfaces
ip link show                    # Alle Interfaces
ip addr show wlan0              # Details zu wlan0
iw dev                          # Wireless Devices
iw dev wlan0 info               # Details zu wlan0
iwconfig wlan0                  # Wireless Config (veraltet, aber oft verfügbar)

# Monitor Mode
ip link set wlan0 down
iw dev wlan0 set type monitor
ip link set wlan0 up
iw dev wlan0 info               # Verifizieren

# Managed Mode
ip link set wlan0 down
iw dev wlan0 set type managed
ip link set wlan0 up

# Kanal setzen
iw dev wlan0 set channel 6
iw dev wlan0 set freq 2437      # 2437 MHz = Kanal 6
```

### Kismet

```bash
# Starten
kismet                          # Default
kismet -c wlan0                 # Mit Interface
kismet -c wlan0 --daemonize     # Im Hintergrund
kismet -c wlan0 --verbose       # Debug-Output

# Mit Config
kismet --config-file=/path/to/kismet.conf

# Ohne Channel Hopping (fester Kanal)
kismet -c wlan0 --override channelhop false

# Stoppen
killall kismet                  # Brutal
pkill kismet                    # Elegant

# Prozess-Check
ps aux | grep kismet
```

### Kismet Database Tools

```bash
# Devices exportieren
kismetdb_dump_devices --in /tmp/kismet/Kismet-*.kismet

# Als JSON
kismetdb_dump_devices --in /tmp/kismet/Kismet-*.kismet --json > devices.json

# Statistics
kismetdb_statistics --in /tmp/kismet/Kismet-*.kismet

# Alle verfügbaren Tools
kismetdb_<TAB><TAB>             # Bash-Completion
```

### Wireshark CLI (tshark)

Auf deinem Mac/PC, falls du CLI bevorzugst:

```bash
# PCAP-Datei lesen
tshark -r capture.pcapng

# Nur Beacon Frames
tshark -r capture.pcapng -Y "wlan.fc.type_subtype == 0x08"

# Frame-Details
tshark -r capture.pcapng -V

# SSIDs extrahieren
tshark -r capture.pcapng -Y "wlan.fc.type_subtype == 0x08" -T fields -e wlan.ssid | sort -u

# Alle MAC-Adressen
tshark -r capture.pcapng -T fields -e wlan.sa | sort -u
```

### File Transfer (Flipper ↔ Laptop)

```bash
# SCP (vom Laptop)
scp root@<FLIPPER_IP>:/path/to/file.pcapng ~/Desktop/

# Ganzes Verzeichnis
scp -r root@<FLIPPER_IP>:/tmp/kismet/ ~/Desktop/kismet_backup/

# Umgekehrt (Config zum Flipper senden)
scp ~/kismet.conf root@<FLIPPER_IP>:~/.kismet/
```

### Nützliche Kombinationen

```bash
# Kismet starten, 30 Minuten laufen lassen, dann stoppen
timeout 30m kismet -c wlan0

# Live-Monitoring der Log-Datei
tail -f /tmp/kismet/Kismet-*.log

# Anzahl entdeckter Devices (grob)
kismetdb_dump_devices --in /tmp/kismet/Kismet-*.kismet | grep "Device" | wc -l

# Liste nur Access Points
kismetdb_dump_devices --in /tmp/kismet/Kismet-*.kismet | grep "Wi-Fi AP"
```

---

## Zusammenfassung Teil 1

Du hast jetzt gelernt:

✅ **Grundlagen:**
- Was passive Reconnaissance ist
- 802.11 Protokoll-Basics (Frames, Kanäle, Verschlüsselung)
- Rechtliche und ethische Aspekte

✅ **Setup:**
- Verbindung zum Flipper (Serial/SSH)
- Monitor Mode verstehen und aktivieren
- Kismet konfigurieren und starten

✅ **Praktische Skills:**
- Netzwerke und Clients identifizieren
- Web-Interface navigieren
- Signalstärken interpretieren
- Versteckte SSIDs entdecken

✅ **Analyse:**
- Logs exportieren
- Wireshark nutzen
- Daten filtern und interpretieren

### Nächste Schritte

In **Teil 2: Active WiFi Reconnaissance** lernst du:
- Gezielte Probes senden
- Deauthentication Frames verstehen
- AP-Informationen forcieren
- Handshake Capturing
- Nmap für WiFi-Netzwerke
- Erweiterte Kismet-Features

In **Teil 3: WiFi Attack Scenarios** dann:
- WPA2-Handshake Attacks
- Evil Twin APs
- MITM (Man-in-the-Middle)
- Denial of Service
- Credential Harvesting

---

## Hilfreiche Ressourcen

**Offizielle Dokumentation:**
- Kismet Docs: https://www.kismetwireless.net/docs/
- Wireshark User Guide: https://www.wireshark.org/docs/wsug_html_chunked/
- 802.11 Standard: https://standards.ieee.org/standard/802_11-2020.html

**Community:**
- Kismet Discord/Forum
- /r/WifiHacking (Reddit)
- WiFi Hacking Labs: https://tryhackme.com / https://hackthebox.eu

**Tools:**
- Aircrack-ng Suite: https://www.aircrack-ng.org/
- Wigle.net (Wardriving Database): https://wigle.net/

---

**Viel Erfolg beim Lernen! Bei Fragen oder für Teil 2, melde dich.**

📡 Happy Sniffing! 🔍
