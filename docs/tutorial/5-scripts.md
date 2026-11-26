# 5. Scripts do servidor e teste de boot das placas

## 5.1 Rodar os scripts

No servidor, nesta ordem, cada um com `sudo`:

```sh
cd ~/starlit
sudo servidor/configurar-servidor.sh     # dnsmasq + nginx; confere que a interface tem o SERVIDOR_IP
sudo imagem/preparar-imagem.sh           # imagem do Ubuntu (demorado; ~1,7 GB comprimida)
sudo imagem/publicar-cloud-init.sh       # user-data e meta-data
sudo ipxe/preparar-ipxe.sh               # compila o iPXE (alguns minutos) e baixa o Alpine
sudo alpine/empacotar-apkovl.sh          # script de gravação que roda no Alpine
```

Todos precisam de internet. Se um script for interrompido (Ctrl+C ou queda de rede), é só rodá-lo de novo. Casos especiais:

- `apt` reclamando do dpkg: `sudo dpkg --configure -a`;
- `git clone` do iPXE interrompido (`destination path ... already exists`): `sudo rm -r /var/tmp/starlit/ipxe` e rodar de novo.

## 5.2 Conferir o servidor

```sh
systemctl is-active dnsmasq nginx                  # active, active
sudo ss -ulpn | grep -E ':67 |:69 |:4011 '         # portas no IP do servidor
curl http://<IP do servidor>/                      # de outra máquina: lista boot.ipxe, noble.raw.gz, alpine/, cloud-init/
```

Se a porta 69 aparecer em outro IP (ou o dnsmasq não estiver ativo), rodar `sudo systemctl restart dnsmasq`.

## 5.3 Testar o boot de uma placa

1. No servidor, deixar os logs abertos ([seção 7](7-logs.md)):
   ```sh
   sudo journalctl -u dnsmasq -f
   ```
2. Ligar **uma** placa limpa ([seção 2](2-placas.md)), com monitor.
3. Sequência esperada:
   1. no monitor, *Start PXE over IPv4*; no log, `PXE(...) <MAC da placa> proxy` e `sent /srv/tftp/ipxe.efi to <IP>`;
   2. o iPXE pede IP e carrega o `boot.ipxe`; o Alpine inicia;
   3. o script mostra `=== Starlit: instalação via rede ===`, encontra a eMMC e grava a imagem (alguns minutos). **Não desligar a placa durante a gravação**;
   4. o script coloca a eMMC em primeiro lugar no boot e reinicia;
   5. o Ubuntu inicia pela eMMC; o cloud-init cria o usuário e avisa o servidor (`phone-home.log`).

Proteções, para testar com a mesma placa:

- **Placa já instalada:** forçar o boot pela rede (menu de boot, IPv4). O script deve mostrar `Imagem ... já instalada, nada será gravado` e reiniciar no Ubuntu.
- **Reinstalação:** sempre manual. Na placa, `sudo wipefs -a -f /dev/mmcblk0` e `sudo reboot`; ela cai no boot pela rede e é instalada de novo. Para uma placa que não inicia, ver *Placa instalada que não inicia* na [seção 7](7-logs.md).
