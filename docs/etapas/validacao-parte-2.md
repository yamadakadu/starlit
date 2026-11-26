# Validação da Parte 2

Serve para avaliar o que só aparece com mais de uma placa:

- **Instalação simultânea:** ligar as três placas ao mesmo tempo, medir o tempo de instalação com elas dividindo a banda do servidor e estimar o tempo para as 20.
- **Inventário:** seguir o procedimento da etapa 6 (etiqueta, MAC no log, reserva no roteador, hostname) e comparar os logs do dnsmasq e do `phone_home` com o `inventario.md`.
- **Situações diferentes:** usar ao menos uma placa ainda com o Ubuntu antigo (o script deve sobrescrevê-lo) e uma com a eMMC já apagada.

As três placas podem seguir para a etapa 7 como cluster de teste (um nó de controle e dois de trabalho) antes da instalação das demais.
