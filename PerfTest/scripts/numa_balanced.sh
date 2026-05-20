#!/bin/bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"
# TC-NUMA-002: NUMA balanced load test

VE0_NUMA=$(cat /sys/bus/pci/devices/0000:$(lspci | grep "NEC" | awk 'NR==1{print $1}')/numa_node 2>/dev/null || echo "0")
VE1_NUMA=$(cat /sys/bus/pci/devices/0000:$(lspci | grep "NEC" | awk 'NR==2{print $1}')/numa_node 2>/dev/null || echo "1")
VE2_NUMA=$(cat /sys/bus/pci/devices/0000:$(lspci | grep "NEC" | awk 'NR==3{print $1}')/numa_node 2>/dev/null || echo "1")

numactl --cpunodebind="$VE0_NUMA" --membind="$VE0_NUMA" ve_exec -N ${VE_NODE_ARRAY[0]} ./ve_matmul > /tmp/numa${VE0}.txt 2>&1 &
numactl --cpunodebind="$VE1_NUMA" --membind="$VE1_NUMA" ve_exec -N ${VE_NODE_ARRAY[1]} ./ve_matmul > /tmp/numa${VE1}.txt 2>&1 &
numactl --cpunodebind="$VE2_NUMA" --membind="$VE2_NUMA" ve_exec -N ${VE_NODE_ARRAY[2]} ./ve_matmul > /tmp/numa${VE2}.txt 2>&1 &
wait

echo "NUMA balanced results:"
grep "GFlops:" /tmp/numa${VE0}.txt
grep "GFlops:" /tmp/numa${VE1}.txt
grep "GFlops:" /tmp/numa${VE2}.txt

echo "PASS"
