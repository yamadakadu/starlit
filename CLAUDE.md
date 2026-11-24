# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repository is

Documentation only: there is no code, build, lint or test. It is the plan, written in **Portuguese**, for provisioning a bare-metal Kubernetes cluster of about 20 UP Board CHT01 boards (4 GB RAM, eMMC) over the network. Write all content in Portuguese.

- `README.md`: the procedure, in 7 steps (`## Proposta` lists them, `## Descrição de cada etapa` details them). Steps 1 to 6 are written, followed by an initial evaluation plan (1 board, then 3); step 7 (cluster) is still empty.
- `especificacoes.md`: hardware specs, linked from the README.
- `inventario.md`: MAC / IP / hostname table of every machine, linked from step 6.

Nothing in the procedure has been tested on the boards yet, except removing the old Ubuntu from the eMMC through GRUB `init=/bin/bash` (step 1).

## Provisioning architecture (spread across steps 1 to 6)

Boot chain of a board:

```
BIOS PXE (IPv4 only) --TFTP--> ipxe.efi --HTTP--> boot.ipxe --HTTP--> Alpine (in RAM)
  -> starlit.apkovl.tar.gz script: write noble.raw.gz to the eMMC, put eMMC first in the UEFI boot order, reboot
  -> Ubuntu 24.04 cloud image boots from the eMMC; cloud-init (NoCloud, seedfrom http://<servidor>/cloud-init/) configures it and calls phone_home
```

Decisions already made with the user, and why. Don't revisit them without a reason:

- **Ubuntu cloud image written to the eMMC, not the ISO installer:** netbooting the ISO loads ~3 GB into the boards' 4 GB of RAM. The image is converted to raw, given a NoCloud datasource config and the marker file `/etc/starlit-release`, then gzipped.
- **Router keeps DHCP; dnsmasq runs in proxy-DHCP mode** and also serves TFTP. nginx serves everything else and has a `/phone-home/` location that returns 200.
- **iPXE built with an embedded script** (`snponly.efi`), so iPXE doesn't receive itself again over DHCP and loop. Secure Boot must be off.
- **Reinstall protection:**
  - the step-5 script never writes if the marker file exists (any version);
  - the script puts the eMMC first in the boot order;
  - to reinstall, wipe the eMMC (`wipefs -a -f /dev/mmcblk0`).
- **UEFI fallback:** the board's UEFI still boots any `\EFI\BOOT\BOOTX64.EFI` on the eMMC even with that entry disabled, so a leftover OS must be wiped, not just disabled. A board with an empty eMMC whose PXE fails stops at the BIOS screen.
- **cloud-init does only the first-boot minimum** (user, SSH key, `preserve_hostname: true`, `phone_home`). Per-host config (hostname) is manual over SSH in step 6. Ansible was suggested for step 7 but not decided.
- **No diskless/NFS root:** the server would become a single point of failure, containerd's overlayfs doesn't work on NFS, and etcd suffers on network storage.
- **IPs by MAC reservation on the router** (whether the router supports this is still unconfirmed). Convention: server `192.168.0.10` / `starlit-srv`, board NN `192.168.0.1NN` / `up-NN`.

## Network

- Network `192.168.0.0/24` (mask assumed). Router TP-Link TL-R470T+ v6.0 at `192.168.0.1`, with 100 Mbps ports, so it only carries internet traffic. Switch D-Link DGS-1210-28 at `192.168.0.2`: managed, 24 gigabit ports + 4 SFP. The server and the boards connect to the switch.
- When inspecting devices on the LAN: read only. Don't log in, try passwords or change network configuration without the user's approval.

## Working with the user

- Keep to the requested scope. The user plans step by step and confirms each decision before it goes into the README.
- Part of step 1 and the components list are the user's own prose: ask before rewriting them.
- In the README, placeholders like `<servidor>` and `<usuário>` are intentional. Mark unverified facts as "a confirmar" or "a verificar".
