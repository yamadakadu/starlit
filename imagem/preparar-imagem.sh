#!/usr/bin/env bash
# Etapa 2: prepara a imagem do Ubuntu que será gravada nas placas.
# Baixa a cloud image, confere o SHA256, converte para raw, troca o kernel
# "virtual" pelo genérico (com o driver da eMMC), aponta o cloud-init para o
# servidor, grava a marca /etc/starlit-release, comprime e publica.
# Uso: sudo imagem/preparar-imagem.sh
RAIZ=$(cd "$(dirname "$0")/.." && pwd)
source "$RAIZ/lib.sh"
exigir_root

ESP_GUID=c12a7328-f81f-11d2-ba4b-00a0c93ec93b   # tipo de partição EFI (GPT)
AUMENTO=2G   # espaço extra na partição raiz para o kernel genérico e o firmware

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

# A raiz da cloud image tem pouco espaço livre (~800 MB). A partição 1 é a última
# do disco: aumenta o arquivo, move a cópia da tabela GPT para o novo fim e
# estende a partição 1. Na placa, o cloud-init ainda a estende até ocupar a eMMC.
msg "Aumentando a partição raiz em $AUMENTO"
truncate -s "+$AUMENTO" noble.raw
sfdisk -q --relocate gpt-bak-std noble.raw
echo ',+' | sfdisk -q --no-reread -N 1 noble.raw

msg "Ajustando a imagem"
MNT=$(mktemp -d)
LOOP=$(losetup -Pf --show noble.raw)
limpar() {
  umount -R "$MNT" 2>/dev/null || true
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

e2fsck -fy "${LOOP}p1" || [ $? -le 1 ] || erro "e2fsck encontrou erros na partição 1"
resize2fs "${LOOP}p1"

# Monta a imagem como no sistema instalado (/etc/fstab da cloud image:
# raiz = p1, /boot = p16, /boot/efi = p15), para rodar o apt dentro dela
mount "${LOOP}p1" "$MNT"
[ -d "$MNT/etc/cloud/cloud.cfg.d" ] || erro "a partição 1 não parece ser a raiz do Ubuntu"
mount "${LOOP}p16" "$MNT/boot"
mount "${LOOP}p15" "$MNT/boot/efi"
for d in dev dev/pts proc sys; do mount --bind "/$d" "$MNT/$d"; done
mount -t tmpfs tmpfs "$MNT/run"
mkdir -p "$MNT/run/systemd/resolve"          # o /etc/resolv.conf da imagem aponta para cá
cp -L /etc/resolv.conf "$MNT/run/systemd/resolve/stub-resolv.conf"
printf '#!/bin/sh\nexit 101\n' > "$MNT/usr/sbin/policy-rc.d"   # impede o apt de iniciar serviços
chmod 755 "$MNT/usr/sbin/policy-rc.d"

# O kernel "virtual" da cloud image não tem os módulos da eMMC (linux-modules-extra):
# a placa carrega o kernel pela UEFI, mas o initramfs não encontra a partição raiz.
# O linux-image-generic traz os módulos e continua trazendo nas atualizações de kernel.
# Os módulos extras também são instalados para os kernels já presentes na imagem,
# caso o linux-image-generic traga um kernel mais novo.
msg "Instalando o kernel genérico na imagem"
EXTRAS=()
for k in "$MNT"/usr/lib/modules/*; do EXTRAS+=("linux-modules-extra-${k##*/}"); done
chroot "$MNT" env DEBIAN_FRONTEND=noninteractive apt-get update
chroot "$MNT" env DEBIAN_FRONTEND=noninteractive apt-get install -y linux-image-generic "${EXTRAS[@]}"
chroot "$MNT" apt-get clean

# Console: o último console= recebe as mensagens do boot. A cloud image usa
# "console=tty1 console=ttyS0" (serial); invertido, elas aparecem no monitor (HDMI).
GRUB_CLOUD=$MNT/etc/default/grub.d/50-cloudimg-settings.cfg
grep -q 'console=tty1 console=ttyS0' "$GRUB_CLOUD" \
  || erro "linha do console não encontrada em ${GRUB_CLOUD#"$MNT"}"
sed -i 's/console=tty1 console=ttyS0/console=ttyS0 console=tty1/' "$GRUB_CLOUD"

msg "Regerando o initramfs e o grub.cfg"
chroot "$MNT" update-initramfs -u -k all
chroot "$MNT" update-grub
for k in "$MNT"/usr/lib/modules/*; do
  [ -d "$k/kernel/drivers/mmc" ] || erro "kernel ${k##*/} sem os módulos da eMMC"
done

rm -f "$MNT/usr/sbin/policy-rc.d"

cat > "$MNT/etc/cloud/cloud.cfg.d/99-starlit-nocloud.cfg" <<EOF
# Gerado por imagem/preparar-imagem.sh: busca user-data e meta-data no servidor
datasource_list: [ NoCloud, None ]
datasource:
  NoCloud:
    seedfrom: http://$SERVIDOR_IP/cloud-init/
EOF
echo "$IMAGEM_VERSAO" > "$MNT/etc/starlit-release"

# Zera os blocos livres (pacotes baixados, initramfs antigos), para o gzip ficar pequeno
fstrim "$MNT/boot"
fstrim "$MNT"
umount -R "$MNT"
losetup -d "$LOOP"

msg "Comprimindo (pode levar alguns minutos)"
gzip -c noble.raw > "$HTTP_DIR/noble.raw.gz.tmp"
mv "$HTTP_DIR/noble.raw.gz.tmp" "$HTTP_DIR/noble.raw.gz"
chmod 644 "$HTTP_DIR/noble.raw.gz"

msg "Pronto: $HTTP_DIR/noble.raw.gz ($(du -h "$HTTP_DIR/noble.raw.gz" | cut -f1)), versão $IMAGEM_VERSAO"
