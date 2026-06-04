# WorkSpaces PCoIP Client (QEMU/KVM VM)

Runs the Amazon WorkSpaces PCoIP client via a headless Ubuntu 20.04 KVM VM
with X11 forwarding. The native Ubuntu 22/24 client only supports DCV, so
PCoIP WorkSpaces (e.g. Amazon Linux 2) need the Ubuntu 20.04 client — but
glib 2.64 + .NET CoreCLR crashes on kernel 6.17+. A lightweight KVM VM with
an older kernel is the workaround.

## Prerequisites

- **QEMU/KVM** — `qemu-system-x86_64` and `qemu-img`
- **`genisoimage`** — `sudo apt install genisoimage` (Ubuntu/Debian). On macOS: `brew install cdrtools` and use `mkisofs`
- **Running X server** — the WorkSpaces client window renders locally via X11 forwarding. On Linux: Xorg or Wayland with XWayland. On macOS: XQuartz. On WSL: an X server like VcXsrv
- **SSH key pair** — see [SSH setup](#ssh-setup) below

### SSH setup

`run.sh` connects to the VM via SSH X11 forwarding on `localhost:2222`. It
relies on your SSH agent having the private key that matches the public key
in `vm/user-data`:

1. Edit `vm/user-data` and replace the `ssh_authorized_keys` entry with **your own** public key
2. Make sure your SSH agent has the corresponding private key loaded (`ssh-add -l`)
3. If you don't use an agent, add `-i ~/.ssh/your_key` to the `SSH_OPTS` at the top of `run.sh` (or change to password auth — edit `user-data` to set `lock_passwd: true` and add `chpasswd` to `runcmd`)

## Setup (first time only)

```bash
# 1. Download the Ubuntu 20.04 cloud image (~618 MB)
#    Pick the right image for your architecture:
#    https://cloud-images.ubuntu.com/focal/current/focal-server-cloudimg-amd64.img
wget https://cloud-images.ubuntu.com/focal/current/focal-server-cloudimg-amd64.img -O vm/focal-server-cloudimg-amd64.img

# 2. Edit vm/user-data and replace the SSH authorized key with yours

# 3. Create the VM disk (qcow2 overlay) and seed ISO
cd vm/
qemu-img create -b focal-server-cloudimg-amd64.img -f qcow2 -F qcow2 workspaces-vm.qcow2
genisoimage -output seed.iso -volid cidata -joliet -rock user-data meta-data
cd ..
```

## Quick start

```bash
# Launch (starts VM, waits for cloud-init, opens WorkSpaces client)
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

## Connection details

| Field | Value |
|-------|-------|
| Registration code | `wsdub+LVF37D` |
| Username | `meaningfy2` |

## VM artifacts (generated, not tracked)

- `vm/workspaces-vm.qcow2` — VM disk (overlay on `focal-server-cloudimg-amd64.img`)
- `vm/seed.iso` — cloud-init seed ISO
- `vm/vm.pid` — QEMU PID file
- `vm/focal-server-cloudimg-amd64.img` — base Ubuntu 20.04 cloud image (~618 MB)
