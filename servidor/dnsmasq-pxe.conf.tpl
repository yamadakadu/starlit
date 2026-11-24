# Gerado por servidor/configurar-servidor.sh
# Proxy DHCP: os IPs continuam vindo do roteador; o dnsmasq só indica de onde baixar o bootloader.
port=0
interface=${INTERFACE}
bind-interfaces
dhcp-range=${REDE},proxy
enable-tftp
tftp-root=${TFTP_DIR}
pxe-service=x86-64_EFI,"Starlit",ipxe.efi
log-dhcp
