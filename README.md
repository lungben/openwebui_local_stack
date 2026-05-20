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

## Notes

- All volumes use SELinux `:Z` label — may need adjustment on non-SELinux hosts
- `open-webui` port is `3000:8080` (host:container)
