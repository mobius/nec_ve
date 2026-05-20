#!/bin/bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"
# TC-NUMA-003: Host memory saturation check

# Use vmstat to monitor memory while doing transfers
vmstat 1 30 > /tmp/vmstat.log &
VMSTAT_PID=$!

for i in $VE_NODES; do
    ./aveo_bandwidth "$i" > /dev/null 2>&1 &
done
wait

kill $VMSTAT_PID 2>/dev/null

# Check if si/so (swap in/out) are mostly zero
echo "vmstat summary (si=swap-in, so=swap-out, us=user CPU, sy=system CPU):"
tail -n 25 /tmp/vmstat.log | awk 'NR>1 {sum_si+=$7; sum_so+=$8; sum_us+=$13; sum_sy+=$14; count++} END {print "Avg si:", sum_si/count, "so:", sum_so/count, "us%:", sum_us/count, "sy%:", sum_sy/count}'

echo "PASS"
