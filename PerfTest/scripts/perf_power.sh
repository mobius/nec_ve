#!/bin/bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"
# TC-PERF-006: Power and thermal monitoring (quick version)

# Try to read power via IPMI if available
if command -v ipmitool >/dev/null 2>&1; then
    POWER=$(ipmitool sdr list 2>/dev/null | grep -i "power" | head -5 || true)
    if [ -n "$POWER" ]; then
        echo "Power sensors:"
        echo "$POWER"
    fi
fi

# Check VE card states via systemd (no sudo)
echo "VE states:"
ve_state_get

# Check VE card temperatures via sysfs sensors
# sensor_15 reports die temperature in units of 1/1,000,000 °C
for ve_dev in /sys/class/ve/ve*; do
    [ -d "$ve_dev" ] || continue
    ve_name=$(basename "$ve_dev")
    temp_raw=$(cat "$ve_dev/sensor_15" 2>/dev/null)
    if [ -n "$temp_raw" ] && [ "$temp_raw" -gt 0 ] 2>/dev/null; then
        temp_c=$(awk "BEGIN {printf \"%.1f\", $temp_raw/1000000}")
        echo "$ve_name temperature: ${temp_c}°C"
    fi
done

# Check CPU thermal
if [ -f /sys/class/thermal/thermal_zone0/temp ]; then
    TEMP=$(cat /sys/class/thermal/thermal_zone0/temp 2>/dev/null)
    if [ -n "$TEMP" ]; then
        echo "CPU thermal zone0: $((TEMP / 1000)) C"
    fi
fi

echo "PASS"
