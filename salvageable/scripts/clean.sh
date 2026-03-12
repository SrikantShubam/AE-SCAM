#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

cd "${REPO_ROOT}"

REMOVE_PATHS=(
  ".dart_tool"
  "build"
  "coverage"
  ".flutter-plugins"
  ".flutter-plugins-dependencies"
  "android/.gradle"
  "android/app/build"
  "android/build"
  "infra/.venv"
  "litellm.log"
  "litellm.err.log"
)

for p in "${REMOVE_PATHS[@]}"; do
  if [[ -e "${p}" ]]; then
    echo "Removing ${p}"
    rm -rf "${p}"
  fi
done

echo "Done."
