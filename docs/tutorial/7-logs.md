# 7. Logs para depuração

## 7.1 Onde estão os logs

**No servidor:**

| O que | Onde | Mostra |
|---|---|---|
| dnsmasq (proxy DHCP + TFTP) | `sudo journalctl -u dnsmasq -f` | pedidos de PXE (por MAC) e envio do `ipxe.efi` por TFTP (por IP) |
| nginx, acessos | `sudo tail -f /var/log/nginx/access.log` | downloads do `boot.ipxe`, Alpine, `noble.raw.gz` e cloud-init, com IP e código HTTP |
| nginx, erros | `sudo tail -f /var/log/nginx/error.log` | arquivos que não existem, permissões |
| fim da instalação | `cat /var/log/nginx/phone-home.log` | placas que concluíram o primeiro boot (IP, hostname) |
| arquivos publicados | `/srv/tftp/`, `/srv/http/` | o que as placas recebem |
| arquivos intermediários | `/var/tmp/starlit/` | imagem e compilação do iPXE |
| saída dos scripts | o próprio terminal | cada passo começa com `==>`; erros com `ERRO:` |

Sem `sudo`, o `journalctl` responde `No entries`: o usuário precisa estar no grupo `adm` ([seção 3.4](3-servidor.md), passo 8).

**Na placa:**

| O que | Onde |
|---|---|
| boot pela rede e gravação | o monitor (mensagens do PXE, do iPXE, do Alpine e do script de gravação) |
| cloud-init | `cloud-init status --long`, `/var/log/cloud-init.log`, `/var/log/cloud-init-output.log` |
| boot do Ubuntu | `sudo journalctl -b` |
| rede | `networkctl status`, `ip -br addr`, `ip route`, `resolvectl status` |

## 7.2 Problemas comuns

| Sintoma | Causa provável | O que fazer |
|---|---|---|
| A placa não aparece no log do dnsmasq | não tentou o boot pela rede | conferir a BIOS (2.1), o cabo e o menu de boot (F7 → IPv4); uma placa instalada inicia direto pela eMMC |
| O log mostra `PXE ... proxy`, mas não `sent ... ipxe.efi`, e a placa inicia o sistema da eMMC ou para na BIOS | o dnsmasq escuta num IP antigo (o IP do servidor mudou depois que ele iniciou) | `sudo ss -ulpn \| grep ':69 '`; `sudo systemctl restart dnsmasq` |
| O dnsmasq não sobe: `unknown interface` | a interface não existia ou estava sem cabo quando ele iniciou | conferir o cabo e o `INTERFACE` do `config.env`; `sudo systemctl restart dnsmasq` |
| O iPXE carrega, mas para num prompt (`iPXE>`) | o `boot.ipxe` não foi encontrado no `SERVIDOR_IP` | `curl http://<IP do servidor>/boot.ipxe`; conferir o IP do servidor e o nginx |
| `journalctl` mostra `No entries` | falta permissão | usar `sudo` ou entrar no grupo `adm` |
| `ping 1.1.1.1` funciona, mas `apt`/`curl` dão `Could not resolve host` | DNS bloqueado ou errado | testar os DNS com `nslookup` (3.4, passo 2) e corrigir o netplan |
| DNS com servidores inesperados em `netplan get` | mais de um arquivo no `/etc/netplan/` (as listas são somadas) | deixar só o `99-starlit.yaml` (3.4, passo 4) |
| `configurar-servidor.sh`: `a interface ... não tem o IP ...` | `SERVIDOR_IP` diferente do IP real | conferir `ip -br addr` e o `config.env` |
| Script reclama de `config.env` ausente ou campo vazio | falta criar ou preencher o `config.env` | [seção 4.2](4-repositorio.md) |

## 7.3 Recuperação

**Servidor sem rede depois do netplan** (e sem senha para o console). Iniciar o Alpine pela rede a partir de outro servidor (por exemplo, o computador temporário da 3.A), **sem** o script de gravação:

1. No servidor temporário: `sudo mv /srv/http/alpine/starlit.apkovl.tar.gz /srv/http/alpine/starlit.apkovl.tar.gz.off`.
2. Na placa: menu de boot → IPv4. O Alpine para no login; entrar como `root`, sem senha.
3. Um comando por vez:
   ```sh
   cat /proc/partitions                   # deve listar mmcblk0p1
   mkdir -p /mnt
   mount -t ext4 /dev/mmcblk0p1 /mnt
   ls /mnt/etc/netplan /mnt/root
   ```
   Corrigir ou trocar os arquivos em `/mnt/etc/netplan/` (por exemplo, voltar o backup `/mnt/root/50-cloud-init.yaml.bak`, que usa DHCP), criar uma senha (`chroot /mnt passwd ubuntu`) e desmontar (`umount /mnt`).
4. No servidor temporário, **antes** de reiniciar a placa: `sudo mv /srv/http/alpine/starlit.apkovl.tar.gz.off /srv/http/alpine/starlit.apkovl.tar.gz`.
5. Na placa: `reboot`. O script de gravação encontra a imagem instalada e não grava nada.

O mesmo vale por um pendrive com Linux live, sem precisar de outro servidor.

**Placa instalada que não inicia** (gravação interrompida ou imagem com defeito): seguir *Reinstalação de uma placa que não inicia* na [etapa 5](../etapas/5-instalacao.md).
