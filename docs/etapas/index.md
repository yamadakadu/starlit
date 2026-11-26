# Etapas

O procedimento está dividido em duas partes.

## Parte 1: implementação inicial com uma placa

Nesta parte são usadas duas UP Boards: uma como **servidor** e uma como **placa de teste**, que recebe o SO via rede. A placa de teste deve ter monitor e teclado, para acompanhar cada passo.

- [Etapa 1. Preparação da infraestrutura](1-infraestrutura.md)
- [Etapa 2. Preparação da imagem com cloud-init](2-imagem.md)
- [Etapa 3. Preparação da máquina com dnsmasq e servidor http](3-servidor.md)
- [Etapa 4. Preparação do bootloader](4-bootloader.md)
- [Etapa 5. Instalação do SO via rede](5-instalacao.md)
- [Validação da Parte 1](validacao-parte-1.md)

## Parte 2: três placas

Com a Parte 1 validada, três placas são instaladas ao mesmo tempo, usando o mesmo servidor e os mesmos scripts. Nenhum script novo é necessário: o que muda é o registro das placas (etapa 6) e a validação com várias placas.

- [Etapa 6. Registro dos endereços MAC e IP](6-registro.md)
- [Validação da Parte 2](validacao-parte-2.md)
- [Etapa 7. Preparação do cluster](7-cluster.md)
