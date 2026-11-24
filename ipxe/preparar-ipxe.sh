#!/usr/bin/env bash
# Etapa 4: compila o iPXE com o script embutido, baixa o netboot do Alpine
# e gera o boot.ipxe.
# Uso: sudo ipxe/preparar-ipxe.sh
RAIZ=$(cd "$(dirname "$0")/.." && pwd)
source "$RAIZ/lib.sh"
exigir_root

ALPINE_URL=https://dl-cdn.alpinelinux.org/alpine
OBRA="$WORK_DIR/ipxe"
mkdir -p "$OBRA" "$TFTP_DIR" "$HTTP_DIR/alpine"

msg "Instalando dependências"
apt-get install -y git build-essential liblzma-dev

msg "Compilando o iPXE (pode levar alguns minutos)"
if [ -d "$OBRA/ipxe/.git" ]; then
  git -C "$OBRA/ipxe" pull --ff-only
else
  git clone --depth 1 https://github.com/ipxe/ipxe.git "$OBRA/ipxe"
fi
renderizar "$RAIZ/ipxe/embed.ipxe.tpl" "$OBRA/embed.ipxe" 'SERVIDOR_IP'
make -C "$OBRA/ipxe/src" -j"$(nproc)" bin-x86_64-efi/snponly.efi EMBED="$OBRA/embed.ipxe"
install -m 644 "$OBRA/ipxe/src/bin-x86_64-efi/snponly.efi" "$TFTP_DIR/ipxe.efi"

msg "Baixando o netboot do Alpine ($ALPINE_VERSAO)"
# Fixa a versão real (ex.: v3.22), para o kernel e os pacotes baixados no boot serem da mesma versão
if [ "$ALPINE_VERSAO" = latest-stable ]; then
  ALPINE_BRANCH=$(curl -fsSL "$ALPINE_URL/latest-stable/releases/x86_64/latest-releases.yaml" \
    | awk '/branch:/ { print $2; exit }')
  [ -n "$ALPINE_BRANCH" ] || erro "não foi possível descobrir a versão estável do Alpine"
else
  ALPINE_BRANCH=$ALPINE_VERSAO
fi
for f in vmlinuz-lts initramfs-lts modloop-lts; do
  curl -fL -o "$HTTP_DIR/alpine/$f" "$ALPINE_URL/$ALPINE_BRANCH/releases/x86_64/netboot/$f"
done
chmod 644 "$HTTP_DIR"/alpine/*

msg "Gerando o boot.ipxe"
renderizar "$RAIZ/ipxe/boot.ipxe.tpl" "$HTTP_DIR/boot.ipxe" 'SERVIDOR_IP ALPINE_BRANCH'
chmod 644 "$HTTP_DIR/boot.ipxe"

msg "Pronto: $TFTP_DIR/ipxe.efi, $HTTP_DIR/boot.ipxe e Alpine $ALPINE_BRANCH em $HTTP_DIR/alpine/"
