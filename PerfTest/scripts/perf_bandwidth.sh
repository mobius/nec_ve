#!/bin/bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"
# TC-PERF-002: HBM bandwidth test per card

PASS=true
for i in $VE_NODES; do
    OUT=$(ve_exec -N "$i" ./ve_bandwidth 2>&1)
    BW=$(echo "$OUT" | grep "Bandwidth:" | awk '{print $2}')
    echo "VE$i: ${BW} GB/s"
    if [ -z "$BW" ] || [ "$(echo "$BW < 100" | bc 2>/dev/null || echo 1)" -eq 1 ]; then
        echo "VE$i: FAIL (bandwidth too low)"
        PASS=false
    fi
done

if $PASS; then
    echo "PASS"
else
    echo "FAIL"
    exit 1
fi
