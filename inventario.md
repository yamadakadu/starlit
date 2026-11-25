# Inventário

Endereços das máquinas da rede do cluster (rede 192.168.0.0/24, roteador em 192.168.0.1).
O servidor não tem IP nem MAC fixos no projeto: a linha abaixo traz os valores desta instalação, e o IP usado pelos scripts é o `SERVIDOR_IP` do `config.env`. Se o servidor mudar de máquina ou de IP, atualizar a linha.
O MAC de cada placa aparece no log do dnsmasq (`sudo journalctl -u dnsmasq -f`) quando ela faz o boot pela rede.

| Máquina | Função | MAC | IP | Hostname | Observações |
|---|---|---|---|---|---|
| Roteador | gateway, DHCP | | 192.168.0.1 | | TP-Link TL-R470T+ v6.0 |
| Switch | switch gerenciável | 78:32:1b:21:66:fd | 192.168.0.2 | | D-Link DGS-1210-28 |
| Servidor | dnsmasq, HTTP | 00:07:32:3f:c7:09 | 192.168.0.110 | starlit-srv | UP Board. IP fixo pelo netplan (`/etc/netplan/99-starlit.yaml`). Instalada pela rede a partir do notebook; recebeu 192.168.0.229 antes da reserva |
| Notebook | servidor temporário | | 192.168.0.216 | | dnsmasq e nginx só enquanto a placa servidor não assume; depois, desligar os dois. O IP coincide com o da placa 16 (`.216`): mudar o IP do notebook antes de instalar a placa 16 |
| Placa 01 | | | 192.168.0.201 | up-01 | |
