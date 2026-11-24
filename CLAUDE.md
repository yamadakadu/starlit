# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repository is

The plan and the scripts for provisioning a bare-metal Kubernetes cluster of about 20 UP Board CHT01 boards (4 GB RAM, eMMC) over the network. Everything is written in **Portuguese**: docs, comments, script messages.

- `README.md`: the procedure, in two parts.
  - Parte 1 (steps 1 to 5 + validation): one server board plus one test board.
  - Parte 2 (step 6 + validation + step 7): three boards. Step 7 (cluster) is still empty.
- `especificacoes.md`: hardware specs.
- `inventario.md`: MAC / IP / hostname table of every machine.
- `config.env`: the only place for values (server IP, interface, user, SSH key, versions).
- `lib.sh`: shared helpers. `renderizar` fills `*.tpl` with envsubst, replacing **only the listed variables**, so `${base}` (iPXE), `$uri` (nginx) and shell variables in templates survive.
- One folder per step, each with one script: `imagem/` (2), `servidor/` (3), `ipxe/` (4), `alpine/` (5).

The scripts run **on the server board**, as root via `sudo`. They can't run on this laptop. Check them locally with:

```sh
for f in lib.sh */*.sh; do bash -n "$f"; done
```

To check `alpine/starlit.start.tpl` (busybox ash on the boards): render it with `renderizar` (`RAIZ=$PWD; source lib.sh`), then run `busybox ash -n` on the result.

Nothing has been tested on the boards yet, except removing the old Ubuntu through GRUB `init=/bin/bash` (step 1).

## Provisioning architecture

```
BIOS PXE (IPv4 only) --TFTP--> ipxe.efi --HTTP--> boot.ipxe --HTTP--> Alpine (in RAM)
  -> starlit.apkovl.tar.gz (alpine/starlit.start): write noble.raw.gz to the eMMC, put eMMC first in the UEFI boot order, reboot
  -> Ubuntu 24.04 cloud image boots from the eMMC; cloud-init (NoCloud, seedfrom http://<server>/cloud-init/) configures it and calls phone_home
```

The server is an UP Board with Ubuntu Server 24.04, installed manually from USB, at `192.168.0.160`, which it gets from the router's DHCP. This IP is baked into the iPXE binary and the image, so it must not change: reserve it on the router, or else use a static IP outside the DHCP pool. The user may later move the server to another machine and will say so.

Decisions already made with the user, and why. Don't revisit them without a reason:

- **Ubuntu cloud image written to the eMMC, not the ISO installer:** netbooting the ISO loads ~3 GB into 4 GB of RAM. `imagem/preparar-imagem.sh`:
  - checks that partition 15 is the ESP and contains `EFI/ubuntu/shimx64.efi` (`starlit.start` depends on it);
  - adds a NoCloud config and the marker file `/etc/starlit-release`;
  - gzips the image.
- **Router keeps DHCP; dnsmasq runs in proxy-DHCP mode** and also serves TFTP. nginx serves `/srv/http`, and its `/phone-home/` location returns 200.
- **iPXE `snponly.efi` built with an embedded script**, so iPXE doesn't receive itself again over DHCP and loop. Secure Boot must be off. The Alpine version is resolved from `latest-stable` and pinned in `boot.ipxe`.
- **Reinstall protection:**
  - `starlit.start` never writes if the marker file exists;
  - `starlit.start` puts the eMMC first in the boot order.
  - **Reinstalling is always manual** (`wipefs -a -f /dev/mmcblk0`). No script may wipe an installed board.
- **UEFI fallback:** the board's UEFI still boots any `\EFI\BOOT\BOOTX64.EFI` on the eMMC even with that entry disabled, so a leftover OS must be wiped, not just disabled. An empty board whose PXE fails stops at the BIOS screen.
- **cloud-init only does the first boot:**
  - user `ubuntu`, key `~/.ssh/cluster-key.pub`, passwordless sudo;
  - `preserve_hostname: true`, `phone_home`.

  Hostnames are set manually in step 6. Ansible was suggested for step 7 but not decided.
- **No diskless/NFS root:** the server would be a single point of failure, containerd's overlayfs doesn't work on NFS, and etcd suffers on network storage.
- **IPs by MAC reservation on the router** (whether the router supports this is still unconfirmed). Convention: server `.160` / `starlit-srv`, board NN `192.168.0.1NN` / `up-NN`.

## Network

- Network `192.168.0.0/24`.
- Router TP-Link TL-R470T+ v6.0 at `.1`. Its ports are 100 Mbps, so it only carries internet traffic.
- Switch D-Link DGS-1210-28 at `.2`: managed, gigabit. The server and the boards connect to the switch.
- When inspecting devices on the LAN: read only. Don't log in, try passwords or change network configuration without the user's approval.

## Working with the user

- Keep to the requested scope. The user decides step by step, and reviews the scripts after they are written.
- Part of step 1 and the components/Proposta sections are the user's own prose: ask before rewriting them.
- Mark unverified facts as "a confirmar" or "a verificar".
- A personal hook blocks `rm -rf` in commands run here: delete specific files, or use `mktemp -d` for scratch directories.
