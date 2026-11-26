# 3. Instalação do Ubuntu no servidor e IP fixo

O servidor roda o dnsmasq (proxy DHCP + TFTP) e o nginx (HTTP). Pode ser qualquer máquina com Ubuntu 24.04 ligada ao switch; neste projeto, uma das UP Boards. Há dois caminhos para instalar o Ubuntu nela:

- **3.A, pela rede, usando um computador como servidor temporário:** o computador roda os scripts deste repositório e instala a placa servidor do mesmo jeito que as outras placas. Não precisa de pendrive e testa toda a cadeia de boot antes de a placa assumir.
- **3.B, por pendrive:** instalação manual com a ISO do Ubuntu Server.

Nos dois casos, a seção 3.4 (IP fixo) é obrigatória.

## 3.0 Chave SSH do cluster

No computador de onde as placas serão acessadas, se a chave ainda não existir:

```sh
ssh-keygen -t ed25519 -f ~/.ssh/cluster-key -C cluster
```

A chave pública (`~/.ssh/cluster-key.pub`) vai para o `user-data` das placas: elas são criadas com o usuário `ubuntu` **sem senha**, e o acesso é só por essa chave.

## 3.A Instalação pela rede, com um computador como servidor temporário

Requisitos do computador: Ubuntu 24.04 (testado), ligado ao **switch por cabo** e com acesso à internet.

1. **IP fixo no computador**, na interface do cabo (exemplo com NetworkManager; o nome da conexão aparece em `nmcli con show`):
   ```sh
   nmcli con show
   sudo nmcli con mod "<conexão do cabo>" ipv4.method manual \
     ipv4.addresses 192.168.0.250/24 ipv4.gateway 192.168.0.1 ipv4.dns "<DNS que funciona na rede>"
   sudo nmcli con up "<conexão do cabo>"
   ip -br addr                     # anotar o nome da interface (ex.: enp3s0) e conferir o IP
   ```
2. **Repositório e `config.env`** no computador: na pasta do repositório, seguir a [seção 4.2](4-repositorio.md), usando o IP e a interface **do computador** (ex.: `SERVIDOR_IP=192.168.0.250`, `INTERFACE=enp3s0`). Como o IP do servidor fica gravado na imagem, o computador gera uma imagem só para instalar a placa servidor; depois a placa gera a dela.
3. **Scripts:** seguir a [seção 5.1](5-scripts.md) no computador.
4. **Instalar a placa servidor:** ligar a placa (já limpa, [seção 2](2-placas.md)) com monitor. Ela faz o boot pela rede, grava a imagem na eMMC, reinicia e o cloud-init cria o usuário `ubuntu`. Acompanhar pelos logs da [seção 7](7-logs.md). Ao terminar, a placa aparece em `/var/log/nginx/phone-home.log` do computador, com o IP que recebeu do roteador.
5. **Primeiro acesso:** `ssh -i ~/.ssh/cluster-key ubuntu@<IP da placa>`.
6. **Senha para o console** (recomendado): o usuário não tem senha, então sem ela não é possível entrar pelo monitor e teclado se a rede cair. O SSH continua aceitando só a chave.
   ```sh
   sudo passwd ubuntu
   ```
7. Seguir com o IP fixo (3.4).
8. **Desligar o servidor temporário** depois que a placa servidor rodar os scripts dela ([seção 5.1](5-scripts.md)). Dois proxy-DHCP na rede respondem às placas ao mesmo tempo:
   ```sh
   sudo systemctl disable --now dnsmasq nginx     # no computador
   ```

Cuidado com o dnsmasq do computador: ele escuta nos IPs que a interface tinha **quando iniciou**. Se o IP do computador mudar ou o cabo for desconectado, rodar `sudo systemctl restart dnsmasq`; senão, as placas recebem a resposta do proxy DHCP mas não conseguem baixar o iPXE, e iniciam o sistema da eMMC ou param na BIOS.

## 3.B Instalação por pendrive

1. Gravar a ISO do **Ubuntu Server 24.04** num pendrive e iniciar a placa por ele (menu de boot).
2. Instalar na eMMC. Na tela de rede, deixar DHCP (o IP fixo é configurado depois, na 3.4). Criar o usuário `ubuntu` com senha e marcar a instalação do **OpenSSH**.
3. Na BIOS, colocar a eMMC em primeiro lugar na ordem de boot.
4. Do computador, copiar a chave pública para o servidor:
   ```sh
   ssh-copy-id -i ~/.ssh/cluster-key.pub ubuntu@<IP do servidor>
   scp ~/.ssh/cluster-key.pub ubuntu@<IP do servidor>:.ssh/
   ```
   O `ssh-copy-id` libera o acesso com a chave; o `scp` deixa o `.pub` em `~/.ssh/`, de onde os scripts o leem para o `user-data` das placas.

## 3.4 IP fixo no servidor (netplan)

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

Se a rede não voltar e não houver senha para o console, ver *Servidor sem rede depois do netplan* na [seção 7](7-logs.md).
