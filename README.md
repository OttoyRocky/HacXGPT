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

- **⚡ Ejecución Real de Comandos**: Módulos de Reconocimiento, Escaneo Web y Análisis de Red ejecutan herramientas reales (`whois`, `nslookup`, `dig`, `subfinder`, `theHarvester`, `whatweb`, `nikto`, `gobuster`, `curl`, `sslscan`, `nmap`, `traceroute`, `tcpdump`) con captura de outputs y fallbacks automáticos.
- **🛡️ Control de Riesgo GuardEn (`confirm_risk`)**: Advertencia visual de riesgo (ALTO/MEDIO) con confirmación explícita `(s/N)` y despliegue del objetivo antes de ejecutar ataques o pruebas activas (`sqlmap`, `hydra`, `xsstrike`, `john`).
- **📊 Telemetría & Tracking MITRE (`track_technique`)**: Registro automático en tiempo real de cada técnica ejecutada en `/tmp/hacx_techniques.json`.
- **📈 Gap Analysis Dinámico (Menú 13)**: Fuente única de verdad respaldada por `dynamic_gap_analysis.py` que mide la cobertura en tiempo real, desglosa técnicas probadas vs. pendientes y exporta reportes.
- **🛠️ Verificación Inteligente de Herramientas (`check_command`)**: Detección de entornos Debian/Ubuntu/Kali con verificación de vigencia de `apt update` (> 24hs) para prevenir errores HTTP 404 por mirrors desactualizados.
- **🤖 IA Local (Ollama)**: Chat libre con LLM real — responde preguntas de ciberseguridad sin enviar datos fuera de tu red.
- **💻 Detección Automática de Entorno**: Selecciona `mistral:7b` en Windows/WSL o `tinyllama` en Raspberry Pi de forma transparente.
- **🟣 Purple Team & APT Simulation**: Simulación de tácticas de ataque (🔴), defensa (🔵) y detección (🟣), junto con killchains de APT29, APT38 y FIN7.

---

## ⚙️ REQUISITOS Y DEPENDENCIAS

- Linux / Kali / macOS / WSL en Windows
- Bash 4.0+
- Python 3+
- Ollama instalado con al menos un modelo

```bash
# Instalación de Ollama y modelos recomendados
curl -fsSL https://ollama.com/install.sh | sh
ollama pull mistral:7b    # Windows/WSL
ollama pull tinyllama     # Raspberry Pi / Sistemas con recursos limitados
```

### Paquetes recomendados (Debian / Kali / Ubuntu)

```bash
sudo apt update && sudo apt install -y \
    whois \
    dnsutils \
    nmap \
    nikto \
    gobuster \
    ffuf \
    sqlmap \
    hydra \
    john \
    aircrack-ng \
    whatweb \
    dirb \
    tcpdump \
    curl \
    wget \
    jq \
    python3 \
    python3-pip

# Herramientas adicionales opcionales en Go:
go install -v github.com/projectdiscovery/subfinder/v2/cmd/subfinder@latest
go install -v github.com/projectdiscovery/httpx/cmd/httpx@latest
go install -v github.com/lc/gau/v2/cmd/gau@latest
```

---

## 🚀 INSTALACIÓN Y EJECUCIÓN

```bash
git clone https://github.com/OttoyRocky/HacXGPT-Private.git
cd HacXGPT-Private
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
| **5** | Generar Reportes | Exportación de logs y hallazgos guardados |
| **6** | Herramientas Avanzadas | Escaneos especializados y utilidades avanzadas |
| **7** | Chat Libre con IA Local | Interacción con LLM local vía Ollama |
| **8** | Escaneo Sigiloso | Escaneo Nmap en modos de evasión con tracking T1046 |
| **9** | Matriz MITRE ATT&CK | Catálogo interactivo de 14 tácticas Enterprise |
| **10** | Modo Purple Team | Matriz de Ataque + Defensa + Detección |
| **11** | Post-Explotación | Técnicas de persistencia y evasión Windows/Linux |
| **12** | Simular APT | Killchains completas de APT29, APT38, FIN7 |
| **13** | Gap Analysis Dinámico | Cobertura en tiempo real vía `dynamic_gap_analysis.py` |
| **14** | Análisis Nmap con IA | Parser inteligente de salidas XML/texto de Nmap con Ollama |
| **C** | Cambiar Objetivo | Configura el `$TARGET` global |
| **S** | Alternar Guardado | Activa/desactiva la captura automática de outputs |

---

## 🤖 IA LOCAL — CÓMO FUNCIONA

El **Módulo 7 (Chat Libre)** combina respuestas estructuradas por palabras clave con inferencia en tiempo real:

| Modo | Condición | Comportamiento |
| :--- | :--- | :--- |
| **Keywords** | Pregunta con tema reconocido | Respuesta estructurada MITRE instantánea |
| **IA (Ollama)** | Pregunta libre | Consulta directa al LLM local en tiempo real |

**Detección de entorno**:
- **Windows/WSL**: Conecta al host WSL (`172.x.x.x:11434`) usando `mistral:7b`.
- **Linux Nativo / Raspberry Pi**: Conecta a `localhost:11434` usando `tinyllama` / `gemma:2b`.

---

## 📁 ESTRUCTURA DEL PROYECTO

```
HacXGPT-Private/
├── hacx_advanced.sh         # Core principal y menú de navegación
├── track_technique.sh       # Telemetría y registro de técnicas MITRE
├── dynamic_gap_analysis.py  # Gap Analysis dinámico y generación de reportes
├── nmap_ai.py               # Módulo 14: análisis de nmapas asistido por IA
├── ollama_integration.sh    # Cliente e integración con Ollama LLM
├── mitre_data.sh            # Base de conocimientos MITRE principal
├── mitre_extras_1.sh        # Tácticas MITRE: Reconnaissance & Resource Dev
├── mitre_extras_2.sh        # Tácticas MITRE: Execution, Persistence, Evasion
├── mitre_extras_3.sh        # Tácticas MITRE: Exfiltration & Impact
├── run_gap_analysis.sh      # Launcher alternativo de Gap Analysis
└── core/
    └── guarden.sh           # GuardEn: validaciones y confirm_risk()
```

---

## 🔄 CHANGELOG

| Versión | Fecha | Cambios Principales |
| :--- | :--- | :--- |
| **v8.2** | Septiembre 2026 | Conversión de Reconocimiento, Web y Red a ejecuciones reales; integración de `confirm_risk()` con paso de objetivo dinámico; telemetría en tiempo real con `track_technique()`; unificación de Gap Analysis en `dynamic_gap_analysis.py`; y validación inteligente de `apt update` en `check_command()`. |
| **v8.1** | Abril 2026 | Integración de IA local Ollama con autodetección de entorno (Windows/WSL vs Raspberry Pi). |
| **v8.0** | Marzo 2026 | Implementación de Matriz MITRE completa, Purple Team, simulaciones APT y Gap Analysis inicial. |
| **v7.0** | Anterior | Chat libre por palabras clave y utilidades de escaneo. |

---

## ⚠️ AVISO LEGAL

Esta herramienta ha sido desarrollada exclusivamente para **fines educativos y auditorías de seguridad autorizadas**.

- ✅ Usar únicamente contra sistemas propios o con autorización explícita documentada.
- ❌ Queda estrictamente prohibido su uso para actividades no autorizadas.
- Los desarrolladores no se responsabilizan por el mal uso o daños causados por esta herramienta.

---

## 📚 RECURSOS Y REFERENCIAS

- [MITRE ATT&CK Enterprise](https://attack.mitre.org/)
- [Ollama Framework](https://ollama.com/)
- [OWASP Foundation](https://owasp.org/)
- [Kali Linux Documentation](https://www.kali.org/docs/)

---

© 2026 OttoyRocky — MIT License
