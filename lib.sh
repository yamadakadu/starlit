# Funções comuns aos scripts. Uso: source "$RAIZ/lib.sh" (define RAIZ antes).
# shellcheck shell=bash

set -euo pipefail

msg()  { printf '\n==> %s\n' "$*"; }
erro() { printf 'ERRO: %s\n' "$*" >&2; exit 1; }

[ -f "$RAIZ/config.env" ] \
  || erro "config.env não encontrado: cp config.env.example config.env e preencher (README, etapa 3)"
# shellcheck source=config.env.example
source "$RAIZ/config.env"
for v in SERVIDOR_IP INTERFACE REDE; do
  [ -n "${!v:-}" ] || erro "$v vazio no config.env"
done
unset v

exigir_root() {
  [ "$(id -u)" -eq 0 ] || erro "rode com sudo: sudo $0"
}

# Gera um arquivo a partir de um modelo, substituindo só as variáveis listadas
# (as demais, como ${base} do iPXE ou $uri do nginx, ficam intactas).
# Uso: renderizar modelo destino 'VAR1 VAR2'
renderizar() {
  local modelo=$1 destino=$2 vars="" v
  command -v envsubst >/dev/null || apt-get install -y gettext-base
  for v in $3; do
    export "${v?}"
    vars="$vars \${$v}"
  done
  envsubst "$vars" < "$modelo" > "$destino"
}
