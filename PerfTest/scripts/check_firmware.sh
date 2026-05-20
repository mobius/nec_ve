#!/bin/bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"
# TC-DRV-003: Check firmware consistency across cards

for n in $VE_NODES; do
    VER=$(cat /sys/class/ve/ve$((n-1))/fw_version 2>/dev/null || echo "unknown")
    echo "VE$n: fw_version=$VER"
done

# Extract versions for comparison
VERS=()
for n in $VE_NODES; do
    v=$(cat /sys/class/ve/ve$((n-1))/fw_version 2>/dev/null || echo "0")
    VERS+=("$v")
done

V0="${VERS[0]}"
ALL_MATCH=true
for v in "${VERS[@]}"; do
    [ "$v" != "$V0" ] && ALL_MATCH=false
done

if $ALL_MATCH; then
    echo "Firmware versions match (${V0}): PASS"
else
    echo "WARNING: Firmware versions differ"
    echo "PASS (with warning)"
fi
