# Startlit project

## Componentes do projeto

- UpBoards CHT01 (especificação e quantidade a serem verificadas)
- Switch D-Link DGS-1210-28
- Roteador TP-Link TL-R470T+ v6.0
- Todo o cabeamento, de energia e rede não precisa ser especificado, 

Especificações detalhadas em [especificacoes.md](especificacoes.md).

## Proposta

A ideia do projeto é de montar uma arquitetura com os componentes mencionados para uma futura implementação de um cluster Kubernetes.
A instalação e implementação do cluster será feita em algumas etapas:

1. Preparação da infraestrutura: roteador, switch, UpBoards

2. Preparação da imagem com cloud-init

3. Preparação da máquina com dnsmasq e servidor http

4. Preparação do bootloader

5. Instalação do SO via rede

6. Registro dos endereços MAC e IP

7. Preparação do cluster

## Descrição de cada etapa

### 1. Preparação da infraestrutura

- Roteador e switch

Para esses dispositivos, basta resetá-los e configurá-los na mesma rede privada. Por enquanto, não foi feita nenhuma segmentação de rede (VLANs).

- UpBoards

**Instalação**

Para as plaquinhas, algumas delas já possuem algum sistema operacional (Ubuntu) instalado na memória eMMC e que não será utilizado.
Como a ideia é que o boot seja feito via rede, uma opção deve ser habilitada nas configurações na BIOS, que pode ser acessada apertando DEL repetidamente quando ligar a energia. Será pedida uma senha, basta apertar ENTER que ele entra na BIOS.
Se a configuração de rede (Advanced -> Network Stack Configuration -> Network Stack, Ipv4 PXE Support -> Enabled) estiver habilitada, será possível escolher o boot por IPv4 na ordem de boot. O Ipv6 PXE Support pode ficar Disabled, pois o servidor não atende IPv6 e essa opção só atrasa o boot.
Na ordem de boot, deixar apenas o IPv4 ativo e as demais opções como Disabled.
Depois da instalação, o próprio script da etapa 5 coloca a eMMC em primeiro lugar na ordem de boot, então esse ajuste manual só é feito uma vez.
O **Secure Boot** também precisa estar **desligado** na BIOS, pois o bootloader usado no boot pela rede (iPXE, etapa 4) não é assinado e seria bloqueado.
Se o servidor com dnsmasq não estiver configurado ou não estiver configurado corretamente, a plaquinha não recebe o SO e tenta a próxima opção de boot. Se não encontrar nada:

- **com o Ubuntu antigo na eMMC**, ela inicia o Ubuntu **mesmo com essa opção desativada na BIOS**. Quando todas as opções falham, a BIOS (UEFI) procura em qualquer disco o arquivo de boot padrão (`\EFI\BOOT\BOOTX64.EFI`), que o Ubuntu instala. Ao iniciar por esse caminho, o Ubuntu também pode recriar a própria opção de boot.
- **sem SO na eMMC**, ela vai direto para a tela da BIOS e não tenta a rede de novo sozinha: é preciso reiniciá-la.

Por isso, é importante que nessas plaquinhas não tenha nenhum SO instalado previamente.

**Remoção do Ubuntu antigo**

Com o servidor funcionando (etapas 3 a 5), não é preciso fazer nada: o script da etapa 5 sobrescreve o Ubuntu antigo. Para removê-lo antes, há três formas de conseguir um terminal na placa (com monitor e teclado):

- **Com usuário e senha do Ubuntu:** entrar normalmente.
- **Sem senha, pelo GRUB:** ao ligar a placa, apertar ESC repetidamente até aparecer o menu do GRUB e parar de apertar assim que ele aparecer (um ESC a mais leva ao terminal do GRUB, `grub>`; para voltar ao menu, digitar `normal` e Enter). Com a primeira opção selecionada, apertar `e`, ir até o fim da linha que começa com `linux`, acrescentar ` init=/bin/bash` e apertar `Ctrl+X`. A placa abre um terminal de root sem pedir senha.
- **Sem senha, por pendrive:** iniciar a placa por um pendrive com qualquer Linux live (ex.: Alpine *standard*, usuário `root` sem senha), escolhendo o pendrive na ordem de boot da BIOS.

No terminal:

1. Identificar a eMMC: `lsblk -d -o NAME,SIZE,TYPE`. A eMMC é a `mmcblk0`. As entradas `mmcblk0boot0`, `mmcblk0boot1` e `mmcblk0rpmb` são áreas internas do eMMC e devem ser ignoradas; se estiver usando um pendrive, ele aparece como `sda`.
2. Apagar a tabela de partições da eMMC (a principal e a cópia de segurança, que fica no fim do disco): `sudo wipefs -a -f /dev/mmcblk0`. No terminal do GRUB e no Alpine, o usuário já é root, então o comando vai sem `sudo`.
3. Reiniciar: `sudo reboot` (no terminal do GRUB: `reboot -f`).

**Verificação:** sem o servidor no ar, a placa deve ir direto para a tela da BIOS. Se ainda iniciar o Ubuntu, a eMMC não foi apagada.

O servidor (etapa 3) deve ser ligado **antes** das placas.

**Conexão dos cabos**

A plaquinha precisa de uma fonte de ()W e tem suporte para até 4 entradas USB-A. Além disso, possui uma interface com entrada para cabo de rede e uma entrada para HDMI.

### 2. Preparação da imagem com cloud-init

**Abordagem:** usar a *cloud image* oficial do **Ubuntu Server 24.04 LTS** (`noble-server-cloudimg-amd64.img`, ~600 MB), que já vem com o sistema instalado e com o cloud-init. Em vez de rodar um instalador, a imagem é gravada direto na eMMC (etapa 5) e o cloud-init faz a configuração no primeiro boot. Isso evita carregar a ISO de instalação (~3 GB) na RAM das placas (4 GB).

**Preparação da imagem** (feita uma vez, no servidor):

1. Baixar `noble-server-cloudimg-amd64.img` e conferir o SHA256 com o arquivo `SHA256SUMS` publicado junto com ela.
2. Converter de qcow2 para raw, o formato que pode ser gravado direto no disco: `qemu-img convert -O raw noble-server-cloudimg-amd64.img noble.raw`.
3. Apontar o cloud-init para o servidor HTTP: montar a partição raiz da imagem (`losetup -Pf --show noble.raw` e montar a partição 1) e criar o arquivo `/etc/cloud/cloud.cfg.d/99-nocloud.cfg`:
   ```yaml
   datasource_list: [ NoCloud, None ]
   datasource:
     NoCloud:
       seedfrom: http://<servidor>/cloud-init/
   ```
4. Na mesma partição, criar o arquivo de marca `/etc/starlit-release` com a versão da imagem (ex.: `noble-1`). A etapa 5 usa esse arquivo para saber se a imagem já está instalada.
5. Desmontar (`umount` e `losetup -d`), comprimir com `gzip -k noble.raw` e publicar o `noble.raw.gz` no servidor HTTP (etapa 3). A maior parte dos ~3,5 GB da imagem é espaço vazio, então o arquivo comprimido fica bem menor, o que reduz o tempo de transferência quando várias placas são instaladas ao mesmo tempo. A descompressão é feita na própria placa, durante a gravação (etapa 5).

**Arquivos do cloud-init** (servidos em `http://<servidor>/cloud-init/`, editáveis sem regerar a imagem):

- `meta-data`: vazio por enquanto (o hostname é definido na etapa 6).
- `user-data`: começa com `#cloud-config` e contém:
  - `users`: usuário com `sudo` e a chave SSH pública;
  - `ssh_pwauth: false`: login só por chave;
  - `packages`: só o básico (ex.: `curl`); o que o Kubernetes precisa fica para a etapa 7;
  - `preserve_hostname: true`: impede o cloud-init de desfazer, a cada boot, o hostname definido na etapa 6;
  - `phone_home`: no fim do primeiro boot, a placa avisa o servidor que a instalação terminou. O aviso fica registrado no log do nginx com o IP da placa (usado na verificação da etapa 6):
    ```yaml
    phone_home:
      url: http://<servidor>/phone-home/
      post: [hostname, instance_id]
      tries: 10
    ```

A cloud image não tem swap (exigência do Kubernetes) e a partição raiz cresce sozinha até ocupar a eMMC inteira no primeiro boot.

**Teste:** validar o `user-data` com `cloud-init schema -c user-data` e iniciar `noble.raw` numa VM (QEMU/KVM, com UEFI) antes de usar nas placas.

### 3. Preparação da máquina com dnsmasq e servidor http

**Abordagem:** uma máquina separada (de início um notebook ligado ao switch), com Ubuntu ou Debian, roda três serviços:

| Serviço | Função | Porta |
|---|---|---|
| dnsmasq (proxy DHCP) | informa às placas de onde baixar o bootloader; os IPs continuam sendo distribuídos pelo roteador | UDP 67 e 4011 |
| dnsmasq (TFTP) | entrega o bootloader (arquivo pequeno, primeiro passo do boot) | UDP 69 |
| nginx (HTTP) | entrega todo o resto: kernel, initrd, `noble.raw.gz`, arquivos do cloud-init | TCP 80 |

**Procedimento:**

1. Dar ao servidor um IP fixo: reservá-lo no roteador ou escolher um IP fora da faixa de DHCP do roteador.
2. Instalar os pacotes: `sudo apt install dnsmasq nginx`.
3. Criar as pastas:
   - `/srv/tftp/`: bootloader (etapa 4);
   - `/srv/http/`: `noble.raw.gz`, `cloud-init/user-data`, `cloud-init/meta-data` e os arquivos do boot (etapas 4 e 5).
4. Configurar o dnsmasq em `/etc/dnsmasq.d/pxe.conf`:
   ```
   port=0                                   # desliga o DNS do dnsmasq (evita conflito com o systemd-resolved)
   interface=<interface de rede>
   dhcp-range=<endereço da rede>,proxy      # ex.: 192.168.0.0,proxy
   enable-tftp
   tftp-root=/srv/tftp
   pxe-service=x86-64_EFI,"Starlit",ipxe.efi
   log-dhcp
   ```
5. Configurar o nginx para servir `/srv/http/` (apontar `root` do site padrão para essa pasta) e para receber os avisos do `phone_home` (etapa 2), acrescentando ao mesmo site:
   ```nginx
   location /phone-home/ {
       access_log /var/log/nginx/phone-home.log;
       return 200;
   }
   ```
   Sem isso, o nginx recusaria o aviso (ele não aceita POST em arquivos estáticos) e o cloud-init tentaria de novo várias vezes.
6. Liberar as portas no firewall, se houver: `sudo ufw allow 67,69,4011/udp` e `sudo ufw allow 80/tcp`.
7. Reiniciar os serviços: `sudo systemctl restart dnsmasq nginx`.

**Teste:**

- HTTP: `curl http://<servidor>/cloud-init/user-data` a partir de outra máquina.
- Boot: acompanhar `journalctl -u dnsmasq -f` e ligar uma placa. Devem aparecer a requisição PXE (com o MAC da placa) e o envio do bootloader por TFTP.

### 4. Preparação do bootloader

**Abordagem:** usar o **iPXE** como bootloader. A BIOS baixa o iPXE por TFTP, e ele baixa todo o resto por HTTP. O que ele inicia é um **Alpine Linux** carregado na RAM (~100 MB), que na etapa 5 grava a `noble.raw` na eMMC.

Sequência do boot:

```
BIOS (PXE) --TFTP--> ipxe.efi --HTTP--> boot.ipxe --HTTP--> kernel + initramfs do Alpine
```

**Procedimento:**

1. Criar o script embutido no iPXE, `embed.ipxe`. Ele pede um IP e carrega o `boot.ipxe` do servidor (sem ele, o iPXE pediria DHCP, receberia de novo o próprio iPXE e entraria em loop):
   ```
   #!ipxe
   dhcp
   chain http://<servidor>/boot.ipxe || shell
   ```
2. Compilar o iPXE com esse script embutido e copiá-lo para o TFTP:
   ```
   sudo apt install git build-essential liblzma-dev
   git clone https://github.com/ipxe/ipxe.git
   cd ipxe/src
   make bin-x86_64-efi/snponly.efi EMBED=/caminho/para/embed.ipxe
   sudo cp bin-x86_64-efi/snponly.efi /srv/tftp/ipxe.efi
   ```
   O `snponly.efi` usa o driver de rede da própria BIOS, o que evita problemas de compatibilidade com a placa de rede.
3. Baixar os arquivos de netboot do Alpine (versão estável mais recente, pasta `releases/x86_64/netboot/` em `dl-cdn.alpinelinux.org`) para `/srv/http/alpine/`: `vmlinuz-lts`, `initramfs-lts` e `modloop-lts`.
4. Criar `/srv/http/boot.ipxe`:
   ```
   #!ipxe
   set base http://<servidor>/alpine
   kernel ${base}/vmlinuz-lts initrd=initramfs-lts ip=dhcp modloop=${base}/modloop-lts alpine_repo=https://dl-cdn.alpinelinux.org/alpine/<versão>/main apkovl=${base}/starlit.apkovl.tar.gz
   initrd ${base}/initramfs-lts
   boot
   ```
   O `apkovl` é o script que grava a imagem, criado na etapa 5. Como o `boot.ipxe` fica no servidor HTTP, dá para mudar o boot sem recompilar o iPXE.

**Teste:** ligar uma placa com monitor. Deve aparecer o iPXE, depois o boot do Alpine, terminando na tela de login do Alpine (enquanto o `apkovl` da etapa 5 não existir).

### 5. Instalação do SO via rede

**Abordagem:** o Alpine iniciado pela rede (etapa 4) roda um script que:

1. encontra a eMMC;
2. verifica se a imagem já está instalada (arquivo `/etc/starlit-release` na partição raiz). Se estiver, **não grava nada**;
3. se não estiver, baixa a `noble.raw.gz` do servidor e grava direto na eMMC, descomprimindo durante a gravação;
4. coloca a eMMC em primeiro lugar na ordem de boot e reinicia.

A partir daí, a placa sempre inicia pela eMMC e só volta ao boot pela rede se a eMMC falhar. No primeiro boot pela eMMC, o cloud-init busca o `user-data` no servidor e configura a placa.

**Reinstalar uma placa:** apagar a eMMC (`sudo wipefs -a /dev/mmcblk0` na própria placa) e reiniciar. Sem sistema na eMMC, a BIOS cai no boot pela rede, e a verificação não encontra a marca.

**Script** (`starlit.start`):

```sh
#!/bin/sh
SERVIDOR=http://<servidor>

# 1. Encontrar a eMMC (ignora pendrives e partições de boot do eMMC)
for d in /sys/block/mmcblk*; do
  [ "$(cat "$d/device/type" 2>/dev/null)" = "MMC" ] && DISCO=/dev/${d##*/}
done
[ -z "$DISCO" ] && { echo "eMMC não encontrada"; exit 1; }

# 2. Verificar se a imagem já está instalada
mkdir -p /mnt/raiz
if mount -o ro "${DISCO}p1" /mnt/raiz 2>/dev/null; then
  INSTALADA=$(cat /mnt/raiz/etc/starlit-release 2>/dev/null)
  umount /mnt/raiz
fi

# 3. Gravar a imagem, se necessário
if [ -n "$INSTALADA" ]; then
  echo "Imagem $INSTALADA já instalada, nada será gravado"
else
  echo "Gravando a imagem em $DISCO..."
  set -o pipefail   # falha se o download ou a descompressão falharem, não só o dd
  wget -qO- "$SERVIDOR/noble.raw.gz" | gunzip | dd of="$DISCO" bs=4M || exit 1
  sync
  partx -u "$DISCO"
fi

# 4. Colocar a eMMC em primeiro lugar na ordem de boot
mount -t efivarfs efivarfs /sys/firmware/efi/efivars 2>/dev/null
for n in $(efibootmgr | grep Starlit | cut -c5-8); do efibootmgr -q -B -b "$n"; done
efibootmgr -q -c -d "$DISCO" -p 15 -L Starlit -l '\EFI\ubuntu\shimx64.efi'

reboot
```

A partição 15 é a partição EFI da cloud image do Ubuntu. O `efibootmgr -c` cria a entrada já em primeiro lugar na ordem de boot.

**Empacotar o script para o Alpine** (*apkovl*: um `.tar.gz` com arquivos que o Alpine copia para o `/etc` ao iniciar):

```sh
mkdir -p ovl/etc/local.d ovl/etc/runlevels/default ovl/etc/apk
cp starlit.start ovl/etc/local.d/ && chmod +x ovl/etc/local.d/starlit.start
ln -s /etc/init.d/local ovl/etc/runlevels/default/local   # executa os scripts de /etc/local.d
touch ovl/etc/.default_boot_services                      # mantém os serviços padrão do Alpine
printf 'alpine-base\nefibootmgr\nutil-linux\n' > ovl/etc/apk/world   # pacotes extras
tar -czf /srv/http/alpine/starlit.apkovl.tar.gz --owner=0 --group=0 -C ovl etc
```

Os pacotes extras são baixados da internet no boot (pelo `alpine_repo` da etapa 4), então a rede precisa ter acesso à internet.

**Teste:**

1. Ligar uma placa com monitor e acompanhar as mensagens do script. A gravação leva alguns minutos.
2. Depois do reinício, a placa deve iniciar o Ubuntu pela eMMC e aceitar `ssh <usuário>@<ip da placa>` com a chave configurada na etapa 2.
3. Forçar o boot pela rede (menu de boot da BIOS) e confirmar que o script exibe "já instalada" e não grava nada.

### 6. Registro dos endereços MAC e IP

A tabela de MAC, IP e hostname de cada máquina fica em [inventario.md](inventario.md).

**Abordagem:** os IPs continuam vindo do DHCP do roteador, mas cada placa recebe sempre o mesmo IP, por meio de uma **reserva de IP por MAC** no roteador. O hostname é definido manualmente, por SSH, depois da instalação.

**Convenção sugerida:**

| Máquina | IP | Hostname |
|---|---|---|
| Servidor | 192.168.0.10 | `starlit-srv` |
| Placa NN | 192.168.0.1NN (ex.: placa 01 → 192.168.0.101) | `up-NN` (ex.: `up-01`) |

**Procedimento** (uma placa por vez):

1. Colar uma etiqueta com o número na placa (01, 02, ...), para saber qual placa física corresponde a cada linha do inventário.
2. Descobrir o MAC: acompanhar `journalctl -u dnsmasq -f` no servidor e ligar **só essa placa**. O MAC aparece na requisição PXE. Com a placa já instalada, dá para ver também por `ip link` na própria placa ou na lista de clientes DHCP do roteador.
3. Anotar no `inventario.md` o número, o MAC, o IP e o hostname da placa.
4. Criar a reserva no roteador (interface web em 192.168.0.1, menu do servidor DHCP, opção de reserva de endereço): MAC → IP. *Confirmar no roteador o nome exato do menu.*
5. Depois da instalação (etapa 5), reiniciar a placa para que ela pegue o IP reservado.
6. Definir o hostname:
   ```
   ssh <usuário>@192.168.0.1NN
   sudo hostnamectl set-hostname up-NN
   ```

**Acompanhamento da instalação:** comparar dois logs do servidor com o `inventario.md`:

- `journalctl -u dnsmasq | grep PXE`: placas que **pediram boot pela rede** (por MAC). Uma placa que não aparece aqui não iniciou pela rede (conferir BIOS e cabo).
- `cat /var/log/nginx/phone-home.log`: placas que **terminaram a instalação** (por IP). Uma placa que pediu boot mas não aparece aqui travou na gravação ou no primeiro boot (conferir pelo monitor).

Para saber o MAC de um IP do `phone-home.log`: `ip neigh show <IP>` no servidor.

**Verificação:** `ping 192.168.0.1NN` e `ssh <usuário>@192.168.0.1NN hostname` devem responder com o hostname da tabela. Para conferir todas as placas de uma vez:

```sh
for n in 01 02 03; do ssh <usuário>@192.168.0.1$n hostname; done
```

### 7. Preparação do cluster
