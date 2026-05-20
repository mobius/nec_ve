#!/bin/bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"
# TC-PERF-004: PCIe transfer bandwidth test

PASS=true
for i in $VE_NODES; do
    OUT=$(./aveo_bandwidth "$i" 2>&1)
    echo "$OUT"
    H2D=$(echo "$OUT" | grep "H2D:" | awk '{print $3}')
    if [ -z "$H2D" ] || [ "$(echo "$H2D < 1" | bc 2>/dev/null || echo 1)" -eq 1 ]; then
        echo "VE$i: FAIL (H2D too low)"
        PASS=false
    fi
done

if $PASS; then
    echo "PASS"
else
    echo "FAIL"
    exit 1
fi
