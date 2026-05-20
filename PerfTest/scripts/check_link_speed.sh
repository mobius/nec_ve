#!/bin/bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"
# TC-HW-002: Check PCIe link speed for all VE cards (uses sysfs, no sudo needed)

VE_DEVICES=$(lspci | grep "NEC" | awk '{print $1}')
PASS=true

for dev in $VE_DEVICES; do
    pci_path="/sys/bus/pci/devices/0000:${dev}"
    speed=$(cat "$pci_path/current_link_speed" 2>/dev/null)
    width=$(cat "$pci_path/current_link_width" 2>/dev/null)
    if echo "$speed" | grep -q "8.0 GT/s" && [ "$width" = "16" ]; then
        echo "VE $dev: PASS - Speed=$speed Width=x${width}"
    else
        echo "VE $dev: FAIL - Speed=${speed:-N/A} Width=x${width:-N/A}"
        PASS=false
    fi
done

if $PASS; then
    echo "OVERALL: PASS"
else
    echo "OVERALL: FAIL"
    exit 1
fi
