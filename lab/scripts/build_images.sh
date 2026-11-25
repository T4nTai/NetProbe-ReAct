#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LAB_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

echo "[*] Building b2-frr:latest..."
docker build -t b2-frr:latest -f "$LAB_DIR/docker/Dockerfile.frr" "$LAB_DIR/docker"

echo "[*] Building b2-node:latest..."
docker build -t b2-node:latest -f "$LAB_DIR/docker/Dockerfile.node" "$LAB_DIR/docker"

echo "[+] Done building lab images."
docker images | grep -E "REPOSITORY|b2-(frr|node)"
