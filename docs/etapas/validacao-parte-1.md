# Validação da Parte 1

Com uma placa só, cada linha dos logs do servidor é dela, o que facilita achar onde algo falhou. Pontos de checagem, na ordem:

1. A placa aparece no log do dnsmasq e baixa o iPXE (etapas 3 e 4).
2. O Alpine inicia (etapa 4).
3. O script grava a imagem e reinicia (etapa 5).
4. A placa inicia pela eMMC, o cloud-init cria o usuário e o acesso funciona: `ssh -i ~/.ssh/cluster-key ubuntu@<ip da placa>` (etapa 2). O IP aparece no `phone-home.log` ou na lista de clientes DHCP do roteador.
5. O aviso da placa aparece em `/var/log/nginx/phone-home.log` no servidor.

Ainda com essa placa, testar as proteções:

- **Placa já instalada:** forçar o boot pela rede pelo menu de boot da BIOS. O script deve exibir "já instalada" e não gravar nada.
- **Reinstalação manual:** seguir o procedimento manual da etapa 5 (`wipefs` + `reboot`). A placa deve ser instalada de novo.
