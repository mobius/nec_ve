#!/bin/bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"
# TC-PERF-001: Single-card matrix multiplication baseline

PASS=true
for i in $VE_NODES; do
    OUT=$(ve_exec -N "$i" ./ve_matmul 2>&1)
    GF=$(echo "$OUT" | grep "GFlops:" | awk '{print $2}')
    echo "VE$i: ${GF} GFLOPS"
    # Threshold: nfort hybrid DGEMM should exceed 350 GFLOPS
    if [ -z "$GF" ] || [ "$(echo "$GF < 350" | bc 2>/dev/null || echo 1)" -eq 1 ]; then
        echo "VE$i: FAIL (performance too low or missing, expected >350 GFLOPS with nfort+8-core OMP)"
        PASS=false
    fi
done

if $PASS; then
    echo "PASS"
else
    echo "FAIL"
    exit 1
fi
