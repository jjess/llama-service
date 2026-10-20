# LEEME.md — Instrucciones de instalación y uso de llama-service

## Instalación en otro entorno

```bash
# 1. Clonar el repositorio
cd ~/WORKSAPCE
git clone https://github.com/shuricksumy/llama-service.git
cd llama-service

# 2. Ejecutar el script de setup
./llama-service.sh
```

El script `llama-service.sh` realiza automáticamente:
- Copia `deploy/llama-server.env.example` → `deploy/llama-server.env`
- Pide confirmación para continuar
- Ejecuta `llama-tool.py init` (instala template systemd + logrotate)
- Ejecuta `llama-tool.py engine install` (descarga llama.cpp Vulkan)
- Lista presets disponibles
- Muestra instrucciones para descargar el modelo

## Descarga del modelo

Una vez terminado `llama-service.sh`, descarga el modelo Qwen3.6-35B-A3B:

```bash
# Opción 1 (automática, requiere HF_TOKEN):
HF_TOKEN=tu_token python3 ./llama-tool.py models download unsloth/Qwen3.6-35B-A3B-GGUF Qwen3.6-35B-A3B-UD-IQ2_M.gguf --preset qwen3.6-35b-ud

# Opción 2 (manual, descarga directa):
mkdir -p ./models/unsloth/unsloth-Qwen3.6-35B-A3B-GGUF
huggingface-cli download unsloth/Qwen3.6-35B-A3B-GGUF Qwen3.6-35B-A3B-UD-IQ2_M.gguf --local-dir ./models/unsloth/unsloth-Qwen3.6-35B-A3B-GGUF
```

## Ejecución

```bash
# Ver el comando generado (sin ejecutarlo):
python3 ./llama-tool.py run qwen3.6-35b-ud --dry-run

# Ejecutar el servidor llama.cpp:
python3 ./llama-tool.py run qwen3.6-35b-ud
```

## Configuración del preset qwen3.6-35b-ud

El preset `presets/qwen3.6-35b-ud.env` está configurado con:

| Parámetro | Valor |
|-----------|-------|
| `LLAMA_HOST` | `0.0.0.0` |
| `LLAMA_PORT` | `8080` |
| `LLAMA_MODEL` | `${LLAMA_MODELS_DIR}/unsloth/unsloth-Qwen3.6-35B-A3B-GGUF/Qwen3.6-35B-A3B-UD-IQ2_M.gguf` |
| `LLAMA_API_KEY` | `alias:Qwen3.6-35B-A3B-UD-IQ2-M` |
| `LLAMA_CTX_SIZE` | `65536` |
| `LLAMA_BATCH_SIZE` | `512` |
| `LLAMA_UBATCH_SIZE` | `128` |
| `LLAMA_PARALLEL` | `1` |
| `LLAMA_N_GPU_LAYERS` | `999` |
| `LLAMA_CACHE_TYPE_K` | `q8_0` |
| `LLAMA_CACHE_TYPE_V` | `q8_0` |
| `LLAMA_FLASH_ATTN` | `on` |
| `LLAMA_VERBOSITY` | `4` |
| `LLAMA_TEMP` | `1.0` |
| `LLAMA_TOP_P` | `0.95` |
| `LLAMA_TOP_K` | `20` |
| `LLAMA_MIN_P` | `0.0` |
| `LLAMA_PRESENCE_PENALTY` | `0.0` |
| `LLAMA_REPEAT_PENALTY` | `1.0` |
| `LLAMA_SPEC_TYPE` | `draft-mtp` |
| `LLAMA_SPEC_DRAFT_N_MAX` | `3` |
| `LLAMA_CHAT_TEMPLATE_KWARGS` | `{"reasoning_effort":"medium"}` |

## Para usar como servicio systemd

```bash
# Habilitar y arrancar el preset como servicio:
sudo systemctl enable --now llama-server@qwen3.6-35b-ud.service

# Ver logs:
tail -f llama-server-qwen3.6-35b-ud.log
```

## Archivos de configuración clave

- **`llama.env`** — Configuración compartida (defaults globales)
- **`deploy/llama-server.env`** — Secrets (gitignore, copiar desde `.example`)
- **`deploy/llama-server@.service`** — Template systemd (ajustar User/Group/WorkingDirectory)
- **`presets/qwen3.6-35b-ud.env`** — Preset del modelo Qwen3.6-35B-A3B
- **`llama-service.sh`** — Script de instalación automatizada
- **`tools/run.py`** — Mapeo de env vars → CLI args de llama.cpp
