#!/bin/bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"
# TC-FUNC-006: Repeated program load/unload stability

PASS=true
for card in $VE_NODES; do
    for run in $(seq 1 10); do
        if ! ve_exec -N "$card" ./sample_bin > /dev/null 2>&1; then
            echo "VE$card run $run: FAIL"
            PASS=false
        fi
    done
    echo "VE$card: 10 runs completed"
done

STATE=$(ve_state_get)
echo "$STATE"

if $PASS && echo "$STATE" | grep -q "ONLINE"; then
    echo "PASS"
else
    echo "FAIL"
    exit 1
fi
