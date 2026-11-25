# Inventário

Endereços das máquinas da rede do cluster (rede 192.168.0.0/24, roteador em 192.168.0.1).
O MAC de cada placa aparece no log do dnsmasq (`journalctl -u dnsmasq -f`) quando ela faz o boot pela rede.

| Máquina | Função | MAC | IP | Hostname | Observações |
|---|---|---|---|---|---|
| Roteador | gateway, DHCP | | 192.168.0.1 | | TP-Link TL-R470T+ v6.0 |
| Switch | switch gerenciável | 78:32:1b:21:66:fd | 192.168.0.2 | | D-Link DGS-1210-28 |
| Servidor | dnsmasq, HTTP | 00:07:32:3f:c7:09 | 192.168.0.160 | starlit-srv | UP Board (IP pelo DHCP do roteador; reservar para o MAC). Instalada pela rede a partir do notebook; recebeu 192.168.0.229 antes da reserva |
| Notebook | servidor temporário | | 192.168.0.216 | | dnsmasq e nginx só enquanto a placa servidor não assume; depois, desligar os dois |
| Placa 01 | | | 192.168.0.101 | up-01 | |
