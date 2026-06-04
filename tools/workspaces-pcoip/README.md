# WorkSpaces PCoIP Client (QEMU/KVM VM)

Runs the Amazon WorkSpaces PCoIP client via a headless Ubuntu 20.04 KVM VM
with X11 forwarding. The native Ubuntu 22/24 client only supports DCV, so
PCoIP WorkSpaces (e.g. Amazon Linux 2) need the Ubuntu 20.04 client — but
glib 2.64 + .NET CoreCLR crashes on kernel 6.17+. A lightweight KVM VM with
an older kernel is the workaround.

## Quick start

```bash
# First time: create the VM disk from the base image
cd vm/
qemu-img create -b focal-server-cloudimg-amd64.img -f qcow2 -F qcow2 workspaces-vm.qcow2
genisoimage -output seed.iso -volid cidata -joliet -rock user-data meta-data
cd ..

# Launch (starts VM + opens WorkSpaces client)
./run.sh

# Stop the VM
./run.sh stop
```

## How it works

`run.sh` uses QEMU/KVM to boot a headless Ubuntu 20.04 VM with cloud-init.
cloud-init provisions the WorkSpaces client on first boot (`vm/user-data`).

| File | Role |
|------|------|
| `run.sh` | Start VM, wait for cloud-init, launch client via SSH X11 forwarding |
| `vm/user-data` | cloud-init config: packages, WorkSpaces client install, SSH setup |
| `vm/meta-data` | cloud-init VM identity |
| `vm/start-vm.sh` | Start VM only (no client launch) |
| `vm/stop-vm.sh` | Graceful VM shutdown |

The WorkSpaces client window appears natively on your desktop via X11
forwarding through SSH on `localhost:2222`.

## Prerequisites

- QEMU/KVM (`qemu-system-x86_64`, `qemu-img`)
- `genisoimage`
- SSH key in `vm/user-data` authorized_keys

## Connection details

| Field | Value |
|-------|-------|
| Registration code | `wsdub+LVF37D` |
| Username | `meaningfy2` |

## VM artifacts (generated, not tracked)

- `vm/workspaces-vm.qcow2` — VM disk (overlay on `focal-server-cloudimg-amd64.img`)
- `vm/seed.iso` — cloud-init seed ISO
- `vm/vm.pid` — QEMU PID file
- `vm/focal-server-cloudimg-amd64.img` — base Ubuntu 20.04 cloud image (~618MB, download separately)
