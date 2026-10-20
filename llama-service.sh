#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# ==========================================
# llama-service setup script
# Usage: ./llama-service.sh
# ==========================================

# 1. Configurar el archivo de secrets (copiar desde el ejemplo)
if [ ! -f deploy/llama-server.env ]; then
    echo "[*] Copiando deploy/llama-server.env.example → deploy/llama-server.env"
    cp deploy/llama-server.env.example deploy/llama-server.env
    echo "    (Edita deploy/llama-server.env para configurar LLAMA_API_KEY si es necesario)"
else
    echo "[✓] deploy/llama-server.env ya existe."
fi

# 2. Configurar el template systemd para tu host
echo ""
echo "[*] Revisa deploy/llama-server@.service"
echo "    - Ajusta User= y Group= a tu UID/GID real"
echo "    - Ajusta WorkingDirectory= a $SCRIPT_DIR"
echo "    (o a la ruta donde clones este repo en el otro entorno)"
echo ""

read -r -p "    ¿Quieres continuar con la configuración actual? [s/N] " CONFIRM
if [ "$CONFIRM" != "s" ] && [ "$CONFIRM" != "S" ]; then
    echo "    Cancelado. Edita deploy/llama-server@.service y ejecuta de nuevo."
    exit 0
fi

# 3. Inicializar systemd (instalar template unit + logrotate)
echo ""
echo "[*] Ejecutando: llama-tool.py init"
python3 ./llama-tool.py init "$@"

# 4. Instalar el engine llama.cpp (vulkan prebuilt)
echo ""
echo "[*] Ejecutando: llama-tool.py engine install"
python3 ./llama-tool.py engine install

# 5. Verificar qué presets están disponibles
echo ""
echo "=== Presets disponibles ==="
python3 ./llama-tool.py run --list

# 6. Configurar el modelo Qwen3.6-35B-A3B
#
# El preset qwen3.6-35b-ud.env espera el modelo en:
#   ./models/unsloth/unsloth-Qwen3.6-35B-A3B-GGUF/Qwen3.6-35B-A3B-UD-IQ2_M.gguf
#
# Puedes descargarlo con:
#   python3 ./llama-tool.py models download unsloth/Qwen3.6-35B-A3B-GGUF Qwen3.6-35B-A3B-UD-IQ2_M.gguf --preset qwen3.6-35b-ud
#
# O descargarlo manualmente con huggingface-cli:
#   huggingface-cli download unsloth/Qwen3.6-35B-A3B-GGUF Qwen3.6-35B-A3B-UD-IQ2_M.gguf --local-dir ./models/unsloth/unsloth-Qwen3.6-35B-A3B-GGUF

echo ""
echo "=== Instrucciones para descargar el modelo ==="
echo ""
echo "Opción 1 (automática, requiere HF_TOKEN):"
echo "  HF_TOKEN=tu_token python3 ./llama-tool.py models download unsloth/Qwen3.6-35B-A3B-GGUF Qwen3.6-35B-A3B-UD-IQ2_M.gguf --preset qwen3.6-35b-ud"
echo ""
echo "Opción 2 (manual, descarga directa):"
echo "  mkdir -p ./models/unsloth/unsloth-Qwen3.6-35B-A3B-GGUF"
echo "  huggingface-cli download unsloth/Qwen3.6-35B-A3B-GGUF Qwen3.6-35B-A3B-UD-IQ2_M.gguf --local-dir ./models/unsloth/unsloth-Qwen3.6-35B-A3B-GGUF"
echo ""

echo "=== Una vez descargado el modelo, ejecuta: ==="
echo ""
echo "  python3 ./llama-tool.py run qwen3.6-35b-ud --dry-run"
echo "  # para ver el comando que se ejecutaría, sin lanzarlo"
echo ""
echo "  python3 ./llama-tool.py run qwen3.6-35b-ud"
echo "  # para ejecutar el servidor"
echo ""
