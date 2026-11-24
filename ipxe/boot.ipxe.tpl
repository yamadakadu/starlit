#!ipxe
# Gerado por ipxe/preparar-ipxe.sh: inicia o Alpine, que roda o script de gravação (etapa 5).
set base http://${SERVIDOR_IP}/alpine
kernel ${base}/vmlinuz-lts initrd=initramfs-lts ip=dhcp modloop=${base}/modloop-lts alpine_repo=http://dl-cdn.alpinelinux.org/alpine/${ALPINE_BRANCH}/main apkovl=${base}/starlit.apkovl.tar.gz
initrd ${base}/initramfs-lts
boot
