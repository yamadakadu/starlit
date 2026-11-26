# 6. IP das placas e acesso por SSH

## 6.1 Descobrir o IP

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

## 6.2 Testar a conexão

```sh
ping -c3 <IP da placa>
ssh -i ~/.ssh/cluster-key ubuntu@<IP da placa>
```

Na placa:

```sh
cloud-init status --long      # deve terminar em "status: done"
cat /etc/starlit-release      # versão da imagem gravada
```

## 6.3 Fixar o IP e o hostname

Seguir a [etapa 6](../etapas/6-registro.md): etiqueta na placa, MAC no inventário, reserva no roteador (placa NN → `192.168.0.2NN`), reinício da placa e hostname `up-NN`.
