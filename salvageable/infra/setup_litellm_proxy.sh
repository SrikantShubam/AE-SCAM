#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

REQUIREMENTS_PATH="${REQUIREMENTS_PATH:-${REPO_ROOT}/infra/requirements.txt}"
VENV_DIR="${VENV_DIR:-${REPO_ROOT}/infra/.venv}"

PYTHON_BIN="${PYTHON_BIN:-}"
if [[ -n "${PYTHON_BIN}" ]]; then
  :
elif command -v python3 >/dev/null 2>&1; then
  PYTHON_BIN="python3"
elif command -v python >/dev/null 2>&1; then
  PYTHON_BIN="python"
else
  echo "Missing required command: python3 (or python)" >&2
  exit 1
fi

if [[ ! -f "${REQUIREMENTS_PATH}" ]]; then
  echo "Missing requirements file: ${REQUIREMENTS_PATH}" >&2
  exit 1
fi

if [[ ! -d "${VENV_DIR}" ]]; then
  echo "Creating venv at ${VENV_DIR}"
  "${PYTHON_BIN}" -m venv "${VENV_DIR}"
fi

VENV_PY="${VENV_DIR}/bin/python"
if [[ ! -x "${VENV_PY}" ]]; then
  echo "Venv python not found at: ${VENV_PY}" >&2
  exit 1
fi

echo "Upgrading pip"
"${VENV_PY}" -m pip install --upgrade pip

echo "Installing infra dependencies from ${REQUIREMENTS_PATH}"
"${VENV_PY}" -m pip install -r "${REQUIREMENTS_PATH}"

VENV_LITELLM="${VENV_DIR}/bin/litellm"
if [[ ! -x "${VENV_LITELLM}" ]]; then
  echo "LiteLLM CLI not found after install at: ${VENV_LITELLM}" >&2
  exit 1
fi

echo "LiteLLM proxy dependencies are ready."
