# 🛡️ HacXGPT v8.2 - MITRE ATT&CK Framework + Local AI

![Linux](https://img.shields.io/badge/Linux-FCC624?style=for-the-badge&logo=linux&logoColor=black)
![Kali](https://img.shields.io/badge/Kali_Linux-557C94?style=for-the-badge&logo=kali-linux&logoColor=white)
![Bash](https://img.shields.io/badge/Bash-4EAA25?style=for-the-badge&logo=gnu-bash&logoColor=white)
![Ollama](https://img.shields.io/badge/Ollama-000000?style=for-the-badge&logo=ollama&logoColor=white)
![GitHub](https://img.shields.io/badge/GitHub-100000?style=for-the-badge&logo=github&logoColor=white)

## 📋 DESCRIPTION

**HacXGPT v8.2** is an educational cybersecurity and pentesting tool that combines the full **MITRE ATT&CK Enterprise framework** with **real tool execution**, **interactive risk control**, **dynamic technique telemetry**, and **local AI via Ollama**. No external API dependencies. Everything runs locally on your system.

---

## 🎯 KEY FEATURES

- **⚡ Real Command Execution**: Reconnaissance, Web Scanning, Network Analysis, and Post-Exploitation modules execute real tools (`whois`, `nslookup`, `dig`, `subfinder`, `theHarvester`, `whatweb`, `nikto`, `gobuster`, `curl`, `sslscan`, `nmap`, `traceroute`, `tcpdump`, `secretsdump`, `GetUserSPNs`, `bloodhound-python`) with output capture and automatic fallbacks.
- **🛡️ GuardEn Risk Control (`confirm_risk`)**: Visual risk warning (HIGH/MEDIUM) with explicit confirmation `(y/N)` and deployment of the real target (`user@host`) before running active penetration or evasion tests (`sqlmap`, `hydra`, `xsstrike`, `john`, `secretsdump`, `wevtutil`).
- **📊 Telemetry & MITRE Tracking (`track_technique`)**: Real-time automatic logging of each executed technique in `/tmp/hacx_techniques.json`.
- **📈 Dynamic Gap Analysis (Menu 13)**: Single source of truth backed by `dynamic_gap_analysis.py` measuring real-time coverage, breaking down tested vs. pending techniques, and exporting reports.
- **🛠️ Smart Tool Verification (`check_command`)**: Detection of Debian/Ubuntu/Kali environments checking `apt update` freshness (> 24h) to prevent HTTP 404 errors due to outdated mirrors.
- **🤖 Local AI (Ollama)**: Free chat with a real LLM — answers cybersecurity questions without sending data outside your network.
- **💻 Automatic Environment Detection**: Seamlessly selects `mistral:7b` on Windows/WSL or `tinyllama` on Raspberry Pi via `core/platform.sh`.
- **🟣 Purple Team & APT Simulation**: Simulation of attack (🔴), defense (🔵), and detection (🟣) tactics, along with kill chains for APT29, APT38, and FIN7.

---

## ⚙️ GENERAL REQUIREMENTS

- Linux / Kali / macOS / WSL on Windows
- Bash 4.0+
- Python 3+
- Ollama installed locally or accessible over the network

---

## 💻 INSTALLATION BY PLATFORM

### 1. 🪟 Windows (WSL2 - Ubuntu / Kali)

In Windows environments, HacXGPT runs inside WSL2 (Windows Subsystem for Linux), while Ollama can run on the Windows host or inside the WSL virtual machine.

* **Ollama Installation**:
  * Download the Windows installer from [ollama.com/download/windows](https://ollama.com/download/windows) and install.
  * Open PowerShell as Administrator and start the service allowing connections from WSL2:
    ```powershell
    $env:OLLAMA_HOST="0.0.0.0:11434"
    ollama serve
    ```
* **Recommended Model**:
  ```powershell
  ollama pull mistral:7b
  ```
* **Dependency Installation (in WSL2)**:
  ```bash
  sudo apt update && sudo apt install -y \
      bash whois dnsutils nmap nikto gobuster ffuf sqlmap hydra john \
      aircrack-ng whatweb dirb tcpdump curl wget jq python3 python3-pip
  pip3 install impacket bloodhound
  ```
* **Platform-Specific Configuration (`core/platform.sh`)**:
  * `core/platform.sh` automatically detects the WSL kernel version (`grep -qi microsoft /proc/version`).
  * Resolves the Windows host IP by calculating the default route:
    `OLLAMA_HOST="$(ip route | grep default | awk '{print $3}'):11434"`

---

### 2. 🍎 macOS (Intel & Apple Silicon M1/M2/M3)

macOS uses `zsh` and ships by default with an outdated version of Bash (3.2). HacXGPT requires **Bash 4.0+** for associative array support.

* **Ollama Installation**:
  * Download from [ollama.com/download/mac](https://ollama.com/download/mac) or via Homebrew:
    ```bash
    brew install ollama
    ollama serve
    ```
* **Recommended Model**:
  ```bash
  ollama pull mistral:7b
  ```
* **Dependency Installation and Bash 4+ (via Homebrew)**:
  ```bash
  # Install updated Bash and pentesting tools
  brew install bash coreutils nmap nikto gobuster ffuf sqlmap hydra john-jumbo wget curl jq python3
  pip3 install impacket bloodhound
  ```
* **Platform-Specific Configuration**:
  * To run HacXGPT ensuring Bash 4+ is used, invoke the Homebrew binary:
    ```bash
    /opt/homebrew/bin/bash ./hacx_advanced.sh   # Apple Silicon
    # or on Intel Mac:
    /usr/local/bin/bash ./hacx_advanced.sh
    ```
  * `core/platform.sh` will resolve `OLLAMA_HOST="localhost:11434"`.

---

### 3. 🍓 Raspberry Pi (ARM 32-bit & 64-bit / Raspberry Pi OS)

On single-board computers (SBCs) such as Raspberry Pi 4 or Pi 5, RAM limitations and the lack of a dedicated GPU restrict the execution of 7B parameter models.

* **Ollama Installation**:
  ```bash
  curl -fsSL https://ollama.com/install.sh | sh
  ```
* **Recommended Model (SLM / Ultra-lightweight Models)**:
  ```bash
  ollama pull tinyllama     # 1.1B parameters (Ultra fast on ARM)
  ollama pull gemma:2b       # 2B parameters (Lightweight alternative)
  ```
* **Dependency Installation (Raspberry Pi OS / Debian ARM)**:
  ```bash
  sudo apt update && sudo apt install -y \
      bash whois dnsutils nmap nikto gobuster ffuf sqlmap hydra john \
      whatweb dirb tcpdump curl wget jq python3 python3-pip
  pip3 install impacket --break-system-packages
  ```
* **Platform-Specific Configuration (`core/platform.sh` & `ollama_config.sh`)**:
  * `core/platform.sh` detects hardware by reading `/proc/device-tree/model` (`grep -qi "raspberry pi"`).
  * `ollama_integration.sh` automatically switches the active model to `tinyllama` to prevent crashes due to excessive RAM / swap usage.

---

### 4. 🐉 Kali Linux / Debian / Ubuntu (Native Linux)

On native x86_64 Linux distributions, all tools are installed directly from the official `apt` repositories.

* **Ollama Installation**:
  ```bash
  curl -fsSL https://ollama.com/install.sh | sh
  ollama pull mistral:7b
  ```
* **Recommended Model**:
  ```bash
  ollama pull mistral:7b
  ```
* **Dependency Installation (APT)**:
  ```bash
  sudo apt update && sudo apt install -y \
      whois dnsutils nmap nikto gobuster ffuf sqlmap hydra john \
      aircrack-ng whatweb dirb tcpdump curl wget jq python3 python3-pip \
      python3-impacket bloodhound-python
  pip3 install impacket
  ```
* **Platform-Specific Configuration**:
  * `core/platform.sh` detects `KALI` or `LINUX` and sets `OLLAMA_HOST="localhost:11434"`.
  * **Repository Verification**: `check_command()` checks `/var/lib/apt/periodic/update-success-stamp`. If package indices are older than 24 hours, it will suggest running `sudo apt update` before installing tools to prevent HTTP 404 errors from out-of-sync mirrors.

---

## 🚀 QUICK INSTALLATION AND EXECUTION

```bash
git clone https://github.com/OttoyRocky/HacXGPT.git
cd HacXGPT
chmod +x *.sh
./hacx_advanced.sh
```

---

## 🎮 MAIN NAVIGATION MENU

| Option | Module | Description |
| :--- | :--- | :--- |
| **1** | Basic Reconnaissance | Exec: WHOIS, DNS, DIG/AXFR, Subfinder, IP Info, theHarvester |
| **2** | Web Scanning | Exec: WhatWeb, Nikto, Gobuster/Dirb, Headers, OPTIONS, SSLScan |
| **3** | Network Analysis | Exec: Nmap Quick, Nmap Advanced, Ping, Traceroute, Netstat, Tcpdump |
| **4** | Pentesting Suite | Exec with `confirm_risk`: Metasploit, SQLMap, Hydra, XSStrike, John |
| **5** | Generate Reports | Export saved logs and findings to HTML, TXT, or PDF |
| **6** | Advanced Tools | Exec: OSINT (recon-ng / theHarvester), Malware, Forensics |
| **7** | Free Chat with Local AI | Interaction with local LLM via Ollama |
| **8** | Stealth Scan | Nmap scanning in evasion modes with T1046 tracking |
| **9** | MITRE ATT&CK Matrix | Interactive catalog of 14 Enterprise tactics |
| **10** | Purple Team Mode | Attack + Defense + Detection Matrix |
| **11** | Post-Exploitation | Exec: Linux SSH / Windows Impacket (secretsdump, GetUserSPNs) |
| **12** | Simulate APT | Full kill chains for APT29, APT38, FIN7 |
| **13** | Dynamic Gap Analysis | Real-time coverage via `dynamic_gap_analysis.py` |
| **14** | Nmap Analysis with AI | Smart parser for Nmap outputs with Ollama and `nmap_ai.py` |
| **A** | Anonymous Mode | Enable/disable routing via Tor + proxychains4 |
| **C** | Change Target | Configure global `$TARGET` |
| **S** | Toggle Logging | Enable/disable automatic output capture |

---

## 🤖 LOCAL AI — HOW IT WORKS

**Module 7 (Free Chat)** combines structured keyword responses with real-time inference:

| Mode | Condition | Behavior |
| :--- | :--- | :--- |
| **Keywords** | Question with recognized topic | Instant structured MITRE response |
| **AI (Ollama)** | Free-form question | Direct query to local LLM in real time |

---

## 🔒 ANONYMOUS MODE

HacXGPT includes an optional **Anonymous Mode** that routes outgoing network tool traffic through the **Tor** network using **proxychains4**.

### 🛠️ Dependency Installation
To use anonymous mode, make sure you have `tor` and `proxychains4` packages installed:

```bash
sudo apt update && sudo apt install -y tor proxychains4
```

### 🚀 Activation and Verification
1. **In the Main Menu**: Press the `A` key to toggle between `ANON_MODE=true` and `ANON_MODE=false`. The banner will display the corresponding status indicator (`🟢 ANON: ON` or `⚫ ANON: OFF`).
2. **Routing Verification**: To verify that traffic is correctly exiting through the Tor network from the terminal, run:
   ```bash
   proxychains curl https://check.torproject.org/api/ip
   ```

> ⚠️ **Warning on Raw Sockets**: Stealth scans (menu 8) using raw packets / raw sockets (`-sS`, `-sF`, `-sX`, `-sN`, `-sU`) **are not compatible with proxychains** because `LD_PRELOAD` only intercepts application-level socket calls (`connect()`). If Anonymous Mode is active during these tests, the script will issue a warning and run the tool directly without the proxy prefix.

---

## 📁 PROJECT STRUCTURE

```
HacXGPT/
├── hacx_advanced.sh         # Main core and navigation menu
├── track_technique.sh       # Telemetry and MITRE technique logging
├── dynamic_gap_analysis.py  # Dynamic Gap Analysis and report generation
├── nmap_ai.py               # Module 14: AI-assisted Nmap analysis
├── ollama_integration.sh    # Client and Ollama LLM integration
├── mitre_data.sh            # Main MITRE knowledge base
├── mitre_extras_1.sh        # MITRE Tactics: Reconnaissance & Resource Dev
├── mitre_extras_2.sh        # MITRE Tactics: Execution, Persistence, Evasion
├── mitre_extras_3.sh        # MITRE Tactics: Exfiltration & Impact
└── core/
    ├── guarden.sh           # GuardEn: validations and confirm_risk()
    └── platform.sh          # Cross-platform detection (WSL, Pi, Mac, Linux)
```

---

## 🔄 CHANGELOG

| Version | Date | Main Changes |
| :--- | :--- | :--- |
| **v8.2** | September 2026 | Integration of **Anonymous Mode (Tor + proxychains4)** with visual toggle and service inspection; conversion of Reconnaissance, Web, Network, OSINT, and Post-Exploitation (Linux/Windows/Evasion) to real executions; integration of `confirm_risk()` with dynamic target passing; real-time telemetry with `track_technique()`; unification of Gap Analysis into `dynamic_gap_analysis.py`; unification of `nmap_ai.py` with dynamic Ollama resolution; and smart `apt update` validation in `check_command()`. |
| **v8.1** | April 2026 | Integration of local Ollama AI with environment auto-detection (Windows/WSL vs Raspberry Pi). |
| **v8.0** | March 2026 | Implementation of full MITRE Matrix, Purple Team, APT simulations, and initial Gap Analysis. |
| **v7.0** | Previous | Keyword-based free chat and scanning utilities. |

---

## ⚠️ DISCLAIMER

This tool has been developed exclusively for **educational purposes and authorized security audits**.

- ✅ Use only against your own systems or with explicit documented authorization.
- ❌ Strictly prohibited for unauthorized activities.
- The developers are not responsible for any misuse or damage caused by this tool.

---

## 📚 RESOURCES AND REFERENCES

- [MITRE ATT&CK Enterprise](https://attack.mitre.org/)
- [Ollama Framework](https://ollama.com/)
- [OWASP Foundation](https://owasp.org/)
- [Kali Linux Documentation](https://www.kali.org/docs/)

---

© 2026 OttoyRocky — MIT License
