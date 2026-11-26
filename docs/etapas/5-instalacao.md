# Etapa 5. Instalação do SO via rede

**Abordagem:** o Alpine iniciado pela rede (etapa 4) roda o script [alpine/starlit.start.tpl](https://github.com/yamadakadu/starlit/blob/main/alpine/starlit.start.tpl), que:

1. garante que a rede está ativa e o servidor responde;
2. encontra a eMMC (ignorando pendrives e as áreas internas `mmcblk0boot0`/`boot1`);
3. verifica se a imagem já está instalada (arquivo `/etc/starlit-release` na partição raiz). Se estiver, **não grava nada**;
4. se não estiver, baixa a `noble.raw.gz` do servidor e grava direto na eMMC, descomprimindo durante a gravação (com `pipefail`: uma falha no download ou na descompressão interrompe o script, em vez de deixar uma imagem incompleta);
5. coloca a eMMC em primeiro lugar na ordem de boot (opção "Starlit", partição EFI 15, `\EFI\ubuntu\shimx64.efi`) e reinicia.

As mensagens do script aparecem no monitor. A partir daí, a placa sempre inicia pela eMMC e só volta ao boot pela rede se a eMMC falhar. No primeiro boot pela eMMC, o cloud-init busca o `user-data` no servidor e configura a placa.

**Não desligar nem reiniciar a placa durante a gravação.** O começo da imagem é gravado primeiro, então a marca `/etc/starlit-release` pode já estar na eMMC antes de a gravação terminar. Nesse caso, o script considera a placa instalada e não grava de novo, mas a placa não inicia. Para recuperar, seguir a reinstalação de uma placa que não inicia (abaixo).

**Script** (empacota o `starlit.start` como *apkovl*: um `.tar.gz` com arquivos que o Alpine copia para o `/etc` ao iniciar):

```sh
sudo alpine/empacotar-apkovl.sh
```

O pacote inclui o script, o ativa no boot e pede ao Alpine os pacotes `efibootmgr` e `util-linux`, que são baixados da internet no boot. Por isso, a rede precisa ter acesso à internet.

**Reinstalação: sempre manual.** Nenhum script apaga a eMMC de uma placa já instalada; isso é proposital, para que um nó do cluster nunca seja apagado por engano (por exemplo, se a ordem de boot voltar ao padrão). Para reinstalar uma placa, à mão, na própria placa:

1. `sudo wipefs -a -f /dev/mmcblk0` (conferir antes com `lsblk` que a eMMC é a `mmcblk0`);
2. `sudo reboot`.

Sem sistema na eMMC, a BIOS cai no boot pela rede, a verificação não encontra a marca e a imagem é gravada de novo.

**Reinstalação de uma placa que não inicia** (imagem com defeito ou gravação interrompida). O Ubuntu da eMMC não chega a um terminal, e o boot pela rede também não serve: o script do Alpine encontra a marca, diz "já instalada" e reinicia. O caminho é iniciar o Alpine **sem** o script:

1. No servidor, desativar o pacote do script:
   ```sh
   sudo mv /srv/http/alpine/starlit.apkovl.tar.gz /srv/http/alpine/starlit.apkovl.tar.gz.off
   ```
2. Na placa, escolher o boot por IPv4 no menu de boot da BIOS (tecla a confirmar; nas UP Boards costuma ser F7) ou pelo *Boot Override* da BIOS. Sem o pacote, o Alpine inicia e para na tela de login.
3. Entrar como `root` (sem senha). O Alpine básico não traz o `wipefs`, que é instalado da internet:
   ```sh
   apk add wipefs
   lsblk                       # conferir que a eMMC é a mmcblk0
   wipefs -a -f /dev/mmcblk0
   ```
4. No servidor, reativar o pacote **antes** de reiniciar a placa:
   ```sh
   sudo mv /srv/http/alpine/starlit.apkovl.tar.gz.off /srv/http/alpine/starlit.apkovl.tar.gz
   ```
5. Na placa: `reboot`. Com a eMMC vazia, ela cai no boot pela rede e a imagem é gravada de novo.

Enquanto o pacote estiver desativado, nenhuma outra placa é instalada pela rede.
