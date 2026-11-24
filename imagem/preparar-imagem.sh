#!/usr/bin/env bash
# Etapa 2: prepara a imagem do Ubuntu que será gravada nas placas.
# Baixa a cloud image, confere o SHA256, converte para raw, aponta o cloud-init
# para o servidor, grava a marca /etc/starlit-release, comprime e publica.
# Uso: sudo imagem/preparar-imagem.sh
RAIZ=$(cd "$(dirname "$0")/.." && pwd)
source "$RAIZ/lib.sh"
exigir_root

ESP_GUID=c12a7328-f81f-11d2-ba4b-00a0c93ec93b   # tipo de partição EFI (GPT)

msg "Instalando dependências"
command -v qemu-img >/dev/null || apt-get install -y qemu-utils

mkdir -p "$WORK_DIR/imagem" "$HTTP_DIR"
cd "$WORK_DIR/imagem"

msg "Baixando $UBUNTU_IMG"
curl -fsSLO "$UBUNTU_BASE_URL/SHA256SUMS"
[ -f "$UBUNTU_IMG" ] || curl -fLO "$UBUNTU_BASE_URL/$UBUNTU_IMG"
if ! grep "[ *]$UBUNTU_IMG\$" SHA256SUMS | sha256sum -c -; then
  rm -f "$UBUNTU_IMG"
  erro "SHA256 não confere (imagem apagada; rode de novo para baixar outra vez)"
fi

msg "Convertendo para raw"
rm -f noble.raw
qemu-img convert -O raw "$UBUNTU_IMG" noble.raw

msg "Ajustando a imagem"
MNT=$(mktemp -d)
LOOP=$(losetup -Pf --show noble.raw)
limpar() {
  umount "$MNT" 2>/dev/null || true
  losetup -d "$LOOP" 2>/dev/null || true
  rmdir "$MNT" 2>/dev/null || true
}
trap limpar EXIT
udevadm settle

# Confere o que o script da etapa 5 assume: partição 15 = EFI, com o shim do Ubuntu
[ "$(lsblk -no PARTTYPE "${LOOP}p15")" = "$ESP_GUID" ] \
  || erro "a partição 15 não é a partição EFI; ajustar alpine/starlit.start.tpl"
mount -o ro "${LOOP}p15" "$MNT"
[ -f "$MNT/EFI/ubuntu/shimx64.efi" ] || erro "EFI/ubuntu/shimx64.efi não encontrado na partição EFI"
umount "$MNT"

mount "${LOOP}p1" "$MNT"
[ -d "$MNT/etc/cloud/cloud.cfg.d" ] || erro "a partição 1 não parece ser a raiz do Ubuntu"
cat > "$MNT/etc/cloud/cloud.cfg.d/99-starlit-nocloud.cfg" <<EOF
# Gerado por imagem/preparar-imagem.sh: busca user-data e meta-data no servidor
datasource_list: [ NoCloud, None ]
datasource:
  NoCloud:
    seedfrom: http://$SERVIDOR_IP/cloud-init/
EOF
echo "$IMAGEM_VERSAO" > "$MNT/etc/starlit-release"
umount "$MNT"
losetup -d "$LOOP"

msg "Comprimindo (pode levar alguns minutos)"
gzip -c noble.raw > "$HTTP_DIR/noble.raw.gz.tmp"
mv "$HTTP_DIR/noble.raw.gz.tmp" "$HTTP_DIR/noble.raw.gz"
chmod 644 "$HTTP_DIR/noble.raw.gz"

msg "Pronto: $HTTP_DIR/noble.raw.gz ($(du -h "$HTTP_DIR/noble.raw.gz" | cut -f1)), versão $IMAGEM_VERSAO"
