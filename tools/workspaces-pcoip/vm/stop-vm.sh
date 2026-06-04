#!/usr/bin/env bash
set -euo pipefail
VM_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [[ -f "$VM_DIR/vm.pid" ]]; then
    PID=$(cat "$VM_DIR/vm.pid")
    if kill -0 "$PID" 2>/dev/null; then
        # Graceful shutdown via SSH
        ssh -o ConnectTimeout=3 -p 2222 ws@localhost "sudo poweroff" 2>/dev/null || true
        sleep 5
        # Force kill if still running
        kill -0 "$PID" 2>/dev/null && kill "$PID" 2>/dev/null || true
        echo "VM stopped."
    else
        echo "VM not running."
    fi
    rm -f "$VM_DIR/vm.pid"
else
    pkill -f "workspaces-vm.qcow2" 2>/dev/null && echo "VM stopped." || echo "VM not running."
fi
