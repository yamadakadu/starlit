# Etapa 3. Preparação da máquina com dnsmasq e servidor http

**Abordagem:** uma das UP Boards é o servidor e roda três serviços. O IP e o MAC do servidor não são fixos no projeto: pode ser qualquer máquina com Ubuntu, em qualquer IP da rede privada, desde que esse IP não mude depois (ver abaixo). O IP escolhido vai no `SERVIDOR_IP` do `config.env`.

| Serviço | Função | Porta |
|---|---|---|
| dnsmasq (proxy DHCP) | informa às placas de onde baixar o bootloader; os IPs continuam sendo distribuídos pelo roteador | UDP 67 e 4011 |
| dnsmasq (TFTP) | entrega o bootloader (arquivo pequeno, primeiro passo do boot) | UDP 69 |
| nginx (HTTP) | entrega todo o resto: kernel, initrd, `noble.raw.gz`, arquivos do cloud-init; recebe os avisos do `phone_home` | TCP 80 |

**Instalação do servidor** (à mão, uma vez):

1. Instalar o **Ubuntu Server 24.04** na placa por pendrive (ISO oficial gravada no pendrive). Na tela de rede do instalador, deixar a configuração automática (DHCP). Criar o usuário `ubuntu` e marcar a instalação do OpenSSH.

   **O IP do servidor não pode mudar:** ele fica gravado no iPXE (etapa 4) e na imagem das placas (etapa 2). Se o roteador entregar outro IP ao servidor, as placas deixam de encontrá-lo, e seria preciso ajustar o `config.env` e rodar os scripts de novo. Por isso, escolher um IP para o servidor e garanti-lo de um destes jeitos:
   - reserva no roteador para o MAC do servidor (mesmo procedimento da etapa 6). *Confirmar se o roteador permite a reserva;*
   - IP fixo no próprio servidor (netplan), fora da faixa de DHCP do roteador.
2. Na BIOS dessa placa, deixar a eMMC em primeiro lugar na ordem de boot.
3. Copiar o repositório e a chave pública para o servidor, a partir do computador onde eles estão:
   ```sh
   scp -r starlit ubuntu@<IP do servidor>:
   scp ~/.ssh/cluster-key.pub ubuntu@<IP do servidor>:.ssh/
   ```
4. No servidor, criar o `config.env` a partir do modelo e preencher `SERVIDOR_IP`, `INTERFACE` (nome visto em `ip -br link`) e `REDE` (endereço da rede, ex.: `192.168.0.0`):
   ```sh
   cd ~/starlit
   cp config.env.example config.env
   nano config.env
   ```
   Os scripts param com erro se o `config.env` não existir ou se um desses três campos estiver vazio.

**Script:**

```sh
cd ~/starlit
sudo servidor/configurar-servidor.sh
```

Ele confere que a interface tem o IP do `SERVIDOR_IP`, instala o dnsmasq e o nginx, gera as configurações a partir de [servidor/dnsmasq-pxe.conf.tpl](https://github.com/yamadakadu/starlit/blob/main/servidor/dnsmasq-pxe.conf.tpl) e [servidor/nginx-starlit.conf.tpl](https://github.com/yamadakadu/starlit/blob/main/servidor/nginx-starlit.conf.tpl), cria `/srv/tftp/` e `/srv/http/`, libera as portas no firewall (se o `ufw` estiver ativo) e reinicia os serviços. O DNS do dnsmasq fica desligado (`port=0`), para não conflitar com o `systemd-resolved`.

**Teste:**

- HTTP: `curl http://<IP do servidor>/` a partir de outra máquina deve listar os arquivos publicados.
- Boot: acompanhar `sudo journalctl -u dnsmasq -f` e ligar a placa de teste. Devem aparecer a requisição PXE (com o MAC da placa) e o envio do bootloader por TFTP.
