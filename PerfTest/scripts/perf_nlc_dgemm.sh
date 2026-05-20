#!/bin/bash
# TC-PERF-007: NLC cblas_dgemm performance baseline
# Tests NEC Numeric Library Collection BLAS on all 3 VE cards
# Expected: > 1200 GFLOPS per card (NLC 3.1.0, N=4096, 8 threads)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

NLC_LIB=/opt/nec/ve/nlc/3.1.0/lib
BINARY="${SCRIPT_DIR}/../ve_nlc_dgemm"
THRESHOLD=1200

# Check NLC library exists
if [ ! -f "${NLC_LIB}/libblas_openmp.so" ]; then
    echo "SKIP: NLC library not found: ${NLC_LIB}/libblas_openmp.so"
    exit 0
fi

# Check binary exists
if [ ! -f "$BINARY" ]; then
    echo "FAIL: Binary not found: $BINARY (run 'make ve_nlc_dgemm')"
    exit 1
fi

PASS=true
for i in $VE_NODES; do
    OUT=$(OMP_NUM_THREADS=8 VE_LD_LIBRARY_PATH="${NLC_LIB}" \
          ve_exec -N "$i" "$BINARY" 2>/dev/null)
    GF=$(echo "$OUT" | grep "^GFlops:" | awk '{print $2}')
    echo "VE$i: ${GF} GFLOPS (NLC cblas_dgemm, N=4096, 8 threads)"

    if [ -z "$GF" ] || [ "$(echo "$GF < $THRESHOLD" | bc 2>/dev/null || echo 1)" -eq 1 ]; then
        echo "VE$i: FAIL (expected > ${THRESHOLD} GFLOPS, got ${GF})"
        PASS=false
    fi
done

if $PASS; then
    echo "PASS"
else
    echo "FAIL"
    exit 1
fi
