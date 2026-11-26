# Especificações dos componentes

## Roteador

- **Modelo:** TP-Link TL-R470T+
- **Versão de hardware:** v6.0
- **IP de gerenciamento:** 192.168.0.1 (interface web)
- **Tipo:** roteador com fio, com balanceamento de carga entre múltiplos links de internet (multi-WAN)
- **Portas:** Fast Ethernet (10/100 Mbps), segundo a ficha técnica do fabricante (a confirmar no equipamento)

Modelo e versão obtidos na interface web do roteador (endpoint de idioma da tela de login, sem autenticação).

## Switch

- **Modelo:** D-Link DGS-1210-28
- **IP de gerenciamento:** 192.168.0.2 (interface web em HTTP e telnet; HTTPS desativado)
- **MAC:** 78:32:1b:21:66:fd
- **Tipo:** switch gerenciável (linha *Web Smart* da D-Link), com suporte a VLANs
- **Portas:** 24 portas 10/100/1000 Mbps (gigabit) + 4 portas SFP gigabit (confirmado no equipamento)
- **Revisão de hardware e versão de firmware:** a verificar (ficam atrás do login, ou na etiqueta do equipamento)

Modelo obtido na mensagem de login do telnet (porta 23), sem autenticação. O fabricante foi confirmado pelo MAC (prefixo 78:32:1B, D-Link International). SNMP com a comunidade `public` não respondeu.

## UpBoards

- **Modelo:** UP Board CHT01
- **RAM:** 4 GB (DDR3L)
- Memory Speed: 1600 MHz
- Quantidade e demais especificações a verificar.
- Intel(R) Atom(TM) x5-Z8350 CPU @ 1.44 GHz 
- eMMC: Unknown m52532 378E2827 (29.1 GB)
