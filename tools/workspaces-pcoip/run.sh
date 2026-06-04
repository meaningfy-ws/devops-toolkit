#!/usr/bin/env bash
# Launch the Amazon WorkSpaces PCoIP client via a headless Ubuntu 20.04 VM.
#
# Why: PCoIP requires Ubuntu 20.04 client, but glib 2.64 + .NET CoreCLR
# crash on kernel 6.17+. A lightweight KVM VM with an older kernel is the
# only reliable workaround.
#
# The WorkSpaces client window appears natively on your desktop via X11 forwarding.
#
# Usage:  ./run.sh          — start VM (if needed) and open WorkSpaces client
#         ./run.sh stop     — stop the VM
#
# Registration code: wsdub+LVF37D
# Username:          meaningfy2

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VM_DIR="$SCRIPT_DIR/vm"
VM_DISK="$VM_DIR/workspaces-vm.qcow2"
SEED_ISO="$VM_DIR/seed.iso"
SSH_PORT=2222
SSH_OPTS="-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR"

# --- Stop command -------------------------------------------------------------
if [[ "${1:-}" == "stop" ]]; then
    if [[ -f "$VM_DIR/vm.pid" ]]; then
        PID=$(cat "$VM_DIR/vm.pid")
        if kill -0 "$PID" 2>/dev/null; then
            ssh $SSH_OPTS -p $SSH_PORT ws@localhost "sudo poweroff" 2>/dev/null || true
            sleep 3
            kill -0 "$PID" 2>/dev/null && kill "$PID" 2>/dev/null || true
        fi
        rm -f "$VM_DIR/vm.pid"
    else
        pkill -f "workspaces-vm.qcow2" 2>/dev/null || true
    fi
    echo "VM stopped."
    exit 0
fi

# --- Start VM if not running --------------------------------------------------
if ! pgrep -f "workspaces-vm.qcow2" > /dev/null 2>&1; then
    echo "Starting WorkSpaces VM..."
    qemu-system-x86_64 \
        -name workspaces-vm \
        -machine type=q35,accel=kvm \
        -cpu host \
        -smp 2 \
        -m 2048 \
        -drive file="$VM_DISK",format=qcow2,if=virtio \
        -drive file="$SEED_ISO",format=raw,if=virtio,media=cdrom \
        -netdev user,id=net0,hostfwd=tcp::${SSH_PORT}-:22 \
        -device virtio-net-pci,netdev=net0 \
        -display none \
        -daemonize \
        -pidfile "$VM_DIR/vm.pid"

    echo -n "Waiting for VM to boot"
    for i in $(seq 1 90); do
        if ssh $SSH_OPTS -o ConnectTimeout=2 -p $SSH_PORT ws@localhost true 2>/dev/null; then
            echo " ready."
            break
        fi
        sleep 2
        printf "."
    done
    echo ""

    # Wait for cloud-init to finish installing WorkSpaces client
    echo -n "Waiting for WorkSpaces client install"
    for i in $(seq 1 120); do
        if ssh $SSH_OPTS -p $SSH_PORT ws@localhost "test -f /home/ws/READY" 2>/dev/null; then
            echo " done."
            break
        fi
        sleep 3
        printf "."
    done
    echo ""
else
    echo "VM already running."
fi

# --- Launch WorkSpaces client with X11 forwarding ----------------------------
echo "Launching WorkSpaces PCoIP client..."
echo "  Registration code: wsdub+LVF37D"
echo "  Username:          meaningfy2"
echo ""
echo "To stop: $0 stop"
echo ""

# Run in foreground so the window stays open
ssh $SSH_OPTS -X -p $SSH_PORT ws@localhost workspacesclient
