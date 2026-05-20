#!/bin/bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"
# TC-DRV-005: Check dmesg for VE-related errors

ERRORS=$(dmesg | grep -i -E "ve_drv|vecmd|veos" | grep -i -E "error|fail|warn" || true)

if [ -z "$ERRORS" ]; then
    echo "No VE-related errors in dmesg"
    echo "PASS"
else
    echo "Found potential issues:"
    echo "$ERRORS"
    echo "FAIL"
    exit 1
fi
