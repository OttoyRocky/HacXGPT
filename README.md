# 🛡️ HacXGPT v8.2 - MITRE ATT&CK Framework + IA Local

![Linux](https://img.shields.io/badge/Linux-FCC624?style=for-the-badge&logo=linux&logoColor=black)
![Kali](https://img.shields.io/badge/Kali_Linux-557C94?style=for-the-badge&logo=kali-linux&logoColor=white)
![Bash](https://img.shields.io/badge/Bash-4EAA25?style=for-the-badge&logo=gnu-bash&logoColor=white)
![Ollama](https://img.shields.io/badge/Ollama-000000?style=for-the-badge&logo=ollama&logoColor=white)
![GitHub](https://img.shields.io/badge/GitHub-100000?style=for-the-badge&logo=github&logoColor=white)

## 📋 DESCRIPCIÓN

**HacXGPT v8.2** es una herramienta educativa de ciberseguridad y pentesting que combina el **framework MITRE ATT&CK Enterprise** completo con **ejecución real de herramientas**, **control de riesgo interactivo**, **telemetría dinámica de técnicas** e **IA local vía Ollama**. Sin dependencias de APIs externas. Todo se ejecuta localmente en tu sistema.

---

## 🎯 CARACTERÍSTICAS PRINCIPALES

- **⚡ Ejecución Real de Comandos**: Módulos de Reconocimiento, Escaneo Web, Análisis de Red y Post-Explotación ejecutan herramientas reales (`whois`, `nslookup`, `dig`, `subfinder`, `theHarvester`, `whatweb`, `nikto`, `gobuster`, `curl`, `sslscan`, `nmap`, `traceroute`, `tcpdump`, `secretsdump`, `GetUserSPNs`, `bloodhound-python`) con captura de outputs y fallbacks automáticos.
- **🛡️ Control de Riesgo GuardEn (`confirm_risk`)**: Advertencia visual de riesgo (ALTO/MEDIO) con confirmación explícita `(s/N)` y despliegue del objetivo real (`user@host`) antes de ejecutar pruebas de penetración o evasión activas (`sqlmap`, `hydra`, `xsstrike`, `john`, `secretsdump`, `wevtutil`).
- **📊 Telemetría & Tracking MITRE (`track_technique`)**: Registro automático en tiempo real de cada técnica ejecutada en `/tmp/hacx_techniques.json`.
- **📈 Gap Analysis Dinámico (Menú 13)**: Fuente única de verdad respaldada por `dynamic_gap_analysis.py` que mide la cobertura en tiempo real, desglosa técnicas probadas vs. pendientes y exporta reportes.
- **🛠️ Verificación Inteligente de Herramientas (`check_command`)**: Detección de entornos Debian/Ubuntu/Kali con verificación de vigencia de `apt update` (> 24hs) para prevenir errores HTTP 404 por mirrors desactualizados.
- **🤖 IA Local (Ollama)**: Chat libre con LLM real — responde preguntas de ciberseguridad sin enviar datos fuera de tu red.
- **💻 Detección Automática de Entorno**: Selecciona `mistral:7b` en Windows/WSL o `tinyllama` en Raspberry Pi de forma transparente mediante `core/platform.sh`.
- **🟣 Purple Team & APT Simulation**: Simulación de tácticas de ataque (🔴), defensa (🔵) y detección (🟣), junto con killchains de APT29, APT38 y FIN7.

---

## ⚙️ REQUISITOS GENERALES

- Linux / Kali / macOS / WSL en Windows
- Bash 4.0+
- Python 3+
- Ollama instalado localmente o accesible en red

---

## 💻 INSTALACIÓN POR PLATAFORMA

### 1. 🪟 Windows (WSL2 - Ubuntu / Kali)

En entornos Windows, HacXGPT se ejecuta dentro de WSL2 (Windows Subsystem for Linux), mientras que Ollama puede correr en el host de Windows o dentro de la máquina virtual WSL.

* **Instalación de Ollama**:
  * Descargar el instalador de Windows desde [ollama.com/download/windows](https://ollama.com/download/windows) e instalar.
  * Abrir PowerShell como Administrador e iniciar el servicio permitiendo conexiones desde WSL2:
    ```powershell
    $env:OLLAMA_HOST="0.0.0.0:11434"
    ollama serve
    ```
* **Modelo Recomendado**:
  ```powershell
  ollama pull mistral:7b
  ```
* **Instalación de Dependencias (en WSL2)**:
  ```bash
  sudo apt update && sudo apt install -y \
      bash whois dnsutils nmap nikto gobuster ffuf sqlmap hydra john \
      aircrack-ng whatweb dirb tcpdump curl wget jq python3 python3-pip
  pip3 install impacket bloodhound
  ```
* **Configuración Específica de Plataforma (`core/platform.sh`)**:
  * `core/platform.sh` detecta automáticamente la versión de kernel de WSL (`grep -qi microsoft /proc/version`).
  * Resuelve la IP del host de Windows calculando la ruta por defecto:
    `OLLAMA_HOST="$(ip route | grep default | awk '{print $3}'):11434"`

---

### 2. 🍎 macOS (Intel & Apple Silicon M1/M2/M3)

macOS utiliza `zsh` y viene por defecto con una versión obsoleta de Bash (3.2). HacXGPT requiere **Bash 4.0+** para soporte de arreglos asociativos.

* **Instalación de Ollama**:
  * Descargar desde [ollama.com/download/mac](https://ollama.com/download/mac) o vía Homebrew:
    ```bash
    brew install ollama
    ollama serve
    ```
* **Modelo Recomendado**:
  ```bash
  ollama pull mistral:7b
  ```
* **Instalación de Dependencias y Bash 4+ (vía Homebrew)**:
  ```bash
  # Instalar Bash actualizado y herramientas de pentesting
  brew install bash coreutils nmap nikto gobuster ffuf sqlmap hydra john-jumbo wget curl jq python3
  pip3 install impacket bloodhound
  ```
* **Configuración Específica de Plataforma**:
  * Para ejecutar HacXGPT asegurando el uso de Bash 4+, invoca el binario de Homebrew:
    ```bash
    /opt/homebrew/bin/bash ./hacx_advanced.sh   # Apple Silicon
    # o bien en Mac Intel:
    /usr/local/bin/bash ./hacx_advanced.sh
    ```
  * `core/platform.sh` resolverá `OLLAMA_HOST="localhost:11434"`.

---

### 3. 🍓 Raspberry Pi (ARM 32-bit & 64-bit / Raspberry Pi OS)

En dispositivos monoplaca (SBC) como Raspberry Pi 4 o Pi 5, la memoria RAM y la ausencia de GPU dedicada limitan la ejecución de modelos de 7B parámetros.

* **Instalación de Ollama**:
  ```bash
  curl -fsSL https://ollama.com/install.sh | sh
  ```
* **Modelo Recomendado (Modelos SLM / Ultra-ligeros)**:
  ```bash
  ollama pull tinyllama     # 1.1B parámetros (Ultra rápido en ARM)
  ollama pull gemma:2b       # 2B parámetros (Alternativa ligera)
  ```
* **Instalación de Dependencias (Raspberry Pi OS / Debian ARM)**:
  ```bash
  sudo apt update && sudo apt install -y \
      bash whois dnsutils nmap nikto gobuster ffuf sqlmap hydra john \
      whatweb dirb tcpdump curl wget jq python3 python3-pip
  pip3 install impacket --break-system-packages
  ```
* **Configuración Específica de Plataforma (`core/platform.sh` & `ollama_config.sh`)**:
  * `core/platform.sh` detecta el hardware leyendo `/proc/device-tree/model` (`grep -qi "raspberry pi"`).
  * `ollama_integration.sh` conmuta automáticamente el modelo activo a `tinyllama` para prevenir cuelgues por consumo excesivo de RAM / swap.

---

### 4. 🐉 Kali Linux / Debian / Ubuntu (Linux Nativo)

En distribuciones Linux nativas x86_64, todas las herramientas se instalan de forma directa desde los repositorios oficiales `apt`.

* **Instalación de Ollama**:
  ```bash
  curl -fsSL https://ollama.com/install.sh | sh
  ollama pull mistral:7b
  ```
* **Modelo Recomendado**:
  ```bash
  ollama pull mistral:7b
  ```
* **Instalación de Dependencias (APT)**:
  ```bash
  sudo apt update && sudo apt install -y \
      whois dnsutils nmap nikto gobuster ffuf sqlmap hydra john \
      aircrack-ng whatweb dirb tcpdump curl wget jq python3 python3-pip \
      python3-impacket bloodhound-python
  pip3 install impacket
  ```
* **Configuración Específica de Plataforma**:
  * `core/platform.sh` detecta `KALI` o `LINUX` y asigna `OLLAMA_HOST="localhost:11434"`.
  * **Verificación de Repositorios**: `check_command()` revisa `/var/lib/apt/periodic/update-success-stamp`. Si los índices de paquetes tienen más de 24 horas, te sugerirá ejecutar `sudo apt update` antes de instalar herramientas para prevenir errores HTTP 404 por espejos desincronizados.

---

## 🚀 INSTALACIÓN RÁPIDA Y EJECUCIÓN

```bash
git clone https://github.com/OttoyRocky/HacXGPT.git
cd HacXGPT
chmod +x *.sh
./hacx_advanced.sh
```

---

## 🎮 MENÚ PRINCIPAL DE NAVEGACIÓN

| Opción | Módulo | Descripción |
| :--- | :--- | :--- |
| **1** | Reconocimiento Básico | Exec: WHOIS, DNS, DIG/AXFR, Subfinder, IP Info, theHarvester |
| **2** | Escaneo Web | Exec: WhatWeb, Nikto, Gobuster/Dirb, Headers, OPTIONS, SSLScan |
| **3** | Análisis de Red | Exec: Nmap Quick, Nmap Advanced, Ping, Traceroute, Netstat, Tcpdump |
| **4** | Suite de Pentesting | Exec con `confirm_risk`: Metasploit, SQLMap, Hydra, XSStrike, John |
| **5** | Generar Reportes | Exportación de logs y hallazgos guardados en HTML, TXT o PDF |
| **6** | Herramientas Avanzadas | Exec: OSINT (recon-ng / theHarvester), Malware, Forense |
| **7** | Chat Libre con IA Local | Interacción con LLM local vía Ollama |
| **8** | Escaneo Sigiloso | Escaneo Nmap en modos de evasión con tracking T1046 |
| **9** | Matriz MITRE ATT&CK | Catálogo interactivo de 14 tácticas Enterprise |
| **10** | Modo Purple Team | Matriz de Ataque + Defensa + Detección |
| **11** | Post-Explotación | Exec: Linux SSH / Windows Impacket (secretsdump, GetUserSPNs) |
| **12** | Simular APT | Killchains completas de APT29, APT38, FIN7 |
| **13** | Gap Analysis Dinámico | Cobertura en tiempo real vía `dynamic_gap_analysis.py` |
| **14** | Análisis Nmap con IA | Parser inteligente de salidas Nmap con Ollama y `nmap_ai.py` |
| **A** | Modo Anónimo | Activa/desactiva enrutamiento vía Tor + proxychains4 |
| **C** | Cambiar Objetivo | Configura el `$TARGET` global |
| **S** | Alternar Guardado | Activa/desactiva la captura automática de outputs |

---

## 🤖 IA LOCAL — CÓMO FUNCIONA

El **Módulo 7 (Chat Libre)** combina respuestas estructuradas por palabras clave con inferencia en tiempo real:

| Modo | Condición | Comportamiento |
| :--- | :--- | :--- |
| **Keywords** | Pregunta con tema reconocido | Respuesta estructurada MITRE instantánea |
| **IA (Ollama)** | Pregunta libre | Consulta directa al LLM local en tiempo real |

---

## 🔒 MODO ANÓNIMO

HacXGPT incluye un **Modo Anónimo** opcional que enruta el tráfico saliente de las herramientas de red a través de la red **Tor** utilizando **proxychains4**.

### 🛠️ Instalación de Dependencias
Para utilizar el modo anónimo, asegurate de tener instalados los paquetes de `tor` y `proxychains4`:

```bash
sudo apt update && sudo apt install -y tor proxychains4
```

### 🚀 Activación y Verificación
1. **En el Menú Principal**: Presioná la tecla `A` para alternar entre `ANON_MODE=true` y `ANON_MODE=false`. El banner mostrará el indicador de estado correspondiente (`🟢 ANON: ON` o `⚫ ANON: OFF`).
2. **Verificación de Enrutamiento**: Para verificar que el tráfico sale correctamente por la red Tor desde la terminal, ejecutá:
   ```bash
   proxychains curl https://check.torproject.org/api/ip
   ```

> ⚠️ **Advertencia sobre Raw Sockets**: Los escaneos sigilosos (menú 8) que utilizan paquetes crudos / raw sockets (`-sS`, `-sF`, `-sX`, `-sN`, `-sU`) **no son compatibles con proxychains** debido a que `LD_PRELOAD` solo intercepta llamadas a sockets de nivel de aplicación (`connect()`). Si el Modo Anónimo está activo durante estas pruebas, el script emitirá una advertencia y ejecutará la herramienta de forma directa sin el prefijo de proxy.

---

## 📁 ESTRUCTURA DEL PROYECTO

```
HacXGPT/
├── hacx_advanced.sh         # Core principal y menú de navegación
├── track_technique.sh       # Telemetría y registro de técnicas MITRE
├── dynamic_gap_analysis.py  # Gap Analysis dinámico y generación de reportes
├── nmap_ai.py               # Módulo 14: análisis de nmapas asistido por IA
├── ollama_integration.sh    # Cliente e integración con Ollama LLM
├── mitre_data.sh            # Base de conocimientos MITRE principal
├── mitre_extras_1.sh        # Tácticas MITRE: Reconnaissance & Resource Dev
├── mitre_extras_2.sh        # Tácticas MITRE: Execution, Persistence, Evasion
├── mitre_extras_3.sh        # Tácticas MITRE: Exfiltration & Impact
└── core/
    ├── guarden.sh           # GuardEn: validaciones y confirm_risk()
    └── platform.sh          # Detección multiplataforma (WSL, Pi, Mac, Linux)
```

---

## 🔄 CHANGELOG

| Versión | Fecha | Cambios Principales |
| :--- | :--- | :--- |
| **v8.2** | Septiembre 2026 | Integración del **Modo Anónimo (Tor + proxychains4)** con alternador visual e inspección de servicios; conversión de Reconocimiento, Web, Red, OSINT y Post-Explotación (Linux/Windows/Evasión) a ejecuciones reales; integración de `confirm_risk()` con paso de objetivo dinámico; telemetría en tiempo real con `track_technique()`; unificación de Gap Analysis en `dynamic_gap_analysis.py`; unificación de `nmap_ai.py` con resolución dinámica de Ollama; y validación inteligente de `apt update` en `check_command()`. |
| **v8.1** | Abril 2026 | Integración de IA local Ollama con autodetección de entorno (Windows/WSL vs Raspberry Pi). |
| **v8.0** | Marzo 2026 | Implementación de Matriz MITRE completa, Purple Team, simulaciones APT y Gap Analysis inicial. |
| **v7.0** | Anterior | Chat libre por palabras clave y utilidades de escaneo. |

---

## ⚠️ AVISO LEGAL

Esta herramienta ha sido desarrollada exclusivamente para **fines educativos y auditorías de seguridad autorizadas**.

- ✅ Usar únicamente contra sistemas propios o con autorización explícita documentada.
- ❌ Queda strictly prohibido su uso para actividades no autorizadas.
- Los desarrolladores no se responsabilizan por el mal uso o daños causados por esta herramienta.

---

## 📚 RECURSOS Y REFERENCIAS

- [MITRE ATT&CK Enterprise](https://attack.mitre.org/)
- [Ollama Framework](https://ollama.com/)
- [OWASP Foundation](https://owasp.org/)
- [Kali Linux Documentation](https://www.kali.org/docs/)

---

© 2026 OttoyRocky — MIT License
