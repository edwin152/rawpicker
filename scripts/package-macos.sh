#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "${SCRIPT_DIR}/.." && pwd)"

PROJECT_PATH="${REPO_ROOT}/rawpicker.xcodeproj"
SCHEME="rawpicker"
CONFIGURATION="Release"
DERIVED_DATA_PATH="${REPO_ROOT}/build/DerivedData"
LOG_DIR="${REPO_ROOT}/build/logs"
LOG_PATH="${LOG_DIR}/package-macos.log"
DIST_DIR="${REPO_ROOT}/dist"
BUILD_APP_NAME="rawpicker.app"
DIST_APP_NAME="RawPicker.app"
BUILD_APP_PATH="${DERIVED_DATA_PATH}/Build/Products/${CONFIGURATION}/${BUILD_APP_NAME}"
DIST_APP_PATH="${DIST_DIR}/${DIST_APP_NAME}"
LEGACY_DIST_APP_PATH="${DIST_DIR}/${BUILD_APP_NAME}"

RUN_AFTER_PACKAGE=false

usage() {
  cat <<'USAGE'
Usage: scripts/package-macos.sh [--run]

Builds the macOS app in Release mode and copies it to dist/RawPicker.app.

Options:
  --run     Launch dist/RawPicker.app after packaging.
  -h, --help
            Show this help message.
USAGE
}

log() {
  printf '%s\n' "$*"
}

fail() {
  printf 'Error: %s\n' "$*" >&2
  exit 1
}

require_command() {
  command -v "$1" >/dev/null 2>&1 || fail "$1 is required but was not found."
}

while (($# > 0)); do
  case "$1" in
    --run)
      RUN_AFTER_PACKAGE=true
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage >&2
      exit 64
      ;;
  esac
  shift
done

require_command xcodebuild
require_command ditto

log "Building ${SCHEME} (${CONFIGURATION})..."
mkdir -p "${LOG_DIR}"
if ! xcodebuild \
    -project "${PROJECT_PATH}" \
    -scheme "${SCHEME}" \
    -destination "platform=macOS" \
    -configuration "${CONFIGURATION}" \
    -derivedDataPath "${DERIVED_DATA_PATH}" \
    clean build \
    CODE_SIGNING_ALLOWED=NO \
    >"${LOG_PATH}" 2>&1; then
  echo "Build failed. Last log lines:" >&2
  tail -n 80 "${LOG_PATH}" >&2
  echo "Full log: ${LOG_PATH}" >&2
  exit 1
fi
log "Build succeeded. Log: ${LOG_PATH}"

if [[ ! -d "${BUILD_APP_PATH}" ]]; then
  fail "Expected app bundle was not found: ${BUILD_APP_PATH}"
fi

log "Packaging ${DIST_APP_NAME}..."
mkdir -p "${DIST_DIR}"
rm -rf "${DIST_APP_PATH}" "${LEGACY_DIST_APP_PATH}"
ditto "${BUILD_APP_PATH}" "${DIST_APP_PATH}"

log "Packaged: ${DIST_APP_PATH}"

if [[ "${RUN_AFTER_PACKAGE}" == true ]]; then
  log "Launching ${DIST_APP_PATH}..."
  open "${DIST_APP_PATH}"
fi
