# Etapa 4. Preparação do bootloader

**Abordagem:** usar o **iPXE** como bootloader. A BIOS baixa o iPXE por TFTP, e ele baixa todo o resto por HTTP. O que ele inicia é um **Alpine Linux** carregado na RAM (~100 MB), que na etapa 5 grava a `noble.raw.gz` na eMMC.

Sequência do boot:

```
BIOS (PXE) --TFTP--> ipxe.efi --HTTP--> boot.ipxe --HTTP--> kernel + initramfs do Alpine
```

**Script:**

```sh
sudo ipxe/preparar-ipxe.sh
```

1. Compila o iPXE (`snponly.efi`, que usa o driver de rede da própria BIOS) com o script embutido [ipxe/embed.ipxe.tpl](https://github.com/yamadakadu/starlit/blob/main/ipxe/embed.ipxe.tpl) e o publica como `/srv/tftp/ipxe.efi`. O script embutido pede um IP e carrega o `boot.ipxe` do servidor; sem ele, o iPXE receberia de novo o próprio iPXE pelo DHCP e entraria em loop. A compilação na UP Board pode levar vários minutos.
2. Descobre a versão estável do Alpine (`ALPINE_VERSAO=latest-stable` no `config.env`; ou uma versão fixa) e baixa os arquivos de netboot (`vmlinuz-lts`, `initramfs-lts`, `modloop-lts`) para `/srv/http/alpine/`.
3. Gera `/srv/http/boot.ipxe` a partir de [ipxe/boot.ipxe.tpl](https://github.com/yamadakadu/starlit/blob/main/ipxe/boot.ipxe.tpl). Ele inicia o Alpine com o `apkovl` da etapa 5 (o script de gravação). Como o `boot.ipxe` fica no servidor HTTP, dá para mudar o boot sem recompilar o iPXE.

**Teste:** ligar a placa de teste com monitor. Deve aparecer o iPXE, depois o boot do Alpine, terminando na tela de login do Alpine (enquanto o `apkovl` da etapa 5 não existir).
