# Etapa 6. Registro dos endereços MAC e IP

A tabela de MAC, IP e hostname de cada máquina fica em [inventario.md](../referencia/inventario.md).

**Abordagem:** os IPs continuam vindo do DHCP do roteador, mas cada placa recebe sempre o mesmo IP, por meio de uma **reserva de IP por MAC** no roteador. O hostname é definido manualmente, por SSH, depois da instalação.

**Convenção sugerida:**

| Máquina | IP | Hostname |
|---|---|---|
| Servidor | o `SERVIDOR_IP` do `config.env` (nesta instalação, 192.168.0.110), fora da faixa das placas | `starlit-srv` |
| Placa NN | 192.168.0.2NN (ex.: placa 01 → 192.168.0.201) | `up-NN` (ex.: `up-01`) |

A faixa das placas (`.201` em diante) deve ficar fora da faixa de DHCP automático do roteador e não pode coincidir com o IP de outra máquina (servidor, notebook). *Confirmar se o roteador aceita reserva fora da faixa de DHCP.*

**Procedimento** (uma placa por vez):

1. Colar uma etiqueta com o número na placa (01, 02, ...), para saber qual placa física corresponde a cada linha do inventário.
2. Descobrir o MAC: acompanhar `sudo journalctl -u dnsmasq -f` no servidor e ligar **só essa placa**. O MAC aparece na requisição PXE. Com a placa já instalada, dá para ver também por `ip link` na própria placa ou na lista de clientes DHCP do roteador.
3. Anotar no `inventario.md` o número, o MAC, o IP e o hostname da placa.
4. Criar a reserva no roteador (interface web em 192.168.0.1, menu do servidor DHCP, opção de reserva de endereço): MAC → IP. *Confirmar no roteador o nome exato do menu.*
5. Depois da instalação (etapa 5), reiniciar a placa para que ela pegue o IP reservado.
6. Definir o hostname:
   ```
   ssh -i ~/.ssh/cluster-key ubuntu@192.168.0.2NN
   sudo hostnamectl set-hostname up-NN
   ```

**Acompanhamento da instalação:** comparar dois logs do servidor com o `inventario.md`:

- `sudo journalctl -u dnsmasq | grep PXE`: placas que **pediram boot pela rede** (por MAC). Uma placa que não aparece aqui não iniciou pela rede (conferir BIOS e cabo).
- `cat /var/log/nginx/phone-home.log`: placas que **terminaram a instalação** (por IP). Uma placa que pediu boot mas não aparece aqui travou na gravação ou no primeiro boot (conferir pelo monitor).

Para saber o MAC de um IP do `phone-home.log`: `ip neigh show <IP>` no servidor.

**Verificação:** `ping 192.168.0.2NN` e `ssh -i ~/.ssh/cluster-key ubuntu@192.168.0.2NN hostname` devem responder com o hostname da tabela. Para conferir todas as placas de uma vez:

```sh
for n in 01 02 03; do ssh -i ~/.ssh/cluster-key ubuntu@192.168.0.2$n hostname; done
```
