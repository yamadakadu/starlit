# Starlit

Plano e scripts para provisionar pela rede um cluster Kubernetes *bare-metal* com cerca de 20 placas **UP Board CHT01** (4 GB de RAM, eMMC).

O servidor do projeto roda dnsmasq (proxy DHCP + TFTP) e nginx (HTTP). Cada placa faz o boot pela rede, grava o Ubuntu 24.04 na própria eMMC e é configurada pelo cloud-init no primeiro boot.

```
BIOS PXE (só IPv4) --TFTP--> ipxe.efi --HTTP--> boot.ipxe --HTTP--> Alpine (na RAM)
  -> starlit.apkovl.tar.gz (starlit.start): grava noble.raw.gz na eMMC, coloca a eMMC
     em primeiro lugar na ordem de boot UEFI e reinicia
  -> a cloud image do Ubuntu 24.04 inicia pela eMMC; o cloud-init (NoCloud, seedfrom
     http://<servidor>/cloud-init/) configura a placa e chama o phone_home
```

## Por onde começar

<div class="grid cards" markdown>

-   **[Projeto](projeto.md)**

    Componentes, proposta e divisão do trabalho em etapas.

-   **[Arquitetura](arquitetura.md)**

    Diagrama do processo inteiro, da preparação do servidor à etapa 7.

-   **[Tutorial](tutorial/index.md)**

    Passo a passo prático, do reset da rede ao acesso às placas por SSH, com os logs para depuração.

-   **[Etapas](etapas/index.md)**

    O que cada script faz e por quê, etapa por etapa, com a validação de cada parte.

-   **[Decisões do projeto](decisoes.md)**

    Escolhas já feitas e os motivos de cada uma.

-   **[Referência](referencia/especificacoes.md)**

    Especificações do hardware, inventário de endereços e o `config.env`.

</div>

## Scripts

Os scripts rodam **no servidor**, como root (`sudo`), e leem os valores do [`config.env`](referencia/configuracao.md). Uma pasta por etapa, cada uma com um script:

| Pasta | Etapa | Script | O que faz |
|---|---|---|---|
| `imagem/` | 2 | `preparar-imagem.sh` | baixa, ajusta, comprime e publica a imagem do Ubuntu |
| `imagem/` | 2 | `publicar-cloud-init.sh` | gera e publica o `user-data` e o `meta-data` |
| `servidor/` | 3 | `configurar-servidor.sh` | instala e configura o dnsmasq e o nginx |
| `ipxe/` | 4 | `preparar-ipxe.sh` | compila o iPXE, baixa o Alpine e gera o `boot.ipxe` |
| `alpine/` | 5 | `empacotar-apkovl.sh` | empacota o script de gravação que roda no Alpine |

Os arquivos `*.tpl` são modelos: o `lib.sh` (função `renderizar`) substitui neles só as variáveis listadas do `config.env`. Nenhum script apaga uma placa já instalada; a reinstalação é sempre manual.

## Estado atual

O que já foi testado nas placas:

- remoção do Ubuntu antigo pelo GRUB (`init=/bin/bash`), etapa 1;
- a cadeia completa de boot pela rede (etapas 3 a 5) instalando a placa servidor, com um notebook como servidor temporário.

Itens marcados como *a confirmar* ou *a verificar* não foram verificados nos equipamentos.
