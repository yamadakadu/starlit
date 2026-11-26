# Etapa 2. Preparação da imagem com cloud-init

**Abordagem:** usar a *cloud image* oficial do **Ubuntu Server 24.04 LTS** (`noble-server-cloudimg-amd64.img`, ~600 MB), que já vem com o sistema instalado e com o cloud-init. Em vez de rodar um instalador, a imagem é gravada direto na eMMC (etapa 5) e o cloud-init faz a configuração no primeiro boot. Isso evita carregar a ISO de instalação (~3 GB) na RAM das placas (4 GB).

**Scripts** (no servidor, depois da etapa 3):

```sh
sudo imagem/preparar-imagem.sh      # imagem: noble.raw.gz
sudo imagem/publicar-cloud-init.sh  # user-data e meta-data
```

O que o `preparar-imagem.sh` faz (arquivos intermediários em `/var/tmp/starlit/`):

1. Baixa `noble-server-cloudimg-amd64.img` e confere o SHA256 com o `SHA256SUMS` publicado junto.
2. Converte de qcow2 para raw, o formato que pode ser gravado direto no disco, e aumenta a partição raiz em 2 GB: a cloud image vem com só ~800 MB livres, pouco para o passo 4.
3. Confere que a partição 15 é a partição EFI e tem o `EFI/ubuntu/shimx64.efi` (o script da etapa 5 depende disso).
4. Troca o kernel. A cloud image vem com o kernel *virtual*, feito para máquinas virtuais, que não tem o driver da eMMC (pacote `linux-modules-extra`). Com ele, a placa carrega o kernel pela UEFI, mas o Linux não encontra a partição raiz e o boot trava. O script instala na imagem (com `chroot`) o `linux-image-generic`, que traz o driver também nas atualizações de kernel futuras, e regera o initramfs e o GRUB. Também inverte a ordem do console para `console=ttyS0 console=tty1`, para as mensagens do boot aparecerem no monitor, e não na porta serial.
5. Na partição raiz (1), cria `/etc/cloud/cloud.cfg.d/99-starlit-nocloud.cfg`, que aponta o cloud-init para `http://<servidor>/cloud-init/`, e o arquivo de marca `/etc/starlit-release` com a versão da imagem (`IMAGEM_VERSAO` no `config.env`). A etapa 5 usa a marca para saber se a imagem já está instalada.
6. Zera os blocos livres (`fstrim`), comprime com gzip e publica `noble.raw.gz` no servidor HTTP. A imagem tem ~5,5 GB, dos quais ~3,3 GB ocupados; comprimida, fica com ~1,7 GB, porque o firmware e os módulos do kernel genérico já vêm comprimidos e quase não diminuem. A descompressão é feita na própria placa, durante a gravação.

**Arquivos do cloud-init** (servidos em `http://<servidor>/cloud-init/`). O modelo é [imagem/user-data.tpl](https://github.com/yamadakadu/starlit/blob/main/imagem/user-data.tpl); para mudar a configuração, editar o modelo e rodar de novo o `publicar-cloud-init.sh`, sem regerar a imagem.

- `meta-data`: vazio por enquanto (o hostname é definido na etapa 6).
- `user-data`:
  - `users`: usuário `ubuntu` com `sudo` sem senha e a chave SSH `~/.ssh/cluster-key.pub`; o usuário não tem senha, o acesso é só pela chave;
  - `ssh_pwauth: false`: login só por chave;
  - `packages`: só o básico (`curl`); o que o Kubernetes precisa fica para a etapa 7;
  - `preserve_hostname: true`: impede o cloud-init de desfazer, a cada boot, o hostname definido na etapa 6;
  - `phone_home`: no fim do primeiro boot, a placa avisa o servidor que a instalação terminou. O aviso fica registrado em `/var/log/nginx/phone-home.log`, com o IP da placa.

A cloud image não tem swap (exigência do Kubernetes) e a partição raiz cresce sozinha até ocupar a eMMC inteira no primeiro boot.
