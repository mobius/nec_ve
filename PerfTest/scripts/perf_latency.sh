#!/bin/bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"
# TC-PERF-005: MPI ping-pong latency across card pairs

PASS=true
NODE_ARRAY=($VE_NODES)

# Generate all unique node pairs from VE_NODES
for (( i=0; i<${#NODE_ARRAY[@]}; i++ )); do
    for (( j=i+1; j<${#NODE_ARRAY[@]}; j++ )); do
        a=${NODE_ARRAY[$i]}
        b=${NODE_ARRAY[$j]}
        OUT=$(mpirun -np 1 -ve "$a" ./mpi_pingpong : -np 1 -ve "$b" ./mpi_pingpong 2>&1)
        LAT=$(echo "$OUT" | grep "latency:" | awk '{print $3}')
        echo "VE$a <-> VE$b: ${LAT} us"
        if [ -z "$LAT" ] || [ "$(echo "$LAT > 500" | bc 2>/dev/null || echo 1)" -eq 1 ]; then
            echo "Pair $a,$b: FAIL (latency too high)"
            PASS=false
        fi
    done
done

if $PASS; then
    echo "PASS"
else
    echo "FAIL"
    exit 1
fi
