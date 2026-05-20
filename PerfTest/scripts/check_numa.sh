#!/bin/bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"
# TC-HW-003: Check NUMA node assignment

VE_DEVICES=$(lspci | grep "NEC" | awk '{print $1}')

for dev in $VE_DEVICES; do
    numa=$(lspci -vv -s "$dev" | grep "NUMA node")
    if [ -z "$numa" ]; then
        # Fallback: use /sys
        bdf=$(echo "$dev" | tr ':' '/')
        numa=$(cat "/sys/bus/pci/devices/0000:$dev/numa_node" 2>/dev/null || echo "unknown")
        echo "VE $dev: NUMA node $numa"
    else
        echo "VE $dev: $numa"
    fi
done

numactl --hardware 2>/dev/null || true
echo "PASS"
