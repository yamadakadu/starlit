# Decisões do projeto

Escolhas já feitas e os motivos de cada uma.

## Cloud image gravada na eMMC, e não o instalador

Fazer o boot pela rede da ISO de instalação carrega ~3 GB nos 4 GB de RAM das placas. Em vez disso, a *cloud image* oficial do Ubuntu 24.04 é ajustada no servidor e gravada direto na eMMC. O `imagem/preparar-imagem.sh`:

- confere que a partição 15 é a partição EFI e contém `EFI/ubuntu/shimx64.efi` (o `starlit.start` depende disso);
- aumenta a partição 1 em 2 GB e instala o `linux-image-generic` num `chroot`. O kernel *virtual* da cloud image não tem os módulos da eMMC (`linux-modules-extra`): a placa carrega o kernel pela UEFI, mas o initramfs nunca encontra a raiz. Foi escolhido o `linux-image-generic`, e não só o `linux-modules-extra-<versão>`, para que as atualizações de kernel mantenham o driver. O custo é o firmware: a `noble.raw.gz` passou de ~0,5 para ~1,7 GB;
- troca o console para `console=ttyS0 console=tty1`, para as mensagens do boot aparecerem no HDMI;
- adiciona a configuração NoCloud e o arquivo de marca `/etc/starlit-release`;
- roda o `fstrim` e comprime a imagem com gzip.

## Roteador mantém o DHCP; dnsmasq em modo proxy DHCP

O dnsmasq não distribui IPs: ele só informa às placas de onde baixar o bootloader, e também serve o TFTP. O nginx serve `/srv/http`, e sua *location* `/phone-home/` responde 200.

## iPXE `snponly.efi` com script embutido

O script embutido faz o iPXE pedir IP e carregar o `boot.ipxe` direto, sem receber de novo o próprio iPXE pelo DHCP e entrar em loop. O **Secure Boot precisa estar desligado**. A versão do Alpine é descoberta a partir de `latest-stable` e fixada no `boot.ipxe`.

## Proteção contra reinstalação

- O `starlit.start` nunca grava se o arquivo de marca já existir.
- O `starlit.start` coloca a eMMC em primeiro lugar na ordem de boot.
- **A reinstalação é sempre manual** (`wipefs -a -f /dev/mmcblk0`). Nenhum script pode apagar uma placa instalada. Uma placa instalada que não inicia é apagada pelo Alpine iniciado sem o apkovl ([etapa 5](etapas/5-instalacao.md)).

## Fallback da UEFI

A UEFI das placas inicia qualquer `\EFI\BOOT\BOOTX64.EFI` que encontrar na eMMC, mesmo com essa opção desativada. Por isso, um sistema antigo precisa ser apagado, e não só desativado. Uma placa vazia cujo boot pela rede falha para na tela da BIOS.

## cloud-init só no primeiro boot

- usuário `ubuntu`, chave `~/.ssh/cluster-key.pub`, `sudo` sem senha;
- `preserve_hostname: true` e `phone_home`.

Os hostnames são definidos à mão na [etapa 6](etapas/6-registro.md). O Ansible foi sugerido para a [etapa 7](etapas/7-cluster.md), mas não foi decidido.

## Sem raiz pela rede (diskless/NFS)

O servidor viraria um ponto único de falha, o overlayfs do containerd não funciona sobre NFS e o etcd sofre com armazenamento pela rede.

## IPs por reserva de MAC no roteador

*A confirmar se o roteador suporta a reserva.* Convenção:

| Máquina | IP | Hostname |
|---|---|---|
| Servidor | o `SERVIDOR_IP` do `config.env` (nesta instalação, `.110`) | `starlit-srv` |
| Placa NN | `192.168.0.2NN` | `up-NN` |

A faixa das placas deve ficar fora da faixa de DHCP do roteador e não pode coincidir com outras máquinas (um notebook em `.216` colide com a placa 16).

O IP do servidor não é fixo no projeto, mas **não pode mudar depois** que os scripts rodarem: ele fica gravado no binário do iPXE e na imagem. Reservá-lo no roteador ou usar um IP fixo fora da faixa de DHCP.

## Rede

- Rede `192.168.0.0/24`.
- Roteador TP-Link TL-R470T+ v6.0 em `.1`. As portas são de 100 Mbps, então ele só leva o tráfego da internet.
- Switch D-Link DGS-1210-28 em `.2`: gerenciável, gigabit. O servidor e as placas ficam ligados ao switch.
