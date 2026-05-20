# AI stack — Podman Compose

Single `docker-compose.yml` launches an AI stack with Ollama, Open WebUI, Open Terminal, and SearXNG. Designed for **Linux + AMD GPU (ROCm) + Podman**.

## Prerequisites

- Linux with AMD GPU (ROCm-compatible)
- [Podman](https://podman.io/)

## Quick start

```sh
# Copy the env template and fill in secrets
cp .env.example .env
# Edit .env with your own random strings for WEBUI_SECRET_KEY and OPEN_TERMINAL_API_KEY

# Start everything
podman compose up -d

# Open http://localhost:3000
```

## Services

| Service | Image | Port | Purpose |
|---------|-------|------|---------|
| `ollama` | `ollama/ollama:rocm` | 11434 | LLM inference (ROCm GPU) |
| `open-webui` | `ghcr.io/open-webui/open-webui:main` | 3000 | Chat UI |
| `open-terminal` | `ghcr.io/open-webui/open-terminal:latest` | — | In-UI terminal |
| `searxng` | `searxng/searxng:latest` | 8080 | Self-hosted web search |
| `comfyui` | `yanwk/comfyui-boot:rocm` | 8188 | Stable Diffusion UI |

## Commands

```sh
# Start everything
podman compose up -d

# View logs for a service
podman compose logs -f open-webui

# Pull latest images and recreate
podman compose pull && podman compose up -d

# Stop everything
podman compose down
```

## Configuration

- **`.env`** — secrets (`WEBUI_SECRET_KEY`, `OPEN_TERMINAL_API_KEY`). Use `.env.example` as a template.
- Runtime data dirs (`ollama_models/`, `open-terminal/`, `open-webui/`, `searxng/`) are gitignored — do not commit
- All other settings are inlined in `docker-compose.yml` (Ollama tuning, Open WebUI mode, SearXNG config, internal URLs)
- Open WebUI runs **auth-less single-user** (`WEBUI_AUTH=False`)
- ROCm GPU tuning: adjust `HSA_OVERRIDE_GFX_VERSION` in the `ollama` service if needed

## ComfyUI

Standalone at **http://localhost:8188**. Open WebUI uses it as the image generation backend.

### Download a model

Models go into `comfyui/ComfyUI/models/checkpoints/` (gitignored). The default workflow expects **SDXL 1.0**:

```sh
# Requires curl and ~7 GB free
curl -L -o comfyui/ComfyUI/models/checkpoints/sd_xl_base_1.0.safetensors \
  https://huggingface.co/stabilityai/stable-diffusion-xl-base-1.0/resolve/main/sd_xl_base_1.0.safetensors
```

Restart ComfyUI after downloading:

```sh
podman compose stop comfyui && podman compose up -d comfyui
```

### Configure Open WebUI (one-time, after first startup)

Open WebUI persists image generation settings in its database, which overrides env vars. After the first `podman compose up -d`, configure ComfyUI in the UI:

1. Open **http://localhost:3000** → click your avatar → **Admin Panel** → **Image Generation**
2. Set **Image Generation Engine** to `ComfyUI`
3. Set **ComfyUI Base URL** to `http://host.containers.internal:8188`
4. Set **Model** to `sd_xl_base_1.0.safetensors`
5. Set **Size** to `1024x1024` (SDXL native resolution)
6. Set **Steps** to `20`
7. Paste the contents of [`comfyui-workflow.json`](comfyui-workflow.json) into **Workflow**
8. Paste the contents of [`comfyui-workflow-nodes.json`](comfyui-workflow-nodes.json) into **Workflow Nodes**
9. Click **Save**

### GPU sharing

ComfyUI runs on **CPU** (`CLI_ARGS=--cpu`) so Ollama keeps the full GPU VRAM for the LLM. Image generation is slower (~90 s for SDXL) but avoids out-of-memory errors when the chat model is loaded.

## Notes

- All volumes use SELinux `:Z` label — may need adjustment on non-SELinux hosts
- `open-webui` port is `3000:8080` (host:container)
