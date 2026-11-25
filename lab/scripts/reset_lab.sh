#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LAB_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
MODE="${1:---hard}"

if [[ "$MODE" == "--destroy" ]]; then
    cd "$LAB_DIR"
    sudo containerlab destroy -t topology.clab.yml --cleanup
    echo "[+] Lab destroyed."
    exit 0
fi

echo "[*] Resetting lab (full clean reconfigure)..."
cd "$LAB_DIR"
sudo containerlab deploy -t topology.clab.yml --reconfigure

echo "[*] Waiting for OSPF/BGP convergence and running health check..."
bash "$SCRIPT_DIR/health_check.sh" --wait 60
