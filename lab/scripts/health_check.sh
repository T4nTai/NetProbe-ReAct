#!/usr/bin/env bash
set -euo pipefail

PREFIX="clab-b2-net-rca"
WAIT_SECS=0

if [[ "${1:-}" == "--wait" ]]; then
    WAIT_SECS="${2:-60}"
fi

NODES=(r1 r2 r3 r4 r5 isp sw1 h1 h2 h3 h4)
ROUTERS=(r1 r2 r3 r4 r5 isp)

echo "=== [1/5] Checking running containers ==="
for n in "${NODES[@]}"; do
    state="$(docker inspect -f '{{.State.Running}}' "${PREFIX}-${n}" 2>/dev/null || echo "missing")"
    if [[ "$state" != "true" ]]; then
        echo "[FAIL] Container ${PREFIX}-${n} state=${state}"
        exit 1
    fi
done
echo "[OK] All ${#NODES[@]} containers are running."

check_convergence() {
    # Expect r1 to have 4 Full OSPF neighbors (r2, r3, r4, r5) and 1 Established BGP peer (172.16.0.2)
    local ospf_full
    ospf_full="$(docker exec "${PREFIX}-r1" vtysh -c "show ip ospf neighbor" 2>/dev/null | grep -c "Full/" || true)"
    local bgp_est
    bgp_est="$(docker exec "${PREFIX}-r1" vtysh -c "show bgp summary json" 2>/dev/null | grep -c '"state":"Established"' || true)"
    local ext_route_r2
    ext_route_r2="$(docker exec "${PREFIX}-r2" vtysh -c "show ip route 203.0.113.0/24" 2>/dev/null | grep -c "203.0.113.0/24" || true)"
    local int_route_isp
    int_route_isp="$(docker exec "${PREFIX}-isp" vtysh -c "show ip route 10.1.2.0/24" 2>/dev/null | grep -c "10.1.2.0/24" || true)"
    [[ "$ospf_full" -ge 4 && "$bgp_est" -ge 1 && "$ext_route_r2" -ge 1 && "$int_route_isp" -ge 1 ]]
}

if [[ "$WAIT_SECS" -gt 0 ]]; then
    echo "=== [2/5] Waiting up to ${WAIT_SECS}s for OSPF + eBGP convergence ==="
    deadline=$((SECONDS + WAIT_SECS))
    until check_convergence; do
        if [[ $SECONDS -ge $deadline ]]; then
            echo "[FAIL] Convergence timed out after ${WAIT_SECS}s"
            docker exec "${PREFIX}-r1" vtysh -c "show ip ospf neighbor" || true
            docker exec "${PREFIX}-r1" vtysh -c "show bgp summary" || true
            exit 1
        fi
        sleep 2
    done
    echo "[OK] OSPF & eBGP converged."
else
    echo "=== [2/5] Verifying OSPF & eBGP convergence ==="
    if ! check_convergence; then
        echo "[FAIL] OSPF/BGP not converged!"
        exit 1
    fi
    echo "[OK] OSPF & eBGP converged."
fi

echo "=== [3/5] Checking OSPF neighbor counts & BGP summary ==="
declare -A EXPECTED_OSPF=( [r1]=4 [r2]=2 [r3]=2 [r4]=2 [r5]=2 )
for r in r1 r2 r3 r4 r5; do
    cnt="$(docker exec "${PREFIX}-${r}" vtysh -c "show ip ospf neighbor" | grep -c "Full/" || true)"
    if [[ "$cnt" -ne "${EXPECTED_OSPF[$r]}" ]]; then
        echo "[FAIL] ${r} has ${cnt} Full OSPF neighbors (expected ${EXPECTED_OSPF[$r]})"
        docker exec "${PREFIX}-${r}" vtysh -c "show ip ospf neighbor"
        exit 1
    fi
    echo "  - ${r}: ${cnt}/${EXPECTED_OSPF[$r]} Full OSPF neighbors"
done

for r in r1 isp; do
    est="$(docker exec "${PREFIX}-${r}" vtysh -c "show bgp summary json" | grep -c '"state":"Established"' || true)"
    if [[ "$est" -lt 1 ]]; then
        echo "[FAIL] ${r} eBGP peer not Established"
        docker exec "${PREFIX}-${r}" vtysh -c "show bgp summary"
        exit 1
    fi
    echo "  - ${r}: eBGP Established"
done

echo "=== [4/5] Checking full-mesh host ping (12 pairs) ==="
declare -A HOST_IP=( [h1]=10.1.2.10 [h2]=10.1.4.10 [h3]=10.1.5.10 [h4]=203.0.113.10 )
for src in h1 h2 h3 h4; do
    for dst in h1 h2 h3 h4; do
        [[ "$src" == "$dst" ]] && continue
        if ! docker exec "${PREFIX}-${src}" ping -c 2 -W 1 "${HOST_IP[$dst]}" >/dev/null 2>&1; then
            echo "[FAIL] Ping ${src} -> ${dst} (${HOST_IP[$dst]}) failed!"
            exit 1
        fi
    done
    echo "  - ${src} -> all other hosts: OK"
done

echo "=== [5/5] Checking telemetry commands (vtysh JSON, ip -s -j link, iptables, frr.log) ==="
docker exec "${PREFIX}-r1" vtysh -c "show ip ospf neighbor json" >/dev/null
docker exec "${PREFIX}-r1" vtysh -c "show ip ospf interface json" >/dev/null
docker exec "${PREFIX}-r1" vtysh -c "show bgp summary json" >/dev/null
docker exec "${PREFIX}-r1" vtysh -c "show ip route json" >/dev/null
docker exec "${PREFIX}-sw1" ip -s -j link >/dev/null
docker exec "${PREFIX}-r1" iptables -L -n -v >/dev/null
docker exec "${PREFIX}-r1" test -s /var/log/frr/frr.log
echo "[OK] All telemetry commands and FRR log file verified."

echo ""
echo "=== Sample Shortest Paths (traceroute -n) ==="
echo "--- h1 -> h2 (expect r2 -> r1 -> r4 -> h2) ---"
docker exec "${PREFIX}-h1" traceroute -n -w 1 -q 1 10.1.4.10
echo "--- h2 -> h3 (expect r4 -> r5 -> h3) ---"
docker exec "${PREFIX}-h2" traceroute -n -w 1 -q 1 10.1.5.10
echo "--- h1 -> h4 (expect r2 -> r1 -> isp -> h4) ---"
docker exec "${PREFIX}-h1" traceroute -n -w 1 -q 1 203.0.113.10

echo ""
echo "[SUCCESS] Lab b2-net-rca passed all health checks!"
