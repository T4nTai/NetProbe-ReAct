#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LAB_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

if ! docker image inspect b2-frr:latest >/dev/null 2>&1 || ! docker image inspect b2-node:latest >/dev/null 2>&1; then
    echo "[*] Lab images not found locally. Building first..."
    bash "$SCRIPT_DIR/build_images.sh"
fi

echo "[*] Deploying Containerlab topology ($LAB_DIR/topology.clab.yml)..."
cd "$LAB_DIR"
sudo containerlab deploy -t topology.clab.yml --reconfigure

echo "[+] Topology deployed. Waiting for OSPF/BGP convergence..."
bash "$SCRIPT_DIR/health_check.sh" --wait 60
