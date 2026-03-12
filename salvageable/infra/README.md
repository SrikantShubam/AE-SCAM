# Infra

## LiteLLM proxy (NVIDIA NIM workers)

Config: `infra/nvidia-workers.litellm.yaml`

### One-time setup

Installs a pinned LiteLLM proxy into `infra/.venv/`.

- Windows (PowerShell): `./infra/setup_litellm_proxy.ps1`
- macOS/Linux: `bash ./infra/setup_litellm_proxy.sh`

### Required environment variables

- `LITELLM_MASTER_KEY`
- `LITELLM_PORT` (optional; defaults to `4001`)
- `NVIDIA_API_KEY`
- `NVIDIA_API_BASE_URL`
- `NVIDIA_MINIMAX25_MODEL`
- `NVIDIA_GLM47_MODEL`

Keep secrets in `.env` (gitignored). If a real key is ever committed, rotate it.
CI refuses to run if `.env`/`.env.*` (except `.env.example`) or `infra/.venv` is present in the repo checkout.

### Run (Windows / PowerShell)

1. Copy `.env.example` -> `.env` and fill in values.
2. Run:
   - `./infra/run_litellm_proxy.ps1` (or `./infra/run_litellm_proxy.ps1 -Bootstrap`)

### Run (macOS/Linux)

1. Copy `.env.example` -> `.env` and fill in values.
2. Run:
   - `bash ./infra/run_litellm_proxy.sh` (or `bash ./infra/run_litellm_proxy.sh --bootstrap`)
