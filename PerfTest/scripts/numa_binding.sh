#!/bin/bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"
# TC-NUMA-001: NUMA binding performance comparison

# Determine NUMA nodes of each VE card
VE0_NUMA=$(cat /sys/bus/pci/devices/0000:$(lspci | grep "NEC" | awk 'NR==1{print $1}')/numa_node 2>/dev/null || echo "0")
VE1_NUMA=$(cat /sys/bus/pci/devices/0000:$(lspci | grep "NEC" | awk 'NR==2{print $1}')/numa_node 2>/dev/null || echo "1")
VE2_NUMA=$(cat /sys/bus/pci/devices/0000:$(lspci | grep "NEC" | awk 'NR==3{print $1}')/numa_node 2>/dev/null || echo "1")

echo "VE0 NUMA: $VE0_NUMA, VE1 NUMA: $VE1_NUMA, VE2 NUMA: $VE2_NUMA"

echo "=== Same NUMA binding ==="
numactl --cpunodebind="$VE0_NUMA" --membind="$VE0_NUMA" ve_exec -N ${VE_NODE_ARRAY[0]} ./ve_matmul 2>&1 | grep "GFlops:"
numactl --cpunodebind="$VE1_NUMA" --membind="$VE1_NUMA" ve_exec -N ${VE_NODE_ARRAY[1]} ./ve_matmul 2>&1 | grep "GFlops:"
numactl --cpunodebind="$VE2_NUMA" --membind="$VE2_NUMA" ve_exec -N ${VE_NODE_ARRAY[2]} ./ve_matmul 2>&1 | grep "GFlops:"

echo "=== Cross NUMA (for comparison) ==="
CROSS0=$((1 - VE0_NUMA))
CROSS1=$((1 - VE1_NUMA))
numactl --cpunodebind="$CROSS0" --membind="$CROSS0" ve_exec -N ${VE_NODE_ARRAY[0]} ./ve_matmul 2>&1 | grep "GFlops:" || true
numactl --cpunodebind="$CROSS1" --membind="$CROSS1" ve_exec -N ${VE_NODE_ARRAY[1]} ./ve_matmul 2>&1 | grep "GFlops:" || true

echo "PASS"
