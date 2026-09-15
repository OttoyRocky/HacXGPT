#!/bin/bash
# core/guarden.sh — Validaciones de seguridad

set -euo pipefail

validate_target() {
    if [[ -z "${TARGET:-}" ]]; then
        echo "❌ [ERROR] TARGET no definido. Usá opción C para configurar."
        exit 1
    fi
    if ! echo "$TARGET" | grep -qP '^(\d{1,3}\.){3}\d{1,3}$|^[a-zA-Z0-9][-a-zA-Z0-9]*\.[a-zA-Z]{2,}'; then
        echo "❌ [ERROR] TARGET inválido: '$TARGET'"
        exit 1
    fi
}

require_tool() {
    local missing=()
    for tool in "$@"; do
        command -v "$tool" >/dev/null 2>&1 || missing+=("$tool")
    done
    if [[ ${#missing[@]} -gt 0 ]]; then
        echo "❌ Faltan herramientas: ${missing[*]}"
        exit 1
    fi
}

confirm_risk() {
    local module="$1"
    local level="${2:-ALTO}"
    local target="${3:-${TARGET:-NO DEFINIDO}}"
    echo ""
    echo -e "\e[0;31m⚠️  [ADVERTENCIA DE RIESGO: $level]\e[0m"
    echo -e "\e[1;33m   Módulo: $module | Objetivo: $target\e[0m"
    echo -e "\e[1;33m   ¡ATENCIÓN! Esta es una acción activa/potencialmente disruptiva contra el objetivo.\e[0m"
    echo ""
    local answer=""
    read -r -p "¿Confirmas la ejecución de esta acción? (s/N): " answer
    if [[ "${answer,,}" =~ ^s ]]; then
        return 0
    else
        echo -e "\e[0;31m❌ Operación cancelada por el usuario.\e[0m"
        return 1
    fi
}
