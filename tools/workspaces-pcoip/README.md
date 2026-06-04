# WorkSpaces PCoIP Client (QEMU/KVM VM)

Runs the Amazon WorkSpaces PCoIP client via a headless Ubuntu 20.04 KVM VM
with X11 forwarding. The native Ubuntu 22/24 client only supports DCV, so
PCoIP WorkSpaces (e.g. Amazon Linux 2) need the Ubuntu 20.04 client — but
glib 2.64 + .NET CoreCLR crashes on kernel 6.17+. A lightweight KVM VM with
an older kernel is the workaround.

## Prerequisites

Install these before you start:

- **QEMU/KVM** — `sudo apt install qemu-system-x86 qemu-utils` (Ubuntu/Debian)
- **`genisoimage`** — `sudo apt install genisoimage` (Ubuntu/Debian)
- **A running X server** — the WorkSpaces client window appears on your desktop. On Linux this is already running if you have a graphical desktop (Xorg or Wayland+XWayland). On macOS install [XQuartz](https://www.xquartz.org/). On WSL install [VcXsrv](https://sourceforge.net/projects/vcxsrv/)

## Setup (first time only)

Follow these steps **in order**. Each step is done once. After that you only
need `./run.sh` and `./run.sh stop` for daily use.

### Step 1: Create an SSH key pair (if you don't have one)

The VM is accessed over SSH. You need a key pair — a **private key** (stays
on your machine) and a **public key** (goes into the VM).

Check if you already have one:

```bash
ls ~/.ssh/id_ed25519.pub ~/.ssh/id_rsa.pub 2>/dev/null
```

If you see a filename printed, skip to Step 2. If nothing prints, generate one:

```bash
ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519_workspaces -N ""
```

This creates two files:
- `~/.ssh/id_ed25519_workspaces` — your private key (keep this secret, never share it)
- `~/.ssh/id_ed25519_workspaces.pub` — your public key (this goes into the VM)

### Step 2: Download the Ubuntu 20.04 cloud image

```bash
cd tools/workspaces-pcoip
wget -O vm/focal-server-cloudimg-amd64.img \
  https://cloud-images.ubuntu.com/focal/current/focal-server-cloudimg-amd64.img
```

This downloads the base operating system image (~618 MB). You only do this
once — the VM runs as a lightweight overlay on top of it.

### Step 3: Add your public key to the VM config

The file `vm/user-data` is a cloud‑init configuration that tells the VM what
to install and which SSH keys to accept. Open it in a text editor:

```bash
nano vm/user-data  # or: gedit vm/user-data
```

Find these lines inside the file:

```yaml
    ssh_authorized_keys:
      - ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHVS6eyfRkyLyNa8v68t3nE8jJkU46vuWPTl7KYhvoAE
```

Print your public key so you can copy it:

```bash
cat ~/.ssh/id_ed25519_workspaces.pub
```

Replace the entire `ssh-ed25519 AAAAC3…` line with the output from `cat`.
The final result should look like this (but with **your** key):

```yaml
    ssh_authorized_keys:
      - ssh-ed25519 AAAAC3N…your-key-here… comment
```

> ⚠️ The leading spaces and the `- ` are important. Keep them exactly as they
> were — only replace the key text. Save and close the file.

### Step 4: Make sure your SSH agent has the key

The `run.sh` script connects via SSH using your SSH agent:

```bash
ssh-add ~/.ssh/id_ed25519_workspaces
```

Verify the key is loaded:

```bash
ssh-add -l
```

You should see your key listed. If you get "Could not open a connection to
your authentication agent", start the agent first:

```bash
eval $(ssh-agent) && ssh-add ~/.ssh/id_ed25519_workspaces
```

### Step 5: Create the VM disk and seed ISO

```bash
cd vm/
qemu-img create -b focal-server-cloudimg-amd64.img -f qcow2 -F qcow2 workspaces-vm.qcow2
genisoimage -output seed.iso -volid cidata -joliet -rock user-data meta-data
cd ..
```

What these do:
- `qemu-img create` makes a lightweight copy-on-write disk (~a few MB) that
  references the base image you downloaded. Any changes the VM makes are saved
  into this overlay, leaving the base image untouched.
- `genisoimage` bundles `user-data` and `meta-data` into an ISO that cloud‑init
  reads on first boot. This is how the VM knows to install the WorkSpaces
  client and accept your SSH key.

## Quick start

```bash
# Launch (starts VM, waits for cloud-init, opens WorkSpaces client)
./run.sh

# Stop the VM
./run.sh stop
```

- `./run.sh` boots the VM (first time: cloud‑init installs the WorkSpaces
  client — this takes ~2 minutes). Once the VM is ready, the WorkSpaces
  client window appears on your desktop automatically.
- `./run.sh stop` gracefully shuts down the VM.

### Resource usage — please stop when done

While running, the VM reserves **2 CPU cores and 2 GB of RAM** from your
host machine (these are set in `run.sh`: `-smp 2 -m 2048`). On a laptop this
can cause the fan to spin up, drain the battery faster, and make other apps
sluggish.

The VM does **not** save battery or reduce CPU usage when the WorkSpaces
client is idle — QEMU runs at full allocation regardless of what happens
inside the VM.

**Always run `./run.sh stop` when you're done.** If you close the WorkSpaces
client window but don't stop the VM, the VM keeps running in the background
consuming those resources until you shut down your computer or kill it
manually. There is no automatic shutdown — it's a bare QEMU process with no
idle detection.

To check if the VM is still running:

```bash
pgrep -f workspaces-vm.qcow2
```

If it prints a number, the VM is still running — stop it with `./run.sh stop`.

## How it works

`run.sh` uses QEMU/KVM to boot a headless Ubuntu 20.04 VM with cloud‑init.
cloud‑init provisions the WorkSpaces client on first boot (`vm/user-data`).

| File | Role |
|------|------|
| `run.sh` | Start VM, wait for cloud‑init, launch client via SSH X11 forwarding |
| `vm/user-data` | cloud‑init config: packages, WorkSpaces client install, SSH setup |
| `vm/meta-data` | cloud‑init VM identity |
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
- `vm/seed.iso` — cloud‑init seed ISO
- `vm/vm.pid` — QEMU PID file
- `vm/focal-server-cloudimg-amd64.img` — base Ubuntu 20.04 cloud image (~618 MB)
