#!/bin/bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"
# TC-MULT-002: Mixed workload across cards

ve_exec -N $VE_FIRST ./ve_float_test > /tmp/ve${VE0}_load.txt 2>&1 &
PID0=$!
ve_exec -N ${VE_NODE_ARRAY[1]} ./ve_matmul > /tmp/ve${VE1}_load.txt 2>&1 &
PID1=$!
ve_exec -N ${VE_NODE_ARRAY[2]} ./sample_bin > /tmp/ve${VE2}_load.txt 2>&1 &
PID2=$!

wait $PID0
wait $PID1
wait $PID2

PASS=true
if grep -q "PASS" /tmp/ve${VE0}_load.txt 2>/dev/null; then
    echo "VE0 (dot product): PASS"
else
    echo "VE0 (dot product): FAIL"
    PASS=false
fi

if grep -q "PASS" /tmp/ve${VE1}_load.txt 2>/dev/null; then
    echo "VE1 (matmul): PASS"
else
    echo "VE1 (matmul): FAIL"
    PASS=false
fi

if grep -q "Hello World" /tmp/ve${VE2}_load.txt 2>/dev/null; then
    echo "VE2 (hello): PASS"
else
    echo "VE2 (hello): FAIL"
    PASS=false
fi

if $PASS; then
    echo "OVERALL: PASS"
else
    echo "OVERALL: FAIL"
    exit 1
fi
