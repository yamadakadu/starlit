# Projeto

## Componentes do projeto

- UpBoards CHT01 (especificação e quantidade a serem verificadas)
- Switch D-Link DGS-1210-28
- Roteador TP-Link TL-R470T+ v6.0
- Todo o cabeamento, de energia e rede não precisa ser especificado, 

Especificações detalhadas em [especificacoes.md](referencia/especificacoes.md).

## Proposta

A ideia do projeto é de montar uma arquitetura com os componentes mencionados para uma futura implementação de um cluster Kubernetes.
A instalação e implementação do cluster será feita em algumas etapas:

1. Preparação da infraestrutura: roteador, switch, UpBoards

2. Preparação da imagem com cloud-init

3. Preparação da máquina com dnsmasq e servidor http

4. Preparação do bootloader

5. Instalação do SO via rede

6. Registro dos endereços MAC e IP

7. Preparação do cluster

O trabalho está dividido em duas partes:

- **[Parte 1: implementação inicial com uma placa](etapas/index.md#parte-1-implementacao-inicial-com-uma-placa)** (etapas 1 a 5): montar o servidor e instalar o SO via rede em **uma** placa, validando cada passo.
- **[Parte 2: três placas](etapas/index.md#parte-2-tres-placas)** (etapas 6 e 7): instalar três placas ao mesmo tempo, registrar MAC/IP/hostname e preparar o cluster de teste.
