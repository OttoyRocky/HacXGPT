#!/usr/bin/env python3
import subprocess
import json
import urllib.request
import os
import sys

def get_ollama_url():
    """
    Resuelve la URL del servicio Ollama invocando core/platform.sh si está disponible,
    o detectando si se ejecuta bajo WSL, Raspberry Pi o Linux local.
    """
    ollama_host = os.environ.get("OLLAMA_HOST")
    
    if not ollama_host:
        # Intentar ejecutar resolve_ollama_host vía bash con core/platform.sh
        script_dir = os.path.dirname(os.path.abspath(__file__))
        platform_sh = os.path.join(script_dir, "core", "platform.sh")
        if os.path.exists(platform_sh):
            try:
                cmd = f'bash -c "source {platform_sh} && resolve_ollama_host >/dev/null && echo $OLLAMA_HOST"'
                output = subprocess.check_output(cmd, shell=True, text=True).strip()
                if output:
                    ollama_host = output
            except Exception:
                pass

    if not ollama_host:
        # Fallback de resolución
        is_wsl = False
        if os.path.exists("/proc/version"):
            try:
                with open("/proc/version", "r") as f:
                    if "microsoft" in f.read().lower():
                        is_wsl = True
            except Exception:
                pass
        
        if is_wsl:
            try:
                ip = subprocess.check_output("ip route | grep default | awk '{print $3}'", shell=True, text=True).strip()
                ollama_host = f"{ip}:11434"
            except Exception:
                ollama_host = "localhost:11434"
        else:
            ollama_host = "localhost:11434"

    # Normalizar esquema http://
    if not ollama_host.startswith("http://") and not ollama_host.startswith("https://"):
        ollama_url = f"http://{ollama_host}/api/generate"
    else:
        ollama_url = f"{ollama_host}/api/generate"
        
    return ollama_url

def main():
    target = input("🎯 Ingresa IP/dominio para escanear: ").strip()
    if not target:
        print("❌ Objetivo no proporcionado.")
        return

    ollama_url = get_ollama_url()
    print(f"🔗 Ollama Endpoint resuelto: {ollama_url}")

    print(f"\n🔍 Ejecutando nmap sigiloso contra {target}...")
    result = subprocess.run(
        ["nmap", "-sS", "-sV", "-T2", "-Pn", target],
        capture_output=True, text=True
    )
    scan_output = result.stdout
    print("✅ Escaneo completado")
    print("🤖 Enviando a IA para análisis...\n")

    prompt = f"""Analizá este escaneo nmap. Respondé en español:
1) Puertos críticos abiertos
2) Técnicas MITRE ATT&CK aplicables
3) Próximos pasos

Escaneo:
{scan_output}"""

    data = {
        "model": "mistral:7b",
        "prompt": prompt,
        "stream": False
    }

    req = urllib.request.Request(
        ollama_url,
        data=json.dumps(data).encode(),
        headers={"Content-Type": "application/json"}
    )

    print("⏳ Analizando... (puede tomar 30-60 segundos)")
    try:
        with urllib.request.urlopen(req, timeout=120) as response:
            response_data = json.loads(response.read().decode())
            ai_response = response_data.get("response", "Error: Respuesta vacía")
    except Exception as e:
        ai_response = f"Error al conectar con Ollama ({ollama_url}): {e}"

    print("\n" + "=" * 50)
    print("🤖 ANÁLISIS DE IA (mistral:7b)")
    print("=" * 50)
    print(ai_response)
    print("=" * 50)

    out_filename = f"analisis_ia_{target}.txt"
    with open(out_filename, "w", encoding="utf-8") as f:
        f.write(ai_response)
    print(f"\n💾 Análisis guardado en {out_filename}")

    input("\nPresiona Enter para volver al menú...")

if __name__ == "__main__":
    main()
