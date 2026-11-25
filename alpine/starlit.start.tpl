#!/bin/sh
# Etapa 5: roda no Alpine iniciado pela rede (gerado por alpine/empacotar-apkovl.sh).
# Grava a imagem na eMMC, se ela ainda não estiver instalada, coloca a eMMC em
# primeiro lugar na ordem de boot e reinicia.
# Este script NUNCA apaga uma placa já instalada: reinstalar é sempre manual (README).
SERVIDOR=http://${SERVIDOR_IP}

exec >/dev/console 2>&1   # mostra as mensagens no monitor
echo "=== Starlit: instalação via rede ==="

# 0. Garantir a rede (normalmente já vem configurada do boot)
i=0
until wget -q --spider "$SERVIDOR/boot.ipxe"; do
  i=$((i + 1))
  [ "$i" -gt 10 ] && { echo "ERRO: servidor $SERVIDOR inacessível"; exit 1; }
  for n in /sys/class/net/*; do
    [ "${n##*/}" = lo ] || udhcpc -q -n -i "${n##*/}" >/dev/null 2>&1
  done
  sleep 2
done

# 1. Encontrar a eMMC (ignora pendrives e as áreas internas boot0/boot1 do eMMC)
DISCO=
for d in /sys/block/mmcblk*; do
  case "${d##*/}" in *boot*) continue ;; esac
  [ "$(cat "$d/device/type" 2>/dev/null)" = "MMC" ] && DISCO=/dev/${d##*/}
done
[ -z "$DISCO" ] && { echo "ERRO: eMMC não encontrada"; exit 1; }
echo "eMMC: $DISCO"

# 2. Verificar se a imagem já está instalada
INSTALADA=
mkdir -p /mnt/raiz
if mount -o ro "${DISCO}p1" /mnt/raiz 2>/dev/null; then
  INSTALADA=$(cat /mnt/raiz/etc/starlit-release 2>/dev/null)
  umount /mnt/raiz
fi

# 3. Gravar a imagem, se necessário
if [ -n "$INSTALADA" ]; then
  echo "Imagem $INSTALADA já instalada, nada será gravado"
else
  echo "Gravando a imagem em $DISCO..."
  set -o pipefail   # falha se o download ou a descompressão falharem, não só o dd
  wget -qO- "$SERVIDOR/noble.raw.gz" | gunzip | dd of="$DISCO" bs=4M \
    || { echo "ERRO: falha na gravação"; exit 1; }
  sync
  partx -u "$DISCO"
  echo "Gravação concluída"
fi

# 4. Colocar a eMMC em primeiro lugar na ordem de boot
mount -t efivarfs efivarfs /sys/firmware/efi/efivars 2>/dev/null
for n in $(efibootmgr | grep Starlit | cut -c5-8); do efibootmgr -q -B -b "$n"; done
efibootmgr -q -c -d "$DISCO" -p 15 -L Starlit -l '\EFI\ubuntu\shimx64.efi' \
  || { echo "ERRO: falha ao criar a opção de boot"; exit 1; }
efibootmgr

echo "Reiniciando em 5 segundos..."
sleep 5
reboot
