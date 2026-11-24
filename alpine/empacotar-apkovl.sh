#!/usr/bin/env bash
# Etapa 5: empacota o script de gravação para o Alpine (apkovl: um .tar.gz com
# arquivos que o Alpine copia para o /etc ao iniciar).
# Uso: sudo alpine/empacotar-apkovl.sh
RAIZ=$(cd "$(dirname "$0")/.." && pwd)
source "$RAIZ/lib.sh"
exigir_root

OVL=$(mktemp -d)
trap 'rm -rf "$OVL"' EXIT
mkdir -p "$OVL/etc/local.d" "$OVL/etc/runlevels/default" "$OVL/etc/apk" "$HTTP_DIR/alpine"

renderizar "$RAIZ/alpine/starlit.start.tpl" "$OVL/etc/local.d/starlit.start" 'SERVIDOR_IP'
chmod 755 "$OVL/etc/local.d/starlit.start"
ln -s /etc/init.d/local "$OVL/etc/runlevels/default/local"    # executa os scripts de /etc/local.d
touch "$OVL/etc/.default_boot_services"                      # mantém os serviços padrão do Alpine
printf 'alpine-base\nefibootmgr\nutil-linux\n' > "$OVL/etc/apk/world"   # pacotes extras

tar -czf "$HTTP_DIR/alpine/starlit.apkovl.tar.gz" --owner=0 --group=0 -C "$OVL" etc
chmod 644 "$HTTP_DIR/alpine/starlit.apkovl.tar.gz"

msg "Pronto: $HTTP_DIR/alpine/starlit.apkovl.tar.gz"
