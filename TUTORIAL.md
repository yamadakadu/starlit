# Tutorial: do zero até as placas instaladas pela rede

Este tutorial segue a ordem prática da montagem, do reset dos equipamentos de rede até o acesso por SSH às placas instaladas. Os detalhes de cada script e as decisões do projeto estão no [README.md](README.md); os valores desta instalação (IPs, MACs, hostnames), no [inventario.md](inventario.md).

Itens marcados como *a confirmar* não foram verificados nos equipamentos.

## Sumário

1. [Rede: roteador, switch e internet](#1-rede-roteador-switch-e-internet)
2. [Preparação das UP Boards: BIOS e eMMC](#2-preparação-das-up-boards-bios-e-emmc)
3. [Instalação do Ubuntu no servidor e IP fixo](#3-instalação-do-ubuntu-no-servidor-e-ip-fixo)
4. [Repositório e config.env no servidor](#4-repositório-e-configenv-no-servidor)
5. [Scripts do servidor e teste de boot das placas](#5-scripts-do-servidor-e-teste-de-boot-das-placas)
6. [IP das placas e acesso por SSH](#6-ip-das-placas-e-acesso-por-ssh)
7. [Logs para depuração](#7-logs-para-depuração)

---

## 1. Rede: roteador, switch e internet

### 1.1 Plano de endereços

Antes de configurar qualquer coisa, decidir os endereços da rede privada. Exemplo, com a rede `192.168.0.0/24`:

| Endereço | Uso | Como é atribuído |
|---|---|---|
| `192.168.0.1` | roteador | fixo (padrão do roteador) |
| `192.168.0.2` | switch | fixo, configurado no switch |
| faixa de DHCP do roteador (ex.: `.20` a `.99`) | notebooks, celulares, outros aparelhos | DHCP automático |
| um IP fora da faixa de DHCP (nesta instalação, `.110`) | servidor | IP fixo no próprio servidor (netplan) |
| `.201` a `.2NN` | placa NN | reserva por MAC no roteador |
| um IP livre (ex.: `.250`) | notebook usado como servidor temporário (opcional, seção 3) | IP fixo no notebook |

Regras:

- os IPs fixos e reservados **ficam fora** da faixa de DHCP automático, para o roteador não entregá-los a outro aparelho;
- **o IP do servidor não pode mudar depois** que os scripts rodarem: ele fica gravado no iPXE, no `boot.ipxe`, na imagem e no script de gravação. Trocá-lo exige rodar todos os scripts de novo;
- nenhum IP pode coincidir com outro (ex.: um notebook em `.216` colide com a placa 16).

Anotar o plano no `inventario.md`.

### 1.2 Cabeamento

```
internet (rede da instituição) ──> porta WAN do roteador
roteador (porta LAN) ──> switch
servidor e placas ──> switch (portas gigabit)
```

As portas do roteador são de 100 Mbps: ele só leva o tráfego da internet. Servidor e placas ficam sempre no **switch**, que é gigabit.

O TL-R470T+ tem mais de uma porta WAN (multi-WAN). Ver na interface web qual WAN está com status *Connected*: é por ela que a internet sai.

### 1.3 Reset e configuração do roteador (TP-Link TL-R470T+)

1. Reset: com o roteador ligado, segurar o botão **RESET** até os LEDs piscarem (*tempo a confirmar*, normalmente alguns segundos).
2. Ligar um computador numa porta LAN e acessar `http://192.168.0.1`. *Usuário e senha padrão a confirmar na etiqueta do equipamento* (nos modelos TP-Link dessa linha costuma ser `admin` / `admin`). Trocar a senha no primeiro acesso.
3. **WAN:** tipo de conexão *Dynamic IP* (o IP vem da rede da instituição). A tela de status da WAN mostra o IP, o gateway e os **DNS** recebidos; anotar os DNS, eles serão usados no servidor (seção 3.4).
4. **LAN:** manter `192.168.0.1` / `255.255.255.0`.
5. **Servidor DHCP:** ativado, com a faixa do plano (ex.: `.20` a `.99`).
6. **Reserva de IP por MAC:** é onde entram as placas (seção 6). *Confirmar o nome do menu e se o roteador aceita reserva fora da faixa de DHCP.*

### 1.4 Reset e configuração do switch (D-Link DGS-1210-28)

1. Reset: com o switch ligado, segurar o botão **Reset** por cerca de 10 segundos (*a confirmar*).
2. Depois do reset, o switch volta ao IP padrão da D-Link, `10.90.90.90/8`, usuário `admin` sem senha (*a confirmar na etiqueta*). Para acessá-lo, ligar um computador direto no switch com um IP fixo temporário na mesma rede (ex.: `10.90.90.100/8`) e abrir `http://10.90.90.90`.
3. Mudar o IP de gerenciamento para o do plano: `192.168.0.2`, máscara `255.255.255.0`, gateway `192.168.0.1`. Trocar a senha.
4. Não é preciso configurar VLANs: todas as portas ficam na VLAN padrão.
5. Voltar o computador para DHCP e conferir o acesso em `http://192.168.0.2`.

### 1.5 Teste da rede

De um computador ligado no switch, por cabo:

```sh
ping -c3 192.168.0.1          # roteador
ping -c3 192.168.0.2          # switch
ping -c3 1.1.1.1              # internet por IP
nslookup ubuntu.com           # DNS
```

Se o ping para `1.1.1.1` funciona e o `nslookup` falha, o problema é o DNS: ver a seção 3.4.

Atenção, num notebook com Wi-Fi e cabo ao mesmo tempo: o DNS pode estar indo pelo Wi-Fi, e o teste passa mesmo com o DNS da rede cabeada quebrado. Para testar só a rede do switch, desligar o Wi-Fi durante o teste.

---

## 2. Preparação das UP Boards: BIOS e eMMC

Fazer em **todas** as placas, inclusive a que será o servidor. Cada placa precisa de monitor (HDMI) e teclado USB durante a preparação.

### 2.1 Configuração da BIOS

1. Ligar a placa e apertar **DEL** repetidamente. Se pedir senha, apertar **Enter**.
2. **Rede no boot:** *Advanced → Network Stack Configuration*:
   - *Network Stack*: **Enabled**;
   - *Ipv4 PXE Support*: **Enabled**;
   - *Ipv6 PXE Support*: **Disabled** (o servidor não atende IPv6, e essa opção só atrasa o boot).

   As opções de boot pela rede (IPv4) **só aparecem na ordem de boot depois** de habilitar o *Network Stack* e o *Ipv4 PXE Support*, salvar e reiniciar. Se não aparecerem, conferir essas duas opções.
3. **Secure Boot: Disabled** (*menu a confirmar*, geralmente em *Security* ou *Boot*). O iPXE não é assinado e seria bloqueado.
4. **Ordem de boot** (*Boot*): deixar o **IPv4** em primeiro lugar e as demais opções como *Disabled*. Depois da instalação, o próprio script de gravação coloca a eMMC em primeiro lugar, então esse ajuste é feito uma vez só.
5. Salvar e sair (*Save & Exit*; *tecla a confirmar*, geralmente F4).

Para forçar o boot pela rede numa placa já instalada, usar o **menu de boot** ao ligar (*tecla a confirmar*, nas UP Boards costuma ser **F7**) e escolher IPv4.

### 2.2 Limpar a eMMC

Placas com um sistema antigo na eMMC devem ser limpas. Mesmo com a eMMC desativada na ordem de boot, a BIOS (UEFI) inicia qualquer `\EFI\BOOT\BOOTX64.EFI` que encontrar quando o boot pela rede falha. Uma placa limpa, ao contrário, para na tela da BIOS, o que deixa claro que o boot pela rede não funcionou.

Há três formas de conseguir um terminal de root na placa:

- **Com usuário e senha do sistema antigo:** entrar normalmente e usar `sudo`.
- **Pelo GRUB, sem senha:** ligar a placa e, **quando o logo da BIOS sumir e a tela ficar preta**, apertar **Esc** uma vez (ou segurar **Shift**). Apertar cedo demais faz a BIOS entrar no setup; um Esc a mais leva ao terminal do GRUB (`grub>`; digitar `normal` e Enter para voltar ao menu). No menu, apertar `e`, ir ao fim da linha que começa com `linux`, acrescentar ` init=/bin/bash` e apertar **Ctrl+X**.
- **Por pendrive:** iniciar por um pendrive com qualquer Linux live (ex.: Alpine *standard*, usuário `root` sem senha), escolhido no menu de boot.

No terminal:

```sh
lsblk -d -o NAME,SIZE,TYPE        # a eMMC é a mmcblk0 (~29 GB)
wipefs -a -f /dev/mmcblk0         # apaga as tabelas de partição (com sudo, se não for root)
```

Ignorar `mmcblk0boot0`, `mmcblk0boot1` e `mmcblk0rpmb` (áreas internas da eMMC). Um pendrive aparece como `sda`. O Alpine não traz o `wipefs`: instalar com `apk add wipefs`.

Reiniciar (`reboot`; no terminal aberto pelo GRUB, `reboot -f`).

**Verificação:** sem servidor no ar, a placa limpa vai direto para a tela da BIOS. Se ainda iniciar o sistema antigo, a eMMC não foi apagada.

---

## 3. Instalação do Ubuntu no servidor e IP fixo

O servidor roda o dnsmasq (proxy DHCP + TFTP) e o nginx (HTTP). Pode ser qualquer máquina com Ubuntu 24.04 ligada ao switch; neste projeto, uma das UP Boards. Há dois caminhos para instalar o Ubuntu nela:

- **3.A, pela rede, usando um computador como servidor temporário:** o computador roda os scripts deste repositório e instala a placa servidor do mesmo jeito que as outras placas. Não precisa de pendrive e testa toda a cadeia de boot antes de a placa assumir.
- **3.B, por pendrive:** instalação manual com a ISO do Ubuntu Server.

Nos dois casos, a seção 3.4 (IP fixo) é obrigatória.

### 3.0 Chave SSH do cluster

No computador de onde as placas serão acessadas, se a chave ainda não existir:

```sh
ssh-keygen -t ed25519 -f ~/.ssh/cluster-key -C cluster
```

A chave pública (`~/.ssh/cluster-key.pub`) vai para o `user-data` das placas: elas são criadas com o usuário `ubuntu` **sem senha**, e o acesso é só por essa chave.

### 3.A Instalação pela rede, com um computador como servidor temporário

Requisitos do computador: Ubuntu 24.04 (testado), ligado ao **switch por cabo** e com acesso à internet.

1. **IP fixo no computador**, na interface do cabo (exemplo com NetworkManager; o nome da conexão aparece em `nmcli con show`):
   ```sh
   nmcli con show
   sudo nmcli con mod "<conexão do cabo>" ipv4.method manual \
     ipv4.addresses 192.168.0.250/24 ipv4.gateway 192.168.0.1 ipv4.dns "<DNS que funciona na rede>"
   sudo nmcli con up "<conexão do cabo>"
   ip -br addr                     # anotar o nome da interface (ex.: enp3s0) e conferir o IP
   ```
2. **Repositório e `config.env`** no computador: na pasta do repositório, seguir a seção 4.2, usando o IP e a interface **do computador** (ex.: `SERVIDOR_IP=192.168.0.250`, `INTERFACE=enp3s0`). Como o IP do servidor fica gravado na imagem, o computador gera uma imagem só para instalar a placa servidor; depois a placa gera a dela.
3. **Scripts:** seguir a seção 5.1 no computador.
4. **Instalar a placa servidor:** ligar a placa (já limpa, seção 2) com monitor. Ela faz o boot pela rede, grava a imagem na eMMC, reinicia e o cloud-init cria o usuário `ubuntu`. Acompanhar pelos logs da seção 7. Ao terminar, a placa aparece em `/var/log/nginx/phone-home.log` do computador, com o IP que recebeu do roteador.
5. **Primeiro acesso:** `ssh -i ~/.ssh/cluster-key ubuntu@<IP da placa>`.
6. **Senha para o console** (recomendado): o usuário não tem senha, então sem ela não é possível entrar pelo monitor e teclado se a rede cair. O SSH continua aceitando só a chave.
   ```sh
   sudo passwd ubuntu
   ```
7. Seguir com o IP fixo (3.4).
8. **Desligar o servidor temporário** depois que a placa servidor rodar os scripts dela (seção 5.1). Dois proxy-DHCP na rede respondem às placas ao mesmo tempo:
   ```sh
   sudo systemctl disable --now dnsmasq nginx     # no computador
   ```

Cuidado com o dnsmasq do computador: ele escuta nos IPs que a interface tinha **quando iniciou**. Se o IP do computador mudar ou o cabo for desconectado, rodar `sudo systemctl restart dnsmasq`; senão, as placas recebem a resposta do proxy DHCP mas não conseguem baixar o iPXE, e iniciam o sistema da eMMC ou param na BIOS.

### 3.B Instalação por pendrive

1. Gravar a ISO do **Ubuntu Server 24.04** num pendrive e iniciar a placa por ele (menu de boot).
2. Instalar na eMMC. Na tela de rede, deixar DHCP (o IP fixo é configurado depois, na 3.4). Criar o usuário `ubuntu` com senha e marcar a instalação do **OpenSSH**.
3. Na BIOS, colocar a eMMC em primeiro lugar na ordem de boot.
4. Do computador, copiar a chave pública para o servidor:
   ```sh
   ssh-copy-id -i ~/.ssh/cluster-key.pub ubuntu@<IP do servidor>
   scp ~/.ssh/cluster-key.pub ubuntu@<IP do servidor>:.ssh/
   ```
   O `ssh-copy-id` libera o acesso com a chave; o `scp` deixa o `.pub` em `~/.ssh/`, de onde os scripts o leem para o `user-data` das placas.

### 3.4 IP fixo no servidor (netplan)

Fazer **pelo console** (monitor e teclado), não por SSH: se o IP mudar, a sessão cai.

1. Descobrir o nome e o MAC da interface:
   ```sh
   ip -br link
   ```
2. **Escolher o DNS.** Em algumas redes (como as de instituições), DNS públicos como `1.1.1.1` são bloqueados e só os DNS internos respondem. Testar a partir do servidor e usar só os que responderem:
   ```sh
   nslookup -timeout=3 ubuntu.com 192.168.0.1         # o próprio roteador
   nslookup -timeout=3 ubuntu.com <DNS da WAN>         # os da tela de status da WAN do roteador (1.3)
   nslookup -timeout=3 ubuntu.com 1.1.1.1
   nslookup -timeout=3 ubuntu.com 8.8.8.8
   ```
3. **Impedir o cloud-init de reescrever a rede** (instalação 3.A; na 3.B não faz mal):
   ```sh
   echo 'network: {config: disabled}' | sudo tee /etc/cloud/cloud.cfg.d/99-disable-network-config.cfg
   ```
4. **Deixar um único arquivo no netplan.** Os arquivos de `/etc/netplan/` são juntados: listas como a de DNS são **somadas**, e duas configurações para a mesma interface podem se misturar. Guardar os antigos fora da pasta:
   ```sh
   ls /etc/netplan/
   sudo mv /etc/netplan/50-cloud-init.yaml /root/50-cloud-init.yaml.bak    # ou o arquivo do instalador (3.B)
   ```
5. Criar `/etc/netplan/99-starlit.yaml`, com o MAC, o IP e os DNS escolhidos:
   ```yaml
   # Rede do servidor do cluster: IP fixo, fora da faixa de DHCP do roteador.
   network:
     version: 2
     renderer: networkd
     ethernets:
       lan:
         match:
           macaddress: "<MAC do servidor>"
         set-name: <nome da interface>       # ex.: enp1s0
         dhcp4: false
         dhcp6: false
         addresses:
           - <IP do servidor>/24             # ex.: 192.168.0.110/24
         routes:
           - to: default
             via: 192.168.0.1
         nameservers:
           addresses: [<DNS que responderam>]
   ```
   Identificar a interface pelo MAC evita depender do nome, que muda de uma máquina para outra.
6. Aplicar:
   ```sh
   sudo chmod 600 /etc/netplan/99-starlit.yaml
   sudo netplan generate                  # aponta erros no YAML antes de mexer na rede
   sudo netplan get                       # configuração final: conferir IP, rota e DNS
   sudo netplan try                       # Enter para confirmar; sem confirmação, volta sozinho em 120 s
   ```
7. Conferir:
   ```sh
   ip -br addr                            # o IP fixo
   ip route                               # default via 192.168.0.1
   ping -c3 1.1.1.1                       # internet
   resolvectl query ubuntu.com            # DNS
   ```
8. Hostname e acesso aos logs sem `sudo`:
   ```sh
   sudo hostnamectl set-hostname starlit-srv
   sudo usermod -aG adm ubuntu            # vale a partir do próximo login
   ```

Se a rede não voltar e não houver senha para o console, ver *Servidor sem rede depois do netplan* na seção 7.

---

## 4. Repositório e config.env no servidor

### 4.1 Copiar o repositório

Se o servidor tem acesso ao repositório no GitHub:

```sh
git clone git@github.com:yamadakadu/starlit.git ~/starlit
```

O repositório é acessado por SSH: o servidor precisa de uma chave cadastrada no GitHub. Sem isso, copiar do computador:

```sh
scp -r starlit ubuntu@<IP do servidor>:
```

### 4.2 Criar e preencher o `config.env`

O `config.env` não vai para o git, porque depende da rede de cada instalação. Ele é criado a partir do modelo:

```sh
cd ~/starlit
cp config.env.example config.env
nano config.env
```

Campos obrigatórios (os scripts param com erro se algum estiver vazio):

| Campo | O que é | Exemplo |
|---|---|---|
| `SERVIDOR_IP` | IP fixo do servidor (seção 3.4) | `192.168.0.110` |
| `INTERFACE` | nome da interface de rede do servidor (`ip -br link`) | `enp1s0` |
| `REDE` | endereço da rede onde o dnsmasq responde | `192.168.0.0` |

Os demais (`USUARIO`, `SSH_PUBKEY_FILE`, versões e pastas) já vêm preenchidos. O `SSH_PUBKEY_FILE` aponta para `~/.ssh/cluster-key.pub` do usuário que roda o `sudo`: conferir que o arquivo existe (`ls ~/.ssh/cluster-key.pub`).

---

## 5. Scripts do servidor e teste de boot das placas

### 5.1 Rodar os scripts

No servidor, nesta ordem, cada um com `sudo`:

```sh
cd ~/starlit
sudo servidor/configurar-servidor.sh     # dnsmasq + nginx; confere que a interface tem o SERVIDOR_IP
sudo imagem/preparar-imagem.sh           # imagem do Ubuntu (demorado; ~1,7 GB comprimida)
sudo imagem/publicar-cloud-init.sh       # user-data e meta-data
sudo ipxe/preparar-ipxe.sh               # compila o iPXE (alguns minutos) e baixa o Alpine
sudo alpine/empacotar-apkovl.sh          # script de gravação que roda no Alpine
```

Todos precisam de internet. Se um script for interrompido (Ctrl+C ou queda de rede), é só rodá-lo de novo. Casos especiais:

- `apt` reclamando do dpkg: `sudo dpkg --configure -a`;
- `git clone` do iPXE interrompido (`destination path ... already exists`): `sudo rm -r /var/tmp/starlit/ipxe` e rodar de novo.

### 5.2 Conferir o servidor

```sh
systemctl is-active dnsmasq nginx                  # active, active
sudo ss -ulpn | grep -E ':67 |:69 |:4011 '         # portas no IP do servidor
curl http://<IP do servidor>/                      # de outra máquina: lista boot.ipxe, noble.raw.gz, alpine/, cloud-init/
```

Se a porta 69 aparecer em outro IP (ou o dnsmasq não estiver ativo), rodar `sudo systemctl restart dnsmasq`.

### 5.3 Testar o boot de uma placa

1. No servidor, deixar os logs abertos (seção 7):
   ```sh
   sudo journalctl -u dnsmasq -f
   ```
2. Ligar **uma** placa limpa (seção 2), com monitor.
3. Sequência esperada:
   1. no monitor, *Start PXE over IPv4*; no log, `PXE(...) <MAC da placa> proxy` e `sent /srv/tftp/ipxe.efi to <IP>`;
   2. o iPXE pede IP e carrega o `boot.ipxe`; o Alpine inicia;
   3. o script mostra `=== Starlit: instalação via rede ===`, encontra a eMMC e grava a imagem (alguns minutos). **Não desligar a placa durante a gravação**;
   4. o script coloca a eMMC em primeiro lugar no boot e reinicia;
   5. o Ubuntu inicia pela eMMC; o cloud-init cria o usuário e avisa o servidor (`phone-home.log`).

Proteções, para testar com a mesma placa:

- **Placa já instalada:** forçar o boot pela rede (menu de boot, IPv4). O script deve mostrar `Imagem ... já instalada, nada será gravado` e reiniciar no Ubuntu.
- **Reinstalação:** sempre manual. Na placa, `sudo wipefs -a -f /dev/mmcblk0` e `sudo reboot`; ela cai no boot pela rede e é instalada de novo. Para uma placa que não inicia, ver *Placa instalada que não inicia* na seção 7.

---

## 6. IP das placas e acesso por SSH

### 6.1 Descobrir o IP

No servidor, qualquer uma destas formas:

```sh
cat /var/log/nginx/phone-home.log                    # placas que terminaram a instalação (IP e hostname)
sudo tail -50 /var/log/nginx/access.log              # quem baixou a imagem e o cloud-init
sudo journalctl -u dnsmasq | grep -E 'PXE|sent'      # MAC no pedido de PXE, IP no envio do iPXE
```

Varrendo a rede (as UP Boards têm MAC começando com `00:07:32`):

```sh
sudo apt install arp-scan
sudo arp-scan -I <interface> --localnet | grep -i 00:07:32
ip neigh | grep -i 00:07:32                          # só as que já falaram com o servidor
```

Também pela lista de clientes DHCP do roteador (`http://192.168.0.1`).

Para saber qual porta do switch tem qual placa: a tabela de MACs do switch (*MAC Address Table*, na interface web em `http://192.168.0.2`; *menu a confirmar*) mostra o MAC de cada porta, que se cruza com a saída do `arp-scan`.

### 6.2 Testar a conexão

```sh
ping -c3 <IP da placa>
ssh -i ~/.ssh/cluster-key ubuntu@<IP da placa>
```

Na placa:

```sh
cloud-init status --long      # deve terminar em "status: done"
cat /etc/starlit-release      # versão da imagem gravada
```

### 6.3 Fixar o IP e o hostname

Seguir a etapa 6 do [README.md](README.md#6-registro-dos-endereços-mac-e-ip): etiqueta na placa, MAC no inventário, reserva no roteador (placa NN → `192.168.0.2NN`), reinício da placa e hostname `up-NN`.

---

## 7. Logs para depuração

### 7.1 Onde estão os logs

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

Sem `sudo`, o `journalctl` responde `No entries`: o usuário precisa estar no grupo `adm` (seção 3.4, passo 8).

**Na placa:**

| O que | Onde |
|---|---|
| boot pela rede e gravação | o monitor (mensagens do PXE, do iPXE, do Alpine e do script de gravação) |
| cloud-init | `cloud-init status --long`, `/var/log/cloud-init.log`, `/var/log/cloud-init-output.log` |
| boot do Ubuntu | `sudo journalctl -b` |
| rede | `networkctl status`, `ip -br addr`, `ip route`, `resolvectl status` |

### 7.2 Problemas comuns

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
| Script reclama de `config.env` ausente ou campo vazio | falta criar ou preencher o `config.env` | seção 4.2 |

### 7.3 Recuperação

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

**Placa instalada que não inicia** (gravação interrompida ou imagem com defeito): seguir *Reinstalação de uma placa que não inicia* na etapa 5 do [README.md](README.md#5-instalação-do-so-via-rede).
