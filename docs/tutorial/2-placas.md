# 2. Preparação das UP Boards: BIOS e eMMC

Fazer em **todas** as placas, inclusive a que será o servidor. Cada placa precisa de monitor (HDMI) e teclado USB durante a preparação.

## 2.1 Configuração da BIOS

1. Ligar a placa e apertar **DEL** repetidamente. Se pedir senha, apertar **Enter**.
2. **Rede no boot:** *Advanced → Network Stack Configuration*:
   - *Network Stack*: **Enabled**;
   - *Ipv4 PXE Support*: **Enabled**;
   - *Ipv6 PXE Support*: **Disabled** (o servidor não atende IPv6, e essa opção só atrasa o boot).

   As opções de boot pela rede (IPv4) **só aparecem na ordem de boot depois** de habilitar o *Network Stack* e o *Ipv4 PXE Support*, salvar e reiniciar. Se não aparecerem, conferir essas duas opções.
3. **Secure Boot: Disabled** (*menu a confirmar*, geralmente em *Security* ou *Boot*). O iPXE não é assinado e seria bloqueado.
4. **Ordem de boot** (*Boot*): deixar o **IPv4** em primeiro lugar e as demais opções como *Disabled*. Depois da instalação, o próprio script de gravação coloca a eMMC em primeiro lugar, então esse ajuste é feito uma vez só.
5. Salvar e sair (*Save & Exit*; *tecla a confirmar*, geralmente F4).

Para forçar o boot pela rede numa placa já instalada, usar o **menu de boot** ao ligar (*tecla a confirmar*, nas UP Boards costuma ser **F7**) e escolher IPv4.

## 2.2 Limpar a eMMC

Placas com um sistema antigo na eMMC devem ser limpas. Mesmo com a eMMC desativada na ordem de boot, a BIOS (UEFI) inicia qualquer `\EFI\BOOT\BOOTX64.EFI` que encontrar quando o boot pela rede falha. Uma placa limpa, ao contrário, para na tela da BIOS, o que deixa claro que o boot pela rede não funcionou.

Há três formas de conseguir um terminal de root na placa:

- **Com usuário e senha do sistema antigo:** entrar normalmente e usar `sudo`.
- **Pelo GRUB, sem senha:** ligar a placa e, **quando o logo da BIOS sumir e a tela ficar preta**, apertar **Esc** uma vez (ou segurar **Shift**). Apertar cedo demais faz a BIOS entrar no setup; um Esc a mais leva ao terminal do GRUB (`grub>`; digitar `normal` e Enter para voltar ao menu). No menu, apertar `e`, ir ao fim da linha que começa com `linux`, acrescentar ` init=/bin/bash` e apertar **Ctrl+X**.
- **Por pendrive:** iniciar por um pendrive com qualquer Linux live (ex.: Alpine *standard*, usuário `root` sem senha), escolhido no menu de boot.

No terminal:

```sh
lsblk -d -o NAME,SIZE,TYPE        # a eMMC é a mmcblk0 (~29 GB)
wipefs -a -f /dev/mmcblk0         # apaga as tabelas de partição (com sudo, se não for root)
```

Ignorar `mmcblk0boot0`, `mmcblk0boot1` e `mmcblk0rpmb` (áreas internas da eMMC). Um pendrive aparece como `sda`. O Alpine não traz o `wipefs`: instalar com `apk add wipefs`.

Reiniciar (`reboot`; no terminal aberto pelo GRUB, `reboot -f`).

**Verificação:** sem servidor no ar, a placa limpa vai direto para a tela da BIOS. Se ainda iniciar o sistema antigo, a eMMC não foi apagada.
