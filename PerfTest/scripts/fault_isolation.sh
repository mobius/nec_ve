#!/bin/bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"
# TC-FAIL-001: Single card fault isolation

# VE0 runs a segfault program
ve_exec -N $VE_FIRST ./ve_segfault > /tmp/fault${VE0}.txt 2>&1 &
BAD_PID=$!

# VE1/VE2 run normally
ve_exec -N ${VE_NODE_ARRAY[1]} ./sample_bin > /tmp/fault${VE1}.txt 2>&1 &
ve_exec -N ${VE_NODE_ARRAY[2]} ./sample_bin > /tmp/fault${VE2}.txt 2>&1 &
wait

echo "VE0 fault result (expected crash):"
cat /tmp/fault${VE0}.txt | head -3 || true

STATE=$(ve_state_get)
echo ""
echo "Post-fault states:"
echo "$STATE"

# Verify VE1/VE2 still work
echo ""
echo "Re-verifying VE1/VE2:"
ve_exec -N ${VE_NODE_ARRAY[1]} ./sample_bin > /tmp/fault1_recheck.txt 2>&1
ve_exec -N ${VE_NODE_ARRAY[2]} ./sample_bin > /tmp/fault2_recheck.txt 2>&1

PASS=true
if grep -q "Hello World" /tmp/fault1_recheck.txt && grep -q "Hello World" /tmp/fault2_recheck.txt; then
    echo "VE1/VE2 isolation: OK"
else
    echo "VE1/VE2 isolation: FAIL"
    PASS=false
fi

# Verify VE0 recovers
echo ""
ve_exec -N $VE_FIRST ./sample_bin > /tmp/fault0_recheck.txt 2>&1
if grep -q "Hello World" /tmp/fault0_recheck.txt; then
    echo "VE0 recovery: OK"
else
    echo "VE0 recovery: FAIL"
    PASS=false
fi

if $PASS; then
    echo "PASS"
else
    echo "FAIL"
    exit 1
fi
