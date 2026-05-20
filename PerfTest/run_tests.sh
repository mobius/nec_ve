#!/bin/bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/scripts/common.sh"
set -e

# NEC VE 1.0 Three-Card Test Suite Runner
# Usage: ./run_tests.sh [category]
#   category: hw|drv|func|mult|perf|strs|numa|fail|all (default: all)

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

# Source environment
if [ -f /etc/profile.d/nec-ve.sh ]; then
    source /etc/profile.d/nec-ve.sh
fi
if [ -f /opt/nec/ve/mpi/3.10.0/bin/necmpivars.sh ]; then
    source /opt/nec/ve/mpi/3.10.0/bin/necmpivars.sh
fi

AVEO_OK=true
# libnfort_m.so.2 is a VE-arch library, not visible to ldconfig; check by file path
NFORT_LIB_VE1=/opt/nec/ve/nfort/5.4.1/lib/libnfort_m.so.2
NFORT_LIB_VE3=/opt/nec/ve3/nfort/5.4.1/lib/libnfort_m.so.2
[ -f "$NFORT_LIB_VE1" ] || [ -f "$NFORT_LIB_VE3" ] || AVEO_OK=false

RESULT_DIR="$SCRIPT_DIR/results"
LOG_DIR="$SCRIPT_DIR/logs"
mkdir -p "$RESULT_DIR" "$LOG_DIR"

TIMESTAMP=$(date +%Y%m%d_%H%M%S)
MASTER_LOG="$LOG_DIR/test_run_${TIMESTAMP}.log"

PASS_COUNT=0
FAIL_COUNT=0
SKIP_COUNT=0

log() {
    echo "$1" | tee -a "$MASTER_LOG"
}

skip_test() {
    local id="$1"
    local name="$2"
    local reason="$3"
    log ""
    log "=== [$id] $name ==="
    log "  [SKIP] $id - $reason"
    SKIP_COUNT=$((SKIP_COUNT + 1))
}

run_test() {
    local id="$1"
    local name="$2"
    local cmd="$3"
    local check="$4"

    log ""
    log "=== [$id] $name ==="
    local out_file="$RESULT_DIR/${id}.txt"

    if eval "$cmd" > "$out_file" 2>&1; then
        if [ -n "$check" ]; then
            if eval "$check" < "$out_file" >/dev/null 2>&1; then
                log "  [PASS] $id"
                PASS_COUNT=$((PASS_COUNT + 1))
            else
                log "  [FAIL] $id (output check failed)"
                FAIL_COUNT=$((FAIL_COUNT + 1))
            fi
        else
            log "  [PASS] $id"
            PASS_COUNT=$((PASS_COUNT + 1))
        fi
    else
        log "  [FAIL] $id (exit code non-zero)"
        FAIL_COUNT=$((FAIL_COUNT + 1))
    fi
}

# ==================== HW Tests ====================
run_hw_tests() {
    log "\n########## Hardware Identification Tests ##########"

    run_test "TC-HW-001" "PCIe Device Detection" \
        "lspci | grep 'NEC' | tee $RESULT_DIR/hw001_raw.txt" \
        "test $(lspci | grep -c 'NEC') -ge 3"

    run_test "TC-HW-002" "Link Speed Verification" \
        "bash $SCRIPT_DIR/scripts/check_link_speed.sh" \
        "grep -q 'PASS'"

    run_test "TC-HW-003" "NUMA Node Assignment" \
        "bash $SCRIPT_DIR/scripts/check_numa.sh" \
        "grep -q 'NUMA node'"

    run_test "TC-HW-004" "Device Nodes Existence" \
        "ls -la /dev/ve0 /dev/ve1 /dev/ve2" \
        "grep -q '/dev/ve'"
}

# ==================== DRV Tests ====================
run_drv_tests() {
    log "\n########## Driver & VEOS Status Tests ##########"

    run_test "TC-DRV-001" "VEOS Service Status" \
        "systemctl is-active ve-os-launcher@${VE_NODE_ARRAY[0]}.service ve-os-launcher@${VE_NODE_ARRAY[1]}.service ve-os-launcher@${VE_NODE_ARRAY[2]}.service" \
        "grep -q 'active'"

    run_test "TC-DRV-002" "VE Card State" \
        "ve_state_get" \
        "grep -c 'ONLINE' | awk '{exit (\$1>=3)?0:1}'"

    run_test "TC-DRV-003" "Firmware Consistency" \
        "bash $SCRIPT_DIR/scripts/check_firmware.sh" \
        "grep -q 'PASS'"

    run_test "TC-DRV-004" "Kernel Modules" \
        "lsmod | grep -E 've_drv|vp'" \
        "grep -q 've_drv'"

    run_test "TC-DRV-005" "Driver Log Check" \
        "bash $SCRIPT_DIR/scripts/check_dmesg.sh" \
        "grep -q 'PASS'"
}

# ==================== FUNC Tests ====================
run_func_tests() {
    log "\n########## Single-Card Function Tests ##########"

    for i in $VE_NODES; do
        run_test "TC-FUNC-001-VE$i" "Hello World on VE$i" \
            "ve_exec -N $i ./sample_bin" \
            "grep -q 'Hello World'"
    done

    for i in $VE_NODES; do
        run_test "TC-FUNC-002-VE$i" "Dot Product on VE$i" \
            "ve_exec -N $i ./ve_float_test" \
            "grep -q 'Result: PASS'"
    done

    for i in $VE_NODES; do
        run_test "TC-FUNC-003-VE$i" "Matrix Multiply on VE$i" \
            "ve_exec -N $i ./ve_matmul" \
            "grep -q 'Result: PASS'"
    done

    for i in $VE_NODES; do
        run_test "TC-FUNC-004-VE$i" "HBM Memory Check VE$i" \
            "ve_exec -N $i ./ve_mem_check $i" \
            "grep -q 'Total Memory'"
    done

    run_test "TC-FUNC-005" "Compiler Vectorization" \
        "nc++ -O3 -report-all -o /tmp/compile_test ve_matmul.c 2>&1; rm -f /tmp/compile_test" \
        "grep -q 'Vectorized'"

    run_test "TC-FUNC-006" "Repeated Load Stability" \
        "bash $SCRIPT_DIR/scripts/repeated_load.sh" \
        "grep -q 'PASS'"
}

# ==================== MULT Tests ====================
run_mult_tests() {
    log "\n########## Multi-Card Parallel Tests ##########"

    run_test "TC-MULT-001" "Independent Parallel Tasks" \
        "bash $SCRIPT_DIR/scripts/multi_independent.sh" \
        "grep -q 'PASS'"

    run_test "TC-MULT-002" "Mixed Workload" \
        "bash $SCRIPT_DIR/scripts/multi_mixed.sh" \
        "grep -q 'PASS'"

    if command -v mpirun >/dev/null 2>&1; then
        run_test "TC-MULT-003" "MPI Basic Communication" \
            "mpirun -ve ${VE_FIRST}-${VE_NODE_ARRAY[-1]} -np 3 ./mpi_hello" \
            "grep -c 'Hello from rank' | grep -q "3""

        run_test "TC-MULT-004" "MPI AllReduce" \
            "mpirun -ve ${VE_FIRST}-${VE_NODE_ARRAY[-1]} -np 3 ./mpi_allreduce_test" \
            "grep -q 'PASS'"
    else
        skip_test "TC-MULT-003" "MPI Basic Communication" "mpirun not found"
        skip_test "TC-MULT-004" "MPI AllReduce" "mpirun not found"
    fi

    _aveo_ok=$AVEO_OK
    if ! $_aveo_ok; then
        skip_test "TC-MULT-005" "AVEO Multi-Device" "AVEO runtime libraries incomplete (libnfort_m missing)"
    else
        run_test "TC-MULT-005" "AVEO Multi-Device" \
            "./aveo_multi_test $VE_NODES" \
            "grep -q 'PASS'"
    fi
}

# ==================== PERF Tests ====================
run_perf_tests() {
    log "\n########## Performance Benchmark Tests ##########"

    run_test "TC-PERF-001" "Single-Card MatMul Baseline" \
        "bash $SCRIPT_DIR/scripts/perf_baseline.sh" \
        "grep -q 'PASS'"

    run_test "TC-PERF-002" "HBM Bandwidth" \
        "bash $SCRIPT_DIR/scripts/perf_bandwidth.sh" \
        "grep -q 'PASS'"

    run_test "TC-PERF-003" "Triple-Card Throughput" \
        "bash $SCRIPT_DIR/scripts/perf_triple.sh" \
        "grep -q 'PASS'"

    if ! $AVEO_OK; then
        skip_test "TC-PERF-004" "PCIe Transfer Bandwidth" "AVEO runtime libraries incomplete (libnfort_m missing)"
    else
        run_test "TC-PERF-004" "PCIe Transfer Bandwidth" \
            "bash $SCRIPT_DIR/scripts/perf_pcie.sh" \
            "grep -q 'PASS'"
    fi

    if command -v mpirun >/dev/null 2>&1; then
        run_test "TC-PERF-005" "MPI Ping-Pong Latency" \
            "bash $SCRIPT_DIR/scripts/perf_latency.sh" \
            "grep -q 'PASS'"
    else
        skip_test "TC-PERF-005" "MPI Ping-Pong Latency" "mpirun not found"
    fi

    run_test "TC-PERF-006" "Power & Thermal Monitor" \
        "bash $SCRIPT_DIR/scripts/perf_power.sh" \
        "grep -q 'PASS'"

    NLC_LIB=/opt/nec/ve/nlc/3.1.0/lib
    if [ -f "${NLC_LIB}/libblas_openmp.so" ]; then
        run_test "TC-PERF-007" "NLC cblas_dgemm Baseline" \
            "bash $SCRIPT_DIR/scripts/perf_nlc_dgemm.sh" \
            "grep -q 'PASS'"
    else
        skip_test "TC-PERF-007" "NLC cblas_dgemm Baseline" "NLC library not installed (${NLC_LIB})"
    fi
}

# ==================== STRS Tests ====================
run_strs_tests() {
    log "\n########## Stability & Stress Tests ##########"

    run_test "TC-STRS-001" "30-Minute Stress Test" \
        "bash $SCRIPT_DIR/scripts/stress_30min.sh" \
        "grep -q 'PASS'"

    run_test "TC-STRS-002" "Fork Bomb Stability" \
        "bash $SCRIPT_DIR/scripts/stress_fork.sh" \
        "grep -q 'PASS'"

    run_test "TC-STRS-003" "Thermal Throttle Detection" \
        "bash $SCRIPT_DIR/scripts/stress_thermal.sh" \
        "grep -q 'PASS'"
}

# ==================== NUMA Tests ====================
run_numa_tests() {
    log "\n########## NUMA Affinity Tests ##########"

    run_test "TC-NUMA-001" "NUMA Binding" \
        "bash $SCRIPT_DIR/scripts/numa_binding.sh" \
        "grep -q 'PASS'"

    run_test "TC-NUMA-002" "NUMA Balanced Load" \
        "bash $SCRIPT_DIR/scripts/numa_balanced.sh" \
        "grep -q 'PASS'"

    run_test "TC-NUMA-003" "Host Memory Saturation" \
        "bash $SCRIPT_DIR/scripts/numa_memsat.sh" \
        "grep -q 'PASS'"
}

# ==================== FAIL Tests ====================
run_fail_tests() {
    log "\n########## Fault Recovery Tests ##########"

    run_test "TC-FAIL-001" "Fault Isolation" \
        "bash $SCRIPT_DIR/scripts/fault_isolation.sh" \
        "grep -q 'PASS'"

    run_test "TC-FAIL-002" "Service Recovery" \
        "bash $SCRIPT_DIR/scripts/fault_recovery.sh" \
        "grep -q 'PASS'"
}

# ==================== Main ====================
print_summary() {
    log ""
    log "========================================"
    log "           TEST SUMMARY"
    log "========================================"
    log "  Passed:  $PASS_COUNT"
    log "  Failed:  $FAIL_COUNT"
    log "  Skipped: $SKIP_COUNT"
    log "  Total:   $((PASS_COUNT + FAIL_COUNT + SKIP_COUNT))"
    log ""
    log "  Log file: $MASTER_LOG"
    log "  Results:  $RESULT_DIR"
    log "========================================"

    if [ "$FAIL_COUNT" -eq 0 ]; then
        log "  OVERALL: ALL TESTS PASSED"
    else
        log "  OVERALL: $FAIL_COUNT TEST(S) FAILED"
    fi
}

main() {
    local category="${1:-all}"

    log "========================================"
    log "NEC VE 1.0 Three-Card Test Suite"
    log "Started: $(date)"
    log "Category: $category"
    log "========================================"

    case "$category" in
        hw)   run_hw_tests ;;
        drv)  run_drv_tests ;;
        func) run_func_tests ;;
        mult) run_mult_tests ;;
        perf) run_perf_tests ;;
        strs) run_strs_tests ;;
        numa) run_numa_tests ;;
        fail) run_fail_tests ;;
        all)
            run_hw_tests
            run_drv_tests
            run_func_tests
            run_mult_tests
            run_perf_tests
            run_strs_tests
            run_numa_tests
            run_fail_tests
            ;;
        *)
            echo "Usage: $0 [hw|drv|func|mult|perf|strs|numa|fail|all]"
            exit 1
            ;;
    esac

    print_summary
}

main "$@"
