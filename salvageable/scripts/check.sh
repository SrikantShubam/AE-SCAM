#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

command -v flutter >/dev/null 2>&1 || { echo "Missing required command: flutter" >&2; exit 1; }
command -v dart >/dev/null 2>&1 || { echo "Missing required command: dart" >&2; exit 1; }

EXPECTED_FLUTTER_VERSION="3.38.4"

assert_infra_requirements_pinned() {
  local req="${REPO_ROOT}/infra/requirements.txt"
  [[ -f "${req}" ]] || return 0

  local bad=()
  while IFS= read -r raw; do
    local line
    line="$(printf "%s" "${raw}" | xargs 2>/dev/null || printf "%s" "${raw}")"
    [[ -z "${line}" ]] && continue
    [[ "${line}" == \#* ]] && continue
    [[ "${line}" == -* ]] && continue
    [[ "${line}" == *"=="* ]] && continue
    bad+=("${line}")
  done <"${req}"

  if [[ "${#bad[@]}" -gt 0 ]]; then
    printf "infra/requirements.txt must pin versions with '=='. Unpinned line(s): %s\n" "$(printf "%s " "${bad[@]}" | xargs 2>/dev/null || printf "%s" "${bad[*]}")" >&2
    exit 1
  fi
}

semver_ge() {
  local a="$1" b="$2"
  local a1 a2 a3 b1 b2 b3
  IFS=. read -r a1 a2 a3 <<<"${a}"
  IFS=. read -r b1 b2 b3 <<<"${b}"
  a1="${a1:-0}"; a2="${a2:-0}"; a3="${a3:-0}"
  b1="${b1:-0}"; b2="${b2:-0}"; b3="${b3:-0}"
  if (( a1 != b1 )); then (( a1 > b1 )); return; fi
  if (( a2 != b2 )); then (( a2 > b2 )); return; fi
  (( a3 >= b3 ))
}

extract_min_dart_from_pubspec() {
  local pubspec_path="$1"
  [[ -f "${pubspec_path}" ]] || return 0

  local sdk_spec
  sdk_spec="$(
    awk '
      $1=="environment:" { inenv=1; next }
      inenv && $1=="sdk:" {
        $1=""
        sub(/^[ \t]+/, "", $0)
        sub(/#.*/, "", $0)
        gsub(/"/, "", $0)
        print $0
        exit
      }
      inenv && /^[^ \t]/ { inenv=0 }
    ' "${pubspec_path}"
  )"
  sdk_spec="$(printf "%s" "${sdk_spec}" | xargs 2>/dev/null || printf "%s" "${sdk_spec}")"

  if [[ "${sdk_spec}" =~ ^\\^([0-9]+\\.[0-9]+\\.[0-9]+) ]]; then
    printf "%s" "${BASH_REMATCH[1]}"
    return 0
  fi
  if [[ "${sdk_spec}" == ">="* ]]; then
    local rest="${sdk_spec#>=}"
    rest="$(printf "%s" "${rest}" | xargs 2>/dev/null || printf "%s" "${rest}")"
    if [[ "${rest}" =~ ^([0-9]+\\.[0-9]+\\.[0-9]+) ]]; then
      printf "%s" "${BASH_REMATCH[1]}"
    fi
    return 0
  fi
  if [[ "${sdk_spec}" =~ ^([0-9]+\\.[0-9]+\\.[0-9]+)$ ]]; then
    printf "%s" "${BASH_REMATCH[1]}"
    return 0
  fi

  return 0
}

if [[ "${SKIP_FLUTTER_VERSION_CHECK:-}" != "1" ]]; then
  VERSION_OUTPUT="$(flutter --version)"
  FIRST_LINE="$(printf "%s\n" "$VERSION_OUTPUT" | head -n 1)"
  if ! printf "%s\n" "$FIRST_LINE" | grep -q "Flutter ${EXPECTED_FLUTTER_VERSION}"; then
    echo "Unexpected Flutter version. Expected ${EXPECTED_FLUTTER_VERSION} but got: ${FIRST_LINE}" >&2
    echo "Tip: rerun with SKIP_FLUTTER_VERSION_CHECK=1 to bypass." >&2
    exit 1
  fi

  MIN_DART_VERSION="${MIN_DART_VERSION:-$(extract_min_dart_from_pubspec "${REPO_ROOT}/pubspec.yaml")}"
  if [[ -n "${MIN_DART_VERSION}" ]]; then
    DART_VERSION_OUTPUT="$(dart --version 2>&1 || true)"
    INSTALLED_DART_VERSION="$(printf "%s" "${DART_VERSION_OUTPUT}" | grep -Eo '[0-9]+\\.[0-9]+\\.[0-9]+' | head -n 1 || true)"
    if [[ -z "${INSTALLED_DART_VERSION}" ]]; then
      echo "Could not determine installed Dart version from: ${DART_VERSION_OUTPUT}" >&2
      exit 1
    fi
    if ! semver_ge "${INSTALLED_DART_VERSION}" "${MIN_DART_VERSION}"; then
      echo "Dart SDK ${INSTALLED_DART_VERSION} is below pubspec minimum ${MIN_DART_VERSION}." >&2
      echo "Tip: rerun with SKIP_FLUTTER_VERSION_CHECK=1 to bypass." >&2
      exit 1
    fi
  fi
fi

cd "${REPO_ROOT}"

if [[ "${CI:-}" == "true" || "${GITHUB_ACTIONS:-}" == "true" ]]; then
  shopt -s nullglob
  BAD_ENV_FILES=()
  for f in .env .env.*; do
    [[ "${f}" == ".env.example" ]] && continue
    [[ -f "${f}" ]] && BAD_ENV_FILES+=("${f}")
  done
  if [[ "${#BAD_ENV_FILES[@]}" -gt 0 ]]; then
    printf "Refusing to run in CI: env file(s) exist in the repo checkout (%s). Remove them from version control.\n" "$(printf "%s " "${BAD_ENV_FILES[@]}" | xargs 2>/dev/null || printf "%s" "${BAD_ENV_FILES[*]}")" >&2
    exit 1
  fi
  if [[ -d "infra/.venv" ]]; then
    echo "Refusing to run in CI: infra/.venv exists in the repo checkout. Remove it from version control." >&2
    exit 1
  fi
fi

assert_infra_requirements_pinned

flutter pub get

if [[ "${CI:-}" == "true" || "${GITHUB_ACTIONS:-}" == "true" ]]; then
  if command -v git >/dev/null 2>&1 && git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    if ! git diff --exit-code -- pubspec.lock >/dev/null; then
      echo "pubspec.lock changed after 'flutter pub get'. Commit the updated lockfile." >&2
      git diff -- pubspec.lock || true
      exit 1
    fi
  fi
fi

FORMAT_TARGETS=()
[[ -d "lib" ]] && FORMAT_TARGETS+=("lib")
[[ -d "test" ]] && FORMAT_TARGETS+=("test")
if [[ "${#FORMAT_TARGETS[@]}" -gt 0 ]]; then
  dart format --output=none --set-exit-if-changed "${FORMAT_TARGETS[@]}"
fi

flutter analyze
flutter test
