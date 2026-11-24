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

O trabalho está dividido em duas partes:

- **[Parte 1: implementação inicial com uma placa](#parte-1-implementação-inicial-com-uma-placa)** (etapas 1 a 5): montar o servidor e instalar o SO via rede em **uma** placa, validando cada passo.
- **[Parte 2: três placas](#parte-2-três-placas)** (etapas 6 e 7): instalar três placas ao mesmo tempo, registrar MAC/IP/hostname e preparar o cluster de teste.

## Estrutura do repositório

Os scripts rodam **no servidor** (por enquanto, uma das UP Boards), com `sudo`, e leem as configurações de [config.env](config.env) (IP do servidor, interface de rede, usuário, chave SSH, versões).

| Pasta | Etapa | Script | O que faz |
|---|---|---|---|
| `imagem/` | 2 | `preparar-imagem.sh` | baixa, ajusta, comprime e publica a imagem do Ubuntu |
| `imagem/` | 2 | `publicar-cloud-init.sh` | gera e publica o `user-data` e o `meta-data` |
| `servidor/` | 3 | `configurar-servidor.sh` | instala e configura o dnsmasq e o nginx |
| `ipxe/` | 4 | `preparar-ipxe.sh` | compila o iPXE, baixa o Alpine e gera o `boot.ipxe` |
| `alpine/` | 5 | `empacotar-apkovl.sh` | empacota o script de gravação que roda no Alpine |

Os arquivos `*.tpl` são modelos: os scripts substituem neles as variáveis do `config.env`. Nenhum script apaga uma placa já instalada; a reinstalação é sempre manual (etapa 5).

---

## Parte 1: implementação inicial com uma placa

Nesta parte são usadas duas UP Boards: uma como **servidor** e uma como **placa de teste**, que recebe o SO via rede. A placa de teste deve ter monitor e teclado, para acompanhar cada passo.

### 1. Preparação da infraestrutura

- Roteador e switch

Para esses dispositivos, basta resetá-los e configurá-los na mesma rede privada. Por enquanto, não foi feita nenhuma segmentação de rede (VLANs).
O servidor e as placas devem ser ligados ao **switch** (portas gigabit), e não às portas do roteador (100 Mbps).

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

A placa que será o **servidor** não usa o boot pela rede: ela é instalada à mão (etapa 3) e inicia pela eMMC.

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

**Scripts** (no servidor, depois da etapa 3):

```sh
sudo imagem/preparar-imagem.sh      # imagem: noble.raw.gz
sudo imagem/publicar-cloud-init.sh  # user-data e meta-data
```

O que o `preparar-imagem.sh` faz (arquivos intermediários em `/var/tmp/starlit/`):

1. Baixa `noble-server-cloudimg-amd64.img` e confere o SHA256 com o `SHA256SUMS` publicado junto.
2. Converte de qcow2 para raw, o formato que pode ser gravado direto no disco.
3. Confere que a partição 15 é a partição EFI e tem o `EFI/ubuntu/shimx64.efi` (o script da etapa 5 depende disso).
4. Na partição raiz (1), cria `/etc/cloud/cloud.cfg.d/99-starlit-nocloud.cfg`, que aponta o cloud-init para `http://<servidor>/cloud-init/`, e o arquivo de marca `/etc/starlit-release` com a versão da imagem (`IMAGEM_VERSAO` no `config.env`). A etapa 5 usa a marca para saber se a imagem já está instalada.
5. Comprime com gzip e publica `noble.raw.gz` no servidor HTTP. A maior parte dos ~3,5 GB da imagem é espaço vazio, então o arquivo comprimido fica bem menor; a descompressão é feita na própria placa, durante a gravação.

**Arquivos do cloud-init** (servidos em `http://<servidor>/cloud-init/`). O modelo é [imagem/user-data.tpl](imagem/user-data.tpl); para mudar a configuração, editar o modelo e rodar de novo o `publicar-cloud-init.sh`, sem regerar a imagem.

- `meta-data`: vazio por enquanto (o hostname é definido na etapa 6).
- `user-data`:
  - `users`: usuário `ubuntu` com `sudo` sem senha e a chave SSH `~/.ssh/cluster-key.pub`; o usuário não tem senha, o acesso é só pela chave;
  - `ssh_pwauth: false`: login só por chave;
  - `packages`: só o básico (`curl`); o que o Kubernetes precisa fica para a etapa 7;
  - `preserve_hostname: true`: impede o cloud-init de desfazer, a cada boot, o hostname definido na etapa 6;
  - `phone_home`: no fim do primeiro boot, a placa avisa o servidor que a instalação terminou. O aviso fica registrado em `/var/log/nginx/phone-home.log`, com o IP da placa.

A cloud image não tem swap (exigência do Kubernetes) e a partição raiz cresce sozinha até ocupar a eMMC inteira no primeiro boot.

### 3. Preparação da máquina com dnsmasq e servidor http

**Abordagem:** uma das UP Boards é o servidor, com IP `192.168.0.160` (recebido pelo DHCP do roteador), e roda três serviços:

| Serviço | Função | Porta |
|---|---|---|
| dnsmasq (proxy DHCP) | informa às placas de onde baixar o bootloader; os IPs continuam sendo distribuídos pelo roteador | UDP 67 e 4011 |
| dnsmasq (TFTP) | entrega o bootloader (arquivo pequeno, primeiro passo do boot) | UDP 69 |
| nginx (HTTP) | entrega todo o resto: kernel, initrd, `noble.raw.gz`, arquivos do cloud-init; recebe os avisos do `phone_home` | TCP 80 |

**Instalação do servidor** (à mão, uma vez):

1. Instalar o **Ubuntu Server 24.04** na placa por pendrive (ISO oficial gravada no pendrive). Na tela de rede do instalador, deixar a configuração automática (DHCP): o roteador atribui `192.168.0.160`. Criar o usuário `ubuntu` e marcar a instalação do OpenSSH.

   **O IP do servidor não pode mudar:** ele fica gravado no iPXE (etapa 4) e na imagem das placas (etapa 2). Se o roteador entregar outro IP ao servidor, as placas deixam de encontrá-lo, e seria preciso ajustar o `config.env` e rodar os scripts de novo. Por isso, reservar `192.168.0.160` para o MAC do servidor no roteador (mesmo procedimento da etapa 6). *Confirmar se o roteador permite a reserva; se não permitir, configurar um IP fixo no servidor, fora da faixa de DHCP do roteador.*
2. Na BIOS dessa placa, deixar a eMMC em primeiro lugar na ordem de boot.
3. Copiar o repositório e a chave pública para o servidor, a partir do computador onde eles estão:
   ```sh
   scp -r starlit ubuntu@192.168.0.160:
   scp ~/.ssh/cluster-key.pub ubuntu@192.168.0.160:.ssh/
   ```
4. No servidor, conferir o nome da interface de rede (`ip -br link`) e ajustar `INTERFACE` no `config.env`.

**Script:**

```sh
cd ~/starlit
sudo servidor/configurar-servidor.sh
```

Ele confere que a interface tem o IP `192.168.0.160`, instala o dnsmasq e o nginx, gera as configurações a partir de [servidor/dnsmasq-pxe.conf.tpl](servidor/dnsmasq-pxe.conf.tpl) e [servidor/nginx-starlit.conf.tpl](servidor/nginx-starlit.conf.tpl), cria `/srv/tftp/` e `/srv/http/`, libera as portas no firewall (se o `ufw` estiver ativo) e reinicia os serviços. O DNS do dnsmasq fica desligado (`port=0`), para não conflitar com o `systemd-resolved`.

**Teste:**

- HTTP: `curl http://192.168.0.160/` a partir de outra máquina deve listar os arquivos publicados.
- Boot: acompanhar `journalctl -u dnsmasq -f` e ligar a placa de teste. Devem aparecer a requisição PXE (com o MAC da placa) e o envio do bootloader por TFTP.

### 4. Preparação do bootloader

**Abordagem:** usar o **iPXE** como bootloader. A BIOS baixa o iPXE por TFTP, e ele baixa todo o resto por HTTP. O que ele inicia é um **Alpine Linux** carregado na RAM (~100 MB), que na etapa 5 grava a `noble.raw.gz` na eMMC.

Sequência do boot:

```
BIOS (PXE) --TFTP--> ipxe.efi --HTTP--> boot.ipxe --HTTP--> kernel + initramfs do Alpine
```

**Script:**

```sh
sudo ipxe/preparar-ipxe.sh
```

1. Compila o iPXE (`snponly.efi`, que usa o driver de rede da própria BIOS) com o script embutido [ipxe/embed.ipxe.tpl](ipxe/embed.ipxe.tpl) e o publica como `/srv/tftp/ipxe.efi`. O script embutido pede um IP e carrega o `boot.ipxe` do servidor; sem ele, o iPXE receberia de novo o próprio iPXE pelo DHCP e entraria em loop. A compilação na UP Board pode levar vários minutos.
2. Descobre a versão estável do Alpine (`ALPINE_VERSAO=latest-stable` no `config.env`; ou uma versão fixa) e baixa os arquivos de netboot (`vmlinuz-lts`, `initramfs-lts`, `modloop-lts`) para `/srv/http/alpine/`.
3. Gera `/srv/http/boot.ipxe` a partir de [ipxe/boot.ipxe.tpl](ipxe/boot.ipxe.tpl). Ele inicia o Alpine com o `apkovl` da etapa 5 (o script de gravação). Como o `boot.ipxe` fica no servidor HTTP, dá para mudar o boot sem recompilar o iPXE.

**Teste:** ligar a placa de teste com monitor. Deve aparecer o iPXE, depois o boot do Alpine, terminando na tela de login do Alpine (enquanto o `apkovl` da etapa 5 não existir).

### 5. Instalação do SO via rede

**Abordagem:** o Alpine iniciado pela rede (etapa 4) roda o script [alpine/starlit.start.tpl](alpine/starlit.start.tpl), que:

1. garante que a rede está ativa e o servidor responde;
2. encontra a eMMC (ignorando pendrives e as áreas internas `mmcblk0boot0`/`boot1`);
3. verifica se a imagem já está instalada (arquivo `/etc/starlit-release` na partição raiz). Se estiver, **não grava nada**;
4. se não estiver, baixa a `noble.raw.gz` do servidor e grava direto na eMMC, descomprimindo durante a gravação (com `pipefail`: uma falha no download ou na descompressão interrompe o script, em vez de deixar uma imagem incompleta);
5. coloca a eMMC em primeiro lugar na ordem de boot (opção "Starlit", partição EFI 15, `\EFI\ubuntu\shimx64.efi`) e reinicia.

As mensagens do script aparecem no monitor. A partir daí, a placa sempre inicia pela eMMC e só volta ao boot pela rede se a eMMC falhar. No primeiro boot pela eMMC, o cloud-init busca o `user-data` no servidor e configura a placa.

**Script** (empacota o `starlit.start` como *apkovl*: um `.tar.gz` com arquivos que o Alpine copia para o `/etc` ao iniciar):

```sh
sudo alpine/empacotar-apkovl.sh
```

O pacote inclui o script, o ativa no boot e pede ao Alpine os pacotes `efibootmgr` e `util-linux`, que são baixados da internet no boot. Por isso, a rede precisa ter acesso à internet.

**Reinstalação: sempre manual.** Nenhum script apaga a eMMC de uma placa já instalada; isso é proposital, para que um nó do cluster nunca seja apagado por engano (por exemplo, se a ordem de boot voltar ao padrão). Para reinstalar uma placa, à mão, na própria placa:

1. `sudo wipefs -a -f /dev/mmcblk0` (conferir antes com `lsblk` que a eMMC é a `mmcblk0`);
2. `sudo reboot`.

Sem sistema na eMMC, a BIOS cai no boot pela rede, a verificação não encontra a marca e a imagem é gravada de novo.

### Validação da Parte 1

Com uma placa só, cada linha dos logs do servidor é dela, o que facilita achar onde algo falhou. Pontos de checagem, na ordem:

1. A placa aparece no log do dnsmasq e baixa o iPXE (etapas 3 e 4).
2. O Alpine inicia (etapa 4).
3. O script grava a imagem e reinicia (etapa 5).
4. A placa inicia pela eMMC, o cloud-init cria o usuário e o acesso funciona: `ssh -i ~/.ssh/cluster-key ubuntu@<ip da placa>` (etapa 2). O IP aparece no `phone-home.log` ou na lista de clientes DHCP do roteador.
5. O aviso da placa aparece em `/var/log/nginx/phone-home.log` no servidor.

Ainda com essa placa, testar as proteções:

- **Placa já instalada:** forçar o boot pela rede pelo menu de boot da BIOS. O script deve exibir "já instalada" e não gravar nada.
- **Reinstalação manual:** seguir o procedimento manual da etapa 5 (`wipefs` + `reboot`). A placa deve ser instalada de novo.

---

## Parte 2: três placas

Com a Parte 1 validada, três placas são instaladas ao mesmo tempo, usando o mesmo servidor e os mesmos scripts. Nenhum script novo é necessário: o que muda é o registro das placas (etapa 6) e a validação com várias placas.

### 6. Registro dos endereços MAC e IP

A tabela de MAC, IP e hostname de cada máquina fica em [inventario.md](inventario.md).

**Abordagem:** os IPs continuam vindo do DHCP do roteador, mas cada placa recebe sempre o mesmo IP, por meio de uma **reserva de IP por MAC** no roteador. O hostname é definido manualmente, por SSH, depois da instalação.

**Convenção sugerida:**

| Máquina | IP | Hostname |
|---|---|---|
| Servidor | 192.168.0.160 | `starlit-srv` |
| Placa NN | 192.168.0.1NN (ex.: placa 01 → 192.168.0.101) | `up-NN` (ex.: `up-01`) |

**Procedimento** (uma placa por vez):

1. Colar uma etiqueta com o número na placa (01, 02, ...), para saber qual placa física corresponde a cada linha do inventário.
2. Descobrir o MAC: acompanhar `journalctl -u dnsmasq -f` no servidor e ligar **só essa placa**. O MAC aparece na requisição PXE. Com a placa já instalada, dá para ver também por `ip link` na própria placa ou na lista de clientes DHCP do roteador.
3. Anotar no `inventario.md` o número, o MAC, o IP e o hostname da placa.
4. Criar a reserva no roteador (interface web em 192.168.0.1, menu do servidor DHCP, opção de reserva de endereço): MAC → IP. *Confirmar no roteador o nome exato do menu.*
5. Depois da instalação (etapa 5), reiniciar a placa para que ela pegue o IP reservado.
6. Definir o hostname:
   ```
   ssh -i ~/.ssh/cluster-key ubuntu@192.168.0.1NN
   sudo hostnamectl set-hostname up-NN
   ```

**Acompanhamento da instalação:** comparar dois logs do servidor com o `inventario.md`:

- `journalctl -u dnsmasq | grep PXE`: placas que **pediram boot pela rede** (por MAC). Uma placa que não aparece aqui não iniciou pela rede (conferir BIOS e cabo).
- `cat /var/log/nginx/phone-home.log`: placas que **terminaram a instalação** (por IP). Uma placa que pediu boot mas não aparece aqui travou na gravação ou no primeiro boot (conferir pelo monitor).

Para saber o MAC de um IP do `phone-home.log`: `ip neigh show <IP>` no servidor.

**Verificação:** `ping 192.168.0.1NN` e `ssh -i ~/.ssh/cluster-key ubuntu@192.168.0.1NN hostname` devem responder com o hostname da tabela. Para conferir todas as placas de uma vez:

```sh
for n in 01 02 03; do ssh -i ~/.ssh/cluster-key ubuntu@192.168.0.1$n hostname; done
```

### Validação da Parte 2

Serve para avaliar o que só aparece com mais de uma placa:

- **Instalação simultânea:** ligar as três placas ao mesmo tempo, medir o tempo de instalação com elas dividindo a banda do servidor e estimar o tempo para as 20.
- **Inventário:** seguir o procedimento da etapa 6 (etiqueta, MAC no log, reserva no roteador, hostname) e comparar os logs do dnsmasq e do `phone_home` com o `inventario.md`.
- **Situações diferentes:** usar ao menos uma placa ainda com o Ubuntu antigo (o script deve sobrescrevê-lo) e uma com a eMMC já apagada.

As três placas podem seguir para a etapa 7 como cluster de teste (um nó de controle e dois de trabalho) antes da instalação das demais.

### 7. Preparação do cluster
