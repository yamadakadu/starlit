#!/usr/bin/env bash
# Etapa 3: configura o servidor (dnsmasq em proxy DHCP + TFTP, nginx).
# O servidor precisa já estar com o IP SERVIDOR_IP (DHCP com reserva no roteador; README, etapa 3).
# Uso: sudo servidor/configurar-servidor.sh
RAIZ=$(cd "$(dirname "$0")/.." && pwd)
source "$RAIZ/lib.sh"
exigir_root

msg "Conferindo a rede"
ip link show "$INTERFACE" >/dev/null 2>&1 \
  || erro "interface $INTERFACE não existe; ajustar INTERFACE no config.env (ver ip -br link)"
ip -4 -o addr show dev "$INTERFACE" | grep -q " $SERVIDOR_IP/" \
  || erro "a interface $INTERFACE não tem o IP $SERVIDOR_IP; conferir o DHCP/reserva do servidor ou o SERVIDOR_IP no config.env (README, etapa 3)"

msg "Instalando pacotes"
apt-get install -y dnsmasq nginx gettext-base

msg "Criando pastas"
mkdir -p "$TFTP_DIR" "$HTTP_DIR/alpine" "$HTTP_DIR/cloud-init"

msg "Configurando o dnsmasq"
renderizar "$RAIZ/servidor/dnsmasq-pxe.conf.tpl" /etc/dnsmasq.d/starlit-pxe.conf 'INTERFACE REDE TFTP_DIR'
dnsmasq --test

msg "Configurando o nginx"
renderizar "$RAIZ/servidor/nginx-starlit.conf.tpl" /etc/nginx/sites-available/starlit 'HTTP_DIR'
ln -sf /etc/nginx/sites-available/starlit /etc/nginx/sites-enabled/starlit
rm -f /etc/nginx/sites-enabled/default
nginx -t

if command -v ufw >/dev/null && ufw status | grep -q "Status: active"; then
  msg "Liberando portas no firewall"
  ufw allow 67,69,4011/udp
  ufw allow 80/tcp
fi

msg "Reiniciando os serviços"
systemctl enable dnsmasq nginx
systemctl restart dnsmasq nginx

msg "Pronto. Acompanhe o boot das placas com: journalctl -u dnsmasq -f"
