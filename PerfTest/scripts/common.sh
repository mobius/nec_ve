#!/bin/bash
# Common helper for VE test scripts
# Detects available VE nodes automatically (no sudo needed)

if [ -z "$VE_NODES" ]; then
    # Primary: detect from active ve-os-launcher systemd services
    SYSD_NODES=$(systemctl list-units 've-os-launcher@*.service' --state=active --no-legend 2>/dev/null \
        | grep -oP 've-os-launcher@\K\d+' | sort -n | tr '\n' ' ')
    [ -n "$SYSD_NODES" ] && VE_NODES="$SYSD_NODES"

    # Fallback: hard-coded based on known system config
    [ -z "$VE_NODES" ] && VE_NODES="1 2 3"
fi

# Set VE_LD_LIBRARY_PATH so VE-side binaries (aveorun_ve1 etc.) can find nfort shared libs
_nfort_lib=/opt/nec/ve/nfort/5.4.1/lib
if [ -d "$_nfort_lib" ]; then
    if [ -z "${VE_LD_LIBRARY_PATH:-}" ]; then
        export VE_LD_LIBRARY_PATH="$_nfort_lib"
    else
        export VE_LD_LIBRARY_PATH="$_nfort_lib:$VE_LD_LIBRARY_PATH"
    fi
fi
unset _nfort_lib

VE_NODE_ARRAY=($VE_NODES)
VE_COUNT=${#VE_NODE_ARRAY[@]}
VE_FIRST=${VE_NODE_ARRAY[0]}

# Short aliases for convenience
VE0=$VE_FIRST
VE1=${VE_NODE_ARRAY[1]}
VE2=${VE_NODE_ARRAY[2]}

# Drop-in replacement for "sudo vecmd state get" using systemd + sysfs (no sudo)
ve_state_get() {
    local _nodes="${1:-$VE_NODES}"
    for n in $_nodes; do
        local svc_state
        svc_state=$(systemctl is-active "ve-os-launcher@${n}.service" 2>/dev/null)
        if [ "$svc_state" = "active" ]; then
            echo "[ ONLINE ] VE${n}"
        else
            echo "[ OFFLINE ] VE${n}"
        fi
    done
}
