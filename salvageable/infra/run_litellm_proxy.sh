#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

BOOTSTRAP=0
if [[ "${1:-}" == "--bootstrap" ]]; then
  BOOTSTRAP=1
  shift
fi

CONFIG_PATH="${1:-infra/nvidia-workers.litellm.yaml}"
ENV_FILE="${ENV_FILE:-.env}"

if [[ "${CONFIG_PATH}" != /* && -f "${REPO_ROOT}/${CONFIG_PATH}" ]]; then
  CONFIG_PATH="${REPO_ROOT}/${CONFIG_PATH}"
fi
if [[ "${ENV_FILE}" != /* && -f "${REPO_ROOT}/${ENV_FILE}" ]]; then
  ENV_FILE="${REPO_ROOT}/${ENV_FILE}"
fi

VENV_LITELLM="${REPO_ROOT}/infra/.venv/bin/litellm"
LITELLM_BIN=""
if [[ -x "${VENV_LITELLM}" ]]; then
  LITELLM_BIN="${VENV_LITELLM}"
elif command -v litellm >/dev/null 2>&1; then
  LITELLM_BIN="litellm"
elif [[ "${BOOTSTRAP}" == "1" ]]; then
  "${SCRIPT_DIR}/setup_litellm_proxy.sh"
  LITELLM_BIN="${VENV_LITELLM}"
else
  echo "Missing required command: litellm. Run ./infra/setup_litellm_proxy.sh or rerun with --bootstrap." >&2
  exit 1
fi

if [[ -f "$ENV_FILE" ]]; then
  set -a
  # shellcheck source=/dev/null
  source "$ENV_FILE"
  set +a
fi

require_env() {
  local name="$1"
  if [[ -z "${!name:-}" ]]; then
    echo "Missing required environment variable: $name" >&2
    exit 1
  fi
}

require_env LITELLM_MASTER_KEY
require_env NVIDIA_API_KEY
require_env NVIDIA_API_BASE_URL
require_env NVIDIA_MINIMAX25_MODEL
require_env NVIDIA_GLM47_MODEL

PORT="${LITELLM_PORT:-4001}"

echo "Starting LiteLLM proxy on port ${PORT} using ${CONFIG_PATH}"
exec "${LITELLM_BIN}" --config "$CONFIG_PATH" --port "$PORT"
