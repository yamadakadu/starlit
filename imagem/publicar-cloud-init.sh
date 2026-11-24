#!/usr/bin/env bash
# Etapa 2: gera e publica o user-data e o meta-data do cloud-init.
# Pode ser rodado de novo sempre que o user-data mudar, sem regerar a imagem.
# Uso: sudo imagem/publicar-cloud-init.sh
RAIZ=$(cd "$(dirname "$0")/.." && pwd)
source "$RAIZ/lib.sh"
exigir_root

[ -f "$SSH_PUBKEY_FILE" ] || erro "chave pública não encontrada: $SSH_PUBKEY_FILE"
SSH_PUBKEY=$(cat "$SSH_PUBKEY_FILE")

DESTINO="$HTTP_DIR/cloud-init"
mkdir -p "$DESTINO"
renderizar "$RAIZ/imagem/user-data.tpl" "$DESTINO/user-data" 'USUARIO SSH_PUBKEY SERVIDOR_IP'
: > "$DESTINO/meta-data"
chmod 644 "$DESTINO/user-data" "$DESTINO/meta-data"

if command -v cloud-init >/dev/null; then
  msg "Validando o user-data"
  cloud-init schema -c "$DESTINO/user-data"
fi

msg "Publicado em $DESTINO"
