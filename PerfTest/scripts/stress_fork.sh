#!/bin/bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"
# TC-STRS-002: Frequent create/destroy stress

FAIL=0
for i in $(seq 1 50); do
    for card in $VE_NODES; do
        ve_exec -N "$card" ./sample_bin > /dev/null 2>&1 || FAIL=$((FAIL + 1)) &
    done
    wait
done

ZOMBIES=$(ps aux | grep "ve_exec" | grep -v grep | wc -l)
echo "Failure count: $FAIL"
echo "Residual ve_exec processes: $ZOMBIES"

if [ "$FAIL" -eq 0 ] && [ "$ZOMBIES" -eq 0 ]; then
    echo "PASS"
else
    echo "FAIL"
    exit 1
fi
