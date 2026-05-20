#!/bin/bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"
# TC-STRS-001: 30-minute continuous stress test

DURATION=${1:-1800}
START=$(date +%s)
ITER=0
FAIL=0

echo "Starting ${DURATION}s stress test..."

while [ $(($(date +%s) - START)) -lt $DURATION ]; do
    ITER=$((ITER + 1))

    for i in $VE_NODES; do
        ve_exec -N "$i" ./ve_matmul > /dev/null 2>&1 || FAIL=$((FAIL + 1)) &
    done
    wait

    if [ $((ITER % 10)) -eq 0 ]; then
        ELAPSED=$(($(date +%s) - START))
        echo "[$ELAPSED s] Completed $ITER rounds, failures: $FAIL"
    fi
done

ELAPSED=$(($(date +%s) - START))
echo "Test complete: duration=${ELAPSED}s, iterations=$ITER, failures=$FAIL"

STATE=$(ve_state_get)
echo "$STATE"

if [ "$FAIL" -eq 0 ] && echo "$STATE" | grep -q "ONLINE"; then
    echo "PASS"
else
    echo "FAIL"
    exit 1
fi
