#!/usr/bin/env bash
# Launch the WorkSpaces PCoIP VM (headless, connect via SSH X11 forwarding)
set -euo pipefail

VM_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VM_DISK="$VM_DIR/workspaces-vm.qcow2"
SEED_ISO="$VM_DIR/seed.iso"
SSH_PORT=2222

# Check if VM is already running
if pgrep -f "workspaces-vm.qcow2" > /dev/null 2>&1; then
    echo "VM already running. Connect with:"
    echo "  ssh -X -p $SSH_PORT ws@localhost"
    echo "  Then run: workspacesclient"
    exit 0
fi

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

echo "VM started (headless). Waiting for SSH..."

# Wait for SSH to become available
for i in $(seq 1 60); do
    if ssh -o StrictHostKeyChecking=no -o ConnectTimeout=2 -p $SSH_PORT ws@localhost true 2>/dev/null; then
        echo "SSH ready."
        break
    fi
    sleep 2
    printf "."
done
echo ""

# Check if WorkSpaces client is installed
if ssh -p $SSH_PORT ws@localhost "test -f /home/ws/READY" 2>/dev/null; then
    echo "WorkSpaces client is ready."
else
    echo "Cloud-init still running. Wait a minute and try again."
    echo "Check progress: ssh -p $SSH_PORT ws@localhost tail -f /var/log/cloud-init-output.log"
fi

echo ""
echo "============================================================"
echo "To connect:"
echo "  ssh -X -p $SSH_PORT ws@localhost workspacesclient"
echo ""
echo "To stop the VM:"
echo "  $VM_DIR/stop-vm.sh"
echo "============================================================"
