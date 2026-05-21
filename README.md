# AI stack — Podman Compose

Single `docker-compose.yml` launches a fully self-hosted AI workspace. No cloud APIs, no accounts, no telemetry — everything runs locally on your AMD GPU.

## What it does

| Capability | How |
|------------|-----|
| **Chat with local LLMs** | Pull any model from Ollama (e.g. `ollama pull qwen3.6:latest`) and chat at `http://localhost:3000` |
| **Generate images from text** | Ask the chat to create images — SDXL runs via ComfyUI on CPU, ~90 s per image |
| **Web search in chat** | Built-in SearXNG fetches live results; the LLM cites sources in its answers |
| **RAG on documents** | Upload PDFs, text files, or URLs — the stack embeds them locally (`all-MiniLM-L6-v2`) and the LLM answers from your documents |
| **In-UI terminal** | Run shell commands, scripts, or code directly inside the chat interface |
| **Code interpreter** | The LLM can execute Python code in the sandboxed terminal |
| **Search Paperless-ngx documents** | Ask the chat to find and cite content from your Paperless-ngx document archive (not included in this stack) via a Workspace Tool |
| **Provision models to other tools** | Open WebUI exposes an authenticated Ollama-compatible API (`/ollama/v1/`) — tools like opencode, Cursor, or any OpenAI-compatible client can access your local models via API key |

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
| `ollama` | `ollama/ollama:rocm` | — | LLM inference (ROCm GPU, internal only) |
| `open-webui` | `ghcr.io/open-webui/open-webui:main` | 3000 | Chat UI |
| `open-terminal` | `ghcr.io/open-webui/open-terminal:latest` | — | In-UI terminal |
| `searxng` | `searxng/searxng:latest` | — | Self-hosted web search (internal only) |
| `comfyui` | `yanwk/comfyui-boot:rocm` | 8188 | Stable Diffusion UI (port required for open-webui via host gateway) |

## Commands

```sh
# Start everything (pulls latest images first)
./start.sh

# Or manually
podman compose up -d

# View logs for a service
podman compose logs -f open-webui

# Stop everything
podman compose down
```

## Configuration

- **`.env`** — secrets (`WEBUI_SECRET_KEY`, `OPEN_TERMINAL_API_KEY`). Use `.env.example` as a template.
- Runtime data dirs (`ollama_models/`, `open-terminal/`, `open-webui/`, `searxng/`) are gitignored — do not commit
- All other settings are inlined in `docker-compose.yml` (Ollama tuning, Open WebUI mode, SearXNG config, internal URLs)
- Open WebUI runs **auth mode** (`WEBUI_AUTH=True`) — first user to register becomes admin
- **Native function calling** enabled for all models (`function_calling: native`) — tools (web search, image generation, terminal, code interpreter) use the model's built-in tool-use capabilities
- Default model capabilities: file context, vision, file upload, web search, image generation, code interpreter, terminal, citations, status updates, builtin tools
- ROCm GPU tuning: adjust `HSA_OVERRIDE_GFX_VERSION` in the `ollama` service if needed

## ComfyUI

Port 8188 is published so Open WebUI can reach it via `host.containers.internal`. Direct access at **http://localhost:8188**.

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

## RAG (Retrieval-Augmented Generation)

Upload documents or paste URLs in the chat to give the LLM context from your own files. Embeddings run locally — no external vector database needed.

### Configuration

| Setting | Value | Purpose |
|---------|-------|---------|
| Embedding model | `sentence-transformers/all-MiniLM-L6-v2` | ~80 MB, downloaded on first use |
| Async embedding | enabled | Embeddings generated in background, don't block chat |
| Text splitter | `token` | Splits by tokens instead of characters |
| Markdown headers | enabled | Treats Markdown headers as natural split boundaries |
| Chunk size | `2000` | Characters per document chunk |
| Chunk overlap | `200` | Characters of overlap between chunks |
| Top-K results | `5` | Number of document chunks retrieved per query |
| Re-ranking | disabled | No re-ranking model configured |
| Hybrid search | disabled | Pure semantic search (no BM25 keyword mixing) |
| Local web fetch | enabled (`ENABLE_RAG_LOCAL_WEB_FETCH=True`) | Required to fetch content from internal URLs (e.g. ComfyUI images) |

### Web search (RAG)

| Setting | Value | Purpose |
|---------|-------|---------|
| Engine | `searxng` | Self-hosted, no API key needed |
| Result count | `3` | Number of search results fetched per query |
| Language | `all` | No language filter |
| Trust env proxies | enabled | Respects `HTTP_PROXY`/`HTTPS_PROXY` env vars |

### Usage

1. In the chat, click the **+** (plus) button → **Documents** or **Web Search**
2. Upload files (PDF, TXT, Markdown, etc.) or enter a URL
3. Toggle the **Web Search** or **Documents** tool on for a conversation
4. The LLM will retrieve relevant chunks and cite sources in its answers

Embedding models are cached in `open-webui/cache/embedding/models/` (gitignored).

## Open WebUI API key (external tool access)

Ollama is **not exposed** on a host port. Other tools (opencode, Cursor, etc.) must connect through Open WebUI's Ollama-compatible proxy.

### 1. Enable API key generation (admin)

Open http://localhost:3000, create the first admin account, then click your avatar → **Admin Panel** → **Settings** → **API Keys** → toggle **Enable API Key Generation**.

### 3. Generate an API key (user)

Click your avatar → **Settings** → **Account** → **Generate API Key**. Copy the key — it won't be shown again.

### 4. Configure opencode

`opencode.jsonc.example` at repo root has a ready-made config for opencode. Copy it to the global config directory and paste your key:

```sh
cp opencode.jsonc.example ~/.config/opencode/opencode.jsonc
# then edit ~/.config/opencode/opencode.jsonc and paste your key
```

Then in opencode, run `/models` and select `open-webui/qwen3.6:latest`.

For other tools, use the Ollama-compatible OpenAI endpoint:

```
OPENAI_BASE_URL=http://localhost:3000/ollama/v1
OPENAI_API_KEY=sk-...  # the key you generated
```

## Paperless-ngx integration

Search your Paperless-ngx documents from Open WebUI chat via a community [Workspace Tool](https://raw.githubusercontent.com/soster/openwebui-ai-tools/refs/heads/main/paperless.py).

### Setup

1. In Open WebUI, go to **Workspace** → **Tools** → **+ New Tool**
2. Paste the contents of [`paperless.py`](https://raw.githubusercontent.com/soster/openwebui-ai-tools/refs/heads/main/paperless.py) (source: [soster/openwebui-ai-tools](https://github.com/soster/openwebui-ai-tools))
3. In the tool's **Valves** settings, configure:
   - `PAPERLESS_URL`: Your Paperless-ngx URL (e.g. `https://paperless.example.com`)
   - `PAPERLESS_TOKEN`: Your Paperless-ngx API token (generate in Paperless → Settings → API Tokens)
4. Attach the tool to a model: **Admin Panel** → **Models** → select a model → **Tools** → enable `get_paperless_documents`

### Usage

Ask the LLM to search your documents:

> "Find my invoice from Acme Corp"
> "What does my lease agreement say about subletting?"

The tool returns matching document content with citations.

## Notes

- All volumes use SELinux `:Z` label — may need adjustment on non-SELinux hosts
- `open-webui` port is `3000:8080` (host:container)
