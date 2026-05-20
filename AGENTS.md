# AI stack — Podman Compose

Single `docker-compose.yml` launches Ollama, Open WebUI, Open Terminal, ComfyUI, and SearXNG. No build steps, no tests.

## GPU sharing — single AMD ROCm GPU

Ollama (LLM) runs on GPU. ComfyUI (image gen) runs on **CPU** (`CLI_ARGS=--cpu`) to avoid VRAM contention. Expect ~90 s per SDXL image.

## Key gotchas

- **`group_add: keep-groups`** required on both `ollama` and `comfyui` for `/dev/kfd` and `/dev/dri` access. Without it, devices appear as `nobody:65534` inside the container and GPU detection fails.
- **`COMFYUI_BASE_URL=http://host.containers.internal:8188`** — Podman's host-gateway DNS. Using the Docker internal hostname `comfyui` breaks Open WebUI's URL validator (`validators.url` rejects single-label hostnames). The port **must be published** (`8188:8188`) so the host-gateway route works.
- **`ENABLE_RAG_LOCAL_WEB_FETCH=True`** — Open WebUI's `validate_url()` rejects private IPs by default. Required so it can fetch generated images from the ComfyUI endpoint.
- **Open WebUI `PersistentConfig` overrides env vars from its SQLite DB.** ComfyUI settings (base URL, workflow, nodes) must be configured once via Admin Panel → Image Generation. Env vars only apply on first startup before the DB is populated. See `README.md` for the setup steps.
- **`podman-compose` 1.0.6** — does not support `podman compose rm`. Use `podman rm <container>` directly.
- Config hash change triggers **full stack recreation** (all services), not just the modified one.
- **`security_opt: label=disable`** on comfyui — required for SELinux with device passthrough.

## ComfyUI model

Download SDXL checkpoint to `comfyui/ComfyUI/models/checkpoints/sd_xl_base_1.0.safetensors`. Workflow and node mappings are in `comfyui-workflow.json` and `comfyui-workflow-nodes.json` at repo root.

### Commands

```sh
podman compose up -d              # start all
podman compose logs -f <service>  # follow logs
podman compose down               # stop all
```
