# AI stack — Podman Compose

Single `docker-compose.yml` launches the full stack. No build steps, no tests.

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
podman-compose up -d

# View logs for a service
podman-compose logs -f open-webui

# Pull latest images and recreate
podman-compose pull && podman-compose up -d

# Stop everything
podman-compose down

# Run with podman (not docker) — use podman-compose or docker-compose with podman socket
```

## Configuration

- **`.env`** — secrets (`WEBUI_SECRET_KEY`, `OPEN_TERMINAL_API_KEY`) and internal URLs
- Runtime data dirs (`ollama_models/`, `open-terminal/`, `open-webui/`, `searxng/`) are gitignored — do not commit
- Ollama tuned for **single model, no parallelism** (`OLLAMA_MAX_LOADED_MODELS=1`, `OLLAMA_NUM_PARALLEL=1`)
- Open WebUI runs **auth-less single-user** (`WEBUI_AUTH=False`)
- Web search uses the bundled SearXNG container (`ENABLE_WEB_SEARCH=True`)
- ROCm requires `HSA_OVERRIDE_GFX_VERSION=11.0.0` — adjust per GPU

## Key gotchas

- All volumes use SELinux `:Z` label — may need adjustment on non-SELinux hosts
- `userns_mode: keep-id` on open-terminal for user namespace mapping
- `open-webui` depends on `ollama`, `open-terminal`, and `searxng` — compose will wait for them
- `open-webui` port is `3000:8080` (host:container)
- No `opencode.json` or other instruction files exist in this repo
