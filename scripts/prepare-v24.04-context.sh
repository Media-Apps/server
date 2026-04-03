#!/usr/bin/env bash
# Fetch official ownCloud server bundle and v24.04 overlay into v24.04/ for local docker build.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
V24="${ROOT}/v24.04"

# Default to stable ownCloud tarball for production-like validation.
TAR_URL="${OWNCLOUD_TAR_URL:-https://download.owncloud.com/server/stable/owncloud-10.16.1.tar.bz2}"
EXPECTED_SHA="${OWNCLOUD_TAR_SHA256:-}"

mkdir -p "${V24}"

TMP="$(mktemp -d)"
trap 'rm -rf "${TMP}"' EXIT

curl -fsSL -o "${TMP}/server.tgz" "https://github.com/owncloud-docker/server/archive/refs/heads/master.tar.gz"
tar -xzf "${TMP}/server.tgz" -C "${TMP}"
UPSTREAM="$(find "${TMP}" -maxdepth 1 -type d -name 'server-*' | head -1)"
cp -a "${UPSTREAM}/v24.04/overlay" "${V24}/"

curl -fsSL -o "${V24}/owncloud.tar.bz2" "${TAR_URL}"

if [[ -n "${EXPECTED_SHA}" ]]; then
  echo "${EXPECTED_SHA}  ${V24}/owncloud.tar.bz2" | sha256sum -c -
else
  echo "SKIP: OWNCLOUD_TAR_SHA256 not set; checksum verification disabled."
fi

echo "OK: ${V24}/owncloud.tar.bz2 and overlay ready."
