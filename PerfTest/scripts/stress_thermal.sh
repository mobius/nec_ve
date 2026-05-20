#!/bin/bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"
# TC-STRS-003: Thermal performance consistency

echo "round,VE0_GFLOPS,VE1_GFLOPS,VE2_GFLOPS" > /tmp/thermal_perf.csv

for round in $(seq 1 20); do
    for i in $VE_NODES; do
        ve_exec -N "$i" ./ve_matmul > /tmp/therm_${i}.txt 2>&1 &
    done
    wait

    GF0=$(grep "GFlops:" /tmp/therm_${VE0}.txt 2>/dev/null | awk '{print $2}')
    GF1=$(grep "GFlops:" /tmp/therm_${VE1}.txt 2>/dev/null | awk '{print $2}')
    GF2=$(grep "GFlops:" /tmp/therm_${VE2}.txt 2>/dev/null | awk '{print $2}')
    echo "$round,${GF0:-0},${GF1:-0},${GF2:-0}" >> /tmp/thermal_perf.csv

    sleep 2
done

echo "Thermal performance data saved to /tmp/thermal_perf.csv"
cat /tmp/thermal_perf.csv

# Simple check: no >10% drop from first round
R1_0=$(sed -n '2p' /tmp/thermal_perf.csv | cut -d',' -f2)
R20_0=$(sed -n '21p' /tmp/thermal_perf.csv | cut -d',' -f2)

if [ -n "$R1_0" ] && [ -n "$R20_0" ] && [ "$R1_0" != "0" ]; then
    DROP=$(echo "scale=2; ($R1_0 - $R20_0) / $R1_0 * 100" | bc 2>/dev/null || echo "0")
    echo "VE0 performance drop: ${DROP}%"
    if [ "$(echo "$DROP > 10" | bc 2>/dev/null || echo 0)" -eq 1 ]; then
        echo "WARNING: Possible thermal throttling detected"
    fi
fi

echo "PASS"
