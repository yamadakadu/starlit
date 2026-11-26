# Etapa 1. Preparação da infraestrutura

- Roteador e switch

Para esses dispositivos, basta resetá-los e configurá-los na mesma rede privada. Por enquanto, não foi feita nenhuma segmentação de rede (VLANs).
O servidor e as placas devem ser ligados ao **switch** (portas gigabit), e não às portas do roteador (100 Mbps).

- UpBoards

**Instalação**

Para as plaquinhas, algumas delas já possuem algum sistema operacional (Ubuntu) instalado na memória eMMC e que não será utilizado.
Como a ideia é que o boot seja feito via rede, uma opção deve ser habilitada nas configurações na BIOS, que pode ser acessada apertando DEL repetidamente quando ligar a energia. Será pedida uma senha, basta apertar ENTER que ele entra na BIOS.
Se a configuração de rede (Advanced -> Network Stack Configuration -> Network Stack, Ipv4 PXE Support -> Enabled) estiver habilitada, será possível escolher o boot por IPv4 na ordem de boot. O Ipv6 PXE Support pode ficar Disabled, pois o servidor não atende IPv6 e essa opção só atrasa o boot.
Na ordem de boot, deixar apenas o IPv4 ativo e as demais opções como Disabled.
Depois da instalação, o próprio script da etapa 5 coloca a eMMC em primeiro lugar na ordem de boot, então esse ajuste manual só é feito uma vez.
O **Secure Boot** também precisa estar **desligado** na BIOS, pois o bootloader usado no boot pela rede (iPXE, etapa 4) não é assinado e seria bloqueado.
Se o servidor com dnsmasq não estiver configurado ou não estiver configurado corretamente, a plaquinha não recebe o SO e tenta a próxima opção de boot. Se não encontrar nada:

- **com o Ubuntu antigo na eMMC**, ela inicia o Ubuntu **mesmo com essa opção desativada na BIOS**. Quando todas as opções falham, a BIOS (UEFI) procura em qualquer disco o arquivo de boot padrão (`\EFI\BOOT\BOOTX64.EFI`), que o Ubuntu instala. Ao iniciar por esse caminho, o Ubuntu também pode recriar a própria opção de boot.
- **sem SO na eMMC**, ela vai direto para a tela da BIOS e não tenta a rede de novo sozinha: é preciso reiniciá-la.

Por isso, é importante que nessas plaquinhas não tenha nenhum SO instalado previamente.

A placa que será o **servidor** não usa o boot pela rede: ela é instalada à mão (etapa 3) e inicia pela eMMC.

**Remoção do Ubuntu antigo**

Com o servidor funcionando (etapas 3 a 5), não é preciso fazer nada: o script da etapa 5 sobrescreve o Ubuntu antigo. Para removê-lo antes, há três formas de conseguir um terminal na placa (com monitor e teclado):

- **Com usuário e senha do Ubuntu:** entrar normalmente.
- **Sem senha, pelo GRUB:** ao ligar a placa, apertar ESC repetidamente até aparecer o menu do GRUB e parar de apertar assim que ele aparecer (um ESC a mais leva ao terminal do GRUB, `grub>`; para voltar ao menu, digitar `normal` e Enter). Com a primeira opção selecionada, apertar `e`, ir até o fim da linha que começa com `linux`, acrescentar ` init=/bin/bash` e apertar `Ctrl+X`. A placa abre um terminal de root sem pedir senha.
- **Sem senha, por pendrive:** iniciar a placa por um pendrive com qualquer Linux live (ex.: Alpine *standard*, usuário `root` sem senha), escolhendo o pendrive na ordem de boot da BIOS.

No terminal:

1. Identificar a eMMC: `lsblk -d -o NAME,SIZE,TYPE`. A eMMC é a `mmcblk0`. As entradas `mmcblk0boot0`, `mmcblk0boot1` e `mmcblk0rpmb` são áreas internas do eMMC e devem ser ignoradas; se estiver usando um pendrive, ele aparece como `sda`.
2. Apagar a tabela de partições da eMMC (a principal e a cópia de segurança, que fica no fim do disco): `sudo wipefs -a -f /dev/mmcblk0`. No terminal do GRUB e no Alpine, o usuário já é root, então o comando vai sem `sudo`.
3. Reiniciar: `sudo reboot` (no terminal do GRUB: `reboot -f`).

**Verificação:** sem o servidor no ar, a placa deve ir direto para a tela da BIOS. Se ainda iniciar o Ubuntu, a eMMC não foi apagada.

O servidor (etapa 3) deve ser ligado **antes** das placas.

**Conexão dos cabos**

A plaquinha precisa de uma fonte de ()W e tem suporte para até 4 entradas USB-A. Além disso, possui uma interface com entrada para cabo de rede e uma entrada para HDMI.
