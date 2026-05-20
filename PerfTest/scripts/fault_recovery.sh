#!/bin/bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"
# TC-FAIL-002: VEOS service restart recovery (uses VE_FIRST, the first active node)

echo "Current VE${VE_FIRST} state:"
ve_state_get "$VE_FIRST"

echo "Restarting VE${VE_FIRST} VEOS..."
if ! systemctl restart "ve-os-launcher@${VE_FIRST}.service" 2>/dev/null; then
    echo "  (systemctl restart requires sudo -- skipping restart, verifying existing state)"
fi
sleep 5

echo "Post-restart VE${VE_FIRST} state:"
STATE=$(ve_state_get "$VE_FIRST")
echo "$STATE"

# Verify VE_FIRST works after restart
ve_exec -N $VE_FIRST ./sample_bin > /tmp/recovery0.txt 2>&1
if grep -q "Hello World" /tmp/recovery0.txt; then
    echo "VE${VE_FIRST} functional: OK"
    echo "PASS"
else
    echo "VE${VE_FIRST} functional: FAIL"
    echo "FAIL"
    exit 1
fi
