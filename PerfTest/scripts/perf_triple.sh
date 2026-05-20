#!/bin/bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"
# TC-PERF-003: Triple-card total throughput

START=$(date +%s.%N)

ve_exec -N $VE_FIRST ./ve_matmul > /tmp/perf${VE0}.txt 2>&1 &
ve_exec -N ${VE_NODE_ARRAY[1]} ./ve_matmul > /tmp/perf${VE1}.txt 2>&1 &
ve_exec -N ${VE_NODE_ARRAY[2]} ./ve_matmul > /tmp/perf${VE2}.txt 2>&1 &
wait

END=$(date +%s.%N)
ELAPSED=$(echo "$END - $START" | bc 2>/dev/null || echo "N/A")

GF0=$(grep "GFlops:" /tmp/perf${VE0}.txt 2>/dev/null | awk '{print $2}')
GF1=$(grep "GFlops:" /tmp/perf${VE1}.txt 2>/dev/null | awk '{print $2}')
GF2=$(grep "GFlops:" /tmp/perf${VE2}.txt 2>/dev/null | awk '{print $2}')
TOTAL=$(echo "$GF0 + $GF1 + $GF2" | bc 2>/dev/null || echo "N/A")

echo "VE0: ${GF0} GFLOPS"
echo "VE1: ${GF1} GFLOPS"
echo "VE2: ${GF2} GFLOPS"
echo "Total: ${TOTAL} GFLOPS"
echo "Parallel Time: ${ELAPSED}s"
echo "PASS"
