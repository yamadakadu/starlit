#cloud-config
# Modelo: imagem/publicar-cloud-init.sh substitui ${USUARIO}, ${SSH_PUBKEY} e ${SERVIDOR_IP}.

users:
  - name: ${USUARIO}
    groups: [sudo]
    shell: /bin/bash
    lock_passwd: true                  # sem senha: acesso só pela chave SSH
    sudo: "ALL=(ALL) NOPASSWD:ALL"     # necessário, já que o usuário não tem senha
    ssh_authorized_keys:
      - ${SSH_PUBKEY}

ssh_pwauth: false
preserve_hostname: true                # o hostname é definido à mão (etapa 6)

package_update: true
packages:
  - curl

phone_home:
  url: http://${SERVIDOR_IP}/phone-home/
  post: [hostname, instance_id]
  tries: 10
