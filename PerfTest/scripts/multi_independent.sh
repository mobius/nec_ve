#!/bin/bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"
# TC-MULT-001: Multi-card independent parallel tasks

START=$(date +%s.%N)

ve_exec -N $VE_FIRST ./sample_bin > /tmp/ve${VE0}_out.txt 2>&1 &
PID0=$!
ve_exec -N ${VE_NODE_ARRAY[1]} ./sample_bin > /tmp/ve${VE1}_out.txt 2>&1 &
PID1=$!
ve_exec -N ${VE_NODE_ARRAY[2]} ./sample_bin > /tmp/ve${VE2}_out.txt 2>&1 &
PID2=$!

wait $PID0
wait $PID1
wait $PID2

END=$(date +%s.%N)
ELAPSED=$(echo "$END - $START" | bc 2>/dev/null || echo "N/A")

echo "Total elapsed: ${ELAPSED}s"

PASS=true
for i in $VE_NODES; do
    OUT=$(cat /tmp/ve${i}_out.txt 2>/dev/null)
    if [ "$OUT" = "Hello World" ]; then
        echo "VE$i: PASS"
    else
        echo "VE$i: FAIL (got: '$OUT')"
        PASS=false
    fi
done

if $PASS; then
    echo "OVERALL: PASS"
else
    echo "OVERALL: FAIL"
    exit 1
fi
