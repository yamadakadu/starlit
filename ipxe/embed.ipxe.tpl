#!ipxe
# Embutido no ipxe.efi: pede um IP e carrega o boot.ipxe do servidor.
# Sem ele, o iPXE receberia de novo o próprio iPXE pelo DHCP e entraria em loop.
dhcp
chain http://${SERVIDOR_IP}/boot.ipxe || shell
